#pragma once

#include "PBRMat.cuh"

class Sphere {
public:
	V3 origin = V3(0);
	float radius = -1;
	PBRMaterial* mat = nullptr;

	__device__ Sphere() { this->origin = V3(0, 0, 0); this->radius = 0.0f; this->mat = nullptr; };
	__device__ Sphere(V3 origin, float rad) { this->origin = origin; this->radius = rad; this->mat = nullptr; };
	__device__ Sphere(V3 origin, float rad, PBRMaterial* mat) { this->origin = origin; this->radius = rad; this->mat = mat; };

	__device__ Ray::hitReg hit(Ray& rayIn, float tMin, float tMax) const {
		Ray::hitReg hitOut{};
		V3 oc = rayIn.origin - origin;
		float a = rayIn.direction.dot(rayIn.direction);
		float b = oc.dot(rayIn.direction);
		float c = oc.dot(oc) - (radius * radius);
		float disc = b * b - a * c;
		float sqrt_disc = sqrtf(disc);
		if (disc > 0) {
			float temp_quad_f = (-b - sqrt_disc) / a;;
			if (temp_quad_f < tMax && temp_quad_f > tMin) {
				hitOut.time = temp_quad_f;
				hitOut.normal_vector = (rayIn.get_at(temp_quad_f) - origin) / radius;
				hitOut.hit = true;
				return hitOut;
			}
			temp_quad_f = (-b + sqrt_disc) / a;
			if (temp_quad_f < tMax && temp_quad_f > tMin) {
				hitOut.time = temp_quad_f;
				hitOut.normal_vector = (rayIn.get_at(temp_quad_f) - origin) / radius;
				hitOut.hit = true;
				return hitOut;
			}
		}
		return hitOut;
	}
};