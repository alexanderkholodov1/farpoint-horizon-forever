shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never;
// The thin shell of air beyond the limb (about 100 km on a 6,371 km Earth, so a little over 1.5 % of the radius):
// seen edge-on it glows, brightest just outside the surface and fading to nothing at the top of the air, blue on the
// day side, orange where the day ends, dark on the night side. `inner` is the planet's radius as a part of the shell's.
uniform vec3 glow_color : source_color = vec3(0.32, 0.6, 1.0);
uniform vec3 dusk_color : source_color = vec3(1.0, 0.5, 0.22);
uniform float intensity = 2.6;
uniform float inner = 0.975;
uniform vec3 sun_dir = vec3(0.0, 0.0, 1.0);
void fragment() {
	// how close this point of the shell's silhouette is to the planet's own edge: 0 at the planet, 1 at the top of the air
	float ca = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float sa = sqrt(1.0 - ca * ca);              // sine of the angle to the view: 1 at the shell's edge
	float h = clamp((sa - inner) / (1.0 - inner), 0.0, 1.0);
	float edge = pow(1.0 - h, 1.6);
	float over = smoothstep(inner - 0.25, inner, sa) * (1.0 - step(inner, sa));   // a faint skirt over the disc
	float a = sa >= inner ? edge : over * 0.12;
	vec3 sv = normalize((VIEW_MATRIX * vec4(sun_dir, 0.0)).xyz);
	float ndl = dot(NORMAL, sv);
	float day = smoothstep(-0.3, 0.25, ndl);
	float dusk = smoothstep(-0.3, -0.08, ndl) * (1.0 - smoothstep(-0.08, 0.15, ndl));
	float dusk_k = sa >= inner ? 0.9 : 0.15;   // the sunset tint belongs to the limb, barely to the skirt over the disc
	ALBEDO = (glow_color * day + dusk_color * dusk * dusk_k) * a * intensity;
}
