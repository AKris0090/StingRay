#pragma once
#include "Vector.cuh"

struct Ray {
public:
	struct hitReg {
		float time = 0;
		V3 normal_vector = V3(0);
		V3 hitPoint = V3(0);
		bool hit = false;
		int hitMaterialIdx;

		__device__ hitReg() {};
	};

	V3 origin;
	V3 direction;

	__device__ Ray() { };
	__device__ Ray(V3 origin, V3 direction) { this->origin = origin; this->direction = direction; };

	__device__ V3 get_at(float time) { return origin + (direction * time); }

	// perfect reflection
	__device__ V3 reflect(hitReg& hR) {
		V3 normal_dir = direction.normalize();
		V3 reflected = normal_dir - (hR.normal_vector * (2 * normal_dir.dot(hR.normal_vector)));
		return reflected.normalize();
	}
};