#pragma once
#include "Vector.h"

struct hitReg {
	bool hit;
	float time;
	V3 normal_vector;
};

class Ray {
public:
	V3 origin;
	V3 direction;
	bool isShadowRay = false;

	Ray() { a = b = c = disc = temp_quad_f = 0.0;  };
	Ray(V3 origin, V3 direction) { this->origin = origin; this->direction = direction; a = b = c = disc = temp_quad_f = 0.0; };
	V3 get_at(float time) { return origin.add(direction.mul_val(time)); }

	hitReg hit;
	V3 oc;
	float a = 0.0;
	float b;
	float c;
	float disc;
	float temp_quad_f = 0;
	hitReg intersect(V3 center, float min_t, float max_t, float radius);

	Ray copy();
};