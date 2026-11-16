extends Control
## Mission 2's hands-on work (issue #46): each part of a spacewalk is fitted by doing the job, not by a timed press.
##   drag    move each piece into its slot; in zero gravity a piece let go away from a slot drifts and bounces
##   screw   circle the mouse around each bolt to turn it out (or hold Space)
##   unroll  pull the solar blanket out to its end; too fast and it snags
##   slide   keep the camera between its rails while it slides into its bay; touching a rail stops it
##   aim     turn each of COSTAR's mirrors until its beam lands on the instrument
## It reports progress (0 to 1, for the 3D view) and finished(mistakes). Keyboard: Space places, turns or holds;
## arrows or A/D steer and turn. Our simplification of the real work, shown as a game, not a procedure.

signal finished(mistakes: int)

const Kit := preload("res://scripts/ui/kit.gd")

const W := 760.0
const H := 330.0

var mode := "drag"
var count := 2                ## Pieces, bolts or mirrors.
var colour := Color(0.8, 0.8, 0.8)
var label := ""
var progress := 0.0
var mistakes := 0
var done := false
var _t := 0.0
var _help := ""
# drag
var pieces: Array = []        ## {pos, vel, slot (-1 free)}
var slots: Array = []         ## Vector2 centres
var grabbed := -1
var grab_off := Vector2.ZERO
# screw
var bolts: Array = []         ## {pos, turns}
var bolt := 0
var last_angle := 0.0
var has_angle := false
# unroll
var edge := 0.0
var pulling := false
var tension := 0.0
var snag_t := 0.0
var last_mouse_x := 0.0
# slide
var depth := 0.0
var offset := 0.0
var drift := 0.0
var bump_t := 0.0
var sparks: Array = []
# aim
var angles: Array = []
var targets: Array = []
var mirror := 0
var lock_t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(m: String, n: int, col: Color, title: String) -> void:
	mode = m
	count = n
	colour = col
	label = title
	progress = 0.0
	mistakes = 0
	done = false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	match mode:
		"drag":
			pieces.clear()
			slots.clear()
			var cols := mini(n, 4)
			var rows := int(ceil(n / float(cols)))
			for i in n:
				pieces.append({"pos": Vector2(70 + (i % 2) * 70, 70 + (i / 2) * 56 + rng.randf_range(-6, 6)), "vel": Vector2.ZERO, "slot": -1})
				slots.append(Vector2(380 + (i % cols) * (300.0 / cols) + 40, 110 + (i / cols) * (150.0 / maxf(rows, 1))))
			_help = TranslationServer.translate("Drag each piece into a slot. Let go away from a slot and it floats off. (Space places one)")
		"screw":
			bolts.clear()
			for i in n:
				var a := i * TAU / n + PI / 4
				bolts.append({"pos": Vector2(W * 0.5, H * 0.5 + 10) + Vector2(cos(a), sin(a)) * 95.0, "turns": 0.0})
			bolt = 0
			has_angle = false
			_help = TranslationServer.translate("Circle the mouse around the lit bolt to turn it out. (or hold Space)")
		"unroll":
			edge = 0.0
			tension = 0.0
			snag_t = 0.0
			_help = TranslationServer.translate("Hold the edge and pull it right, steady: too fast and the blanket snags. (or hold →)")
		"slide":
			depth = 0.0
			offset = 0.0
			drift = rng.randf_range(-1, 1)
			bump_t = 0.0
			sparks.clear()
			_help = TranslationServer.translate("Keep the camera between the rails while it slides in: move the mouse left and right. (or A/D)")
		"aim":
			angles.clear()
			targets.clear()
			for i in n:
				angles.append(rng.randf_range(-0.9, 0.9))
				targets.append(rng.randf_range(-0.6, 0.6))
				while absf(targets[i] - angles[i]) < 0.35:
					angles[i] = rng.randf_range(-0.9, 0.9)
			mirror = 0
			lock_t = 0.0
			_help = TranslationServer.translate("Turn the lit mirror (drag up and down, the wheel or ↑↓) until its beam hits the instrument.")
	queue_redraw()


## Space from the screen: places the next piece (drag).
func key_space() -> void:
	if mode == "drag" and not done:
		for i in pieces.size():
			if pieces[i].slot == -1:
				var s := _free_slot()
				if s >= 0:
					_place(i, s)
				return


func _free_slot() -> int:
	for s in slots.size():
		var used := false
		for p in pieces:
			used = used or p.slot == s
		if not used:
			return s
	return -1


func _place(i: int, s: int) -> void:
	pieces[i].slot = s
	pieces[i].vel = Vector2.ZERO
	Kit.UiSound.play("snap")
	var placed := 0
	for p in pieces:
		placed += 1 if p.slot >= 0 else 0
	progress = placed / float(pieces.size())
	if placed == pieces.size():
		_finish()


func _finish() -> void:
	if done:
		return
	done = true
	progress = 1.0
	Kit.UiSound.play("success", 0.0)
	finished.emit(mistakes)


func _gui_input(e: InputEvent) -> void:
	if done:
		return
	match mode:
		"drag":
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
				if e.pressed:
					for i in range(pieces.size() - 1, -1, -1):
						if pieces[i].slot == -1 and (pieces[i].pos as Vector2).distance_to(e.position) < 26:
							grabbed = i
							grab_off = pieces[i].pos - e.position
							break
				elif grabbed >= 0:
					var best := -1
					for s in slots.size():
						var used := false
						for p in pieces:
							used = used or p.slot == s
						if not used and (slots[s] as Vector2).distance_to(pieces[grabbed].pos) < 40:
							best = s
					if best >= 0:
						_place(grabbed, best)
					else:
						# let go in zero gravity: it floats away
						pieces[grabbed].vel = Input.get_last_mouse_velocity() * 0.4
						mistakes += 1
						Kit.UiSound.play("click")
					grabbed = -1
			elif e is InputEventMouseMotion and grabbed >= 0:
				pieces[grabbed].pos = e.position + grab_off
		"screw":
			if e is InputEventMouseMotion:
				var c: Vector2 = bolts[bolt].pos
				var d: Vector2 = e.position - c
				if d.length() < 110 and d.length() > 8:
					var a := d.angle()
					if has_angle:
						var da := wrapf(a - last_angle, -PI, PI)
						if da > 0.0:
							_turn(da)
					last_angle = a
					has_angle = true
				else:
					has_angle = false
		"unroll":
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
				pulling = e.pressed and absf(e.position.x - _edge_x()) < 60
				last_mouse_x = e.position.x
			elif e is InputEventMouseMotion and pulling and snag_t <= 0.0:
				var dx: float = e.position.x - last_mouse_x
				last_mouse_x = e.position.x
				if dx > 0.0:
					_pull(dx / 560.0, dx / maxf(get_process_delta_time(), 0.001))
		"slide":
			if e is InputEventMouseMotion:
				offset = clampf(offset + e.relative.x / 140.0, -1.2, 1.2)
		"aim":
			if e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT:
				angles[mirror] = clampf(angles[mirror] - e.relative.y / 200.0, -1.2, 1.2)
			elif e is InputEventMouseButton and e.pressed:
				if e.button_index == MOUSE_BUTTON_WHEEL_UP:
					angles[mirror] = clampf(angles[mirror] + 0.03, -1.2, 1.2)
				elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					angles[mirror] = clampf(angles[mirror] - 0.03, -1.2, 1.2)


func _turn(da: float) -> void:
	bolts[bolt].turns += da / TAU
	if int(bolts[bolt].turns * 4.0) != int((bolts[bolt].turns - da / TAU) * 4.0):
		Kit.UiSound.play("click", 0.1)
	if bolts[bolt].turns >= 3.0:
		Kit.UiSound.play("snap")
		bolt += 1
		has_angle = false
		if bolt >= bolts.size():
			_finish()
	progress = (bolt + (bolts[mini(bolt, bolts.size() - 1)].turns / 3.0 if bolt < bolts.size() else 0.0)) / float(bolts.size())


func _edge_x() -> float:
	return 120.0 + edge * 560.0


## Pulls the blanket by `amount` (0..1 of its length) at `speed` pixels a second: too fast and it snags.
func _pull(amount: float, speed: float) -> void:
	tension = lerpf(tension, clampf(speed / 1400.0, 0.0, 1.0), 0.35)
	if tension > 0.85:
		snag_t = 0.9
		pulling = false
		mistakes += 1
		Kit.UiSound.play("error")
		return
	edge = minf(1.0, edge + amount)
	progress = edge
	if edge >= 1.0:
		_finish()


func _process(delta: float) -> void:
	_t += delta
	if not done:
		match mode:
			"drag":
				for i in pieces.size():
					var p: Dictionary = pieces[i]
					if p.slot == -1 and i != grabbed and p.vel.length() > 0.1:
						p.pos += p.vel * delta
						p.vel *= 0.995
						if p.pos.x < 20 or p.pos.x > W - 20:
							p.vel.x = -p.vel.x
							p.pos.x = clampf(p.pos.x, 20, W - 20)
						if p.pos.y < 20 or p.pos.y > H - 40:
							p.vel.y = -p.vel.y
							p.pos.y = clampf(p.pos.y, 20, H - 40)
			"screw":
				if Input.is_physical_key_pressed(KEY_SPACE):
					_turn(delta * TAU * 1.6)
			"unroll":
				snag_t = maxf(0.0, snag_t - delta)
				tension = maxf(0.0, tension - delta * 0.8)
				if Input.is_physical_key_pressed(KEY_RIGHT) and snag_t <= 0.0:
					_pull(delta * 0.22, 300.0)
			"slide":
				# the camera wobbles in zero gravity; the player keeps it centred
				drift += (randf_range(-1, 1) * 2.2 - drift * 0.4) * delta
				offset = clampf(offset + drift * delta * 0.55, -1.2, 1.2)
				if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
					offset -= delta * 1.4
				if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
					offset += delta * 1.4
				bump_t = maxf(0.0, bump_t - delta)
				if absf(offset) > 0.75:
					if bump_t <= 0.0:
						mistakes += 1
						Kit.UiSound.play("error")
						for k in 10:
							sparks.append({"p": Vector2(W * 0.5 + signf(offset) * 120, 150), "v": Vector2(randf_range(-80, 80), randf_range(-120, 40)), "t": 0.6})
					bump_t = 0.6
				elif bump_t <= 0.0:
					depth = minf(1.0, depth + delta * 0.17)
					progress = depth
					if depth >= 1.0:
						_finish()
				for s in sparks:
					s.p += s.v * delta
					s.t -= delta
				sparks = sparks.filter(func(s): return s.t > 0.0)
			"aim":
				if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
					angles[mirror] = clampf(angles[mirror] + delta * 0.6, -1.2, 1.2)
				if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
					angles[mirror] = clampf(angles[mirror] - delta * 0.6, -1.2, 1.2)
				if absf(angles[mirror] - targets[mirror]) < 0.05:
					lock_t += delta
					if lock_t > 0.45:
						Kit.UiSound.play("snap")
						angles[mirror] = targets[mirror]
						mirror += 1
						lock_t = 0.0
						progress = mirror / float(angles.size())
						if mirror >= angles.size():
							mirror = angles.size() - 1
							_finish()
				else:
					lock_t = 0.0
	queue_redraw()


# ===================================================================================== DRAWING
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.02, 0.03, 0.06, 0.85))
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(Kit.C_EDGE, 0.6), false, 1.0)
	draw_string(Kit.FONT_B, Vector2(16, 26), label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_CAPS + 1, Kit.C_GOLD)
	draw_string(Kit.FONT_R, Vector2(16, H - 14), _help, HORIZONTAL_ALIGNMENT_LEFT, W - 32, Kit.T_SMALL, Kit.C_DIM)
	match mode:
		"drag":
			_draw_drag()
		"screw":
			_draw_screw()
		"unroll":
			_draw_unroll()
		"slide":
			_draw_slide()
		"aim":
			_draw_aim()
	if done:
		draw_string(Kit.FONT_T, Vector2(0, H * 0.5 + 16), "✓", HORIZONTAL_ALIGNMENT_CENTER, W, 64, Kit.C_OK)


func _draw_drag() -> void:
	draw_rect(Rect2(330, 50, 400, 230), Color(0.12, 0.13, 0.16), true)
	draw_rect(Rect2(330, 50, 400, 230), Color(0.5, 0.52, 0.56), false, 2.0)
	for s in slots.size():
		var used := false
		for p in pieces:
			used = used or p.slot == s
		var c: Vector2 = slots[s]
		var pulse := 0.5 + 0.5 * sin(_t * 5.0 + s)
		draw_rect(Rect2(c - Vector2(24, 18), Vector2(48, 36)), Color(Kit.C_GOLD, 0.15 + 0.2 * pulse) if not used else Color(0, 0, 0, 0), true)
		draw_rect(Rect2(c - Vector2(24, 18), Vector2(48, 36)), Kit.C_GOLD if not used else Kit.C_OK, false, 2.0)
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		var at: Vector2 = slots[p.slot] if p.slot >= 0 else p.pos
		var r := Rect2(at - Vector2(20, 14), Vector2(40, 28))
		draw_rect(r, colour, true)
		draw_rect(r, Color(1, 1, 1, 0.6), false, 1.5)
		draw_line(at - Vector2(12, 0), at + Vector2(12, 0), Color(0, 0, 0, 0.4), 2.0)
		if i == grabbed:
			draw_rect(r.grow(4), Kit.C_ACCENT, false, 2.0)


func _draw_screw() -> void:
	var c := Vector2(W * 0.5, H * 0.5 + 10)
	draw_rect(Rect2(c - Vector2(150, 120), Vector2(300, 240)), Color(0.55, 0.56, 0.6), true)
	draw_rect(Rect2(c - Vector2(150, 120), Vector2(300, 240)), Color(0.8, 0.8, 0.85), false, 2.0)
	draw_rect(Rect2(c - Vector2(60, 40), Vector2(120, 80)), colour, true)
	for i in bolts.size():
		var b: Dictionary = bolts[i]
		var out := i < bolt
		var lit := i == bolt and not done
		var rad := 18.0
		if lit:
			draw_arc(b.pos, 40 + 6 * sin(_t * 6.0), 0, TAU, 40, Color(Kit.C_GOLD, 0.6), 3.0)
			# the turns so far, as an arc
			draw_arc(b.pos, 28, -PI / 2, -PI / 2 + TAU * fmod(b.turns, 1.0), 32, Kit.C_GOLD, 4.0)
			draw_string(Kit.FONT_B, b.pos + Vector2(-40, 58), "%d / 3" % int(b.turns), HORIZONTAL_ALIGNMENT_CENTER, 80, Kit.T_SMALL, Kit.C_GOLD)
		var col := Color(0.3, 0.3, 0.32) if out else Color(0.82, 0.82, 0.86)
		draw_circle(b.pos, rad, col)
		var ang: float = b.turns * TAU
		for k in 2:
			var a := ang + k * PI / 2
			draw_line(b.pos - Vector2(cos(a), sin(a)) * 11, b.pos + Vector2(cos(a), sin(a)) * 11, Color(0.2, 0.2, 0.22), 3.0)


func _draw_unroll() -> void:
	var y0 := 70.0
	var h := 190.0
	# the blanket: blue cells with gold lines, as far as it has been pulled
	var x0 := 120.0
	var x1 := _edge_x()
	draw_rect(Rect2(x0, y0, x1 - x0, h), Color(0.12, 0.2, 0.5), true)
	var n := int((x1 - x0) / 28.0)
	for i in n:
		draw_line(Vector2(x0 + i * 28, y0), Vector2(x0 + i * 28, y0 + h), Color(0.85, 0.65, 0.25, 0.8), 1.5)
	draw_line(Vector2(x0, y0 + h * 0.5), Vector2(x1, y0 + h * 0.5), Color(0.85, 0.65, 0.25, 0.8), 1.5)
	# the roll it comes from, turning
	draw_rect(Rect2(x0 - 40, y0 - 10, 40, h + 20), Color(0.75, 0.75, 0.78), true)
	for k in 6:
		var yy := y0 + fmod(k * 36.0 + edge * 900.0, h + 20.0) - 10
		draw_line(Vector2(x0 - 40, yy), Vector2(x0, yy), Color(0.5, 0.5, 0.55), 2.0)
	# the edge to hold
	var snag := snag_t > 0.0
	var ec := Kit.C_BAD if snag else (Kit.C_ACCENT if pulling else Kit.C_GOLD)
	draw_rect(Rect2(x1 - 6, y0 - 14, 12, h + 28), ec, true)
	if not pulling and not snag and not done:
		draw_arc(Vector2(x1, y0 + h * 0.5), 34 + 5 * sin(_t * 6.0), 0, TAU, 32, Color(Kit.C_GOLD, 0.6), 3.0)
	if snag:
		draw_string(Kit.FONT_T, Vector2(0, y0 - 20), TranslationServer.translate("Snagged! Slower."), HORIZONTAL_ALIGNMENT_CENTER, W, Kit.T_ACTION, Kit.C_BAD)
	# tension meter
	var tx := W - 40.0
	draw_rect(Rect2(tx, y0, 16, h), Color(0, 0, 0, 0.5), true)
	draw_rect(Rect2(tx, y0 + h * (1.0 - tension), 16, h * tension), Kit.C_BAD if tension > 0.6 else Kit.C_OK, true)
	draw_string(Kit.FONT_B, Vector2(tx - 50, y0 - 8), TranslationServer.translate("Tension"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_DIM)


func _draw_slide() -> void:
	var c := Vector2(W * 0.5, 160)
	# the bay seen from the front: two rails; the camera shrinks as it goes in
	var gap := 130.0
	draw_rect(Rect2(c.x - gap - 12, 50, 12, 230), Color(0.7, 0.7, 0.75), true)
	draw_rect(Rect2(c.x + gap, 50, 12, 230), Color(0.7, 0.7, 0.75), true)
	draw_rect(Rect2(c.x - gap, 50, gap * 2, 230), Color(0.06, 0.07, 0.09), true)
	var s := lerpf(1.0, 0.55, depth)
	var x := c.x + offset * gap * 0.9
	var r := Rect2(Vector2(x, c.y + 20) - Vector2(100, 70) * s, Vector2(200, 140) * s)
	var hit := absf(offset) > 0.75
	draw_rect(r, Color(0.9, 0.9, 0.95), true)
	draw_rect(r, Kit.C_BAD if hit else Color(0.4, 0.45, 0.55), false, 3.0)
	draw_circle(r.get_center() - Vector2(0, 14 * s), 14 * s, Color(0.2, 0.25, 0.35))
	# the centre mark and how far in
	draw_line(Vector2(c.x, 52), Vector2(c.x, 72), Kit.C_GOLD, 3.0)
	draw_rect(Rect2(40, 60, 16, 200), Color(0, 0, 0, 0.5), true)
	draw_rect(Rect2(40, 60 + 200 * (1.0 - depth), 16, 200 * depth), Kit.C_OK, true)
	draw_string(Kit.FONT_B, Vector2(20, 52), TranslationServer.translate("In"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_DIM)
	for sp in sparks:
		draw_circle(sp.p, 3.0, Color(1.0, 0.8, 0.3, sp.t / 0.6))


func _draw_aim() -> void:
	# light comes down from Hubble's mirror; each COSTAR mirror bounces it sideways to an instrument
	var src := Vector2(200, 50)
	for i in angles.size():
		var m := Vector2(200 + i * 200, 150 + i * 30)
		var lit := i == mirror and not done
		var locked := i < mirror or done
		draw_line(Vector2(m.x, 40), m, Color(1.0, 0.95, 0.7, 0.7), 3.0)
		var a: float = angles[i]
		var dir := Vector2(1, 0).rotated(-a)
		var hitp := m + dir * 330.0
		draw_line(m, hitp, Color(1.0, 0.9, 0.5, 0.9 if lit or locked else 0.4), 3.0 if lit else 2.0)
		var tgt := m + Vector2(1, 0).rotated(-targets[i]) * 300.0
		draw_rect(Rect2(tgt - Vector2(22, 16), Vector2(44, 32)), Kit.C_OK if locked else Color(0.6, 0.62, 0.68), true)
		draw_string(Kit.FONT_B, tgt + Vector2(-40, 32), TranslationServer.translate("Instrument"), HORIZONTAL_ALIGNMENT_CENTER, 80, Kit.T_SMALL, Kit.C_DIM)
		var mm := Vector2(0, 26).rotated(-a * 0.5)
		draw_line(m - mm, m + mm, Kit.C_GOLD if lit else (Kit.C_OK if locked else Color(0.8, 0.8, 0.85)), 6.0)
		if lit:
			draw_arc(m, 38 + 5 * sin(_t * 6.0), 0, TAU, 32, Color(Kit.C_GOLD, 0.5), 3.0)
	src = src
