shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// Soft round puffs for the CPU particles (flames, smoke, explosions), facing the camera like StandardMaterial3D's
// particle billboard. In GL Compatibility (Godot 4.7.2) the particles an emitter has not emitted yet, or will not
// emit after it stops, are still drawn, full size and black, at the emitter: a black disc. Their colour is exactly
// black (every colour we give a living particle is lighter), so they are discarded here.
uniform sampler2D puff : source_color, filter_linear;
void vertex() {
	mat4 w = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * w;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	if (COLOR.r + COLOR.g + COLOR.b < 0.004) {
		discard;
	}
	vec4 t = texture(puff, UV);
	ALBEDO = COLOR.rgb * t.rgb;
	ALPHA = COLOR.a * t.a;
}
