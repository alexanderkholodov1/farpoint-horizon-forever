extends Control
## The brand's horizon line (lead's identity direction B, issue #12): the Earth's limb at sunrise seen from orbit, a thin
## arc whose light runs from warm orange where the Sun rises to deep blue at its ends, as in real orbital photographs.
## Used in the logo, as a progress line (progress 0..1 lights the arc from the left) and in screen transitions.
##   var h := preload("res://scripts/ui/horizon.gd").new()
##   h.custom_minimum_size = Vector2(420, 40)
##   h.progress = 0.6

const WARM := Color(1.0, 0.58, 0.22)     ## Sunrise orange at the arc's bright point.
const PALE := Color(1.0, 0.86, 0.62)     ## Its hot core.
const DEEP := Color(0.08, 0.28, 0.66)    ## Deep blue toward the ends.

@export var bulge := 0.55               ## How much the arc rises in the middle, as a part of the control's height.
@export var thickness := 2.0
@export var glow := true
@export var sun_at := 0.5                ## Where along the arc the light is brightest (0 left, 1 right).
@export var progress := 1.0:
	set(v):
		progress = clampf(v, 0.0, 1.0)
		queue_redraw()
@export var track := false              ## Show the unlit rest of the arc faintly (as a progress track).


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _point(t: float) -> Vector2:
	var w := size.x
	var h := size.y
	# a flat circular arc through (0, h), (w/2, h - bulge*h), (w, h)
	var x := t * w
	var u := (t - 0.5) * 2.0
	return Vector2(x, h - bulge * h * (1.0 - u * u))


func _color(t: float) -> Color:
	# as a progress line the sunrise rides the line's head and the lit part stays visible to its start
	var sun := progress if track else sun_at
	var d := absf(t - sun) / maxf(maxf(sun, 1.0 - sun), 0.001)
	var c := PALE.lerp(WARM, smoothstep(0.0, 0.12, d)).lerp(DEEP, smoothstep(0.12, 0.85, d))
	c.a = (1.0 - smoothstep(0.75, 1.0, d)) if not track else lerpf(1.0, 0.55, smoothstep(0.3, 1.0, d))
	return c


func _draw() -> void:
	var n := 64
	var lit := PackedVector2Array()
	var cols := PackedColorArray()
	var rest := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		if t <= progress:
			lit.append(_point(t))
			cols.append(_color(t))
		elif track:
			rest.append(_point(t))
	if track and rest.size() > 1:
		draw_polyline(rest, Color(DEEP.r, DEEP.g, DEEP.b, 0.18), thickness, true)
	if lit.size() > 1:
		if glow:
			var soft := PackedColorArray()
			for c in cols:
				soft.append(Color(c.r, c.g, c.b, c.a * 0.22))
			draw_polyline_colors(lit, soft, thickness * 4.0, true)
		draw_polyline_colors(lit, cols, thickness, true)
