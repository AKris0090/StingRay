#include "Vector.cuh"
#include "Ray.cuh"
#include <stdint.h>

constexpr float EPS = 1e-6f;

struct AABB {
	V3 min, max;
};

static __device__ float intersectAABB(const Ray& ray, float tMaxLimit, const V3& bmin, const V3& bmax) {
    // use inverse direction to avoid division-by-zero issues
    float invDx = 1.0f / ray.direction.x;
    float invDy = 1.0f / ray.direction.y;
    float invDz = 1.0f / ray.direction.z;

    float tx1 = (bmin.x - ray.origin.x) * invDx;
    float tx2 = (bmax.x - ray.origin.x) * invDx;
    float tmin = fminf(tx1, tx2);
    float tmax = fmaxf(tx1, tx2);

    float ty1 = (bmin.y - ray.origin.y) * invDy;
    float ty2 = (bmax.y - ray.origin.y) * invDy;
    tmin = fmaxf(tmin, fminf(ty1, ty2));
    tmax = fminf(tmax, fmaxf(ty1, ty2));

    float tz1 = (bmin.z - ray.origin.z) * invDz;
    float tz2 = (bmax.z - ray.origin.z) * invDz;
    tmin = fmaxf(tmin, fminf(tz1, tz2));
    tmax = fminf(tmax, fmaxf(tz1, tz2));

    // no overlap or we hit further than allowed
    if (tmax < tmin || tmin >= tMaxLimit || tmax <= 0.0f) return FLT_MAX;
    return tmin;
}

struct BVHNode {
	V3 aabbMin, aabbMax;
	uint32_t leftNode, firstTriIdx, primCount;
    __device__ bool isLeaf() const { return primCount > 0; }
};

