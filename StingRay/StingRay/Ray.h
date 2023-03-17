#pragma once
#include "Vertex.h"

class Ray {
public:
	V3 origin;
	V3 direction;

	Ray() {};
	Ray(V3 origin, V3 direction) { this->origin = origin; this->direction = direction; };
	V3 get_at(float time) { return origin.add(direction.mul_val(time)); }
	bool intersect(V3 center, float radius);

	//bool intersection(V3 center, float radius);
};