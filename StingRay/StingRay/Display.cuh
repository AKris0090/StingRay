#pragma once
#include "Tracer.cuh"
#include <SDL.h>
#include <chrono>
#include "PBRMat.cuh"
#include "Vector.cuh"
#include "Ray.cuh"
#include "cuda.h"
#include "cuda_runtime.h"
#include "Sphere.cuh"
#include <iostream>

using namespace std;

class DisplayWindow {
public:
	int SCREEN_WIDTH = 0;
	int SCREEN_HEIGHT = 0;
	SDL_Window* window;
	SDL_Renderer* renderer;
	SDL_Texture* texture;
	SDL_Surface* surface;
	V3* totals;
	Uint8* devPixels;

	V3 bot_left;
	V3 horizontal;
	V3 vertical;
	V3 copied_origin;
	V3 center_one;
	int repeat_samples = 0;

	void initDisplay(int screen_width, int screen_height);
	PBRMaterial** mats;
	Sphere** objects;
	AreaLight** lights;
};