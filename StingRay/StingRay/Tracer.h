#pragma once
#include "Ray.h"

class Tracer {
public:
	// Should return a color that corresponds to the traced ray
	V3 trace_ray(Ray& primaryRay, V3 prims, V3 center, float radius);
};