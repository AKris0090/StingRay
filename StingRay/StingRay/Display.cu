#include "Display.cuh"

#define SDL_MAIN_HANDLED

void DisplayWindow::initDisplay(int screen_width, int screen_height) {
    cout << ",d88~~\\ ~~~888~~~ 888 888b    |  e88~~\\  888~-_        e      Y88b    / " << endl;
    cout << "8888       888    888 |Y88b   | d888     888   \\      d8b      Y88b  /  " << endl;
    cout << "`Y88b      888    888 | Y88b  | 8888 __  888    |    /Y88b      Y88b/  " << endl;
    cout << " `Y88b,    888    888 |  Y88b | 8888   | 888   /    /  Y88b      Y8Y  " << endl;
    cout << "   8888    888    888 |   Y88b| Y888   | 888_-~    /____Y88b      Y   " << endl;
    cout << "\\__88P'    888    888 |    Y888  \"88__ / 888 ~- _ /      Y88b    /    " << endl;
    cout << "v 1.0.0 -------------------------------------------------------------   " << endl;
    cout << "--------------------------------------------------------------------- " << endl;

    // Startup the video feed
    SDL_Init(SDL_INIT_VIDEO);

    // Create the SDL Window and open
    window = SDL_CreateWindow("StingRay", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, (screen_width), (screen_height), 0);

    this->SCREEN_HEIGHT = screen_height;
    this->SCREEN_WIDTH = screen_width;
        
    // Create the renderer for the window
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

    // Get surface off of the window
    surface = SDL_GetWindowSurface(window);
}