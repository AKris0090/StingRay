#include "PBRMat.cuh"

__device__ V3 PBRMaterial::random_direction(curandState* localDevState) {
	V3 random = V3(curand_uniform(localDevState), curand_uniform(localDevState), curand_uniform(localDevState)).normalize().mul_val(2.0).sub(V3(1.0));
	//while (random.squared_length() >= 1) {
	//	random = V3(curand_uniform(localDevState), curand_uniform(localDevState), curand_uniform(localDevState)).mul_val(2.0).sub(V3(1));
	//}
	return random;
}

__device__ V3 PBRMaterial::random_direction_in_n(float radius, curandState* localDevState) {
	V3 random = random_direction(localDevState);
	return random.mul_val(radius);
}

// Perfect reflection
__device__ V3 PBRMaterial::reflect(Ray& in_dir, hitReg& hR) {
	V3 normal_dir = in_dir.direction.normalize();
	V3 reflected = normal_dir.sub(hR.normal_vector.mul_val(2 * normal_dir.dot(hR.normal_vector)));
	return reflected;
}

// Imperfect scattering
__device__ V3 PBRMaterial::random_scatter(Ray& in_dir, hitReg& hR, curandState* localDevState) {
	return in_dir.get_at(hR.time).add(hR.normal_vector.add(random_direction(localDevState)));
}

__device__ V3 PBRMaterial::hitColor(Ray& in_ray, hitReg& hR, Ray& out_ray, curandState* localDevState){
	if (roughness <= 0.0f) {
		out_ray = Ray(in_ray.get_at(hR.time), this->reflect(in_ray, hR));
	}
	else if (roughness >= 1.0f) {
		out_ray = Ray(in_ray.get_at(hR.time), this->random_scatter(in_ray, hR, localDevState).sub(in_ray.get_at(hR.time)));
	}
	else {
		out_ray = Ray(in_ray.get_at(hR.time), this->reflect(in_ray, hR).mul_val((1.0f - this->roughness)).add(this->random_scatter(in_ray, hR, localDevState).mul_val(roughness)));
	}
	return this->base_color.div_val(255.0f);
}