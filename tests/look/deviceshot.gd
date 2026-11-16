extends Node
## Every screen at the window size the harness is run with (issue #76): phone, tablet, laptop. Saves shots/dev_<tag>_*.png.
## Run: tools/dev/godot.sh --path . --resolution 1215x562 res://tests/look/deviceshot.tscn -- phone
var g
var tag := "dev"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(150.0).timeout.connect(func(): get_tree().quit())
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		tag = a[0]
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await _wait(1.5)
	print(tag, " window ", DisplayServer.window_get_size(), " factor ", get_window().content_scale_factor, " visible ", get_viewport().get_visible_rect().size)
	await _shot("menu")
	g.go("missions")
	await _wait(0.8)
	await _shot("missions")
	GameState.start_solo()
	GameState.start_mission("volcanes")
	GameState.mission.from_dict({"bus": "small", "instruments": ["ir_adv", "gas_adv", "cam_ms"], "panels": "dep_m", "battery": "b1k", "comms": "xband", "adcs": "rw", "propulsion": "cold", "launcher": "medium", "orbit": "sso", "years": 3})
	g.go("design", {"step": 3})
	await _wait(1.0)
	await _shot("design")
	GameState.begin_flight(GameState.mission.compute())
	GameState.last_sim.launch_failed = false
	g.go("launch")
	await _wait(4.0)
	await _shot("launch")
	g.go("operation")
	await _wait(1.5)
	await _shot("operation")
	g.go("report")
	await _wait(1.0)
	g.screen._end_intro()
	await _wait(0.8)
	await _shot("report")
	g.go("flight")
	await _wait(6.0)
	await _shot("trip")
	g.go("landing")
	await _wait(3.0)
	await _shot("landing")
	g.go("builder", {"back_step": 7})
	await _wait(1.5)
	await _shot("builder")
	g.go("menu")
	await _wait(0.8)
	g.overlay("howto")
	await _wait(0.6)
	await _shot("howto")
	g.go("menu", {"settings": true})
	await _wait(0.8)
	await _shot("settings")
	g.overlay("credits")
	await _wait(0.8)
	await _shot("credits")
	g.go("design", {"step": 0})
	await _wait(0.8)
	g.overlay("pause")
	await _wait(0.5)
	await _shot("pause")
	get_tree().paused = false
	print("deviceshot: done")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await _wait(1.0)
	print("  fps %s: %d" % [name, Engine.get_frames_per_second()])
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/dev_%s_%s.png" % [dir, tag, name])
