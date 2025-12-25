#include "Scene.cuh"

#define TINYOBJLOADER_IMPLEMENTATION
#include "tiny_obj_loader.h"

void SceneObject::loadModel(std::string filepath, int matIdx) {
    tinyobj::attrib_t attrib;
    std::vector<tinyobj::shape_t> shapes;
    std::vector<tinyobj::material_t> materials;
    std::string mtlPath = "./";
    
    std::string err;
    
    bool ret = tinyobj::LoadObj(&attrib, &shapes, &materials, &err, filepath.c_str(), mtlPath.c_str());
    if (!err.empty()) {
        std::cerr << err << std::endl;
    }
    
    if (!ret) {
        exit(1);
    }
    
    // Loop over shapes
    for (size_t s = 0; s < shapes.size(); s++) {
        // Loop over faces(polygon)
        size_t index_offset = 0;
        for (size_t f = 0; f < shapes[s].mesh.num_face_vertices.size(); f++) {
            size_t fv = size_t(shapes[s].mesh.num_face_vertices[f]);
    
            tinyobj::index_t i1 = shapes[s].mesh.indices[index_offset + 0];
            tinyobj::index_t i2 = shapes[s].mesh.indices[index_offset + 1];
            tinyobj::index_t i3 = shapes[s].mesh.indices[index_offset + 2];
    
            auto fetch = [&](tinyobj::index_t idx) {
                return V3(
                    attrib.vertices[3 * idx.vertex_index + 0],
                    attrib.vertices[3 * idx.vertex_index + 1],
                    attrib.vertices[3 * idx.vertex_index + 2]
                );
                };
    
            V3 v1 = fetch(i1);
            V3 v2 = fetch(i2);
            V3 v3 = fetch(i3);
    
            auto fetchN = [&](tinyobj::index_t idx) {
                return V3(
                    attrib.normals[3 * idx.normal_index + 0],
                    attrib.normals[3 * idx.normal_index + 1],
                    attrib.normals[3 * idx.normal_index + 2]
                );
                };
    
            V3 n1 = fetchN(i1);
            V3 n2 = fetchN(i2);
            V3 n3 = fetchN(i3);
    
            Triangle t{ v1, v2, v3 };
            t.matIdx = matIdx;
            t.normal = ((n1 + n2 + n3) / 3).normalize();
            h_primitives.push_back(t);
    
            index_offset += fv;
        }
    }
}

// SCENE STRUCT IMPLEMENTATION

void Scene::addTriangle(V3 v0, V3 v1, V3 v2, int matIdx) {
    Triangle t{ v0, v1, v2 };
    t.normal = V3(0, 1, 0);
    t.matIdx = matIdx;
    miscTriangles.h_primitives.push_back(t);
}

void Scene::addObjectFromFile(std::string filepath, int matIdx) {
    SceneObject obj;
    obj.loadModel(filepath, matIdx);
    h_objects.push_back(std::move(obj));
}

void Scene::addMaterial(V3 baseColor, float roughness, float metallic) {
    PBRMaterial m = PBRMaterial(baseColor, metallic, roughness, 0, 0, 0);
    h_mats.push_back(m);
}

void Scene::addLight(V3 pos, float radius, float intensity) {
    AreaLight l = AreaLight(pos, radius, intensity);
    h_lights.push_back(l);
    lightCounter++;
}

void Scene::offloadObjects() {
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

void Scene::updateNodeBounds(uint32_t nodeIdx) {
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

float nodeCost(const BVHNode& node) {
    V3 extent = node.aabbMax - node.aabbMin;
    float area = extent.x * extent.y + extent.y * extent.z + extent.z * extent.x;
    return node.primCount * area;
}

float Scene::findSplitPlane(const BVHNode& node, int& axis, float& splitPos) {
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
            int binIdx = std::min(BIN_COUNT - 1, (int)((aaCenter - boundsMin) * scale));
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

void Scene::subdivideBVH(uint32_t nodeIdx) {
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

void Scene::buildBVH() {
    h_bvhNodes.resize(h_triangles.size() * 2 - 1);

    BVHNode& root = h_bvhNodes[rootIdx];
    root.leftFirst = 0, root.primCount = h_triangles.size();
    updateNodeBounds(rootIdx);
    subdivideBVH(rootIdx);

    d_bvhNodes = upload_vector(h_bvhNodes);
    d_indexBuffer = upload_vector(h_triIdx);
}

// SCENE COLLECTION IMPLEMENTATION

// Uploads all scenes to device and sets deviceScenes array pointer
void h_SceneCollection::uploadToDevice() {
    std::vector<d_Scene> deviceScenes;
    for (int i = 0; i < scenes.size(); i++) {
        scenes[i].offloadObjects();
        scenes[i].buildBVH();
        d_Scene dScene = d_Scene{
            scenes[i].d_mats,
            scenes[i].d_lights,
            scenes[i].d_bvhNodes,
            scenes[i].d_indexBuffer,
            scenes[i].d_primitives,
            scenes[i].lightCounter
        };
        deviceScenes.push_back(dScene);
    }
    d_Scenes = upload_vector<d_Scene>(deviceScenes);
}