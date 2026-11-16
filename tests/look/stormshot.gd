extends Node
## The space weather alert in the operation (issue #90), played with real keys: a low-orbit mission and a lunar one run
## until their first alert, the card is photographed, then answered with 2 (keep working) and the log photographed.
## Saves shots/storm_<tag>_*.png. Run: tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/stormshot.tscn -- laptop
var g
var tag := "laptop"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(120.0).timeout.connect(func(): print("stormshot: timed out"); get_tree().quit())
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		tag = a[0]
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await _wait(1.5)
	await _run("sso", "volcanes", {"bus": "small", "instruments": ["ir_adv", "gas_adv", "cam_ms"], "panels": "dep_m", "battery": "b1k", "comms": "xband", "adcs": "rw", "propulsion": "none", "launcher": "medium", "orbit": "leo", "years": 3})
	await _run("moon", "luna", {"bus": "medium", "instruments": ["cam_ms"], "panels": "dep_m", "battery": "b1k", "comms": "xband", "adcs": "rw", "propulsion": "chem", "launcher": "heavy", "orbit": "lunar", "years": 2, "shielding": false})
	print("stormshot: done")
	get_tree().quit()


func _run(name: String, scenario: String, design: Dictionary) -> void:
	GameState.start_solo()
	GameState.start_mission(scenario)
	if not design.is_empty():
		GameState.mission.from_dict(design)
	GameState.begin_flight(GameState.mission.compute(), 7)
	GameState.last_sim.launch_failed = false
	GameState.last_sim.status = "ok" if GameState.last_sim.status != "lost" else "lost"
	print(name, ": orbit ", GameState.mission.orbit, ", storms at ", GameState.last_sim.storms.map(func(s): return [s.month, s.name, s.p_safe, s.p_keep]))
	g.go("operation")
	await _wait(0.5)
	g.screen._set_speed(2)
	var t := 0.0
	while not is_instance_valid(g.screen.alert) and t < 40.0:
		await _wait(0.25)
		t += 0.25
	if not is_instance_valid(g.screen.alert):
		print(name, ": FAIL no alert card")
		return
	await _shot(name + "_alert")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_2
	e.keycode = KEY_2
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(0.3)
	print(name, ": answered, card open ", is_instance_valid(g.screen.alert), ", choices ", g.screen.choices)
	await _wait(1.5)
	await _shot(name + "_after")


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await _wait(0.6)
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/storm_%s_%s.png" % [dir, tag, name])
