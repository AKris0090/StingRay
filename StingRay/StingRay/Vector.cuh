#pragma once
#include <math.h>
#include <cstdio>
#include "device_launch_parameters.h"

struct V3 {
	float x, y, z;

	__host__ __device__ V3() noexcept : x(0.0), y(0.0), z(0.0) {}
	__host__ __device__ V3(float a, float b, float c) noexcept : x(a), y(b), z(c) {};
	__host__ __device__ V3(float num) noexcept : x(num), y(num), z(num) {};

	__host__ __device__ V3 operator+(const V3& other) const noexcept {
		return V3{ x + other.x, y + other.y, z + other.z };
	}

	__host__ __device__ V3& operator+=(const V3& other) noexcept {
		x += other.x; y += other.y; z += other.z;
		return *this;
	}

	__host__ __device__ V3 operator-(const V3& other) const noexcept {
		return V3{ x - other.x, y - other.y, z - other.z };
	}

	__host__ __device__ V3 operator-() const noexcept {
		return V3{ -x, -y, -z };
	}

	__host__ __device__ V3& operator-=(const V3& other) noexcept {
		x -= other.x; y -= other.y; z -= other.z;
		return *this;
	}

	__host__ __device__ V3 operator*(const V3& other) const noexcept {
		return V3{ x * other.x, y * other.y, z * other.z };
	}

	__host__ __device__ V3& operator*=(const V3& other) noexcept {
		x *= other.x; y *= other.y; z *= other.z;
		return *this;
	}

	__host__ __device__ V3 operator/(const V3& other) const noexcept {
		if (other.x == 0.0 || other.y == 0.0 || other.z == 0.0) {
			printf("ERROR: Division by 0 vector");
			return V3(0.0);
		}
		return V3{ x / other.x, y / other.y, z / other.z };
	}

	__host__ __device__ V3& operator/=(const float o) noexcept {
		if (o == 0.0) {
			printf("ERROR: Division by 0 vector");
			return *this;
		}
		x /= o; y /= o; z /= o;
		return *this;
	}

	__host__ __device__ V3 operator+(float o) const noexcept {
		return V3{ x + o, y + o, z + o };
	}

	__host__ __device__ V3 operator-(float o) const noexcept {
		return V3{ x - o, y - o, z - o };
	}

	__host__ __device__ V3 operator*(float o) const noexcept {
		return V3{ x * o, y * o, z * o };
	}

	__host__ __device__ V3 operator/(float o) const noexcept{
		if (o == 0.0) {
			printf("ERROR: Division by 0 value");
			return V3(0.0);
		}
		return V3{ x / o, y / o, z / o };
	}

	__host__ __device__ float distance_to(V3 other) const noexcept {
		float squared_val_x = (other.x - x) * (other.x - x);
		float squared_val_y = (other.y - y) * (other.y - y);
		float squared_val_z = (other.z - z) * (other.z - z);
		return squared_val_x + squared_val_y + squared_val_z;
	};

	__host__ __device__ float squared_length() const noexcept {
		return x * x + y * y + z * z;
	}

	__host__ __device__ float length() const noexcept {
		return sqrt(x * x + y * y + z * z);
	}

	__host__ __device__ V3 normalize() const noexcept {
		float l = length();
		return l > 0 ? (*this) / l : V3(0.0);
	}

	__host__ __device__ V3 cross(const V3 other) const noexcept {
		return V3((this->y * other.z - this->z * other.y),
			(-(this->x * other.z - this->z * other.x)),
			(this->x * other.y - this->y * other.x));
	}

	__host__ __device__ float dot(const V3 other) const noexcept {
		return x * other.x + y * other.y + z * other.z;
	};
};