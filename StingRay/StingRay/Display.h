#pragma once
#include "Tracer.h"
#include <SDL.h>
#include <execution>
#include <chrono>
#include "Sphere.h"
#include "PBRMat.h"
#include "Vector.h"
#include "Ray.h"

using namespace std;

class DisplayWindow {
public:
	Tracer tracer;
	int SCREEN_WIDTH = 0;
	int SCREEN_HEIGHT = 0;
	SDL_Window* window;
	SDL_Renderer* renderer;
	SDL_Texture* texture;
	SDL_Surface* surface;
	Uint32* pixels;
	V3* totals;
	AreaLight* a;
	AreaLight* b;

	Uint32 segment_width = 0;
	float cam_aspect_width = 0;
	float cam_aspect_height = 0;
	V3 bot_left;
	V3 horizontal;
	V3 vertical;
	V3 copied_origin;
	V3 center_one;
	float radius_one = 0;
	int repeat_samples = 0;

	void initDisplay(int screen_width, int screen_height);
	void updateDisplay(V3 cam_origin, float numSamples, int numBounces);
	vector<Sphere> objects;
	vector<AreaLight> lights;
	vector<int> width_iterator;
	vector<int> height_iterator;
};