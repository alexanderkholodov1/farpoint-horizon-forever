extends Node3D
## Farpoint HORIZON. The flow controller: it owns the 3D world and the UI root, and switches screens.
## Flow: menu -> team -> missions (CML 1) -> design (CML 2-4, with the rocket builder) -> launch -> [flight -> landing,
## for a mission that lands] -> operation -> report.
## Each screen is a script in scripts/screens/ (see screen.gd); the shared state is the autoload GameState.

const World := preload("res://scripts/world/world.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const Screen := preload("res://scripts/screens/screen.gd")
const Found := preload("res://scripts/core/found.gd")

## Every screen and overlay by id, found in scripts/screens/ at startup (scripts/core/found.gd): a new screen is only a new
## file there, named after its id; nothing to register. An overlay is a screen opened with overlay(id).
var SCREENS := {}

var world: World
var ui: CanvasLayer
var root_ui: Control
var fade_rect: ColorRect
var screen: Screen          ## The current screen.
var screen_id := ""
var launching := false      ## A launch is fading in: a second click on the launch button does nothing.
## The screens of a mission where Esc opens the pause card (scripts/screens/pause.gd) and stops time (issue #65).
const PAUSABLE := ["design", "builder", "launch", "flight", "landing", "operation"]


func _ready() -> void:
	randomize()
	SCREENS = Found.screens()
	GameState.trace("inicio")
	world = World.new()
	add_child(world)
	world.setup()
	GameState.trace("mundo listo")
	_setup_ui()
	_fit_screen()
	get_window().size_changed.connect(_fit_screen)
	GameState.trace("interfaz lista")
	go("menu")
	GameState.trace("menu listo")


func _setup_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	root_ui = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.theme = Kit.build_theme()
	ui.add_child(root_ui)
	var top := CanvasLayer.new()
	top.layer = 10
	add_child(top)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(fade_rect)


# ===================================================================================== SCREENS OF EVERY SIZE (issue #76)
var turn_card: Control
const MIN_SCALE := 0.8
## The phone adaptation (bigger text, compact layouts, the turn card) is off by the team's decision of 2026-11-15: on a
## phone the game is drawn as on a laptop, only smaller, so nothing covers anything. The compact layouts stay in the
## code, off; true turns them on again.
const PHONE_ADAPT := false

## The interface grows on small screens so its text stays readable (a phone in landscape is about 390 CSS pixels tall:
## the 1600 x 900 layout shrunk to it makes 13 px text about 6 px), and a phone held upright is asked to turn: the
## game's panels are laid out for a wide screen. Layouts were checked at 1.25 (shots/dev_phone125_*).
func _fit_screen() -> void:
	if not PHONE_ADAPT:
		if absf(get_window().content_scale_factor - 1.0) > 0.01:
			get_window().content_scale_factor = 1.0
		if Kit.compact:
			Kit.set_compact(false)
		if turn_card:
			turn_card.visible = false
		return
	var px: Vector2 = Vector2(DisplayServer.window_get_size())
	var css_h: float = px.y / maxf(DisplayServer.screen_get_scale(), 1.0)
	if OS.has_feature("web"):
		var h = JavaScriptBridge.eval("window.innerHeight", true)
		if h != null and float(h) > 0.0:
			css_h = float(h)
	if OS.get_environment("FIT_CSS_H") != "":   # a test sets the CSS height of the screen it stands for
		css_h = float(OS.get_environment("FIT_CSS_H"))
	# text is never drawn below 80 % of its design size in CSS pixels: 1600 x 900 shrunk to a 390 px tall phone would
	# be 43 %, so short screens get a bigger interface (the screens lay themselves out for the space left, Kit.compact)
	var factor := maxf(1.0, MIN_SCALE * 900.0 / maxf(css_h, 200.0))
	# but the room stays at least 1000 units wide, or a narrow phone (667 px across) cannot hold the three columns of
	# the design side by side: there the text gives a little instead (issue #93)
	factor = maxf(1.0, minf(factor, 0.9 * (px.x / maxf(px.y, 1.0))))
	var upright: bool = px.x < px.y * 1.05
	if upright:
		factor = 3.0   # only the turn card is seen: big enough to read on a phone held upright
	if absf(get_window().content_scale_factor - factor) > 0.01:
		get_window().content_scale_factor = factor
	# the room the layout has once scaled: short (a phone in landscape) means compact
	var room: Vector2 = px / maxf(factor * minf(px.x / 1600.0, px.y / 900.0), 0.001)
	var short: bool = not upright and room.y < 640.0
	if short != Kit.compact:
		Kit.set_compact(short)
		if root_ui:
			root_ui.theme = Kit.build_theme()
		if screen_id in ["menu", "missions"]:
			go.call_deferred(screen_id)   # drawn again for the room it has now
	if upright and turn_card == null:
		turn_card = _make_turn_card()
	if turn_card:
		turn_card.visible = upright


func _make_turn_card() -> Control:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.04, 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.theme = Kit.build_theme()
	layer.add_child(shade)
	var v := Kit.vbox(16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(v)
	for t in [["⟲", 120, Kit.C_GOLD], [tr("Turn your device sideways"), Kit.T_STAT + 10, Kit.C_ON_DARK], [tr("Farpoint HORIZON is made for a wide screen."), Kit.T_LEAD + 6, Color(Kit.C_ON_DARK, 0.75)]]:
		var l := Kit.lbl(t[0], t[1], t[2], Kit.FONT_T, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	return shade


## Esc pauses a mission (a screen that uses Esc itself handles it first and this never sees it).
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_ESCAPE 			and screen_id in PAUSABLE and not get_tree().paused and not launching:
		get_viewport().set_input_as_handled()
		overlay("pause")


func _process(delta: float) -> void:
	world.update(delta)
	if screen and is_instance_valid(screen):
		screen.process(delta)


# ===================================================================================== FLOW
## Leaves the current screen and enters screen `id` (a key of SCREENS) with args.
func go(id: String, args := {}) -> void:
	if screen and is_instance_valid(screen):
		screen.exit()
		screen.queue_free()
	world.cam_free = true
	screen_id = id
	screen = _make(SCREENS[id], root_ui)
	GameState.phase = id
	screen.enter(args)


## Fades to black in out_time, goes to screen `id`, and fades back in in_time.
## The brand's horizon arc sweeps across the dark as the screen changes.
func go_faded(id: String, out_time: float, in_time: float, args := {}) -> void:
	preload("res://scripts/ui/ui_sound.gd").play("whoosh", 0.1)
	var arc := preload("res://scripts/ui/horizon.gd").new()
	arc.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	arc.offset_left = -420
	arc.offset_right = 420
	arc.offset_top = -40
	arc.offset_bottom = 40
	arc.thickness = 3.0
	arc.progress = 0.0
	arc.modulate.a = 0.0
	fade_rect.add_child(arc)
	var tw := arc.create_tween().set_parallel(true)
	tw.tween_property(arc, "modulate:a", 1.0, out_time)
	tw.tween_property(arc, "progress", 1.0, out_time + in_time * 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await fade(1.0, out_time).finished
	go(id, args)
	fade(0.0, in_time)
	var tw2 := arc.create_tween()
	tw2.tween_property(arc, "modulate:a", 0.0, in_time)
	tw2.tween_callback(arc.queue_free)


## Opens overlay `id` (a key of OVERLAYS) on top of the current screen.
func overlay(id: String, args := {}) -> void:
	var o: Screen = _make(SCREENS[id], screen)
	o.enter(args)


func _make(script: GDScript, parent: Control) -> Screen:
	var s: Screen = script.new()
	s.main = self
	s.world = world
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(s)
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return s


func fade(to: float, time: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", to, time)
	return tw


## Launches GameState's mission if it can fly: records the flight (GameState.begin_flight) and fades to the launch.
## In an online room the press only asks the room: every machine then launches with the same seed (`seed_value`), so
## everyone flies the same random events.
func launch(seed_value := -1) -> void:
	if launching:
		return
	var r: Dictionary = GameState.mission.compute()
	if seed_value < 0 and not GameState.can_launch(r):
		screen.toast(tr("Fix the red items first"), Kit.C_BAD)
		return
	if seed_value < 0 and GameState.room.is_online():
		GameState.room.request_launch(randi() % 1000000)
		return
	launching = true
	GameState.begin_flight(r, seed_value)
	preload("res://scripts/minigames/desk.gd").install(self)   # ground control during the flight (#9)
	await go_faded("launch", 0.5, 0.6)
	launching = false


var _frames_traced := 0
func _physics_process(_d: float) -> void:
	if _frames_traced < 3:
		_frames_traced += 1
		GameState.trace("frame %d dibujado" % _frames_traced)
