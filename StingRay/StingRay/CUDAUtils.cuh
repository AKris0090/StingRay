#pragma once

#include <cstdio>
#include "device_launch_parameters.h"
#include <curand.h>
#include <vector>
#include <curand_kernel.h>

// GPU Error Checking MACRO
#define CUDA_CHECK(expr)  gpuAssert((expr), #expr, __FILE__, __LINE__)

inline void gpuAssert(cudaError_t code, const char* expr, const char* file, int line, bool abort = true)
{
    if (code != cudaSuccess)
    {
        fprintf(stderr,
            "\n================ CUDA ERROR ================\n"
            "Expression : %s\n"
            "Error      : %s\n"
            "File       : %s\n"
            "Line       : %d\n"
            "Function   : %s\n"
            "============================================\n",
            expr,
            cudaGetErrorString(code),
            file,
            line,
            __func__
        );

        if (abort)
            exit(code);
    }
}

template<typename T>
T* upload_vector(const std::vector<T>& vec) {
    T* devPtr = nullptr;
    size_t size = vec.size() * sizeof(T);
    CUDA_CHECK(cudaMalloc(&devPtr, size));
    CUDA_CHECK(cudaMemcpy(devPtr, vec.data(), size, cudaMemcpyHostToDevice));
    return devPtr;
}

template<typename T>
T* device_allocate(size_t count) {
    T* devPtr = nullptr;
    CUDA_CHECK(cudaMalloc(&devPtr, count * sizeof(T)));
    return devPtr;
}

template<typename T>
T* device_alloc_and_upload(const T* obj) {
    T* devPtr = nullptr;
    CUDA_CHECK(cudaMalloc(&devPtr, sizeof(T)));
    CUDA_CHECK(cudaMemcpy(devPtr, obj, sizeof(T), cudaMemcpyHostToDevice));
    return devPtr;
}