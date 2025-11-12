#include "Display.cuh"
#include "SDL.h"
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

// GPU Error Checking MACRO
#define gpuChk(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char* file, int line, bool abort = true)
{
    if (code != cudaSuccess)
    {
        fprintf(stdout, "GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
        if (abort) exit(code);
    }
}

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

// Setup CUDA resources in device memory only once
__global__ void setup_kernel(Sphere** objects, AreaLight** lights, PBRMaterial** mats, int numLights, int numObjects) {
    if (threadIdx.x == 0 && blockIdx.x == 0) {
        PBRMaterial* metal = new PBRMaterial(V3(100.0f, 100.0f, 100.0f), 1.0f, 0.75f, 0.0f, 0.0f, 0.0f);
        PBRMaterial* metal2 = new PBRMaterial(V3(180.0f, 180.0f, 180.0f), 0.0f, 1.0f, 0.0f, 0.0f, 0.0f);
        PBRMaterial* red = new PBRMaterial(V3(255.0f, 140.0f, 0.0f), 0.0f, 1.0f, 0.0f, 0.0f, 0.0f);
        PBRMaterial* blue = new PBRMaterial(V3(186.0f, 85.0f, 211.0f), 0.0f, 1.0f, 0.0f, 0.0f, 10.0f);

        *(mats) = metal;
        *(mats + 1) = metal2;
        *(mats + 2) = red;
        *(mats + 3) = blue;

        *(lights) = new AreaLight(Sphere(V3(1.0f, 1.5f, 2.0f), 0.15f), 9.0f);
        *(lights + 1) = new AreaLight(Sphere(V3(-1.0f, 1.5f, 2.0f), 0.15f), 9.0f);
        *(lights + 2) = new AreaLight(Sphere(V3(1.0f, 1.5f, -2.0f), 0.15f), 9.0f);
        *(lights + 3) = new AreaLight(Sphere(V3(-1.0f, 1.5f, -2.0f), 0.15f), 9.0f);

        *(objects) = new Sphere(V3(0.0, 0.0, -1), 0.5, mats[3]);
        *(objects + 1) = new Sphere(V3(0, -100.5, -1), 100, mats[2]);
        *(objects + 2) = new Sphere(V3(1, 0, -1), 0.5, mats[0]);
        *(objects + 3) = new Sphere(V3(-1, 0, -1), 0.5, mats[1]);
    }
}

__host__ void resetDisplay(DisplayWindow& window) {
    cudaMemset(window.totals, 0, ((SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(V3)));
    cudaMemset(window.devPixels, 0, ((SCREEN_WIDTH * SCREEN_HEIGHT) * (sizeof(Uint8) * 3)));

    window.repeat_samples = 0;
}

__global__ void updateDisplay(V3* totals, Uint8* devPixels, V3 hor, V3 ver, V3 botL, V3 copOrigin, const int numBounces, int numObjects, Sphere** objects, int numLights, AreaLight** lights, curandState* devStates, int repeatSamples, unsigned long seed) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;
    int index = i + (j * SCREEN_WIDTH);
    curand_init(seed, index, 0, &devStates[index]);
    curandState localDevState = devStates[index];
    if ((i >= SCREEN_WIDTH) || (j >= SCREEN_HEIGHT)) return;

    V3 u = hor * ((float)(i + (curand_uniform(&localDevState))) / (float) (SCREEN_WIDTH - 1.0));
    V3 v = ver * ((float)(j + (curand_uniform(&localDevState))) / (float) (SCREEN_HEIGHT - 1.0));

    V3 dir = (botL + u + v - copOrigin).normalize();
    Ray primary_ray(copOrigin, dir);
    V3 ret_color = Tracer::trace_ray(primary_ray, objects, lights, numBounces, numObjects, numLights, &localDevState);

    totals[index].x += clampRGB(ret_color.x);
    totals[index].y += clampRGB(ret_color.y);
    totals[index].z += clampRGB(ret_color.z);
    devPixels[(index * 3)] = totals[index].x / repeatSamples;
    devPixels[(index * 3) + 1] = totals[index].y / repeatSamples;
    devPixels[(index * 3) + 2] = totals[index].z / repeatSamples;
}

void updateProgressBar(float progress, std::chrono::steady_clock::time_point t1, std::chrono::steady_clock::time_point t2) {
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

__host__ inline float radians(float deg) {
    return deg * (CUDART_PI_F / 180.0f);
}

int main(int argc, char** arcgv) {
    int tx = 8;
    int ty = 8;
    dim3 blocks(SCREEN_WIDTH / tx + 1, SCREEN_HEIGHT / ty + 1);
    dim3 threads(tx, ty);

    DisplayWindow window;

    int numObjects, numLights;
    bool running = true;
    SDL_Event event;

    window.initDisplay(SCREEN_WIDTH, SCREEN_HEIGHT);
    SDL_SetRelativeMouseMode(SDL_TRUE);

    numObjects = 4;
    numLights = 4;

    curandState* devStates;
    gpuChk(cudaMalloc((void**)&devStates, (SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(curandState)));

    gpuChk(cudaMalloc((void**)&(window.objects), numObjects * sizeof(Sphere*)));
    gpuChk(cudaMalloc((void**)&(window.lights), numLights * sizeof(AreaLight*)));
    gpuChk(cudaMalloc((void**)&(window.mats), 4 * sizeof(PBRMaterial*)));
    gpuChk(cudaMalloc((void**)&(window.totals), ((SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(V3))));
    gpuChk(cudaMalloc((void**)&(window.devPixels), ((SCREEN_WIDTH * SCREEN_HEIGHT) * (sizeof(Uint8) * 3))));
    gpuChk(cudaMallocManaged((void**)&(window.copied_origin), sizeof(V3)));

    Uint8* copyTotals;
    gpuChk(cudaHostAlloc((void**)&(copyTotals), (size_t)((SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(Uint8) * 3), 0));

    Uint32* pixels;
    pixels = (Uint32*)malloc((SCREEN_HEIGHT * SCREEN_WIDTH) * sizeof(Uint32));
    float aspect = SCREEN_WIDTH / SCREEN_HEIGHT;
    float yaw = -90.0f;
    float pitch = 0.0f;
    bool cameraChanged = false;

    V3 u, v, w;

    V3 cam_origin = V3(0.0, 0.0, 0.5);
    V3 lookat = V3(0.0, 0.0, -1.0);
    V3 up = V3(0.0, 1.0, 0.0);

    float theta = CAM_VFOV_DEG * (CUDART_PI_F / 180.0f);
    float h_height = tanf(theta / 2.0f);
    float h_width = aspect * h_height;

    w = (cam_origin - lookat).normalize();
    u = (up.cross(w)).normalize();
    v = w.cross(u);

    window.bot_left = cam_origin - u * h_width - v * h_height - w;
    window.horizontal = u * (2.0f * h_width);
    window.vertical = v * (2.0f * h_height);

    // setup seeds
    setup_kernel<<<1, 1>>>(window.objects, window.lights, window.mats, numLights, numObjects);
    gpuChk(cudaDeviceSynchronize());
    gpuChk(cudaPeekAtLastError());

    window.copied_origin = cam_origin;

    window.texture = SDL_CreateTexture(window.renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, SCREEN_WIDTH, SCREEN_HEIGHT);

    while (running) {
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) running = false;

            if (event.type == SDL_MOUSEMOTION) {
                float xoffset = event.motion.xrel * LOOK_SENS;
                float yoffset = event.motion.yrel * LOOK_SENS;

                yaw += xoffset;
                pitch -= yoffset;

                // convert yaw/pitch to a direction vector
                V3 direction;
                direction.x = cosf(radians(yaw)) * cosf(radians(pitch));
                direction.y = sinf(radians(pitch));
                direction.z = sinf(radians(yaw)) * cosf(radians(pitch));
                lookat = (cam_origin + direction).normalize();

                cameraChanged = true;
            }

            if (event.type == SDL_KEYDOWN) {
                switch (event.key.keysym.sym) {
                case SDLK_w: cam_origin.z -= MOVE_SENS; lookat.z -= MOVE_SENS; break;
                case SDLK_s: cam_origin.z += MOVE_SENS; lookat.z += MOVE_SENS; break;
                case SDLK_a: cam_origin.x -= MOVE_SENS; lookat.x -= MOVE_SENS; break;
                case SDLK_d: cam_origin.x += MOVE_SENS; lookat.x += MOVE_SENS; break;
                case SDLK_q: cam_origin.y -= MOVE_SENS; lookat.y -= MOVE_SENS; break;
                case SDLK_e: cam_origin.y += MOVE_SENS; lookat.y += MOVE_SENS; break;
                }
                window.copied_origin = cam_origin;
                cameraChanged = true;
            }
        }

        auto t1 = high_resolution_clock::now();

        if (window.repeat_samples < NUM_SAMPLES) {
            window.repeat_samples += 1;
            updateDisplay << <blocks, threads >> > (window.totals, window.devPixels, window.horizontal, window.vertical, window.bot_left, window.copied_origin, NUM_BOUNCES, numObjects, window.objects, numLights, window.lights, devStates, window.repeat_samples, unsigned(rand()));

            cudaMemcpyAsync(copyTotals, window.devPixels, (SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(Uint8) * 3, cudaMemcpyDeviceToHost);

            gpuChk(cudaDeviceSynchronize());
            gpuChk(cudaPeekAtLastError());

            for (int i = 0; i < SCREEN_WIDTH; i++) {
                for (int j = 0; j < SCREEN_HEIGHT; j++) {
                    int index = i + (j * SCREEN_WIDTH);
                    pixels[index] = SDL_MapRGB(window.surface->format, copyTotals[(index * 3)], copyTotals[(index * 3) + 1], copyTotals[(index * 3) + 2]);
                }
            }

            SDL_UpdateTexture(window.texture, NULL, pixels, SCREEN_WIDTH * sizeof(Uint32));
            SDL_RenderClear(window.renderer);
            SDL_RenderCopyEx(window.renderer, window.texture, NULL, NULL, 0, NULL, SDL_FLIP_VERTICAL);
            SDL_RenderPresent(window.renderer);

            auto t2 = high_resolution_clock::now();

            updateProgressBar(window.repeat_samples / (float)NUM_SAMPLES, t1, t2);
        }

        if (cameraChanged) {
            // recompute camera basis once per frame
            w = (cam_origin - lookat).normalize();
            u = (up.cross(w)).normalize();
            v = w.cross(u);

            window.bot_left = cam_origin - u * h_width - v * h_height - w;
            window.horizontal = u * (2.0f * h_width);
            window.vertical = v * (2.0f * h_height);

            resetDisplay(window);
            cameraChanged = false;
        }
    }
    SDL_DestroyRenderer(window.renderer);
    SDL_DestroyTexture(window.texture);
    SDL_DestroyWindow(window.window);
    cudaFree(window.totals);
    cudaFree(devStates);
    free(pixels);

    cudaFree(window.lights);
    cudaFree(window.objects);
    cudaFree(window.mats);

    return 0;
}