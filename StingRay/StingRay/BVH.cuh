#include "Vector.cuh"

struct AABB {
	V3 min, max;
};

struct BVHNode {
	BVHNode* left, * right;
	bool isLeaf;
};