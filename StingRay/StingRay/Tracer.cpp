#include "Tracer.h"
#include <execution>
#include <iostream>
using namespace std;

V3 Tracer::trace_ray(Ray& ray, vector<Sphere> objects, int numBounces) {
	hitReg hit{ false, 0, V3(0, 0, 0) };
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

	if (hit_anything) {
		// For normal color display
		//V3 normal = hit.normal_vector.add_val(1).mul_val(0.5).mul_val(255.99);
		//return normal;
		Ray scattered_ray(V3(0, 0, 0), V3(0, 0, 0));
		if (numBounces < this->max_bounces) {
			V3 attenuation = current_mat.hitColor(ray, hit, scattered_ray);
			//cout << attenuation.x << " " << attenuation.y << " " << attenuation.z << endl;
			numBounces += 1;
			return attenuation.mul(trace_ray(scattered_ray, objects, numBounces));
		}
		else {
			return V3(0, 0, 0);
		}
	}
	else {
		return V3(255, 255, 255);
	}
}