shader_type sky;
// Space as seen from outside the air: black, and full of stars. Thousands of faint ones, fewer bright ones, and the
// band of the Milky Way, where they crowd together over a soft glow broken by dark lanes of dust. The stars are OUR
// OWN, scattered by a formula, not a catalogue of the real sky: they say "deep space", not which star is which.
#include "res://assets/shaders/noise.gdshaderinc"
uniform float star_density = 0.996;   // kept for older callers; the layers below set their own

// One layer of stars: a grid `scale` cells across a radian, a star in the cells whose hash passes `thr`, drawn `rad`
// of a cell wide (the finest layers need wide dots, or they fall between the screen's pixels and vanish).
float star_layer(vec3 d, float scale, float thr, float rad) {
	vec3 p = d * scale;
	vec3 i = floor(p);
	vec3 f = fract(p) - 0.5;
	float h = hash13(i);
	if (h < thr) return 0.0;
	vec3 off = vec3(hash13(i + 7.0), hash13(i + 13.0), hash13(i + 29.0)) - 0.5;
	float dist = length(f - off * 0.6);
	float b = (h - thr) / (1.0 - thr);
	return smoothstep(rad, 0.0, dist) * (0.4 + 1.6 * b);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 col = vec3(0.003, 0.004, 0.009);
	// the Milky Way: a great circle across the sky
	vec3 pole = normalize(vec3(0.35, 0.86, 0.36));
	float lat = dot(d, pole);
	float band = exp(-lat * lat * 14.0);
	float cloud = fbm(d * 3.2 + vec3(5.0));
	float lanes = smoothstep(0.42, 0.7, fbm(d * 7.0 + vec3(11.0)));
	col += vec3(0.1, 0.105, 0.125) * band * (0.35 + cloud) * (1.0 - 0.75 * lanes * band);
	col += vec3(0.05, 0.035, 0.02) * band * band * smoothstep(0.5, 0.9, cloud);   // its warm heart
	// stars: a fine dust everywhere, thicker in the band; then the ones the eye picks out; then a few bright ones
	float crowd = 1.0 + 2.2 * band;
	float s = star_layer(d, 520.0, 0.972, 0.36) * 0.5 * crowd;
	s += star_layer(d, 300.0, 0.978, 0.3) * 0.8 * (0.7 + 0.6 * band);
	s += star_layer(d, 170.0, 0.988, 0.2);
	s += star_layer(d, 85.0, 0.9972, 0.13) * 1.9;
	vec3 tint = mix(vec3(0.78, 0.86, 1.0), vec3(1.0, 0.88, 0.7), hash13(floor(d * 170.0)));
	col += s * tint;
	// the Sun
	float sun = max(dot(d, LIGHT0_DIRECTION), 0.0);
	col += vec3(1.0, 0.9, 0.7) * (pow(sun, 2000.0) * 40.0 + pow(sun, 80.0) * 0.4);
	COLOR = col;
}
