extends "res://scripts/screens/screen.gd"
## Coming home (issue #67): the re-entry and the splashdown, played. The rules are scripts/flight/reentry.gd (values in
## data/reentry.json); this screen draws the capsule in the plasma, the corridor gauge and the parachutes, and hands
## back to the story. Inside the story, Apollo 13's outro plays it (data/story/apollo13.json, "play": "reentry").
##   go("reentry", {"craft": "apollo13", "then": [...scenes], "back": "chapters"})

const Reentry := preload("res://scripts/flight/reentry.gd")
const Scene3D := preload("res://scripts/flight/flight_scene.gd")
const Sets := preload("res://scripts/story/sets.gd")
const EARTH_R := 6000.0                ## The globe under the plasma, scene units (as the launch's horizon).

var R
var craft := "apollo13"
var then_scenes: Array = []
var back := "menu"
var view: Control
var gauge: Control
var title_l: Label
var hint_l: Label
var big_l: Label
var info_l: Label
var black_l: Label
var chute_btn: Button
var done_card: Control
var push := 0
var pad: HBoxContainer
var bg: ColorRect
var earth: Node3D
var saved := {}
var shake := 0.0


func enter(args: Dictionary) -> void:
	craft = str(args.get("craft", "apollo13"))
	then_scenes = args.get("then", [])
	back = str(args.get("back", "menu"))
	R = Reentry.new(craft)
	_build()
	_build_earth()


## The game's own Earth (the launch's horizon globe, NASA's textures and its air) under the capsule, seen from about
## 90 km up, for the plasma part; the parachutes then play over the drawn sky and sea.
func _build_earth() -> void:
	saved = Sets.save_world(world)
	world.clear_stage()
	world.cam_free = false
	world.cam.far = 20000.0
	world.cam.position = Vector3.ZERO
	world.cam.rotation = Vector3.ZERO
	world.cam.rotate_x(deg_to_rad(-8.0))
	earth = Scene3D.horizon_earth(EARTH_R)
	world.stage.add_child(earth)
	Scene3D.horizon_place(earth, Vector3.ZERO, EARTH_R, 700000.0, 6.371e6, 0.0)   # high enough to see the curve


func exit() -> void:
	world.cam_free = true
	Sets.restore_world(world, saved)


func _build() -> void:
	bg = ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.visible = false   # the plasma plays over the 3D Earth; the parachutes draw their own sky
	add_child(bg)
	view = Control.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.draw.connect(_draw_view)
	add_child(view)
	var head := Kit.vbox(4)
	Kit.place(head, 0, 0, 1, 0, 24 if Kit.compact else 40, 12 if Kit.compact else 24, -40, 140)
	add_child(head)
	head.add_child(Kit.caps(tr("Coming home") + "  ·  " + tr(str(R.D.date))))
	title_l = Kit.lbl(tr("Bring them home through the air"), 22 if Kit.compact else 30, Kit.C_ON_DARK, Kit.FONT_T)
	head.add_child(title_l)
	hint_l = Kit.lbl("", Kit.T_BODY, Kit.C_GOLD, Kit.FONT_B, true)
	head.add_child(hint_l)
	for l in [title_l, hint_l]:
		Kit.legible(l, 1.4)   # readable over the bright sky of the parachutes
	gauge = Control.new()
	if Kit.compact:   # a phone: a shorter scale, clear of the title and the buttons
		Kit.place(gauge, 0, 0.5, 0, 0.5, 30, -60, 100, 70)
	else:
		Kit.place(gauge, 0, 0.5, 0, 0.5, 60, -190, 150, 190)
	gauge.draw.connect(_draw_gauge)
	add_child(gauge)
	var right := Kit.vbox(6)
	Kit.place(right, 1, 0.5, 1, 0.5, -330, -120, -40, 140)
	add_child(right)
	big_l = Kit.lbl("", 34, Kit.C_ON_DARK, Kit.font_num())
	right.add_child(big_l)
	info_l = Kit.lbl("", Kit.T_BODY, Color(Kit.C_ON_DARK, 0.8), Kit.FONT_R, true)
	right.add_child(info_l)
	Kit.legible(big_l, 1.4)
	Kit.legible(info_l, 1.4)
	chute_btn = Kit.accent_btn(Kit.btn(tr("Drogues · 1"), func(): _chute(), Kit.T_ACTION), Kit.C_GOLD)
	chute_btn.visible = false
	right.add_child(chute_btn)
	var pad_box := Kit.panel_box(8)   # touch controls for the angle (phones), on a card so they read over the clouds
	if Kit.compact:
		Kit.place(pad_box, 1, 1, 1, 1, -310, -72, -14, -10)
	else:
		Kit.place(pad_box, 0, 1, 0, 1, 40, -100, 380, -26)
	add_child(pad_box)
	pad = Kit.hbox(Kit.GAP)
	pad_box.add_child(pad)
	for d in [[tr("▲ Shallower"), 1], [tr("▼ Steeper"), -1]]:
		var b := Kit.btn(d[0], func(): pass, Kit.T_BODY, 140)
		var v: int = d[1]
		b.button_down.connect(func(): push = v)
		b.button_up.connect(func(): push = 0)
		pad.add_child(b)
	black_l = Kit.lbl("", Kit.T_LEAD, Kit.C_WARN, Kit.FONT_B, true)
	black_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Kit.place(black_l, 0.5, 1, 0.5, 1, -360, -150, 360, -96)
	add_child(black_l)
	Kit.legible(black_l, 1.6)
	Kit.UiSound.play("notify")


func process(delta: float) -> void:
	if R.phase == "splash":
		if done_card == null:
			_finish()
		return
	var key_push := 0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		key_push = 1
	elif Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		key_push = -1
	R.step(delta, key_push if key_push != 0 else push)
	shake = R.heat() * (1.0 if R.in_corridor() else 1.8)
	_texts()
	view.queue_redraw()
	gauge.queue_redraw()


func _texts() -> void:
	if R.phase == "plasma":
		hint_l.text = tr("Keep the arrow inside the bright band: W or ▲ makes it shallower, S or ▼ steeper.")
		var side: String = R.off_side()
		big_l.text = "%s mph" % _num(R.speed_mph())
		info_l.text = tr("Angle %.1f°.") % R.angle + " " + (tr("Too steep: the heat shield is overheating!") if side == "steep" else (tr("Too shallow: the capsule could skip off the air!") if side == "shallow" else tr("In the corridor. Good.")))
		black_l.text = (tr("RADIO BLACKOUT · the glowing air blocks the radio.") + " " + tr(str(R.D.blackout_note))) if R.blackout() else ""
	else:
		var next_ft: float = float(R.D.drogue_ft) if R.drogue_err < 0.0 else float(R.D.main_ft)
		hint_l.text = tr("Open the parachutes on their marks: 1 for the drogues at %s ft, 2 for the mains at %s ft.") % [_num(float(R.D.drogue_ft)), _num(float(R.D.main_ft))]
		big_l.text = "%s ft" % _num(R.height_ft)
		info_l.text = tr("Next mark: %s ft.") % _num(next_ft) if R.main_err < 0.0 else tr("Under three main parachutes. Splashdown coming.")
		black_l.text = ""
		pad.get_parent().visible = false
		chute_btn.visible = R.main_err < 0.0
		chute_btn.text = tr("Drogues · 1") if R.drogue_err < 0.0 else tr("Mains · 2")


func _chute() -> void:
	var what: String = R.call_chute()
	if what != "":
		Kit.UiSound.play("select")
		var err: float = R.drogue_err if what == "drogue" else R.main_err
		Kit.toast(self, (tr("Drogues out!") if what == "drogue" else tr("Mains out!")) + "  " + (tr("Right on the mark.") if err < 800.0 else tr("%s ft off the mark.") % _num(err)), Kit.C_OK if err < 800.0 else Kit.C_GOLD, 1.6, 170.0)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = e.physical_keycode
	if R.phase == "chutes" and ((k == KEY_1 and R.drogue_err < 0.0) or (k == KEY_2 and R.drogue_err >= 0.0 and R.main_err < 0.0)):
		_chute()
		get_viewport().set_input_as_handled()
	elif done_card and (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE):
		_continue()
		get_viewport().set_input_as_handled()


func _finish() -> void:
	Kit.UiSound.play("notify")
	var n: int = R.stars()
	var v := Kit.overlay(self, tr("Splashdown!"), 620.0, 360.0, func(): _continue())
	done_card = v.get_parent().get_parent()
	v.add_child(Kit.lbl("★".repeat(n) + "☆".repeat(3 - n), 40, Kit.C_GOLD, Kit.FONT_B))
	v.add_child(Kit.lbl(tr(str(R.D.down_in)) % [str(R.D.craft), tr(str(R.D.date))], Kit.T_BODY, Kit.C_TEXT, Kit.FONT_R, true))
	v.add_child(Kit.lbl(tr("In the corridor %d %% of the time · drogues %s ft off · mains %s ft off.") % [roundi(R.corridor_quality() * 100.0), _num(R.drogue_err), _num(R.main_err)], Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))
	v.add_child(Kit.lbl(tr(str(R.D.simplified)) + " " + tr(str(R.D.sources_line)), Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))
	var row := Kit.hbox(Kit.GAP)
	v.add_child(row)
	row.add_child(Kit.btn(tr("Fly it again"), func(): go("reentry", {"craft": craft, "then": then_scenes, "back": back}), Kit.T_BODY))
	row.add_child(Kit.accent_btn(Kit.btn(tr("Continue · Enter"), func(): _continue(), Kit.T_ACTION), Kit.C_GOLD))


func _continue() -> void:
	if not then_scenes.is_empty():
		go("story", {"scenes": then_scenes, "back": back})
	else:
		go(back)


func _num(x: float) -> String:
	var v := roundi(x)
	return "%d,%03d" % [v / 1000, v % 1000] if v >= 1000 else str(v)


## The capsule, blunt heat shield first, tilted by its angle, inside the plasma's glow and its trailing streaks, over
## the Earth's curve; then the parachutes as canopies, and the ocean rising as it falls.
func _draw_view() -> void:
	var s := view.size
	var c := Vector2(s.x * 0.5, s.y * 0.5) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 6.0
	var t_ms := Time.get_ticks_msec() * 0.001
	if R.phase == "plasma":
		pass   # the 3D Earth and its stars (_build_earth)
	else:
		var sea_y: float = lerpf(s.y + 40.0, s.y * 0.7, 1.0 - R.height_ft / Reentry.TOP_FT)
		view.draw_rect(Rect2(0, 0, s.x, s.y), Color(0.35, 0.58, 0.85))
		view.draw_rect(Rect2(0, sea_y, s.x, s.y - sea_y), Color(0.06, 0.3, 0.55))
		for w in 12:
			var x := fmod(w * 157.0 + t_ms * 30.0, s.x)
			view.draw_line(Vector2(x, sea_y + 14 + (w % 3) * 18), Vector2(x + 40, sea_y + 14 + (w % 3) * 18), Color(1, 1, 1, 0.35), 2.0)
	# the capsule descends shield first (down-left); its tilt follows the angle around the corridor's middle
	var mid: float = (float(R.D.corridor_deg[0]) + float(R.D.corridor_deg[1])) * 0.5
	var rot: float = deg_to_rad(35.0 + (R.angle - mid) * 6.0) if R.phase == "plasma" else 0.0
	var tf := Transform2D(rot, c)
	var h: float = R.heat()
	if h > 0.0:
		for k in 14:   # streaks of glowing air trailing behind
			var off := Vector2(randf_range(-40, 40), 0)
			var a := tf * (Vector2(0, 40) + off)
			var b := tf * (Vector2(0, -160 - randf() * 140.0) + off * 1.6)
			view.draw_line(a, b, Color(1.0, 0.65, 0.25, minf(0.6 * h, 0.7)), 3.0, true)
		for i in 5:
			var r := 58.0 + i * 16.0 + randf() * 6.0
			view.draw_circle(tf * Vector2(0, 40), r * (0.7 + h * 0.6), Color(1.0, 0.5 + i * 0.1, 0.2 + i * 0.12, minf((0.75 - i * 0.12) * h * 1.5, 0.9)))
	if R.phase != "plasma":
		var n: int = 0 if R.drogue_err < 0.0 else (2 if R.main_err < 0.0 else 3)
		var big: bool = R.main_err >= 0.0
		for i in n:
			var x := (i - (n - 1) * 0.5) * (90.0 if big else 46.0)
			var top := c + Vector2(x, -170.0 if big else -120.0)
			var rr := 44.0 if big else 16.0
			view.draw_line(c + Vector2(0, -32), top + Vector2(-rr, 0), Color(1, 1, 1, 0.6), 1.2, true)
			view.draw_line(c + Vector2(0, -32), top + Vector2(rr, 0), Color(1, 1, 1, 0.6), 1.2, true)
			var dome := PackedVector2Array()
			for k in 13:
				dome.append(top + Vector2.from_angle(PI + PI * k / 12.0) * Vector2(rr, rr * 0.7))
			view.draw_colored_polygon(dome, Color(1.0, 0.5, 0.15) if i % 2 == 0 else Color(0.97, 0.97, 0.97))
	var cone := PackedVector2Array([tf * Vector2(-46, 30), tf * Vector2(46, 30), tf * Vector2(14, -34), tf * Vector2(-14, -34)])
	view.draw_colored_polygon(cone, Color(0.8, 0.82, 0.86))
	view.draw_line(tf * Vector2(-50, 34), tf * Vector2(50, 34), Color(0.3, 0.18, 0.1), 9.0, true)
	view.draw_line(tf * Vector2(-30, 0), tf * Vector2(30, 0), Color(0.5, 0.52, 0.56), 2.0)


## The corridor: a vertical scale of the angle, the green band, and the marker where the capsule is.
func _draw_gauge() -> void:
	var s := gauge.size
	if R.phase != "plasma":
		return
	var lo := -11.0
	var hi := -2.0
	var y_of := func(a: float) -> float: return s.y * (1.0 - (a - lo) / (hi - lo))
	gauge.draw_rect(Rect2(-12, -34, s.x + 24, s.y + 66), Color(0.02, 0.03, 0.07, 0.75))   # a dark card behind it
	gauge.draw_rect(Rect2(0, 0, s.x * 0.4, s.y), Color(1, 1, 1, 0.12))
	var y0: float = y_of.call(float(R.D.corridor_deg[1]))
	var y1: float = y_of.call(float(R.D.corridor_deg[0]))
	gauge.draw_rect(Rect2(0, y0, s.x * 0.4, y1 - y0), Color(Kit.C_OK, 0.95))
	gauge.draw_string(Kit.font_num(), Vector2(s.x * 0.45, y0 - 6.0), tr("corridor"), HORIZONTAL_ALIGNMENT_LEFT, 120, Kit.T_SMALL, Kit.C_OK)
	var ym: float = y_of.call(R.angle)
	var col: Color = Kit.C_OK if R.in_corridor() else Kit.C_BAD
	gauge.draw_colored_polygon(PackedVector2Array([Vector2(s.x * 0.42, ym), Vector2(s.x * 0.72, ym - 12), Vector2(s.x * 0.72, ym + 12)]), col)
	var f := Kit.font_num()
	gauge.draw_string(f, Vector2(0, -10), tr("shallow: skips off"), HORIZONTAL_ALIGNMENT_LEFT, 200, Kit.T_SMALL, Color(1, 1, 1, 0.7))
	gauge.draw_string(f, Vector2(0, s.y + 22), tr("steep: too hot"), HORIZONTAL_ALIGNMENT_LEFT, 200, Kit.T_SMALL, Color(1, 1, 1, 0.7))
