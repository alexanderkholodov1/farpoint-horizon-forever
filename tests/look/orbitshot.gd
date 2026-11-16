extends Node
## The operation in orbit as a player sees it (issue #64; development only, needs a window): every orbit (LEO, SSO,
## GEO, the Moon) at each speed of time, so the ring can be judged around its body. Saves to shots/orbit_*.png.
## Run: tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/orbitshot.tscn
const CASES := [["telescopio", "l2"], ["volcanes", "sso"]]
var g


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/orbit_%s.png" % [dir, name])
	print("shot ", name)


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func(): print("orbitshot: gave up"); get_tree().quit())
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await wait(1.0)
	GameState.start_solo()
	for c in CASES:
		GameState.start_mission(c[0])
		GameState.mission.from_dict({"bus": "small", "instruments": ["cam_ms"], "panels": "dep_m", "battery": "b1k", "comms": "xband", "adcs": "rw", "propulsion": "cold", "launcher": "medium", "orbit": c[1], "years": 3})
		GameState.begin_flight(GameState.mission.compute())
		GameState.last_sim.launch_failed = false
		g.go("operation")
		await wait(2.5)
		await shot("%s_x1" % c[1])
		for i in [1, 2]:
			if g.screen_id != "operation":   # a mission that ends early has gone on to the report
				break
			g.screen._set_speed(i)
			await wait(1.2)
			await shot("%s_x%d" % [c[1], [1, 3, 10][i]])
	get_tree().quit()
