extends Control
## On-screen buttons for the keys a screen needs, for phones and tablets (issue #91, the campaign's part): a phone has
## no keyboard, so each button presses the same key the screen already reads (its `_unhandled_input` and
## `Input.is_physical_key_pressed`), held while the finger stays on it. The screen says which keys matter at each
## moment with `touch_keys()`, returning [[label, keycode, side], ...] where side is "left" (the pad: directions)
## or "right" (actions); only those show, so a phone never carries more than it needs.
## Shown on a short screen (Kit.compact) or a touch screen; TOUCH_KEYS=1 shows it anywhere (tests).
##   const TouchKeys := preload("res://scripts/ui/touch_keys.gd")
##   TouchKeys.attach(self)    # in enter(); then define func touch_keys() -> Array

const Kit := preload("res://scripts/ui/kit.gd")

var owner_screen: Node
var left: HBoxContainer
var right: HBoxContainer
var _sig := ""
var _t := 0.0
var _held := {}


static func wanted() -> bool:
	return Kit.compact or DisplayServer.is_touchscreen_available() or OS.get_environment("TOUCH_KEYS") != ""


## Adds the bar to a screen (over everything it draws), if this device needs it. Returns it, or null.
static func attach(screen: Node) -> Control:
	if not wanted():
		return null
	var bar = load("res://scripts/ui/touch_keys.gd").new()
	bar.owner_screen = screen
	screen.add_child(bar)
	return bar


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	left = HBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	Kit.place(left, 0, 1, 0, 1, Kit.MARGIN, -84, Kit.MARGIN + 10, -Kit.MARGIN)
	left.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(left)
	right = HBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.alignment = BoxContainer.ALIGNMENT_END
	Kit.place(right, 1, 1, 1, 1, -Kit.MARGIN - 10, -84, -Kit.MARGIN, -Kit.MARGIN)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(right)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.15
	if owner_screen == null or not is_instance_valid(owner_screen) or not owner_screen.has_method("touch_keys"):
		return
	var keys: Array = owner_screen.touch_keys()
	var sig := str(keys)
	if sig == _sig:
		return
	_sig = sig
	_rebuild(keys)


func _rebuild(keys: Array) -> void:
	_release_all()
	for c in left.get_children() + right.get_children():
		c.queue_free()
	for k in keys:
		var b := Button.new()
		b.text = str(k[0])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(maxf(76.0, 14.0 * str(k[0]).length() + 28.0), 64)
		b.add_theme_font_override("font", Kit.FONT_B)
		b.add_theme_font_size_override("font_size", Kit.T_ACTION)
		var col: Color = Kit.C_GOLD if str(k[2]) == "right" else Kit.C_ACCENT
		b.add_theme_stylebox_override("normal", Kit.flat(Color(0.03, 0.05, 0.1, 0.82), Color(col, 0.8), 14, 2, 10, 6))
		b.add_theme_stylebox_override("hover", Kit.flat(Color(0.03, 0.05, 0.1, 0.82), Color(col, 0.8), 14, 2, 10, 6))
		b.add_theme_stylebox_override("pressed", Kit.flat(Color(col, 0.55), col, 14, 2, 10, 6))
		b.add_theme_color_override("font_color", Kit.C_TEXT)
		var code: int = int(k[1])
		b.button_down.connect(func(): _key(code, true))
		b.button_up.connect(func(): _key(code, false))
		(right if str(k[2]) == "right" else left).add_child(b)


## The same key event a keyboard would send: the screen cannot tell a finger from a key.
func _key(code: int, down: bool) -> void:
	if down:
		_held[code] = true
	else:
		_held.erase(code)
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _release_all() -> void:
	for code in _held.keys():
		_key(code, false)


func _exit_tree() -> void:
	_release_all()
