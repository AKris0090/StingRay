#include "Display.h"
#include <iostream>
#include <random>

#define SDL_MAIN_HANDLED

#define SCREEN_WIDTH 960
#define SCREEN_HEIGHT 540

#define max_num_threads std::thread::hardware_concurrency()

vector<int> width_iterator;
vector<int> height_iterator;

void DisplayWindow::initDisplay() {

    // Startup the video feed
    SDL_Init(SDL_INIT_VIDEO);

    // Create the SDL Window and open
    window = SDL_CreateWindow("StingRay", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, (SCREEN_WIDTH), (SCREEN_HEIGHT), 0);

    // Create the renderer for the window
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

    // Get surface off of the window
    surface = SDL_GetWindowSurface(window);

    cam_aspect_width = 16.0;
    cam_aspect_height = 9.0;

    this->bot_left = { -cam_aspect_width, -cam_aspect_height, -1 };
    this->horizontal = { cam_aspect_width * 2, 0, 0 };
    this->vertical = { 0, cam_aspect_height * 2, 0 };
    segment_width = (int)(SCREEN_WIDTH / std::thread::hardware_concurrency());

    for (int i = 0; i < SCREEN_WIDTH; i++) {
        width_iterator.emplace_back(i);
    }
    for (int i = 0; i < SCREEN_HEIGHT; i++) {
        height_iterator.emplace_back(i);
    }
}

void DisplayWindow::traceSegment(V3 cam_origin, float numSamples, V3 bot_left, V3 horizontal, V3 vertical, V3 center_one, float radius_one, Uint32 segment_width, int thread) {
    for (int i = (thread * segment_width); i < ((thread + 1) * segment_width); i++) {
        for (int j = 0; j < SCREEN_HEIGHT; j++) {
            V3 out_color(0, 0, 0);
            for (int k = 0; k < numSamples; k++) {
                float u = float(i + ((rand() / (RAND_MAX)))) / float(SCREEN_WIDTH);
                float v = float(j + ((rand() / (RAND_MAX)))) / float(SCREEN_HEIGHT);
                V3 alt_horiz = horizontal.mul_val(u);
                V3 alt_vert = vertical.mul_val(v);

                Ray primary_ray(cam_origin, bot_left.add(alt_horiz).add(alt_vert).sub(cam_origin));
                out_color = out_color.add(tracer.trace_ray(primary_ray, bot_left, center_one, radius_one));
                //out_color = tracer.trace_ray(primary_ray, bot_left, center_one, radius_one);
            }
            out_color = out_color.div_val(numSamples);
            pixels[i + (j * surface->w)] = SDL_MapRGB(surface->format, out_color.x, out_color.y, out_color.z);
        }
    }
}

void DisplayWindow::updateDisplay(V3 cam_origin, float numSamples) {
    std::vector<std::thread> workers;
    pixels = new Uint32[SCREEN_WIDTH * SCREEN_HEIGHT];
    texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STATIC, SCREEN_WIDTH, SCREEN_HEIGHT);

    std::for_each(std::execution::par, width_iterator.begin(), width_iterator.end(), [this](int i) {
        V3 cam_origin(0, 0, 1);
        float num_samples = 1;
        V3 center_one(0, 0, -1);
        float radius_one = 1.5;
        for_each(std::execution::par, height_iterator.begin(), height_iterator.end(), [this, i, cam_origin, num_samples, center_one, radius_one](int j) {
            V3 out_color(0, 0, 0);
        for (int k = 0; k < num_samples; k++) {
            float u = float(i + ((rand() / (RAND_MAX)))) / float(SCREEN_WIDTH);
            float v = float(j + ((rand() / (RAND_MAX)))) / float(SCREEN_HEIGHT);
            V3 alt_horiz = horizontal.mul_val(u);
            V3 alt_vert = vertical.mul_val(v);

            Ray primary_ray(cam_origin, bot_left.add(alt_horiz).add(alt_vert).sub(cam_origin));
            out_color = out_color.add(tracer.trace_ray(primary_ray, bot_left, center_one, radius_one));
            //out_color = tracer.trace_ray(primary_ray, bot_left, center_one, radius_one);
        }
        out_color = out_color.div_val(num_samples);
        pixels[i + (j * surface->w)] = SDL_MapRGB(surface->format, out_color.x, out_color.y, out_color.z);
            });
    });

    SDL_UpdateTexture(texture, NULL, pixels, SCREEN_WIDTH * sizeof(Uint32));
    SDL_RenderClear(renderer);
    SDL_RenderCopyEx(renderer, texture, NULL, NULL, 0, NULL, SDL_FLIP_VERTICAL);
    SDL_RenderPresent(renderer);

    workers.clear();
    workers.shrink_to_fit();
    delete[] pixels;
    SDL_DestroyTexture(texture);
}