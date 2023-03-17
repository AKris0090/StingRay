#pragma once
#include "SDL.h"
#include "tracer.h"
#include <thread>

class DisplayWindow {
public:
	SDL_Window* window;
	SDL_Renderer* renderer;
	SDL_Texture* texture;
	SDL_Surface* surface;
	Tracer tracer;
	Uint32* pixels;

	Uint32 segment_width = 0;
	float cam_aspect_width = 0;
	float cam_aspect_height = 0;
	V3 bot_left;
	V3 horizontal;
	V3 vertical;


	void traceSegment(V3 cam_origin, float numSamples, V3 bot_left, V3 horizontal, V3 vertical, V3 center_one, float radius_one, Uint32 segment_width, int thread);
	void initDisplay();
	void updateDisplay(V3 cam_origin, float numSamples);
};