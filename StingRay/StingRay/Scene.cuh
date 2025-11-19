#pragma once

#include "Vector.cuh"
#include "PBRMat.cuh"
#include "AreaLight.cuh"
#include <vector>
#include <string>
#include <iostream>

// GPU Error Checking MACRO
#define gpuChk(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char* file, int line, bool abort = true)
{
    if (code != cudaSuccess)
    {
        fprintf(stdout, "GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
        if (abort) exit(code);
    }
}

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

struct Scene {
    SceneObject miscTriangles;
    std::vector<SceneObject> h_objects;
    std::vector<PBRMaterial> h_mats;
    std::vector<AreaLight> h_lights;
    Triangle* d_primitives = nullptr;
    PBRMaterial* d_mats = nullptr;
    AreaLight* d_lights = nullptr;

    int primitiveCounter = 0;
    int materialCounter = 0;
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
        materialCounter++;
    }

    void addLight(V3 pos, float radius, float intensity) {
        AreaLight l = AreaLight(pos, radius, intensity);
        h_lights.push_back(l);
        lightCounter++;
    }

    __host__ void offloadObjects() {
        primitiveCounter = miscTriangles.h_primitives.size();
        for (const SceneObject& o : h_objects) {
            primitiveCounter += o.h_primitives.size();
        }

        std::cout << "offloading: " << primitiveCounter << " primitives" << std::endl;
        gpuChk(cudaMalloc((void**)&d_primitives, sizeof(Triangle) * primitiveCounter));
        int count = 0;
        for (const SceneObject& o : h_objects) {
            for (const Triangle& t : o.h_primitives) {
                gpuChk(cudaMemcpy(d_primitives + count, &t, sizeof(Triangle), cudaMemcpyHostToDevice));
                count++;
            }
        }
        for (const Triangle& t : miscTriangles.h_primitives) {
            gpuChk(cudaMemcpy(d_primitives + count, &t, sizeof(Triangle), cudaMemcpyHostToDevice));
            count++;
        }

        std::cout << "offloading: " << materialCounter << " materials" << std::endl;
        count = 0;
        gpuChk(cudaMalloc((void**)&d_mats, sizeof(PBRMaterial) * materialCounter));
        for (const PBRMaterial& m : h_mats) {
            gpuChk(cudaMemcpy(d_mats + count, &m, sizeof(PBRMaterial), cudaMemcpyHostToDevice));
            count++;
        }

        std::cout << "offloading: " << lightCounter << " lights" << std::endl;
        count = 0;
        gpuChk(cudaMalloc((void**)&d_lights, sizeof(AreaLight) * lightCounter));
        for (const AreaLight& l : h_lights) {
            gpuChk(cudaMemcpy(d_lights + count, &l, sizeof(AreaLight), cudaMemcpyHostToDevice));
            count++;
        }
    }
};