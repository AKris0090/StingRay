#pragma once
#include "Vector.h"
#include "Sphere.h"

class AreaLight {
public:
	Sphere pos;
	V3 color;
	float intensity;

	AreaLight(Sphere origin, float in) { this->pos = origin; this->intensity = in; this->color = V3(1, 1, 1); };
	AreaLight(Sphere origin, float in, V3 color) { this->pos = origin; this->intensity = in; this->color = color; };

	float get_intensity(float distance) {
		return (1 / (distance * distance)) * this->intensity;
	};
};