#pragma once

#include "Vector.cuh"
#include "PBRMat.cuh"
#include "AreaLight.cuh"
#include "BVH.cuh"
#include <vector>
#include <string>
#include <iostream>

constexpr int BIN_COUNT = 100;
constexpr int NUM_SCENES = 2;

struct Triangle {
    V3 v0, v1, v2, normal;
    int matIdx = -1;
};

struct SceneObject {
    std::vector<Triangle> h_primitives;
    int numPrims;

    void loadModel(std::string filepath, int matIdx);
};

struct d_Scene {
    PBRMaterial* d_mats     = nullptr;
    AreaLight* d_lights     = nullptr;
    BVHNode* d_bvhNodes     = nullptr;
    uint32_t* d_indexBuffer = nullptr;
    Triangle* d_primitives  = nullptr;
    int lightCounter = 0;
};

struct Scene {
    SceneObject miscTriangles;
    std::vector<SceneObject> h_objects;
    std::vector<Triangle> h_triangles;
    std::vector<PBRMaterial> h_mats;
    std::vector<AreaLight> h_lights;
    std::vector<V3> h_centroids;
    std::vector<BVHNode> h_bvhNodes;
    std::vector<uint32_t> h_triIdx;
    uint32_t rootIdx = 0, nodesUsed = 1;
    Triangle* d_primitives = nullptr;
    PBRMaterial* d_mats = nullptr;
    AreaLight* d_lights = nullptr;
    BVHNode* d_bvhNodes = nullptr;
    uint32_t* d_indexBuffer = nullptr;

    int lightCounter = 0;

    void addTriangle(V3 v0, V3 v1, V3 v2, int matIdx);
    void addMaterial(V3 baseColor, float roughness, float metallic);
    void addLight(V3 pos, float radius, float intensity);
    void addObjectFromFile(std::string filepath, int matIdx);

    void offloadObjects();

    void updateNodeBounds(uint32_t nodeIdx);
    float findSplitPlane(const BVHNode& node, int& axis, float& splitPos);
    void subdivideBVH(uint32_t nodeIdx);

    void buildBVH();
};

struct h_SceneCollection {
	std::vector<Scene> scenes;
	d_Scene* d_Scenes;

    void addScene(const Scene& scene) {
        scenes.push_back(scene);
	}

    void uploadToDevice();
};