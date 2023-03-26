#include "Display.h"
#include "SDL.h"
#include "Vector.h"
#include <chrono>
#include <iostream>

unsigned int threadsMax = std::thread::hardware_concurrency();

using namespace std;

DisplayWindow window;

#define SCREEN_WIDTH 1200
#define SCREEN_HEIGHT 600
#define NUMBOUNCES 3

void reclearFrame() {
    delete[] window.totals;
    window.totals = new V3[SCREEN_WIDTH * SCREEN_HEIGHT];
    window.repeat_samples = 0;
}

int main(int argc, char** arcgv) {

    window.initDisplay(SCREEN_WIDTH, SCREEN_HEIGHT);

    bool running = true;
    SDL_Event event;
    V3 cam_origin(0.0f, 0.0f, 1.0f);
    float numSamples = 500.0f;

    using std::chrono::high_resolution_clock;
    using std::chrono::duration_cast;
    using std::chrono::duration;
    using std::chrono::milliseconds;

    cout << threadsMax << " threads found" << endl;

    while (SDL_PollEvent(&event) || running) {
        cout << "\r";

        auto t1 = high_resolution_clock::now();
        window.updateDisplay(cam_origin, numSamples, NUMBOUNCES);
        auto t2 = high_resolution_clock::now();

        /* Getting number of milliseconds as an integer. */
        auto ms_int = duration_cast<milliseconds>(t2 - t1);

        /* Getting number of milliseconds as a double. */
        duration<double, std::milli> ms_double = t2 - t1;

        cout << window.repeat_samples << "/" << numSamples << " samples " << ms_double.count() << " ms";

        switch (event.type) {
        case SDL_QUIT:
            running = false;
            break;
        case SDL_KEYDOWN:
            if (event.key.keysym.sym == SDLK_a) {
                cam_origin.x -= 0.5;
                reclearFrame();
            }
            else if (event.key.keysym.sym == SDLK_d) {
                cam_origin.x += 0.5;
                reclearFrame();
            }
            else if (event.key.keysym.sym == SDLK_s) {
                cam_origin.y -= 0.25;
                reclearFrame();
            }
            else if (event.key.keysym.sym == SDLK_w) {
                cam_origin.y += 0.25;
                reclearFrame();
            }
            else if (event.key.keysym.sym == SDLK_q) {
                reclearFrame();
            }
            [[fallthrough]];
        default:
            break;
        }
    }

    SDL_DestroyRenderer(window.renderer);
    SDL_DestroyWindow(window.window);
    delete[] window.pixels;
    delete[] window.totals;

    window.objects.clear();
    window.width_iterator.clear();
    window.height_iterator.clear();

    window.objects.shrink_to_fit();
    window.width_iterator.shrink_to_fit();
    window.height_iterator.shrink_to_fit();

    return 0;
}