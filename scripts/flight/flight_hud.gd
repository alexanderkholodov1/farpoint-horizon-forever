extends Control
## The pilot's panel, shared by the launch, the burn toward the Moon and the landing: readouts on the top left, an
## instrument on the bottom left (the attitude dial, or the landing radar), the controls on the bottom right (steering,
## throttle lever, a big action button, the autopilot switch), a message in the middle and a plain-words hint at the
## bottom. It only shows and reports: the screen that owns it runs the flight. Its own node, so the look (issue #12)
## can restyle it without touching the flight.
##   var hud := FlightHud.new(); add_child(hud); hud.build(tr("LAUNCH"), ...)

signal action_pressed                       ## The big button (STAGE, BURN...) or its key (Space).
signal throttle_changed(value: float)       ## The pilot moved the lever.
signal autopilot_toggled(on: bool)
signal skip_pressed
signal restart_pressed                      ## The pilot asked to fly this part again (add_restart()).
signal warp_changed(value: float)           ## How fast time runs changed.
signal warp_picked(value: float)            ## The pilot chose how fast time runs (a button or , .).

## How fast time can run: real time, then faster. The screen multiplies its real seconds by `warp`.
const WARPS := [1.0, 10.0, 100.0, 1000.0, 10000.0, 100000.0]
## How each gauge is drawn (Instruments.Gauge.look), by its name: what climbs is a rocket, what drains is a tank.
const GAUGE_LOOK := {"orbit": "climb", "burn": "climb", "fuel": "tank", "stress": "needle"}

const Kit := preload("res://scripts/ui/kit.gd")
const Instruments := preload("res://scripts/flight/instruments.gd")
const Sound := preload("res://scripts/flight/sound.gd")

var title: Label
var clock: Label
var readouts: GridContainer
var gauges: HBoxContainer
var dial: Instruments.Dial
var instrument_box: PanelContainer
var lever: Instruments.Lever
var action: Instruments.BigButton
var autopilot_btn: Instruments.Switch
var left_btn: Instruments.HoldButton
var right_btn: Instruments.HoldButton
var up_btn: Instruments.HoldButton
var down_btn: Instruments.HoldButton
var keys_lbl: Label
var big: Label
var sub: Label
var hint_lbl: Label
var hint_panel: PanelContainer
var _values := {}          ## readout name -> Label
var _gauges := {}          ## gauge name -> Instruments.Gauge
var _msg_tw: Tween
var autopilot := false
var warp := 1.0             ## Mission seconds per real second (1 is real time).
var warp_cap := 1.0         ## The fastest allowed now (an engine on, the ground near).
var warp_box: HBoxContainer
var warp_note: Label
var _warp_btns := {}        ## warp -> Button
var _top: VBoxContainer
var _cap_why := ""         ## Why time may not run faster now, said beside the warp.
var auto_note := ""        ## Set by a screen that runs time by itself ("Auto"), shown before the speed.
var extra_note := "":      ## Set by a screen to say what the speed changes in the picture, shown after it.
	set(v):
		if v != extra_note:
			extra_note = v
			_show_warp()


var _top_right: HBoxContainer
var ring: Instruments.TimingRing   ## The timing ring in the middle (ring_show, ring_grade).
var _hint_tw: Tween
var controls_panel: PanelContainer   ## The controls, bottom right (a screen may hide it while it has nothing to do).
var gauges_panel: PanelContainer   ## On a phone the gauges' own panel, top right.
var readouts_panel: PanelContainer   ## The readouts, top left.
var left_panel: Control   ## A screen's own panel bottom left instead of the instrument (the trip's mini-map): the hint starts after it.
var right_panel: Control   ## A screen's own panel top right (the trip's plan): the big message stays left of it.


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Builds the panel. action_label is the big button's word; four_way adds forward and back steering (the lander).
## Built with the UI kit's pieces, as the menu and the builder are (issue #12): frosted panels with room to breathe,
## small spaced capitals for section labels, joined choices, tabular numbers, the appearance's own colours.
func build(heading: String, action_label: String, keys_text: String, four_way := false, with_dial := true) -> void:
	# readouts, top left
	var p := Kit.panel_box(Kit.PAD)
	Kit.place(p, 0, 0, 0, 0, Kit.MARGIN, Kit.MARGIN, 300 if Kit.compact else 480, Kit.MARGIN)
	add_child(p)
	readouts_panel = p
	var v := Kit.vbox(Kit.GAP)
	p.add_child(v)
	_top = v
	title = Kit.caps(heading)
	v.add_child(title)
	title.visible = not Kit.compact   # on a phone the clock and the steps say where you are
	# the mission clock, as a lit display set into the console
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", Kit.flat(Color(0.0, 0.01, 0.03, 0.55), Color(Kit.C_GOLD, 0.35), 8, 1, 14, 4))
	clock = Kit.lbl("", Kit.T_CLOCK, Kit.C_GOLD, Kit.font_num())
	clock.add_theme_color_override("font_color", Color(1.0, 0.78, 0.42))
	plate.add_child(clock)
	v.add_child(plate)
	readouts = GridContainer.new()
	readouts.columns = 2
	v.add_child(readouts)
	gauges = Kit.hbox(8)
	if Kit.compact:
		# on a phone the gauges sit top right under Skip, so the readouts panel stays short
		var gp := Kit.panel_box(8)
		_console(gp)
		Kit.place(gp, 1, 0, 1, 0, -Kit.MARGIN, 64, -Kit.MARGIN, 64)
		gp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		gp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(gp)
		gp.add_child(gauges)
		gauges.visibility_changed.connect(func(): gp.visible = gauges.visible)
		gauges_panel = gp
	else:
		v.add_child(gauges)
	_console(p)
	# the instrument, bottom left
	instrument_box = Kit.panel_box(18)
	_console(instrument_box)
	if Kit.compact:
		Kit.place(instrument_box, 0, 1, 0, 1, Kit.MARGIN, -Kit.MARGIN, Kit.MARGIN, -Kit.MARGIN)
		instrument_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		Kit.place(instrument_box, 0, 1, 0, 1, 24, -262, 340, -24)
	add_child(instrument_box)
	if with_dial:
		dial = Instruments.Dial.new()
		dial.caption = TranslationServer.translate("Needle on the green")
		instrument_box.add_child(dial)
	else:
		instrument_box.visible = false
	# controls, bottom right
	var cp := Kit.panel_box(12 if Kit.compact else 20)
	_console(cp)
	controls_panel = cp
	if Kit.compact:
		Kit.place(cp, 1, 1, 1, 1, -Kit.MARGIN, -Kit.MARGIN, -Kit.MARGIN, -Kit.MARGIN)
		cp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		cp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		Kit.place(cp, 1, 1, 1, 1, -476, -330, -24, -24)
	add_child(cp)
	var ch := Kit.hbox(10 if Kit.compact else 18)
	cp.add_child(ch)
	var steer := Kit.vbox(8)
	steer.alignment = BoxContainer.ALIGNMENT_CENTER
	ch.add_child(steer)
	if four_way:
		up_btn = Instruments.HoldButton.new("▲")
		up_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		steer.add_child(up_btn)
	var lr := Kit.hbox(8)
	steer.add_child(lr)
	left_btn = Instruments.HoldButton.new("◀")
	right_btn = Instruments.HoldButton.new("▶")
	lr.add_child(left_btn)
	lr.add_child(right_btn)
	if four_way:
		down_btn = Instruments.HoldButton.new("▼")
		down_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		steer.add_child(down_btn)
	autopilot_btn = Instruments.Switch.new()
	autopilot_btn.pressed.connect(func(): set_autopilot(not autopilot, true))
	steer.add_child(autopilot_btn)
	lever = Instruments.Lever.new()
	lever.changed.connect(func(x): throttle_changed.emit(x))
	ch.add_child(lever)
	var av := Kit.vbox(10)
	av.alignment = BoxContainer.ALIGNMENT_CENTER
	ch.add_child(av)
	action = Instruments.BigButton.new()
	action.label = action_label
	action.pressed.connect(func(): action_pressed.emit())
	av.add_child(action)
	keys_lbl = Kit.lbl(keys_text, Kit.T_CAPS, Kit.C_DIM, Kit.FONT_R, true)
	keys_lbl.modulate.a = 0.75
	keys_lbl.custom_minimum_size.x = 132
	keys_lbl.visible = not Kit.compact   # keyboard keys mean nothing to fingers
	keys_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av.add_child(keys_lbl)
	# sound and skip, top right
	var tr_panel := Kit.panel_box(8)
	Kit.place(tr_panel, 1, 0, 1, 0, -Kit.MARGIN, Kit.MARGIN, -Kit.MARGIN, Kit.MARGIN)
	tr_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN   # as wide as its buttons, against the right edge
	add_child(tr_panel)
	var tr_box := Kit.hbox(8)
	tr_panel.add_child(tr_box)
	var skip := Kit.btn(TranslationServer.translate("Skip ▶▶") + ("" if Kit.compact else "  · K"), func(): skip_pressed.emit(), Kit.T_BODY, 0 if Kit.compact else 128)
	skip.focus_mode = Control.FOCUS_NONE
	skip.custom_minimum_size.y = Kit.BTN_H
	tr_box.add_child(skip)
	_top_right = tr_box
	# the message, straight on the scene, and the hint in its own panel
	big = Kit.lbl("", Kit.T_SHOUT, Kit.C_ON_DARK, Kit.FONT_T)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Kit.legible(big)   # straight on the scene: readable over the white pad, clouds and the Moon
	if Kit.compact:
		Kit.place(big, 0, 0.27, 1, 0.27, 310, -40, -310, 24)
	else:
		Kit.place(big, 0, 0.2, 1, 0.2, 500, -50, -400, 32)
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(big)
	sub = Kit.lbl("", Kit.T_ACTION, Kit.C_ON_DARK, Kit.FONT_B, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Kit.legible(sub, 1.3)
	if Kit.compact:
		sub.add_theme_font_size_override("font_size", Kit.T_LEAD)
		Kit.place(sub, 0, 0.27, 1, 0.27, 310, 26, -310, 96)
	else:
		Kit.place(sub, 0, 0.2, 1, 0.2, 520, 38, -420, 110)   # the column between the readouts and the buttons, at any width
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub)
	ring = Instruments.TimingRing.new()
	Kit.place(ring, 0.5, 0.5, 0.5, 0.5, -320, -250, 320, 330)
	ring.visible = false
	add_child(ring)
	var hb: Array = Kit.hint_box()
	hint_panel = hb[0]
	hint_lbl = hb[1]
	if Kit.compact:
		# between the bottom-left instrument (about 230 wide) and the controls (about 350): the middle of the screen
		Kit.place(hint_panel, 0, 1, 1, 1, 256, -Kit.MARGIN, -364, -Kit.MARGIN)
		hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		hint_lbl.add_theme_font_size_override("font_size", Kit.T_BODY)
		hint_lbl.max_lines_visible = 4   # a long hint is cut on a phone rather than covering the scene
	else:
		Kit.place(hint_panel, 0.5, 1, 0.5, 1, -400, -128, 330, -Kit.MARGIN)   # clear of the mini-map on narrower screens (#76)
		hint_panel.offset_top = -Kit.MARGIN
		hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN   # a long hint grows up, never past the bottom edge
	add_child(hint_panel)
	hint_panel.visible = false


## On a phone nothing may cover anything (issue #93), whatever the screen's height: every frame the controls shrink
## from their corner just enough to sit under the gauges, the instrument under the readouts, and the hint and the big
## message take the gap that is really left between the panels.
func _process(_delta: float) -> void:
	if not Kit.compact or controls_panel == null:
		return
	var view: Vector2 = get_viewport_rect().size
	var gap := 6.0
	var s := 1.0
	if controls_panel.visible:
		var limit: float = Kit.MARGIN
		if gauges_panel and gauges_panel.visible:
			limit = gauges_panel.get_global_rect().end.y + gap
		elif _top_right:
			limit = _top_right.get_parent().get_global_rect().end.y + gap
		s = Kit.fit_under(controls_panel, limit, true)
	if instrument_box and instrument_box.visible and readouts_panel:
		Kit.fit_under(instrument_box, readouts_panel.get_global_rect().end.y + gap, false)
	var left: float = Kit.MARGIN
	if instrument_box and instrument_box.visible:
		left = instrument_box.get_global_rect().end.x + gap
	if left_panel and left_panel.visible:
		Kit.fit_under(left_panel, readouts_panel.get_global_rect().end.y + gap, false)
		left = maxf(left, left_panel.get_global_rect().end.x + gap)
	var right: float = view.x - Kit.MARGIN
	if controls_panel.visible:
		right = controls_panel.get_global_rect().position.x - gap
	if hint_panel:
		hint_panel.offset_left = left
		hint_panel.offset_right = minf(right, view.x - Kit.MARGIN) - view.x
	# the big message: between the readouts and the gauges (or the top-right buttons)
	var mid_l: float = (readouts_panel.get_global_rect().end.x if readouts_panel and readouts_panel.visible else 0.0) + gap
	var mid_r: float = view.x - gap
	if gauges_panel and gauges_panel.visible:
		mid_r = gauges_panel.get_global_rect().position.x - gap
	if right_panel and right_panel.visible:
		mid_r = minf(mid_r, right_panel.get_global_rect().position.x - gap)
	for l in [big, sub]:
		if l:
			l.offset_left = mid_l
			l.offset_right = mid_r - view.x


## Makes a panel read as a piece of the craft's console: a rivet in each corner and a warm bar at its top edge.
func _console(p: PanelContainer) -> void:
	p.draw.connect(func():
		var sz := p.size
		for q in [Vector2(11, 11), Vector2(sz.x - 11, 11), Vector2(11, sz.y - 11), Vector2(sz.x - 11, sz.y - 11)]:
			p.draw_circle(q, 3.2, Color(Kit.C_TEXT, 0.32))
			p.draw_circle(q, 1.3, Color(0, 0, 0, 0.55))
		p.draw_line(Vector2(26, 1.5), Vector2(84, 1.5), Kit.C_GOLD, 3.0)
		p.draw_line(Vector2(90, 1.5), Vector2(98, 1.5), Color(Kit.C_GOLD, 0.6), 3.0))


## A Restart button beside Skip: the pilot can always fly this part again, whatever happened (never a dead end).
func add_restart() -> void:
	var b := Kit.btn(TranslationServer.translate("↺ Restart") + "  · R", func(): restart_pressed.emit(), Kit.T_BODY, 128)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = Kit.BTN_H
	_top_right.add_child(b)
	_top_right.move_child(b, 1)


func _sound_text() -> String:
	return TranslationServer.translate("Sound off") if Sound.is_muted() else TranslationServer.translate("Sound on")


## Adds the time control under the clock: real time and faster, chosen with the buttons or the keys , and . ;
## `cap` is the fastest allowed at first. A note says in words how fast time runs, so the clock never misleads.
func add_time_warp(cap := 1.0) -> void:
	warp_box = Kit.segmented()
	for w in WARPS:
		var b := Kit.choice(_warp_label(w), false, func(): set_warp(w, true), 0 if Kit.compact else 66)
		_warp_btns[w] = b
		warp_box.add_child(b)
	_top.add_child(warp_box)
	_top.move_child(warp_box, 2)
	warp_note = Kit.lbl("", Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R)
	_top.add_child(warp_note)
	_top.move_child(warp_note, 3)
	cap_warp(cap)


static func _warp_label(w: float) -> String:
	return "×1" if w <= 1.0 else "×" + ("%dk" % roundi(w / 1000.0) if w >= 1000.0 else "%d" % roundi(w))


## Sets how fast time runs (kept at most warp_cap).
func set_warp(w: float, by_pilot := false) -> void:
	w = clampf(w, 1.0, warp_cap)
	var changed := w != warp
	warp = w
	_show_warp()
	if changed:
		warp_changed.emit(warp)
	if by_pilot:
		warp_picked.emit(warp)


## The fastest time may run now; why is said in the note. Lowers the current warp when it is above.
func cap_warp(cap: float, why := "") -> void:
	warp_cap = cap
	if warp > cap:
		set_warp(cap)
	_cap_why = why
	_show_warp()


func _show_warp() -> void:
	if warp_box == null:
		return
	# the speed lit in the accent colour only when time runs exactly at it; at a speed the flight set itself (a burn
	# at x50, a wait at x8,640) no button is lit and the line below says the real one (#57: x10 was lit at x50)
	var lit_w := -1.0
	for w in _warp_btns:
		if absf(w - warp) <= 0.001 * maxf(w, 1.0):
			lit_w = w
	for w in _warp_btns:
		var b: Button = _warp_btns[w]
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.remove_theme_stylebox_override(st)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.remove_theme_color_override(k)
		b.visible = w <= warp_cap   # only the speeds allowed now: fewer things to read
		if w == lit_w:
			Kit.accent_btn(b, Kit.C_ACCENT)
	var t: String = TranslationServer.translate("Real time") if warp <= 1.0 else TranslationServer.translate("Time runs %s times faster") % _thousands(warp)
	if auto_note != "":
		t = auto_note + " · " + t
	if _cap_why != "":
		t += " · " + _cap_why
	if extra_note != "":
		t += " · " + extra_note
	warp_note.text = t
	warp_note.visible = warp > 1.0 or auto_note != ""   # at real time there is nothing to add


## 100000 as "100,000".
static func _thousands(v: float) -> String:
	var s := str(roundi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


## Mission elapsed time as the clock shows it: "T+ 00:52:10", with days when there are.
static func met_text(seconds: float) -> String:
	var s := maxi(roundi(seconds), 0)
	var d := s / 86400
	var h := (s % 86400) / 3600
	var m := (s % 3600) / 60
	var text := "T+ %02d:%02d:%02d" % [h, m, s % 60]
	if d > 0:
		text = "T+ %d d %02d:%02d:%02d" % [d, h, m, s % 60]
	return text


## Adds a readout (name, then its value label); set it with value(name, text).
func add_readout(name_: String, label: String) -> void:
	_values[name_] = Kit.readout(readouts, label)


## Sets a readout. col is a status colour (Kit.C_OK...); white or none means the appearance's plain text colour, and
## any colour is made readable on the current panels (Kit.ink).
func value(name_: String, text: String, col := Color.WHITE) -> void:
	var l: Label = _values[name_]
	l.text = text
	l.add_theme_color_override("font_color", Kit.C_TEXT if col == Color.WHITE else Kit.ink(col))


## Adds a gauge; set it with gauge(name, 0..1, text).
func add_gauge(name_: String, label: String, warn_at := 2.0, bad_at := 2.0, col := Color(0.4, 0.75, 1.0)) -> void:
	var g := Instruments.Gauge.new()
	g.look = GAUGE_LOOK.get(name_, "needle")
	g.title = label
	g.warn_at = warn_at
	g.bad_at = bad_at
	g.color = col
	gauges.add_child(g)
	_gauges[name_] = g


func gauge(name_: String, v: float, text := "") -> void:
	var g: Instruments.Gauge = _gauges[name_]
	g.value = v
	g.text = text


## Shows the timing ring this frame: `remaining` from 1 (far) to 0 (press now), `window` how near 0 is on time.
func ring_show(label: String, remaining: float, window := 0.05) -> void:
	ring.active = true
	ring.label = label
	ring.remaining = remaining
	ring.window = window


## Flashes how a timed press went ("PERFECT", "LATE"...).
func ring_grade(text: String, col: Color) -> void:
	ring.grade(text, col)
	Sound.player(self, "chime" if col == Kit.C_OK else "beep").play()


## Renames a gauge (the same instrument reads the speed added in a burn and the speed lost in a brake).
func name_gauge(name_: String, label: String) -> void:
	_gauges[name_].title = label


func show_gauge(name_: String, on: bool) -> void:
	_gauges[name_].visible = on


## A message in the middle: a big line and a small one, for `time` seconds (0 keeps it).
func message(big_text: String, small_text := "", col := Color.WHITE, time := 2.5) -> void:
	if _msg_tw and _msg_tw.is_valid():
		_msg_tw.kill()
	big.text = big_text
	sub.text = small_text
	var fs := Kit.T_SHOUT
	while fs > 30 and Kit.FONT_T.get_string_size(big_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxf(size.x - 920.0, 300.0):
		fs -= 2
	big.add_theme_font_size_override("font_size", fs)
	big.add_theme_color_override("font_color", col)
	big.modulate.a = 1.0
	sub.modulate.a = 1.0
	big.scale = Vector2.ONE
	big.pivot_offset = big.size / 2.0
	big.scale = Vector2(1.18, 1.18)
	_msg_tw = create_tween()
	_msg_tw.tween_property(big, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if time > 0.0:
		_msg_tw.tween_interval(time)
		_msg_tw.tween_property(big, "modulate:a", 0.0, 0.5)
		_msg_tw.parallel().tween_property(sub, "modulate:a", 0.0, 0.5)


## The plain-words line at the bottom ("" hides it).
func hint(text: String) -> void:
	hint_panel.visible = text != ""
	if hint_lbl.text != text:
		hint_lbl.text = text
		hint_panel.modulate.a = 0.0
		# it comes in, stays long enough to be read (longer for a longer text) and steps aside: the screen stays clear
		if _hint_tw and _hint_tw.is_valid():
			_hint_tw.kill()
		_hint_tw = hint_panel.create_tween()
		_hint_tw.tween_property(hint_panel, "modulate:a", 1.0, 0.3)
		_hint_tw.tween_interval(6.0 + text.length() * 0.06)
		_hint_tw.tween_property(hint_panel, "modulate:a", 0.0, 1.0)


func set_autopilot(on: bool, by_pilot := false) -> void:
	autopilot = on
	autopilot_btn.on = on
	if by_pilot:
		autopilot_toggled.emit(on)


func _plain(b: Button) -> void:
	for s in ["normal", "hover", "pressed"]:
		b.remove_theme_stylebox_override(s)


## Steering from the keys and the on-screen buttons: x is left (-1) to right (1); y is back (-1) to forward (1).
func steer() -> Vector2:
	var s := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A) or (left_btn and left_btn.held):
		s.x -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D) or (right_btn and right_btn.held):
		s.x += 1.0
	if Input.is_physical_key_pressed(KEY_UP) or (up_btn and up_btn.held):
		s.y += 1.0
	if Input.is_physical_key_pressed(KEY_DOWN) or (down_btn and down_btn.held):
		s.y -= 1.0
	return s


## Throttle keys: W or Shift up, S or Ctrl down (per second), Z full, X cut. Returns the new throttle.
func throttle_keys(current: float, delta: float, rate := 0.8) -> float:
	var t := current
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_SHIFT):
		t += rate * delta
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_CTRL):
		t -= rate * delta
	if Input.is_physical_key_pressed(KEY_Z):
		t = 1.0
	if Input.is_physical_key_pressed(KEY_X):
		t = 0.0
	t = clampf(t, 0.0, 1.0)
	lever.value = t
	return t


## True when the pilot touches any control (the keys or the on-screen buttons): a person takes over the autopilot.
func pilot_input() -> bool:
	for k in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_A, KEY_D, KEY_W, KEY_S, KEY_Z, KEY_X]:
		if Input.is_physical_key_pressed(k):
			return true
	for b in [left_btn, right_btn, up_btn, down_btn]:
		if b and b.held:
			return true
	return false


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_SPACE:
		action.press()
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_P:
		set_autopilot(not autopilot, true)
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_K:
		skip_pressed.emit()
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_R:
		restart_pressed.emit()
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo and warp_box and (e.physical_keycode == KEY_PERIOD or e.physical_keycode == KEY_COMMA):
		var i := WARPS.find(warp)
		i = clampi(i + (1 if e.physical_keycode == KEY_PERIOD else -1), 0, WARPS.size() - 1)
		set_warp(WARPS[i], true)
		get_viewport().set_input_as_handled()
