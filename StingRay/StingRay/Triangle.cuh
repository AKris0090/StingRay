#pragma once
#include "PBRMat.cuh"

//class Triangle {
//public:
//	V3 v1;
//	V3 v2;
//	V3 v3;
//	PBRMaterial* mat = nullptr;
//
//	__device__ Triangle(V3 v1, V3 v2, V3 v3, PBRMaterial* mat) { this->v1 = v1; this->v2 = v2; this->v3 = v3; this->mat = mat; };
//	__device__ Ray::hitReg hit(Ray& rayIn, float tMin, float tMax) const {
//		Ray::hitReg hitOut{};
//		
//		const float EPS = 1e-6f;
//
//		V3 edge1 = v2 - v1;
//		V3 edge2 = v3 - v1;
//		V3 pvec = rayIn.direction.cross(edge2);
//		float det = edge1.dot(pvec);
//		if (fabsf(det) < EPS) return hitOut;
//		float invDet = 1.0f / det;
//		V3 tvec = rayIn.origin - v1;
//		float u = tvec.dot(pvec) * invDet;
//		if (u < 0.0f || u > 1.0f)
//			return hitOut;
//		V3 qvec = tvec.cross(edge1);
//		float v = rayIn.direction.dot(qvec) * invDet;
//		if (v < 0.0f || u + v > 1.0f)
//			return hitOut;
//		float t = edge2.dot(qvec) * invDet;
//		if (t < tMin || t > tMax)
//			return hitOut;
//		hitOut.time = t;
//		hitOut.hit = true;
//		hitOut.normal_vector = edge1.cross(edge2).normalize();
//
//		return hitOut;
//	}
//};