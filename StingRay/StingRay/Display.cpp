#include "Display.h"
#include <iostream>
#include <random>

#define SDL_MAIN_HANDLED

#define max_num_threads std::thread::hardware_concurrency()

void DisplayWindow::initDisplay(int screen_width, int screen_height) {
    cout << ",d88~~\\ ~~~888~~~ 888 888b    |  e88~~\\  888~-_        e      Y88b    / " << endl;
    cout << "8888       888    888 |Y88b   | d888     888   \\      d8b      Y88b  /  " << endl;
    cout << "`Y88b      888    888 | Y88b  | 8888 __  888    |    /Y88b      Y88b/  " << endl;
    cout << " `Y88b,    888    888 |  Y88b | 8888   | 888   /    /  Y88b      Y8Y  " << endl;
    cout << "   8888    888    888 |   Y88b| Y888   | 888_-~    /____Y88b      Y   " << endl;
    cout << "\\__88P'    888    888 |    Y888  \"88__ / 888 ~- _ /      Y88b    /    " << endl;
    cout << "v 1.0.0 -------------------------------------------------------------   " << endl;
    cout << "--------------------------------------------------------------------- " << endl;

    // Startup the video feed
    SDL_Init(SDL_INIT_VIDEO);

    // Create the SDL Window and open
    window = SDL_CreateWindow("StingRay", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, (screen_width), (screen_height), 0);

    this->SCREEN_HEIGHT = screen_height;
    this->SCREEN_WIDTH = screen_width;

    // Create the renderer for the window
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

    // Get surface off of the window
    surface = SDL_GetWindowSurface(window);

    cam_aspect_width = 3.0;
    cam_aspect_height = 1.5;


    this->bot_left = { -cam_aspect_width, -cam_aspect_height, -1 };
    this->horizontal = { cam_aspect_width * 2, 0, 0 };
    this->vertical = { 0, cam_aspect_height * 2, 0 };

    for (int i = 0; i < SCREEN_WIDTH; i++) {
        width_iterator.emplace_back(i);
    }
    for (int i = 0; i < SCREEN_HEIGHT; i++) {
        height_iterator.emplace_back(i);
    }

    center_one = { 0, 0, -1 };
    radius_one = 1.5;

    PBRMaterial metal(V3(204.0f, 204.0f, 204.0f), 0.0, 0.05, 0.0, 0.0, 0.0);
    PBRMaterial metal2(V3(204.0f, 204.0f, 204.0f), 0.0, 0.25, 0.0, 0.0, 0.0);
    PBRMaterial red(V3(255.0f, 0.0f, 0.0f), 0.0, 1.0, 0.0, 0.0, 0.0);
    PBRMaterial blue(V3(0.0f, 0.0f, 255.0f), 0.0, 1.0, 0.0, 0.0, 0.0);

    a = new AreaLight(Sphere(V3(0.0f, 2.0f, 1.0f), 0.25), 1500.0f);
    b = new AreaLight(Sphere(V3(0.0f, 2.0f, -1.0f), 0.25), 1500.0f);
    lights.push_back(*a);
    lights.push_back(*b);

    objects.push_back(Sphere(V3(0, 0, -1), 0.5, blue));
    objects.push_back(Sphere(V3(0, -100.5, -1), 100, red));
    objects.push_back(Sphere(V3(1, 0, -1), 0.5, metal));
    objects.push_back(Sphere(V3(-1, 0, -1), 0.5, metal2));
    totals = new V3[SCREEN_WIDTH * SCREEN_HEIGHT];
}

void DisplayWindow::updateDisplay(const V3 cam_origin, float numSamples, const int numBounces) {
    tracer = Tracer(numBounces);
    if (repeat_samples < numSamples) {
        pixels = new Uint32[SCREEN_WIDTH * SCREEN_HEIGHT];
        texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, SCREEN_WIDTH, SCREEN_HEIGHT);
        repeat_samples += 1;

        std::for_each(std::execution::par, width_iterator.begin(), width_iterator.end(), [this, cam_origin](int i) {
            std::for_each(std::execution::par, height_iterator.begin(), height_iterator.end(), [this, i, cam_origin](int j) {
                V3 u = horizontal.mul_val((float) ((i + ((rand() / (float) RAND_MAX))) / SCREEN_WIDTH));
                V3 v = vertical.mul_val((float) ((j + ((rand() / (float) RAND_MAX))) / SCREEN_HEIGHT));

                Ray primary_ray(copied_origin, bot_left.add(u).add(v).sub(cam_origin));
                V3 ret_color = tracer.trace_ray(primary_ray, objects, 0, lights);
                int index = i + (j * SCREEN_WIDTH);

                totals[index].x += (long) clamp(ret_color.x, 0.0f, 255.0f);
                totals[index].y += (long) clamp(ret_color.y, 0.0f, 255.0f);
                totals[index].z += (long) clamp(ret_color.z, 0.0f, 255.0f);
                pixels[index] = SDL_MapRGB(surface->format, (Uint8) (totals[index].x / repeat_samples), (Uint8) (totals[index].y / repeat_samples), (Uint8) (totals[index].z / repeat_samples));
            });
        });

        SDL_UpdateTexture(texture, NULL, pixels, SCREEN_WIDTH * sizeof(Uint32));
        SDL_RenderClear(renderer);
        SDL_RenderCopyEx(renderer, texture, NULL, NULL, 0, NULL, SDL_FLIP_VERTICAL);
        SDL_DestroyTexture(texture);
        delete[] pixels;
    }
    SDL_RenderPresent(renderer);
}