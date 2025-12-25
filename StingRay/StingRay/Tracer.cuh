#pragma once
#include <vector>
#include "AreaLight.cuh"
#include "device_launch_parameters.h"
#include "PBRMat.cuh"
#include "Scene.cuh"

using namespace std;

constexpr int NUM_BOUNCES = 5;

class Tracer {
public:
	// Should return a color that corresponds to the traced ray
	__device__ static V3 calculate_shadow_ray(Ray& shadowRay, d_Scene* scenes, AreaLight& a, const hitReg& primHit);
	__device__ static V3 trace_ray(const Ray& ray, d_Scene* scenes, curandState* localDevState);
};