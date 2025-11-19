#include "Scene.cuh"

#define TINYOBJLOADER_IMPLEMENTATION
#include "tiny_obj_loader.h"

void SceneObject::loadModel(std::string filepath) {
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
    
            Triangle t(v1, v2, v3);
            t.matIdx = 1;
            t.normal = ((n1 + n2 + n3) / 3).normalize();
            h_primitives.push_back(t);
    
            index_offset += fv;
        }
    }
}