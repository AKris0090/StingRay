#include "Tracer.cuh"
#include <execution>
#include <iostream>
using namespace std;

__device__ V3 Tracer::get_light_intensity(Ray in, Sphere** objects, V3 hitcolor, AreaLight a, hitReg primHit, PBRMaterial* mat, int numObjects) {
	bool hit_anything = false;
	float closest_so_far = FLT_MAX;
	for (int k = 0; k < numObjects; k++) {
		Sphere current = *(*(objects + k));
		hitReg temp_rec = in.intersect(current.origin, 0.00001f, closest_so_far, current.radius);
		if (temp_rec.hit) {
			hit_anything = true;
			closest_so_far = temp_rec.time;
		}
	}
	if (!hit_anything) {
		return hitcolor.mul(a.color).mul_val(primHit.normal_vector.dot(in.direction.normalize()));
	}
	else {
		return V3(0, 0, 0);
	}
}

__device__ V3 Tracer::trace_ray(const Ray& ray, Sphere** objects, AreaLight** lights, int max_bounces, int numObjects, int numLights, curandState* localDevState) {
	Ray cur_r = ray;
	V3 cur_attenuation = V3(1.0, 1.0, 1.0);
	for (int i = 0; i < max_bounces; i++) {
		hitReg hit{ false, 0, V3(0, 0, 0) };
		hitReg lightHit{ false, 0, V3(0, 0, 0) };
		bool hit_anything = false;
		float closest_so_far = FLT_MAX;
		PBRMaterial* current_mat = nullptr;
		for (int j = 0; j < numObjects; j++) {
			Sphere current = *(*(objects + j));
			hitReg temp_rec = cur_r.intersect(current.origin, 0.00001f, closest_so_far, current.radius);
			if (temp_rec.hit) {
				current_mat = current.mat;
				hit_anything = true;
				closest_so_far = temp_rec.time;
				hit = temp_rec;
				hit.hitPoint = cur_r.get_at(hit.time);
			}
		}

		// SOMETHING WRONG WITH THE REFLECTIONS
		if (hit_anything) {
			V3 true_color(0, 0, 0);
			Ray secondaryRay = Ray(V3(0, 0, 0), V3(0, 0, 0));
			V3 attenuation = current_mat->hitColor(cur_r, hit, secondaryRay, localDevState);
			V3 emittance = attenuation.mul(current_mat->emission_strength);
			for (int j = 0; j < numLights; j++) {
				AreaLight l = *(*(lights + j));
				float intensity = l.get_intensity(hit.hitPoint.distance_to(l.pos.origin));
				Ray shadowRay(cur_r.get_at(hit.time), l.pos.origin.sub(hit.hitPoint).add(current_mat->random_direction_in_n(l.pos.radius, localDevState)));
				true_color = true_color.add(get_light_intensity(shadowRay, objects, attenuation, l, hit, current_mat, numObjects).mul_val(intensity));
				if (secondaryRay.intersect(l.pos.origin, 0.0f, FLT_MAX, l.pos.radius).hit) {
					return l.color.mul(intensity);
				}
			}
			cur_attenuation = attenuation.mul_val(1.0f - current_mat->roughness).mul(cur_attenuation).add(true_color.mul_val(current_mat->roughness).add(emittance));
			cur_r = secondaryRay;
		} else {
			return cur_attenuation;
		}

		//if (hit_anything) {
		//	V3 target = hit.hitPoint.add(hit.normal_vector).add(current_mat->random_direction(localDevState));
		//	V3 att = cur_attenuation;
		//	cur_attenuation = att.mul_val(0.5f);
		//	cur_r = Ray(hit.hitPoint, target.sub(hit.hitPoint));
		//} else {
		//	V3 unit_direction = cur_r.direction.normalize();
		//	float t = 0.5f * (unit_direction.y + 1.0f);
		//	V3 c = V3(1.0, 1.0, 1.0).mul_val(1.0 - t).add(V3(0.5, 0.7, 1.0).mul_val(t));
		//	return c.mul(cur_attenuation).mul_val(255.0);
		//}

		//if (hit_anything) {
		//	return current_mat->base_color;
		//}
		//else {
		//	return V3(0.0, 0.0, 0.0);
		//}

	}
	return V3(0.0, 0.0, 0.0);
}