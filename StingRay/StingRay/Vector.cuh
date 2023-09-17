#pragma once
#include <math.h>
#include "device_launch_parameters.h"

class V3 {

public:
	float x;
	float y;
	float z;
	float w;

	__host__ __device__ V3() { V3(0.0, 0.0, 0.0); };
	__host__ __device__ V3(float x, float y, float z, float w) { this->x = x; this->y = y; this->z = z; this->w = w; }
	__host__ __device__ V3(float x, float y, float z) { this->x = x; this->y = y; this->z = z; this->w = 0.0F; }
	__host__ __device__ V3(float num) { this->x = num; this->y = num; this->z = num; this->w = 0.0F; }
	__host__ 
	__host__ __device__ V3 add(const V3 other);
	__host__ __device__ V3 sub(const V3 other);
	__host__ __device__ V3 mul(const V3 other);
	__host__ __device__ V3 div(const V3 other);
	__host__ __device__ V3 add_val(float val);
	__host__ __device__ V3 sub_val(float val);
	__host__ __device__ V3 mul_val(float val);
	__host__ __device__ V3 div_val(float val);
	__host__ __device__ V3 copy();
	__host__ __device__ void reset();
	__host__ 
	__host__ __device__ float distance_to(V3 other);
	__host__ __device__ float length();
	__host__ __device__ float squared_length();
	__host__ 
	__host__ __device__ V3 normalize();
	__host__ __device__ V3 cross(const V3 other);
	__host__ __device__ float dot(const V3 other);
};