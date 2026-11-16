extends Node
## Ground control as a player sees it (issue #9; development only, needs a window): the south pole mission flown by
## the flight computer, the person holding every station, so the desk opens "Find the carrier" after the burn to the
## Moon and the 1202 in the descent. Saves to shots/ground_*.png.
## Run: tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/groundshot.tscn
var g


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/ground_%s.png" % [dir, name])
	print("shot ", name)


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _desk_panel() -> Control:
	var d = g.get_node_or_null("GroundDesk")
	return d.panel if d and d.panel and is_instance_valid(d.panel) else null


func _ready() -> void:
	get_tree().create_timer(300.0).timeout.connect(func(): print("groundshot: gave up"); get_tree().quit())
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await wait(1.0)
	GameState.start_solo()
	GameState.start_mission("moon_south_pole")
	GameState.mission.from_dict({"bus": "medium", "instruments": ["cam_ms", "gamma", "alt"], "panels": "wing_l", "battery": "b1k", "comms": "ka", "adcs": "st", "propulsion": "chem", "launcher": "medium", "orbit": "lunar", "years": 1})
	GameState.pilot_bot = true
	GameState.begin_flight(GameState.mission.compute())
	GameState.last_sim.launch_failed = false
	preload("res://scripts/minigames/desk.gd").install(g)
	g.go("flight")
	var t := 0.0
	while _desk_panel() == null and t < 240.0:
		await wait(0.5)
		t += 0.5
		var f = g.screen
		if g.screen_id == "flight" and f.phase == "plan" and not f.plan.is_empty():
			f._go_ahead()
		if int(t * 2) % 10 == 0 and g.screen_id == "flight":
			print("t=", t, " phase=", f.phase, " met=", roundi(f.m.t - f.t_launch), " warp=", f.hud.warp)
	print("carrier opened after ", t, " s on ", g.screen_id)
	if _desk_panel() == null:
		await shot("carrier_missing")
		get_tree().quit()
		return
	await wait(1.5)
	await shot("carrier_wide")
	var c = _desk_panel().get_child(0)
	c.tune(c.f_of.call() + 9000.0)
	await wait(0.8)
	c.set_band(1)
	await wait(1.6)
	await shot("carrier_mid")
	c.tune(c.f_of.call() + 150.0)
	c.set_band(2)
	await wait(0.6)
	await shot("carrier_narrow")
	await wait(1.4)
	await shot("carrier_lock")
	t = 0.0
	while g.screen_id != "landing" and t < 120.0:
		await wait(0.5)
		t += 0.5
	print("landing after ", t)
	t = 0.0
	while (_desk_panel() == null or not ("tray" in _desk_panel().get_child(0))) and t < 120.0:
		await wait(0.5)
		t += 0.5
	print("1202 opened after ", t)
	if _desk_panel() == null:
		get_tree().quit()
		return
	await wait(2.5)
	await shot("1202")
	var tri = _desk_panel().get_child(0)
	for i in 6:
		for k in tri.tray.size():
			if tri.tray[k] == "radar":
				tri.click(k)
				break
		await wait(0.6)
	await shot("1202_shed")
	tri.call_go()
	await wait(0.6)
	await shot("1202_go")
	print("ground: ", GameState.flight.get("ground", {}))
	get_tree().quit()
