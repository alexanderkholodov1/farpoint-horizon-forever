shader_type spatial;
render_mode blend_mix, unshaded, depth_test_disabled, cull_disabled, shadows_disabled;
// A ring around a part of the craft that a problem comes from: it faces the camera, breathes, and draws over the
// craft so it is seen from any side.
uniform vec4 tint : source_color = vec4(1.0, 0.3, 0.25, 1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float beat = 0.5 + 0.5 * sin(TIME * 4.0);
	float r = 0.78 + 0.08 * beat;
	float ring = smoothstep(0.07, 0.0, abs(d - r));
	float halo = smoothstep(r + 0.2, r, d) * 0.12;
	ALBEDO = tint.rgb;
	ALPHA = clamp(ring + halo, 0.0, 1.0) * (0.75 + 0.25 * beat);
}
