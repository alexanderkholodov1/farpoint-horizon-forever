extends Node
## The 30-second video, recorded from the game itself (issue #38). Plays the Moon's south pole mission end to end on
## the real screens (design, the rocket builder, liftoff from the Andes, the climb, the trip, the landing, the report,
## an Earthrise to close) with English caption cards, and prints "[cut] <moment> <seconds>" when each moment starts,
## in the recording's own time. tools/content/video/make_trailer.py records it and cuts the 30 seconds from those marks.
## Run (records): tools/dev/godot.sh --path . --write-movie build/video/raw.ogv --fixed-fps 30 --resolution 1920x1080 res://tests/look/trailer.tscn
## Not a check: it has no "## check:" line, so tools/dev/check.sh leaves it alone.

const Kit := preload("res://scripts/ui/kit.gd")
const Horizon := preload("res://scripts/ui/horizon.gd")
const RD := preload("res://scripts/craft/rocket_design.gd")
const FPS := 30.0

var g
var frames := 0
var cap_layer: CanvasLayer


func now() -> float:
	return frames / FPS


func _process(_d: float) -> void:
	frames += 1


func wait(t: float) -> void:
	# counted in recorded frames, so the marks match the video whatever the machine's speed
	var until := now() + t
	while now() < until:
		await get_tree().process_frame


func cut(name: String) -> void:
	print("[cut] %s %.2f" % [name, now()])


## A caption in the lower third: a line and a smaller note (the NASA data behind it).
func caption(line: String, note := "", life := 4.0) -> void:
	var v := Kit.vbox(2)
	Kit.place(v, 0, 1, 0, 1, 64, -220, 1100, -96)
	cap_layer.add_child(v)
	var a := Horizon.new()
	a.custom_minimum_size = Vector2(420, 18)
	a.bulge = 0.0
	a.sun_at = 0.95
	a.progress = 0.0
	v.add_child(a)
	var l := Kit.legible(Kit.lbl(line, 46, Color(0.97, 0.98, 1.0), Kit.FONT_T))
	l.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0))
	v.add_child(l)
	if note != "":
		var n := Kit.legible(Kit.lbl(note, 22, Color(1.0, 0.82, 0.5), Kit.FONT_B))
		n.add_theme_color_override("font_color", Color(1.0, 0.82, 0.5))
		v.add_child(n)
	v.modulate.a = 0.0
	var tw := v.create_tween()
	tw.tween_property(v, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(a, "progress", 1.0, 0.8)
	tw.tween_interval(life)
	tw.tween_property(v, "modulate:a", 0.0, 0.4)
	tw.tween_callback(v.queue_free)


func clear_captions() -> void:
	for c in cap_layer.get_children():
		c.queue_free()


func _ready() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	cap_layer = CanvasLayer.new()
	cap_layer.layer = 20
	add_child(cap_layer)
	await wait(1.0)

	# 1. the opening: a sunrise over the real Earth, the title
	g.go("credits_film")
	cut("open")
	await wait(12.5)        # the film's own title comes in at 7 s (credits_film.gd, _title)

	# 2. the craft, assembled part by part
	RD.current = null
	GameState.start_solo()
	GameState.start_mission("moon_south_pole")
	GameState.mission.from_dict({"bus": "medium", "instruments": ["cam_ms"], "panels": "body", "battery": "b1k", "comms": "uhf", "adcs": "mag", "propulsion": "none", "launcher": "medium", "orbit": "lunar", "years": 1})
	g.go("design", {"step": 2})
	await wait(1.0)
	cut("design")
	caption("Design your own mission", "A lander for the Moon's south pole, part by part", 3.6)
	for patch in [{"instruments": ["cam_ms", "gamma"]}, {"panels": "wing_l"}, {"comms": "ka"}, {"instruments": ["cam_ms", "gamma", "alt"]}, {"adcs": "st", "propulsion": "chem"}]:
		for k in patch:
			GameState.mission.set(k, patch[k])
		g.world.rebuild_ship()
		await wait(0.9)
	await wait(0.6)

	# 3. the rocket, stacked from real engines and tanks
	clear_captions()
	g.go("builder", {"back_step": 6})
	await wait(0.4)
	g.screen.design = RD.from_preset("medium")
	g.screen.design.stack = ["engine_merlin_x9", "tank_37_long"]
	g.screen._rebuild(false)
	await wait(0.6)
	cut("builder")
	caption("Stack a real rocket", "Engines and tanks with the real Falcon 9 and Electron numbers", 3.4)
	for p in ["interstage_37", "engine_merlin_vac", "tank_37_short", "fairing_52"]:
		g.screen._add(p)
		await wait(0.75)
	await wait(1.0)

	# 4. liftoff from the Andes
	clear_captions()
	GameState.mission.from_dict({"bus": "medium", "instruments": ["cam_ms", "gamma", "alt"], "panels": "wing_l", "battery": "b1k", "comms": "ka", "adcs": "st", "propulsion": "chem", "launcher": "medium", "orbit": "lunar", "years": 1})
	GameState.begin_flight(GameState.mission.compute())
	GameState.last_sim.launch_failed = false
	g.go("launch")
	await wait(2.2)
	cut("liftoff")
	await wait(1.0)
	caption("Launch from the Andes", "Cotopaxi from NASA SRTM elevation · Earth from NASA Blue Marble", 4.5)
	await wait(8.0)
	g.screen.hud.set_autopilot(true)
	g.screen.hud.set_warp(10.0)
	while g.screen_id == "launch" and g.screen.model.h < 90000.0:
		await wait(0.2)
	cut("space")
	caption("Real physics, real time", "Speed time up when you want, never in secret", 3.0)
	await wait(3.6)
	g.screen._skip()        # the game's own Skip: the rest of the climb is computed, not recorded
	while g.screen_id == "launch":
		await wait(0.2)

	# 5. the trip to the Moon
	clear_captions()
	while g.screen_id != "flight":
		await wait(0.2)
	while g.screen.plan.is_empty():
		await wait(0.2)
	await wait(1.0)
	g.screen.hud.set_warp(1000.0)
	while g.screen.phase == "plan" and g.screen.burn_start - g.screen.m.t > 400.0:
		await wait(0.2)
	while g.screen.phase == "plan":
		await wait(0.2)
	g.screen.hud.set_warp(10.0)
	await wait(2.0)
	cut("burn")
	caption("Fly to the Moon", "The burn, the coast and the capture, as Apollo 11 flew them", 3.5)
	while g.screen.phase == "burn":
		await wait(0.2)
	g.screen.hud.set_warp(10000.0)
	while g.screen.correction_state != "done":
		await wait(0.2)
	g.screen.hud.set_warp(100000.0)
	while g.screen.phase == "coast":
		await wait(0.2)
	g.screen.hud.set_warp(10.0)
	while g.screen_id == "flight":
		await wait(0.2)

	# 6. the landing at Shackleton's rim
	clear_captions()
	while g.screen_id != "landing":
		await wait(0.2)
	await wait(1.0)
	while g.screen_id == "landing" and g.screen.model.altitude() > 160.0:
		await wait(0.2)
	cut("landing")
	caption("Land at the south pole", "Shackleton's rim from NASA LOLA elevation data", 4.0)
	while g.screen_id == "landing" and g.screen.phase == "descent":
		await wait(0.2)
	cut("touchdown")
	await wait(3.0)

	# 7. what it sent home
	clear_captions()
	while g.screen_id != "report" and g.screen_id != "operation":
		await wait(0.2)
	if g.screen_id == "operation":
		g.screen.month_f = 9999.0
	while g.screen_id != "report":
		await wait(0.2)
	await wait(1.2)
	cut("report")
	caption("Bring home real NASA photos", "What a mission like yours would really see", 3.0)
	await wait(4.0)

	# 8. the end: an Earthrise and the title
	clear_captions()
	g.go("credits_film")
	g.screen.t = 64.0
	g.screen.next_cue = g.screen.cues.size()
	for c in g.screen.layer.get_children():
		c.queue_free()
	await wait(0.5)
	cut("end")
	g.screen._title()       # the game's own logo, as the film shows it
	await wait(7.0)
	cut("done")
	get_tree().quit()
