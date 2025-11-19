#pragma once
#include <vector>
#include "AreaLight.cuh"
#include "device_launch_parameters.h"
#include "PBRMat.cuh"
#include "Scene.cuh"

using namespace std;

class Tracer {
public:
	Ray pRay;

	// Should return a color that corresponds to the traced ray
	__device__ static V3 calculate_shadow_ray(Ray shadowRay, Scene* objects, AreaLight& a, Ray::hitReg& primHit);
	__device__ static V3 trace_ray(const Ray& ray, Scene* scene, int max_bounces, curandState* localDevState);
};