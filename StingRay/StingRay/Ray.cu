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

//__device__ hitReg Ray::intersect(V3 v1, V3 v2, V3 v3, V3 normal, float min_t, float max_t) {
//	hitReg h;
//
//	float ndotDir = normal.dot(this->direction);
//	if (abs(ndotDir) < 0.000000001f) {
//		return h;
//	}
//
//	float d = normal.mul_val(-1.0).dot(v1);
//
//	h.time = -(normal.dot(this->origin) + d) / ndotDir;
//
//	if (t < 0) {
//		return h;
//	}
//
//	h.hitPoint = this->origin.add(this->direction.mul_val(t));
//
//	V3 C;
//
//	V3 edge1 = v2.sub(v1);
//	V3 vp0 = h.hitPoint.sub(v1);
//	C = edge1.cross(vp0);
//	if (normal.dot(C) < 0) {
//		return h;
//	}
//
//	V3 edge2 = v2.sub(v2);
//	V3 vp1 = h.hitPoint.sub(v2);
//	C = edge2.cross(vp1);
//	if (normal.dot(C) < 0) {
//		return h;
//	}
//
//	V3 edge3 = v1.sub(v3);
//	V3 vp2 = h.hitPoint.sub(v3);
//	C = edge3.cross(vp2);
//	if (normal.dot(C) < 0) {
//		return h;
//	}
//
//	h.hit = true;
//	h.normal_vector = normal;
//	
//	return h;
//}

__device__ Ray Ray::copy() {
	return Ray(this->origin, this->direction);
}