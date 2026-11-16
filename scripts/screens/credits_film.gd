extends "res://scripts/screens/screen.gd"
## The credits as a short film (issue #14): the camera flies the game's own 3D world (the real Earth, Ecuador, the
## Moon, an Earthrise at true scale through a long lens) while title cards fade, track in and type themselves out:
## the title, the team, the crew, what the game is made with, the NASA data, the AI that helped, and every source
## rolling up as at the end of a film. About a minute and a half; Skip (or Esc) jumps to the end card, which opens
## the full list of sources (the "credits" overlay) or goes back to the menu. Text comes from data/credits.json.

const CreditsList := preload("res://scripts/screens/credits.gd")
const CREDITS_PATH := "res://data/credits.json"
const Space := preload("res://scripts/world/space_builder.gd")
const Horizon := preload("res://scripts/ui/horizon.gd")
const Bots := preload("res://scripts/crew/bots.gd")
const UiSound := preload("res://scripts/ui/ui_sound.gd")

## The Moon at its true distance and size, in Earth radii: 384,400 km and 1,737 km against 6,371 km [S8].
const MOON_POS := Vector3(-60.3, 4.0, -8.0)
const MOON_R := 0.273
const END_T := 92.0

var data: Dictionary
var t := 0.0
var cues: Array = []           ## [time, Callable], fired once in order.
var next_cue := 0
var shots: Array = []          ## [time, position, look-at, fov], the camera's keyframes.
var earth: Node3D
var moon: Node3D
var layer: Control             ## Where the title cards live.
var roll: VBoxContainer        ## The rolling credits.
var ended := false
var old_fov := 75.0
var skip: Button
var ecu := Vector3.FORWARD     ## Direction of Ecuador from the Earth's centre.


func enter(_args: Dictionary) -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(CREDITS_PATH))
	world.clear_stage()
	world.cam_free = false
	old_fov = world.cam.fov
	world.cam.far = 400.0
	earth = Space.make_earth(1.0, true)
	world.stage.add_child(earth)
	world.planet = null          # the globe holds still, so the camera finds Ecuador where it expects it
	ecu = (earth.get_node("Surface/Ecuador") as Node3D).position.normalized()
	(earth.get_node("Surface/Ecuador/Label") as Node3D).visible = false
	moon = Space.make_moon(MOON_R)
	moon.position = MOON_POS
	world.stage.add_child(moon)
	_sun_from(Vector3(0.2, 0.15, 1.0))
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	black.create_tween().tween_property(black, "modulate:a", 0.0, 3.0).set_delay(1.0)
	layer = Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	skip = Kit.btn(tr("Skip ▶▶"), _to_end, Kit.T_BODY)
	Kit.place(skip, 1, 1, 1, 1, -150, -Kit.MARGIN - Kit.BTN_H, -Kit.MARGIN, -Kit.MARGIN)
	skip.modulate.a = 0.6
	add_child(skip)
	_script()
	_camera()


func exit() -> void:
	world.cam.fov = old_fov
	world.cam.h_offset = 0.0
	world.cam.v_offset = 0.0
	world.cam.far = 2000.0


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	for c in get_children():   # the list of every source is open on top: its keys are its own (#97: Esc and Enter
		if c.get_script() == CreditsList:   # went to the menu and left the list open over it)
			return
	var k: int = e.physical_keycode
	if not at_end and k in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_to_end()
	elif at_end and k in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_BACKSPACE]:
		go("menu")   # the end card's main action (issue #58)
	elif at_end and k == KEY_S:
		main.overlay("credits")
	else:
		return
	get_viewport().set_input_as_handled()


# ===================================================================================== THE FILM
func _script() -> void:
	var ec := Vector3.ZERO
	# camera: the night side and a sunrise over the limb, round to Ecuador, along the limb, out to the Moon,
	# down to its surface, the Earthrise through a long lens
	var up := Vector3.UP
	var away := MOON_POS.normalized()                    # from the Earth through the Moon
	var e1 := (ecu + up * 0.12).normalized()
	var e2 := e1.rotated(up, 0.5)
	var e3 := e1.rotated(up, 1.0)
	shots = [
		[0.0, Vector3(0.3, 0.25, -3.4), Vector3(0.2, 0.55, 0.0), 40.0, 0.0, 0.0],
		[9.0, Vector3(-0.6, 0.35, -2.9), Vector3(0.0, 0.5, 0.0), 40.0, 0.0, 0.0],
		[16.0, e1 * 2.7, Vector3.ZERO, 45.0, -1.05, 0.0],
		[24.0, e2 * 2.6, Vector3.ZERO, 45.0, -1.1, 0.0],
		[34.0, e3 * 3.6 + up * 0.8, Vector3.ZERO, 45.0, 0.0, 0.85],
		[44.0, e3.rotated(up, 0.6) * 5.0 + up * 1.2, Vector3.ZERO, 45.0, 0.0, 1.2],
		[52.0, MOON_POS - away * 1.6 + Vector3(0, 0.3, 0.9), MOON_POS, 40.0, -0.32, 0.0],
		[63.0, MOON_POS - away * 0.95 + Vector3(0, 0.15, 0.6), MOON_POS, 40.0, -0.3, 0.0],
		# the Earthrise: from behind the Moon, its limb filling the bottom, the Earth climbing over it, long lens
		[66.0, MOON_POS + away * 2.0 + up * 0.22, Vector3.ZERO + up * 0.2, 16.0, 0.0, 0.0],
		[END_T, MOON_POS + away * 2.0 + up * 0.36, Vector3.ZERO + up * 0.2, 14.0, 0.0, 0.0],
	]
	var people: Array = data.get("people", [])
	cues = [
		[1.5, func(): _arc(0.44, 0.5, 4.6)],
		[2.2, func(): _card(tr("SK-Horizons presents"), Kit.T_SHOUT * 0.5, Color(Kit.C_ON_DARK, 0.85), 0.52, 4.0, "fade")],   # as the loading screen: the arc above, the team below it
		[7.0, func(): _title()],
		[16.5, func(): _card_at(tr("Designed, launched and flown from"), Kit.T_LEAD, Kit.C_ON_DARK, 0.27, 0.36, 6.0, "fade", 720)],
		[17.3, func(): _card_at("Quito, Ecuador", Kit.T_CINEMA * 0.8, Kit.C_ON_DARK, 0.27, 0.45, 5.6, "track", 720)],
		[18.4, func(): _card_at("0.18° S · 78.47° W", Kit.T_BODY, Color(1, 0.8, 0.3), 0.27, 0.54, 4.6, "type", 720)],
		[24.5, func(): _card(tr("Made by"), Kit.T_LEAD, Color(Kit.C_ON_DARK, 0.8), 0.33, 12.6, "track")],
	]
	# the team at once, side by side and the same size, so nobody comes first; each with what they made, on the kit's
	# frosted panel so the words read over the bright clouds behind them
	var team_n := people.size()
	for i in team_n:
		var P: Dictionary = people[i]
		var x := (i + 0.5) / float(team_n) * 0.84 + 0.08
		var role := String(P.role).substr(0, 1).to_upper() + String(P.role).substr(1)
		cues.append([25.2, func(): _card_at(P.name, Kit.T_CINEMA * 0.5, Kit.C_ON_DARK, x, 0.43, 12.0, "type", 640)])
		cues.append([26.4, func(): _plate_at(role, x, 0.6, 10.6, 600)])
	var made := [["Godot", tr("the engine")], ["Blender", tr("every model of ours")], ["Inter", tr("every letter")], [tr("NASA open data"), tr("the Earth, the Moon, the Andes")]]
	for i in made.size():
		var M: Array = made[i]
		cues.append([44.0 + i * 1.7, func():
			UiSound.play("whoosh", 0.1)
			_card(M[0], Kit.T_CINEMA * 0.8, Kit.C_ON_DARK, 0.27, 1.6, "track")
			_card(M[1], Kit.T_LEAD, Color(Kit.C_ON_DARK, 0.8), 0.37, 1.6, "fade")])
	cues.append([44.0 - 0.6, func(): _card(tr("Made with"), Kit.T_BODY, Color(Kit.C_ON_DARK, 0.7), 0.14, 7.2, "track")])
	cues.append([53.0, func(): _card_at(tr("Real data from NASA"), Kit.T_SHOUT, Kit.C_ON_DARK, 0.3, 0.3, 12.0, "track", 760)])
	var nasa := ["Blue Marble · Black Marble · VIIRS", "LRO camera · LOLA altimeter · SVS Moon Kit", "SRTM elevation · JPL Horizons · NSSDC fact sheets", "Landsat 8 · EO-1 · ASTER · Voyager"]
	for i in nasa.size():
		var n: String = nasa[i]
		cues.append([54.2 + i * 0.9, func(): _card_at(n, Kit.T_LEAD, Color(1, 0.86, 0.6), 0.3, 0.4 + i * 0.06, 10.6 - i * 0.9, "type", 760)])
	cues.append([66.5, func(): _card(tr("With a little help"), Kit.T_BODY, Color(Kit.C_ON_DARK, 0.7), 0.14, 6.5, "track")])
	var ai: Array = data.get("ai", [])
	for i in ai.size():
		var a: String = ai[i]
		cues.append([67.2 + i * 0.8, func(): _card(a, Kit.T_BODY, Kit.C_ON_DARK, 0.2 + i * 0.05, 5.6 - i * 0.8, "fade", 900)])
	cues.append([73.0, func(): _roll()])
	cues.append([END_T - 2.0, func(): _to_end()])
	cues.sort_custom(func(a, b): return a[0] < b[0])


func process(delta: float) -> void:
	if ended:
		_camera()
		t += delta * 0.15   # the last shot keeps drifting, slowly
		return
	t += delta
	while next_cue < cues.size() and cues[next_cue][0] <= t:
		(cues[next_cue][1] as Callable).call()
		next_cue += 1
	_camera()


## The camera between its keyframes, eased, its look and field of view too.
func _camera() -> void:
	var cam: Camera3D = world.cam
	var tt := minf(t, END_T)
	var i := 0
	while i < shots.size() - 2 and shots[i + 1][0] <= tt:
		i += 1
	var a: Array = shots[i]
	var b: Array = shots[i + 1]
	var k := clampf((tt - a[0]) / maxf(b[0] - a[0], 0.001), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var pos: Vector3 = (a[1] as Vector3).lerp(b[1], k)
	var look: Vector3 = (a[2] as Vector3).lerp(b[2], k)
	cam.position = pos
	cam.look_at(look, Vector3.UP)
	cam.fov = lerpf(a[3], b[3], k)
	cam.h_offset = lerpf(a[4], b[4], k)   # frames the body to one side, so the words sit on dark space
	cam.v_offset = lerpf(a[5], b[5], k)
	# the Sun swings round as the camera does: a sunrise behind the Earth first, then light from behind the camera
	if tt < 15.0:
		_sun_from(Vector3(0.2, 0.15, 1.0))
	elif tt < 50.0:
		_sun_from((pos.normalized() + Vector3(0.5, 0.4, 0.0)).normalized().lerp(Vector3(0.2, 0.15, 1.0), clampf((17.0 - tt) / 2.0, 0.0, 1.0)))
	else:
		_sun_from(Vector3(0.6, 0.35, 0.7).normalized())


func _sun_from(dir: Vector3) -> void:
	world.sun.global_transform.basis = Basis.looking_at(-dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.FORWARD)


# ===================================================================================== TITLE CARDS
func _title() -> void:
	UiSound.play("success", 0.0)
	var h := Kit.hbox(18)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	Kit.place(h, 0, 0.5, 1, 0.5, 0, -70, 0, 50)
	layer.add_child(h)
	var f := Kit.legible(Kit.lbl("Farpoint", Kit.T_CINEMA, Kit.C_ON_DARK, Kit.FONT_T))
	h.add_child(f)
	var sp := FontVariation.new()
	sp.base_font = Kit.FONT_B
	sp.spacing_glyph = 40
	var hz := Kit.legible(Kit.lbl("HORIZON", Kit.T_CINEMA, Color(0.55, 0.78, 1.0), sp))
	h.add_child(hz)
	h.modulate.a = 0.0
	var tw := h.create_tween()
	tw.set_parallel(true)
	tw.tween_property(h, "modulate:a", 1.0, 1.6)
	tw.tween_property(sp, "spacing_glyph", 10, 3.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(4.0)
	tw.chain().tween_property(h, "modulate:a", 0.0, 1.2)
	tw.chain().tween_callback(h.queue_free)
	_arc(0.62, 0.36, 7.5)


## A paragraph on the kit's frosted panel centred at (x, y), fading in and out over `life` seconds: words that must be
## read over a bright planet.
func _plate_at(text: String, x: float, y: float, life: float, width: float) -> void:
	var p := Kit.panel_box(18)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Kit.lbl(text, Kit.T_LEAD, Kit.C_TEXT, Kit.FONT_R, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = width - 36.0
	p.add_child(l)
	Kit.place(p, x, y, x, y, -width / 2.0, -36, width / 2.0, 36)
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.modulate.a = 0.0
	layer.add_child(p)
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.8)
	tw.tween_interval(maxf(0.0, life - 1.6))
	tw.tween_property(p, "modulate:a", 0.0, 0.8)
	tw.tween_callback(p.queue_free)


## A line of text across the screen at height y (0..1), styled "track" (letters close in), "type" (typed out) or "fade".
func _card(text: String, size: float, col: Color, y: float, life: float, style: String, width := 1400.0) -> Label:
	return _card_at(text, size, col, 0.5, y, life, style, width)


func _card_at(text: String, size: float, col: Color, x: float, y: float, life: float, style: String, width := 1400.0) -> Label:
	var l := Kit.lbl(text, int(size), col, Kit.FONT_T if size >= Kit.T_STAT else Kit.FONT_B, true)
	l.add_theme_color_override("font_color", col)   # straight on the scene: keep the colour as given
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Kit.legible(l)
	var w := minf(width, 1400.0)
	Kit.place(l, x, y, x, y, -w / 2.0, -size * 0.8, w / 2.0, size * 0.8)
	layer.add_child(l)
	var tw := l.create_tween()
	match style:
		"track":
			var f := FontVariation.new()
			f.base_font = l.get_theme_font("font")
			f.spacing_glyph = int(size * 0.5)
			l.add_theme_font_override("font", f)
			l.modulate.a = 0.0
			tw.set_parallel(true)
			tw.tween_property(l, "modulate:a", 1.0, 0.9)
			tw.tween_property(f, "spacing_glyph", int(size * 0.06), 2.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			tw.set_parallel(false)
		"type":
			l.visible_ratio = 0.0
			tw.tween_property(l, "visible_ratio", 1.0, minf(1.6, 0.05 * text.length())).set_trans(Tween.TRANS_LINEAR)
		_:
			l.modulate.a = 0.0
			tw.tween_property(l, "modulate:a", 1.0, 0.9)
	tw.chain().tween_interval(maxf(0.3, life - 2.0))
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(l.queue_free)
	return l


## The brand's arc drawing itself across the screen at height y.
func _arc(y: float, sun: float, life: float) -> void:
	var a := Horizon.new()
	Kit.place(a, 0.15, y, 0.85, y, 0, -24, 0, 24)
	a.thickness = 2.5
	a.sun_at = sun
	a.progress = 0.0
	layer.add_child(a)
	var tw := a.create_tween()
	tw.tween_property(a, "progress", 1.0, 2.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.3, life - 3.2))
	tw.tween_property(a, "modulate:a", 0.0, 1.0)
	tw.tween_callback(a.queue_free)


## Every source rolling up the screen, section by section, as at the end of a film.
func _roll() -> void:
	roll = Kit.vbox(6)
	roll.custom_minimum_size.x = 840
	Kit.place(roll, 0.5, 1, 0.5, 1, -420, 40, 420, 40)
	layer.add_child(roll)
	var head := Kit.legible(Kit.lbl(tr("The sources behind every number"), Kit.T_STAT, Kit.C_ON_DARK, Kit.FONT_T, true))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roll.add_child(head)
	roll.add_child(Kit.spacer(Kit.GAP * 2))
	for sec in data.get("sections", []):
		var st := Kit.lbl(String(sec.title).to_upper(), Kit.T_SMALL, Color(1, 0.8, 0.45), Kit.FONT_B, true)
		st.add_theme_color_override("font_color", Color(1, 0.8, 0.45))
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		roll.add_child(Kit.spacer(Kit.GAP))
		roll.add_child(st)
		for e in sec.entries:
			# "NASA Earth Observatory (...), image pages ..." -> its first phrase
			var who: String = String(e.text).get_slice(". ", 0).get_slice(" https", 0)
			var l := Kit.legible(Kit.lbl("%s   %s" % [e.id, who.left(90)], Kit.T_BODY, Color(Kit.C_ON_DARK, 0.9), Kit.FONT_R, true))
			l.add_theme_color_override("font_color", Color(Kit.C_ON_DARK, 0.85))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			roll.add_child(l)
	await get_tree().process_frame
	var h := roll.size.y
	var tw := roll.create_tween()
	tw.tween_property(roll, "position:y", roll.position.y - h - get_viewport_rect().size.y - 80, END_T - 2.0 - t).set_trans(Tween.TRANS_LINEAR)


## The end card: the thanks, and the way out.
var at_end := false


func _to_end() -> void:
	at_end = true
	if ended:
		return
	ended = true
	t = maxf(t, 66.0)
	for c in layer.get_children():
		c.create_tween().tween_property(c, "modulate:a", 0.0, 0.6)
	var v := Kit.vbox(Kit.GAP)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	Kit.place(v, 0.5, 0.5, 0.5, 0.5, -500, -150, 500, 190)
	add_child(v)
	var a := Horizon.new()
	a.custom_minimum_size = Vector2(0, 40)
	a.sun_at = 0.5
	a.thickness = 2.5
	v.add_child(a)
	var th := Kit.legible(Kit.lbl(tr("Thank you for flying with us."), Kit.T_SHOUT, Kit.C_ON_DARK, Kit.FONT_T))
	th.add_theme_color_override("font_color", Kit.C_ON_DARK)
	th.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(th)
	var sub := Kit.lbl(tr("Farpoint HORIZON uses NASA's open data. NASA does not endorse it."), Kit.T_BODY, Color(Kit.C_ON_DARK, 0.7))
	sub.add_theme_color_override("font_color", Color(Kit.C_ON_DARK, 0.8))
	Kit.legible(sub)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(Kit.spacer(Kit.GAP))
	var row := Kit.hbox(Kit.GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	row.add_child(Kit.btn(tr("Every source") + "  ·  S", func(): main.overlay("credits"), Kit.T_BODY, 200))
	row.add_child(Kit.accent_btn(Kit.btn(tr("Back to the menu") + "  ·  Enter", func(): go("menu"), Kit.T_BODY, 200), Kit.C_GOLD))
	v.modulate.a = 0.0
	v.create_tween().tween_property(v, "modulate:a", 1.0, 1.2).set_delay(0.6)
	a.progress = 0.0
	a.create_tween().tween_property(a, "progress", 1.0, 2.0).set_delay(0.6)
	if skip and is_instance_valid(skip):
		skip.queue_free()
