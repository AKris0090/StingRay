#pragma once

#include "Vector.cuh"
#include "PBRMat.cuh"
#include "AreaLight.cuh"
#include "BVH.cuh"
#include <vector>
#include <string>
#include <iostream>

struct Triangle {
	V3 v0, v1, v2;
	V3 normal;
	int matIdx;
	Triangle(V3 v1, V3 v2, V3 v3) { this->v0 = v1; this->v1 = v2; this->v2 = v3; matIdx = -1; };
};

struct SceneObject {
    std::vector<Triangle> h_primitives;
    int numPrims;

    void loadModel(std::string filepath);
};

struct d_Scene {
    PBRMaterial* d_mats = nullptr;
    AreaLight* d_lights = nullptr;
    BVHNode* d_bvhNodes = nullptr;
    int lightCounter = 0;
    uint32_t* d_indexBuffer = nullptr;
    Triangle* d_primitives = nullptr;

    static __device__ Ray::hitReg intersectTriangle(Ray& rayIn, const Triangle& t, float tMin, float tMax) {
        Ray::hitReg hitOut{};
        V3 edge1 = t.v1 - t.v0;
        V3 edge2 = t.v2 - t.v0;
        V3 pvec = rayIn.direction.cross(edge2);
        float det = edge1.dot(pvec);

        if (fabsf(det) < EPS) return hitOut;

        float invDet = 1.0f / det;
        V3 tvec = rayIn.origin - t.v0;
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
        hitOut.hitMaterialIdx = t.matIdx;
        hitOut.normal_vector = t.normal;
        hitOut.hitPoint = rayIn.get_at(time);

        return hitOut;
    }

    __device__ Ray::hitReg intersectBVH(Ray& ray, uint32_t rootIdx) {
        Ray::hitReg hit{};

        uint32_t stack[32];
        int sp = 0;

        stack[sp++] = rootIdx;

        float closest = FLT_MAX;

        while (sp > 0) {
            uint32_t nodeIdx = stack[--sp];
            BVHNode& node = d_bvhNodes[nodeIdx];

            float tEntry = intersectAABB(ray, closest, node.aabbMin, node.aabbMax);
            if (tEntry == FLT_MAX) {
                continue;
            }

            if (node.isLeaf()) {
                for (uint32_t i = 0; i < node.primCount; i++) {
                    uint32_t triIdx = (uint32_t)d_indexBuffer[node.firstTriIdx + i];
                    Triangle tri = d_primitives[triIdx];

                    // update hitReg
                    Ray::hitReg tempHit = intersectTriangle(ray, tri, 0.00001f, closest);

                    if (tempHit.hit && tempHit.time < hit.time) {
                        hit = tempHit;
                    }
                }
            }
            else {
                uint32_t left = node.leftNode;
                uint32_t right = node.leftNode + 1;

                stack[sp++] = right;
                stack[sp++] = left;
            }
        }

        return hit;
    }
};

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
    std::vector<uint32_t> triIdx;
    uint32_t* d_indexBuffer = nullptr;
    uint32_t rootIdx = 0, nodesUsed = 1;

    int lightCounter = 0;

    void addTriangle(V3 v0, V3 v1, V3 v2, int matIdx) {
        Triangle t(v0, v1, v2);
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
        for (const SceneObject& o : h_objects) {
            for (const Triangle& t : o.h_primitives) {
                h_triangles.push_back(t);
            }
        }
        for (const Triangle& t : miscTriangles.h_primitives) {
            h_triangles.push_back(t);
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
        for (uint32_t first = node.firstTriIdx, i = 0; i < node.primCount; i++) {
            uint32_t leafIdx = triIdx[first + i];
            Triangle& leafTri = h_triangles[leafIdx];
            node.aabbMin = V3::vminf(node.aabbMin, leafTri.v0);
            node.aabbMin = V3::vminf(node.aabbMin, leafTri.v1);
            node.aabbMin = V3::vminf(node.aabbMin, leafTri.v2);
            node.aabbMax = V3::vmaxf(node.aabbMax, leafTri.v0);
            node.aabbMax = V3::vmaxf(node.aabbMax, leafTri.v1);
            node.aabbMax = V3::vmaxf(node.aabbMax, leafTri.v2);
        }
    }

    void subdivideBVH(uint32_t nodeIdx, const std::vector<V3>& centroidBuffer) {
        BVHNode& node = h_bvhNodes[nodeIdx];
        if (node.primCount <= 2) return; // early exit (base case)

        V3 extent = node.aabbMax - node.aabbMin;
        int axis = 0;
        if (extent.y > extent.x) axis = 1;
        if (extent.z > extent[axis]) axis = 2;
        float splitPos = node.aabbMin[axis] + extent[axis] * 0.5f;

        // partition in-place
        int i = node.firstTriIdx;
        int j = i + node.primCount - 1;
        while (i <= j) {
            if (centroidBuffer[triIdx[i]][axis] < splitPos) {
                i++;
            }
            else {
                std::swap(triIdx[i], triIdx[j--]);
            }
        }
        int leftCount = i - node.firstTriIdx;
        if (leftCount == 0 || leftCount == node.primCount) return;

        int leftChildIdx = nodesUsed++;
        int rightChildIdx = nodesUsed++;
        h_bvhNodes[leftChildIdx].firstTriIdx = node.firstTriIdx;
        h_bvhNodes[leftChildIdx].primCount = leftCount;
        h_bvhNodes[rightChildIdx].firstTriIdx = i;
        h_bvhNodes[rightChildIdx].primCount = node.primCount - leftCount;
        node.leftNode = leftChildIdx;
        node.primCount = 0;
        updateNodeBounds(leftChildIdx);
        updateNodeBounds(rightChildIdx);

        subdivideBVH(leftChildIdx, centroidBuffer);
        subdivideBVH(rightChildIdx, centroidBuffer);
    }

    void buildBVH() {
        h_bvhNodes.resize(h_triangles.size() * 2 - 1);
        std::vector<V3> centroidBuffer;
        int count = 0;
        for (const SceneObject& o : h_objects) {
            for (const Triangle& t : o.h_primitives) {
                triIdx.push_back(count);
                centroidBuffer.push_back((t.v0 + t.v1 + t.v2) * 0.3333333f);
                count++;
            }
        }
        for (const Triangle& t : miscTriangles.h_primitives) {
            triIdx.push_back(count);
            centroidBuffer.push_back((t.v0 + t.v1 + t.v2) * 0.3333333f);
            count++;
        }

        BVHNode& root = h_bvhNodes[rootIdx];
        root.firstTriIdx = 0, root.leftNode = 0, root.primCount = h_triangles.size();
        updateNodeBounds(rootIdx);
        subdivideBVH(rootIdx, centroidBuffer);

        d_bvhNodes = upload_vector(h_bvhNodes);
        d_indexBuffer = upload_vector(triIdx);
    }

    d_Scene getDeviceScene() {
        return d_Scene{
            d_mats,
            d_lights,
            d_bvhNodes,
            lightCounter,
            d_indexBuffer,
            d_primitives
        };
    }
    
};