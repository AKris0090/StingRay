#pragma once

#include "Vector.cuh"

struct AreaLight {
	V3 pos;
	float radius;
	V3 color;
	float intensity;

	AreaLight() { this->pos = V3(0, 0, 0); this->color = V3(0, 0, 0); this->intensity = 1.0f; };
	AreaLight(V3 origin, float radius, float in) { this->pos = origin; this->intensity = in; this->color = V3(1, 1, 1); };
	AreaLight(V3 origin, float radius, float in, V3 color) { this->pos = origin; this->intensity = in; this->color = color; };

	__device__ float get_intensity(float squared_distance) {
		return (1 / (squared_distance)) * this->intensity;
	};
};