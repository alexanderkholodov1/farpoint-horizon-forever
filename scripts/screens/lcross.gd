extends "res://scripts/screens/screen.gd"
## Mission 4, LCROSS (October 9, 2009): "The plan is to crash?" (issue #48). The crew fly it from mission control.
## (1) The aim, at separation (01:50 UT): on NASA's LROC mosaic of the south pole the Centaur's predicted impact point
## is nudged with small burns (WASD or arrows) into the shadowed floor of Cabeus; Enter lets it go. Time runs 5,000
## times faster to 6 s before the impact (said on screen). (2) The impact and the four minutes, 11:31:19.5 to
## 11:35:36.1 UT, seen through the shepherding craft's camera as it falls at about 2.5 km/s: a countdown, the flash,
## the shock ring, the plume rising into the sunlight. Shown 4 times faster (said on screen), real time for the last
## 15 km. Glints of ice fly out of the plume (clumps of ejecta, our simplification); the player chases each one with
## the crosshair (mouse or WASD), through the craft's wobbles, and catches it with Space: one reading each, combos for
## catches in a row; a press with no glint pauses the instruments. Then the ground rushes up and the signal is lost.
## Outside Cabeus, on its sunlit floor, or too few readings: a lose screen, tried again. Rules:
## scripts/missions/lcross/impact.gd; data: data/missions/lcross.json. The world is in km: the south pole at the
## origin, the map's x as x and its y as z.

const TouchKeys := preload("res://scripts/ui/touch_keys.gd")
const Progress := preload("res://scripts/story/campaign_progress.gd")
const Impact := preload("res://scripts/missions/lcross/impact.gd")
const Sets := preload("res://scripts/story/sets.gd")
const Space := preload("res://scripts/world/space_builder.gd")
const Sound := preload("res://scripts/flight/sound.gd")
const VIEW_DIR := Vector3(0.18, 1.0, 0.5)   ## From the impact point toward the falling craft (our simplification).

var I: Impact
var T: Dictionary
var campaign := false
var then_scenes: Array = []
var back := "menu"
var saved := {}
var phase := "brief"           ## brief, aim, warp, fall, four, end, done, lost
var phase_t := 0.0
var _t := 0.0
var t := 0.0                   ## Seconds after the Centaur's impact (negative before).
var aim_off := Vector2.ZERO    ## Where the camera points, away from the plume (degrees).
var drift := Vector2.ZERO
var _mouse := Vector2.ZERO
var impact_at := Vector3.ZERO  ## The impact point in the world (km).
var verdict := ""
var next_wobble := 18.0
var shake := 0.0
var combo := 0
var best_combo := 0
var glints: Array = []         ## {node, pos, vel, pulse}
var _jit: Array = []           ## Fixed offsets that fill out the drawn plume around each grain.
var _spawned := {}
var result_shown := false
var thump: AudioStreamPlayer
# the five stages
var armed: Array = []          ## Each instrument: "" waiting, "on", "missed".
var arm_i := -1                ## The instrument lit now.
var flash_q := -1.0            ## How well the flash was caught (-1: not yet).
var dive_p := Vector2.ZERO     ## Our craft's miss from the Centaur's crater, sideways (km).
var dive_v := Vector2.ZERO
var dive_sum := 0.0
var dive_n := 0
var stage_rows: Array = []
var stage_names: Array = []
var arm_panel: PanelContainer
var arm_tiles: Array = []
var meter: Control
var data_bar: Control
# the world
var cap: MeshInstance3D
var plume: MultiMeshInstance3D
var flash_l: OmniLight3D
var flash_ball: MeshInstance3D
var ring: MeshInstance3D
var glint_mat: ShaderMaterial
var dust_mat: ShaderMaterial
var burst: CPUParticles3D
# interface
var head_title: Label
var clock_lbl: Label
var clock_sub: Label
var speed_lbl: Label
var who_chip: PanelContainer
var radio: Label
var hint: Label
var hint_panel: PanelContainer
var big: Label
var big_sub: Label
var shout_panel: PanelContainer
var count_lbl: Label
var count_panel: PanelContainer
var now_lbl: Label
var now_panel: PanelContainer
var bubble: Label
var flash: ColorRect
var fx: ColorRect
var map_view: Control
var map_panel: PanelContainer
var aim_info: Label
var side_panel: PanelContainer
var spectrum: Control
var reads_lbl: Label
var combo_lbl: Label
var cross: Control
var tags: Control
var brief: Control
var lose_layer: Control


func enter(args: Dictionary) -> void:
	campaign = args.get("campaign", false)
	then_scenes = args.get("then", [])
	back = args.get("back", "menu")
	I = Impact.new()
	T = I.D.texts
	saved = Sets.save_world(world)
	world.cam_free = false
	_build_world()
	thump = Sound.player(self, "thud", -2.0)
	_build_ui()
	impact_at = Vector3(I.point.x, 0.0, I.point.y)
	_say("Wayra", tr("Separation at 01:50 UT. The Centaur is ours to aim, nine hours and forty minutes before it hits."))
	_show_brief()
	_phone_layout()
	TouchKeys.attach(self)


func exit() -> void:
	Sets.restore_world(world, saved)


# ===================================================================================== THE WORLD (km)
## A soft round glow that always faces the camera; its colour from the instance (multimesh) or from "tint".
func _soft(code_color: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color = vec4(1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, 1, 0), vec4(0, 0, 0, 1));
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = pow(clamp(1.0 - d, 0.0, 1.0), 1.7);
	vec4 c = %s;
	ALBEDO = c.rgb * c.a * a;
}
""" % code_color
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _build_world() -> void:
	world.clear_stage()
	var env: Environment = world.world_env.environment
	env.sky = Space.make_space_sky()
	env.background_energy_multiplier = 1.0
	env.fog_enabled = false
	env.glow_enabled = true
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.ambient_light_energy = 0.3
	world.sun.light_energy = 0.0
	world.cam.fov = 42.0
	world.cam.near = 0.02
	world.cam.far = 9000.0
	var st: Node3D = world.stage
	var R := float(I.A.moon_radius_km)
	# the whole Moon below, its real map, for the horizon (south pole up)
	var moon := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = R - 1.5
	sm.height = (R - 1.5) * 2.0
	sm.radial_segments = 128
	sm.rings = 64
	moon.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_texture = Space.MOON_COLOR
	mm.albedo_color = Color(0.16, 0.16, 0.17)
	moon.material_override = mm
	moon.position = Vector3(0, -R, 0)
	moon.rotation.x = PI
	st.add_child(moon)
	# the south pole as NASA's LROC camera saw it, curved with the Moon; a fine grain added close up (drawn for the
	# game: the mosaic's pixel is about 0.67 km)
	cap = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	var half := I.km_px * float(I.A.map_px) * 0.5
	pm.size = Vector2(half * 2.0, half * 2.0)
	pm.subdivide_width = 160
	pm.subdivide_depth = 160
	cap.mesh = pm
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D map : source_color, filter_linear_mipmap;
uniform float R = 1737.4;
varying vec2 wp;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	wp = VERTEX.xz;
	VERTEX.y -= (VERTEX.x * VERTEX.x + VERTEX.z * VERTEX.z) / (2.0 * R);
}
vec2 h2(vec2 p) { return vec2(h(p), h(p + vec2(17.3, 5.1))); }
// small craters: in each cell a bowl, its rim lit toward the low Sun (from -x), its far wall in shade
float craters(vec2 p) {
	vec2 i = floor(p);
	float s = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = i + vec2(float(x), float(y));
			vec2 o = h2(c);
			float rad = 0.18 + 0.32 * h(c + 3.7);
			vec2 d = (p - c - o) / rad;
			float l = length(d);
			if (l < 1.25 && h(c + 9.1) > 0.45) {
				float bowl = smoothstep(1.0, 0.2, l) * (0.5 + 0.5 * d.x);
				float rim = smoothstep(0.75, 1.0, l) * smoothstep(1.25, 1.0, l) * (0.5 - 0.5 * d.x);
				s += rim * 0.6 - bowl * 0.55;
			}
		}
	}
	return s;
}
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	if (r > 1.0) { discard; }
	// hard lunar light: crisp shadow edges from NASA's light and shade, so the ground reads as rock
	float L0 = texture(map, UV).r;
	float edge = smoothstep(0.09, 0.14, L0 + (n(wp * 2.0) - 0.5) * 0.05);
	vec3 c = vec3(0.1 + 0.75 * L0) * mix(0.08, 1.0, edge);
	float g = n(wp * 1.3) * 0.5 + n(wp * 4.1) * 0.3 + n(wp * 11.0) * 0.2;
	float k = craters(wp * 0.22) * 0.7 + craters(wp * 0.9) * 0.45 + craters(wp * 3.2) * 0.25;
	// the regolith's own grey where the Sun reaches, so lit ground reads as rock, not as cloud
	float lit = smoothstep(0.05, 0.35, c.r);
	c = mix(c, vec3(0.42, 0.41, 0.4) * (0.6 + c.r), 0.35 * lit);
	c *= clamp(0.8 + 0.3 * g + k * lit, 0.2, 1.4);
	ALBEDO = mix(c, vec3(0.13), smoothstep(0.82, 1.0, r));
}
"""
	var smat := ShaderMaterial.new()
	smat.shader = sh
	smat.set_shader_parameter("map", load(I.A.map))
	smat.set_shader_parameter("R", R)
	cap.material_override = smat
	st.add_child(cap)
	# the plume: one soft grain per ejecta grain of the rules, bright once in the sunlight
	plume = MultiMeshInstance3D.new()
	var mmesh := MultiMesh.new()
	mmesh.transform_format = MultiMesh.TRANSFORM_3D
	mmesh.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(2.4, 2.4)
	mmesh.mesh = q
	mmesh.instance_count = Impact.N * 4
	plume.multimesh = mmesh
	plume.material_override = _soft("COLOR")
	var jr := RandomNumberGenerator.new()
	jr.seed = 7
	for k in 97:
		_jit.append(Vector3(jr.randf_range(-1, 1), jr.randf_range(-0.6, 0.6), jr.randf_range(-1, 1)))
	plume.visible = false
	st.add_child(plume)
	glint_mat = _soft("tint")
	glint_mat.set_shader_parameter("tint", Color(0.6, 0.85, 1.0, 1.0))
	dust_mat = _soft("tint")
	dust_mat.set_shader_parameter("tint", Color(0.75, 0.6, 0.45, 0.9))
	# the impact: a light, a white fireball and a shock ring along the ground
	flash_l = OmniLight3D.new()
	flash_l.light_color = Color(1.0, 0.9, 0.7)
	flash_l.omni_range = 150.0
	flash_l.light_energy = 0.0
	st.add_child(flash_l)
	flash_ball = MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(2, 2)
	flash_ball.mesh = fq
	flash_ball.material_override = _soft("tint")
	(flash_ball.material_override as ShaderMaterial).set_shader_parameter("tint", Color(1.0, 0.92, 0.75, 0.0))
	st.add_child(flash_ball)
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 64
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.albedo_color = Color(1.0, 0.85, 0.6, 0.0)
	ring.material_override = rm
	ring.visible = false
	st.add_child(ring)
	# a burst of sparkles where a glint is caught
	burst = CPUParticles3D.new()
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 60
	burst.lifetime = 0.9
	burst.explosiveness = 1.0
	burst.direction = Vector3.UP
	burst.spread = 180.0
	burst.initial_velocity_min = 3.0
	burst.initial_velocity_max = 9.0
	burst.gravity = Vector3.ZERO
	burst.damping_min = 4.0
	burst.damping_max = 6.0
	var bq := QuadMesh.new()
	bq.size = Vector2(0.6, 0.6)
	burst.mesh = bq
	burst.material_override = glint_mat
	st.add_child(burst)


# ===================================================================================== THE INTERFACE
func _card() -> PanelContainer:
	var p := Kit.panel_box(12)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _build_ui() -> void:
	# the camera's own look: a dark edge, scan lines, a fine grain, and static when the signal goes
	fx = ColorRect.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fsh := Shader.new()
	fsh.code = """
shader_type canvas_item;
uniform float vig = 0.0;
uniform float noise = 0.0;
void fragment() {
	float v = smoothstep(0.95, 0.35, length((UV - vec2(0.5)) * vec2(1.25, 1.0)));
	vec2 cell = floor(UV * vec2(400.0, 225.0));
	float n = fract(sin(dot(cell, vec2(12.9898, 78.233)) + fract(TIME * 7.31) * 437.585) * 43758.5453);
	float scan = 0.5 + 0.5 * sin(UV.y * 900.0);
	float a = (1.0 - v) * vig * 0.8 + vig * 0.05 * scan + vig * 0.04 * n;
	vec3 c = vec3(n) * noise;
	COLOR = vec4(c, clamp(a + noise * 0.97, 0.0, 1.0));
}
"""
	var fm := ShaderMaterial.new()
	fm.shader = fsh
	fx.material = fm
	add_child(fx)
	# the crosshair over the whole view
	cross = Crosshair.new()
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(cross as Crosshair).hit_px = float(I.P.hit_px)
	cross.visible = false
	add_child(cross)
	# labels on the world (the Centaur, Cabeus, the glints)
	tags = Tags.new()
	tags.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tags)
	var head := Kit.vbox(2)
	Kit.place(head, 0, 0, 0, 0, Kit.MARGIN, Kit.MARGIN, 560, 100)
	add_child(head)
	var over := Kit.caps(tr("Mission 4 · LCROSS · October 9, 2009"))
	over.add_theme_color_override("font_color", Color(Kit.C_ON_DARK, 0.8))
	head.add_child(over)
	head_title = Kit.lbl(tr("Aim at Cabeus"), Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T)
	head.add_child(head_title)
	# the clock, top middle
	var cp := Kit.panel_box(Kit.PAD)
	Kit.place(cp, 0.5, 0, 0.5, 0, -190, Kit.MARGIN, 190, Kit.MARGIN + 130)
	add_child(cp)
	var cv := Kit.vbox(0)
	cp.add_child(cv)
	var cap_l := Kit.caps(tr("Mission time"))
	cap_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(cap_l)
	clock_lbl = Kit.lbl("01:50:00.0 UT", Kit.T_CLOCK + 6, Kit.C_GOLD, Kit.font_num())
	clock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(clock_lbl)
	clock_sub = Kit.lbl("", Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B)
	clock_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(clock_sub)
	speed_lbl = Kit.lbl(tr("Real time"), Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R)
	speed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(speed_lbl)
	# the crew on the radio
	var hp := Kit.panel_box(Kit.PAD)
	Kit.place(hp, 1, 0, 1, 0, -Kit.MARGIN - 430, Kit.MARGIN, -Kit.MARGIN, Kit.MARGIN + 60)
	add_child(hp)
	var hv := Kit.vbox(Kit.GAP)
	hp.add_child(hv)
	var hh := Kit.hbox(Kit.GAP)
	hv.add_child(hh)
	who_chip = Kit.chip("Wayra", Kit.C_ACCENT)
	hh.add_child(who_chip)
	hh.add_child(Kit.lbl(tr("Mission control"), Kit.T_SMALL, Kit.C_DIM))
	radio = Kit.lbl("", Kit.T_ACTION - 2, Kit.C_TEXT, Kit.FONT_B, true)
	radio.custom_minimum_size.x = 380
	hv.add_child(radio)
	# the aim: NASA's map of the south pole
	map_panel = Kit.panel_box(10)
	Kit.place(map_panel, 0.5, 0.5, 0.5, 0.5, -330, -260, 330, 300)
	add_child(map_panel)
	var mv := Kit.vbox(6)
	map_panel.add_child(mv)
	map_view = MapView.new()
	map_view.I = I
	map_view.custom_minimum_size = Vector2(500, 500)
	map_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mv.add_child(map_view)
	aim_info = Kit.lbl("", Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B, true)
	aim_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(aim_info)
	var credit := Kit.lbl(tr("The south pole from above: NASA/GSFC/Arizona State University, LRO"), Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(credit)
	# the five stages, left: done, now, still to come
	var stp := _card()
	Kit.place(stp, 0, 0, 0, 0, Kit.MARGIN, 120, Kit.MARGIN + 10, 130)
	add_child(stp)
	var stv := Kit.vbox(4)
	stp.add_child(stv)
	stv.add_child(Kit.caps(tr("The mission")))
	for nm in [tr("Aim the Centaur"), tr("Turn on the instruments"), tr("Catch the flash"), tr("Catch the ice"), tr("Dive onto the crater")]:
		stage_names.append(nm)
		var l := Kit.lbl(nm, Kit.T_BODY, Kit.C_DIM, Kit.FONT_B)
		stv.add_child(l)
		stage_rows.append(l)
	# the instruments to turn on: six tiles, a number key each
	arm_panel = _card()
	Kit.place(arm_panel, 0.5, 1, 0.5, 1, -10, -320, 10, -310)
	arm_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(arm_panel)
	var av := Kit.vbox(6)
	arm_panel.add_child(av)
	var at := Kit.caps(tr("Turn on the instruments: press the number when it lights up"))
	at.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av.add_child(at)
	var ah := Kit.hbox(8)
	av.add_child(ah)
	for i in I.D.stages.instruments.size():
		armed.append("")
		var tile := PanelContainer.new()
		tile.custom_minimum_size = Vector2(150, 74)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tv := Kit.vbox(0)
		tile.add_child(tv)
		var k := Kit.lbl(str(i + 1), Kit.T_CLOCK, Kit.C_TEXT, Kit.FONT_T)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tv.add_child(k)
		var nl := Kit.lbl(tr(I.D.stages.instruments[i]), Kit.T_SMALL, Kit.C_TEXT, Kit.FONT_B, true)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.custom_minimum_size.x = 140
		tv.add_child(nl)
		ah.add_child(tile)
		arm_tiles.append(tile)
	arm_panel.visible = false
	# the flash meter: the photometer's light, rising and falling
	meter = FlashMeter.new()
	meter.custom_minimum_size = Vector2(520, 70)
	Kit.place(meter, 0.5, 1, 0.5, 1, -260, -290, 260, -220)
	meter.visible = false
	add_child(meter)
	# the instruments: the spectrum, the readings and the combo
	side_panel = Kit.panel_box(10)
	Kit.place(side_panel, 1, 1, 1, 1, -Kit.MARGIN - 400, -Kit.MARGIN - 250, -Kit.MARGIN, -Kit.MARGIN)
	add_child(side_panel)
	var iv := Kit.vbox(6)
	side_panel.add_child(iv)
	iv.add_child(Kit.caps(tr("The instruments, live")))
	spectrum = Spectrum.new()
	spectrum.custom_minimum_size = Vector2(380, 100)
	iv.add_child(spectrum)
	data_bar = DataBar.new()
	data_bar.custom_minimum_size = Vector2(380, 34)
	iv.add_child(data_bar)
	reads_lbl = Kit.lbl("", Kit.T_BODY, Kit.C_GOLD, Kit.FONT_B)
	iv.add_child(reads_lbl)
	combo_lbl = Kit.lbl("", Kit.T_BODY, Kit.C_ACCENT, Kit.FONT_B)
	iv.add_child(combo_lbl)
	side_panel.visible = false
	# what to do now, bottom left
	hint = Kit.lbl("", Kit.T_ACTION, Kit.C_ON_DARK, Kit.FONT_B, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_panel = _card()
	Kit.place(hint_panel, 0, 1, 0, 1, Kit.MARGIN, -130, Kit.MARGIN + 700, -Kit.MARGIN)
	hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_panel.add_child(hint)
	add_child(hint_panel)
	shout_panel = _card()
	Kit.place(shout_panel, 0.5, 0, 0.5, 0, -10, Kit.MARGIN + 176, 10, Kit.MARGIN + 186)
	shout_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(shout_panel)
	var sb := Kit.vbox(2)
	shout_panel.add_child(sb)
	big = Kit.lbl("", Kit.T_SHOUT, Kit.C_GOLD, Kit.FONT_T)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sb.add_child(big)
	big_sub = Kit.lbl("", Kit.T_ACTION, Kit.C_TEXT, Kit.FONT_B)
	big_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sb.add_child(big_sub)
	# the countdown, on its own small card under the clock, clear of the crosshair
	count_panel = _card()
	Kit.place(count_panel, 0.5, 0, 0.5, 0, -10, Kit.MARGIN + 176, 10, Kit.MARGIN + 186)
	count_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(count_panel)
	count_lbl = Kit.lbl("", Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_panel.add_child(count_lbl)
	# the call to act, above the hint
	now_panel = _card()
	Kit.place(now_panel, 0.5, 1, 0.5, 1, -10, -300, 10, -290)
	now_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(now_panel)
	now_lbl = Kit.lbl("", Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T)
	now_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	now_panel.add_child(now_lbl)
	# what a catch or a miss says, right of the crosshair
	bubble = Kit.lbl("", Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T)
	Kit.place(bubble, 0.5, 0.5, 0.5, 0.5, 110, -40, 560, 20)
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # a long call wraps instead of leaving the screen
	bubble.add_theme_constant_override("outline_size", 8)
	bubble.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	add_child(bubble)
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 1, 1, 0)
	add_child(flash)


func _say(who: String, text: String) -> void:
	radio.text = text
	var l := who_chip.get_child(0) as Label
	if l:
		l.text = who


func _shout(a: String, b := "", col := Kit.C_GOLD) -> void:
	big.text = a
	big_sub.text = b
	big.add_theme_color_override("font_color", col)


func _pop(text: String, col: Color) -> void:
	bubble.text = text
	# a long call in a smaller size; under the crosshair while a headline is up, so two never read at once
	bubble.add_theme_font_size_override("font_size", Kit.T_CLOCK if text.length() <= 22 else Kit.T_ACTION)
	bubble.offset_top = 60.0 if big.text != "" else -40.0
	bubble.offset_bottom = bubble.offset_top + 60.0
	bubble.add_theme_color_override("font_color", col)
	bubble.pivot_offset = Vector2(0, 30)
	bubble.scale = Vector2(1.5, 1.5)
	bubble.modulate.a = 1.0
	var tw := bubble.create_tween()
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.7)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.4)


## How to play, in two steps, before anything moves.
func _show_brief() -> void:
	brief = Control.new()
	brief.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(brief)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brief.add_child(shade)
	var p := Kit.panel_box(Kit.PAD)
	Kit.place(p, 0.5, 0.5, 0.5, 0.5, -440, -320, 440, 320)
	brief.add_child(p)
	var v := Kit.vbox(Kit.GAP)
	p.add_child(v)
	v.add_child(Kit.caps(tr("How to play")))
	v.add_child(Kit.lbl(tr("Two crashes, on purpose"), Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T))
	for row in [["1", tr("Aim the Centaur at Cabeus's dark floor"), tr("WASD or the arrows: small burns. Ice hides in the shadow.")],
			["2", tr("Turn on the instruments"), tr("Keys 1 to 6, each when it lights up, before the impact.")],
			["3", tr("Catch the flash"), tr("SPACE at the peak of the impact's light.")],
			["4", tr("Catch the ice in the plume"), tr("Chase the blue glints with the crosshair (mouse or WASD), SPACE. Grey ones are dust: leave them.")],
			["5", tr("Dive onto the crater"), tr("Steer our craft onto the Centaur's fresh crater, 20 m wide.")]]:
		var h := Kit.hbox(Kit.PAD)
		v.add_child(h)
		h.add_child(Kit.lbl(row[0], Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T))
		var tv := Kit.vbox(0)
		h.add_child(tv)
		tv.add_child(Kit.lbl(row[1], Kit.T_ACTION - 2, Kit.C_TEXT, Kit.FONT_B))
		var d := Kit.lbl(row[2], Kit.T_BODY, Kit.C_DIM, Kit.FONT_R, true)
		d.custom_minimum_size.x = 640
		tv.add_child(d)
	v.add_child(Kit.lbl(tr("Each stage sends data to Earth. At least %d%% before our craft hits too.") % int(I.D.stages.need), Kit.T_SMALL + 1, Kit.C_DIM, Kit.FONT_R, true))
	var go_btn := Kit.btn(tr("Start  ·  Enter"), _start, Kit.T_BODY)
	Kit.accent_btn(go_btn, Kit.C_GOLD)
	v.add_child(go_btn)
	go_btn.grab_focus()


func _start() -> void:
	if phase != "brief":
		return
	if brief and is_instance_valid(brief):
		brief.queue_free()
	phase = "aim"
	phase_t = 0.0
	t = -float(I.A.seconds_left)
	hint.text = tr(T.aim)
	_say("Rumi", tr("Every quarter meter per second moves the impact about 9 km. Do not waste them."))


# ===================================================================================== THE AIM
func _nudge(dir: Vector2) -> void:
	if I.nudge(dir):
		Kit.UiSound.play("click")
	else:
		_say("Rumi", tr("No more trim. That is where it goes."))


func _release() -> void:
	verdict = I.verdict()
	impact_at = Vector3(I.point.x, 0.0, I.point.y)
	impact_at.y = -(impact_at.x * impact_at.x + impact_at.z * impact_at.z) / (2.0 * float(I.A.moon_radius_km))
	phase = "warp"
	phase_t = 0.0
	head_title.text = tr("The four minutes")
	hint.text = tr(T.warp)
	_say("Wayra", tr("Centaur released. See you at 11:31 UT."))
	Kit.UiSound.play("whoosh")


# ===================================================================================== THE IMPACT AND THE FOUR MINUTES
func _impact() -> void:
	phase = "four"
	phase_t = 0.0
	count_lbl.text = ""
	flash.color = Color(1, 0.97, 0.9, 1.0)
	flash_l.position = impact_at + Vector3(0, 2, 0)
	flash_l.light_energy = 40.0
	flash_ball.position = impact_at + Vector3(0, 0.5, 0)
	ring.position = impact_at + Vector3(0, 0.05, 0)
	ring.visible = true
	shake = 1.2
	thump.play()
	Kit.UiSound.play("whoosh")
	if verdict != "in":
		_lose(tr(T.missed if verdict == "missed" else T.sunlit), tr(T.missed_sub if verdict == "missed" else T.sunlit_sub))
		return
	plume.visible = true
	side_panel.visible = true
	arm_panel.visible = false
	phase = "flash"
	phase_t = 0.0
	meter.visible = true
	_shout(tr(T.hit), tr(T.hit_sub))
	hint.text = tr(T.flash)
	_say("Rumi", tr("Photometer: catch the peak of the flash!"))
	aim_off = Vector2(0.6, -0.4)


func _flash_level(s_: float) -> float:
	var pk := float(I.D.stages.flash_peak_s)
	var x := maxf(s_, 0.0) / pk
	return clampf(x * exp(1.0 - x), 0.0, 1.0)


## The photometer's reading of the flash: press_s seconds after the impact, or -1 for no press.
func _flash_result(press_s: float) -> void:
	var on: bool = armed[armed.size() - 1] == "on"
	if not on:
		flash_q = 0.0
		_pop(tr("The photometer was off!"), Kit.C_BAD)
		return
	flash_q = I.flash_quality(press_s) if press_s >= 0.0 else 0.0
	if flash_q > 0.8:
		_pop(tr("Perfect flash!"), Kit.C_GOLD)
		Kit.UiSound.play("success")
	elif flash_q > 0.3:
		_pop(tr("Good flash"), Kit.C_GOLD)
		Kit.UiSound.play("snap")
	else:
		_pop(tr("Missed the flash"), Kit.C_BAD)
		Kit.UiSound.play("error")


func _start_plume() -> void:
	phase = "four"
	phase_t = 0.0
	meter.visible = false
	hint.text = tr(T.read)
	_say("Killa", tr("Plume! Watch for the ice. I read, you catch."))


# ===================================================================================== STAGE 2: THE INSTRUMENTS
func _arming() -> void:
	var S: Dictionary = I.D.stages
	var k := int(floor((t - float(S.arm_start_s)) / float(S.arm_step_s)))
	var in_win := t - float(S.arm_start_s) - k * float(S.arm_step_s) <= float(S.arm_window_s)
	var now := k if k >= 0 and k < armed.size() and in_win else -1
	if now != arm_i:
		if arm_i >= 0 and armed[arm_i] == "":
			armed[arm_i] = "missed"
			Kit.UiSound.play("error")
		arm_i = now
		if arm_i >= 0:
			Kit.UiSound.play("notify")
			_say("Killa", tr("%s, now!") % tr(S.instruments[arm_i]))
	for i in arm_tiles.size():
		var col := Color(0.2, 0.22, 0.28, 0.9)
		if armed[i] == "on":
			col = Color(0.2, 0.55, 0.3, 0.95)
		elif armed[i] == "missed":
			col = Color(0.55, 0.18, 0.15, 0.95)
		elif i == arm_i:
			col = Color(0.85, 0.6, 0.15, 0.7 + 0.3 * sin(_t * 14.0))
		(arm_tiles[i] as PanelContainer).add_theme_stylebox_override("panel", Kit.flat(col, Color(1, 1, 1, 0.25 if i == arm_i else 0.05), 10, 2, 6, 6))


func _arm_key(n: int) -> void:
	if arm_i == n and armed[n] == "":
		armed[n] = "on"
		Kit.UiSound.play("snap")
		_pop(tr("%s on!") % tr(I.D.stages.instruments[n]), Kit.C_OK)
	elif n >= 0 and n < armed.size() and armed[n] == "":
		Kit.UiSound.play("error")
		_pop(tr("Not that one yet!"), Kit.C_BAD)


func _armed_n() -> int:
	var n := 0
	for a in armed:
		if a == "on":
			n += 1
	return n


# ===================================================================================== STAGE 5: THE DIVE
func _start_dive() -> void:
	phase = "dive"
	phase_t = 0.0
	for gl in glints:
		(gl.node as Node3D).queue_free()
	glints.clear()
	now_lbl.text = ""
	cross.visible = false
	var r: Array = I.D.stages.dive_start_km
	dive_p = Vector2.from_angle(randf() * TAU) * randf_range(float(r[0]), float(r[1]))
	hint.text = tr(T.dive)
	_say("Inti", tr("My turn! Steering us onto the Centaur's crater."))
	Kit.UiSound.play("whoosh")


func _dive(delta: float) -> void:
	var S: Dictionary = I.D.stages
	var push := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		push.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		push.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		push.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		push.y += 1.0
	push += _mouse * 0.02
	_mouse = Vector2.ZERO
	# a slow sideways drift (our simplification), countered by the craft's small thrusters
	dive_v += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * float(S.dive_drift_kms) * delta
	dive_v = dive_v.lerp(push.limit_length(1.0) * float(S.dive_push_kms), clampf(delta * 2.5, 0.0, 1.0)) if push != Vector2.ZERO else dive_v * (1.0 - delta * 0.3)
	dive_p += dive_v * delta
	var q := clampf(1.0 - dive_p.length() / float(S.dive_good_km), 0.0, 1.0)
	dive_sum += q
	dive_n += 1
	now_lbl.text = tr("ON THE CRATER!") if q > 0.75 else tr("Steer to the crater!")
	now_lbl.add_theme_color_override("font_color", Kit.C_OK if q > 0.75 else Kit.C_GOLD)
	if t >= float(I.P.gap_s):
		_end()


func _dive_q() -> float:
	return dive_sum / dive_n if dive_n > 0 else 0.0


func _data() -> float:
	return I.data(_armed_n(), maxf(flash_q, 0.0), _dive_q() if phase in ["dive", "end", "done", "lost"] else 0.0)


func _spawn_glints() -> void:
	var i := I.pulse_at(t)
	if i < 0:
		# between two flashes of ice, a grain of dust flies too: a decoy
		var gk := "d%d" % int(t / 7.0)
		if not _spawned.has(gk) and I.lit(t) >= 0.12 and fmod(t, 7.0) > 2.0:
			_spawned[gk] = true
			_spawn_one(-1, false)
		return
	if _spawned.has(i) or I.lit(t) < 0.12:
		return
	_spawned[i] = true
	_spawn_one(i, true)


func _spawn_one(i: int, ice: bool) -> void:
	# a clump of ejecta leaves the plume: from a high sunlit grain, outward and up (our simplification)
	var best := 0
	for k in 30:
		var j := randi() % Impact.N
		if I.grain(j, t).y > I.grain(best, t).y:
			best = j
	var g: Vector3 = I.grain(best, t)
	var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var sp: Array = I.P.glint_kms
	var vel := side * randf_range(float(sp[0]), float(sp[1])) + Vector3(0, randf_range(0.0, 0.08), 0)
	var node := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(4.5, 4.5)
	node.mesh = q
	node.material_override = glint_mat if ice else dust_mat
	world.stage.add_child(node)
	glints.append({"node": node, "pos": impact_at + g, "vel": vel, "pulse": i, "ice": ice, "born": t})
	if ice:
		Kit.UiSound.play("notify")


func _update_glints(dt_sim: float) -> void:
	for gl in glints.duplicate():
		var i: int = gl.pulse
		var gone: bool = (t > float(I.pulses[i][1]) or I.used_pulse.has(i)) if gl.ice else (t - float(gl.born) > 5.0 or gl.has("caught"))
		if gone:
			(gl.node as Node3D).queue_free()
			glints.erase(gl)
			if gl.ice and not I.used_pulse.has(i):
				combo = 0
			continue
		gl.pos += gl.vel * dt_sim
		var n: Node3D = gl.node
		n.position = gl.pos
		n.scale = Vector3.ONE * (1.0 + 0.35 * sin(_t * 18.0))


## The glint nearest the crosshair, and how far from it on the screen (px), or [null, INF].
func _nearest_glint() -> Array:
	var c := get_viewport().get_visible_rect().size * 0.5
	var best = null
	var bd := INF
	for gl in glints:
		if world.cam.is_position_behind(gl.pos):
			continue
		var d := world.cam.unproject_position(gl.pos).distance_to(c)
		if gl.ice:
			d -= 25.0
		if d < bd:
			bd = d
			best = gl
	return [best, bd]


func _four(delta: float, dt_sim: float) -> void:
	# the pointing drifts; the player holds it
	drift += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * float(I.P.drift) * delta
	drift = drift.limit_length(0.9)
	var push := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		push.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		push.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		push.y += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		push.y -= 1.0
	var fov_k := world.cam.fov / 30.0
	aim_off += (drift * delta + push * 9.0 * delta) * fov_k + _mouse * 0.03 * fov_k
	_mouse = Vector2.ZERO
	aim_off = aim_off.limit_length(world.cam.fov * 0.45)
	if phase_t > 4.0:
		big.text = ""
		big_sub.text = ""
	# the craft wobbles now and then (our simplification): the view jumps
	if t >= next_wobble and I.shepherd_alt(t) > float(I.P.real_km):
		var wg: Array = I.P.wobble_gap_s
		next_wobble = t + randf_range(float(wg[0]), float(wg[1]))
		aim_off += Vector2.from_angle(randf() * TAU) * world.cam.fov * 0.18
		shake = 0.5
		_say("Inti", tr(T.wobble))
		Kit.UiSound.play("whoosh")
	_spawn_glints()
	_update_glints(dt_sim)
	var ng := _nearest_glint()
	var near: bool = ng[0] != null and float(ng[1]) <= float(I.P.hit_px)
	(cross as Crosshair).lock = near and ng[0].ice
	(spectrum as Spectrum).water = I.flash(t) * (1.0 if near else 0.25)
	(spectrum as Spectrum).t = _t
	if ng[0] != null and ng[0].ice:
		now_lbl.text = tr("ICE! SPACE!") if near else tr("Ice glint! Chase it!")
		now_lbl.add_theme_color_override("font_color", Kit.C_GOLD if near else Kit.C_ACCENT)
	elif ng[0] != null and near:
		now_lbl.text = tr("Dust: let it go")
		now_lbl.add_theme_color_override("font_color", Kit.C_DIM)
	else:
		now_lbl.text = ""
	reads_lbl.text = tr("Ice caught: %d") % I.readings
	combo_lbl.text = tr("Combo x%d · best x%d") % [combo, best_combo] if best_combo > 1 else ""
	if I.shepherd_alt(t) <= float(I.D.stages.dive_km):
		_start_dive()


func _catch() -> void:
	var ng := _nearest_glint()
	var near: bool = ng[0] != null and float(ng[1]) <= float(I.P.hit_px)
	if near and not ng[0].ice:
		ng[0]["caught"] = true
		I.dust(t)
		combo = 0
		_pop(tr(T.dust), Kit.C_BAD)
		Kit.UiSound.play("error")
		_say("Killa", tr("That was dust! Blue ones only."))
		return
	var r := I.read(t, 0.0 if near else 99.0)
	match r:
		"good":
			combo += 1
			best_combo = maxi(best_combo, combo)
			var gl: Dictionary = ng[0]
			burst.position = gl.pos
			burst.restart()
			burst.emitting = true
			Kit.UiSound.play("snap")
			flash.color = Color(0.55, 0.8, 1.0, 0.22)
			_pop(tr("+1 ICE!") + ("  x%d" % combo if combo > 1 else ""), Kit.C_GOLD)
			var cheers := [tr("Water! Again!"), tr("That one sparkled!"), tr("Ice in the sunlight. Beautiful."), tr("Got it. Next one!")]
			_say("Killa", cheers[I.readings % cheers.size()])
		"early":
			combo = 0
			_pop(tr(T.early), Kit.C_BAD)
			Kit.UiSound.play("error")
			_say("Rumi", tr("Patience. Wait for the glint."))
		"dark":
			combo = 0
			_pop(tr(T.dark), Kit.C_BAD)
			Kit.UiSound.play("error")
		"faint":
			_pop(tr(T.faint), Kit.C_BAD)
			Kit.UiSound.play("error")


func _end() -> void:
	phase = "end"
	phase_t = 0.0
	thump.play()
	plume.visible = false
	side_panel.visible = false
	now_lbl.text = ""
	cross.visible = false
	for gl in glints:
		(gl.node as Node3D).queue_free()
	glints.clear()
	if _data() < float(I.D.stages.need):
		_lose(tr(T.few), tr(T.few_sub) + "\n" + tr("Data sent: %d%% of %d%% needed.") % [int(_data()), int(I.D.stages.need)])
		return
	_shout(tr(T.end), tr(T.end_sub))
	hint.text = ""
	_say("Wayra", tr("Signal lost at 11:35:36 UT. Just as planned. Data is home."))
	Kit.UiSound.play("fanfare")


func _stages_ui() -> void:
	var cur := 0
	match phase:
		"brief", "aim":
			cur = 0
		"warp", "fall":
			cur = 1
		"flash":
			cur = 2
		"four":
			cur = 3
		"dive":
			cur = 4
		_:
			cur = 5
	for i in stage_rows.size():
		var l: Label = stage_rows[i]
		l.text = ("✓  " if i < cur else ("▶  " if i == cur else "·  ")) + stage_names[i]
		l.add_theme_color_override("font_color", Kit.C_OK if i < cur else (Kit.C_GOLD if i == cur else Kit.C_DIM))


# ===================================================================================== THE END
func _lose(a: String, b: String) -> void:
	phase = "lost"
	phase_t = 0.0
	Kit.UiSound.play("error")
	hint.text = ""
	side_panel.visible = false
	cross.visible = false
	now_lbl.text = ""
	lose_layer = Control.new()
	lose_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(lose_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.0, 0.0, 0.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lose_layer.add_child(shade)
	shade.create_tween().tween_property(shade, "color:a", 0.78, 1.0)
	var v := Kit.vbox(Kit.GAP)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.modulate.a = 0.0
	lose_layer.add_child(v)
	var l1 := Kit.lbl(a, Kit.T_SHOUT, Kit.C_BAD, Kit.FONT_T)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l1)
	var l2 := Kit.lbl(b, Kit.T_ACTION, Kit.C_ON_DARK, Kit.FONT_B, true)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l2.custom_minimum_size.x = 900
	v.add_child(l2)
	var row := Kit.hbox(Kit.GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var again := Kit.btn(tr("Try again  ·  Enter"), _again, Kit.T_BODY)
	Kit.accent_btn(again, Kit.C_GOLD)
	row.add_child(again)
	v.create_tween().tween_property(v, "modulate:a", 1.0, 0.6).set_delay(0.5)
	again.grab_focus()


func _again() -> void:
	go("lcross", {"campaign": campaign, "then": then_scenes, "back": back})


func _continue() -> void:
	if not then_scenes.is_empty():
		go("story", {"scenes": then_scenes, "back": back})
	else:
		go(back)


func _show_result() -> void:
	result_shown = true
	big.text = ""
	big_sub.text = ""
	var shade := ColorRect.new()
	shade.color = Kit.C_SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var p := Kit.panel_box(Kit.PAD)
	Kit.place(p, 0.5, 0.5, 0.5, 0.5, -440, -270, 440, 270)
	add_child(p)
	var v := Kit.vbox(Kit.GAP)
	p.add_child(v)
	v.add_child(Kit.caps(tr("Mission 4 · done")))
	var total := _data()
	var stars := I.stars_for(total)
	Progress.earn("lcross", stars)
	var top := Kit.hbox(Kit.PAD)
	v.add_child(top)
	top.add_child(Kit.lbl("★".repeat(stars) + "☆".repeat(3 - stars), Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T))
	top.add_child(Kit.lbl(tr("%d%% of the data home") % int(total), Kit.T_CLOCK, Kit.C_TEXT, Kit.FONT_T))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	v.add_child(grid)
	for row in [[tr("Instruments on"), "%d / %d" % [_armed_n(), armed.size()]], [tr("The flash"), "%d%%" % int(maxf(flash_q, 0.0) * 100.0)],
			[tr("Ice caught"), tr("%d · best combo x%d") % [I.readings, best_combo]], [tr("The dive onto the crater"), "%d%%" % int(_dive_q() * 100.0)]]:
		grid.add_child(Kit.lbl(row[0], Kit.T_BODY, Kit.C_DIM, Kit.FONT_R))
		grid.add_child(Kit.lbl(row[1], Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B))
	v.add_child(Kit.rule())
	for F in I.D.facts:
		var fh := Kit.hbox(Kit.GAP)
		fh.add_child(Kit.chip("NASA", Kit.C_GOLD))
		var fl := Kit.lbl(tr(F.text), Kit.T_SMALL + 1, Kit.C_DIM, Kit.FONT_R, true)
		fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fl.custom_minimum_size.x = 640
		fh.add_child(fl)
		v.add_child(fh)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var row := Kit.hbox(Kit.GAP)
	v.add_child(row)
	var go_on := Kit.btn(tr("Continue  ·  Enter"), _continue, Kit.T_BODY)
	Kit.accent_btn(go_on, Kit.C_GOLD)
	row.add_child(go_on)
	row.add_child(Kit.btn(tr("Play again  ·  R"), _again, Kit.T_BODY))
	go_on.grab_focus()


# ===================================================================================== EVERY FRAME
func process(delta: float) -> void:
	_t += delta
	phase_t += delta
	flash.color.a = maxf(0.0, flash.color.a - delta * 1.1)
	var sp := 1.0
	var dt_sim := 0.0
	match phase:
		"aim":
			var to_c: Vector2 = I.point - I.cabeus
			var floor_txt := tr("outside Cabeus")
			if to_c.length() <= I.cabeus_r:
				floor_txt = tr("on the dark floor") if I.brightness(I.point) <= float(I.A.dark_max) else tr("on the sunlit floor")
			aim_info.text = tr("Impact point: %d km from Cabeus's center, %s · Trim: %.2f of %.0f m/s") % [int(to_c.length()), floor_txt, float(I.A.budget_ms) - I.used, float(I.A.budget_ms)]
			clock_sub.text = tr("Separation")
		"warp":
			sp = float(I.P.warp)
			t = minf(t + delta * sp, float(I.P.warp_to_s))
			if t >= float(I.P.warp_to_s):
				phase = "fall"
				phase_t = 0.0
				hint.text = tr(T.arm)
				cross.visible = true
				arm_panel.visible = true
				_say("Killa", tr("Instruments! I call them, you switch them on."))
		"fall":
			t += delta
			_arming()
			count_lbl.text = tr("Impact in") + "  " + str(int(ceil(-t))) if t > -3.0 and t < 0.0 else ""
			if t >= 0.0:
				t = 0.0
				_impact()
		"flash":
			t += delta * float(I.D.stages.flash_slow)
			(meter as FlashMeter).level = _flash_level(phase_t)
			if phase_t > float(I.D.stages.flash_wait_s):
				if flash_q < 0.0:
					_flash_result(-1.0)
				_start_plume()
		"dive":
			t += delta
			_dive(delta)
		"four":
			# the four minutes shown 4 times faster, slow motion just after the impact; the last 15 km in real time
			sp = float(I.P.show_fast)
			if phase_t < 1.0:
				sp = 0.35
			if I.shepherd_alt(t) < float(I.P.real_km):
				sp = 1.0
				if hint.text != tr(T.final):
					hint.text = tr(T.final)
					_say("Wayra", tr("Ground coming up. Keep sending!"))
			dt_sim = delta * sp
			t += dt_sim
			_four(delta, dt_sim)
		"end":
			if phase_t > 3.0 and not result_shown:
				phase = "done"
				_show_result()
	speed_lbl.text = tr("Real time") if sp <= 1.0 else (tr(T.fast) if phase == "four" else tr("Time x%d") % int(sp))
	if phase in ["warp", "fall", "four", "end", "done"]:
		clock_lbl.text = I.ut(minf(t, float(I.P.gap_s)))
		clock_sub.text = tr("Our craft: %d km above the Moon") % int(I.shepherd_alt(t))
	elif phase == "aim" or phase == "brief":
		clock_lbl.text = I.ut(-float(I.A.seconds_left))
	# the plume, the fireball and the shock ring
	if plume.visible:
		var mm := plume.multimesh
		var fl := I.flash(t)
		for i in Impact.N:
			var g: Vector3 = I.grain(i, t)
			var lit_g := g.y > float(I.P.sunlit_km)
			var glow := 0.3 + 0.25 * fl
			var col := Color(1.0, 0.94, 0.82, glow) if lit_g else Color(0.4, 0.37, 0.35, 0.18 if g.y > 0.0 else 0.0)
			for k in 4:
				var jit: Vector3 = _jit[(i * 4 + k) % _jit.size()] * (0.4 + g.y * 0.08)
				var sc := 1.0 + 0.5 * k
				mm.set_instance_transform(i * 4 + k, Transform3D(Basis.from_scale(Vector3.ONE * sc), impact_at + Vector3(g.x, maxf(g.y, -1.0), g.z) + jit))
				mm.set_instance_color(i * 4 + k, Color(col, col.a / sc))
	flash_l.light_energy = maxf(0.0, flash_l.light_energy - delta * 20.0)
	var fa := clampf(1.0 - t / 5.0, 0.0, 1.0) if phase == "four" and t >= 0.0 else 0.0
	(flash_ball.material_override as ShaderMaterial).set_shader_parameter("tint", Color(1.0, 0.92, 0.75, fa))
	flash_ball.scale = Vector3.ONE * (2.0 + maxf(t, 0.0) * 3.0)
	if ring.visible:
		var rr := 1.0 + maxf(t, 0.0) * 3.5
		ring.scale = Vector3(rr, 0.4, rr)
		(ring.material_override as StandardMaterial3D).albedo_color.a = clampf(1.0 - t / 10.0, 0.0, 1.0) * 0.9
	# the camera: from our falling craft; wide over the map while aiming, then the instrument's narrow view that keeps
	# about 46 km in frame as we fall, so the plume fills it
	var alt := clampf(I.shepherd_alt(t), 0.25, 900.0)
	var dir := VIEW_DIR.normalized()
	var at := impact_at if phase != "aim" and phase != "brief" else Vector3(I.cabeus.x, 0, I.cabeus.y)
	var eye := at + dir * alt
	var look := at
	var fov_goal := 42.0
	if phase in ["fall", "flash", "four", "dive", "end", "lost", "done"] and verdict != "":
		var frame := float(I.P.frame_km)
		fov_goal = clampf(rad_to_deg(2.0 * atan(frame * 0.5 / alt)), 3.0, 80.0)
		if phase == "four" or phase == "flash":
			look = at + I.plume_mid(t) * 0.6
	world.cam.fov = lerpf(world.cam.fov, fov_goal, clampf(delta * (1.5 if phase == "warp" or phase == "aim" else 3.0), 0.0, 1.0))
	shake = maxf(0.0, shake - delta)
	if phase == "dive" or (phase in ["end", "done"] and dive_n > 0):
		var off := Vector3(dive_p.x, 0, dive_p.y)
		eye += off
		look = at + off
	world.cam.position = eye
	world.cam.look_at(look, Vector3.UP)
	if phase == "four":
		world.cam.rotate_object_local(Vector3.UP, deg_to_rad(-aim_off.x))
		world.cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(aim_off.y))
	if shake > 0.0:
		world.cam.rotate_object_local(Vector3.UP, deg_to_rad(randf_range(-1, 1) * shake * world.cam.fov * 0.03))
		world.cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(randf_range(-1, 1) * shake * world.cam.fov * 0.03))
	# the camera's look: grain while we watch through it, static when the signal goes
	var fxm := fx.material as ShaderMaterial
	var through := phase in ["fall", "flash", "four", "dive"]
	fxm.set_shader_parameter("vig", 1.0 if through else 0.0)
	fxm.set_shader_parameter("noise", clampf(1.0 - phase_t / 2.5, 0.0, 1.0) if phase == "end" else 0.0)
	# labels on the world
	var tg := tags as Tags
	tg.items.clear()
	if phase in ["warp", "fall"]:
		var c_dir := (VIEW_DIR + Vector3(0.35, 0.0, -0.3)).normalized()
		var c_pos := impact_at + c_dir * I.centaur_alt(t)
		var c_back := impact_at + c_dir * (I.centaur_alt(t) + maxf(3.0, I.centaur_alt(t) * 0.15))
		if not world.cam.is_position_behind(c_pos):
			tg.items.append([world.cam.unproject_position(c_pos), tr("Centaur  %d km up") % int(I.centaur_alt(t)), Kit.C_GOLD, world.cam.unproject_position(c_back)])
		if not world.cam.is_position_behind(at):
			tg.items.append([world.cam.unproject_position(at), tr("Cabeus crater"), Kit.C_ACCENT])
	if phase == "dive" and not world.cam.is_position_behind(at):
		tg.items.append([world.cam.unproject_position(at), tr("The Centaur's crater · 20 m"), Kit.C_GOLD])
		(tags as Tags).ring = world.cam.unproject_position(at)
	else:
		(tags as Tags).ring = Vector2(-1, -1)
	if phase == "four":
		for gl in glints:
			if not world.cam.is_position_behind(gl.pos):
				tg.items.append([world.cam.unproject_position(gl.pos), tr("ICE") if gl.ice else tr("dust"), Color(0.6, 0.85, 1.0) if gl.ice else Color(0.7, 0.6, 0.5)])
	tg.queue_redraw()
	_stages_ui()
	(data_bar as DataBar).value = _data()
	(data_bar as DataBar).need = float(I.D.stages.need)
	map_panel.visible = phase == "aim" or phase == "brief"
	if Kit.compact:
		clock_lbl.get_parent().get_parent().visible = not map_panel.visible
	hint_panel.visible = hint.text != ""
	shout_panel.visible = big.text != ""
	big_sub.visible = big_sub.text != ""
	now_panel.visible = now_lbl.text != ""
	count_panel.visible = count_lbl.text != ""


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		if phase == "four" or phase == "dive":
			_mouse += Vector2(e.relative.x, -e.relative.y)
		return
	if not (e is InputEventKey) or not e.pressed:
		return
	var k: int = e.physical_keycode
	if result_shown:
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			_continue()
		elif k == KEY_R:
			_again()
		else:
			return
	elif phase == "lost":
		if k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_R:
			_again()
		else:
			return
	elif phase == "brief" and not e.echo and (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE):
		_start()
	elif phase == "aim":
		match k:
			KEY_W, KEY_UP:
				_nudge(Vector2.UP)
			KEY_S, KEY_DOWN:
				_nudge(Vector2.DOWN)
			KEY_A, KEY_LEFT:
				_nudge(Vector2.LEFT)
			KEY_D, KEY_RIGHT:
				_nudge(Vector2.RIGHT)
			KEY_ENTER, KEY_KP_ENTER:
				if not e.echo:
					_release()
			KEY_ESCAPE:
				go(back)
			_:
				return
	elif phase == "four" and not e.echo and k == KEY_SPACE:
		_catch()
	elif phase == "flash" and not e.echo and k == KEY_SPACE:
		if flash_q < 0.0:
			_flash_result(phase_t)
	elif phase == "fall" and not e.echo and k >= KEY_1 and k <= KEY_6:
		_arm_key(k - KEY_1)
	elif k == KEY_ESCAPE:
		go(back)
	else:
		return
	get_viewport().set_input_as_handled()


# ===================================================================================== DRAWINGS
## NASA's map of the south pole, Cabeus drawn on it, and where the Centaur will hit.
class MapView extends Control:
	var I

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var tex := load(I.A.map) as Texture2D
		var s := minf(size.x, size.y)
		var o := (size - Vector2(s, s)) * 0.5
		draw_texture_rect(tex, Rect2(o, Vector2(s, s)), false)
		var k := s / float(I.A.map_px)
		var c: Vector2 = o + I.km_to_px(I.cabeus) * k
		var r: float = I.cabeus_r / I.km_px * k
		draw_arc(c, r, 0, TAU, 64, Kit.C_ACCENT, 2.0)
		draw_string(Kit.FONT_B, c + Vector2(-r, -r - 8), TranslationServer.translate("Cabeus  ·  100 km"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_ACCENT)
		draw_string(Kit.FONT_B, o + Vector2(s * 0.5 + 6, s * 0.5 - 6), TranslationServer.translate("South pole"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_DIM)
		draw_circle(o + Vector2(s, s) * 0.5, 3.0, Kit.C_DIM)
		var p: Vector2 = o + I.km_to_px(I.point) * k
		var col: Color = Kit.C_OK if I.verdict() == "in" else Kit.C_BAD
		var pulse := 1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.008)
		draw_arc(p, 10.0 * pulse, 0, TAU, 24, col, 2.5)
		draw_arc(p, 18.0 * pulse, 0, TAU, 24, Color(col, 0.35), 1.5)
		draw_line(p + Vector2(-20, 0), p + Vector2(-6, 0), col, 2.0)
		draw_line(p + Vector2(6, 0), p + Vector2(20, 0), col, 2.0)
		draw_line(p + Vector2(0, -20), p + Vector2(0, -6), col, 2.0)
		draw_line(p + Vector2(0, 6), p + Vector2(0, 20), col, 2.0)
		draw_string(Kit.FONT_B, p + Vector2(16, 26), TranslationServer.translate("Centaur's impact"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, col)


## The crosshair over the camera view: green, gold and spinning when a glint is inside it.
class Crosshair extends Control:
	var lock := false
	var hit_px := 85.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var col := Color(1.0, 0.82, 0.3, 0.95) if lock else Color(0.6, 1.0, 0.7, 0.85)
		var spin := Time.get_ticks_msec() * 0.003 if lock else 0.0
		draw_arc(c, hit_px, 0, TAU, 48, Color(col, 0.3), 1.5)
		draw_arc(c, 26.0, 0, TAU, 32, col, 2.0)
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(c + d * 34.0, c + d * 60.0, col, 2.0)
		if lock:
			for a in 4:
				var ang := spin + a * PI * 0.5
				draw_arc(c, hit_px - 8.0, ang, ang + 0.6, 8, col, 4.0)


## The spectrum, drawn for the game: light against colour, with dips where water absorbs when ice is in view.
class Spectrum extends Control:
	var water := 0.0
	var t := 0.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, 0.9))
		var pts := PackedVector2Array()
		var n := 120
		for i in n:
			var x := float(i) / (n - 1)
			var y := 0.35 + 0.25 * sin(x * 3.0) + 0.04 * sin(x * 47.0 + t * 9.0)
			for band in [0.38, 0.62, 0.84]:
				y += water * 0.45 * exp(-pow((x - band) / 0.025, 2.0))
			pts.append(Vector2(x * size.x, 14 + y * (size.y - 34)))
		draw_polyline(pts, Color(0.6, 1.0, 0.7), 2.0)
		if water > 0.25:
			for band in [0.38, 0.62, 0.84]:
				draw_line(Vector2(band * size.x, 14), Vector2(band * size.x, size.y - 20), Color(0.4, 0.75, 1.0, 0.6), 1.0)
		draw_string(Kit.FONT_B, Vector2(8, size.y - 5), TranslationServer.translate("Spectrum (drawn for the game): the dips are the water mark"), HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, Kit.T_SMALL - 2, Kit.C_DIM)


## The photometer's light: a bar that rises to the flash's peak and falls; the peak's mark.
class FlashMeter extends Control:
	var level := 0.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, 0.85))
		var w := (size.x - 20) * level
		draw_rect(Rect2(10, 26, w, size.y - 36), Color(1.0, 0.85 - 0.3 * level, 0.4, 0.95))
		draw_line(Vector2(size.x - 14, 20), Vector2(size.x - 14, size.y - 6), Kit.C_GOLD, 3.0)
		draw_string(Kit.FONT_B, Vector2(10, 18), TranslationServer.translate("Photometer: the flash's light"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_TEXT)
		draw_string(Kit.FONT_B, Vector2(size.x - 90, 18), TranslationServer.translate("peak"), HORIZONTAL_ALIGNMENT_RIGHT, 70, Kit.T_SMALL, Kit.C_GOLD)


## The data sent to Earth, 0 to 100 %, with the mark of what is needed.
class DataBar extends Control:
	var value := 0.0
	var need := 60.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var top := 18.0
		draw_rect(Rect2(0, top, size.x, size.y - top), Color(0.06, 0.08, 0.12, 0.95))
		draw_rect(Rect2(0, top, size.x * clampf(value / 100.0, 0.0, 1.0), size.y - top), Kit.C_OK if value >= need else Kit.C_ACCENT)
		var nx := size.x * need / 100.0
		draw_line(Vector2(nx, top - 2), Vector2(nx, size.y), Kit.C_GOLD, 2.0)
		draw_string(Kit.FONT_B, Vector2(0, 13), TranslationServer.translate("Data sent to Earth: %d%%") % int(value), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_TEXT)


## Labels of constant size on the world: what is too small to see at its true size.
class Tags extends Control:
	var items: Array = []
	var ring := Vector2(-1, -1)

	func _draw() -> void:
		if ring.x >= 0.0:
			var c := size * 0.5
			draw_arc(c, 60.0, 0, TAU, 48, Color(0.6, 1.0, 0.7, 0.8), 2.0)
			draw_line(c, ring, Color(1.0, 0.82, 0.3, 0.6), 2.0)
			draw_arc(ring, 22.0 + 4.0 * sin(Time.get_ticks_msec() * 0.01), 0, TAU, 32, Kit.C_GOLD, 3.0)
		for it in items:
			var p: Vector2 = it[0]
			if it.size() > 3:
				draw_line(it[3], p, Color(1.0, 0.85, 0.5, 0.8), 3.0)
				draw_circle(p, 4.5, Color(1.0, 0.95, 0.8))
			draw_arc(p, 9.0, 0, TAU, 16, it[2], 2.0)
			draw_string(Kit.FONT_B, p + Vector2(14, 5), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, it[2])


## The buttons a phone needs now (scripts/ui/touch_keys.gd): only what this stage asks for.
func touch_keys() -> Array:
	var pad := [["◀", KEY_A, "left"], ["▲", KEY_W, "left"], ["▼", KEY_S, "left"], ["▶", KEY_D, "left"]]
	match phase:
		"aim":
			return pad + [[tr("LET IT GO"), KEY_ENTER, "right"]]
		"fall":
			if arm_i >= 0 and armed[arm_i] == "":
				return [[tr("ON: %d") % (arm_i + 1), KEY_1 + arm_i, "right"]]
		"flash":
			return [[tr("PEAK!"), KEY_SPACE, "right"]]
		"four":
			return pad + [[tr("CATCH"), KEY_SPACE, "right"]]
		"dive":
			return pad
	return []


## A phone in landscape (Kit.compact): fewer panels and nothing over anything. The stage list goes (the step is in the
## title and the call to act), the radio keeps one short line at the top right, the line of what to do sits in the
## middle above the touch buttons (scripts/ui/touch_keys.gd), and the big call to act just above it.
func _phone_layout() -> void:
	if not Kit.compact:
		return
	if not stage_rows.is_empty():
		(stage_rows[0] as Control).get_parent().get_parent().visible = false
	var radio_card: Control = radio.get_parent().get_parent()
	Kit.place(radio_card, 1, 0, 1, 0, -Kit.MARGIN - 330, Kit.MARGIN, -Kit.MARGIN, Kit.MARGIN + 50)
	radio.custom_minimum_size.x = 300
	radio.add_theme_font_size_override("font_size", Kit.T_BODY)
	Kit.place(hint_panel, 0.5, 1, 0.5, 1, -250, -150, 250, -96)
	hint.add_theme_font_size_override("font_size", Kit.T_BODY)
	Kit.place(now_panel, 0.5, 1, 0.5, 1, -10, -210, 10, -160)
	now_lbl.add_theme_font_size_override("font_size", Kit.T_ACTION + 2)
	# the map of the south pole, smaller, clear of the radio and the buttons
	# while aiming the map takes the top middle; the clock steps aside (it shows only the separation's time then)
	Kit.place(map_panel, 0.5, 0, 0.5, 0, -160, 8, 160, 330)
	map_view.custom_minimum_size = Vector2(176, 176)
	aim_info.add_theme_font_size_override("font_size", Kit.T_SMALL)
	for c in map_view.get_parent().get_children():
		if c is Label:
			(c as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			(c as Label).custom_minimum_size.x = 290
			(c as Label).add_theme_font_size_override("font_size", Kit.T_SMALL - 1)
	Kit.place(side_panel, 1, 1, 1, 1, -Kit.MARGIN - 300, -Kit.MARGIN - 230, -Kit.MARGIN, -Kit.MARGIN - 96)
	spectrum.custom_minimum_size = Vector2(280, 60)
