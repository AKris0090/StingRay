#pragma once
#include "Vector.cuh"

struct GPUCam {
    V3 origin, botLeft, horizontal, vertical;
};

struct Camera {
	V3 lookat, up, forward;
    float pitch, yaw, hWidth, hHeight;
    bool needUpdate = false;
    GPUCam h_cam{};

    Camera() {};

    inline float radians(float deg) {
        return deg * (3.141593 / 180.0f);
    }

	Camera(int width, int height, float fov) {
        h_cam.origin = V3(0.0f, 0.0f, 0.5f);
        lookat = V3(0.0f, 0.0f, -1.0f);
        up = V3(0.0f, 1.0f, 0.0f);

        pitch = 0.0f;
        yaw = -90.0f;

        float aspect = width / (float) height;

        float theta = fov * (3.141593 / 180.0f);
        hHeight = tanf(theta / 2.0f);
        hWidth = aspect * hHeight;

        V3 w = (h_cam.origin - lookat).normalize();
        V3 u = (up.cross(w)).normalize();
        V3 v = w.cross(u);

        h_cam.botLeft = h_cam.origin - u * hWidth - v * hHeight - w;
        h_cam.horizontal = u * (2.0f * hWidth);
        h_cam.vertical = v * (2.0f * hHeight);

        needUpdate = false;
	}

    void mouseMove(float deltaX, float deltaY) {
        yaw += deltaX;
        pitch -= deltaY;

        if (pitch > 89.0f) pitch = 89.0f;
        if (pitch < -89.0f) pitch = -89.0f;

        // convert yaw/pitch to a direction vector
        V3 direction;
        direction.x = cosf(radians(yaw)) * cosf(radians(pitch));
        direction.y = sinf(radians(pitch));
        direction.z = sinf(radians(yaw)) * cosf(radians(pitch));
        forward = direction.normalize();

        lookat = h_cam.origin + forward;

        needUpdate = true;
    }

    void updateCam() {
        V3 w = -forward.normalize();
        V3 u = (up.cross(w)).normalize();
        V3 v = w.cross(u);

        h_cam.botLeft = h_cam.origin - u * hWidth - v * hHeight - w;
        h_cam.horizontal = u * (2.0f * hWidth);
        h_cam.vertical   = v * (2.0f * hHeight);
        needUpdate = false;
    }
};