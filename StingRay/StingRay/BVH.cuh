#include "Vector.cuh"
#include "Ray.cuh"
#include <stdint.h>

constexpr float EPS = 1e-6f;

struct AABB {
    V3 bMin = FLT_MAX, bMax = -FLT_MAX;
    void grow(V3 p) { bMin = V3::vminf(bMin, p), bMax = V3::vmaxf(bMax, p); }
    void grow(AABB& o) {
        if (o.bMin.x != FLT_MAX) {
            grow(o.bMin);
            grow(o.bMax);
        }
    }
    float area() const {
        V3 e = bMax - bMin;
        return e.x * e.y + e.y * e.z + e.z * e.x;
    }
};

struct Bin {
    AABB bounds;
    int primCount = 0;
};

static __device__ float intersectAABB(const Ray& ray, const V3& bmin, const V3& bmax, const float& closest) {
    float tx1 = (bmin.x - ray.origin.x) * ray.invDirection.x, tx2 = (bmax.x - ray.origin.x) * ray.invDirection.x;
    float tmin = min(tx1, tx2), tmax = max(tx1, tx2);
    float ty1 = (bmin.y - ray.origin.y) * ray.invDirection.y, ty2 = (bmax.y - ray.origin.y) * ray.invDirection.y;
    tmin = max(tmin, min(ty1, ty2)), tmax = min(tmax, max(ty1, ty2));
    float tz1 = (bmin.z - ray.origin.z) * ray.invDirection.z, tz2 = (bmax.z - ray.origin.z) * ray.invDirection.z;
    tmin = max(tmin, min(tz1, tz2)), tmax = min(tmax, max(tz1, tz2));
    if (tmax >= tmin && tmin < closest && tmax > 0) return tmin; else return FLT_MAX;
}

struct BVHNode {
	V3 aabbMin, aabbMax;
    uint32_t leftFirst, primCount;
};

