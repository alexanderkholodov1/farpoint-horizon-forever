extends Node
## The trip to the Moon never leaves the player stuck (issue #36): a hands-off pilot arrives (the flight computer acts
## after each countdown), a departure moved far off ends in "you missed the Moon" with the way back, and Skip from a
## miss flies it. Run: tools/dev/godot.sh --headless --path . res://tests/look/flightsafe.tscn
var g
var fails := 0

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _fresh() -> void:
	GameState.start_solo()
	GameState.start_mission("moon_south_pole")
	GameState.mission.from_dict({"bus": "medium", "instruments": ["cam_ms", "gamma"], "panels": "dep_m", "battery": "b1k", "comms": "ka", "adcs": "st", "propulsion": "chem", "launcher": "medium", "orbit": "lunar", "years": 1, "redundancy": true, "shielding": true})
	GameState.begin_flight(GameState.mission.compute())
	GameState.last_sim.launch_failed = false
	g.go("flight")

## Waits until `done` says so; false after `limit` real seconds (a dead end).
func _until(done: Callable, limit: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not done.call():
		if Time.get_ticks_msec() - t0 > limit * 1000.0:
			return false
		await wait(0.1)
	return true

func _ready() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await wait(1.0)
	# 1. hands off: nobody presses anything
	_fresh()
	var ok: bool = await _until(func(): return g.screen_id == "landing", 150.0)
	_check(ok, "hands off: the trip reaches the landing (ended in %s%s)" % [g.screen_id, "" if ok else " / " + str(g.screen.phase)])
	# 2. a departure moved far off: it must say so and give the way back
	_fresh()
	await _until(func(): return g.screen_id == "flight" and not g.screen.plan.is_empty(), 30.0)
	for i in 25:
		g.screen._shift(1.0)
	g.screen._go_ahead()
	ok = await _until(func(): return g.screen_id != "flight" or g.screen.phase in ["missed", "lunar"], 150.0)
	var ph: String = str(g.screen.phase) if g.screen_id == "flight" else g.screen_id
	_check(ok, "a departure 25 degrees late ends, not hangs (ended in %s)" % ph)
	if g.screen_id == "flight" and g.screen.phase == "missed":
		_check(g.screen.hud.warp <= 1.0 and g.screen.hud.action.lit, "missed: the RETRY button is lit")
		g.screen._skip()
		await wait(0.5)
		_check(g.screen_id == "flight" and g.screen.phase == "plan" and g.screen.hud.autopilot, "Skip from a miss: back in orbit, the flight computer flying")
		ok = await _until(func(): return g.screen_id == "landing", 150.0)
		_check(ok, "after Skip the trip reaches the landing")
	print("flightsafe: ", fails, " failure(s)")
	get_tree().quit(1 if fails > 0 else 0)
