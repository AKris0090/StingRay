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

struct BVHNode {
    V3 aabbMin, aabbMax;
    uint32_t leftFirst, primCount;
};
