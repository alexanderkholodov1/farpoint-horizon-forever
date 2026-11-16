extends Node
## Scripted walkthrough: plays through the game and saves screenshots to the project's shots/ folder (development only; needs a window).
## It drives the game as the buttons do: GameState for the choices, g.go(screen id) and g.overlay(id) for the flow.
var g

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("shot ", name)

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _ready() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await wait(1.5)
	if OS.get_cmdline_user_args().has("report"):
		await _report()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("operation"):
		await _operation()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("panels"):
		await _panels()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("moon"):
		_moon_mission()
		g.go("flight")
		await _to_the_moon()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("pilot"):
		await _pilot()
		get_tree().quit()
		return
	await shot("01_menu")
	GameState.start_solo()
	g.go("missions")
	await wait(0.5)
	await shot("02_scenarios")
	GameState.start_mission("volcanes")
	g.go("design", {"step": 0})
	GameState.mission.from_dict({"bus": "small", "instruments": ["ir_adv", "gas_adv", "cam_ms"], "panels": "dep_m", "battery": "b1k", "comms": "xband", "adcs": "rw", "propulsion": "cold", "launcher": "ride", "orbit": "sso", "years": 3})
	g.world.rebuild_ship()
	g.go("design", {"step": 2})
	await wait(1.5)
	await shot("03_instruments")
	g.go("design", {"step": 7})
	await wait(0.5)
	await shot("04_review")
	g.launch()
	await wait(4.6)
	await shot("05_launch")
	await wait(4.0)
	await shot("06_launch_high")
	while g.screen_id != "operation":
		await wait(0.2)
	await wait(5.0)
	await shot("07_sim")
	g.screen.month_f = 9999.0
	while g.screen_id != "report":
		await wait(0.2)
	await wait(1.0)
	await shot("08_report")
	# Moon
	GameState.start_mission("luna")
	g.go("design", {"step": 0})
	GameState.mission.from_dict({"bus": "medium", "instruments": ["cam_ms", "gamma"], "panels": "dep_m", "battery": "b1k", "comms": "ka", "adcs": "st", "propulsion": "chem", "launcher": "medium", "orbit": "lunar", "years": 1, "redundancy": true, "shielding": true})
	g.world.stage_design()
	g.go("design", {"step": 5})
	await wait(1.5)
	await shot("09_luna_design")
	GameState.last_sim = GameState.mission.simulate(5)
	GameState.last_report = GameState.mission.compute()
	g.go("operation")
	await wait(3.0)
	await shot("10_luna_orbit")
	# Telescope at L2
	GameState.start_mission("telescopio")
	g.go("design", {"step": 0})
	GameState.mission.from_dict({"bus": "large", "instruments": ["tel_ir"], "panels": "wing_l", "battery": "b6k", "comms": "ka", "adcs": "st", "propulsion": "cold", "launcher": "heavy", "orbit": "l2", "years": 5})
	g.world.stage_design()
	g.go("design", {"step": 2})
	await wait(1.5)
	await shot("11_tel_design")
	GameState.last_sim = GameState.mission.simulate(2)
	GameState.last_report = GameState.mission.compute()
	g.go("operation")
	await wait(3.0)
	await shot("12_l2_orbit")
	# Forced launch failure
	GameState.last_report = GameState.mission.compute()
	var s = GameState.mission.simulate(2)
	s.launch_failed = true
	s.months = 0
	s.status = "lost"
	s.score = GameState.mission.score(GameState.last_report, s)
	GameState.last_sim = s
	g.go("launch")
	g.screen.fail_at = 28.0
	await wait(7.0)
	await shot("13_explosion")
	while g.screen_id != "report":
		await wait(0.2)
	await wait(1.0)
	await shot("14_fail_report")
	# Team mode
	g.go("team", {"players": 3})
	await wait(0.5)
	await shot("15_team")
	g.overlay("howto")
	await wait(0.5)
	await shot("16_howto")
	# The crew (issue #5): the lobby, the stations, a bot's choice and the crew sign-off
	g.go("team")
	await wait(0.5)
	await shot("30_lobby")
	g.go("team", {"view": "solo"})
	await wait(0.5)
	await shot("31_pick_station")
	GameState.start_solo("pilot")
	GameState.start_mission("volcanes")
	g.world.stage_design()
	g.go("design", {"step": 1})
	await wait(1.2)
	await shot("32_bot_choice")
	for i in range(2, 8):   # the bots decide their steps as the crew reaches them
		g.go("design", {"step": i})
		await wait(0.4)
	await wait(0.8)
	await shot("33_crew_signoff")
	GameState.start_solo()
	# The rocket builder (issue #6): the launcher step, the builder, a part that snaps, the player's rocket flying
	var RD := preload("res://scripts/craft/rocket_design.gd")
	RD.current = null
	GameState.start_mission("volcanes")
	GameState.mission.from_dict({"bus": "small", "instruments": ["ir_adv", "cam_ms"], "panels": "dep_m", "battery": "b1k", "comms": "xband", "adcs": "rw", "propulsion": "cold", "launcher": "ride", "orbit": "sso", "years": 3})
	g.world.stage_design()
	g.go("design", {"step": 6})
	await wait(1.0)
	await shot("17_launcher_step")
	g.go("builder", {"back_step": 6})
	await wait(1.5)
	await shot("18_builder")
	g.screen.design = RD.from_preset("light")
	g.screen.design.stack.pop_back()
	g.screen._rebuild(false)
	g.screen._add("fairing_12")
	await wait(0.15)
	await shot("19_builder_snap")
	g.screen.design = RD.from_preset("heavy")
	g.screen._rebuild(false)
	await wait(1.0)
	await shot("20_builder_heavy")
	g.screen._use()
	await wait(0.5)
	await shot("21_launcher_step_custom")
	GameState.last_report = GameState.mission.compute()
	var cs = GameState.mission.simulate(3)
	cs.launch_failed = false
	GameState.last_sim = cs
	g.go("launch")
	await wait(4.4)
	await shot("22_custom_liftoff")
	await wait(2.0)
	g.screen._on_stage()
	await wait(0.9)
	await shot("23_custom_separation")
	await _pilot()
	get_tree().quit()


## The pilot's flight to the Moon's south pole (issue #8): the launch panel, the climb, staging, orbit.
func _pilot() -> void:
	var RD := preload("res://scripts/craft/rocket_design.gd")
	RD.current = null
	_moon_mission()
	g.go("launch")
	await wait(1.2)
	await shot("24_pilot_countdown")
	await wait(4.0)
	await shot("25_pilot_liftoff")
	g.screen.hud.set_warp(10.0)     # the climb is real time; a player speeds it up
	await wait(6.0)
	await shot("26_pilot_maxq")
	while g.screen_id == "launch" and g.screen.phase == "climb" and not g.screen.model.wants_stage():
		await wait(0.2)
	await wait(0.4)
	await shot("27_pilot_stage_now")
	await wait(4.0)
	await shot("28_pilot_upper_stage")
	while g.screen_id == "launch" and g.screen.phase == "climb":
		await wait(0.2)
	await wait(2.4)
	await shot("29_pilot_orbit")
	await wait(1.4)
	await shot("30_pilot_craft_away")
	await _to_the_moon()


func _moon_mission() -> void:
	GameState.start_solo()
	GameState.start_mission("moon_south_pole")
	GameState.mission.from_dict({"bus": "medium", "instruments": ["cam_ms", "gamma"], "panels": "dep_m", "battery": "b1k", "comms": "ka", "adcs": "st", "propulsion": "chem", "launcher": "medium", "orbit": "lunar", "years": 1, "redundancy": true, "shielding": true})
	GameState.begin_flight(GameState.mission.compute())
	GameState.last_sim.launch_failed = false


## The trip to the Moon (issue #8), flown as a player who lets the flight computer act and speeds up time:
## the plan, the countdown, the burn, the correction, the coast, the arrival, the capture into lunar orbit.
func _to_the_moon() -> void:
	while g.screen_id != "flight":
		await wait(0.2)
	while g.screen.plan.is_empty():
		await wait(0.2)
	await wait(1.0)
	await shot("31_moon_plan")
	g.screen.hud.set_warp(1000.0)
	while g.screen.phase == "plan" and g.screen.burn_start - g.screen.m.t > 400.0:
		await wait(0.2)
	await wait(1.5)
	await shot("32_moon_countdown")
	while g.screen.phase == "plan":
		await wait(0.2)
	g.screen.hud.set_warp(10.0)
	await wait(12.0)
	await shot("33_moon_burn")
	while g.screen.phase == "burn":
		await wait(0.2)
	await wait(1.0)
	await shot("34_moon_cut")
	g.screen.hud.set_warp(10000.0)
	while g.screen.correction_state != "offered" and g.screen.correction_state != "done":
		await wait(0.2)
	await wait(0.5)
	await shot("35_moon_correction")
	while g.screen.correction_state != "done":
		await wait(0.2)
	g.screen.hud.set_warp(100000.0)
	await wait(2.0)
	await shot("36_moon_coast")
	while g.screen.phase == "coast" and g.screen.m.about_moon().r > 2.0e7:
		await wait(0.2)
	await shot("37_moon_approach")
	while g.screen.phase == "coast":
		await wait(0.2)
	g.screen.hud.set_warp(10.0)
	while g.screen.phase == "capture" and not g.screen.braking:
		await wait(0.2)
	await wait(3.0)
	await shot("38_moon_brake")
	while g.screen.phase == "capture":
		await wait(0.2)
	await wait(2.0)
	await shot("39_lunar_orbit")
	print("flight ", GameState.flight.get("tli", {}), " correction ", GameState.flight.get("correction", {}), " capture ", GameState.flight.get("capture", {}))
	while g.screen_id != "landing":
		await wait(0.2)
	await wait(1.5)
	await shot("40_landing_start")
	while g.screen_id == "landing" and g.screen.model.altitude() > 240.0:
		await wait(0.2)
	await wait(0.6)
	await shot("41_landing_alarm")
	while g.screen_id == "landing" and g.screen.model.altitude() > 20.0:
		await wait(0.2)
	await shot("42_landing_low")
	while g.screen_id == "landing" and g.screen.phase == "descent":
		await wait(0.2)
	await wait(1.2)
	await shot("43_touchdown")
	print("landing ", GameState.flight.get("landing", {}), " extras ", GameState.flight.get("extras", {}), " tli ", GameState.flight.get("tli", {}))
	while g.screen_id == "landing":
		await wait(0.2)
	await wait(2.0)
	await shot("44_after_landing")


## The flight panels at a glance, in the appearance LOOK_MODE names ("dark" or "light"): launch, trip, landing.
## Quick (seconds), to judge the panels' look against the rest of the game.
func _panels() -> void:
	var mode := OS.get_environment("LOOK_MODE")
	if mode != "":
		var K := preload("res://scripts/ui/kit.gd")
		K.load_mode()
		K._apply(mode)
		g.root_ui.theme = K.build_theme()
	mode = "dark" if mode == "" else mode
	_moon_mission()
	g.go("launch")
	await wait(4.5)
	await shot("50_panel_launch_" + mode)
	g.go("flight")
	while g.screen.plan.is_empty():
		await wait(0.2)
	await wait(0.8)
	await shot("51_panel_trip_" + mode)
	g.go("landing")
	await wait(2.0)
	await shot("52_panel_landing_" + mode)


## The operation after a landing at the south pole, and after reaching an orbit (issue #30). Quick.
func _operation() -> void:
	_moon_mission()
	GameState.flight["landing"] = {"landed": true, "grade": "soft", "x": 0.0, "z": 0.0, "touchdown_mps": 0.81, "target_m": 0.0}
	g.go("operation")
	await wait(2.0)
	await shot("60_operation_surface")
	await wait(9.0)
	await shot("61_operation_surface_later")
	while g.screen_id != "report":      # the landed mission ends and fades to its report first
		await wait(0.2)
	await wait(1.0)
	await shot("61b_report_after_landing")
	GameState.start_solo()
	GameState.start_mission("volcanes")
	GameState.mission.from_dict({"bus": "small", "instruments": ["ir_adv", "gas_adv"], "panels": "dep_m", "battery": "b1k", "comms": "xband", "adcs": "rw", "propulsion": "cold", "launcher": "ride", "orbit": "sso", "years": 2})
	for seed in 200:       # a mission that lives its whole time, to see the orbit play out
		GameState.begin_flight(GameState.mission.compute(), seed)
		if GameState.last_sim.status != "lost" and GameState.last_sim.months >= 24:
			break
	GameState.flight = {}
	g.go("operation")
	await wait(3.0)
	await shot("62_operation_orbit")
	g.screen._set_speed(0)
	g.screen.month_f = 0.0
	await wait(1.0)
	await shot("63_operation_orbit_slow")


## The report as a celebration (issue #11): after a soft landing that met two extra objectives, and its photo shown
## large; then after an orbital mission. Quick.
func _report() -> void:
	_moon_mission()
	GameState.mission.extras_offered = ["shadow_photo", "pole_visit", "soft_touch"]
	GameState.mission.extras = GameState.mission.extras_offered.duplicate()
	for seed in 200:
		GameState.begin_flight(GameState.mission.compute(), seed)
		if GameState.last_sim.status != "lost" and GameState.last_sim.months >= 12:
			break
	GameState.flight["landing"] = {"landed": true, "grade": "soft", "x": 0.0, "z": 0.0, "touchdown_mps": 0.81, "target_m": 0.0,
		"shadow_edge_m": 60.0, "pole_m": 424.0, "fuel_left": 0.4, "contact_kept": true}
	GameState.settle_extras()
	g.go("report")
	await wait(2.5)
	await shot("70_report_landed")
	var ph: Array = preload("res://scripts/flight/photos.gd").of("moon_south_pole")
	g.screen._show_photo(ph[2])
	await wait(1.0)
	await shot("71_report_photo")
