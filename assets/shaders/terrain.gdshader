shader_type spatial;
// The Andes around Cotopaxi (assets/textures/terrain_cotopaxi.png, NASA SRTM). The colour follows the real altitude belts of
// the Ecuadorian highlands: farmland in the valley, golden paramo grass above about 3,600 m, dark volcanic sand and
// scree above about 4,500 m, glacier above about 4,850 m (the snow line of Cotopaxi, simplified), bare rock where the
// slope is too steep to hold snow or grass.
#include "res://assets/shaders/noise.gdshaderinc"
uniform float k = 0.088;           // game units per metre
uniform float base_alt = 3333.0;   // altitude of the pad (y = 0)
varying float alt;
varying vec3 wp;
varying float slope;
void vertex() {
	alt = VERTEX.y / k + base_alt;
	wp = VERTEX;
	slope = 1.0 - NORMAL.y;
}
void fragment() {
	vec3 p = wp / k;                       // metres
	float n1 = fbm(p * 0.0012);
	float n2 = fbm(p * 0.006 + 7.0);
	float n3 = vnoise(p * 0.03);
	// valley: a patchwork of fields
	vec3 cell = floor(p * vec3(1.0 / 260.0, 0.0, 1.0 / 190.0) + vec3(n1 * 2.0, 0.0, n2 * 2.0));
	float f = hash13(cell);
	vec3 field = mix(vec3(0.31, 0.34, 0.2), vec3(0.44, 0.4, 0.28), step(0.55, f));
	field = mix(field, vec3(0.2, 0.25, 0.15), step(0.82, f));
	vec3 paramo = mix(vec3(0.52, 0.47, 0.28), vec3(0.4, 0.4, 0.24), n2);
	vec3 ash = mix(vec3(0.26, 0.21, 0.19), vec3(0.36, 0.3, 0.27), n2);
	vec3 rock = mix(vec3(0.3, 0.29, 0.28), vec3(0.42, 0.4, 0.38), n3);
	vec3 snow = vec3(0.93, 0.95, 0.98) - vec3(0.06) * n3;
	float a = alt + (n1 - 0.5) * 260.0;
	vec3 c = field;
	c = mix(c, paramo, smoothstep(3150.0, 3500.0, a));
	c = mix(c, ash, smoothstep(4400.0, 4600.0, a));
	c = mix(c, rock, smoothstep(0.35, 0.6, slope));
	float snowline = 4850.0 + (n2 - 0.5) * 300.0;
	float s = smoothstep(snowline - 40.0, snowline + 60.0, alt) * (1.0 - smoothstep(0.55, 0.85, slope));
	c = mix(c, snow, s);
	c *= 0.85 + 0.3 * n3;
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.55, s);
	SPECULAR = mix(0.2, 0.45, s);
}
