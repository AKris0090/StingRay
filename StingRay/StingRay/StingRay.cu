#include "Display.cuh"
#include "SDL.h"
#include "device_launch_parameters.h"
#include <random>
#include <curand.h>
#include <curand_kernel.h>

#define SCREEN_WIDTH 1200
#define SCREEN_HEIGHT 600
#define NUMBOUNCES 3

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

// Setup CUDA resources in device memory. Only once.
__global__ void setup_kernel(Sphere** objects, AreaLight** lights, PBRMaterial** mats, int numLights, int numObjects) {
    if (threadIdx.x == 0 && blockIdx.x == 0) {
        V3 center_one = { 0, 0, -1 };
        V3 radius_one = 1.5;

        PBRMaterial* metal = new PBRMaterial(V3(204.0f, 204.0f, 204.0f), 0.0f, 0.05f, 0.0f, 0.0f, 0.0f);
        PBRMaterial* metal2 = new PBRMaterial(V3(204.0f, 204.0f, 204.0f), 0.0f, 0.25f, 0.0f, 0.0f, 0.0f);
        PBRMaterial* red = new PBRMaterial(V3(255.0f, 0.0f, 0.0f), 0.0f, 1.0f, 0.0f, 0.0f, 0.0f);
        PBRMaterial* blue = new PBRMaterial(V3(0.0f, 0.0f, 255.0f), 0.0f, 1.0f, 0.0f, 0.0f, 0.0f);

        *(mats) = metal;
        *(mats + 1) = metal2;
        *(mats + 2) = red;
        *(mats + 3) = blue;

        *(lights) = new AreaLight(Sphere(V3(-2.0f, 2.0f, 1.0f), 0.15f), 1500.0f);
        *(lights + 1) = new AreaLight(Sphere(V3(2.0f, 2.0f, 1.0f), 0.15f), 1500.0f);

        *(objects) = new Sphere(V3(0, 0, -1), 0.5, mats[3]);
        *(objects + 1) = new Sphere(V3(0, -100.5, -1), 100, mats[2]);
        *(objects + 2) = new Sphere(V3(1, 0, -1), 0.5, mats[0]);
        *(objects + 3) = new Sphere(V3(-1, 0, -1), 0.5, mats[1]);
    }
}


__global__ void updateDisplay(V3* totals, V3* devPixels, V3 hor, V3 ver, V3 botL, V3 copOrigin, float numSamples, const int numBounces, int numObjects, Sphere** objects, int numLights, AreaLight** lights, curandState* devStates, int repeatSamples, unsigned long seed) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;
    int index = i + (j * SCREEN_WIDTH);
    curand_init(seed, index, 0, &devStates[index]);
    curandState localDevState = devStates[index];
    if ((i >= SCREEN_WIDTH) || (j >= SCREEN_HEIGHT)) return;

    V3 u = hor.mul_val((float)(i + (curand_uniform(&localDevState))) / (float) SCREEN_WIDTH);
    V3 v = ver.mul_val((float)(j + (curand_uniform(&localDevState))) / (float) SCREEN_HEIGHT);

    Ray primary_ray(copOrigin, botL.add(u).add(v).sub(copOrigin));
    V3 ret_color = Tracer::trace_ray(primary_ray, objects, lights, numBounces, numObjects, numLights, &localDevState);

    totals[index].x += clampRGB(ret_color.x);
    totals[index].y += clampRGB(ret_color.y);
    totals[index].z += clampRGB(ret_color.z);
    devPixels[index] = totals[index].div_val(repeatSamples);
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
    float numSamples = 1000.0f;

    window.initDisplay(SCREEN_WIDTH, SCREEN_HEIGHT);

    numObjects = 4;
    numLights = 2;

    curandState* devStates;
    gpuChk(cudaMallocManaged((void**)&devStates, (SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(curandState)));

    gpuChk(cudaMallocManaged((void**)&(window.objects), numObjects * sizeof(Sphere*)));
    gpuChk(cudaMallocManaged((void**)&(window.lights), numLights * sizeof(AreaLight*)));
    gpuChk(cudaMallocManaged((void**)&(window.mats), 4 * sizeof(PBRMaterial*)));
    gpuChk(cudaMallocManaged((void**)&(window.totals), ((SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(V3))));
    gpuChk(cudaMallocManaged((void**)&(window.devPixels), ((SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(V3))));


    float cam_aspect_width = 4;
    float cam_aspect_height = 2;
    V3* copyTotals;

    window.bot_left = V3(-cam_aspect_width, -cam_aspect_height, -1);
    window.horizontal = V3(cam_aspect_width * 2, 0, 0);
    window.vertical = V3(0, cam_aspect_height * 2, 0);

    // setup seeds
    setup_kernel<<<1, 1>>>(window.objects, window.lights, window.mats, numLights, numObjects);
    gpuChk(cudaDeviceSynchronize());
    gpuChk(cudaPeekAtLastError());

    window.copied_origin = V3(0.0, 0.0, 0.0);

    while (SDL_PollEvent(&event) || running) {

        cout << "\r";

        auto t1 = high_resolution_clock::now();


        Uint32* pixels = (Uint32*) malloc((SCREEN_HEIGHT * SCREEN_WIDTH) * sizeof(Uint32));
        window.texture = SDL_CreateTexture(window.renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, SCREEN_WIDTH, SCREEN_HEIGHT);

        if (window.repeat_samples < numSamples) {

            window.repeat_samples += 1;
            updateDisplay<<<blocks, threads>>>(window.totals, window.devPixels, window.horizontal, window.vertical, window.bot_left, window.copied_origin, numSamples, NUMBOUNCES, numObjects, window.objects, numLights, window.lights, devStates, window.repeat_samples, unsigned(rand()));
            gpuChk(cudaDeviceSynchronize());
            gpuChk(cudaPeekAtLastError());

            copyTotals = (V3*)malloc((SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(V3));

            gpuChk(cudaMemcpy(copyTotals, window.devPixels, ((SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(V3)), cudaMemcpyDeviceToHost));

            for (int i = 0; i < SCREEN_WIDTH; i++) {
                for (int j = 0; j < SCREEN_HEIGHT; j++) {
                    int index = i + (j * SCREEN_WIDTH);
                    pixels[index] = SDL_MapRGB(window.surface->format, (Uint8)(copyTotals[index].x), (Uint8)(copyTotals[index].y), (Uint8)(copyTotals[index].z));
                }
            }

            free(copyTotals);
            SDL_UpdateTexture(window.texture, NULL, pixels, SCREEN_WIDTH * sizeof(Uint32));
            SDL_RenderClear(window.renderer);
            SDL_RenderCopyEx(window.renderer, window.texture, NULL, NULL, 0, NULL, SDL_FLIP_VERTICAL);
            SDL_DestroyTexture(window.texture);
            SDL_RenderPresent(window.renderer);
        }
        auto t2 = high_resolution_clock::now();

        /* Getting number of milliseconds as an integer. */
        auto ms_int = duration_cast<milliseconds>(t2 - t1);

        /* Getting number of milliseconds as a double. */
        duration<double, std::milli> ms_double = t2 - t1;

        cout << window.repeat_samples << "/" << numSamples << " samples " << ms_double.count() << " ms";

        free(pixels);

        switch (event.type) {
        case SDL_QUIT:
            running = false;
            break;
        default:
            break;
        }
    }
    SDL_DestroyRenderer(window.renderer);
    SDL_DestroyWindow(window.window);
    cudaFree(window.totals);
    cudaFree(devStates);

    cudaFree(window.lights);
    cudaFree(window.objects);
    cudaFree(window.mats);

    return 0;
}