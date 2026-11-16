extends Node
## The text a demo video shows, photographed where it is hardest to read (issue #77): the credits list and its team,
## cards of the credits film, the launch's big messages over the white pad, the end celebration, the menu's corner.
## Run (needs a window): tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/legibleshot.tscn
## Development harness, not part of tools/dev/check.sh. Screenshots in shots/legible_*.png.
var g


func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func(): print("legibleshot: gave up"); get_tree().quit())
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await _wait(1.5)
	await _shot("menu")
	g.overlay("credits")
	await _wait(0.8)
	await _shot("credits_top")
	var sc: ScrollContainer = g.screen.find_children("*", "ScrollContainer", true, false)[0]
	sc.scroll_vertical = 420
	await _wait(0.4)
	await _shot("credits_team")
	g.go("credits_film")
	for at in [9.0, 18.5, 27.0, 37.0]:
		while g.screen.t < at:
			await _wait(0.1)
		await _shot("film_%02d" % int(at))
	GameState.start_solo()
	GameState.start_mission("volcanes")
	GameState.mission.from_dict({"bus": "small", "instruments": ["ir_adv", "gas_adv", "cam_ms"], "panels": "dep_m", "battery": "b1k", "comms": "xband", "adcs": "rw", "propulsion": "cold", "launcher": "medium", "orbit": "sso", "years": 3})
	g.go("missions")
	await _wait(1.0)
	await _shot("missions")
	GameState.begin_flight(GameState.mission.compute())
	GameState.last_sim.launch_failed = false
	g.go("launch")
	await _wait(3.4)
	await _shot("liftoff")
	g.screen.hud.message(tr("OUT OF FUEL · STAGE!"), tr("This stage's tank is empty and its engines went quiet. Press SPACE (or STAGE) to drop it and light the next one."), Color(1.0, 0.76, 0.32), 0.0)
	await _wait(0.6)
	await _shot("stage_msg")
	g.go("report")
	await _wait(1.6)
	await _shot("celebration")
	print("legibleshot: done")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/legible_%s.png" % [dir, name])
