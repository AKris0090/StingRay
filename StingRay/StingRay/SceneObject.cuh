#pragma once

#include "PBRMat.cuh"

enum ObjectType { SPHERE, TRIANGLE };

struct SceneObject {
	ObjectType type;
	PBRMaterial* mat;
	int matIdx;
};

struct Sphere {
	SceneObject base;

	V3 origin = V3(0);
	float radius = -1;
	Sphere() { this->origin = V3(0, 0, 0); this->radius = 0.0f; base.mat = nullptr; };
	Sphere(V3 origin, float rad) { this->origin = origin; this->radius = rad; base.mat = nullptr; };
	Sphere(V3 origin, float rad, PBRMaterial* mat) { this->origin = origin; this->radius = rad; base.mat = mat; };


};

static __device__ Ray::hitReg intersectSphere(Ray& rayIn, const Sphere* s, float tMin, float tMax)  {
	Ray::hitReg hitOut{};
	V3 oc = rayIn.origin - s->origin;
	float a = rayIn.direction.dot(rayIn.direction);
	float b = oc.dot(rayIn.direction);
	float c = oc.dot(oc) - (s->radius * s->radius);
	float disc = b * b - a * c;
	float sqrt_disc = sqrtf(disc);
	if (disc > 0) {
		float temp_quad_f = (-b - sqrt_disc) / a;;
		if (temp_quad_f < tMax && temp_quad_f > tMin) {
			hitOut.time = temp_quad_f;
			hitOut.normal_vector = (rayIn.get_at(temp_quad_f) - s->origin) / s->radius;
			hitOut.hit = true;
			return hitOut;
		}
		temp_quad_f = (-b + sqrt_disc) / a;
		if (temp_quad_f < tMax && temp_quad_f > tMin) {
			hitOut.time = temp_quad_f;
			hitOut.normal_vector = (rayIn.get_at(temp_quad_f) - s->origin) / s->radius;
			hitOut.hit = true;
			return hitOut;
		}
	}
	return hitOut;
}

struct Triangle {
	SceneObject base;

	V3 v0, v1, v2;
	Triangle(V3 v1, V3 v2, V3 v3) { this->v0 = v1; this->v1 = v2; this->v2 = v3; base.mat = nullptr; };
};

static __device__ Ray::hitReg intersectTriangle(Ray& rayIn, const Triangle* t, float tMin, float tMax) {
	const float EPS = 1e-6f;

	Ray::hitReg hitOut{};
	V3 edge1 = t->v1 - t->v0;
	V3 edge2 = t->v2 - t->v0;
	V3 pvec = rayIn.direction.cross(edge2);
	float det = edge1.dot(pvec);
	if (fabsf(det) < EPS) return hitOut;
	float invDet = 1.0f / det;
	V3 tvec = rayIn.origin - t->v0;
	float u = tvec.dot(pvec) * invDet;
	if (u < 0.0f || u > 1.0f)
		return hitOut;
	V3 qvec = tvec.cross(edge1);
	float v = rayIn.direction.dot(qvec) * invDet;
	if (v < 0.0f || u + v > 1.0f)
		return hitOut;
	float time = edge2.dot(qvec) * invDet;
	if (time < tMin || time > tMax)
		return hitOut;
	hitOut.time = time;
	hitOut.hit = true;
	hitOut.normal_vector = edge1.cross(edge2).normalize();

	return hitOut;
}

static __device__ Ray::hitReg intersect(const SceneObject* obj, Ray& r, float tMin, float tMax) {
	switch (obj->type) {
	case SPHERE: {
		const Sphere* s = (const Sphere*)obj;
		return intersectSphere(r, s, tMin, tMax);
	}
	case TRIANGLE: {
		const Triangle* t = (const Triangle*)obj;
		return intersectTriangle(r, t, tMin, tMax);
	}
	}
	return Ray::hitReg{};
}