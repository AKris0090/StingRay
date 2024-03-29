#include "Vertex.h"

V3 V3::add(const V3& other) {
	return V3(this->x + other.x, this->y + other.y, this->z + other.z, this->w + other.w);
}

V3 V3::sub(const V3& other) {
	return V3(this->x - other.x, this->y - other.y, this->z - other.z, this->w - other.w);
}

V3 V3::mul(const V3& other) {
	return V3(this->x * other.x, this->y * other.y, this->z * other.z, this->w * other.w);
}

V3 V3::div(const V3& other) {
	if (other.w == 0) {
		return V3(this->x + other.x, this->y + other.y, this->z + other.z, this->w / 1);
	}
	else {
		return V3(this->x + other.x, this->y + other.y, this->z + other.z, this->w + other.w);
	}
}

V3 V3::add_val(float val) {
	return V3(this->x + val, this->y + val, this->z + val, this->w);
}

V3 V3::sub_val(float val) {
	return V3(this->x - val, this->y - val, this->z - val, this->w);
}

V3 V3::mul_val(float val) {
	return V3(this->x * val, this->y * val, this->z * val, this->w);
}

V3 V3::div_val(float val) {
	return V3(this->x / val, this->y / val, this->z / val, this->w);
}

float V3::length() {
	return sqrt(squared_length());
}

float V3::squared_length() {
	return this->x * this->x + this->y * this->y + this->z * this->z;
}

V3 V3::normalize() {
	return this->div_val(this->length());
}

float V3::dot(const V3& other) {
	return ((this->x * other.x) + (this->y * other.y) + (this->z * other.z));
}

V3 V3::cross(const V3& other) {
	return V3((this->y * other.z - this->z * other.y),
		(-(this->x * other.z - this->z * other.x)),
		(this->x * other.y - this->y * other.x));
}