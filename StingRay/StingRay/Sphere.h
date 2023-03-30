#pragma once

class Sphere {
public:
	V3 origin;
	float radius;
	PBRMaterial mat;

	Sphere() { this->origin = V3(0, 0, 0); this->radius = 0.0f; };
	Sphere(V3 origin, float rad) { this->origin = origin; this->radius = rad; };
	Sphere(V3 origin, float rad, PBRMaterial mat) { this->origin = origin; this->radius = rad; this->mat = mat; };
};