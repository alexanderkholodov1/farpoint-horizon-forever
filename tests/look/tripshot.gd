extends Node
## The trip to the Moon as a stranger sees it (issue #79): from Earth orbit to the Moon's orbit, a screenshot every few
## seconds and what the screen says. The pilot does nothing unless the screen asks with a key (then the harness presses
## it, as a player would). Development harness; needs a window. Screenshots in shots/trip_*.png.
var g
var n := 0


func _ready() -> void:
	get_tree().create_timer(200.0).timeout.connect(func(): print("tripshot: gave up"); get_tree().quit())
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await _wait(1.2)
	GameState.start_solo()
	GameState.start_mission("moon_south_pole")
	GameState.mission.from_dict({"bus": "medium", "instruments": ["cam_ms", "gamma", "alt"], "panels": "wing_l", "battery": "b1k", "comms": "ka", "adcs": "st", "propulsion": "chem", "launcher": "medium", "orbit": "lunar", "years": 1})
	GameState.begin_flight(GameState.mission.compute())
	g.go("flight")
	var t := 0.0
	while t < 170.0 and g.screen_id == "flight":
		await _wait(2.0)
		t += 2.0
		var f = g.screen
		n += 1
		await _shot("%02d" % n)
		print("t=%d phase=%s big='%s' sub='%s' hint='%s'" % [t, f.phase, f.hud.big.text, f.hud.sub.text.left(110), _hint(f).left(140)])
		if f.hud.action.lit:
			_key(KEY_SPACE)

	await _wait(4.0)
	await _shot("landing")
	print("tripshot: ended on ", g.screen_id)
	get_tree().quit()


func _hint(f) -> String:
	for l in f.hud.find_children("*", "Label", true, false):
		if l.is_visible_in_tree() and l.text.length() > 40 and l != f.hud.big and l != f.hud.sub:
			return l.text
	return ""


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _key(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.keycode = k
		e.pressed = down
		get_viewport().push_input(e)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/trip_%s.png" % [dir, name])
