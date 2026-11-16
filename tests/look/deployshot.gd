extends Node
## The Earth below at the moment the craft separates (CRAFT AWAY), to judge its texture. Development harness.
var g


func _ready() -> void:
	get_tree().create_timer(160.0).timeout.connect(func(): get_tree().quit())
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await get_tree().create_timer(1.0).timeout
	GameState.start_solo()
	GameState.start_mission("volcanes")
	GameState.mission.from_dict({"bus": "small", "instruments": ["ir_adv", "gas_adv", "cam_ms"], "panels": "dep_m", "battery": "b1k", "comms": "xband", "adcs": "rw", "propulsion": "cold", "launcher": "medium", "orbit": "sso", "years": 3})
	GameState.begin_flight(GameState.mission.compute())
	GameState.last_sim.launch_failed = false
	g.go("launch")
	var n := 0
	while g.screen_id == "launch" and n < 200:
		await get_tree().create_timer(0.5).timeout
		n += 1
		if g.screen.hud.action.lit:
			g.screen.hud.action_pressed.emit()
		if g.screen.hud.big.text == "CRAFT AWAY":
			await get_tree().create_timer(1.5).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/deploy.png"))
			print("deployshot: shot at h=%.0f km, %.0f km downrange (%.1f deg east)" % [g.screen.model.h / 1000.0, g.screen.model.x / 1000.0, rad_to_deg(g.screen.model.x / g.screen.model.R)])
			break
	get_tree().quit()
