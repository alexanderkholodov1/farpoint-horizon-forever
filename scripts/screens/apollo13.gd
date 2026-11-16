extends "res://scripts/screens/screen.gd"
## Mission 1, Apollo 13: "Square peg, round hole" (issue #45). Inside Aquarius, powered down, the CO2 climbs on the
## gauge; Mission Control reads the steps; the player picks each part from the table (keys 1-6 or a click) and the
## adapter takes shape in the middle; the tape is pressed on with the timing ring (Space). The last part turns the
## reading around; then the real NASA photo of the crew's "Mail Box". It is an emergency against the clock: the air
## left counts down, the master alarm and a heartbeat speed up, the lights flicker, and in the danger zone the view
## blurs and darkens at the edges (too much CO2 makes people dizzy). A part out of order costs seconds; when the clock
## reaches zero the air runs out and the player tries again (the team's choice). The win is a moment of slow motion,
## a flash and the fans starting: the needle turns around and the clock freezes on "Saved!". Only the crew's version:
## the story's scenes give the context, this screen only the task, with Rumi and Killa working beside the adapter.
## Rules: scripts/missions/apollo13/adapter.gd; data: data/missions/apollo13.json. Played on its own
## (go("apollo13")) or inside the story (args {"campaign": true, "then": [scene refs], "back": id}), where Rumi and
## Killa work beside the adapter and the story's outro follows.

const TouchKeys := preload("res://scripts/ui/touch_keys.gd")
const Progress := preload("res://scripts/story/campaign_progress.gd")
const Adapter := preload("res://scripts/missions/apollo13/adapter.gd")
const Sets := preload("res://scripts/story/sets.gd")
const CuyActor := preload("res://scripts/story/cuy_actor.gd")
const Instruments := preload("res://scripts/flight/instruments.gd")
const Sound := preload("res://scripts/flight/sound.gd")
const HAZE := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
uniform float pulse = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	float r = amount * 10.0;
	vec2 px = SCREEN_PIXEL_SIZE * r;
	vec3 c = texture(screen_tex, uv).rgb * 0.2;
	c += texture(screen_tex, uv + vec2(px.x, 0.0)).rgb * 0.1;
	c += texture(screen_tex, uv - vec2(px.x, 0.0)).rgb * 0.1;
	c += texture(screen_tex, uv + vec2(0.0, px.y)).rgb * 0.1;
	c += texture(screen_tex, uv - vec2(0.0, px.y)).rgb * 0.1;
	c += texture(screen_tex, uv + px).rgb * 0.1;
	c += texture(screen_tex, uv - px).rgb * 0.1;
	c += texture(screen_tex, uv + vec2(sin(TIME * 0.9) * 0.012 * amount, 0.0)).rgb * 0.2;
	float d = distance(uv, vec2(0.5));
	float edge = smoothstep(0.8 - 0.45 * amount, 0.15, d);
	c *= mix(1.0, edge, clamp(amount * 1.2, 0.0, 1.0));
	c = mix(c, c * vec3(1.25, 0.75, 0.75), pulse * amount * 0.6);
	COLOR = vec4(c, 1.0);
}
"""
const RING_PERIOD := 1.5      ## Seconds for the ring to close, then a little past.

var A: Adapter
var campaign := false
var then_scenes: Array = []
var back := "menu"
var gauge: Control
var houston: Label
var step_rows: Array = []
var part_tiles := {}           ## part id -> PanelContainer
var part_keys: Array = []      ## parts on the table in key order
var ring: Control
var ring_t := 0.0
var msg: Label
var msg_sub: Label
var note: Label
var model := {}                ## The adapter's 3D pieces: "root", "cardboard", "bag", "tape" (Array), "hose".
var S := {}
var actors := {}
var saved := {}
var taping := false            ## The tape is picked: the ring runs until its presses are done.
var finish_t := -1.0
var lost_t := -1.0
var clock: Label
var clock_cap: Label
var penalty: Label
var haze: ColorRect             ## The danger zone's blur and dark edges (under the interface).
var flash: ColorRect
var alarm: AudioStreamPlayer
var heart: AudioStreamPlayer
var tick: AudioStreamPlayer
var _alarm_t := 0.0
var _heart_t := 0.0
var _last_sec := -1
var _said := {}
var spot: SpotLight3D
var photo_shown := false
var _t := 0.0


func enter(args: Dictionary) -> void:
	campaign = args.get("campaign", false)
	then_scenes = args.get("then", [])
	back = args.get("back", "menu")
	A = Adapter.new()
	saved = Sets.save_world(world)
	world.cam_free = false
	world.cam.fov = 42.0
	S = Sets.build("lm", world)
	S.flood.light_energy = float(S.flood_energy) * 0.45
	_build_adapter()
	# a lamp on the work: the adapter is the hero of the scene
	spot = SpotLight3D.new()
	spot.position = Vector3(0.6, 2.6, 2.4)
	spot.light_color = Color(1.0, 0.92, 0.8)
	spot.light_energy = 1.8
	spot.spot_range = 6.0
	spot.spot_angle = 24.0
	world.stage.add_child(spot)
	spot.look_at(Vector3(0, 1.15, 1.0), Vector3.UP)
	alarm = Sound.player(self, "alarm", -16.0)
	heart = Sound.player(self, "thud", -8.0)
	tick = Sound.player(self, "beep", -14.0)
	if true:
		for id in ["rumi", "killa"]:
			var a = CuyActor.new()
			a.id = id
			world.stage.add_child(a)
			actors[id] = a
		actors.rumi.position = Vector3(0.95, 0.75, 1.05)
		actors.rumi.rotation.y = -0.9
		actors.rumi.act = "work"
		actors.rumi.set_mood("determined")
		actors.killa.position = Vector3(-1.0, 0.85, 0.9)
		actors.killa.rotation.y = 0.8
		actors.killa.act = "float"
		actors.killa.set_mood("worried")
	world.cam.position = Vector3(0.15, 1.55, 3.6)
	world.cam.look_at(Vector3(0, 1.15, 1.0), Vector3.UP)
	_build_ui()
	_show_step()
	TouchKeys.attach(self)


func exit() -> void:
	Engine.time_scale = 1.0
	Sets.restore_world(world, saved)


# ===================================================================================== THE ADAPTER IN 3D
func _build_adapter() -> void:
	var root := Node3D.new()
	root.position = Vector3(0, 1.15, 1.0)
	world.stage.add_child(root)
	model.root = root
	var metal := Sets.mat(Color(0.55, 0.56, 0.58), 0.4, 0.6)
	var dark := Sets.mat(Color(0.18, 0.19, 0.2), 0.5, 0.4)
	# the command module's square canister, its grid on the front
	Sets.box(root, Vector3(0.5, 0.5, 0.42), Vector3.ZERO, metal)
	for i in 4:
		Sets.box(root, Vector3(0.46, 0.018, 0.02), Vector3(0, -0.17 + i * 0.115, 0.215), dark)
		Sets.box(root, Vector3(0.018, 0.46, 0.02), Vector3(-0.17 + i * 0.115, 0, 0.215), dark)
	# cardboard: a frame around the open end
	var cb := Node3D.new()
	root.add_child(cb)
	var card := Sets.mat(Color(0.62, 0.48, 0.3), 0.95)
	for k in 4:
		var p := Sets.box(cb, Vector3(0.56, 0.2, 0.02), Vector3.ZERO, card)
		var a := k * PI / 2.0
		p.position = Vector3(sin(a) * 0.28, 0.33, cos(a) * 0.24)
		p.rotation = Vector3(0, a, 0)
	cb.scale = Vector3.ZERO
	model.cardboard = cb
	# the bag over it all
	var bag := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.66, 0.86, 0.56)
	bag.mesh = bm
	var bmat := Sets.mat(Color(0.9, 0.93, 0.95, 0.42), 0.25)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bag.material_override = bmat
	bag.position = Vector3(0, 0.14, 0)
	bag.scale = Vector3.ZERO
	root.add_child(bag)
	model.bag = bag
	# the tape: one band per press
	var tape := Sets.mat(Color(0.45, 0.47, 0.5), 0.6, 0.4)
	model.tape = []
	for i in 3:
		var band := Sets.box(root, Vector3(0.68, 0.045, 0.58), Vector3(0, -0.15 + i * 0.2, 0), tape)
		band.visible = false
		model.tape.append(band)
	# the hose from the bag's top to the air outlet
	var hose := Node3D.new()
	root.add_child(hose)
	var white := Sets.mat(Color(0.92, 0.92, 0.9), 0.7)
	var pts := [Vector3(0, 0.58, 0), Vector3(0.1, 0.8, -0.05), Vector3(0.35, 0.92, -0.15), Vector3(0.7, 0.9, -0.3), Vector3(1.05, 0.75, -0.45)]
	for i in pts.size() - 1:
		Sets.rope(hose, pts[i], pts[i + 1], 0.055, white)
	var fit := Sets.cyl(hose, 0.07, 0.07, 0.08, pts[0], Sets.mat(Color(0.7, 0.72, 0.75), 0.3, 0.8), 20)
	fit.name = "Fitting"
	hose.visible = false
	model.hose = hose


func _grow(n: Node3D) -> void:
	n.visible = true
	n.scale = Vector3.ONE * 0.01
	n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ===================================================================================== THE INTERFACE
func _build_ui() -> void:
	# under everything else: the haze of the danger zone
	haze = ColorRect.new()
	haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = HAZE
	hm.shader = sh
	haze.material = hm
	haze.visible = false
	add_child(haze)
	# the countdown, big, in the middle at the top
	var cp := Kit.panel_box(Kit.PAD)
	Kit.place(cp, 0.5, 0, 0.5, 0, -150, Kit.MARGIN, 150, Kit.MARGIN + 110)
	add_child(cp)
	var cv := Kit.vbox(0)
	cp.add_child(cv)
	clock_cap = Kit.caps(tr("Air left"))
	clock_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(clock_cap)
	clock = Kit.lbl("2:00", Kit.T_CLOCK + 16, Kit.C_GOLD, Kit.font_num())
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(clock)
	penalty = Kit.lbl("", Kit.T_ACTION, Kit.C_BAD, Kit.FONT_T)
	Kit.place(penalty, 0.5, 0, 0.5, 0, 160, Kit.MARGIN + 30, 300, Kit.MARGIN + 70)
	penalty.add_theme_constant_override("outline_size", 8)
	penalty.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	add_child(penalty)
	# top left: what this is, in one line
	var head := Kit.vbox(2)
	Kit.place(head, 0, 0, 0, 0, Kit.MARGIN, Kit.MARGIN, 560, 120)
	add_child(head)
	var over := Kit.caps(tr("Mission 1 · Apollo 13 · April 1970"))
	over.add_theme_color_override("font_color", Color(Kit.C_ON_DARK, 0.75))
	head.add_child(over)
	head.add_child(Kit.lbl(tr("Square peg, round hole"), Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T))
	# left: the gauge
	var gp := Kit.panel_box(Kit.PAD)
	Kit.place(gp, 0, 0, 0, 1, Kit.MARGIN, 150, Kit.MARGIN + 190, -230)
	add_child(gp)
	var gv := Kit.vbox(Kit.GAP)
	gp.add_child(gv)
	gv.add_child(Kit.caps(tr("CO2 in the cabin")))
	gauge = Co2Gauge.new()
	gauge.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gauge.custom_minimum_size = Vector2(140, 200)
	gv.add_child(gauge)
	note = Kit.lbl(tr("Simplified: hours of real work in about a minute."), Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true)
	gv.add_child(note)
	# right: Mission Control
	var hp := Kit.panel_box(Kit.PAD)
	Kit.place(hp, 1, 0, 1, 0, -Kit.MARGIN - 430, Kit.MARGIN, -Kit.MARGIN, Kit.MARGIN + 60)
	add_child(hp)
	var hv := Kit.vbox(Kit.GAP)
	hp.add_child(hv)
	var hh := Kit.hbox(Kit.GAP)
	hv.add_child(hh)
	hh.add_child(Kit.chip("Wayra", Kit.C_ACCENT))
	hh.add_child(Kit.lbl(tr("Mission Control, on the radio"), Kit.T_SMALL, Kit.C_DIM))
	houston = Kit.lbl("", Kit.T_ACTION - 2, Kit.C_TEXT, Kit.FONT_B, true)
	houston.custom_minimum_size.x = 380
	hv.add_child(houston)
	hv.add_child(Kit.rule())
	for i in A.steps().size():
		var row := Kit.lbl("", Kit.T_BODY, Kit.C_DIM, Kit.FONT_R, true)
		hv.add_child(row)
		step_rows.append(row)
	# bottom: the table of parts
	var tp := Kit.panel_box(Kit.PAD)
	Kit.place(tp, 0.5, 1, 0.5, 1, -560, -200, 560, -Kit.MARGIN)
	tp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(tp)
	var tv := Kit.vbox(Kit.GAP)
	tp.add_child(tv)
	tv.add_child(Kit.caps(tr("What you have on board · press 1 to 6 or click")))
	var row2 := Kit.hbox(Kit.GAP)
	tv.add_child(row2)
	var n := 0
	for P in A.D.parts:
		if P.get("given", false):
			continue
		n += 1
		part_keys.append(P.id)
		var tile := _tile(n, P)
		row2.add_child(tile)
		part_tiles[P.id] = tile
	# middle: the timing ring for the tape, and the big messages
	ring = Instruments.TimingRing.new()
	Kit.place(ring, 0.5, 0.5, 0.5, 0.5, -320, -260, 320, 220)
	add_child(ring)
	msg = Kit.lbl("", Kit.T_SHOUT, Kit.C_GOLD, Kit.FONT_T)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Kit.place(msg, 0, 0.5, 1, 0.5, 0, -170, 0, -100)
	msg.add_theme_constant_override("outline_size", 12)
	msg.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	msg.visible = false
	add_child(msg)
	msg_sub = Kit.lbl("", Kit.T_ACTION, Kit.C_ON_DARK, Kit.FONT_B)
	msg_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Kit.place(msg_sub, 0, 0.5, 1, 0.5, 0, -96, 0, -60)
	msg_sub.add_theme_constant_override("outline_size", 8)
	msg_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	msg_sub.visible = false
	add_child(msg_sub)
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 1, 1, 0)
	add_child(flash)


## A part on the table: its drawing, its key and its name; the line about it as the tooltip.
func _tile(n: int, P: Dictionary) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Kit.flat(Kit.C_CARD, Kit.C_EDGE, 10, 1, 8, 8))
	pc.custom_minimum_size = Vector2(146, 0)
	pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pc.tooltip_text = tr(P.line)
	pc.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_pick(P.id))
	var v := Kit.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(v)
	var icon := PartIcon.new()
	icon.part = P.id
	icon.custom_minimum_size = Vector2(120, 62)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon)
	var name_l := Kit.lbl("%d  %s" % [n, tr(P.name)], Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	return pc


func _show_step() -> void:
	var cur := A.current()
	houston.text = tr(str(cur.get("houston", ""))) if not cur.is_empty() else tr(A.D.win)
	for i in step_rows.size():
		var St: Dictionary = A.steps()[i]
		var row: Label = step_rows[i]
		var part_name := ""
		for P in A.D.parts:
			if P.id == St.part:
				part_name = tr(P.name)
		if i < A.step:
			row.text = "✓  " + tr(St.done)
			row.add_theme_color_override("font_color", Kit.C_OK)
		elif i == A.step:
			row.text = "▶  " + tr("Step %d: %s") % [i + 1, part_name]
			row.add_theme_color_override("font_color", Kit.C_GOLD)
		else:
			row.text = "·  " + tr("Step %d") % (i + 1)
			row.add_theme_color_override("font_color", Kit.C_DIM)
	_light_tiles()


func _light_tiles() -> void:
	for id in part_tiles:
		var lit := false
		var pc: PanelContainer = part_tiles[id]
		pc.add_theme_stylebox_override("panel", Kit.flat(Color(Kit.C_GOLD, 0.18) if lit else Kit.C_CARD, Kit.C_GOLD if lit else Kit.C_EDGE, 10, 2 if lit else 1, 8, 8))


# ===================================================================================== PLAY
func _pick(id: String) -> void:
	if A.done or A.lost:
		return
	if taping and id == A.needed():
		return                          # already taping: the ring does it
	var r := A.pick(id)
	var pc: PanelContainer = part_tiles.get(id)
	match r:
		"wrong":
			Kit.UiSound.play("error")
			houston.text = tr(A.D.wrong)
			penalty.text = tr("-%d s") % int(round(float(A.D.gauge.wrong_pick) / float(A.D.gauge.rise_per_s)))
			penalty.modulate.a = 1.0
			penalty.position.y = Kit.MARGIN + 30
			var pt := penalty.create_tween()
			pt.tween_property(penalty, "position:y", Kit.MARGIN + 70, 1.2)
			pt.parallel().tween_property(penalty, "modulate:a", 0.0, 1.2)
			if pc:
				var tw := pc.create_tween()
				for k in 3:
					tw.tween_property(pc, "position:x", pc.position.x + 8, 0.04)
					tw.tween_property(pc, "position:x", pc.position.x - 8, 0.04)
				tw.tween_property(pc, "position:x", pc.position.x, 0.04)
			if actors.has("killa"):
				actors.killa.set_mood("scared")
			get_tree().create_timer(1.6).timeout.connect(func():
				if is_inside_tree() and not A.done:
					_show_step())
		"ok":
			Kit.UiSound.play("select")
			houston.text = tr("Press Space when the ring meets the circle: one press for each band of tape.")
			ring_t = 0.0
			taping = true
		"next":
			_on_step_done(id)


func _on_step_done(id: String) -> void:
	Kit.UiSound.play("snap")
	match id:
		"cardboard":
			_grow(model.cardboard)
		"bag":
			_grow(model.bag)
		"hose":
			_grow(model.hose)
	if actors.has("rumi"):
		actors.rumi.hop()
	if A.done:
		_win()
	else:
		_show_step()


func _press() -> void:
	var rem := 1.0 - ring_t / (RING_PERIOD * 0.8)
	var grade := "late"
	var col := Kit.C_WARN
	if absf(rem) <= 0.08:
		grade = "perfect"
		col = Kit.C_OK
	elif absf(rem) <= 0.2:
		grade = "good"
		col = Kit.C_ACCENT
	(ring as Instruments.TimingRing).grade(tr(grade.to_upper()), col)
	Kit.UiSound.play("snap" if grade != "late" else "click")
	var band: MeshInstance3D = model.tape[mini(A.presses, 2)]
	_grow(band)
	var r := A.press(grade)
	ring_t = 0.0
	if r == "next":
		taping = false
		_on_step_done("tape")


func _win() -> void:
	finish_t = 0.0
	# a breath of slow motion and a flash as the fans start
	Engine.time_scale = 0.3
	get_tree().create_timer(0.7, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
	flash.color.a = 0.85
	Kit.UiSound.play("whoosh", 0.0)
	alarm.stop()
	# one headline at a time (#97): the clock just freezes, green, on the air that was left; the big line says what
	# happened; Houston's panel carries the why, away from the crew's faces
	clock.text = _mmss(A.seconds_left())
	clock.add_theme_color_override("font_color", Kit.C_OK)
	clock.scale = Vector2.ONE
	clock_cap.text = tr(A.D.saved)
	ring.set("active", false)
	houston.text = tr(A.D.win_sub)
	_show_step()
	msg.text = tr(A.D.win)
	msg_sub.text = ""
	msg.visible = true
	msg_sub.visible = false
	msg.pivot_offset = Vector2(msg.size.x * 0.5, 30)
	msg.scale = Vector2(0.6, 0.6)
	msg.create_tween().tween_property(msg, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK)
	Kit.UiSound.play("fanfare", 0.0)
	for k in actors:
		actors[k].act = "cheer"
		actors[k].set_mood("happy")


## The air ran out: the cabin goes dark and red, the crew slump, and the game is tried again.
func _lose() -> void:
	lost_t = 0.0
	taping = false
	alarm.stop()
	Kit.UiSound.play("error", 0.0)
	clock.text = "0:00"
	clock.add_theme_color_override("font_color", Kit.C_BAD)
	for k in actors:
		actors[k].act = "hide"
		actors[k].set_mood("tired")
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.0, 0.0, 0.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	shade.create_tween().tween_property(shade, "color:a", 0.75, 1.2)
	var v := Kit.vbox(Kit.GAP)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.modulate.a = 0.0
	add_child(v)
	var big := Kit.lbl(tr(A.D.lost), Kit.T_SHOUT, Kit.C_BAD, Kit.FONT_T)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var sub := Kit.lbl(tr(A.D.lost_sub), Kit.T_ACTION, Kit.C_ON_DARK, Kit.FONT_B)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var row := Kit.hbox(Kit.GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var again := Kit.btn(tr("Try again  ·  Enter"), _again, Kit.T_BODY)
	Kit.accent_btn(again, Kit.C_GOLD)
	row.add_child(again)
	v.create_tween().tween_property(v, "modulate:a", 1.0, 0.8).set_delay(0.8)
	again.grab_focus()


func _again() -> void:
	go("apollo13", {"campaign": campaign, "then": then_scenes, "back": back})


## The real thing: NASA's photo of the crew's adapter, the stars earned, and what comes next.
func _show_photo() -> void:
	photo_shown = true
	msg.visible = false
	msg_sub.visible = false
	var shade := ColorRect.new()
	shade.color = Kit.C_SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var p := Kit.panel_box(Kit.PAD)
	Kit.place(p, 0.5, 0.5, 0.5, 0.5, -470, -330, 470, 330)
	add_child(p)
	var h := Kit.hbox(Kit.PAD)
	p.add_child(h)
	var img := TextureRect.new()
	img.texture = load(A.D.photo.file)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.custom_minimum_size = Vector2(420, 420)
	h.add_child(img)
	var v := Kit.vbox(Kit.GAP)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(Kit.caps(tr("Mission 1 · done")))
	var stars := A.stars()
	Progress.earn("apollo13", stars)
	v.add_child(Kit.lbl("★".repeat(stars) + "☆".repeat(3 - stars), Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T))
	v.add_child(Kit.lbl(tr("Wrong parts: %d · Perfect tape: %d of 3") % [A.wrong, A.perfect], Kit.T_SMALL + 1, Kit.C_DIM))
	v.add_child(Kit.rule())
	v.add_child(Kit.lbl(tr(A.D.photo.caption), Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B, true))
	v.add_child(Kit.lbl(A.D.photo.credit, Kit.T_SMALL, Kit.C_DIM))
	for F in A.D.facts:
		var fh := Kit.hbox(Kit.GAP)
		fh.add_child(Kit.chip("NASA", Kit.C_GOLD))
		var fl := Kit.lbl(tr(F.text), Kit.T_SMALL + 1, Kit.C_DIM, Kit.FONT_R, true)
		fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	row.add_child(Kit.btn(tr("Play again  ·  R"), func(): go("apollo13", {"campaign": campaign, "then": then_scenes, "back": back}), Kit.T_BODY))
	go_on.grab_focus()


static func _mmss(sec: float) -> String:
	var s := int(ceil(sec))
	return "%d:%02d" % [s / 60, s % 60]


func _continue() -> void:
	if not then_scenes.is_empty():
		go("story", {"scenes": then_scenes, "back": back})
	else:
		go(back)


func process(delta: float) -> void:
	_t += delta
	A.update(delta)
	(gauge as Co2Gauge).value = A.co2
	(gauge as Co2Gauge).warning = A.D.gauge.warning
	(gauge as Co2Gauge).falling = A.done
	# the adapter floats a little, as everything does in zero gravity
	var r: Node3D = model.root
	r.rotation.y = sin(_t * 0.35) * 0.35 + 0.25
	r.position.y = 1.15 + sin(_t * 0.8) * 0.02
	# pressure: the camera creeps in and shakes as the air gets worse; the clock, the alarm and the heartbeat speed up
	var dz: float = A.danger() if not A.done else maxf(0.0, A.danger() - finish_t * 0.5)
	var press_in := clampf((A.co2 - float(A.D.gauge.start)) / (1.0 - float(A.D.gauge.start)), 0.0, 1.0)
	var jit := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.012 * dz
	var push := 0.8 * press_in if not A.done else lerpf(0.8 * press_in, 0.55, clampf(finish_t, 0.0, 1.0))
	world.cam.position = Vector3(0.15 + sin(_t * 0.2) * 0.12, 1.55 + sin(_t * 0.27) * 0.03, 3.6 - push) + jit
	world.cam.look_at(Vector3(0, 1.15, 1.0), Vector3.UP)
	haze.visible = dz > 0.01
	(haze.material as ShaderMaterial).set_shader_parameter("amount", dz)
	(haze.material as ShaderMaterial).set_shader_parameter("pulse", 0.5 + 0.5 * sin(_t * 5.0))
	flash.color.a = maxf(0.0, flash.color.a - delta * 1.5)
	if not A.done and not A.lost:
		var left := A.seconds_left()
		var sec := int(ceil(left))
		clock.text = _mmss(left)
		var col: Color = Kit.C_BAD if left <= 30.0 else (Kit.C_WARN if left <= 60.0 else Kit.C_GOLD)
		clock.add_theme_color_override("font_color", col if left > 10.0 or int(_t * 4.0) % 2 == 0 else Kit.C_TEXT)
		clock.pivot_offset = clock.size * 0.5
		clock.scale = Vector2.ONE * (1.0 + (0.08 * (0.5 + 0.5 * sin(_t * 10.0)) if left <= 10.0 else 0.0))
		if sec != _last_sec and sec <= 10 and sec > 0:
			tick.play()
		_last_sec = sec
		for k in ["60", "30", "10"]:
			if left <= float(k) and not _said.has(k) and not taping:
				_said[k] = true
				houston.text = tr(A.D.urgent[k])
		if A.warning():
			_alarm_t -= delta
			if _alarm_t <= 0.0:
				alarm.play()
				_alarm_t = lerpf(2.2, 0.9, dz)
		_heart_t -= delta
		if _heart_t <= 0.0 and A.co2 > 0.55:
			heart.play()
			_heart_t = lerpf(1.1, 0.42, press_in)
		# the lights flicker in the danger zone
		if dz > 0.0:
			S.flood.light_energy = float(S.flood_energy) * 0.45 * (1.0 - 0.6 * dz * (1.0 if randf() < 0.08 else 0.0))
	# the alarm light while the air is bad
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	if S.has("alarm_lamp"):
		var am := (S.alarm_lamp as MeshInstance3D).material_override as StandardMaterial3D
		am.emission_energy_multiplier = (4.0 * pulse) if A.warning() and not A.done else 0.2
	if A.lost and lost_t < 0.0:
		_lose()
	# the tape's ring
	var tr_ring := ring as Instruments.TimingRing
	if taping and not A.done:
		ring_t += delta
		if ring_t > RING_PERIOD:
			ring_t = 0.0
		tr_ring.active = true
		tr_ring.label = tr("Tape")
		tr_ring.remaining = 1.0 - ring_t / (RING_PERIOD * 0.8)
		tr_ring.window = 0.08
	else:
		tr_ring.active = false
	# after the win: the air clears, the lights come back a little, then the photo
	if finish_t >= 0.0:
		finish_t += delta
		S.flood.light_energy = lerpf(S.flood.light_energy, float(S.flood_energy) * 0.9, delta)
		if finish_t > 3.2 and not photo_shown:
			_show_photo()


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = e.physical_keycode
	if lost_t >= 0.0:
		if k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_R:
			_again()
		else:
			return
	elif photo_shown:
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			_continue()
		elif k == KEY_R:
			go("apollo13", {"campaign": campaign, "then": then_scenes, "back": back})
		else:
			return
	elif k >= KEY_1 and k <= KEY_9 and k - KEY_1 < part_keys.size():
		_pick(part_keys[k - KEY_1])
	elif k == KEY_SPACE and (ring as Instruments.TimingRing).active:
		_press()
	elif k == KEY_ESCAPE:
		go(back)
	else:
		return
	get_viewport().set_input_as_handled()


# ===================================================================================== DRAWINGS
## The CO2 gauge: a tall bar from clean air to the top of the scale, the warning zone in red, the reading as a needle
## with a trail; green when it falls.
class Co2Gauge extends Control:
	var value := 0.0
	var warning := 0.7
	var falling := false
	var _shown := 0.0

	func _process(delta: float) -> void:
		_shown = lerpf(_shown, value, clampf(delta * 6.0, 0.0, 1.0))
		queue_redraw()

	func _draw() -> void:
		var bar := Rect2(Vector2(size.x * 0.5 - 22, 6), Vector2(44, size.y - 30))
		draw_rect(bar, Color(0, 0, 0, 0.35))
		var wy := bar.position.y + bar.size.y * (1.0 - warning)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x, wy - bar.position.y)), Color(Kit.C_BAD, 0.22))
		draw_line(Vector2(bar.position.x - 8, wy), Vector2(bar.end.x + 8, wy), Color(Kit.C_BAD, 0.8), 2.0)
		var col: Color = Kit.C_OK if falling else (Kit.C_BAD if _shown >= warning else Kit.C_GOLD)
		var vy := bar.position.y + bar.size.y * (1.0 - _shown)
		draw_rect(Rect2(Vector2(bar.position.x + 4, vy), Vector2(bar.size.x - 8, bar.end.y - vy - 2)), Color(col, 0.85))
		draw_line(Vector2(bar.position.x - 14, vy), Vector2(bar.end.x + 14, vy), col, 4.0)
		draw_string(Kit.FONT_B, Vector2(bar.end.x + 18, wy + 5), TranslationServer.translate("Warning"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_BAD)
		var word := TranslationServer.translate("Falling") if falling else (TranslationServer.translate("Too high") if _shown >= warning else TranslationServer.translate("Rising"))
		draw_string(Kit.FONT_B, Vector2(0, size.y - 4), word, HORIZONTAL_ALIGNMENT_CENTER, size.x, Kit.T_BODY, col)


## A drawing of a part, from simple shapes.
class PartIcon extends Control:
	var part := ""

	func _draw() -> void:
		var c := size * 0.5
		match part:
			"cardboard":
				var pts := PackedVector2Array([c + Vector2(-40, 18), c + Vector2(-26, -20), c + Vector2(40, -20), c + Vector2(28, 18)])
				draw_colored_polygon(pts, Color(0.66, 0.5, 0.3))
				draw_line(c + Vector2(-26, -20), c + Vector2(-12, 18), Color(0.45, 0.33, 0.2), 2.0)
			"bag":
				draw_rect(Rect2(c + Vector2(-28, -24), Vector2(56, 48)), Color(0.9, 0.94, 0.97, 0.45))
				draw_rect(Rect2(c + Vector2(-28, -24), Vector2(56, 48)), Color(0.95, 0.97, 1.0, 0.9), false, 2.0)
				draw_line(c + Vector2(-28, -16), c + Vector2(28, -16), Color(0.8, 0.85, 0.9), 2.0)
			"tape":
				draw_arc(c, 22, 0, TAU, 40, Color(0.62, 0.64, 0.66), 12.0)
				draw_arc(c, 12, 0, TAU, 30, Color(0.85, 0.75, 0.55), 4.0)
				draw_line(c + Vector2(22, 4), c + Vector2(42, 20), Color(0.62, 0.64, 0.66), 8.0)
			"hose":
				var pts2 := PackedVector2Array()
				for i in 20:
					var t := i / 19.0
					pts2.append(c + Vector2(lerpf(-44, 40, t), sin(t * PI * 1.4) * -16 + 6))
				draw_polyline(pts2, Color(0.93, 0.93, 0.9), 11.0, true)
				draw_circle(c + Vector2(40, 2), 9, Color(0.7, 0.72, 0.75))
			"food":
				draw_rect(Rect2(c + Vector2(-24, -22), Vector2(48, 44)), Color(0.95, 0.62, 0.25))
				draw_rect(Rect2(c + Vector2(-14, -10), Vector2(28, 18)), Color(1, 0.95, 0.85))
			"checklist":
				draw_rect(Rect2(c + Vector2(-22, -26), Vector2(44, 52)), Color(0.96, 0.96, 0.92))
				for i in 5:
					draw_line(c + Vector2(-14, -16 + i * 9), c + Vector2(14, -16 + i * 9), Color(0.4, 0.45, 0.5), 2.0)
			_:
				draw_rect(Rect2(c + Vector2(-24, -24), Vector2(48, 48)), Color(0.55, 0.56, 0.58))


## The buttons a phone needs now (scripts/ui/touch_keys.gd): the parts are tapped on the table; the tape needs SPACE.
func touch_keys() -> Array:
	if lost_t >= 0.0 or photo_shown:
		return []
	if (ring as Instruments.TimingRing).active:
		return [[tr("TAPE!"), KEY_SPACE, "right"]]
	return []
