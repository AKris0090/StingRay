#pragma once

#include <random>
#include "Vector.cuh"
#include "Ray.cuh"

struct PBRMaterial {
	V3 base_color;
	float metallic;
	float roughness;


	PBRMaterial() { base_color = V3(0, 0, 0); metallic = roughness = 0.5f;}
	PBRMaterial(V3 color = V3(0, 0, 0), float met = 0.0f, float rough = 0.0f , float index_ref=0.0f, float trans = 0.0f, float emi = 0.0f) { base_color = color; metallic = met; roughness = rough; }
	

	__device__ V3 random_in_hemisphere(const V3& normal, curandState* localDevState);
	__device__ V3 hitColor(Ray& in_ray, hitReg& hR, Ray& out_ray, curandState* localDevState);
};