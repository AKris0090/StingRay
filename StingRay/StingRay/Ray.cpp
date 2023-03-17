#include "Ray.h"
#include <iostream>

bool Ray::intersect(V3 center, float radius) {
	V3 oc = this->origin.sub(center);
	float a = this->direction.dot(this->direction);
	float b = oc.dot(this->direction);
	float c = oc.dot(oc) - (radius * radius);
	float disc = b * b - a * c;
	return disc > 0;
}