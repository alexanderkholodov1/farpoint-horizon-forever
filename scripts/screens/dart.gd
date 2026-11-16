extends "res://scripts/screens/screen.gd"
## Mission 5, DART (September 26, 2022): "Push an asteroid" (issue #49). The crew fly it from mission control.
## Four stages, each part of the result: (1) Find Dimorphos: through DRACO, DART's camera, with its real 0.29-degree
## view, Didymos is one dot; when it splits in two the player picks the small moon (A/D) and locks it (Enter), as
## SMARTNav did. Locking the big one: lose screen. (2) Steer: WASD fires small thruster pulses; the scope shows where
## DART will pass Dimorphos; early pulses move it far, late ones little (straight-line motion). Time shown 600 then 60
## times faster (said on screen), real time for the last 2 minutes. Missing Dimorphos: lose screen. (3) The last
## picture: SPACE as late as possible; its sharpness from the distance and DRACO's 0.5 arcsec pixel. (4) Weeks later:
## telescopes watch the pair's light dip; the player marks two deep dips before the impact and two after, and finds the
## orbit 32 minutes shorter. Rules: scripts/missions/dart/approach.gd; data: data/missions/dart.json. The world is in
## km: Dimorphos at the origin, DART coming down the +z axis.

const TouchKeys := preload("res://scripts/ui/touch_keys.gd")
const Progress := preload("res://scripts/story/campaign_progress.gd")
const Approach := preload("res://scripts/missions/dart/approach.gd")
const Sets := preload("res://scripts/story/sets.gd")
const Space := preload("res://scripts/world/space_builder.gd")
const Sound := preload("res://scripts/flight/sound.gd")
const DIDYMOS_AT := Vector3(-0.95, 0.25, -0.7)   ## Didymos from Dimorphos (km): 1.2 km apart, ours.
const CAM_FOV := 1.0           ## Godot's narrowest camera; DRACO's 0.29 degrees is kept by bringing the eye closer.

var A: Approach
var T: Dictionary
var campaign := false
var then_scenes: Array = []
var back := "menu"
var saved := {}
var phase := "brief"           ## brief, find, steer, impact, measure, done, lost
var phase_t := 0.0
var _t := 0.0
var t := 0.0                   ## Seconds to impact (negative before it).
var pick := 0                  ## 0 Didymos, 1 Dimorphos (the one the selection ring is on).
var lock_q := 0.0
var photo_cm := -1.0
var photo_tex: ImageTexture
var pulse_cool := 0.0
var shake := 0.0
var round_i := 0               ## 0: before the impact, 1: after.
var marks: Array = []
var cursor_h := 1.0
var round_done := false
var _beeped := {}
const SCROLL_HPS := 3.0        ## Hours of telescope watching shown per second.
var next_glitch := 0.0         ## When the next drift alarm comes (real seconds of steering).
var alarm_t := 0.0
var periods: Array = [-1.0, -1.0]
var result_shown := false
var thump: AudioStreamPlayer
# the world
var didymos: MeshInstance3D
var dimorphos: MeshInstance3D
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
var now_lbl: Label
var now_panel: PanelContainer
var bubble: Label
var flash: ColorRect
var fx: ColorRect
var cross: Control
var draco: Label
var tags: Control
var scope_panel: PanelContainer
var scope: Control
var fuel_lbl: Label
var stage_rows: Array = []
var stage_names: Array = []
var measure_layer: Control
var curve_view: Control
var measure_lbl: Label
var brief: Control
var lose_layer: Control


func enter(args: Dictionary) -> void:
	campaign = args.get("campaign", false)
	then_scenes = args.get("then", [])
	back = args.get("back", "menu")
	A = Approach.new()
	T = A.D.texts
	saved = Sets.save_world(world)
	world.cam_free = false
	_build_world()
	thump = Sound.player(self, "thud", -2.0)
	_build_ui()
	t = float(A.P.start_s)
	_say("Wayra", tr("Four hours out. DRACO is on. Find the little moon."))
	_show_brief()
	_phone_layout()
	TouchKeys.attach(self)


func exit() -> void:
	var env: Environment = world.world_env.environment
	env.adjustment_enabled = false
	Sets.restore_world(world, saved)


# ===================================================================================== THE WORLD (km)
func _build_world() -> void:
	world.clear_stage()
	var env: Environment = world.world_env.environment
	env.sky = Space.make_space_sky()
	env.background_energy_multiplier = 0.6
	env.fog_enabled = false
	env.glow_enabled = true
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.ambient_light_energy = 0.12
	# DRACO sees in black and white
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.0
	world.sun.light_energy = 2.2
	world.sun.light_color = Color(1, 1, 1)
	world.sun.rotation_degrees = Vector3(-20, 55, 0)
	world.sun.shadow_enabled = true
	world.cam.fov = CAM_FOV
	var st: Node3D = world.stage
	didymos = MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = float(A.P.didymos_m) * 0.0005
	dm.height = float(A.P.didymos_m) * 0.0009
	dm.radial_segments = 96
	dm.rings = 48
	didymos.mesh = dm
	didymos.material_override = Sets.rock_mat(1.7)
	didymos.position = DIDYMOS_AT
	st.add_child(didymos)
	dimorphos = MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = float(A.P.dimorphos_m) * 0.0005
	mm.height = float(A.P.dimorphos_m) * 0.0007
	mm.radial_segments = 96
	mm.rings = 48
	dimorphos.mesh = mm
	dimorphos.material_override = Sets.rock_mat(4.2)
	dimorphos.rotation = Vector3(0.3, 0.8, 0.2)
	st.add_child(dimorphos)


# ===================================================================================== THE INTERFACE
func _card() -> PanelContainer:
	var p := Kit.panel_box(12)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _build_ui() -> void:
	fx = ColorRect.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fsh := Shader.new()
	fsh.code = """
shader_type canvas_item;
uniform float vig = 1.0;
uniform float noise = 0.0;
void fragment() {
	float v = smoothstep(0.95, 0.35, length((UV - vec2(0.5)) * vec2(1.25, 1.0)));
	vec2 cell = floor(UV * vec2(400.0, 225.0));
	float n = fract(sin(dot(cell, vec2(12.9898, 78.233)) + fract(TIME * 7.31) * 437.585) * 43758.5453);
	float a = (1.0 - v) * vig * 0.8 + vig * 0.04 * n;
	COLOR = vec4(vec3(n) * noise, clamp(a + noise * 0.97, 0.0, 1.0));
}
"""
	var fm := ShaderMaterial.new()
	fm.shader = fsh
	fx.material = fm
	add_child(fx)
	draco = Kit.lbl("", Kit.T_SMALL, Color(0.75, 1.0, 0.8, 0.85), Kit.font_num())
	Kit.place(draco, 0, 1, 0, 1, Kit.MARGIN, -170, Kit.MARGIN + 600, -140)
	add_child(draco)
	cross = Crosshair.new()
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cross)
	tags = Tags.new()
	tags.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tags)
	var head := Kit.vbox(2)
	Kit.place(head, 0, 0, 0, 0, Kit.MARGIN, Kit.MARGIN, 560, 100)
	add_child(head)
	var over := Kit.caps(tr("Mission 5 · DART · September 26, 2022"))
	over.add_theme_color_override("font_color", Color(Kit.C_ON_DARK, 0.8))
	head.add_child(over)
	head_title = Kit.lbl(tr("Push an asteroid"), Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T)
	head.add_child(head_title)
	# the stages, left
	var stp := _card()
	Kit.place(stp, 0, 0, 0, 0, Kit.MARGIN, 120, Kit.MARGIN + 10, 130)
	add_child(stp)
	var stv := Kit.vbox(4)
	stp.add_child(stv)
	stv.add_child(Kit.caps(tr("The mission")))
	for nm in [tr("Find Dimorphos"), tr("Steer onto it"), tr("The last picture"), tr("Measure its orbit")]:
		stage_names.append(nm)
		var l := Kit.lbl(nm, Kit.T_BODY, Kit.C_DIM, Kit.FONT_B)
		stv.add_child(l)
		stage_rows.append(l)
	# the clock
	var cp := Kit.panel_box(Kit.PAD)
	Kit.place(cp, 0.5, 0, 0.5, 0, -190, Kit.MARGIN, 190, Kit.MARGIN + 130)
	add_child(cp)
	var cv := Kit.vbox(0)
	cp.add_child(cv)
	var cap_l := Kit.caps(tr("Time to impact"))
	cap_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(cap_l)
	clock_lbl = Kit.lbl("", Kit.T_CLOCK + 6, Kit.C_GOLD, Kit.font_num())
	clock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(clock_lbl)
	clock_sub = Kit.lbl("", Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B)
	clock_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(clock_sub)
	speed_lbl = Kit.lbl("", Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R)
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
	# the aim scope: where DART will pass Dimorphos, and the fuel
	scope_panel = _card()
	Kit.place(scope_panel, 1, 1, 1, 1, -Kit.MARGIN - 320, -Kit.MARGIN - 380, -Kit.MARGIN, -Kit.MARGIN)
	add_child(scope_panel)
	var sv := Kit.vbox(6)
	scope_panel.add_child(sv)
	sv.add_child(Kit.caps(tr("Where DART will hit")))
	scope = Scope.new()
	scope.A = A
	scope.custom_minimum_size = Vector2(296, 260)
	sv.add_child(scope)
	fuel_lbl = Kit.lbl("", Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B)
	sv.add_child(fuel_lbl)
	scope_panel.visible = false
	# what to do now
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
	now_panel = _card()
	Kit.place(now_panel, 0.5, 1, 0.5, 1, -10, -300, 10, -290)
	now_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(now_panel)
	now_lbl = Kit.lbl("", Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T)
	now_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	now_panel.add_child(now_lbl)
	bubble = Kit.lbl("", Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T)
	Kit.place(bubble, 0.5, 0.5, 0.5, 0.5, 110, -40, 700, 20)
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
	bubble.add_theme_color_override("font_color", col)
	bubble.pivot_offset = Vector2(0, 30)
	bubble.scale = Vector2(1.5, 1.5)
	bubble.modulate.a = 1.0
	var tw := bubble.create_tween()
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.8)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.4)


func _show_brief() -> void:
	brief = Control.new()
	brief.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(brief)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brief.add_child(shade)
	var p := Kit.panel_box(Kit.PAD)
	Kit.place(p, 0.5, 0.5, 0.5, 0.5, -440, -280, 440, 280)
	brief.add_child(p)
	var v := Kit.vbox(Kit.GAP)
	p.add_child(v)
	v.add_child(Kit.caps(tr("How to play")))
	v.add_child(Kit.lbl(tr("Push an asteroid"), Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T))
	for row in [["1", tr("Find Dimorphos"), tr("When the dot splits in two, pick the small moon (A/D) and lock it (Enter).")],
			["2", tr("Steer onto it"), tr("WASD fires small thrusters. Early pulses move the hit far; late ones, little.")],
			["3", tr("The last picture"), tr("SPACE as late as you dare: the closer, the sharper.")],
			["4", tr("Measure its orbit"), tr("Weeks later, mark the dips in the light to time Dimorphos's orbit.")]]:
		var h := Kit.hbox(Kit.PAD)
		v.add_child(h)
		h.add_child(Kit.lbl(row[0], Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T))
		var tv := Kit.vbox(0)
		h.add_child(tv)
		tv.add_child(Kit.lbl(row[1], Kit.T_ACTION - 2, Kit.C_TEXT, Kit.FONT_B))
		var d := Kit.lbl(row[2], Kit.T_BODY, Kit.C_DIM, Kit.FONT_R, true)
		d.custom_minimum_size.x = 640
		tv.add_child(d)
	var go_btn := Kit.btn(tr("Start  ·  Enter"), _start, Kit.T_BODY)
	Kit.accent_btn(go_btn, Kit.C_GOLD)
	v.add_child(go_btn)
	go_btn.grab_focus()


func _start() -> void:
	if phase != "brief":
		return
	if brief and is_instance_valid(brief):
		brief.queue_free()
	phase = "find"
	phase_t = 0.0
	hint.text = tr(T.find)


# ===================================================================================== STAGE 1: FIND DIMORPHOS
func _lock() -> void:
	if not A.resolved(t):
		_pop(tr("Still one dot. Wait for it to split."), Kit.C_BAD)
		return
	if pick == 0:
		_lose(tr(T.big), tr(T.big_sub))
		return
	lock_q = 1.0
	now_lbl.text = ""
	phase = "steer"
	phase_t = 0.0
	scope_panel.visible = true
	Kit.UiSound.play("success")
	_pop(tr("Dimorphos locked!"), Kit.C_OK)
	hint.text = tr(T.steer)
	_say("Inti", tr("The little one! Locked. Now keep it in the middle."))


# ===================================================================================== STAGE 2 AND 3: STEER, THE LAST PICTURE
func _steer(delta: float) -> void:
	pulse_cool -= delta
	# now and then the aim jumps (SMARTNav refining its picture of the target, our simplification): an alarm
	next_glitch -= delta
	alarm_t = maxf(0.0, alarm_t - delta)
	if next_glitch <= 0.0 and -t > 6.0:
		next_glitch = randf_range(3.5, 6.0)
		var room := maxf(-t, 1.0)
		A.vel += Vector2.from_angle(randf() * TAU) * randf_range(35.0, 60.0) / room
		alarm_t = 1.4
		shake = 0.4
		Kit.UiSound.play("error")
		_say(["Inti", "Rumi", "Killa"][randi() % 3], [tr("Drift! Correct it!"), tr("We are sliding off! Thrusters!"), tr("Target moved! Bring it back!")][randi() % 3])
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y -= 1.0
	if dir != Vector2.ZERO and pulse_cool <= 0.0:
		pulse_cool = 0.12
		# a pulse moves the hit point the way the player pushes (the craft slides that way)
		if A.pulse(dir, t):
			Kit.UiSound.play("click")
		else:
			_say("Rumi", tr("Fuel is out. That is where we hit."))
	var miss: float = A.miss(t).length()
	if not A.hits(t):
		now_lbl.text = tr("OFF TARGET! WASD!")
		now_lbl.add_theme_color_override("font_color", Kit.C_BAD)
	elif now_lbl.text == tr("OFF TARGET! WASD!"):
		now_lbl.text = ""
	flash.color = Color(1.0, 0.1, 0.05, maxf(flash.color.a, 0.18 * alarm_t)) if alarm_t > 0.0 else flash.color
	fuel_lbl.text = tr("Fuel: %d%% · miss: %d m") % [int(100.0 * (1.0 - A.used / float(A.P.budget_pulses))), int(miss)]
	fuel_lbl.add_theme_color_override("font_color", Kit.C_OK if A.hits(t) else Kit.C_BAD)
	if -t <= float(A.P.photo_window_s):
		if photo_cm < 0.0 and A.hits(t):
			now_lbl.text = tr("LAST PICTURE: SPACE!")
			now_lbl.add_theme_color_override("font_color", Kit.C_GOLD)
		hint.text = tr(T.photo)
	elif -t <= -float(A.P.real_s) and hint.text != tr(T.real):
		hint.text = tr(T.real)
		_say("Killa", tr("Thirty seconds. Look at it grow!"))
	if t >= 0.0:
		_impact()


func _photo() -> void:
	if -t > float(A.P.photo_window_s) or t >= 0.0:
		return
	photo_cm = A.photo_cm(t)
	# the picture is DRACO's alone: the interface hides for one frame
	visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	visible = true
	photo_tex = ImageTexture.create_from_image(img)
	flash.color = Color(1, 1, 1, 0.5)
	Kit.UiSound.play("snap")
	now_lbl.text = ""
	_pop(tr("Picture: %.1f cm per pixel") % photo_cm, Kit.C_GOLD)


func _impact() -> void:
	t = 0.0
	phase = "impact"
	phase_t = 0.0
	now_lbl.text = ""
	thump.play()
	if not A.hits(0.0):
		_lose(tr(T.miss), tr(T.miss_sub) + "\n" + tr("Missed by %d m.") % int(A.miss(0.0).length()))
		return
	scope_panel.visible = false
	cross.visible = false
	hint.text = ""
	flash.color = Color(1, 1, 1, 1)
	shake = 1.0
	_shout(tr("SIGNAL LOST!"), tr("Impact! 23:14 UT, as Earth heard it, 11 million km away."))
	_say("Wayra", tr("Signal lost. Right on target. Now we wait and watch."))
	Kit.UiSound.play("fanfare")


# ===================================================================================== STAGE 4: MEASURE THE ORBIT
func _start_measure() -> void:
	phase = "measure"
	phase_t = 0.0
	big.text = ""
	big_sub.text = ""
	hint.text = tr(T.measure)
	measure_layer = Control.new()
	measure_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(measure_layer)
	move_child(measure_layer, hint_panel.get_index())
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	measure_layer.add_child(shade)
	var p := Kit.panel_box(Kit.PAD)
	Kit.place(p, 0.5, 0.5, 0.5, 0.5, -620, -120, 620, 300)
	measure_layer.add_child(p)
	var v := Kit.vbox(Kit.GAP)
	p.add_child(v)
	measure_lbl = Kit.lbl("", Kit.T_ACTION, Kit.C_GOLD, Kit.FONT_B, true)
	v.add_child(measure_lbl)
	curve_view = LightCurve.new()
	curve_view.A = A
	curve_view.custom_minimum_size = Vector2(1200, 300)
	v.add_child(curve_view)
	_say("Killa", tr("Telescopes on Earth! Each deep dip is Dimorphos passing Didymos. Hit them on the beat!"))
	_round(0)


func _round(i: int) -> void:
	round_i = i
	marks = []
	cursor_h = -2.0
	round_done = false
	(curve_view as LightCurve).after = i == 1
	(curve_view as LightCurve).marks = marks
	measure_lbl.text = tr("BEFORE the impact: SPACE when each deep dip crosses the line!") if i == 0 else tr("AFTER the impact: SPACE when each deep dip crosses the line!")


## The light runs by (shown 3 hours of sky each second, said on screen); the line is "now".
func _measure(delta: float) -> void:
	if round_done:
		return
	cursor_h += delta * SCROLL_HPS
	(curve_view as LightCurve).cursor = cursor_h
	# the next deep dip coming: a beat on the line
	var dips: Array = A.dips(round_i == 1)
	for dh in dips:
		var lead: float = dh - cursor_h
		if lead > 0.0 and lead < 0.35 and not _beeped.has(dh):
			_beeped[dh] = true
			Kit.UiSound.play("notify")
	if cursor_h > float(A.M.window_h) + 2.0:
		_round_end()


func _mark() -> void:
	if round_done:
		return
	var h := cursor_h
	# only presses near a deep dip count; a press elsewhere is a miss
	var near := INF
	for dh in A.dips(round_i == 1):
		near = minf(near, absf(dh - h))
	if near > 0.9:
		_pop(tr("No dip there!"), Kit.C_BAD)
		Kit.UiSound.play("error")
		shake = 0.2
		return
	marks.append(h)
	(curve_view as LightCurve).marks = marks
	Kit.UiSound.play("snap")
	var acc := clampf(1.0 - near / 0.9, 0.0, 1.0)
	_pop(tr("PERFECT!") if acc > 0.85 else (tr("Good!") if acc > 0.5 else tr("Close")), Kit.C_GOLD if acc > 0.5 else Kit.C_TEXT)
	flash.color = Color(0.6, 1.0, 0.7, 0.15 * acc)
	if marks.size() >= 3:
		_round_end()


func _round_end() -> void:
	round_done = true
	var m := 0.0
	if marks.size() >= 2:
		# the orbit: the time between marks, divided by how many orbits passed between them
		var per := float(A.M.after_min if round_i == 1 else A.M.before_min) / 60.0
		var span: float = marks[marks.size() - 1] - marks[0]
		m = span / maxf(1.0, round(span / per)) * 60.0
	else:
		_pop(tr("Too few dips marked"), Kit.C_BAD)
		periods[round_i] = 0.0
		if round_i == 0:
			get_tree().create_timer(1.4).timeout.connect(func(): _round(1))
		else:
			phase = "reveal"
			phase_t = 0.0
		return
	periods[round_i] = m
	var q: float = A.period_quality(m, round_i == 1)
	_pop(tr("%d h %d min") % [int(m / 60.0), int(fmod(m, 60.0))], Kit.C_GOLD if q > 0.5 else Kit.C_BAD)
	if round_i == 0:
		_say("Rumi", tr("Before: %d h %d min. Now the same, after the impact.") % [int(m / 60.0), int(fmod(m, 60.0))])
		get_tree().create_timer(1.4).timeout.connect(func(): _round(1))
	else:
		var diff: float = periods[0] - periods[1]
		_shout(tr("%d minutes shorter!") % int(round(diff)), tr("NASA measured 32 minutes, plus or minus about 2."))
		Kit.UiSound.play("fanfare")
		flash.color = Color(1, 0.95, 0.8, 0.3)
		_say("Killa", tr("We moved an asteroid! A real one!"))
		phase = "reveal"
		phase_t = 0.0


func _measure_q() -> float:
	var a := A.period_quality(periods[0], false) if periods[0] > 0.0 else 0.0
	var b := A.period_quality(periods[1], true) if periods[1] > 0.0 else 0.0
	return (a + b) * 0.5


func _score() -> float:
	return A.score(lock_q, A.aim_quality(0.0), A.photo_quality(photo_cm) if photo_cm > 0.0 else 0.0, _measure_q())


# ===================================================================================== THE END
func _lose(a: String, b: String) -> void:
	phase = "lost"
	phase_t = 0.0
	Kit.UiSound.play("error")
	hint.text = ""
	now_lbl.text = ""
	scope_panel.visible = false
	cross.visible = false
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
	go("dart", {"campaign": campaign, "then": then_scenes, "back": back})


func _continue() -> void:
	if not then_scenes.is_empty():
		go("story", {"scenes": then_scenes, "back": back})
	else:
		go(back)


func _show_result() -> void:
	result_shown = true
	big.text = ""
	big_sub.text = ""
	hint.text = ""
	var total := _score()
	if total < float(A.D.score.need):
		_lose(tr(T.few), tr(T.few_sub) + "\n" + tr("Result: %d%% of %d%% needed.") % [int(total), int(A.D.score.need)])
		result_shown = false
		return
	var shade := ColorRect.new()
	shade.color = Kit.C_SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var p := Kit.panel_box(Kit.PAD)
	Kit.place(p, 0.5, 0.5, 0.5, 0.5, -520, -280, 520, 280)
	add_child(p)
	var top := Kit.hbox(Kit.PAD)
	p.add_child(top)
	var pv := Kit.vbox(6)
	top.add_child(pv)
	pv.add_child(Kit.caps(tr("Your last picture")))
	var img := TextureRect.new()
	img.texture = photo_tex
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.custom_minimum_size = Vector2(380, 300)
	pv.add_child(img)
	pv.add_child(Kit.lbl(tr("%.1f cm per pixel (the real last one: about 3)") % photo_cm if photo_cm > 0.0 else tr("No picture taken"), Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))
	var v := Kit.vbox(Kit.GAP)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(v)
	v.add_child(Kit.caps(tr("Mission 5 · done")))
	var stars := A.stars_for(total)
	Progress.earn("dart", stars)
	var sh := Kit.hbox(Kit.PAD)
	v.add_child(sh)
	sh.add_child(Kit.lbl("★".repeat(stars) + "☆".repeat(3 - stars), Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T))
	sh.add_child(Kit.lbl("%d%%" % int(total), Kit.T_CLOCK, Kit.C_TEXT, Kit.FONT_T))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	v.add_child(grid)
	for row in [[tr("Hit"), tr("%d m from the center") % int(A.miss(0.0).length())],
			[tr("Your picture"), ("%.1f cm/px" % photo_cm) if photo_cm > 0.0 else "-"],
			[tr("Orbit before"), _hm(periods[0])], [tr("Orbit after"), _hm(periods[1])]]:
		grid.add_child(Kit.lbl(row[0], Kit.T_BODY, Kit.C_DIM, Kit.FONT_R))
		grid.add_child(Kit.lbl(row[1], Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B))
	v.add_child(Kit.rule())
	for F in A.D.facts:
		var fh := Kit.hbox(Kit.GAP)
		fh.add_child(Kit.chip("NASA", Kit.C_GOLD))
		var fl := Kit.lbl(tr(F.text), Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true)
		fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fl.custom_minimum_size.x = 480
		fh.add_child(fl)
		v.add_child(fh)
	var row2 := Kit.hbox(Kit.GAP)
	v.add_child(row2)
	var go_on := Kit.btn(tr("Continue  ·  Enter"), _continue, Kit.T_BODY)
	Kit.accent_btn(go_on, Kit.C_GOLD)
	row2.add_child(go_on)
	row2.add_child(Kit.btn(tr("Play again  ·  R"), _again, Kit.T_BODY))
	go_on.grab_focus()


func _hm(m: float) -> String:
	if m <= 0.0:
		return "-"
	return "%d h %02d min" % [int(m / 60.0), int(fmod(m, 60.0))]


# ===================================================================================== EVERY FRAME
func process(delta: float) -> void:
	_t += delta
	phase_t += delta
	flash.color.a = maxf(0.0, flash.color.a - delta * 1.2)
	var sp := 1.0
	match phase:
		"find":
			sp = float(A.P.fast) if not A.resolved(t) else 40.0
			if A.resolved(t) and not _said_split:
				_said_split = true
				Kit.UiSound.play("notify")
				_say("Inti", tr("Two dots! The big one is Didymos. The little one is ours."))
				now_lbl.text = tr("Two dots: pick the small one!")
			t += delta * sp
			A.update(delta * sp, t)
			if t >= float(A.P.real_s):
				_lose(tr("No lock."), tr("DART needs its target in time. Try again."))
		"steer":
			sp = float(A.P.steer_fast) if t < -120.0 else (6.0 if t < float(A.P.real_s) else 1.0)
			# the last seconds: the rock fills the view, the craft shakes
			if -t < 6.0:
				shake = maxf(shake, 0.25 * (1.0 - -t / 6.0))
			t = minf(t + delta * sp, 0.0)
			A.update(delta * sp, t)
			_steer(delta)
		"impact":
			if phase_t > 2.6:
				_start_measure()
		"measure":
			_measure(delta)
		"reveal":
			if phase_t > 4.5 and not result_shown:
				phase = "done"
				_show_result()
	_stages_ui()
	speed_lbl.text = tr("Real time") if sp <= 1.0 else tr("Shown %d times faster") % int(sp)
	clock_lbl.text = A.countdown(t)
	clock_sub.text = tr("Distance: %s km") % _km(A.dist_km(t)) if phase in ["find", "steer", "brief"] else ""
	# DRACO's view: from DART toward where it will pass; Dimorphos shows off center by the miss
	# the eye at the distance that gives DRACO's real view (0.29 deg) through a 1-degree camera
	var d := maxf(A.dist_km(t), 0.002) * float(A.P.fov_deg) / CAM_FOV
	var m: Vector2 = A.miss(t) * 0.001 if phase != "find" else Vector2.ZERO
	var aim := Vector3.ZERO if phase != "find" or pick == 1 else DIDYMOS_AT * 0.0
	var eye := Vector3(m.x, m.y, d)
	if phase == "find":
		eye = Vector3(DIDYMOS_AT.x * 0.5, DIDYMOS_AT.y * 0.5, d)
		aim = Vector3(DIDYMOS_AT.x * 0.5, DIDYMOS_AT.y * 0.5, 0)
	else:
		aim = Vector3(m.x, m.y, 0)
	shake = maxf(0.0, shake - delta)
	world.cam.near = clampf(d * 0.05, 0.00005, 1.0)
	world.cam.far = d + 50.0
	world.cam.position = eye
	world.cam.look_at(aim, Vector3.UP)
	if shake > 0.0:
		world.cam.rotate_object_local(Vector3.UP, deg_to_rad(randf_range(-1, 1) * shake * 0.04))
		world.cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(randf_range(-1, 1) * shake * 0.04))
	var nz := 0.0
	if phase == "impact":
		nz = clampf(1.0 - phase_t / 2.5, 0.0, 1.0)
	elif phase == "steer" and -t < 5.0:
		nz = 0.12 * (1.0 - -t / 5.0)
	(fx.material as ShaderMaterial).set_shader_parameter("noise", nz)
	# dots for what is too small to see: Didymos, Dimorphos, and the selection ring
	var tg := tags as Tags
	tg.items.clear()
	if phase in ["find", "steer"]:
		var res := A.resolved(t)
		for k in [0, 1]:
			var p3: Vector3 = DIDYMOS_AT if k == 0 else Vector3.ZERO
			var size_px: float = A.px(float(A.P.didymos_m if k == 0 else A.P.dimorphos_m), t)
			if world.cam.is_position_behind(p3):
				continue
			var sp2 := world.cam.unproject_position(p3)
			if not res and k == 1:
				continue
			var label := "Didymos" if k == 0 and res else ("Dimorphos" if k == 1 else "Didymos · Dimorphos")
			var sel: bool = phase == "find" and res and pick == k
			if size_px < 60.0 or sel:
				tg.items.append([sp2, label, Kit.C_GOLD if sel else Kit.C_ACCENT, sel, size_px, k == 0 and res])
	tg.queue_redraw()
	(scope as Scope).t = t
	draco.visible = phase in ["find", "steer"]
	if draco.visible:
		var frame := int((float(A.P.start_s) - t) * -1.0)
		draco.text = "DRACO · 0.29° · %s  ·  frame %06d  ·  %s px" % [tr("black and white"), frame, String.num(A.px(float(A.P.dimorphos_m), t), 0)]
	cross.visible = phase in ["steer", "find"]
	hint_panel.visible = hint.text != ""
	shout_panel.visible = big.text != ""
	big_sub.visible = big_sub.text != ""
	now_panel.visible = now_lbl.text != ""


var _said_split := false


func _km(k: float) -> String:
	if k >= 10.0:
		return "%d" % int(k)
	return "%.2f" % k


func _stages_ui() -> void:
	var cur := 0
	match phase:
		"brief", "find":
			cur = 0
		"steer":
			cur = 1 if -t > float(A.P.photo_window_s) else 2
		"impact":
			cur = 3
		"measure", "reveal":
			cur = 3
		_:
			cur = 4
	for i in stage_rows.size():
		var l: Label = stage_rows[i]
		l.text = ("✓  " if i < cur else ("▶  " if i == cur else "·  ")) + stage_names[i]
		l.add_theme_color_override("font_color", Kit.C_OK if i < cur else (Kit.C_GOLD if i == cur else Kit.C_DIM))


func _unhandled_input(e: InputEvent) -> void:
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
	elif phase == "find" and not e.echo and (k == KEY_A or k == KEY_LEFT or k == KEY_D or k == KEY_RIGHT):
		pick = 1 - pick
		Kit.UiSound.play("click")
	elif phase == "find" and not e.echo and (k == KEY_ENTER or k == KEY_KP_ENTER):
		_lock()
	elif phase == "steer" and not e.echo and k == KEY_SPACE:
		_photo()
	elif phase == "measure" and not e.echo and k == KEY_SPACE:
		_mark()
	elif k == KEY_ESCAPE:
		go(back)
	else:
		return
	get_viewport().set_input_as_handled()


# ===================================================================================== DRAWINGS
class Crosshair extends Control:
	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var col := Color(0.6, 1.0, 0.7, 0.8)
		draw_arc(c, 30.0, 0, TAU, 32, col, 1.5)
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(c + d * 40.0, c + d * 70.0, col, 1.5)


## Where DART will pass Dimorphos: the moon's outline (160 m) and the hit point, with how fast it is moving.
class Scope extends Control:
	var A
	var t := 0.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, 0.9))
		var c := size * 0.5
		var k := (minf(size.x, size.y) * 0.5 - 14.0) / 240.0         # px per metre: 240 m to the edge
		var r := float(A.P.dimorphos_m) * 0.5 * k
		draw_circle(c, r, Color(0.35, 0.33, 0.3))
		draw_arc(c, r, 0, TAU, 48, Color(0.8, 0.8, 0.8), 2.0)
		draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), Color(0.9, 0.9, 0.9), 1.0)
		draw_line(c + Vector2(0, -8), c + Vector2(0, 8), Color(0.9, 0.9, 0.9), 1.0)
		var m: Vector2 = A.miss(t)
		var p := c + Vector2(m.x, -m.y) * k
		p = p.clamp(Vector2(6, 6), size - Vector2(6, 6))
		var ok: bool = A.hits(t)
		draw_circle(p, 7.0, Kit.C_OK if ok else Kit.C_BAD)
		draw_string(Kit.FONT_B, Vector2(8, size.y - 8), TranslationServer.translate("Dimorphos, 160 m"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_DIM)


## The pair's light over 30 hours, the cursor and the player's marks.
class LightCurve extends Control:
	var A
	var after := false
	var cursor := 1.0
	var marks: Array = []

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, 0.95))
		var W := 30.0
		var h0 := cursor - 9.0
		var pts := PackedVector2Array()
		for i in 600:
			var h := h0 + W * i / 599.0
			var b: float = A.curve(maxf(h, 0.0), after)
			pts.append(Vector2(size.x * i / 599.0, size.y * 0.15 + (1.0 - b) / 0.14 * size.y * 0.7))
		draw_polyline(pts, Color(0.6, 1.0, 0.7), 2.5)
		for hh in range(int(ceil(h0 / 6.0)) * 6, int(h0 + W) + 1, 6):
			var x := size.x * (hh - h0) / W
			draw_line(Vector2(x, size.y - 18), Vector2(x, size.y - 10), Kit.C_DIM, 1.0)
			draw_string(Kit.FONT_B, Vector2(x + 3, size.y - 4), "%d h" % hh, HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL - 2, Kit.C_DIM)
		for m in marks:
			var x: float = size.x * (m - h0) / W
			if x < 0.0 or x > size.x:
				continue
			draw_line(Vector2(x, 0), Vector2(x, size.y - 20), Kit.C_GOLD, 3.0)
			draw_circle(Vector2(x, 26), 6.0, Kit.C_GOLD)
		var cx := size.x * 0.3
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012)
		draw_rect(Rect2(cx - 18, 0, 36, size.y - 20), Color(1, 1, 1, 0.05 * pulse))
		draw_line(Vector2(cx, 0), Vector2(cx, size.y - 20), Color(1, 1, 1, 0.9), 2.5)
		draw_string(Kit.FONT_B, Vector2(cx + 6, 34), TranslationServer.translate("NOW"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_TEXT)
		draw_string(Kit.FONT_B, Vector2(8, 16), TranslationServer.translate("The pair's light, as telescopes saw it (drawn for the game)"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_DIM)


## Labels of constant size for what is too small to see; the ring on the chosen one.
class Tags extends Control:
	var items: Array = []

	func _draw() -> void:
		for it in items:
			var p: Vector2 = it[0]
			var r := maxf(10.0, float(it[4]) * 0.6 + 8.0)
			if it[3]:
				var a := Time.get_ticks_msec() * 0.004
				for q in 4:
					draw_arc(p, r + 6.0, a + q * PI * 0.5, a + q * PI * 0.5 + 0.8, 8, it[2], 3.0)
			else:
				draw_arc(p, r, 0, TAU, 24, it[2], 1.5)
			draw_circle(p, 2.5, Color(1, 1, 1))
			if it[5]:
				draw_string(Kit.FONT_B, p + Vector2(-r - 210, 5), it[1], HORIZONTAL_ALIGNMENT_RIGHT, 200, Kit.T_SMALL, it[2])
			else:
				draw_string(Kit.FONT_B, p + Vector2(r + 8, 5), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, it[2])


## The buttons a phone needs now (scripts/ui/touch_keys.gd): only what this stage asks for.
func touch_keys() -> Array:
	var pad := [["◀", KEY_A, "left"], ["▲", KEY_W, "left"], ["▼", KEY_S, "left"], ["▶", KEY_D, "left"]]
	match phase:
		"find":
			if A.resolved(t):
				return [[tr("◀ ▶ SWITCH"), KEY_D, "left"], [tr("LOCK"), KEY_ENTER, "right"]]
		"steer":
			if -t <= float(A.P.photo_window_s) and photo_cm < 0.0:
				return pad + [[tr("PHOTO"), KEY_SPACE, "right"]]
			return pad
		"measure":
			return [[tr("MARK"), KEY_SPACE, "right"]]
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
	Kit.place(scope_panel, 1, 1, 1, 1, -Kit.MARGIN - 210, -Kit.MARGIN - 280, -Kit.MARGIN, -Kit.MARGIN - 96)
	scope.custom_minimum_size = Vector2(190, 160)
	draco.visible = false
