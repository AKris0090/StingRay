#include "Display.cuh"

#define SDL_MAIN_HANDLED

void DisplayWindow::initDisplay(int screen_width, int screen_height) {
    cout << ",d88~~\\ ~~~888~~~ 888 888b    |  e88~~\\  888~-_        e      Y88b    / " << endl;
    cout << "8888       888    888 |Y88b   | d888     888   \\      d8b      Y88b  /  " << endl;
    cout << "`Y88b      888    888 | Y88b  | 8888 __  888    |    /Y88b      Y88b/  " << endl;
    cout << " `Y88b,    888    888 |  Y88b | 8888   | 888   /    /  Y88b      Y8Y  " << endl;
    cout << "   8888    888    888 |   Y88b| Y888   | 888_-~    /____Y88b      Y   " << endl;
    cout << "\\__88P'    888    888 |    Y888  \"88__ / 888 ~- _ /      Y88b    /    " << endl;
    cout << "v 2.0.0 -------------------------------------------------------------   " << endl;
    cout << "--------------------------------------------------------------------- " << endl;

    // Startup the video feed
    SDL_Init(SDL_INIT_VIDEO);

    window = SDL_CreateWindow(
        "StingRay",        // title
        screen_width,       // width in pixels
        screen_height,      // height in pixels
        0                   // flags (0 = default)
    );
        
    // Create the renderer for the window
    renderer = SDL_CreateRenderer(window, NULL);

    // Get surface off of the window
    surface = SDL_GetWindowSurface(window);

    float deltaTime = (SDL_GetTicks() - lastFrameTime) / 1000.0f;
    lastFrameTime = SDL_GetTicks();
    SDL_SetWindowRelativeMouseMode(window, true);

    texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, screen_width, screen_height);
}