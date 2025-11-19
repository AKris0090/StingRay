#include "Tracer.cuh"
#include <iostream>
using namespace std;

constexpr float PI = 3.14159265f;
constexpr float EPS = 1e-6f;

static __device__ Ray::hitReg intersectTriangle(Ray& rayIn, const Triangle& t, float tMin, float tMax) {
	Ray::hitReg hitOut{};
	V3 edge1 = t.v1 - t.v0;
	V3 edge2 = t.v2 - t.v0;
	V3 pvec = rayIn.direction.cross(edge2);
	float det = edge1.dot(pvec);

	if (fabsf(det) < EPS) return hitOut;

	float invDet = 1.0f / det;
	V3 tvec = rayIn.origin - t.v0;
	float u = tvec.dot(pvec) * invDet;
	if (u < 0.0f || u > 1.0f)
		return hitOut;

	V3 qvec = tvec.cross(edge1);
	float v = rayIn.direction.dot(qvec) * invDet;
	if (v < 0.0f || u + v > 1.0f)
		return hitOut;

	float time = edge2.dot(qvec) * invDet;
	if (time < tMin || time > tMax)
		return hitOut;

	hitOut.time = time;
	hitOut.hit = true;
	hitOut.normal_vector = t.normal;

	return hitOut;
}

__device__ V3 Tracer::calculate_shadow_ray(Ray shadowRay, Scene* scene, AreaLight& a, Ray::hitReg& primHit) {
	// check if the ray hits anything
	bool hit_anything = false;
	float closest_so_far = FLT_MAX;
	for (int k = 0; k < scene->primitiveCounter; k++) {
		Triangle current = scene->d_primitives[k];
		Ray::hitReg temp_rec = intersectTriangle(shadowRay, current, 0.00001, closest_so_far);
		if (temp_rec.hit) {
			hit_anything = true;
			closest_so_far = temp_rec.time;
		}
	}
	if (!hit_anything) {
		return a.color * a.get_intensity(primHit.hitPoint.distance_to(a.pos));
	} else {
		return V3(0, 0, 0);
	}
}

// normal distribution function
__device__ float dGGX(float ndoth, float roughness) {
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
__device__ V3 fSchlick(float cosTheta, const V3& F0) {
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

__device__ V3 Tracer::trace_ray(const Ray& ray, Scene* scene, int max_bounces, curandState* localDevState) {
	Ray cur_r = ray;
	V3 radiance(0.0f);
	V3 attenuation(1.0f);
	// iterative tracer (since no recursion on GPU!!!)
	for (int i = 0; i < max_bounces; i++) {

		// Check if the primary ray hits anything
		Ray::hitReg hit;
		Ray::hitReg temp_rec;
		bool hit_anything = false;
		float closest_so_far = FLT_MAX;
		for (int j = 0; j < scene->primitiveCounter; j++) {
			Triangle current = scene->d_primitives[j];
			temp_rec = intersectTriangle(cur_r, current, 0.00001f, closest_so_far);
			if (temp_rec.hit) {
				temp_rec.hitMaterialIdx = current.matIdx;
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
		//else {
		//	return hitMaterial->base_color;
		//}

		Ray secondaryRay;
		V3 albedo = scene->d_mats[hit.hitMaterialIdx].hitColor(cur_r, hit, secondaryRay, localDevState);

		V3 direct(0.0f);
		for (int j = 0; j < scene->lightCounter; j++) {
			AreaLight l = scene->d_lights[j];
			V3 lightRay = (l.pos - hit.hitPoint).normalize();

			// random light sample (for soft shadows)
			V3 randLightPos = l.pos + curand_uniform(localDevState) * l.radius;
			V3 shadowSampleDir = (randLightPos - hit.hitPoint).normalize();

			Ray shadowRay = Ray(hit.hitPoint + hit.normal_vector * 1e-6f, shadowSampleDir);

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
	return radiance * 255.0f;
}