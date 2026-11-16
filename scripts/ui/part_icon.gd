extends Control
## A part's drawing for its tile: a few lines that say what it is at a glance, in the kit's two colours. Used by the
## rocket builder and the craft's design, so both speak the same picture language.
##   const PartIcon := preload("res://scripts/ui/part_icon.gd")
##   var i := PartIcon.new(); i.kind = "tank"; i.k = 0.75
## kinds: engine, upper, tank, booster, fairing, orbit, bus, camera, panel, battery, antenna, wheel, thruster, rocket,
## shield, spare, star, none.

const Kit := preload("res://scripts/ui/kit.gd")

var kind := "engine"
## Its size: 1 is 64 x 72 pixels.
var k := 1.0:
	set(v):
		k = v
		custom_minimum_size = Vector2(64, 72) * v
		queue_redraw()
var small := false:
	set(v):
		small = v
		k = 0.5 if v else 1.0


func _init() -> void:
	custom_minimum_size = Vector2(64, 72)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _shape(pts: Array, col: Color) -> void:
	var p := PackedVector2Array(pts)
	draw_colored_polygon(p, Color(col, 0.16))
	p.append(pts[0])
	draw_polyline(p, col, 2.0, true)


## A rocket bell from its throat at (cx, top) down h pixels: the curved contour of a real nozzle (a parabola that
## opens fast after the throat and straightens toward the exit), half-widths `throat` and `exit`.
func _bell(cx: float, top: float, h: float, throat: float, exit_r: float) -> Array:
	var right: Array = []
	for i in 9:
		var f: float = i / 8.0
		right.append(Vector2(cx + throat + (exit_r - throat) * sqrt(f), top + h * f))
	var pts: Array = right.duplicate()
	for i in range(right.size() - 1, -1, -1):
		pts.append(Vector2(2.0 * cx - right[i].x, right[i].y))
	return pts


## A tank: a cylinder of half-width r from top to bottom with round domes.
func _capsule(cx: float, top: float, bottom: float, r: float, col: Color) -> void:
	var pts: Array = []
	for i in 9:
		var a: float = PI + PI * i / 8.0
		pts.append(Vector2(cx, top + r) + Vector2.from_angle(a) * r)
	for i in 9:
		var a: float = PI * i / 8.0
		pts.append(Vector2(cx, bottom - r) + Vector2.from_angle(a) * r)
	_shape(pts, col)


func _box(x0: float, y0: float, x1: float, y1: float, col: Color) -> void:
	_shape([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)], col)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var c: Color = Kit.ink(Kit.C_ACCENT)
	var w: Color = Kit.ink(Kit.C_GOLD)
	var x := 32.0
	match kind:
		"engine":   # nine engines seen from the side: a thrust plate, three curved bells, their flames
			_box(x - 24, 8, x + 24, 16, c)
			for dx in [-16.0, 0.0, 16.0]:
				draw_line(Vector2(x + dx, 16), Vector2(x + dx, 22), c, 2.0)     # the engine's turbopump and feed
				draw_circle(Vector2(x + dx + 4, 19), 2.2, Color(c, 0.6))
				_shape(_bell(x + dx, 22, 22, 2.5, 7.5), c)
				_shape([Vector2(x + dx - 6, 46), Vector2(x + dx + 6, 46), Vector2(x + dx + 2, 58), Vector2(x + dx, 66), Vector2(x + dx - 2, 58)], w)
		"upper":    # an upper stage: a short tank on a long vacuum bell (much wider than a sea-level one)
			_capsule(x, 6, 30, 11, c)
			draw_line(Vector2(x, 30), Vector2(x, 34), c, 2.0)
			_shape(_bell(x, 34, 30, 3.0, 15.0), c)
			draw_line(Vector2(x - 26, 67), Vector2(x + 26, 67), Color(c, 0.4), 1.0)
		"tank":     # a propellant tank: a cylinder with domed ends, the inner bulkhead between fuel and oxidizer
			_capsule(x, 4, 68, 14, c)
			draw_arc(Vector2(x, 34), 14.0, 0.0, PI, 16, Color(c, 0.75), 1.5, true)
			draw_line(Vector2(x - 14, 34), Vector2(x + 14, 34), Color(c, 0.35), 1.0)
			draw_string(Kit.FONT_B, Vector2(x - 5, 26), "O", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(c, 0.8))
			draw_string(Kit.FONT_B, Vector2(x - 4, 56), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(w, 0.9))
		"booster":  # the core with a solid booster on each side, nose cones and plumes
			_box(x - 7, 10, x + 7, 60, Color(c, 0.45))
			for sd in [-1.0, 1.0]:
				var bx: float = x + sd * 19.0
				_shape([Vector2(bx, 14), Vector2(bx + 5, 22), Vector2(bx + 5, 58), Vector2(bx - 5, 58), Vector2(bx - 5, 22)], c)
				draw_line(Vector2(bx - 5, 40), Vector2(bx + 5, 40), Color(c, 0.5), 1.0)
				_shape([Vector2(bx - 5, 61), Vector2(bx + 5, 61), Vector2(bx, 71)], w)
		"fairing":  # the nose fairing: an ogive in two halves, the craft tucked inside
			var pts: Array = []
			for i in 13:
				var f: float = i / 12.0
				pts.append(Vector2(x + 16.0 * sqrt(f), 4.0 + 34.0 * f))
			pts.append(Vector2(x + 16, 66))
			pts.append(Vector2(x - 16, 66))
			for i in range(12, -1, -1):
				var f: float = i / 12.0
				pts.append(Vector2(x - 16.0 * sqrt(f), 4.0 + 34.0 * f))
			_shape(pts, c)
			draw_line(Vector2(x, 6), Vector2(x, 66), Color(c, 0.55), 1.5)
			_box(x - 7, 44, x + 7, 58, w)
		"orbit":    # a world and the path around it, the craft a warm dot
			draw_circle(Vector2(x, 36), 13.0, Color(c, 0.2))
			draw_arc(Vector2(x, 36), 13.0, 0.0, TAU, 32, c, 2.0, true)
			draw_set_transform(Vector2(x, 36) * k, -0.45, Vector2(k, k * 0.42))
			draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 48, Color(c, 0.75), 2.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
			draw_circle(Vector2(x + 24, 25), 4.0, w)
		"bus":      # the craft's body: a box seen from a corner
			_shape([Vector2(x - 20, 24), Vector2(x + 6, 24), Vector2(x + 6, 58), Vector2(x - 20, 58)], c)
			_shape([Vector2(x - 20, 24), Vector2(x - 6, 12), Vector2(x + 20, 12), Vector2(x + 6, 24)], c)
			_shape([Vector2(x + 6, 24), Vector2(x + 20, 12), Vector2(x + 20, 46), Vector2(x + 6, 58)], c)
		"camera":   # an instrument: a barrel and its lens
			_box(x - 22, 22, x + 6, 50, c)
			_shape([Vector2(x + 6, 26), Vector2(x + 22, 18), Vector2(x + 22, 54), Vector2(x + 6, 46)], c)
			draw_circle(Vector2(x - 8, 36), 7.0, Color(w, 0.25))
			draw_arc(Vector2(x - 8, 36), 7.0, 0.0, TAU, 24, w, 2.0, true)
		"panel":    # a solar wing: cells on a frame, the arm to the body
			_shape([Vector2(x - 26, 20), Vector2(x + 20, 12), Vector2(x + 26, 46), Vector2(x - 20, 54)], c)
			for i in [1, 2, 3]:
				var f: float = i / 4.0
				draw_line(Vector2(x - 26, 20).lerp(Vector2(x + 20, 12), f), Vector2(x - 20, 54).lerp(Vector2(x + 26, 46), f), Color(c, 0.6), 1.5)
			draw_line(Vector2(x - 23, 37), Vector2(x + 23, 29), Color(c, 0.6), 1.5)
			draw_circle(Vector2(x + 18, 60), 4.0, w)
		"battery":  # a cell with its charge
			_box(x - 16, 14, x + 16, 62, c)
			_box(x - 6, 8, x + 6, 14, c)
			_box(x - 10, 36, x + 10, 56, w)
		"antenna":  # a dish on its mast, waves going out
			draw_arc(Vector2(x - 4, 30), 20.0, 0.25 * PI, 1.25 * PI, 24, c, 2.5, true)
			draw_line(Vector2(x - 4, 30) + Vector2.from_angle(0.75 * PI) * 20.0, Vector2(x - 12, 64), c, 2.0)
			draw_line(Vector2(x - 4, 30), Vector2(x + 6, 20), c, 2.0)
			for r in [10.0, 18.0]:
				draw_arc(Vector2(x + 8, 18), r, -0.6 * PI, 0.1 * PI, 12, Color(w, 0.9), 2.0, true)
		"wheel":    # pointing: a wheel that spins and the star it aims at
			draw_arc(Vector2(x - 4, 40), 18.0, 0.0, TAU, 40, c, 2.0, true)
			draw_circle(Vector2(x - 4, 40), 5.0, Color(c, 0.4))
			for a in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
				draw_line(Vector2(x - 4, 40), Vector2(x - 4, 40) + Vector2.from_angle(a) * 18.0, Color(c, 0.6), 1.5)
			draw_line(Vector2(x + 20, 8), Vector2(x + 20, 20), w, 2.0)
			draw_line(Vector2(x + 14, 14), Vector2(x + 26, 14), w, 2.0)
		"thruster": # a small engine: a tank ball, a bell and its jet
			draw_arc(Vector2(x, 20), 12.0, 0.0, TAU, 32, c, 2.0, true)
			_shape([Vector2(x - 4, 32), Vector2(x + 4, 32), Vector2(x + 12, 50), Vector2(x - 12, 50)], c)
			_shape([Vector2(x - 7, 53), Vector2(x + 7, 53), Vector2(x, 68)], w)
		"rocket":   # a whole rocket on its flame
			_shape([Vector2(x, 4), Vector2(x + 9, 18), Vector2(x + 9, 52), Vector2(x - 9, 52), Vector2(x - 9, 18)], c)
			_shape([Vector2(x - 9, 40), Vector2(x - 18, 54), Vector2(x - 9, 52)], c)
			_shape([Vector2(x + 9, 40), Vector2(x + 18, 54), Vector2(x + 9, 52)], c)
			_shape([Vector2(x - 6, 55), Vector2(x + 6, 55), Vector2(x, 70)], w)
		"shield":   # protection
			_shape([Vector2(x, 8), Vector2(x + 20, 16), Vector2(x + 18, 42), Vector2(x, 64), Vector2(x - 18, 42), Vector2(x - 20, 16)], c)
			draw_polyline(PackedVector2Array([Vector2(x - 9, 34), Vector2(x - 2, 42), Vector2(x + 10, 26)]), w, 2.5, true)
		"spare":    # a backup: two of the same
			_box(x - 20, 22, x + 4, 54, c)
			_box(x - 4, 14, x + 20, 46, w)
		"star":     # a goal to go for
			var pts: Array = []
			for i in 10:
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(Vector2(x, 36) + Vector2.from_angle(a) * (24.0 if i % 2 == 0 else 10.0))
			_shape(pts, w)
		_:          # nothing here
			draw_arc(Vector2(x, 36), 20.0, 0.0, TAU, 40, Color(c, 0.6), 2.0, true)
			draw_line(Vector2(x - 14, 50), Vector2(x + 14, 22), Color(c, 0.6), 2.0)
