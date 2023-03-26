#pragma once
#include <vector>
#include "PBRMat.h"
#include "Sphere.h"

using namespace std;

class Tracer {
public:
	Ray pRay;
	int max_bounces = 0;
	Tracer() {};
	Tracer(int bounces) {
		this->max_bounces = bounces;
	};
	// Should return a color that corresponds to the traced ray
	V3 trace_ray(Ray& primaryRay, std::vector<Sphere>, int numBounces);
};