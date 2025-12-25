#include "PBRMat.cuh"

constexpr float PI = 3.14159f;

// diffuse (imperfect) scattering
__device__ V3 PBRMaterial::random_in_hemisphere(const V3& normal, curandState* localDevState) {
	float r1 = curand_uniform(localDevState);
	float r2 = curand_uniform(localDevState);

	float phi = 2.0f * PI * r1;
	float cosTheta = sqrtf(1.0f - r2);
	float sinTheta = sqrtf(r2);

	// Local space direction
	V3 local(
		cosf(phi) * sinTheta,
		sinf(phi) * sinTheta,
		cosTheta
	);

	// Transform local -> world space
	V3 tangent, bitangent;
	if (fabs(normal.x) > fabs(normal.z))
		tangent = V3(-normal.y, normal.x, 0.0f).normalize();
	else
		tangent = V3(0.0f, -normal.z, normal.y).normalize();
	bitangent = normal.cross(tangent);

	return (tangent * local.x + bitangent * local.y + normal * local.z).normalize();
}

// perfect reflection
__device__ V3 reflect(const Ray& r, hitReg& hR) {
	V3 normal_dir = r.direction.normalize();
	V3 reflected = normal_dir - (hR.normal_vector * (2 * normal_dir.dot(hR.normal_vector)));
	return reflected.normalize();
}

__device__ V3 PBRMaterial::hitColor(Ray& in_ray, hitReg& hR, Ray& out_ray, curandState* localDevState){
	float rand = curand_uniform(localDevState);
	if (rand < metallic) {
		// specular reflection
		V3 reflectedDir = reflect(in_ray, hR);
		out_ray = Ray(hR.hitPoint + hR.normal_vector * 1e-4f, reflectedDir);
	}
	else {
		// diffuse
		V3 diffuseDir = hR.normal_vector + random_in_hemisphere(hR.normal_vector, localDevState);
		out_ray = Ray(hR.hitPoint + hR.normal_vector * 1e-4f, diffuseDir.normalize());
	}

	return this->base_color / 255.0f;
}