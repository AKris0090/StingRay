#include "Display.cuh"
#include "SDL.h"
#include "Camera.cuh"
#include "SceneObject.cuh"
#include "device_launch_parameters.h"
#include <random>
#include <curand.h>
#include <curand_kernel.h>
#include <math_constants.h>

#define TINYOBJLOADER_IMPLEMENTATION
#include "tiny_obj_loader.h"

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

void setupObjectsHost(vector<SceneObject*>& hostObjects, vector<PBRMaterial*>& hostMaterials, vector<AreaLight*>& hostLights) {
    AreaLight* l1 = new AreaLight(Sphere(V3(1.0f, 1.5f, 2.0f), 0.15f), 9.0f);
    AreaLight* l2 = new AreaLight(Sphere(V3(-1.0f, 1.5f, 2.0f), 0.15f), 9.0f);
    AreaLight* l3 = new AreaLight(Sphere(V3(1.0f, 1.5f, -2.0f), 0.15f), 9.0f);
    AreaLight* l4 = new AreaLight(Sphere(V3(-1.0f, 1.5f, -2.0f), 0.15f), 9.0f);
    hostLights.push_back(l1);
    hostLights.push_back(l2);
    hostLights.push_back(l3);
    hostLights.push_back(l4);

    PBRMaterial* metal = new PBRMaterial(V3(100.0f, 100.0f, 100.0f), 1.0f, 0.75f, 0.0f, 0.0f, 0.0f);
    PBRMaterial* metal2 = new PBRMaterial(V3(180.0f, 180.0f, 180.0f), 0.0f, 1.0f, 0.0f, 0.0f, 0.0f);
    PBRMaterial* red = new PBRMaterial(V3(255.0f, 140.0f, 0.0f), 0.0f, 1.0f, 0.0f, 0.0f, 0.0f);
    PBRMaterial* blue = new PBRMaterial(V3(186.0f, 85.0f, 211.0f), 0.0f, 1.0f, 0.0f, 0.0f, 10.0f);
    hostMaterials.push_back(metal);
    hostMaterials.push_back(metal2);
    hostMaterials.push_back(red);
    hostMaterials.push_back(blue);

    Triangle* t1 = new Triangle(
        V3(-50, -0.5f, -50),
        V3(50, -0.5f, -50),
        V3(50, -0.5f, 50)
    );
    t1->normal = V3(0, 1, 0);
    t1->base.type = TRIANGLE;
    t1->base.matIdx = 2;
    hostObjects.push_back((SceneObject*)t1);

    Triangle* t2 = new Triangle(
        V3(-50, -0.5f, -50),
        V3(50, -0.5f, 50),
        V3(-50, -0.5f, 50)
    );
    t2->normal = V3(0, 1, 0);
    t2->base.type = TRIANGLE;
    t2->base.matIdx = 2;
    hostObjects.push_back((SceneObject*)t2);
}

void setupObjectsDevice(vector<SceneObject*>& hostObjects, vector<PBRMaterial*>& hostMaterials, vector<AreaLight*>& hostLights, DisplayWindow& window) {
    gpuChk(cudaMalloc((void**) & window.objects, hostObjects.size() * sizeof(SceneObject*)));

    gpuChk(cudaMalloc((void**) &window.mats, hostMaterials.size() * sizeof(PBRMaterial*)));

    gpuChk(cudaMalloc((void**) &window.lights, hostLights.size() * sizeof(AreaLight*)));

    for (int i = 0; i < (int)hostMaterials.size(); i++) {
        PBRMaterial* devMatPtr = nullptr;
        gpuChk(cudaMalloc(&devMatPtr, sizeof(PBRMaterial)));
        gpuChk(cudaMemcpy(devMatPtr, hostMaterials[i], sizeof(PBRMaterial), cudaMemcpyHostToDevice));
        PBRMaterial* tmp = devMatPtr;
        gpuChk(cudaMemcpy(window.mats + i, &tmp, sizeof(PBRMaterial*), cudaMemcpyHostToDevice));
    }

    for (int i = 0; i < hostObjects.size(); i++) {
        SceneObject* devPtr;
        size_t size = 0;

        PBRMaterial* devMatPtr = nullptr;
        gpuChk(cudaMemcpy(&devMatPtr, window.mats + hostObjects[i]->matIdx, sizeof(PBRMaterial*), cudaMemcpyDeviceToHost));
        hostObjects[i]->mat = devMatPtr;

        if (hostObjects[i]->type == SPHERE) {
            size = sizeof(Sphere);
        } else if (hostObjects[i]->type == TRIANGLE) {
            size = sizeof(Triangle);
        }

        gpuChk(cudaMalloc(&devPtr, size));
        gpuChk(cudaMemcpy(devPtr, hostObjects[i], size, cudaMemcpyHostToDevice));
        gpuChk(cudaMemcpy(window.objects + i, &devPtr, sizeof(SceneObject*), cudaMemcpyHostToDevice));
    }

    for (int i = 0; i < hostLights.size(); i++) {
        AreaLight* devLight;

        gpuChk(cudaMalloc(&devLight, sizeof(AreaLight)));
        gpuChk(cudaMemcpy(devLight, hostLights[i], sizeof(AreaLight), cudaMemcpyHostToDevice));
        gpuChk(cudaMemcpy(window.lights + i, &devLight, sizeof(AreaLight*), cudaMemcpyHostToDevice));
    }
}

void loadModel(string filepath, vector<SceneObject*>& hostObjects) {
    tinyobj::attrib_t attrib;
    std::vector<tinyobj::shape_t> shapes;
    std::vector<tinyobj::material_t> materials;
    string mtlPath = "./";

    std::string err;

    bool ret = tinyobj::LoadObj(&attrib, &shapes, &materials, &err, filepath.c_str(), mtlPath.c_str());
    if (!err.empty()) {
        std::cerr << err << std::endl;
    }

    if (!ret) {
        exit(1);
    }

    // Loop over shapes
    for (size_t s = 0; s < shapes.size(); s++) {
        // Loop over faces(polygon)
        size_t index_offset = 0;
        for (size_t f = 0; f < shapes[s].mesh.num_face_vertices.size(); f++) {
            size_t fv = size_t(shapes[s].mesh.num_face_vertices[f]);

            tinyobj::index_t i1 = shapes[s].mesh.indices[index_offset + 0];
            tinyobj::index_t i2 = shapes[s].mesh.indices[index_offset + 1];
            tinyobj::index_t i3 = shapes[s].mesh.indices[index_offset + 2];

            auto fetch = [&](tinyobj::index_t idx) {
                return V3(
                    attrib.vertices[3 * idx.vertex_index + 0],
                    attrib.vertices[3 * idx.vertex_index + 1],
                    attrib.vertices[3 * idx.vertex_index + 2]
                );
                };

            V3 v1 = fetch(i1);
            V3 v2 = fetch(i2);
            V3 v3 = fetch(i3);

            auto fetchN = [&](tinyobj::index_t idx) {
                return V3(
                    attrib.normals[3 * idx.normal_index + 0],
                    attrib.normals[3 * idx.normal_index + 1],
                    attrib.normals[3 * idx.normal_index + 2]
                );
                };

            V3 n1 = fetchN(i1);
            V3 n2 = fetchN(i2);
            V3 n3 = fetchN(i3);

            Triangle* t = new Triangle(v1, v2, v3);
            t->base.type = TRIANGLE;
            t->base.matIdx = 1;
            t->normal = ((n1 + n2 + n3) / 3).normalize();
            hostObjects.push_back((SceneObject*)t);

            index_offset += fv;
        }
    }
}

__host__ void resetDisplay(DisplayWindow& window) {
    cudaMemset(window.totals, 0, ((SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(V3)));
    cudaMemset(window.devPixels, 0, ((SCREEN_WIDTH * SCREEN_HEIGHT) * (sizeof(Uint8) * 3)));

    window.repeat_samples = 0;
}

__global__ void updateDisplay(V3* totals, Uint8* devPixels, V3 hor, V3 ver, V3 botL, V3 copOrigin, const int numBounces, int numObjects, SceneObject** objects, int numLights, AreaLight** lights, curandState* devStates, int repeatSamples, unsigned long seed) {
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
    gpuChk(cudaMalloc((void**)&devStates, (SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(curandState)));
    gpuChk(cudaMalloc((void**)&(window.totals), ((SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(V3))));
    gpuChk(cudaMalloc((void**)&(window.devPixels), ((SCREEN_WIDTH * SCREEN_HEIGHT) * (sizeof(Uint8) * 3))));

    Uint8* copyTotals;
    size_t totalSize = (size_t)((SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(Uint8) * 3);
    gpuChk(cudaHostAlloc((void**)&copyTotals, totalSize, 0));

    std::vector<Uint32> pixels(SCREEN_WIDTH * SCREEN_HEIGHT);
    Camera cam(SCREEN_WIDTH, SCREEN_HEIGHT, CAM_VFOV_DEG);

    vector<SceneObject*> hostObjects;
    vector<PBRMaterial*> hostMaterials;
    vector<AreaLight*> hostLights;
    setupObjectsHost(hostObjects, hostMaterials, hostLights);
    loadModel("./objects/fox.obj", hostObjects);
    setupObjectsDevice(hostObjects, hostMaterials, hostLights, window);

    window.texture = SDL_CreateTexture(window.renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, SCREEN_WIDTH, SCREEN_HEIGHT);

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
            window.copied_origin = cam.origin;
            cam.needUpdate = true;
        }

        auto t1 = high_resolution_clock::now();

        if (window.repeat_samples < NUM_SAMPLES) {
            window.repeat_samples += 1;
            updateDisplay << <blocks, threads >> > (window.totals, window.devPixels, cam.horizontal, cam.vertical, cam.botLeft, cam.origin, NUM_BOUNCES, hostObjects.size(), window.objects, hostLights.size(), window.lights, devStates, window.repeat_samples, unsigned(rand()));
            gpuChk(cudaDeviceSynchronize());
            gpuChk(cudaPeekAtLastError());

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
            resetDisplay(window);
        }
    }
    SDL_DestroyRenderer(window.renderer);
    SDL_DestroyTexture(window.texture);
    SDL_DestroyWindow(window.window);
    cudaFree(window.totals);
    cudaFree(devStates);

    cudaFree(window.lights);
    cudaFree(window.objects);
    cudaFree(window.mats);

    return 0;
}