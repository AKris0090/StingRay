#pragma once
#include <random>
#include "Vector.h"
#include "Ray.h"

class PBRMaterial {
public:
	V3 base_color;
	float specular;
	float roughness;
	float IOR;
	float transmission;
	float emission_strength;

	PBRMaterial() { base_color = V3(0, 0, 0); transmission = 0.0f; specular = roughness = 0.5f; emission_strength = 1.0f; IOR = 1.45f; }
	PBRMaterial(V3 color, float spec, float rough, float index_ref, float trans, float emi) { base_color = color; transmission = trans; specular = spec; roughness = rough; emission_strength = emi; IOR = index_ref; }

	V3 random_direction_in_n(float radius);
	V3 random_direction();
	V3 random_scatter(Ray& in_dir, hitReg& hR);
	V3 reflect(Ray& in_dir, hitReg& hR);
	V3 hitColor(Ray& in_ray, hitReg& hR, Ray& out_ray);
};