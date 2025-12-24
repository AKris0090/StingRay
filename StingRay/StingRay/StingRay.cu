#include "Stingray.cuh"

void setupObjectsHostToDevice() {
	Scene h_scene;
    h_scene.addLight(V3(1.0f, 1.5f, 2.0f), 0.15f,  8.5f);
    h_scene.addLight(V3(-1.0f, 1.5f, 2.0f), 0.15f, 8.5f);
    h_scene.addLight(V3(1.0f, 1.5f, -2.0f), 0.15f, 8.5f);
    h_scene.addLight(V3(-1.0f, 1.5f, -2.0f), 0.15f,8.5f);

    h_scene.addMaterial(V3(100.0f, 100.0f, 100.0f), 0.75f, 1.0f);
    h_scene.addMaterial(V3(180.0f, 180.0f, 180.0f), 1.0f, 0.0f);
    h_scene.addMaterial(V3(255.0f, 140.0f, 0.0f), 1.0f, 0.0f);
    h_scene.addMaterial(V3(186.0f, 85.0f, 211.0f), 0.25f, 1.0f);

    h_scene.addObjectFromFile("./objects/dragon.obj", 2);

	Scene h_scene2;
    h_scene2.addObjectFromFile("./objects/box.obj", 0);

	h_sceneCollection.scenes.push_back(h_scene);
    h_sceneCollection.scenes.push_back(h_scene2);

	h_sceneCollection.uploadToDevice();
}

static __global__ void init_rng(curandState* states, unsigned long seed) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int j = blockIdx.y * blockDim.y + threadIdx.y;
    int idx = i + j * SCREEN_WIDTH;
    if (idx >= SCREEN_WIDTH * SCREEN_HEIGHT) return;
    curand_init(seed, (unsigned long long) idx, 0, &states[idx]);
}

static __global__ void updateDisplay(V3* totals, Uint8* devPixels, GPUCam* cam, d_Scene* scenes, curandState* devStates, int repeatSamples) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;
    if ((i >= SCREEN_WIDTH) || (j >= SCREEN_HEIGHT)) return;

    int index = i + (j * SCREEN_WIDTH);
    curandState localDevState = devStates[index];

    float jitterX = curand_uniform(&localDevState);
    float jitterY = curand_uniform(&localDevState);

    V3 u = cam->horizontal * (float)(i + jitterX) / (float) (SCREEN_WIDTH - 1.0);
    V3 v = cam->vertical * (float)(j + jitterY) / (float) (SCREEN_HEIGHT - 1.0);

    V3 dir = (cam->botLeft + u + v - cam->origin).normalize();
    Ray primary_ray(cam->origin, dir);
    V3 ret_color = Tracer::trace_ray(primary_ray, scenes, &localDevState);

    totals[index].x += clampRGB(ret_color.x);
    totals[index].y += clampRGB(ret_color.y);
    totals[index].z += clampRGB(ret_color.z);
    devPixels[(index * 3)] = (totals[index].x / repeatSamples) * 255.0f;
    devPixels[(index * 3) + 1] = (totals[index].y / repeatSamples) * 255.0f;
    devPixels[(index * 3) + 2] = (totals[index].z / repeatSamples) * 255.0f;

    devStates[index] = localDevState;
}

int main(int argc, char** arcgv) {
    int tx = 8;
    int ty = 8;
    dim3 blocks(SCREEN_WIDTH / tx + 1, SCREEN_HEIGHT / ty + 1);
    dim3 threads(tx, ty);

    window.initDisplay(SCREEN_WIDTH, SCREEN_HEIGHT);

    devStates = device_allocate<curandState>(NUM_PIXELS);
    init_rng << <blocks, threads >> > (devStates, unsigned(rand()));
    CUDA_CHECK(cudaDeviceSynchronize());
    CUDA_CHECK(cudaPeekAtLastError());

    totals = device_allocate<V3>(NUM_PIXELS);
    devPixels = device_allocate<Uint8>(NUM_PIXELS * 3);
    CUDA_CHECK(cudaHostAlloc((void**)&copyTotals, (NUM_PIXELS) * sizeof(Uint8) * 3, 0));

    cam = Camera(SCREEN_WIDTH, SCREEN_HEIGHT, CAM_VFOV_DEG);
    d_cam = device_alloc_and_upload<GPUCam>(&cam.h_cam);

    setupObjectsHostToDevice();

    while (window.running) {
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_EVENT_QUIT) window.running = false;

            if (event.type == SDL_EVENT_MOUSE_MOTION) {
                float xoffset = event.motion.xrel * LOOK_SENS;
                float yoffset = event.motion.yrel * LOOK_SENS;

                cam.mouseMove(xoffset, yoffset);
            }
        }

        V3 forward = (cam.lookat - cam.h_cam.origin).normalize();
        V3 right = forward.cross(cam.up).normalize();

        bool write = false;

        const bool* state = SDL_GetKeyboardState(NULL);
        if (state[SDL_SCANCODE_W]) { cam.h_cam.origin += forward * MOVE_SENS; write = true; }
        if (state[SDL_SCANCODE_S]) { cam.h_cam.origin -= forward * MOVE_SENS; write = true; }
        if (state[SDL_SCANCODE_A]) { cam.h_cam.origin -= right * MOVE_SENS; write = true; }
        if (state[SDL_SCANCODE_D]) { cam.h_cam.origin += right * MOVE_SENS; write = true; }
        if (state[SDL_SCANCODE_Q]) { cam.h_cam.origin -= cam.up * MOVE_SENS; write = true; }
        if (state[SDL_SCANCODE_E]) { cam.h_cam.origin += cam.up * MOVE_SENS; write = true; }

        if (write) {
            cam.lookat = cam.h_cam.origin + cam.forward;
            cam.needUpdate = true;
        }

        auto t1 = high_resolution_clock::now();

        if (window.repeat_samples < NUM_SAMPLES) {
            window.repeat_samples += 1;
            updateDisplay << <blocks, threads >> > (totals, devPixels, d_cam, h_sceneCollection.d_Scenes, devStates, window.repeat_samples);
            CUDA_CHECK(cudaDeviceSynchronize());
            CUDA_CHECK(cudaPeekAtLastError());

            cudaMemcpy(copyTotals, devPixels, (SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(Uint8) * 3, cudaMemcpyDeviceToHost);

            for (int i = 0; i < SCREEN_WIDTH * SCREEN_HEIGHT; i++) {
                Uint32 r = copyTotals[i*3 + 0];
                Uint32 g = copyTotals[i*3 + 1];
                Uint32 b = copyTotals[i*3 + 2];
                pixels[i] = (0xFF << 24) | (r << 16) | (g << 8) | b;
            }

            SDL_UpdateTexture(window.texture, NULL, pixels.data(), SCREEN_WIDTH * sizeof(Uint32));
            SDL_RenderClear(window.renderer);
            SDL_RenderTextureRotated(window.renderer, window.texture, NULL, NULL, 0, NULL, SDL_FLIP_VERTICAL);
            SDL_RenderPresent(window.renderer);

            auto t2 = high_resolution_clock::now();

            updateProgressBar(window.repeat_samples / (float)NUM_SAMPLES, t1, t2);
        }

        if (cam.needUpdate) {
            // recompute camera basis once per frame b   
            cam.updateCam();
            CUDA_CHECK(cudaMemcpy(d_cam, &cam.h_cam, sizeof(GPUCam), cudaMemcpyHostToDevice));

            cudaMemset(totals, 0, ((SCREEN_WIDTH * SCREEN_HEIGHT) * sizeof(V3)));
            cudaMemset(devPixels, 0, ((SCREEN_WIDTH * SCREEN_HEIGHT) * (sizeof(Uint8) * 3)));

            window.repeat_samples = 0;
        }
    }
    return 0;
}