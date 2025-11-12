#pragma once
#include "Vector.cuh"

struct Camera {
	V3 origin, lookat, up, botLeft, horizontal, vertical;
    float pitch, yaw, hWidth, hHeight;
    bool needUpdate;

    inline float radians(float deg) {
        return deg * (3.141593 / 180.0f);
    }

	Camera(int width, int height, float fov) {
        origin = V3(0.0f, 0.0f, 0.5f);
        lookat = V3(0.0f, 0.0f, -1.0f);
        up = V3(0.0f, 1.0f, 0.0f);

        pitch = 0.0f;
        yaw = -90.0f;

        float aspect = width / (float) height;

        float theta = fov * (3.141593 / 180.0f);
        hHeight = tanf(theta / 2.0f);
        hWidth = aspect * hHeight;

        V3 w = (origin - lookat).normalize();
        V3 u = (up.cross(w)).normalize();
        V3 v = w.cross(u);

        botLeft = origin - u * hWidth - v * hHeight - w;
        horizontal = u * (2.0f * hWidth);
        vertical = v * (2.0f * hHeight);

        needUpdate = false;
	}

    void mouseMove(float deltaX, float deltaY) {
        yaw += deltaX;
        pitch -= deltaY;

        // convert yaw/pitch to a direction vector
        V3 direction;
        direction.x = cosf(radians(yaw)) * cosf(radians(pitch));
        direction.y = sinf(radians(pitch));
        direction.z = sinf(radians(yaw)) * cosf(radians(pitch));
        lookat = (origin + direction).normalize();

        needUpdate = true;
    }

    void updateCam() {
        V3 w = (origin - lookat).normalize();
        V3 u = (up.cross(w)).normalize();
        V3 v = w.cross(u);

        botLeft = origin - u * hWidth - v * hHeight - w;
        horizontal = u * (2.0f * hWidth);
        vertical = v * (2.0f * hHeight);
        needUpdate = false;
    }
};