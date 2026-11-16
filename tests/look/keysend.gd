extends Node
## The last screens played from the keyboard only (issue #58): the menu and how to play, the credits film and its
## sources, the report and a photo in it. Every step is a key press through the viewport, as a player's.
## Run (needs a window): tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/keysend.tscn
## Development harness, not part of tools/dev/check.sh. Screenshots in shots/keys_*.png.
var g


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(90.0).timeout.connect(func(): print("keysend: gave up"); get_tree().quit())
	g = load("res://scenes/main.tscn").instantiate()
	g.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(g)
	await _wait(1.5)
	print("menu focus: ", _focus())
	for k in [KEY_DOWN, KEY_DOWN, KEY_ENTER]:
		await _key(k)
		await _wait(0.3)
	print("menu Down, Down, Enter: how to play open=", _has("Enter goes on · Backspace goes back · Esc pauses a mission · Esc or Enter closes this"))
	await _shot("howto")
	await _key(KEY_ESCAPE)
	await _wait(0.4)
	print("how to play + Esc: open=", _has("Enter goes on · Backspace goes back · Esc pauses a mission · Esc or Enter closes this"))
	# the credits film: Enter skips to the end card, S opens every source, Page Down scrolls, Esc closes, Enter = menu
	g.go("credits_film")
	await _wait(1.5)
	await _key(KEY_ENTER)
	await _wait(1.5)
	await _shot("film_end")
	await _key(KEY_S)
	await _wait(0.8)
	print("film Enter then S: sources open=", _has("Close ×  ·  Esc"))
	await _key(KEY_PAGEDOWN)
	await _wait(0.3)
	await _shot("credits_scrolled")
	await _key(KEY_ESCAPE)
	await _wait(0.4)
	print("sources + Esc: closed=", not _has("Close ×  ·  Esc"), " screen=", g.screen_id)
	await _key(KEY_ENTER)
	await _wait(0.8)
	print("end card + Enter: screen=", g.screen_id)
	# a report, then keys: a photo large closes with Esc, Enter redesigns
	GameState.start_solo()
	GameState.start_mission("volcanes")
	GameState.mission.from_dict({"bus": "small", "instruments": ["ir_adv", "gas_adv", "cam_ms"], "panels": "dep_m", "battery": "b1k", "comms": "xband", "adcs": "rw", "propulsion": "cold", "launcher": "medium", "orbit": "sso", "years": 3})
	GameState.begin_flight(GameState.mission.compute())
	g.go("report")
	await _wait(1.0)
	await _key(KEY_SPACE)
	await _wait(0.8)
	await _shot("report")
	print("report focus: ", _focus())
	for b in g.find_children("*", "PanelContainer", true, false):
		if b.is_visible_in_tree() and b.tooltip_text != "" and b.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = true
			b.gui_input.emit(e)
			break
	await _wait(0.5)
	print("photo open: ", _has("A photo your mission sent home"))
	await _key(KEY_ESCAPE)
	await _wait(0.4)
	print("photo + Esc: closed=", not _has("A photo your mission sent home"), " screen=", g.screen_id)
	await _key(KEY_ENTER)
	await _wait(0.8)
	print("report + Enter: screen=", g.screen_id)
	get_tree().quit()


func _has(t: String) -> bool:
	for n in g.find_children("*", "", true, false):
		if (n is Label or n is Button) and n.is_visible_in_tree() and n.text == t:
			return true
	return false


func _focus() -> String:
	var f := get_viewport().gui_get_focus_owner()
	return (f as Button).text if f is Button else str(f)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


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
	get_viewport().get_texture().get_image().save_png("%s/keys_%s.png" % [dir, name])
