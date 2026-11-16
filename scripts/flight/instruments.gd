extends RefCounted
## The pilot's instruments, drawn in code so they feel like hardware: the attitude dial with the guidance marker, the
## throttle lever, a stage button that glows when it is time, gauges, and hold-to-steer buttons for touch screens.
##   const Instruments := preload("res://scripts/flight/instruments.gd")
##   var dial := Instruments.Dial.new()

const Kit := preload("res://scripts/ui/kit.gd")

const C_PANEL := Color(0.05, 0.08, 0.13, 0.92)
const C_EDGE := Color(0.45, 0.62, 0.85, 0.35)
const C_MARK := Color(0.42, 0.95, 0.6)
const C_NEEDLE := Color(1.0, 0.97, 0.9)


## Where the rocket points (pitch, degrees from straight up toward downrange) against where guidance wants it (marker).
## The green wedge is the marker; the white needle is the rocket. Inside the wedge you are on course.
class Dial extends Control:
	var pitch := 0.0
	var marker := 0.0
	var tolerance := 5.0
	var caption := ""
	var _pulse := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(200, 128) if Kit.compact else Vector2(270, 180)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_pulse += delta
		queue_redraw()

	func _draw() -> void:
		var r := minf(size.y - 46.0, size.x - 92.0)
		var c := Vector2(26.0, size.y - 26.0)
		# the arc from straight up (0) to flat (90) and a little below
		var a0 := deg_to_rad(-92.0)
		var a1 := deg_to_rad(12.0)
		draw_arc(c, r, a0, a1, 48, Kit.C_LINE, 16.0, true)
		# marker wedge
		var on := absf(pitch - marker) <= tolerance
		var mk := deg_to_rad(clampf(marker, -2.0, 102.0) - 90.0)
		var w := deg_to_rad(tolerance)
		var mc: Color = C_MARK if on else C_MARK.lerp(Color(1, 0.8, 0.3), 0.5 + 0.5 * sin(_pulse * 6.0))
		draw_arc(c, r, mk - w, mk + w, 12, Color(mc.r, mc.g, mc.b, 0.85), 16.0, true)
		draw_line(c + Vector2.from_angle(mk) * (r - 14.0), c + Vector2.from_angle(mk) * (r + 14.0), mc, 3.0, true)
		# ticks every 15 degrees
		for d in range(0, 106, 15):
			var a := deg_to_rad(float(d) - 90.0)
			var len := 10.0 if d % 45 == 0 else 5.0
			draw_line(c + Vector2.from_angle(a) * (r + 10.0), c + Vector2.from_angle(a) * (r + 10.0 + len), Color(Kit.C_TEXT.r, Kit.C_TEXT.g, Kit.C_TEXT.b, 0.45), 1.5, true)
		# the rocket needle, drawn as a small rocket
		var pa := deg_to_rad(clampf(pitch, -5.0, 110.0) - 90.0)
		var dir := Vector2.from_angle(pa)
		var side := dir.orthogonal()
		draw_line(c, c + dir * (r - 4.0), Color(Kit.C_TEXT.r, Kit.C_TEXT.g, Kit.C_TEXT.b, 0.25), 1.0, true)
		var tip := c + dir * (r * 0.7)
		var mid := c + dir * (r * 0.52)
		var base := c + dir * (r * 0.16)
		draw_colored_polygon(PackedVector2Array([tip, mid + side * 6.0, base + side * 6.0, base - side * 6.0, mid - side * 6.0]), C_NEEDLE)
		draw_colored_polygon(PackedVector2Array([base + side * 6.0, base + side * 13.0 - dir * 5.0, base + side * 6.0 + dir * 12.0]), C_NEEDLE)
		draw_colored_polygon(PackedVector2Array([base - side * 6.0, base - side * 13.0 - dir * 5.0, base - side * 6.0 + dir * 12.0]), C_NEEDLE)
		var fl := 8.0 + 4.0 * sin(_pulse * 28.0)
		draw_colored_polygon(PackedVector2Array([base + side * 4.0, base - side * 4.0, base - dir * fl]), Color(1.0, 0.66, 0.26))
		# labels
		var f: Font = Kit.FONT_B
		draw_string(f, c + Vector2(22, -r + 4), TranslationServer.translate("UP"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_DIM)
		draw_string(f, c + Vector2(r - 30, -10), TranslationServer.translate("FLAT"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_DIM)
		if caption != "":
			draw_string(Kit.FONT_R, Vector2(size.x - 200, size.y - 4), caption, HORIZONTAL_ALIGNMENT_RIGHT, 200, Kit.T_SMALL, Kit.C_DIM)


## A throttle lever, 0 to 1. Drag it, or set `value`. Emits changed(value) when the pilot moves it.
class Lever extends Control:
	signal changed(value: float)
	var value := 1.0
	var title := "THROTTLE"
	var marks: Array = []          ## Values to draw a notch at (hover, for the lander).
	var _drag := false

	func _init() -> void:
		custom_minimum_size = Vector2(80, 196) if Kit.compact else Vector2(104, 262)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_VSIZE

	func _process(_d: float) -> void:
		queue_redraw()

	func _slot() -> Rect2:
		return Rect2(Vector2(size.x / 2.0 - 9.0, 34.0), Vector2(18.0, size.y - 74.0))

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			_drag = e.pressed
			if e.pressed:
				_set_from(e.position.y)
			accept_event()
		elif e is InputEventMouseMotion and _drag:
			_set_from(e.position.y)
			accept_event()
		elif e is InputEventScreenTouch or e is InputEventScreenDrag:
			_set_from(e.position.y)
			accept_event()

	func _set_from(y: float) -> void:
		var s := _slot()
		value = clampf(1.0 - (y - s.position.y) / s.size.y, 0.0, 1.0)
		changed.emit(value)

	func _draw() -> void:
		var s := _slot()
		draw_style_box(Kit.flat(Kit.C_CARD, Kit.C_LINE, 9, 1, 0, 0), s)
		var fill := Rect2(s.position + Vector2(3, s.size.y * (1.0 - value)), Vector2(s.size.x - 6, s.size.y * value))
		var col := Color(1.0, 0.62, 0.22).lerp(Color(1.0, 0.86, 0.45), value)
		draw_style_box(Kit.flat(Color(col.r, col.g, col.b, 0.85), Color(0, 0, 0, 0), 6, 0, 0, 0), fill)
		for m in marks:
			var my: float = s.position.y + s.size.y * (1.0 - float(m))
			draw_line(Vector2(s.position.x - 8, my), Vector2(s.end.x + 8, my), Color(0.6, 0.95, 0.7, 0.8), 2.0)
		for i in 5:
			var ty := s.position.y + s.size.y * i / 4.0
			draw_line(Vector2(s.end.x + 4, ty), Vector2(s.end.x + 10, ty), Kit.C_LINE, 1.0)
		# the handle
		var hy := s.position.y + s.size.y * (1.0 - value)
		var hr := Rect2(Vector2(s.position.x - 20, hy - 9), Vector2(s.size.x + 40, 18))
		draw_style_box(Kit.flat(Color(0.86, 0.9, 0.96), Color(1, 1, 1), 5, 1, 0, 0), hr)
		draw_line(Vector2(hr.position.x + 8, hy), Vector2(hr.end.x - 8, hy), Color(0.3, 0.35, 0.42), 2.0)
		draw_string(Kit.FONT_B, Vector2(0, 18), TranslationServer.translate(title), HORIZONTAL_ALIGNMENT_CENTER, size.x, Kit.T_SMALL, Kit.C_DIM)
		draw_string(Kit.font_num(), Vector2(0, size.y - 12), "%d %%" % roundi(value * 100.0), HORIZONTAL_ALIGNMENT_CENTER, size.x, Kit.T_VALUE, Kit.C_TEXT)


## A cockpit gauge, 0 to 1, drawn as the thing it measures (`look`), coloured by `warn_at` and `bad_at`:
##   "climb": a small rocket climbing from the ground to the ring of the orbit (speed toward orbit, speed added);
##   "tank": a fuel tank that drains;
##   "needle": a round dial with its fine, caution and danger arcs and a needle (stress).
class Gauge extends Control:
	var title := ""
	var value := 0.0
	var text := ""
	var warn_at := 2.0
	var bad_at := 2.0
	var color := Color(0.4, 0.75, 1.0)
	var look := "needle"
	var _shown := 0.0      ## The value the gauge draws, easing toward `value` (a needle has weight).
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(100, 146) if Kit.compact else Vector2(124, 150)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		_shown = lerpf(_shown, clampf(value, 0.0, 1.2), clampf(delta * 6.0, 0.0, 1.0))
		queue_redraw()

	func _draw() -> void:
		var col := color
		if value >= bad_at:
			col = Kit.C_BAD
		elif value >= warn_at:
			col = Kit.C_WARN
		var v := clampf(_shown, 0.0, 1.0)
		var w := size.x
		var cx := w * 0.5
		var ink: Color = Kit.C_TEXT
		var line := Color(ink.r, ink.g, ink.b, 0.28)
		match look:
			"climb":
				var y0 := 96.0
				var y1 := 16.0
				# the ground, the way up, the orbit to reach
				draw_arc(Vector2(cx, y0 + 46.0), 52.0, -PI * 0.78, -PI * 0.22, 24, Color(Kit.C_ACCENT, 0.9), 3.0, true)
				for k in 9:
					var yy := lerpf(y0 - 8.0, y1 + 6.0, k / 8.0)
					draw_line(Vector2(cx, yy), Vector2(cx, yy - 3.0), line, 2.0)
				draw_arc(Vector2(cx, y1 + 60.0), 62.0, -PI * 0.66, -PI * 0.34, 24, Color(Kit.C_GOLD, 0.95), 2.0, true)
				# the rocket, with its flame while it climbs
				var ry := lerpf(y0 - 10.0, y1 + 8.0, v)
				var flick := 4.0 + 3.0 * sin(_t * 30.0)
				if v < 0.995:
					draw_colored_polygon(PackedVector2Array([Vector2(cx - 4, ry + 8), Vector2(cx + 4, ry + 8), Vector2(cx, ry + 12 + flick)]), Kit.C_GOLD)
				draw_colored_polygon(PackedVector2Array([Vector2(cx, ry - 11), Vector2(cx + 5, ry - 2), Vector2(cx + 5, ry + 8), Vector2(cx - 5, ry + 8), Vector2(cx - 5, ry - 2)]), col)
				draw_colored_polygon(PackedVector2Array([Vector2(cx - 5, ry + 2), Vector2(cx - 10, ry + 9), Vector2(cx - 5, ry + 8)]), col)
				draw_colored_polygon(PackedVector2Array([Vector2(cx + 5, ry + 2), Vector2(cx + 10, ry + 9), Vector2(cx + 5, ry + 8)]), col)
			"tank":
				var r := Rect2(Vector2(cx - 22.0, 12.0), Vector2(44.0, 88.0))
				draw_style_box(Kit.flat(Color(0, 0, 0, 0.3), line, 20, 2, 0, 0), r)
				var inner := r.grow(-5.0)
				var hgt := inner.size.y * v
				if hgt > 1.0:
					var wave := 1.5 * sin(_t * 3.0)
					draw_style_box(Kit.flat(Color(col, 0.9), Color(0, 0, 0, 0), 14, 0, 0, 0), Rect2(Vector2(inner.position.x, inner.end.y - hgt + wave), Vector2(inner.size.x, hgt - wave)))
				for k in [0.25, 0.5, 0.75]:
					var ty: float = inner.end.y - inner.size.y * k
					draw_line(Vector2(r.end.x + 3.0, ty), Vector2(r.end.x + 9.0, ty), line, 1.5)
				draw_line(Vector2(cx - 5.0, 8.0), Vector2(cx + 5.0, 8.0), line, 3.0)   # the filler cap
			_:
				var c := Vector2(cx, 74.0)
				var rad := 50.0
				var a0 := PI * 0.85
				var a1 := PI * 2.15
				var span := a1 - a0
				var w_at := clampf(warn_at, 0.0, 1.0)
				var b_at := clampf(bad_at, 0.0, 1.0)
				draw_arc(c, rad, a0, a0 + span * w_at, 24, Color(Kit.C_OK, 0.85), 7.0, true)
				if b_at > w_at:
					draw_arc(c, rad, a0 + span * w_at, a0 + span * b_at, 12, Color(Kit.C_WARN, 0.9), 7.0, true)
				if b_at < 1.0:
					draw_arc(c, rad, a0 + span * b_at, a1, 12, Color(Kit.C_BAD, 0.9), 7.0, true)
				for k in 9:
					var a := a0 + span * k / 8.0
					draw_line(c + Vector2.from_angle(a) * (rad - 12.0), c + Vector2.from_angle(a) * (rad - 6.0), line, 1.5, true)
				var na := a0 + span * v + (0.012 * sin(_t * 23.0) if value >= warn_at else 0.0)   # it trembles when stressed
				draw_line(c, c + Vector2.from_angle(na) * (rad - 14.0), col, 3.0, true)
				draw_circle(c, 6.0, col)
				draw_circle(c, 2.5, Color(0, 0, 0, 0.6))
		# the number and the name, as engraved under an instrument
		draw_string(Kit.font_num(), Vector2(0, 122), text, HORIZONTAL_ALIGNMENT_CENTER, w, Kit.T_BODY, Kit.ink(col) if value >= warn_at else ink)
		draw_multiline_string(Kit.FONT_B, Vector2(0, 137), title.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, w, Kit.T_CAPS - 1, 2, Kit.C_DIM)


## A big round push button (STAGE). `lit` makes it glow; pressed emits `pressed`.
class BigButton extends Control:
	signal pressed
	var label := "STAGE"
	var lit := false
	var color := Color(1.0, 0.55, 0.2)
	var _t := 0.0
	var _down := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(104, 104) if Kit.compact else Vector2(136, 136)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _process(delta: float) -> void:
		_t += delta
		_down = maxf(0.0, _down - delta * 4.0)
		queue_redraw()

	func press() -> void:
		_down = 1.0
		pressed.emit()

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			press()
			accept_event()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 6.0
		var glow := 0.5 + 0.5 * sin(_t * 7.0) if lit else 0.0
		if lit:
			draw_circle(c, r + 5.0 + glow * 4.0, Color(color.r, color.g, color.b, 0.25 + glow * 0.3))
		draw_circle(c, r, Color(0.08, 0.06, 0.05))
		# the guard ring, striped amber and black as on real hardware
		for k in 16:
			if k % 2 == 0:
				draw_arc(c, r - 4.0, TAU * k / 16.0, TAU * (k + 1) / 16.0, 6, Color(1.0, 0.72, 0.2, 0.95 if lit else 0.5), 7.0, true)
		var face := color.darkened(0.55 - glow * 0.35) if lit else Color(0.22, 0.2, 0.2)
		var fr := r - 12.0
		draw_circle(c + Vector2(0, _down * 3.0), fr, face)
		draw_arc(c + Vector2(0, _down * 3.0), fr, 0, TAU, 40, Color(1, 1, 1, 0.25), 2.0, true)
		draw_arc(c + Vector2(0, _down * 3.0), fr - 5.0, -PI * 0.9, -PI * 0.55, 12, Color(1, 1, 1, 0.35 if lit else 0.15), 3.0, true)   # a highlight on the dome
		# the word shrinks to fit inside the face (CORRECT, CORREGIR)
		var word := TranslationServer.translate(label)
		var fs := 18
		while fs > 9 and Kit.FONT_T.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > (r - 18.0) * 2.0:
			fs -= 1
		draw_string(Kit.FONT_T, c + Vector2(-r, fs * 0.38 + _down * 3.0), word, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color.WHITE if lit else Color(1, 1, 1, 0.55))


## A key of the steering pad that reports while it is held (hold-to-steer for touch screens and mice): a dark keycap
## with a bevel, its arrow in the console's amber; it lights while down. `held` is true while down.
class HoldButton extends Button:
	var held := false

	func _init(text_: String = "") -> void:
		text = text_
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(56, 44) if Kit.compact else Vector2(64, 50)
		add_theme_font_size_override("font_size", 18)
		button_down.connect(func(): held = true)
		button_up.connect(func(): held = false)
		for st in ["normal", "hover", "pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.13, 0.15, 0.2) if st == "normal" else (Color(0.18, 0.21, 0.28) if st == "hover" else Color(1.0, 0.66, 0.26))
			sb.set_corner_radius_all(10)
			sb.border_color = Color(0.0, 0.0, 0.0, 0.7)
			sb.border_width_bottom = 1 if st == "pressed" else 5   # the cap sinks when pressed
			sb.border_width_left = 1
			sb.border_width_right = 1
			sb.border_width_top = 1
			sb.content_margin_top = 4.0 if st == "pressed" else 0.0
			add_theme_stylebox_override(st, sb)
		add_theme_color_override("font_color", Color(1.0, 0.78, 0.42))
		add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.6))
		add_theme_color_override("font_pressed_color", Color(0.05, 0.06, 0.1))


## A toggle switch with its lamp, as on a console: the name on the left, the lever on the right. Clicking flips it.
class Switch extends Button:
	var on := false:
		set(v):
			on = v
			queue_redraw()
	var label := "AUTOPILOT"
	var _k := 0.0     ## Where the lever is drawn, easing between off (0) and on (1).

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(116, 40) if Kit.compact else Vector2(136, 46)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _process(delta: float) -> void:
		var goal := 1.0 if on else 0.0
		if absf(_k - goal) > 0.001:
			_k = lerpf(_k, goal, clampf(delta * 14.0, 0.0, 1.0))
			queue_redraw()

	func _draw() -> void:
		var lit: Color = Kit.C_OK
		draw_style_box(Kit.flat(Color(0.0, 0.01, 0.03, 0.45), Color(Kit.C_TEXT, 0.18), 10, 1, 0, 0), Rect2(Vector2.ZERO, size))
		var word := TranslationServer.translate(label) + " · P"   # its key
		var fs := 11
		while fs > 8 and Kit.FONT_B.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 66.0:
			fs -= 1
		draw_string(Kit.FONT_B, Vector2(12, size.y * 0.5 + fs * 0.36), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lit if on else Kit.C_DIM)
		var track := Rect2(Vector2(size.x - 52.0, size.y * 0.5 - 10.0), Vector2(40.0, 20.0))
		draw_style_box(Kit.flat(Color(lit, 0.35 * _k) if _k > 0.02 else Color(1, 1, 1, 0.08), Color(Kit.C_TEXT, 0.3), 10, 1, 0, 0), track)
		var kx := lerpf(track.position.x + 10.0, track.end.x - 10.0, _k)
		draw_circle(Vector2(kx, size.y * 0.5), 8.0, Color(0.9, 0.93, 0.98).lerp(lit, _k))
		draw_circle(Vector2(kx, size.y * 0.5), 3.0, Color(0, 0, 0, 0.25))


## A timing ring, for the moments that ask for one press at the right instant (light the engine, cut it, brake): a
## ring closes onto a fixed circle and the pilot presses when they meet. `remaining` runs from 1 (far) to 0 (now) and
## below (late); `window` is how near 0 still counts as on time. grade() flashes how the press went.
class TimingRing extends Control:
	var active := false
	var remaining := 1.0
	var window := 0.05
	var label := ""
	var _grade := ""
	var _grade_col := Color.WHITE
	var _grade_t := 9.0
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func grade(text: String, col: Color) -> void:
		_grade = text
		_grade_col = col
		_grade_t = 0.0

	func _process(delta: float) -> void:
		_t += delta
		_grade_t += delta
		visible = active or _grade_t < 1.6
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r0 := 62.0
		if active:
			var on: bool = absf(remaining) <= window
			var late: bool = remaining < -window
			var target: Color = Kit.C_OK if on else Kit.C_GOLD
			draw_arc(c, r0, 0.0, TAU, 64, Color(target, 0.95), 5.0 if on else 3.0, true)
			for k in 4:   # four marks, as a sight
				var a := TAU * k / 4.0
				draw_line(c + Vector2.from_angle(a) * (r0 - 9.0), c + Vector2.from_angle(a) * (r0 + 9.0), Color(target, 0.9), 2.0, true)
			var r := r0 * (1.0 + 2.4 * clampf(remaining, -0.25, 1.4))
			var col: Color = Kit.C_BAD if late else (Kit.C_OK if on else Kit.C_ACCENT)
			draw_arc(c, r, 0.0, TAU, 72, Color(col, 0.35), 9.0, true)
			draw_arc(c, r, 0.0, TAU, 72, col, 3.0, true)
			# the key and the word
			var word := TranslationServer.translate("SPACE") + "  ·  " + label
			var w := Kit.FONT_B.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_BODY).x + 28.0
			var box := Rect2(c + Vector2(-w * 0.5, r0 + 26.0), Vector2(w, 30.0))
			draw_style_box(Kit.flat(Color(0.0, 0.01, 0.04, 0.8), Color(target, 0.9 if on else 0.5 + 0.3 * sin(_t * 8.0)), 8, 2, 0, 0), box)
			draw_string(Kit.FONT_B, box.position + Vector2(0, 21), word, HORIZONTAL_ALIGNMENT_CENTER, w, Kit.T_BODY, target)
		if _grade_t < 1.6:
			var k := clampf(_grade_t / 0.18, 0.0, 1.0)
			var fade := 1.0 - smoothstep(1.0, 1.6, _grade_t)
			var fs := int(lerpf(64.0, 44.0, k))
			draw_string_outline(Kit.FONT_T, c + Vector2(-300, -r0 - 34.0), _grade, HORIZONTAL_ALIGNMENT_CENTER, 600, fs, 10, Color(0, 0, 0, 0.6 * fade))
			draw_string(Kit.FONT_T, c + Vector2(-300, -r0 - 34.0), _grade, HORIZONTAL_ALIGNMENT_CENTER, 600, fs, Color(_grade_col, fade))
