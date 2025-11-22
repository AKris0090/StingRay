#pragma once

#include "Vector.cuh"
#include <float.h>

struct hitReg {
	V3 normal_vector = V3(0);
	V3 hitPoint = V3(0);
	bool hit = false;
	int hitMaterialIdx = -1;
	float time = FLT_MAX;
};

struct Ray {
	V3 origin;
	V3 direction;
	V3 invDirection;

	__device__ Ray() { };
	__device__ Ray(V3 origin, V3 direction) { this->origin = origin; this->direction = direction; this->invDirection = V3(1.0f / direction.x, 1.0f / direction.y, 1.0f / direction.z); };
	__device__ V3 get_at(float time) { return origin + (direction * time); }
};