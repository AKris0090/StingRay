#include "Ray.cuh"
#include <iostream>

__device__ hitReg Ray::intersect(V3 center, float min_t, float max_t, float radius) {
	hit = { false, 0.0f, V3(0.0f, 0.0f, 0.0f), V3(0.0f, 0.0f, 0.0f) };
	oc = this->origin.sub(center);
	a = this->direction.dot(this->direction);
	b = oc.dot(this->direction);
	c = oc.dot(oc) - (radius * radius);
	disc = b * b - a * c;
	if (disc > 0) {
		temp_quad_f = ((0 - b) - sqrt(b * b - a * c)) / a;
		if (temp_quad_f < max_t && temp_quad_f > min_t) {
			hit.time = temp_quad_f;
			hit.hit = true;
			hit.normal_vector = this->get_at(temp_quad_f).sub(center).div_val(radius);
			return hit;
		}
		temp_quad_f = ((0 - b) + sqrt(b * b - a * c)) / a;
		if (temp_quad_f < max_t && temp_quad_f > min_t) {
			hit.time = temp_quad_f;
			hit.hit = true;
			hit.normal_vector = this->get_at(temp_quad_f).sub(center).div_val(radius);
			return hit;
		}
	}
	return hit;
}

__device__ Ray Ray::copy() {
	return Ray(this->origin, this->direction);
}