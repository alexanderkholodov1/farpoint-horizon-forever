shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
// The exhaust plume under an engine: brightest and white-hot along its axis near the nozzle, fading toward its
// edges and its tail, so it reads as a glowing jet and not as a solid cylinder.
uniform vec3 glow : source_color = vec3(1.0, 0.6, 0.2);
uniform float strength = 2.0;
void fragment() {
	float flick = 0.85 + 0.15 * sin(TIME * 40.0 + UV.x * 20.0);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));   // 1 looking through the middle, 0 at the silhouette
	float core = pow(facing, 2.5);
	float along = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.6);            // bright at the nozzle, gone at the tail
	vec3 col = mix(glow, vec3(1.0, 0.95, 0.85), core * along);
	ALBEDO = col * strength * flick * along * core;
}
