#include "Display.cuh"
#include "SDL.h"
#include "Camera.cuh"
#include "Tracer.cuh"
#include "Scene.cuh"
#include "device_launch_parameters.h"
#include <random>
#include <curand.h>
#include <curand_kernel.h>
#include <math_constants.h>

constexpr int SCREEN_WIDTH = 1200;
constexpr int SCREEN_HEIGHT = 600;
constexpr int NUM_BOUNCES = 5;
constexpr float CAM_VFOV_DEG = 90.0f;
constexpr float MOVE_SENS = 0.1f;
constexpr float LOOK_SENS = 0.1f;
constexpr int PROGRESS_WIDTH = 50;
constexpr int NUM_SAMPLES = 1000;

using namespace std;

using std::chrono::high_resolution_clock;
using std::chrono::duration_cast;
using std::chrono::duration;
using std::chrono::milliseconds;

// Clamping the color traced
__device__ float clampRGB(float in) {
    if (in < 0.0f) {
        return 0.0f;
    }
    else if (in > 255.0f) {
        return 255.0f;
    }
    else {
        return in;
    }
}

void setupObjectsHost(Scene& scene) {
    scene.addLight(V3(1.0f, 1.5f, 2.0f), 0.15f, 9.0f);
    scene.addLight(V3(-1.0f, 1.5f, 2.0f), 0.15f, 9.0f);
    scene.addLight(V3(1.0f, 1.5f, -2.0f), 0.15f, 9.0f);
    scene.addLight(V3(-1.0f, 1.5f, -2.0f), 0.15f, 9.0f);

    scene.addMaterial(V3(100.0f, 100.0f, 100.0f), 0.75f, 1.0f);
    scene.addMaterial(V3(180.0f, 180.0f, 180.0f), 1.0f, 0.0f);
    scene.addMaterial(V3(255.0f, 140.0f, 0.0f), 1.0f, 0.0f);
    scene.addMaterial(V3(186.0f, 85.0f, 211.0f), 1.0f, 0.0f);

    scene.addObjectFromFile("./objects/fox.obj");

    scene.addTriangle(V3(-50, -0.5f, -50),
        V3(50, -0.5f, 50),
        V3(-50, -0.5f, 50), 2);
    scene.addTriangle(V3(-50, -0.5f, -50),
        V3(50, -0.5f, -50),
        V3(50, -0.5f, 50), 2);
}

__global__ void updateDisplay(V3* totals, Uint8* devPixels, GPUCam* cam, const int numBounces, d_Scene* scene, curandState* devStates, int repeatSamples, unsigned long seed) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;
    int index = i + (j * SCREEN_WIDTH);
    curand_init(seed, index, 0, &devStates[index]);
    curandState localDevState = devStates[index];
    if ((i >= SCREEN_WIDTH) || (j >= SCREEN_HEIGHT)) return;

    V3 u = cam->horizontal * ((float)(i + (curand_uniform(&localDevState))) / (float) (SCREEN_WIDTH - 1.0));
    V3 v = cam->vertical * ((float)(j + (curand_uniform(&localDevState))) / (float) (SCREEN_HEIGHT - 1.0));

    V3 dir = (cam->botLeft + u + v - cam->origin).normalize();
    Ray primary_ray(cam->origin, dir);
    V3 ret_color = Tracer::trace_ray(primary_ray, scene, numBounces, &localDevState);

    totals[index].x += clampRGB(ret_color.x);
    totals[index].y += clampRGB(ret_color.y);
    totals[index].z += clampRGB(ret_color.z);
    devPixels[(index * 3)] = totals[index].x / repeatSamples;
    devPixels[(index * 3) + 1] = totals[index].y / repeatSamples;
    devPixels[(index * 3) + 2] = totals[index].z / repeatSamples;
}

static void updateProgressBar(float progress, std::chrono::steady_clock::time_point t1, std::chrono::steady_clock::time_point t2) {
    cout << "\r";

    duration<double, std::milli> ms_double = t2 - t1;
    std::cout << "[";
    int pos = PROGRESS_WIDTH * progress;
    for (int i = 0; i < PROGRESS_WIDTH; ++i) {
        if (i < pos) std::cout << "=";
        else if (i == pos) std::cout << ">";
        else std::cout << " ";
    }
    std::cout << "] " << int(progress * 100.0) << "% : " << ms_double.count() << "ms" << " \r";
    std::cout.flush();
}

int main(int argc, char** arcgv) {
    int tx = 8;
    int ty = 8;
    dim3 blocks(SCREEN_WIDTH / tx + 1, SCREEN_HEIGHT / ty + 1);
    dim3 threads(tx, ty);

    DisplayWindow window;

    bool running = true;
    SDL_Event event;
    float lastFrameTime = 0.0f;
    const Uint8* state = SDL_GetKeyboardState(NULL);

    float deltaTime = (SDL_GetTicks() - lastFrameTime) / 1000.0f;
    lastFrameTime = SDL_GetTicks();

    window.initDisplay(SCREEN_WIDTH, SCREEN_HEIGHT);
    SDL_SetRelativeMouseMode(SDL_TRUE);

    curandState* devStates;
    CUDA_CHECK(cudaMalloc((void**)&devStates, (SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(curandState)));
    CUDA_CHECK(cudaMalloc((void**)&(window.totals), ((SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(V3))));
    CUDA_CHECK(cudaMalloc((void**)&(window.devPixels), ((SCREEN_WIDTH * SCREEN_HEIGHT) * (sizeof(Uint8) * 3))));

    Uint8* copyTotals = nullptr;
    size_t totalSize = (size_t)((SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(Uint8) * 3);
    CUDA_CHECK(cudaHostAlloc((void**)&copyTotals, totalSize, 0));

    std::vector<Uint32> pixels(SCREEN_WIDTH * SCREEN_HEIGHT);
    Camera cam(SCREEN_WIDTH, SCREEN_HEIGHT, CAM_VFOV_DEG);

    Scene h_scene;
    setupObjectsHost(h_scene);
    h_scene.offloadObjects();
    h_scene.buildBVH();
    d_Scene tempScene = h_scene.getDeviceScene();

    d_Scene* d_scene = nullptr;
    CUDA_CHECK(cudaMalloc((void**)&d_scene, sizeof(d_Scene)));
    CUDA_CHECK(cudaMemcpy((void*)d_scene, &(tempScene), sizeof(d_Scene), cudaMemcpyHostToDevice));

    window.texture = SDL_CreateTexture(window.renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, SCREEN_WIDTH, SCREEN_HEIGHT);

    GPUCam* d_cam = nullptr;
    CUDA_CHECK(cudaMalloc((void**)&d_cam, sizeof(GPUCam)));
    GPUCam h_cam{
        cam.origin,
        cam.botLeft,
        cam.horizontal,
        cam.vertical
    };
    CUDA_CHECK(cudaMemcpy((void*)d_cam, &h_cam, sizeof(GPUCam), cudaMemcpyHostToDevice));

    while (running) {
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) running = false;

            if (event.type == SDL_MOUSEMOTION) {
                float xoffset = event.motion.xrel * LOOK_SENS;
                float yoffset = event.motion.yrel * LOOK_SENS;

                cam.mouseMove(xoffset, yoffset);
            }
        }

        V3 forward = (cam.lookat - cam.origin).normalize();
        V3 right = forward.cross(cam.up).normalize();

        bool write = false;

        if (state[SDL_SCANCODE_W]) { cam.origin += forward * MOVE_SENS; write = true; }
        if (state[SDL_SCANCODE_S]) { cam.origin -= forward * MOVE_SENS; write = true; }
        if (state[SDL_SCANCODE_A]) { cam.origin -= right   * MOVE_SENS; write = true; }
        if (state[SDL_SCANCODE_D]) { cam.origin += right   * MOVE_SENS; write = true; }
        if (state[SDL_SCANCODE_Q]) { cam.origin -= cam.up  * MOVE_SENS; write = true; }
        if (state[SDL_SCANCODE_E]) { cam.origin += cam.up  * MOVE_SENS; write = true; }

        if (write) {
            cam.lookat = cam.origin + cam.forward;
            cam.needUpdate = true;
        }

        auto t1 = high_resolution_clock::now();

        if (window.repeat_samples < NUM_SAMPLES) {
            window.repeat_samples += 1;
            updateDisplay << <blocks, threads >> > (window.totals, window.devPixels, d_cam, NUM_BOUNCES, d_scene, devStates, window.repeat_samples, unsigned(rand()));
            CUDA_CHECK(cudaDeviceSynchronize());
            CUDA_CHECK(cudaPeekAtLastError());

            cudaMemcpy(copyTotals, window.devPixels, (SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(Uint8) * 3, cudaMemcpyDeviceToHost);
            
            for (int i = 0; i < SCREEN_WIDTH * SCREEN_HEIGHT; i++) {
                pixels[i] = SDL_MapRGB(window.surface->format, copyTotals[(i * 3)], copyTotals[(i * 3) + 1], copyTotals[(i * 3) + 2]);
            }

            SDL_UpdateTexture(window.texture, NULL, pixels.data(), SCREEN_WIDTH * sizeof(Uint32));
            SDL_RenderClear(window.renderer);
            SDL_RenderCopyEx(window.renderer, window.texture, NULL, NULL, 0, NULL, SDL_FLIP_VERTICAL);
            SDL_RenderPresent(window.renderer);

            auto t2 = high_resolution_clock::now();

            updateProgressBar(window.repeat_samples / (float)NUM_SAMPLES, t1, t2);
        }

        if (cam.needUpdate) {
            // recompute camera basis once per frame b   
            cam.updateCam();
            h_cam = cam.getCamStruct();
            CUDA_CHECK(cudaMemcpy((void*)d_cam, &h_cam, sizeof(GPUCam), cudaMemcpyHostToDevice));
            
            cudaMemset(window.totals, 0, ((SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(V3)));
            cudaMemset(window.devPixels, 0, ((SCREEN_WIDTH * SCREEN_HEIGHT) * (sizeof(Uint8) * 3)));

            window.repeat_samples = 0;
        }
    }
    SDL_DestroyRenderer(window.renderer);
    SDL_DestroyTexture(window.texture);
    SDL_DestroyWindow(window.window);
    cudaFree(window.totals);
    cudaFree(devStates);

    return 0;
}