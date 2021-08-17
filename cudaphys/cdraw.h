#pragma once
#define SDL_MAIN_HANDLED
#include <SDL2/SDL.h>
namespace draw {
	const int SCREEN_WIDTH = 1380;
	const int SCREEN_HEIGHT = 1020;
	//The window we'll be rendering to
	SDL_Window* gWindow = NULL;

	//The window renderer
	SDL_Renderer* gRenderer = NULL;

	SDL_Event e;
	void set_pixel(SDL_Renderer* rend, int x, int y, Uint8 r, Uint8 g, Uint8 b, Uint8 a)
	{
		SDL_SetRenderDrawColor(rend, r, g, b, a);
		SDL_RenderDrawPoint(rend, x, y);
	}

	void draw_circle(SDL_Renderer* surface, int n_cx, int n_cy, int radius, Uint8 r, Uint8 g, Uint8 b, Uint8 a)
	{
		// if the first pixel in the screen is represented by (0,0) (which is in sdl)
		// remember that the beginning of the circle is not in the middle of the pixel
		// but to the left-top from it:

		double error = (double)-radius;
		double x = (double)radius - 0.5;
		double y = (double)0.5;
		double cx = n_cx - 0.5;
		double cy = n_cy - 0.5;

		while (x >= y)
		{
			set_pixel(surface, (int)(cx + x), (int)(cy + y), r, g, b, a);
			set_pixel(surface, (int)(cx + y), (int)(cy + x), r, g, b, a);

			if (x != 0)
			{
				set_pixel(surface, (int)(cx - x), (int)(cy + y), r, g, b, a);
				set_pixel(surface, (int)(cx + y), (int)(cy - x), r, g, b, a);
			}

			if (y != 0)
			{
				set_pixel(surface, (int)(cx + x), (int)(cy - y), r, g, b, a);
				set_pixel(surface, (int)(cx - y), (int)(cy + x), r, g, b, a);
			}

			if (x != 0 && y != 0)
			{
				set_pixel(surface, (int)(cx - x), (int)(cy - y), r, g, b, a);
				set_pixel(surface, (int)(cx - y), (int)(cy - x), r, g, b, a);
			}

			error += y;
			++y;
			error += y;

			if (error >= 0)
			{
				--x;
				error -= x;
				error -= x;
			}
			/*
			// sleep for debug
			SDL_RenderPresent(gRenderer);
			std::this_thread::sleep_for(std::chrono::milliseconds{ 100 });
			*/
		}
	}

	void fill_circle(SDL_Renderer* surface, int cx, int cy, int radius, Uint8 r, Uint8 g, Uint8 b, Uint8 a)
	{
		// Note that there is more to altering the bitrate of this 
		// method than just changing this value.  See how pixels are
		// altered at the following web page for tips:
		//   http://www.libsdl.org/intro.en/usingvideo.html
		static const int BPP = 4;

		//double ra = (double)radius;

		for (double dy = 1; dy <= radius; dy += 1.0)
		{
			// This loop is unrolled a bit, only iterating through half of the
			// height of the circle.  The result is used to draw a scan line and
			// its mirror image below it.

			// The following formula has been simplified from our original.  We
			// are using half of the width of the circle because we are provided
			// with a center and we need left/right coordinates.

			double dx = floor(sqrt((2.0 * radius * dy) - (dy * dy)));
			int x = cx - dx;
			SDL_SetRenderDrawColor(gRenderer, r, g, b, a);
			SDL_RenderDrawLine(gRenderer, cx - dx, cy + dy - radius, cx + dx, cy + dy - radius);
			SDL_RenderDrawLine(gRenderer, cx - dx, cy - dy + radius, cx + dx, cy - dy + radius);

			// Grab a pointer to the left-most pixel for each half of the circle
			/*Uint8 *target_pixel_a = (Uint8 *)surface->pixels + ((int)(cy + r - dy)) * surface->pitch + x * BPP;
			Uint8 *target_pixel_b = (Uint8 *)surface->pixels + ((int)(cy - r + dy)) * surface->pitch + x * BPP;
			for (; x <= cx + dx; x++)
			{
				*(Uint32 *)target_pixel_a = pixel;
				*(Uint32 *)target_pixel_b = pixel;
				target_pixel_a += BPP;
				target_pixel_b += BPP;
			}*/
			/*
			// sleep for debug
			SDL_RenderPresent(gRenderer);
			std::this_thread::sleep_for(std::chrono::milliseconds{ 100 });
			*/
		}
	}

	bool init()
	{
		//Initialization flag
		bool success = true;

		//Initialize SDL
		if (SDL_Init(SDL_INIT_VIDEO) < 0)
		{
			printf("SDL could not initialize! SDL_Error: %s\n", SDL_GetError());
			success = false;
		}
		else
		{
			//Create window
			gWindow = SDL_CreateWindow("SDL Tutorial", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 1500, 1000, SDL_WINDOW_SHOWN);
			if (gWindow == NULL)
			{
				printf("Window could not be created! SDL Error: %s\n", SDL_GetError());
				success = false;
			}
			else
			{
				//Create renderer for window
				gRenderer = SDL_CreateRenderer(gWindow, -1, SDL_RENDERER_ACCELERATED);
				if (gRenderer == NULL)
				{
					printf("Renderer could not be created! SDL Error: %s\n", SDL_GetError());
					success = false;
				}
				else
				{
					//Initialize renderer color
					SDL_SetRenderDrawColor(gRenderer, 0xFF, 0xFF, 0xFF, 0xFF);

					//Initialize PNG loading
				}
			}
		}

		return success;
	}

	bool loadMedia()
	{
		//Loading success flag
		bool success = true;

		return success;
	}

	void close()
	{
		//Free loaded images
		//gSpriteSheetTexture.free();

		//Destroy window    
		SDL_DestroyRenderer(gRenderer);
		SDL_DestroyWindow(gWindow);
		gWindow = NULL;
		gRenderer = NULL;

		//Quit SDL subsystems
		SDL_Quit();
	}
}