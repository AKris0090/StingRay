#include "Display.h"
#include "SDL.h"
#include <chrono>
#include <iostream>

unsigned int threadsMax = std::thread::hardware_concurrency();

using namespace std;

DisplayWindow window;

int main(int argc, char** arcgv) {

    window.initDisplay();

    bool running = true;
    SDL_Event event;
    V3 cam_origin(0, 0, 1);
    float numSamples = 1;

    using std::chrono::high_resolution_clock;
    using std::chrono::duration_cast;
    using std::chrono::duration;
    using std::chrono::milliseconds;

    cout << threadsMax << " threads found" << endl;

    while (SDL_PollEvent(&event) || running) {
        cout << "\r";

        auto t1 = high_resolution_clock::now();
        window.updateDisplay(cam_origin, numSamples);
        auto t2 = high_resolution_clock::now();

        /* Getting number of milliseconds as an integer. */
        auto ms_int = duration_cast<milliseconds>(t2 - t1);

        /* Getting number of milliseconds as a double. */
        duration<double, std::milli> ms_double = t2 - t1;

        cout << ms_double.count() << "ms";

        switch (event.type) {
        case SDL_QUIT:
            running = false;
            break;
        case SDL_KEYDOWN:
            if (event.key.keysym.sym == SDLK_a) {
                cam_origin.x -= 1;
            }
            else if (event.key.keysym.sym == SDLK_d) {
                cam_origin.x += 1;
            }
            else if (event.key.keysym.sym == SDLK_s) {
                cam_origin.y -= 1;
            }
            else if (event.key.keysym.sym == SDLK_w) {
                cam_origin.y += 1;
            }
            else if (event.key.keysym.sym == SDLK_z) {
                numSamples -= 10;
            }
            else if (event.key.keysym.sym == SDLK_x) {
                numSamples += 10;
            }
        default:
            break;
        }
    }
    SDL_DestroyRenderer(window.renderer);
    SDL_DestroyWindow(window.window);

    return 0;
}