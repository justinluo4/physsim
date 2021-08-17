// physsim.cpp : This file contains the 'main' function. Program execution begins and ends there.
//

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <iostream>
#include <vector>
#include<math.h>
#include<chrono>
#include<thread>
#include <future>
#include <string>
#define SDL_MAIN_HANDLED
#include<SDL2/SDL.h>
#include <sstream>
#include "cdraw.h"
#include "vec.h"

using namespace v;
using namespace draw;

bool quit = false;
int grabbed = -1;

struct PhysObj {
	double mass, rv, radius;
	vec2 vel, pos;
	bool do_gravity, do_collide;
};


auto start = std::chrono::system_clock::now();
auto end = std::chrono::system_clock::now();
vec2 mousepos = { 0, 0 };
vec2 lastmousepos;
vec2 graboffset;
std::stringstream ss;
const double G = 10;
const double CR = 0;
const double FRIC = 1;
const double dt = 0.00001;
int frame_tick = 0;
int tpf = 1;
int N = 1000;
PhysObj* objects;
PhysObj* dev_objects;
PhysObj* dev_objects_write;
__device__
inline vec2 devMul(vec2 v1, double k) {
	return { v1.x * k , v1.y * k };
}
__device__
inline vec2 devAdd(vec2 v1, vec2 v2) {
	return { v1.x + v2.x , v1.y + v2.y };
}
__device__
inline vec2 devSub(vec2 v1, vec2 v2) {
	return { v1.x - v2.x , v1.y - v2.y };
}
__device__
inline double devLen(vec2 v1) {
	return powf(pow(v1.x, 2) + pow(v1.y, 2), 0.5);
}
__device__
inline double devDist(vec2 v1, vec2 v2) {
	return powf(pow(v1.x - v2.x, 2) + pow(v1.y - v2.y, 2), 0.5);
} 
__device__
inline vec2 devNormalize(vec2 v1, vec2 v2) {
	vec2 sub = devSub(v2 , v1);
	sub = devMul(sub, (1.0 / devLen(sub)));
	return sub;
}
__device__
inline double devDot(vec2 v1, vec2 v2) {
	return v1.x * v2.x + v1.y * v2.y;
}
__global__
void collide(int N, PhysObj* objs, PhysObj* objs_write, double CR, double FRIC)
{
	int index = blockIdx.x * blockDim.x + threadIdx.x;
	int i = index / N;
	int j = index % N;
	if (i < N && j < N) {
		PhysObj& obj1 = objs[i];
		PhysObj& obj2 = objs[j];
		double dist = devDist(obj1.pos, obj2.pos);
		if (i < j && objs[i].do_collide && objs[j].do_collide && dist <= obj1.radius + obj2.radius) {
			vec2 dir = devNormalize(obj1.pos, obj2.pos);
			vec2 tan = { -dir.y, dir.x };

			double overlap = obj1.radius + obj2.radius - dist;


			double pv1 = devDot(dir, obj1.vel);
			double pv2 = devDot(dir, obj2.vel);
			double cv1 = FRIC * devDot(tan, obj1.vel);
			double cv2 = FRIC * devDot(tan, obj2.vel);
			double dv1 = (CR * obj2.mass * (pv2 - pv1) + obj1.mass * pv1 + obj2.mass * pv2) / (obj1.mass + obj2.mass);
			double dv2 = (CR * obj1.mass * (pv1 - pv2) + obj1.mass * pv1 + obj2.mass * pv2) / (obj1.mass + obj2.mass);
			vec2 diff = devAdd(devMul(dir, dv1), devMul(tan, cv1));
			atomicAdd(&objs_write[i].vel.x, diff.x -obj1.vel.x);
			atomicAdd(&objs_write[i].vel.y, diff.y -obj1.vel.y);
			diff = devAdd(devMul(dir, dv2), devMul(tan, cv2));
			atomicAdd(&objs_write[j].vel.x, diff.x -obj2.vel.x);
			atomicAdd(&objs_write[j].vel.y, diff.y -obj2.vel.y);
			diff = devMul(dir, overlap * (obj2.mass / (obj1.mass + obj2.mass)) * -1);
			atomicAdd(&objs_write[i].pos.x, diff.x);
			atomicAdd(&objs_write[i].pos.y, diff.y);
			diff = devMul(dir, overlap * (obj1.mass / (obj1.mass + obj2.mass)));
			atomicAdd(&objs_write[j].pos.x, diff.x);
			atomicAdd(&objs_write[j].pos.y, diff.y);
		}
	}

}
__global__
void gravitate(int N, PhysObj* objs, PhysObj* objs_write, double G, double dt) {
	int index = blockIdx.x * blockDim.x + threadIdx.x;
	int i = index / N;
	int j = index % N;
	if (i < N && j < N) {
		PhysObj& obj1 = objs[i];
		PhysObj& obj2 = objs[j];
		if (i != j && objs[i].do_gravity && objs[j].do_gravity) {
			vec2 diff = devMul(devNormalize(obj1.pos, obj2.pos), G * dt * obj2.mass / devDot(devSub(obj2.pos, obj1.pos), devSub(obj2.pos, obj1.pos)));
			atomicAdd(&objs_write[i].vel.x, diff.x);
			atomicAdd(&objs_write[i].vel.y, diff.y);
		}
	}
}
__global__
void step(int N,  PhysObj* objs, PhysObj* objs_write, double dt) {
	int i = blockIdx.x * blockDim.x + threadIdx.x;
	if(i < N){
		PhysObj& obj = objs[i];
		vec2 diff = devMul(obj.vel, dt);
		atomicAdd(&objs_write[i].pos.x, diff.x);
		atomicAdd(&objs_write[i].pos.y, diff.y);
	}

}

void main_loop()
{
	//Handle events on queue
	while (SDL_PollEvent(&e) != 0)
	{
		switch (e.type)
		{
		case SDL_QUIT:
			quit = true;
			break;
		
		case SDL_MOUSEBUTTONDOWN:
			switch (e.button.button)
			{
			case SDL_BUTTON_LEFT:
				mousepos = { (float)e.motion.x / 100, (float)e.motion.y / 100 };
				ss << "X: " << mousepos.x << " Y: " << mousepos.y;

				SDL_SetWindowTitle(gWindow, ss.str().c_str());
				for (int i = 0; i < N; i++) {
					if (dist(mousepos, objects[i].pos) <= objects[i].radius) {
						grabbed = i;
						graboffset = objects[i].pos - mousepos;
					}
				}
				break;
			case SDL_BUTTON_RIGHT:
				grabbed = -1;
				break;
		
			}
			
		}

	}
	int mouseX, mouseY;
	SDL_GetMouseState(&mouseX, &mouseY);
	start = end;
	end = std::chrono::system_clock::now();
	std::chrono::duration<double> elapsed_seconds = end - start;
	lastmousepos = mousepos;
	mousepos = { (float)mouseX / 100, (float)mouseY / 100 };
	if (grabbed != -1) {
		objects[grabbed].pos = mousepos + graboffset;
		objects[grabbed].vel = (mousepos - lastmousepos)*(1/ elapsed_seconds.count());
	}
	//Clear screen
	SDL_SetRenderDrawColor(gRenderer, 0x0, 0x0, 0x0, 0xFF);
	SDL_RenderClear(gRenderer);
	for (int i = 0; i < N; i++) {
		PhysObj& obj = objects[i];
		fill_circle(gRenderer, 100 * obj.pos.x, 100 * obj.pos.y, obj.radius * 100, 0x00, obj.mass / 10, 0xFF, 0xFF);
	}



	//Update screen
	SDL_RenderPresent(gRenderer);
}
int main(int argc, char* args[])
{
	size_t size = N * sizeof(PhysObj);
	objects = (PhysObj*)malloc(size);
	cudaMalloc((void**)&dev_objects, size);
	cudaMalloc((void**)&dev_objects_write, size);
	int blockSize;
	int numBlocks;
	SDL_SetMainReady();
	//Start up SDL and create window
	srand(time(NULL));
	/*
	for(int c = 0; c < 40; c++) {
		double osize = (float)rand() / RAND_MAX * 0.3 + 0.03;
		objects.push_back({ osize*1000, 0.0, osize, {(float)rand() / RAND_MAX * 10 - 5, (float)rand() / RAND_MAX * 10 - 5}, {(float)rand() / RAND_MAX * 10, (float)rand() / RAND_MAX * 5} });
	}*/
	int rows = 50;
	for (int i = 0; i < rows; i++) {
		for (int j = 0; j < N / rows; j++) {
			objects[i+rows*j] = { (double)5, 0, 0.03, {100, 0}, {3+ j * 0.06 , 5 + i*0.06} , true, true};
		}

	}
	objects[0] = { (double)10000, 0, 0.15, {0, 0}, {7.5123 , 2.6} , true, true};
	/*
	for (int j = 0; j < N ; j++) {
		objects[j] = { (double)100, 0, 0.1, {0, 0}, {4 + j * 0.21, 2.0 } };
	}
	*/
	/*
	for (int p = 0; p < 30; p++) {
		objects.push_back({ 50, 0, 0.04, {10, 0}, {p * 0.1, 2.5} });
	}
	for (int p = 0; p < 30; p++) {
		objects.push_back({ 50, 0, 0.04, {-10, 0}, {p * 0.1, 3.5} });
	}
	*/
	if (!init())
	{
		printf("Failed to initialize!\n");
	}
	else
	{
		//Load media
		if (!loadMedia())
		{
			printf("Failed to load media!\n");
		}
		else
		{
#ifdef __EMSCRIPTEN__
			emscripten_set_main_loop(main_loop, 0, 1);
#else

			//While application is running
			while (!quit)
			{
				//Host Collide
				/*
				for (int i = 0; i < N; i++) {
					for (int j = 0; j < N; j++) {
						PhysObj& obj1 = objects[i];
						PhysObj& obj2 = objects[j];
						if ((obj1.pos.x != obj2.pos.x || obj1.pos.y != obj2.pos.y) && dist(obj1.pos, obj2.pos) < obj1.radius + obj2.radius) {
							vec2 dir = normalize(obj1.pos, obj2.pos);
							vec2 tan = { -dir.y, dir.x };

							double overlap = obj1.radius + obj2.radius - dist(obj1.pos, obj2.pos);
							obj1.pos += dir * overlap * (obj2.mass / (obj1.mass + obj2.mass)) * -1;
							obj2.pos += dir * overlap * (obj1.mass / (obj1.mass + obj2.mass));

							double pv1 = dot(dir, obj1.vel);
							double pv2 = dot(dir, obj2.vel);
							double cv1 = dot(tan, obj1.vel);
							double cv2 = dot(tan, obj2.vel);
							double dv1 = (CR * obj2.mass * (pv2 - pv1) + obj1.mass * pv1 + obj2.mass * pv2) / (obj1.mass + obj2.mass);
							double dv2 = (CR * obj1.mass * (pv1 - pv2) + obj1.mass * pv1 + obj2.mass * pv2) / (obj1.mass + obj2.mass);
							obj1.vel = dir * dv1 + tan * cv1;
							obj2.vel = dir * dv2 + tan * cv2;
						}

					}
				}
				*/

				// GPU Section
				blockSize = 256;
				numBlocks = (N*N + blockSize - 1)/blockSize;
				cudaMemcpy(dev_objects, objects, size, cudaMemcpyHostToDevice);
				cudaMemcpy(dev_objects_write, dev_objects, size, cudaMemcpyDeviceToDevice);

				collide << <numBlocks, blockSize >> > (N, dev_objects,dev_objects_write,  CR, FRIC);
				cudaMemcpy(dev_objects, dev_objects_write, size, cudaMemcpyDeviceToDevice);
				step << <numBlocks, blockSize >> > (N, dev_objects, dev_objects_write, dt);
				cudaMemcpy(dev_objects, dev_objects_write, size, cudaMemcpyDeviceToDevice);
				gravitate << <numBlocks, blockSize >> > (N, dev_objects, dev_objects_write, G, dt);

				cudaMemcpy(objects, dev_objects_write, size, cudaMemcpyDeviceToHost);
				cudaDeviceSynchronize();

				// Host Gravitate
				/*
				for (int i = 0; i < N; i++) {
					for (int j = 0; j < N; j++) {
						PhysObj& obj1 = objects[i];
						PhysObj& obj2 = objects[j];
						if (i!=j) {
							obj1.vel += normalize(obj1.pos, obj2.pos) * (G * dt * obj2.mass / (pow(dist(obj1.pos, obj2.pos), 2)));
							obj2.vel += normalize(obj2.pos, obj1.pos) * (G * dt * obj1.mass / (pow(dist(obj1.pos, obj2.pos), 2)));
						}
					}
				}
				*/
				
				if (frame_tick >= tpf) {
					main_loop();
					frame_tick = 0;
				}
				frame_tick++;
				

			}
#endif
		}
	}

	//Free resources and close SDL
	close();
	free(objects);
	return 0;
}
// Run program: Ctrl + F5 or Debug > Start Without Debugging menu
// Debug program: F5 or Debug > Start Debugging menu

// Tips for Getting Started: 
//   1. Use the Solution Explorer window to add/manage files
//   2. Use the Team Explorer window to connect to source control
//   3. Use the Output window to see build output and other messages
//   4. Use the Error List window to view errors
//   5. Go to Project > Add New Item to create new code files, or Project > Add Existing Item to add existing code files to the project
//   6. In the future, to open this project again, go to File > Open > Project and select the .sln file
