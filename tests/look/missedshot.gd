extends Node
## A craft that never reached its orbit, in the operation (issue #70): GEO without an engine stays on the transfer
## ellipse, the Moon without brakes flies past. Development harness; needs a window. Screenshots in shots/missed_*.png.
var g


func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func(): get_tree().quit())
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await _wait(1.0)
	GameState.start_solo()
	for c in [["clima", "geo"], ["luna", "lunar"], ["volcanes", "sso"]]:
		GameState.start_mission(c[0])
		GameState.mission.from_dict({"bus": "small", "instruments": ["cam_ms"], "panels": "dep_m", "battery": "b1k", "comms": "xband", "adcs": "rw", "propulsion": "none", "launcher": "medium", "orbit": c[1], "years": 3})
		GameState.begin_flight(GameState.mission.compute())
		GameState.last_sim.launch_failed = false
		g.go("operation")
		await _wait(2.0)
		print(c[1], ": insertion_ok=", GameState.last_report.insertion_ok, " missed=", g.world.orbit_missed, " note=", g.screen.orbit_note.text.left(80) if g.screen_id == "operation" else g.screen_id)
		await _shot(c[1] + "_a")
		await _wait(2.0)
		await _shot(c[1] + "_b")
	print("missedshot: done")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/missed_%s.png" % [dir, name])
