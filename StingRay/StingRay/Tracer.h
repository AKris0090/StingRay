#pragma once
#include <vector>
#include "PBRMat.h"
#include "Sphere.h"
#include "AreaLight.h"

using namespace std;

class Tracer {
public:
	Ray pRay;
	int max_bounces = 0;
	V3 out_true_color;

	Tracer() {};
	Tracer(int bounces) {
		this->max_bounces = bounces;
	};
	// Should return a color that corresponds to the traced ray
	V3 get_light_intensity(Ray& in, std::vector<Sphere> objects, V3 hitcolor, AreaLight a, hitReg primHit, PBRMaterial mat);
	V3 trace_ray(Ray& primaryRay, std::vector<Sphere>, int numBounces, std::vector<AreaLight> lights);
};