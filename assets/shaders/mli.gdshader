shader_type spatial;
// Multi-layer insulation: the crinkled metallized foil wrapped around real spacecraft (gold-coloured Kapton outside, as
// on most science craft, or silver). Crinkles from a cellular-noise normal map, taped seams on a grid, mapped from the
// mesh's own position so a box of any size keeps the same crinkle size.
uniform vec3 foil : source_color = vec3(1.0, 0.7, 0.28);
uniform sampler2D crinkle : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float crinkle_size = 0.6;    // world units per crinkle tile
uniform float seam_every = 0.5;      // blanket width between taped seams
varying vec3 lp;
varying vec3 ln;
void vertex() { lp = VERTEX; ln = NORMAL; }
void fragment() {
	vec3 an = abs(ln);
	vec2 uv = an.x > 0.5 ? lp.zy : (an.y > 0.5 ? lp.xz : lp.xy);
	vec3 nm = texture(crinkle, uv / crinkle_size).rgb;
	vec3 nm2 = texture(crinkle, uv / (crinkle_size * 0.37) + 0.31).rgb;
	NORMAL_MAP = normalize(mix(nm, nm2, 0.4) * 2.0 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.2;
	vec2 g = abs(fract(uv / seam_every) - 0.5);
	float seam = smoothstep(0.47, 0.49, max(g.x, g.y));
	ALBEDO = mix(foil, foil * 0.6, seam);
	METALLIC = 0.45;
	ROUGHNESS = mix(0.16, 0.45, seam);
	SPECULAR = 0.8;
}
