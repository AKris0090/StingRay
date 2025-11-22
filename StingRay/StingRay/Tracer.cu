#include "Tracer.cuh"
#include <iostream>
using namespace std;

constexpr float PI = 3.14159265f;

__device__ V3 Tracer::calculate_shadow_ray(Ray& shadowRay, d_Scene* scene, AreaLight& a, const hitReg& primHit) {
	hitReg temp_rec = intersectBVH(shadowRay, scene, 0);
	if (!temp_rec.hit) {
		return a.color * a.get_intensity(primHit.hitPoint.distance_to(a.pos + (-primHit.normal_vector * a.radius)));
	} else {
		return V3(0, 0, 0);
	}
}

// normal distribution function
static __device__ float dGGX(float ndoth, float roughness) {
	float a = roughness * roughness;
	float a2 = a * a;
	float denom = (ndoth * ndoth) * (a2 - 1.0f) + 1.0f;
	return a2 / (PI * denom * denom);
}

// geometry visibility function (self-shadowing, microfacets)
__device__ float gSchlickGGX(float ndotv, float roughness) {
	float r = (roughness + 1.0f);
	float k = (r * r) / 8.0f;
	return ndotv / (ndotv * (1.0f - k) + k);
}

__device__ float gSmith(float ndotv, float ndotl, float roughness) {
	return gSchlickGGX(ndotv, roughness) * gSchlickGGX(ndotl, roughness);
}

// fresnel approximation
static __device__ V3 fSchlick(float cosTheta, const V3& F0) {
	return F0 + (V3(1.0f) - F0) * powf(1.0f - cosTheta, 5.0f);
}

// cook-torrence BRDF
__device__ V3 cookTorrence(const V3& normal, const V3& view, const V3& light, const PBRMaterial& mat) {
	V3 half = (view + light).normalize();

	float ndotl = fmaxf(normal.dot(light), 0.0f);
	float ndotv = fmaxf(normal.dot(view), 0.0f);
	float ndoth = fmaxf(normal.dot(half), 0.0f);
	float vdoth = fmaxf(view.dot(half), 0.0f);

	V3 albedo = mat.base_color / 255.0f;

	V3 F0 = V3(0.04f);
	F0 = F0 * (1.0f - mat.metallic) + albedo * mat.metallic;

	float normalDist = dGGX(ndoth, mat.roughness);
	float geom = gSmith(ndotv, ndotl, mat.roughness);
	V3 F = fSchlick(vdoth, F0);

	V3 numerator = F * normalDist * geom;
	float denominator = 4.0f * ndotv * ndotl + 1e-4f;

	V3 spec = numerator / denominator;
	V3 ks = F;
	V3 kd = V3(1.0f) - ks;
	kd *= (1.0f - mat.metallic);

	return (kd * albedo / PI + spec) * ndotl;
}

__device__ V3 Tracer::trace_ray(const Ray& ray, d_Scene* scene, int max_bounces, curandState* localDevState) {
	Ray cur_r = ray;
	V3 radiance(0.0f);
	V3 attenuation(1.0f);
	// iterative tracer (since no recursion on GPU!!!)
	for (int i = 0; i < max_bounces; i++) {
		// Check if the primary ray hits anything
		hitReg hit = intersectBVH(cur_r, scene, 0);

		if (!hit.hit) {
			// add sky color here if necessary (radiance += attenuation * env_color)
			break;
		}
		//else {
		//	return scene->d_mats[hit.hitMaterialIdx].base_color;
		//}

		Ray secondaryRay;
		V3 albedo = scene->d_mats[hit.hitMaterialIdx].hitColor(cur_r, hit, secondaryRay, localDevState);

		V3 direct(0.0f);
		for (int j = 0; j < scene->lightCounter; j++) {
			AreaLight& l = scene->d_lights[j];
			V3 lightRay = (l.pos - hit.hitPoint).normalize();

			// random light sample (for soft shadows)
			float u = curand_uniform(localDevState);
			float v = curand_uniform(localDevState);
			float w = curand_uniform(localDevState);

			V3 randOffset = V3(u, v, w) * 2.0f - V3(1.0f);
			randOffset = randOffset.normalize() * (curand_uniform(localDevState) * l.radius);
			V3 randLightPos = l.pos + randOffset;
			V3 shadowSampleDir = (randLightPos - hit.hitPoint).normalize();

			Ray shadowRay = Ray(hit.hitPoint + hit.normal_vector * 1e-4f, shadowSampleDir);

			direct += cookTorrence(hit.normal_vector, -cur_r.direction, lightRay, scene->d_mats[hit.hitMaterialIdx]) * calculate_shadow_ray(shadowRay, scene, l, hit);
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
	return radiance;
}