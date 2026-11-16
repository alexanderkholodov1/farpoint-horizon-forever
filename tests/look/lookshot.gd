extends Node
## Quick look at the scenes that carry the game's look (development only; needs a window): the menu Earth, the craft,
## the Earth and the Moon in operation, the pad before and after liftoff, the builder. Saves to shots/look_*.png.
## Run: tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/lookshot.tscn
var g

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/look_%s.png" % [dir, name])
	print("shot ", name)

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _ready() -> void:
	var only: String = OS.get_environment("LOOK_ONLY")
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	var look_mode := OS.get_environment("LOOK_MODE")   # "light" or "dark": shoot that appearance without saving it
	if look_mode != "":
		var K := preload("res://scripts/ui/kit.gd")
		K.load_mode()
		K._apply(look_mode)
		g.root_ui.theme = K.build_theme()
		g.go("menu")
	await wait(1.2)
	if only == "" or "menu" in only:
		await shot("menu")
	if "tutorial" in only:
		preload("res://scripts/tutorial/coach.gd").start(g)
		for i in 8:
			g.screen.show_step(i)
			await wait(1.2)
			await shot("tutorial_%d" % i)
		GameState.mission.from_dict({"bus": "medium", "instruments": ["cam_ms", "gamma", "alt"], "panels": "wing_l", "battery": "b1k", "comms": "ka", "adcs": "st", "propulsion": "chem", "launcher": "medium", "orbit": "lunar", "years": 1})
		GameState.begin_flight(GameState.mission.compute())
		GameState.last_sim.launch_failed = false
		g.go("launch")
		await wait(5.0)
		await shot("tutorial_launch")
		g.go("menu")
		await wait(0.5)
	if "film" in only:
		g.go("credits_film")
		for at in [3.5, 9.0, 18.5, 26.5, 37.5, 45.0, 56.0, 68.5, 80.0]:
			while g.screen.t < at:
				await wait(0.1)
			await shot("film_%02d" % int(at))
		g.screen._to_end()
		await wait(2.5)
		await shot("film_end")
		g.go("menu")
		await wait(0.5)
	if "credits" in only:
		g.screen.main.overlay("credits") if false else g.overlay("credits")
		await wait(0.8)
		await shot("credits")
		var sc: ScrollContainer = g.screen.find_children("*", "ScrollContainer", true, false)[0]
		sc.scroll_vertical = 700
		await wait(0.4)
		await shot("credits_mid")
		for b in g.screen.find_children("*", "Button", true, false):
			if (b as Button).text.begins_with("▸  NASA data"):
				(b as Button).pressed.emit()
		sc.scroll_vertical = 1500
		await wait(0.4)
		await shot("credits_sources")
	GameState.start_solo()
	GameState.start_mission("volcanes")
	g.go("design", {"step": 0})
	GameState.mission.from_dict({"bus": "small", "instruments": ["ir_adv", "gas_adv", "cam_ms"], "panels": "dep_m", "battery": "b1k", "comms": "xband", "adcs": "rw", "propulsion": "cold", "launcher": "medium", "orbit": "sso", "years": 3})
	g.world.rebuild_ship()
	if only == "" or "craft" in only:
		g.go("design", {"step": 2})
		await wait(1.5)
		await shot("craft")
		g.world.cam_dist_goal = 2.2
		g.world.cam_dist = 2.2
		g.world.cam_auto = false
		g.world.cam_yaw = 0.5
		g.world.cam_pitch = -0.35
		await wait(0.4)
		await shot("craft_close")
		GameState.mission.from_dict({"bus": "medium", "instruments": ["cam_hr", "sar", "gamma"], "panels": "wing_l", "battery": "b1k", "comms": "ka", "adcs": "st", "propulsion": "chem", "launcher": "medium", "orbit": "sso", "years": 3})
		g.world.rebuild_ship()
		g.world.cam_dist_goal = 3.6
		g.world.cam_dist = 3.6
		g.world.cam_yaw = 2.4
		await wait(0.6)
		await shot("craft_medium")
		GameState.mission.from_dict({"bus": "cube6", "instruments": ["cam_basic"], "panels": "dep_s", "battery": "b1k", "comms": "uhf", "adcs": "mag", "propulsion": "ion", "launcher": "ride", "orbit": "sso", "years": 3})
		g.world.rebuild_ship()
		g.world.cam_dist_goal = 2.0
		g.world.cam_dist = 2.0
		g.world.cam_yaw = 0.9
		await wait(0.6)
		await shot("craft_cube")
		GameState.mission.from_dict({"bus": "small", "instruments": ["ir_adv", "gas_adv", "cam_ms"], "panels": "dep_m", "battery": "b1k", "comms": "xband", "adcs": "rw", "propulsion": "cold", "launcher": "medium", "orbit": "sso", "years": 3})
		g.world.rebuild_ship()
	if "assemble" in only:
		# the craft as it is assembled: a part snapping on, then the part a problem comes from glowing (#6)
		g.go("design", {"step": 4})
		await wait(1.2)
		await shot("assemble_before")
		GameState.mission.comms = "ka"
		g.world.rebuild_ship()
		await wait(0.12)
		await shot("assemble_snap")
		await wait(0.8)
		await shot("assemble_after")
		GameState.mission.comms = "uhf"
		g.world.rebuild_ship()
		await wait(1.0)
		await shot("assemble_alert")
	if only == "" or "earth" in only:
		GameState.last_sim = GameState.mission.simulate(3)
		GameState.last_report = GameState.mission.compute()
		g.go("operation")
		await wait(2.5)
		await shot("earth")
	if only == "" or "pad" in only:
		GameState.last_report = GameState.mission.compute()
		var s = GameState.mission.simulate(3)
		s.launch_failed = false
		GameState.last_sim = s
		g.go("launch")
		await wait(0.6)
		await shot("pad")
		await wait(4.0)
		await shot("liftoff")
		await wait(1.6)
		await shot("smoke_after")
		await wait(2.4)
		await shot("ascent")
	if "climb" in only:
		# the whole climb, a frame every 2.5 s, to judge the camera (the pilot's moon mission, as the walkthrough)
		GameState.start_solo("pilot")
		GameState.start_mission("luna")
		GameState.mission.from_dict({"bus": "medium", "instruments": ["cam_ms", "gamma"], "panels": "dep_m", "battery": "b1k", "comms": "ka", "adcs": "st", "propulsion": "chem", "launcher": "medium", "orbit": "lunar", "years": 1})
		GameState.last_report = GameState.mission.compute()
		GameState.last_sim = GameState.mission.simulate(5)
		g.go("launch")
		await wait(3.6)
		var i := 0
		while g.screen_id == "launch" and i < 60:
			await shot("climb_%02d" % i)
			await wait(2.5)
			i += 1
	if only == "" or "boom" in only:
		GameState.last_report = GameState.mission.compute()
		var f = GameState.mission.simulate(3)
		f.launch_failed = true
		f.months = 0
		f.status = "lost"
		GameState.last_sim = f
		g.go("launch")
		await wait(6.6)
		await shot("boom")
		await wait(0.8)
		await shot("boom_late")
	if only == "" or "moon" in only:
		GameState.start_mission("luna")
		GameState.mission.from_dict({"bus": "medium", "instruments": ["cam_ms", "gamma"], "panels": "dep_m", "battery": "b1k", "comms": "ka", "adcs": "st", "propulsion": "chem", "launcher": "medium", "orbit": "lunar", "years": 1})
		GameState.last_sim = GameState.mission.simulate(5)
		GameState.last_report = GameState.mission.compute()
		g.go("operation")
		await wait(2.5)
		await shot("moon")
	if only == "" or "builder" in only:
		GameState.start_mission("volcanes")
		g.go("builder", {"back_step": 6})
		await wait(1.5)
		await shot("builder")
	get_tree().quit()
