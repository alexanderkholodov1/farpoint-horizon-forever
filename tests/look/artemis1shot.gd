extends Node
## A look at mission 6 (issue #50; development only, needs a window): the countdown, liftoff, Max Q, the boosters and
## the core stage, the lunar flyby burn, the Earth's picture, NASA's far-point picture, re-entry, the parachutes,
## splashdown and the result. Saves to shots/art_*.png and always quits.
## Run: tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/artemis1shot.tscn
var g
var n := 0

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/art_%02d_%s.png" % [dir, n, name])
	print("shot ", n, " ", name)
	n += 1

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func key(k: int, down := true) -> void:
	var e := InputEventKey.new()
	e.pressed = down
	e.physical_keycode = k
	g.screen._unhandled_input(e)

func until(cond: Callable, limit := 30.0) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < limit * 1000.0:
		await get_tree().process_frame

func _ready() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await wait(1.0)
	g.go("artemis1", {"back": "menu"})
	await wait(1.5)
	await shot("brief")
	var s = g.screen
	s._start()
	await until(func(): return s.met >= -4.0, 20.0)
	await shot("count")
	await until(func(): return s.met >= -0.05)
	key(KEY_SPACE)
	await wait(1.2)
	await shot("liftoff")
	# the climb as in Missions: the game's own flight computer flies it; the stages drop when empty
	if s.hud:
		s.hud.set_autopilot(true)
	var took_q := false
	while is_instance_valid(s) and s.phase == "ascent":
		if s.model and s.model.wants_stage():
			s._on_stage()
		if s.model and s.model.h > 19000.0 and not s.has_meta("e17"):
			s.set_meta("e17", true)
			await shot("earth17")
		if s.cam_focus > 50.0 and not s.has_meta("upper"):
			s.set_meta("upper", true)
			await wait(1.5)
			await shot("upper_stage")
		if not took_q and s.model and s.model.h > 9000.0:
			took_q = true
			await shot("maxq")
		await get_tree().process_frame
	await until(func(): return s.phase == "beat", 20.0)
	await wait(2.0)
	await shot("cabin_beat")
	await until(func(): return s.phase == "beat", 20.0)
	await _pass_beats(s)
	await until(func(): return s.phase == "map", 20.0)
	await wait(1.5)
	await shot("map_to_moon")
	s._map_go()
	await until(func(): return s.phase == "flyby")
	await wait(3.0)
	await shot("flyby")
	# the burn: hold SPACE until near 5,102 mph
	var e := InputEventKey.new()
	e.physical_keycode = KEY_SPACE
	e.keycode = KEY_SPACE
	e.pressed = true
	Input.parse_input_event(e)
	await until(func(): return s.speed >= 3600.0, 10.0)
	await shot("burning")
	await until(func(): return s.speed >= 5095.0, 10.0)
	var e2 := InputEventKey.new()
	e2.physical_keycode = KEY_SPACE
	e2.keycode = KEY_SPACE
	e2.pressed = false
	Input.parse_input_event(e2)
	await until(func(): return s.phase == "earth", 10.0)
	await until(func(): return s.frame_box.hot, 8.0)
	await shot("earth")
	key(KEY_SPACE)
	await until(func(): return s.phase == "far", 8.0)
	await wait(1.5)
	await shot("far")
	await until(func(): return s.phase == "beat", 20.0)
	await _pass_beats(s)
	await until(func(): return s.phase == "map", 20.0)
	await wait(1.5)
	await shot("map_home")
	s._map_go()
	await until(func(): return s.phase == "entry", 12.0)
	await wait(4.0)
	# the corridor: a hand that steers the angle back to the middle
	var shot_e := false
	while s.phase == "entry":
		s.angle = lerpf(s.angle, -6.0, 0.08)
		if not shot_e and s.phase_t > 10.0:
			shot_e = true
			await shot("entry")
		await get_tree().process_frame
	await until(func(): return absf(s.alt_km - 7.6) < 0.05, 30.0)
	key(KEY_1)
	await wait(1.5)
	await shot("drogues")
	await until(func(): return absf(s.alt_km - 2.9) < 0.05, 30.0)
	key(KEY_2)
	await wait(2.5)
	await shot("mains")
	await until(func(): return s.phase == "splash", 30.0)
	await wait(1.5)
	await shot("splash")
	await until(func(): return s.phase == "beat", 20.0)
	await _pass_beats(s)
	await until(func(): return s.result_shown, 10.0)
	await wait(0.8)
	await shot("result")
	print("score ", s._score(), " launch ", s._launch_q(), " flyby ", s._flyby_q(), " entry ", s._entry_q())
	get_tree().quit()

## Reads the crew's lines between the stages: Enter on their card until it closes.
func _pass_beats(s) -> void:
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(s) and s.phase == "beat" and Time.get_ticks_msec() - t0 < 30000:
		if s.beat_dialogue and is_instance_valid(s.beat_dialogue):
			var e := InputEventKey.new()
			e.pressed = true
			e.physical_keycode = KEY_ENTER
			s.beat_dialogue._input(e)
		await get_tree().create_timer(0.9).timeout
