#pragma once
#include "Vector.cuh"

struct hitReg {
	bool hit = false;
	float time = 0;
	V3 normal_vector = V3(0);
	V3 hitPoint = V3(0);
};

struct Ray {
	V3 origin;
	V3 direction;
	bool isShadowRay = false;

	__device__ Ray() { };
	__device__ Ray(V3 origin, V3 direction) { this->origin = origin; this->direction = direction; };
	__device__ V3 get_at(float time) { return origin + (direction * time); }

	__device__ hitReg intersect(V3 center, float min_t, float max_t, float radius) {
		hitReg hit = { false, 0.0f, V3(), V3() };
		V3 oc = this->origin - center;
		float a = this->direction.dot(this->direction);
		float b = oc.dot(this->direction);
		float c = oc.dot(oc) - (radius * radius);
		float disc = b * b - a * c;
		float sqrt_disc = sqrtf(disc);
		if (disc > 0) {
			float temp_quad_f = (-b - sqrt_disc) / a;;
			if (temp_quad_f < max_t && temp_quad_f > min_t) {
				hit.time = temp_quad_f;
				hit.hit = true;
				hit.normal_vector = (this->get_at(temp_quad_f) - center) / radius;
				return hit;
			}
			temp_quad_f = (-b + sqrt_disc) / a;
			if (temp_quad_f < max_t && temp_quad_f > min_t) {
				hit.time = temp_quad_f;
				hit.hit = true;
				hit.normal_vector = (this->get_at(temp_quad_f) - center) / radius;
				return hit;
			}
		}
		return hit;
	}
};