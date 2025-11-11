#include "Tracer.cuh"
#include <iostream>
using namespace std;

__device__ V3 Tracer::calculate_shadow_ray(Ray shadowRay, Sphere** objects, AreaLight a, hitReg primHit, int numObjects) {
	// check if the ray hits anything
	bool hit_anything = false;
	float closest_so_far = FLT_MAX;
	for (int k = 0; k < numObjects; k++) {
		Sphere current = *(*(objects + k));
		hitReg temp_rec = shadowRay.intersect(current.origin, 0.00001f, closest_so_far, current.radius);
		if (temp_rec.hit) {
			hit_anything = true;
			closest_so_far = temp_rec.time;
		}
	}
	if (!hit_anything) {
		return a.color * a.get_intensity(primHit.hitPoint.distance_to(a.pos.origin));
	} else {
		return V3(0, 0, 0);
	}
}

// normal distribution function
__device__ float D_GGX(float ndoth, float roughness) {
	float a = roughness * roughness;
	float a2 = a * a;
	float denom = (ndoth * ndoth) * (a2 - 1.0f) + 1.0f;
	return a2 / (PI * denom * denom);
}

// geometry visibility function (self-shadowing, microfacets)
__device__ float G_SchlickGGX(float ndotv, float roughness) {
	float r = (roughness + 1.0f);
	float k = (r * r) / 8.0f;
	return ndotv / (ndotv * (1.0f - k) + k);
}

__device__ float G_Smith(float ndotv, float ndotl, float roughness) {
	return G_SchlickGGX(ndotv, roughness) * G_SchlickGGX(ndotl, roughness);
}

// fresnel approximation
__device__ V3 F_Schlick(float cosTheta, const V3& F0) {
	return F0 + (V3(1.0f) - F0) * powf(1.0f - cosTheta, 5.0f);
}

// cook-torrence BRDF
__device__ V3 Cook_Torrence(const V3& normal, const V3& view, const V3& light, const PBRMaterial* mat) {
	V3 half = (view + light).normalize();

	float ndotl = fmaxf(normal.dot(light), 0.0f);
	float ndotv = fmaxf(normal.dot(view), 0.0f);
	float ndoth = fmaxf(normal.dot(half), 0.0f);
	float vdoth = fmaxf(view.dot(half), 0.0f);

	V3 albedo = mat->base_color / 255.0f;

	V3 F0 = V3(0.04f);
	F0 = F0 * (1.0f - mat->metallic) + albedo * mat->metallic;

	float normalDist = D_GGX(ndoth, mat->roughness);
	float geom = G_Smith(ndotv, ndotl, mat->roughness);
	V3 F = F_Schlick(vdoth, F0);

	V3 numerator = F * normalDist * geom;
	float denominator = 4.0f * ndotv * ndotl + 1e-4f;

	V3 spec = numerator / denominator;
	V3 ks = F;
	V3 kd = V3(1.0f) - ks;
	kd *= (1.0f - mat->metallic);

	return (kd * albedo / PI + spec) * ndotl;
}

__device__ V3 Tracer::trace_ray(const Ray& ray, Sphere** objects, AreaLight** lights, int max_bounces, int numObjects, int numLights, curandState* localDevState) {
	Ray cur_r = ray;
	V3 radiance(0.0f);
	V3 attenuation(1.0f);
	PBRMaterial* prevMat = nullptr;
	// iterative tracer (since no recursion on GPU!!!)
	for (int i = 0; i < max_bounces; i++) {

		// Check if the primary ray hits anything
		hitReg hit;
		bool hit_anything = false;
		float closest_so_far = FLT_MAX;
		PBRMaterial* hitMaterial = nullptr;
		for (int j = 0; j < numObjects; j++) {
			Sphere current = *(*(objects + j));
			hitReg temp_rec = cur_r.intersect(current.origin, 0.00001f, closest_so_far, current.radius);
			if (temp_rec.hit) {
				hitMaterial = current.mat;
				hit_anything = true;
				closest_so_far = temp_rec.time;
				hit = temp_rec;
				hit.hitPoint = cur_r.get_at(hit.time);
			}
		}

		if (!hit_anything) {
			// add sky color here if necessary (radiance += attenuation * env_color)
			break;
		}

		Ray secondaryRay;
		V3 albedo = hitMaterial->hitColor(cur_r, hit, secondaryRay, localDevState);

		V3 direct(0.0f);
		for (int j = 0; j < numLights; j++) {
			AreaLight l = *(*(lights + j));
			V3 lightRay = (l.pos.origin - hit.hitPoint).normalize();

			// random light sample (for soft shadows)
			V3 randLightPos = l.pos.origin + curand_uniform(localDevState) * l.pos.radius;
			V3 shadowSampleDir = (randLightPos - hit.hitPoint).normalize();

			Ray shadowRay = Ray(hit.hitPoint + hit.normal_vector * 1e-4f, shadowSampleDir);

			direct += Cook_Torrence(hit.normal_vector, -cur_r.direction, lightRay, hitMaterial) * calculate_shadow_ray(shadowRay, objects, l, hit, numObjects);
		}

		radiance += attenuation * direct;
		attenuation = attenuation * albedo;

		// Russian roulette termination to keep paths efficient and unbiased
		if (i > 3) {
			float p = fmaxf(attenuation.x, fmaxf(attenuation.y, attenuation.z));
			if (p <= 0.0f) break;
			if (curand_uniform(localDevState) > p) break;
			// renormalize throughput to account for survival probability
			attenuation /= p;
		}

		cur_r = secondaryRay;
	}
	return radiance * 255.0f;
}