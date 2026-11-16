shader_type spatial;
// The Moon from NASA data (assets/source/planet_textures.py): LRO colour and the relief of the LOLA elevation.
uniform sampler2D color_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
void fragment() {
	ALBEDO = texture(color_tex, UV).rgb * 0.72;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 0.75;
	ROUGHNESS = 0.97;
	SPECULAR = 0.05;
}
