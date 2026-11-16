shader_type canvas_item;
// Frosted glass for the "clean room" panels: what lies behind the panel (the 3D scene) is blurred and washed with the
// panel's own colour. The panel's StyleBoxFlat draws the shape (rounded corners, hairline border, anti-aliased edges);
// this shader only replaces its fill with blur + tint. Two rings of taps around each pixel: soft enough under the tint,
// cheap enough for a laptop GPU and the browser (no mipmaps needed, which GL Compatibility may not build).
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float tint : hint_range(0.0, 1.0) = 0.8;    // how much of the panel colour covers the blur
uniform float lift : hint_range(0.0, 1.0) = 0.0;    // frost scatters light: the blur is lifted toward lift_to first
uniform vec3 lift_to : source_color = vec3(0.0);       // white for the light appearance, black for the dark one
uniform float radius = 9.0;                         // blur radius in pixels

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * radius;
	vec3 b = texture(screen, SCREEN_UV).rgb * 0.2;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 d = vec2(cos(a), sin(a));
		b += texture(screen, SCREEN_UV + d * px * 0.5).rgb * 0.06;
		b += texture(screen, SCREEN_UV + d.yx * vec2(1.0, -1.0) * px).rgb * 0.04;
	}
	b = mix(b, lift_to, lift);
	COLOR = vec4(mix(b, COLOR.rgb, tint), COLOR.a);
}
