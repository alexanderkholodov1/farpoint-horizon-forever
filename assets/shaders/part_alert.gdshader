shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never;
// Drawn over a part of the craft (as its material_overlay) when a check of the mission comes from it: a soft rim of
// the warning colour that breathes, strongest at the edges, so the part still reads underneath.
uniform vec4 tint : source_color = vec4(1.0, 0.3, 0.25, 1.0);
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float beat = 0.55 + 0.45 * sin(TIME * 4.0);
	ALBEDO = tint.rgb * (0.3 + rim * 1.2) * beat * tint.a;
}
