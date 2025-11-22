#pragma once

#include "Vector.cuh"
#include "PBRMat.cuh"
#include "AreaLight.cuh"
#include "BVH.cuh"
#include <vector>
#include <string>
#include <iostream>

constexpr int BIN_COUNT = 100;

struct Triangle {
    V3 v0, v1, v2, normal;
    int matIdx = -1;
};

struct SceneObject {
    std::vector<Triangle> h_primitives;
    int numPrims;

    void loadModel(std::string filepath);
};

struct d_Scene {
    PBRMaterial* d_mats     = nullptr;
    AreaLight* d_lights     = nullptr;
    BVHNode* d_bvhNodes     = nullptr;
    uint32_t* d_indexBuffer = nullptr;
    Triangle* d_primitives  = nullptr;
    int lightCounter = 0;
};

static __device__ hitReg intersectTriangle(Ray& rayIn, const Triangle* t, float tMin, float tMax) {
    hitReg hitOut{};
    V3 edge1 = t->v1 - t->v0;
    V3 edge2 = t->v2 - t->v0;
    V3 pvec = rayIn.direction.cross(edge2);
    float det = edge1.dot(pvec);

    if (fabsf(det) < EPS) return hitOut;

    float invDet = 1.0f / det;
    V3 tvec = rayIn.origin - t->v0;
    float u = tvec.dot(pvec) * invDet;
    if (u < 0.0f || u > 1.0f)
        return hitOut;

    V3 qvec = tvec.cross(edge1);
    float v = rayIn.direction.dot(qvec) * invDet;
    if (v < 0.0f || u + v > 1.0f)
        return hitOut;

    float time = edge2.dot(qvec) * invDet;
    if (time < tMin || time > tMax)
        return hitOut;

    hitOut.time = time;
    hitOut.hit = true;
    hitOut.hitMaterialIdx = t->matIdx;
    hitOut.normal_vector = t->normal;
    hitOut.hitPoint = rayIn.get_at(time);

    return hitOut;
}

static __device__ hitReg intersectBVH(Ray& ray, const d_Scene* scene, uint32_t rootIdx) {
    hitReg hit{};

    BVHNode* stack[64];
    uint32_t sp = 0u;
    BVHNode* node = (BVHNode*) &scene->d_bvhNodes[rootIdx];
    stack[sp++] = node;

    float closest = FLT_MAX;

    while (sp > 0) {
        if (node->primCount > 0) {
            for (uint32_t i = 0; i < node->primCount; i++) {
                uint32_t triIdx = (uint32_t)scene->d_indexBuffer[node->leftFirst + i];
                const Triangle* tri = &scene->d_primitives[triIdx];

                // update hitReg
                hitReg tempHit = intersectTriangle(ray, tri, 0.00001f, closest);

                if (tempHit.hit && tempHit.time < closest) {
                    hit = tempHit;
                    closest = hit.time;
                }
            }
            if (sp == 0) {
                break;
            }
            else {
                node = stack[--sp];
            }
        }
        else {
            BVHNode* child1 = &scene->d_bvhNodes[node->leftFirst];
            BVHNode* child2 = &scene->d_bvhNodes[node->leftFirst + 1];

            float dist1 = intersectAABB(ray, child1->aabbMin, child1->aabbMax, closest);
            float dist2 = intersectAABB(ray, child2->aabbMin, child2->aabbMax, closest);

            if (dist1 > dist2) {
                float d = dist1; dist1 = dist2; dist2 = d;
                BVHNode* n = child1; child1 = child2; child2 = n;
            }

            if (dist1 == FLT_MAX) {
                if (sp == 0) {
                    break;
                }
                else {
                    node = stack[--sp];
                }
            }
            else {
                node = child1;
                if (dist2 != FLT_MAX) {
                    stack[sp++] = child2;
                }
            }
        }
    }

    return hit;
}

struct Scene {
    SceneObject miscTriangles;
    std::vector<SceneObject> h_objects;
    std::vector<Triangle> h_triangles;
    std::vector<PBRMaterial> h_mats;
    std::vector<AreaLight> h_lights;
    Triangle* d_primitives = nullptr;
    PBRMaterial* d_mats = nullptr;
    AreaLight* d_lights = nullptr;
    std::vector<BVHNode> h_bvhNodes;
    BVHNode* d_bvhNodes = nullptr;
    std::vector<uint32_t> h_triIdx;
    uint32_t* d_indexBuffer = nullptr;
    uint32_t rootIdx = 0, nodesUsed = 1;
    std::vector<V3> h_centroids;

    int lightCounter = 0;

    void addTriangle(V3 v0, V3 v1, V3 v2, int matIdx) {
        Triangle t{ v0, v1, v2 };
        t.normal = V3(0, 1, 0);
        t.matIdx = matIdx;
        miscTriangles.h_primitives.push_back(t);
    }

    void addObjectFromFile(std::string filepath) {
        SceneObject obj;
        obj.loadModel(filepath);
        h_objects.push_back(std::move(obj));
    }

    void addMaterial(V3 baseColor, float roughness, float metallic) {
        PBRMaterial m = PBRMaterial(baseColor, metallic, roughness, 0, 0, 0);
        h_mats.push_back(m);
    }

    void addLight(V3 pos, float radius, float intensity) {
        AreaLight l = AreaLight(pos, radius, intensity);
        h_lights.push_back(l);
        lightCounter++;
    }

    void offloadObjects() {
        int count = 0;
        for (const SceneObject& o : h_objects) {
            for (const Triangle& t : o.h_primitives) {
                h_triangles.push_back(t);
                h_centroids.push_back((t.v0 + t.v1 + t.v2) * 0.3333333f);;
                h_triIdx.push_back(count);
                count++;
            }
        }
        for (const Triangle& t : miscTriangles.h_primitives) {
            h_triangles.push_back(t);
            h_centroids.push_back((t.v0 + t.v1 + t.v2) * 0.3333333f);;
            h_triIdx.push_back(count);
            count++;
        }

        std::cout << "offloading: " << h_triangles.size() << " primitives" << std::endl;
        d_primitives = upload_vector(h_triangles);

        std::cout << "offloading: " << h_mats.size() << " materials" << std::endl;
        d_mats = upload_vector(h_mats);

        std::cout << "offloading: " << h_lights.size() << " lights" << std::endl;
        d_lights = upload_vector(h_lights);
    }

    void updateNodeBounds(uint32_t nodeIdx) {
        BVHNode& node = h_bvhNodes[nodeIdx];
        node.aabbMin = V3(FLT_MAX);
        node.aabbMax = V3(-FLT_MAX);
        for (uint32_t first = node.leftFirst, i = 0; i < node.primCount; i++) {
            uint32_t leafIdx = h_triIdx[first + i];
            Triangle& leafTri = h_triangles[leafIdx];
            node.aabbMin = V3::vminf(node.aabbMin, leafTri.v0);
            node.aabbMin = V3::vminf(node.aabbMin, leafTri.v1);
            node.aabbMin = V3::vminf(node.aabbMin, leafTri.v2);
            node.aabbMax = V3::vmaxf(node.aabbMax, leafTri.v0);
            node.aabbMax = V3::vmaxf(node.aabbMax, leafTri.v1);
            node.aabbMax = V3::vmaxf(node.aabbMax, leafTri.v2);
        }
    }

    // binned SAH splitting
    float findSplitPlane(const BVHNode& node, int& axis, float& splitPos) {
        float bestCost = FLT_MAX;
        for (int a = 0; a < 3; a++) {
            float boundsMin = FLT_MAX, boundsMax = -FLT_MAX;
            for (uint32_t i = 0; i < node.primCount; i++) {
                float aaCenter = h_centroids[h_triIdx[node.leftFirst + i]][a];
                boundsMin = fminf(boundsMin, aaCenter);
                boundsMax = fmaxf(boundsMax, aaCenter);
            }
            if (boundsMin == boundsMax) continue;
            std::vector<Bin> bin(BIN_COUNT);
            float scale = BIN_COUNT / (boundsMax - boundsMin);
            for (uint32_t i = 0; i < node.primCount; i++) {
                uint32_t triIndex = h_triIdx[node.leftFirst + i];
                Triangle& tri = h_triangles[triIndex];
                float aaCenter = h_centroids[triIndex][a];
                int binIdx = min(BIN_COUNT - 1, (int)((aaCenter - boundsMin) * scale));
                bin[binIdx].primCount++;
                bin[binIdx].bounds.grow(tri.v0);
                bin[binIdx].bounds.grow(tri.v1);
                bin[binIdx].bounds.grow(tri.v2);
            }
            float leftArea[BIN_COUNT - 1], rightArea[BIN_COUNT - 1];
            int leftCount[BIN_COUNT - 1], rightCount[BIN_COUNT - 1];
            AABB leftBox, rightBox;
            int leftSum = 0, rightSum = 0;
            for (int i = 0; i < BIN_COUNT - 1; i++)
            {
                leftSum += bin[i].primCount;
                leftCount[i] = leftSum;
                leftBox.grow(bin[i].bounds);
                leftArea[i] = leftBox.area();
                rightSum += bin[BIN_COUNT - 1 - i].primCount;
                rightCount[BIN_COUNT - 2 - i] = rightSum;
                rightBox.grow(bin[BIN_COUNT - 1 - i].bounds);
                rightArea[BIN_COUNT - 2 - i] = rightBox.area();
            }
            scale = (boundsMax - boundsMin) / BIN_COUNT;
            for (int i = 0; i < BIN_COUNT - 1; i++) {
                float planeCost = leftCount[i] * leftArea[i] + rightCount[i] * rightArea[i];
                if (planeCost < bestCost) {
                    axis = a;
                    splitPos = boundsMin + scale * (i + 1);
                    bestCost = planeCost;
                }
            }
        }
        return bestCost;
    }

    float nodeCost(const BVHNode& node) {
        V3 extent = node.aabbMax - node.aabbMin;
        float area = extent.x * extent.y + extent.y * extent.z + extent.z * extent.x;
        return node.primCount * area;
    }

    void subdivideBVH(uint32_t nodeIdx) {
        BVHNode& node = h_bvhNodes[nodeIdx];

        int axis;
        float splitPos;
        float splitCost = findSplitPlane(node, axis, splitPos);
        
        // early exit pt. 2 - if the splitting doesnt help the cost, then abort the attempt to split
        V3 e = node.aabbMax - node.aabbMin;
        float parentArea = e.x * e.y + e.y * e.z + e.z * e.x;
        float parentCost = node.primCount * parentArea;

        if (splitCost >= parentCost) return;

        // partition in-place
        int i = node.leftFirst;
        int j = i + node.primCount - 1;
        while (i <= j) {
            if (h_centroids[h_triIdx[i]][axis] < splitPos) {
                i++;
            }
            else {
                std::swap(h_triIdx[i], h_triIdx[j--]);
            }
        }
        int leftCount = i - node.leftFirst;
        if (leftCount == 0 || leftCount == node.primCount) return;

        int leftChildIdx = nodesUsed++;
        int rightChildIdx = nodesUsed++;
        h_bvhNodes[leftChildIdx].leftFirst = node.leftFirst;
        h_bvhNodes[leftChildIdx].primCount = leftCount;
        h_bvhNodes[rightChildIdx].leftFirst = i;
        h_bvhNodes[rightChildIdx].primCount = node.primCount - leftCount;
        node.leftFirst = leftChildIdx;
        node.primCount = 0;
        updateNodeBounds(leftChildIdx);
        updateNodeBounds(rightChildIdx);

        subdivideBVH(leftChildIdx);
        subdivideBVH(rightChildIdx);
    }

    void buildBVH() {
        h_bvhNodes.resize(h_triangles.size() * 2 - 1);

        BVHNode& root = h_bvhNodes[rootIdx];
        root.leftFirst = 0, root.primCount = h_triangles.size();
        updateNodeBounds(rootIdx);
        subdivideBVH(rootIdx);

        d_bvhNodes = upload_vector(h_bvhNodes);
        d_indexBuffer = upload_vector(h_triIdx);
    }
};