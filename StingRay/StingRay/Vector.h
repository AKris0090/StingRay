#pragma once
#include <math.h>

class V3 {

public:
	float x;
	float y;
	float z;
	float w;

	V3() { V3(0.0, 0.0, 0.0); };
	V3(float x, float y, float z, float w) { this->x = x; this->y = y; this->z = z; this->w = w; }
	V3(float x, float y, float z) { this->x = x; this->y = y; this->z = z; this->w = 0.0F; }
	V3(float num) { this->x = num; this->y = num; this->z = num; this->w = 0.0F; }

	V3 add(const V3& other);
	V3 sub(const V3& other);
	V3 mul(const V3& other);
	V3 div(const V3& other);
	V3 add_val(float val);
	V3 sub_val(float val);
	V3 mul_val(float val);
	V3 div_val(float val);
	V3 copy();
	void reset();

	double length();
	float squared_length();

	V3 normalize();
	V3 cross(const V3& other);
	float dot(const V3& other);
};