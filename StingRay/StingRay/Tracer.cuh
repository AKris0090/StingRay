#pragma once
#include <vector>
#include "PBRMat.cuh"
#include "Sphere.cuh"
#include "AreaLight.cuh"
#include "device_launch_parameters.h"

using namespace std;

class Tracer {
public:
	Ray pRay;

	// Should return a color that corresponds to the traced ray
	__device__ static V3 get_light_intensity(Ray in, Ray secondary, Sphere** objects, V3 hitcolor, AreaLight a, hitReg primHit, PBRMaterial* mat, int numObjects);
	__device__ static V3 trace_ray(const Ray& ray, Sphere** objects, AreaLight** lights, int max_bounces, int numObjects, int numLights, curandState* localDevState);
};