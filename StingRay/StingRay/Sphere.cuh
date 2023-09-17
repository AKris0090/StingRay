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
};