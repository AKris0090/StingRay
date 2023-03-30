#include "Tracer.h"
#include <execution>
#include <iostream>
using namespace std;

V3 Tracer::get_light_intensity(Ray& in, std::vector<Sphere> objects, V3 hitcolor, AreaLight a, hitReg primHit, PBRMaterial mat) {
	bool hit_anything = false;
	float closest_so_far = FLT_MAX;
	for (int i = 0; i < objects.size(); i++) {
		Sphere current = objects.at(i);
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

V3 Tracer::trace_ray(Ray& ray, vector<Sphere> objects, int numBounces, std::vector<AreaLight> lights) {
	hitReg hit{ false, 0, V3(0, 0, 0) };
	hitReg lightHit{ false, 0, V3(0, 0, 0) };
	bool hit_anything = false;
	float closest_so_far = FLT_MAX;
	PBRMaterial current_mat;
	for(int i = 0; i < objects.size(); i++){
		Sphere current = objects.at(i);
		hitReg temp_rec = ray.intersect(current.origin, 0.00001f, closest_so_far, current.radius);
		if(temp_rec.hit) {
			current_mat = current.mat;
			hit_anything = true;
			closest_so_far = temp_rec.time;
			hit = temp_rec;
		}
	}

// For normal color display
//V3 normal = hit.normal_vector.add_val(1).mul_val(0.5).mul_val(255.99);
//return normal;
//cout << attenuation.x << " " << attenuation.y << " " << attenuation.z << endl;

	if (hit_anything) {
		if (numBounces < this->max_bounces) {
			Ray secondaryRay(V3(0, 0, 0), V3(0, 0, 0));
			V3 attenuation = current_mat.hitColor(ray, hit, secondaryRay);
			V3 true_color(0, 0, 0);
			for (int i = 0; i < lights.size(); i++) {
				AreaLight l = lights.at(i);
				numBounces += 1;
				Ray shadowRay(ray.get_at(hit.time), l.pos.origin.sub(ray.get_at(hit.time)).add(current_mat.random_direction_in_n(l.pos.radius)));
				true_color = true_color.add(get_light_intensity(shadowRay, objects, attenuation, l, hit, current_mat).mul(l.intensity));
				if (secondaryRay.intersect(l.pos.origin, 0.0f, FLT_MAX, l.pos.radius).hit) {
					return l.color.mul(l.intensity);
				}
			}
			V3 out_v = attenuation.mul(trace_ray(secondaryRay, objects, numBounces, lights)).add(true_color.mul_val(current_mat.roughness));
			return out_v;
		}
		else {
			Ray secondaryRay(V3(0, 0, 0), V3(0, 0, 0));
			return current_mat.hitColor(ray, hit, secondaryRay);
		}
	}
	else {
		return V3(0, 0, 0);
	}
}