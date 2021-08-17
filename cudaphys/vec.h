#pragma once
#include<math.h>
namespace v {
	struct vec2 {
		double x, y;
		double len() {
			return pow(pow(x, 2) + pow(y, 2), 0.5);
		}
		void norm() {
			y = y / this->len();
			x = x / this->len();
		}
		struct vec2& operator+=(const vec2& rhs) { x += rhs.x; y += rhs.y; return *this; }
		struct vec2& operator-=(const vec2& rhs) { x -= rhs.x; y -= rhs.y; return *this; }
		struct vec2& operator*=(const vec2& rhs) { x *= rhs.x; y *= rhs.y; return *this; }
		struct vec2& operator*=(const double& rhs) { x *= rhs; y *= rhs; return *this; }
	};
	vec2 operator+(vec2 lhs, const vec2& rhs) { return lhs += rhs; }
	vec2 operator-(vec2 lhs, const vec2& rhs) { return lhs -= rhs; }
	vec2 operator*(vec2 lhs, const vec2& rhs) { return lhs *= rhs; }
	vec2 operator*(vec2 lhs, const double k) { return lhs *= k; }
	vec2 normalize(vec2 p1, vec2 p2) {
		vec2 sub = p2 - p1;
		sub *= (1.0 / sub.len());
		return sub;
	}
	double dot(vec2 p1, vec2 p2) {
		return p1.x * p2.x + p1.y * p2.y;
	}
	double dist(vec2 o1, vec2 o2) {
		return pow(pow(o1.x - o2.x, 2) + pow(o1.y - o2.y, 2), 0.5);
	}
}