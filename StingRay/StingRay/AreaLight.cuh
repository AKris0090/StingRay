#pragma once
#include "Vector.cuh"
#include "Sphere.cuh"

class AreaLight {
public:
	Sphere pos;
	V3 color;
	float intensity;

	__device__ AreaLight() { this->pos = Sphere(0, 0, 0); this->color = V3(0, 0, 0); this->intensity = 1.0f; };
	__device__ AreaLight(Sphere origin, float in) { this->pos = origin; this->intensity = in; this->color = V3(1, 1, 1); };
	__device__ AreaLight(Sphere origin, float in, V3 color) { this->pos = origin; this->intensity = in; this->color = color; };

	__device__ float get_intensity(float squared_distance) {
		return (1 / (squared_distance)) * this->intensity;
	};
};