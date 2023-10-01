#include "Tracer.cuh"
#include <iostream>
using namespace std;

__device__ V3 Tracer::get_light_intensity(Ray in, Ray secondary, Sphere** objects, V3 hitcolor, AreaLight a, hitReg primHit, PBRMaterial* mat, int numObjects) {
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
		hitReg temp_rec = secondary.intersect(a.pos.origin, 0.00001f, closest_so_far, a.pos.radius);
		if (temp_rec.hit) {
			return a.color;
		}
		else {
			// object albedo * light color * dot product between hit normal and light vector
			return hitcolor.mul(((a.color).mul_val((primHit.normal_vector.dot(in.direction.normalize())))).mul_val(mat->roughness));
		}
	}
	else {
		return V3(0, 0, 0);
	}
}

__device__ V3 Tracer::trace_ray(const Ray& ray, Sphere** objects, AreaLight** lights, int max_bounces, int numObjects, int numLights, curandState* localDevState) {
	Ray cur_r = ray;
	V3 cur_attenuation = V3(0.0, 0.0, 0.0);
	PBRMaterial* prevMat = nullptr;
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

		if (hit_anything) {
			Ray secondaryRay = Ray(V3(0, 0, 0), V3(0, 0, 0));
			V3 attenuation = current_mat->hitColor(cur_r, hit, secondaryRay, localDevState);
			V3 true_light_intensity = V3(0.0, 0.0, 0.0);
			if (current_mat->roughness != 0) {
				Ray secondaryRay(V3(0, 0, 0), V3(0, 0, 0));
				V3 attenuation = current_mat->hitColor(cur_r, hit, secondaryRay, localDevState);
				V3 true_color(0, 0, 0);
				for (int j = 0; j < numLights; j++) {
					AreaLight l = *(*(lights + j));
					Ray shadowRay = Ray(hit.hitPoint, hit.hitPoint.add(l.pos.origin.add(current_mat->random_direction_in_n(l.pos.radius, localDevState))));
					true_light_intensity = true_light_intensity.add(get_light_intensity(shadowRay, secondaryRay, objects, attenuation, l, hit, current_mat, numObjects));
					true_light_intensity = true_light_intensity.mul_val(l.get_intensity((hit.hitPoint.distance_to(l.pos.origin))));
				}
				if (i == 0) {
					cur_attenuation = true_light_intensity;
				}
				else {
					cur_attenuation = cur_attenuation.add((true_light_intensity).mul_val(1.0 - prevMat->roughness));

				}
			}
			prevMat = current_mat;
			cur_r = secondaryRay;
		} else {
			//Multiply for global illumination (background color)
			return cur_attenuation.mul_val(255.0);
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

//__device__ V3 Tracer::trace_ray_2(const Ray& ray, Sphere** objects, AreaLight** lights, int max_bounces, int numObjects, int numLights, curandState* localDevState) {
//	Ray cur_r = ray;
//	V3 cur_attenuation = V3(0.0, 0.0, 0.0);
//	PBRMaterial* prevMat = nullptr;
//	for (int i = 0; i < max_bounces; i++) {
//		hitReg hit{ false, 0, V3(0, 0, 0) };
//		hitReg lightHit{ false, 0, V3(0, 0, 0) };
//		bool hit_anything = false;
//		float closest_so_far = FLT_MAX;
//		PBRMaterial* current_mat = nullptr;
//		for (int j = 0; j < 1; j++) {
//			Sphere current = *(*(objects + j));
//			hitReg temp_rec = cur_r.intersect(current.origin, 0.00001f, closest_so_far, current.radius);
//			if (temp_rec.hit) {
//				current_mat = current.mat;
//				hit_anything = true;
//				closest_so_far = temp_rec.time;
//				hit = temp_rec;
//				hit.hitPoint = cur_r.get_at(hit.time);
//			}
//		}
//
//		if (hit_anything) {
//			Ray secondaryRay = Ray(V3(0, 0, 0), V3(0, 0, 0));
//			V3 attenuation = current_mat->hitColor(cur_r, hit, secondaryRay, localDevState);
//			V3 true_light_intensity = V3(0.0, 0.0, 0.0);
//			if (current_mat->roughness != 0) {
//				Ray secondaryRay(V3(0, 0, 0), V3(0, 0, 0));
//				V3 attenuation = current_mat->hitColor(cur_r, hit, secondaryRay, localDevState);
//				V3 true_color(0, 0, 0);
//				for (int j = 0; j < numLights; j++) {
//					AreaLight l = *(*(lights + j));
//					Ray shadowRay = Ray(hit.hitPoint, hit.hitPoint.add(l.pos.origin.add(current_mat->random_direction_in_n(l.pos.radius, localDevState))));
//					true_light_intensity = true_light_intensity.add(get_light_intensity(shadowRay, secondaryRay, objects, attenuation, l, hit, current_mat, numObjects));
//					true_light_intensity = true_light_intensity.mul_val(l.get_intensity((hit.hitPoint.distance_to(l.pos.origin))));
//				}
//				if (i == 0) {
//					cur_attenuation = true_light_intensity;
//				}
//				else {
//					cur_attenuation = cur_attenuation.add((true_light_intensity).mul_val(1.0 - prevMat->roughness));
//
//				}
//			}
//			prevMat = current_mat;
//			cur_r = secondaryRay;
//		}
//		else {
//			//Multiply for global illumination (background color)
//			return cur_attenuation.mul_val(255.0);
//		}
//
//		//if (hit_anything) {
//		//	V3 target = hit.hitPoint.add(hit.normal_vector).add(current_mat->random_direction(localDevState));
//		//	V3 att = cur_attenuation;
//		//	cur_attenuation = att.mul_val(0.5f);
//		//	cur_r = Ray(hit.hitPoint, target.sub(hit.hitPoint));
//		//} else {
//		//	V3 unit_direction = cur_r.direction.normalize();
//		//	float t = 0.5f * (unit_direction.y + 1.0f);
//		//	V3 c = V3(1.0, 1.0, 1.0).mul_val(1.0 - t).add(V3(0.5, 0.7, 1.0).mul_val(t));
//		//	return c.mul(cur_attenuation).mul_val(255.0);
//		//}
//
//		//if (hit_anything) {
//		//	return current_mat->base_color;
//		//}
//		//else {
//		//	return V3(0.0, 0.0, 0.0);
//		//}
//
//	}
//	return V3(0.0, 0.0, 0.0);
//}