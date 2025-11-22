#pragma once

#include <SDL.h>
#include <chrono>
#include "cuda.h"
#include "cuda_runtime.h"
#include "Scene.cuh"
#include <iostream>

using namespace std;

class DisplayWindow {
public:
	SDL_Window* window		= nullptr;
	SDL_Renderer* renderer	= nullptr;
	SDL_Texture* texture	= nullptr;
	SDL_Surface* surface	= nullptr;
	int repeat_samples		= 0;
	float lastFrameTime		= 0.0f;
	bool running			= true;

	void initDisplay(int screen_width, int screen_height);
};

// Clamping the color traced
static __device__ float clampRGB(float in) {
	if (in < 0.0f) {
		return 0.0f;
	}
	else if (in > 1) {
		return 1.0f;
	}
	else {
		return in;
	}
}