#pragma once
#include <random>
#include "Vector.cuh"
#include "Ray.cuh"
#include <curand.h>
#include <curand_kernel.h>

class PBRMaterial {
public:
	V3 base_color;
	float specular;
	float roughness;
	float IOR;
	float transmission;
	float emission_strength;
	curandState* globalState;


	__device__ PBRMaterial() { base_color = V3(0, 0, 0); transmission = 0.0f; specular = roughness = 0.5f; emission_strength = 1.0f; IOR = 1.45f; }
	__device__ PBRMaterial(V3 color = V3(0, 0, 0), float spec = 0.0f, float rough = 0.0f , float index_ref=0.0f, float trans = 0.0f, float emi = 0.0f) { base_color = color; transmission = trans; specular = spec; roughness = rough; emission_strength = emi; IOR = index_ref; }
	

	__device__ V3 random_direction_in_n(float radius, curandState* localDevState);
	__device__ V3 random_direction(curandState* localDevState);
	__device__ V3 random_scatter(Ray& in_dir, hitReg& hR, curandState* localDevState);
	__device__ V3 reflect(Ray& in_dir, hitReg& hR);
	__device__ V3 hitColor(Ray& in_ray, hitReg& hR, Ray& out_ray, curandState* localDevState);
};