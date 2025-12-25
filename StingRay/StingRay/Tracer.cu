#include "Tracer.cuh"
#include <iostream>
using namespace std;

constexpr float PI = 3.14159265f;

static __device__ hitReg intersectTriangle(Ray& rayIn, const Triangle* t, float tMin, float tMax) {
	hitReg hitOut{};
	V3 edge1 = t->v1 - t->v0;
	V3 edge2 = t->v2 - t->v0;
	V3 pvec = rayIn.direction.cross(edge2);
	float det = edge1.dot(pvec);

	if (fabsf(det) < EPS) return hitOut;

	float invDet = 1.0f / det;
	V3 tvec = rayIn.origin - t->v0;
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
	hitOut.hitMaterialIdx = t->matIdx;
	hitOut.normal_vector = t->normal;
	hitOut.hitPoint = rayIn.get_at(time);

	return hitOut;
}

static __device__ float intersectAABB(const Ray& ray, const V3& bmin, const V3& bmax, const float& closest) {
	float tx1 = (bmin.x - ray.origin.x) * ray.invDirection.x, tx2 = (bmax.x - ray.origin.x) * ray.invDirection.x;
	float tmin = min(tx1, tx2), tmax = max(tx1, tx2);
	float ty1 = (bmin.y - ray.origin.y) * ray.invDirection.y, ty2 = (bmax.y - ray.origin.y) * ray.invDirection.y;
	tmin = max(tmin, min(ty1, ty2)), tmax = min(tmax, max(ty1, ty2));
	float tz1 = (bmin.z - ray.origin.z) * ray.invDirection.z, tz2 = (bmax.z - ray.origin.z) * ray.invDirection.z;
	tmin = max(tmin, min(tz1, tz2)), tmax = min(tmax, max(tz1, tz2));
	if (tmax >= tmin && tmin < closest && tmax > 0) return tmin; else return FLT_MAX;
}

static __device__ hitReg intersectBVH(Ray& ray, const d_Scene* scene, uint32_t rootIdx) {
	hitReg hit{};

	BVHNode* stack[64];
	uint32_t sp = 0u;
	BVHNode* node = (BVHNode*)&scene->d_bvhNodes[rootIdx];
	stack[sp++] = node;

	float closest = FLT_MAX;

	while (sp > 0) {
		if (node->primCount > 0) {
			for (uint32_t i = 0; i < node->primCount; i++) {
				uint32_t triIdx = (uint32_t)scene->d_indexBuffer[node->leftFirst + i];
				const Triangle* tri = &scene->d_primitives[triIdx];

				// update hitReg
				hitReg tempHit = intersectTriangle(ray, tri, 0.00001f, closest);

				if (tempHit.hit && tempHit.time < closest) {
					hit = tempHit;
					closest = hit.time;
				}
			}
			if (sp == 0) {
				break;
			}
			else {
				node = stack[--sp];
			}
		}
		else {
			BVHNode* child1 = &scene->d_bvhNodes[node->leftFirst];
			BVHNode* child2 = &scene->d_bvhNodes[node->leftFirst + 1];

			float dist1 = intersectAABB(ray, child1->aabbMin, child1->aabbMax, closest);
			float dist2 = intersectAABB(ray, child2->aabbMin, child2->aabbMax, closest);

			if (dist1 > dist2) {
				float d = dist1; dist1 = dist2; dist2 = d;
				BVHNode* n = child1; child1 = child2; child2 = n;
			}

			if (dist1 == FLT_MAX) {
				if (sp == 0) {
					break;
				}
				else {
					node = stack[--sp];
				}
			}
			else {
				node = child1;
				if (dist2 != FLT_MAX) {
					stack[sp++] = child2;
				}
			}
		}
	}

	return hit;
}

static __device__ hitReg hitAnything(d_Scene* scenes, Ray& r, float tMin, float tMax) {
	hitReg final_hit{};
	for (int i = 0; i < NUM_SCENES; i++) {
		hitReg temp_rec = intersectBVH(r, scenes + i, 0);
		if (temp_rec.hit && temp_rec.time < tMax && temp_rec.time > tMin && final_hit.time > temp_rec.time) {
			final_hit = temp_rec;
		}
	}
	return final_hit;
}

__device__ V3 Tracer::calculate_shadow_ray(Ray& shadowRay, d_Scene* scenes, AreaLight& a, const hitReg& primHit) {
	hitReg hit = hitAnything(scenes, shadowRay, 0.0001f, FLT_MAX);
	if (!hit.hit) {
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

__device__ V3 Tracer::trace_ray(const Ray& ray, d_Scene* scenes, curandState* localDevState) {
	Ray cur_r = ray;
	V3 radiance(0.0f);
	V3 attenuation(1.0f);
	// iterative tracer (since no recursion on GPU!!!)
	for (int i = 0; i < NUM_BOUNCES; i++) {
		// Check if the primary ray hits anything
		hitReg hit = hitAnything(scenes, cur_r, 0.0001f, FLT_MAX);

		if (!hit.hit) {
			// add sky color here if necessary (radiance += attenuation * env_color)
			break;
		}

		Ray secondaryRay;
		V3 albedo = scenes->d_mats[hit.hitMaterialIdx].hitColor(cur_r, hit, secondaryRay, localDevState);

		V3 direct(0.0f);
		for (int j = 0; j < scenes->lightCounter; j++) {
			AreaLight& l = scenes->d_lights[j];
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

			direct += cookTorrence(hit.normal_vector, -cur_r.direction, lightRay, scenes->d_mats[hit.hitMaterialIdx]) * calculate_shadow_ray(shadowRay, scenes, l, hit);
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