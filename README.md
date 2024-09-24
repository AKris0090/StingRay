# ![stingray](https://github.com/user-attachments/assets/b95c7f60-cbff-4912-8487-a42d867f74a5) Stingray ![Language](https://img.shields.io/badge/Language-C%2B%2B-blue) ![CUDA](https://img.shields.io/badge/API-CUDA-green)

![main](https://github.com/user-attachments/assets/fe7869d3-1d11-4d48-8330-5e7716fa5db2)

Stingray is a iterative raytracer made in C++ and optimized using the CUDA API.

## 🛠 How to Build
1. Clone the repo: `git clone https://github.com/AKris0090/StingRay.git`
2. Build and run in Visual Studio. Release mode preferred, debug is slow.

## ⚙️ Core Features:

### Spot Light Specular Lighting

![reflectOrange](https://github.com/user-attachments/assets/2f278af3-2554-4033-b5ea-48860d686814)

Each primary ray splits into a shadow ray for each light source at the point of contact, allowing for additive shadows and specular highlights. 

### Iterative Sampling + CUDA API Integration

|                                                     1 Sample                                                    |                                               1000 Samples                                                                    |
| :-------------------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------------------------------------------------: |
|      ![FirstSample](https://github.com/user-attachments/assets/26967660-b16a-4afb-9178-2c56337734d6)            |                 ![ThousandSample](https://github.com/user-attachments/assets/39b55f5b-9097-4574-9b7e-7ef97be084dd)            |

Each frame, a different sub-pixel random position is sampled for a ray direction, and its result is added to a cumulative array of pixel values. This array is then divided by the current number of samples to get the average pixel color.

Parallelizing the raytracing work onto the GPU increased frame times from 350 ms/frame to 31 ms/frame, almost an 11x speedup. Necessary functions and memory are exposed to the GPU with the ``__device__`` qualifier, and those that need to be accessed by the CPU attain the ``__host__`` qualifier. Calling functions with the ``__global__`` qualifier, followed by a ``<<< dim3 >>>`` argument dispatches the work on the GPU.

### Material System

![roseGOld](https://github.com/user-attachments/assets/c9d37816-166b-417c-bc29-cf4f6b402a7e)

The material system I implemented allows for variable color and roughness. In the future, I plan to incorporate more PBR elements such as metallicity, specular, and transmission materials.

## Credits:
* https://raytracing.github.io/
