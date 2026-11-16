extends Node
## The launch's end as a player sees it: in orbit, engine off, the fairing splitting in two, the craft riding on top
## of the last stage, the springs pushing it off and its wings unfolding. Development harness (needs a window).
## Run: tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/separationshot.tscn
## Screenshots in shots/sep_*.png.
var g


func _ready() -> void:
	get_tree().create_timer(220.0).timeout.connect(func(): get_tree().quit())
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await get_tree().create_timer(1.0).timeout
	GameState.start_solo()
	GameState.start_mission("volcanes")
	GameState.mission.from_dict({"bus": "small", "instruments": ["ir_adv", "gas_adv", "cam_ms"], "panels": "dep_m", "battery": "b1k", "comms": "xband", "adcs": "rw", "propulsion": "cold", "launcher": "medium", "orbit": "sso", "years": 3})
	GameState.begin_flight(GameState.mission.compute())
	GameState.last_sim.launch_failed = false
	g.go("launch")
	var shots := {"fairing": false, "ride": false, "c60": false, "c120": false, "orbit": false}
	var away_t := -1.0
	var n := 0
	while g.screen_id == "launch" and n < 400:
		await get_tree().create_timer(0.25).timeout
		n += 1
		var s = g.screen
		if s.hud.action.lit:
			s.hud.action_pressed.emit()
		if s.model.h > 60000.0 and not shots.c60:
			shots.c60 = true
			await _shot("0a_climb60")
		if s.model.h > 120000.0 and not shots.c120:
			shots.c120 = true
			await _shot("0b_climb120")
		if s.phase == "orbit" and not shots.orbit:
			shots.orbit = true
			await _shot("0c_orbit_t0")
			await get_tree().create_timer(0.5).timeout
			await _shot("0d_orbit_t05")
		if s.fairing_off and not shots.fairing:
			shots.fairing = true
			await get_tree().create_timer(0.5).timeout
			await _shot("1_fairing")
			await get_tree().create_timer(1.0).timeout
			await _shot("2_ride")
		if s.released and away_t < 0.0:
			away_t = 0.0
			await _shot("3_away")
		elif away_t >= 0.0:
			away_t += 0.25
			if is_equal_approx(away_t, 2.5):
				await _shot("4_unfolding")
			elif is_equal_approx(away_t, 4.5):
				await _shot("5_open")
				break
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/sep_%s.png" % [dir, name])
	print("separationshot: ", name)
