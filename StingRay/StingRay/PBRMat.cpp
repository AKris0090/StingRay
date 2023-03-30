#include "PBRMat.h"

V3 PBRMaterial::random_direction() {
	V3 random = V3(1, 1, 1);
	while (random.squared_length() >= 1) {
		random = V3((rand() / (float)(RAND_MAX)), (rand() / (float)(RAND_MAX)), (rand() / (float)(RAND_MAX))).mul_val(2.0).sub(V3(1));
	}
	return random;
}

V3 PBRMaterial::random_direction_in_n(float radius) {
	V3 random = random_direction();
	return random.mul_val(radius);
}

// Perfect reflection
V3 PBRMaterial::reflect(Ray& in_dir, hitReg& hR) {
	V3 normal_dir = in_dir.direction.normalize();
	V3 reflected = normal_dir.sub(hR.normal_vector.mul_val(2 * normal_dir.dot(hR.normal_vector)));
	return reflected;
}

// Imperfect scattering
V3 PBRMaterial::random_scatter(Ray& in_dir, hitReg& hR) {
	return in_dir.get_at(hR.time).add(hR.normal_vector.add(random_direction()));
}

V3 PBRMaterial::hitColor(Ray& in_ray, hitReg& hR, Ray& out_ray){
	if (roughness <= 0.0) {
		out_ray = Ray(in_ray.get_at(hR.time), this->reflect(in_ray, hR));
	}
	else if (roughness >= 1.0) {
		out_ray = Ray(in_ray.get_at(hR.time), this->random_scatter(in_ray, hR).sub(in_ray.get_at(hR.time)));
	}
	else {
		out_ray = Ray(in_ray.get_at(hR.time), this->reflect(in_ray, hR).mul_val((1.0 - this->roughness)).add(this->random_scatter(in_ray, hR).mul_val(roughness)));
	}
	return this->base_color.div_val(255.0f);
}