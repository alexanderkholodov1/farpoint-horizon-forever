shader_type spatial;
// Triple-junction solar cells laid on a panel. The cell pattern (dark blue cells with cropped corners, silver busbar,
// pale gaps) is a small texture with mipmaps made by ship_builder.gd, so far panels blend to their mean colour instead
// of shimmering. Mapped from the mesh's position (the panel's face is its local XZ plane), so the cells keep their size
// whatever the panel's size.
uniform sampler2D cell_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 cell_size = vec2(0.12, 0.06);
uniform float back_face = 0.0;   // 1 on the panel's back: plain substrate
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec4 t = texture(cell_tex, lp.xz / cell_size);
	vec3 c = t.rgb;
	float cellv = t.a;   // 1 on a cell, 0 on a gap or busbar
	if (back_face > 0.5) { c = vec3(0.12, 0.13, 0.14); cellv = 0.0; }
	ALBEDO = c;
	METALLIC = mix(0.2, 0.5, cellv);
	ROUGHNESS = mix(0.55, 0.14, cellv);
	SPECULAR = mix(0.4, 0.85, cellv);
}
