#include "Tracer.h"

V3 Tracer::trace_ray(Ray& primaryRay, V3 prims, V3 center, float radius) {
	if (primaryRay.intersect(center, radius)) {
		return V3(255, 0, 0);
	}
	else {
		return V3(0, 0, 0, 0);
	}
}