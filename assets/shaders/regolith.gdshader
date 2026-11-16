shader_type spatial;
// The Moon's ground seen from a lander. The shape and the light come from the mesh (NASA's LOLA heights and the
// sunlight baked into its vertex colours, scripts/flight/terrain.gd). What LOLA's grid is too coarse to hold, the
// small craters and the grain of the regolith, is drawn here: OUR OWN detail, made by a formula and not measured,
// so the ground reads as ground at the scale of a lander. It changes how the surface looks, never its heights.
#include "res://assets/shaders/noise.gdshaderinc"
uniform vec3 tint : source_color = vec3(0.82, 0.8, 0.77);   // the regolith's grey, a little warm
varying vec3 mp;
varying vec3 mn;
varying vec3 vcol;

void vertex() {
	mp = VERTEX;       // metres
	mn = NORMAL;
	vcol = COLOR.rgb;
}

// Bowl-shaped craters with a raised rim, one at most in each cell of a grid `cell` metres wide.
float craters(vec2 p, float cell, float seed) {
	vec2 g = floor(p / cell);
	float h = 0.0;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 c = g + vec2(float(i), float(j));
			if (hash13(vec3(c, seed + 7.7)) < 0.66) {   // most cells are bare ground
				continue;
			}
			vec2 ctr = (c + vec2(hash13(vec3(c, seed)), hash13(vec3(c, seed + 3.1)))) * cell;
			float sz = hash13(vec3(c, seed + 11.3));
			float rad = cell * (0.06 + 0.3 * sz * sz);   // many small ones, few large
			float d = length(p - ctr) / rad;
			if (d < 1.7) {
				float bowl = d < 1.0 ? -(1.0 - d * d) : 0.0;
				float rim = 0.3 * exp(-pow((d - 1.0) * 4.5, 2.0));
				h += (bowl + rim) * rad * 0.22;
			}
		}
	}
	return h;
}

float relief(vec2 p) {
	// shallow: at the pole the Sun grazes the ground, so a little relief already throws long shade
	return craters(p, 70.0, 1.0) * 0.4 + craters(p, 19.0, 5.0) * 0.35 + craters(p, 6.0, 9.0) * 0.3 + (fbm(vec3(p * 0.6, 0.0)) - 0.5) * 0.025;
}

void fragment() {
	vec2 p = mp.xz;
	float fade = 1.0 - smoothstep(180.0, 1400.0, length(VERTEX));   // the detail fades with distance (no shimmer)
	float e = 0.3;
	float h0 = relief(p);
	float hx = relief(p + vec2(e, 0.0));
	float hz = relief(p + vec2(0.0, e));
	vec3 n = normalize(mn + vec3(-(hx - h0) / e, 0.0, -(hz - h0) / e) * fade);
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(n, 0.0)).xyz);
	float grain = 0.88 + 0.24 * vnoise(vec3(p * 2.2, 3.0));
	float soil = 0.92 + 0.16 * fbm(vec3(p * 0.05, 9.0));        // fresh and old ground, lighter and darker
	ALBEDO = vcol * tint * mix(1.0, grain, fade) * soil * (1.0 + clamp(h0, -1.0, 0.3) * 0.08 * fade);
	ROUGHNESS = 1.0;
	SPECULAR = 0.08;
}
