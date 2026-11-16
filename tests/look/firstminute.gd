extends Node
## The first minute through real input (issue #65): drag the menu's globe, then click Play once; Esc in a few screens.
## Run (needs a window): tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/firstminute.tscn
## check-free: development harness, not part of tools/dev/check.sh.
var g


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # the harness keeps running while the game is paused
	get_tree().create_timer(60.0).timeout.connect(func(): print("firstminute: gave up"); get_tree().quit())
	g = load("res://scenes/main.tscn").instantiate()
	g.process_mode = Node.PROCESS_MODE_PAUSABLE   # the game pauses as it does on its own
	add_child(g)
	await _wait(1.5)
	var play := _button("Play")
	print("menu: ", g.screen_id, " play at ", play.get_global_rect().get_center() if play else "none")
	# drag the globe from its middle to the right, releasing over empty space
	await _press(Vector2(1150, 450), true)
	for i in 12:
		await _move(Vector2(1150 + i * 15, 450 - i * 3), true)
	await _press(Vector2(1330, 414), false)
	await _wait(0.3)
	print("after drag, dragging=", g.world.dragging)
	# a second drag released right on the Play button (the interface takes the release)
	await _press(Vector2(1150, 450), true)
	for i in 10:
		await _move(Vector2(1150, 450).lerp(play.get_global_rect().get_center(), (i + 1) / 10.0), true)
	await _press(play.get_global_rect().get_center(), false)
	await _move(play.get_global_rect().get_center() + Vector2(4, 0), false)
	print("after a drag released on Play, dragging=", g.world.dragging, " screen=", g.screen_id)
	# one click on Play
	await _click(play.get_global_rect().get_center())
	await _wait(0.8)
	print("after one click on Play: ", g.screen_id)
	# Esc on the design: the pause card, time stopped; Esc again resumes
	GameState.start_solo()
	GameState.start_mission("volcanes")
	g.go("design", {"step": 0})
	await _wait(1.0)
	await _key(KEY_ESCAPE)
	await _wait(0.4)
	print("design + Esc: paused=", get_tree().paused, " card=", _button("Resume") != null)
	await _shot("pause_design")
	await _key(KEY_ESCAPE)
	await _wait(0.3)
	print("Esc again: paused=", get_tree().paused, " card=", _button("Resume") != null)
	# Esc in the launch: the mission clock must stand still while paused
	GameState.mission.from_dict({"bus": "small", "instruments": ["ir_adv", "gas_adv", "cam_ms"], "panels": "dep_m", "battery": "b1k", "comms": "xband", "adcs": "rw", "propulsion": "cold", "launcher": "medium", "orbit": "sso", "years": 3})
	GameState.begin_flight(GameState.mission.compute())
	g.go("launch")
	await _wait(6.0)
	await _key(KEY_ESCAPE)
	await _wait(0.3)
	var t0: float = g.screen.model.t
	await _wait(2.0)
	print("launch + Esc: paused=", get_tree().paused, " clock moved ", snappedf(g.screen.model.t - t0, 0.01), " s in 2 s")
	await _shot("pause_launch")
	# Back to the menu asks twice
	await _click(_button("Back to the menu").get_global_rect().get_center())
	print("one click on Back to the menu: ", g.screen_id, " / button says: ", _button("Leave") != null)
	await _click(_button("Leave").get_global_rect().get_center())
	await _wait(0.6)
	print("second click: ", g.screen_id, " paused=", get_tree().paused)
	get_tree().quit()


func _key(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.keycode = k
		e.pressed = down
		get_viewport().push_input(e)
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/first_%s.png" % [dir, name])


func _button(t: String) -> Button:
	for b in g.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and t in b.text:
			return b
	return null


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _move(p: Vector2, held: bool) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	e.relative = Vector2(15, -3)
	get_viewport().push_input(e)
	await get_tree().process_frame


func _press(p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	get_viewport().push_input(e)
	await get_tree().process_frame


func _click(p: Vector2) -> void:
	await _move(p, false)
	await _press(p, true)
	await _press(p, false)
