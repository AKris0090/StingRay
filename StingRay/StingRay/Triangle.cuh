#pragma once
#include "PBRMat.cuh"

class Triangle {
public:
	V3 v1;
	V3 v2;
	V3 v3;
	V3 normal;
	PBRMaterial* mat = nullptr;

	__device__ Triangle(V3 v1, V3 v2, V3 v3, PBRMaterial* mat) { this->v1 = v1; this->v2 = v2; this->v3 = v3; this->mat = mat; };
};