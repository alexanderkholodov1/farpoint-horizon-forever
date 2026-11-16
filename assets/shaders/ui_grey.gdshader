shader_type canvas_item;
// Whatever it draws, in grey: a mission that is not open yet (scripts/screens/missions.gd). The card and everything
// in it use this material, so the picture, the words and the chips all lose their colour.
uniform float dim : hint_range(0.0, 1.0) = 0.75;
void fragment() {
	float g = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = vec3(g) * dim;
}
