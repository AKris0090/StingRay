#pragma once
#include "Vector.cuh"

struct hitReg {
	bool hit = false;
	float time = -1;
	V3 normal_vector = V3(-1);
	V3 hitPoint = V3(0);
};

class Ray {
public:
	V3 origin;
	V3 direction;
	bool isShadowRay = false;

	__device__ Ray() { a = b = c = disc = temp_quad_f = 0.0;  };
	__device__ Ray(V3 origin, V3 direction) { this->origin = origin; this->direction = direction; a = b = c = disc = temp_quad_f = 0.0; };
	__device__ V3 get_at(float time) { return origin.add(direction.mul_val(time)); }

	hitReg hit;
	V3 oc;
	float a = 0.0;
	float b;
	float c;
	float disc;
	float temp_quad_f = 0;
	__device__ hitReg intersect(V3 center, float min_t, float max_t, float radius);

	__device__ Ray copy();
};