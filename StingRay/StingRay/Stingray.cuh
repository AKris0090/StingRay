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

constexpr int   SCREEN_WIDTH    = 1500;
constexpr int   SCREEN_HEIGHT   = 750;
constexpr int   NUM_PIXELS      = SCREEN_WIDTH * SCREEN_HEIGHT;
constexpr int   NUM_BOUNCES     = 5;
constexpr float CAM_VFOV_DEG    = 90.0f;
constexpr float MOVE_SENS       = 0.05f;
constexpr float LOOK_SENS       = 0.1f;
constexpr int   PROGRESS_WIDTH  = 50;
constexpr int   NUM_SAMPLES     = 1000;

using namespace std;

using std::chrono::high_resolution_clock;
using std::chrono::duration_cast;
using std::chrono::duration;
using std::chrono::milliseconds;

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

DisplayWindow   window;
SDL_Event       event;

V3* totals = nullptr;
Uint8* devPixels = nullptr;
Uint8* copyTotals = nullptr;
std::vector<Uint32> pixels(NUM_PIXELS);

curandState* devStates;
Camera cam;
Scene h_scene;

GPUCam* d_cam = nullptr;
d_Scene* d_scene;