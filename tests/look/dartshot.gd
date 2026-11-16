extends Node
## A look at mission 5 (issue #49; development only, needs a window): the brief, the dot splitting, the lock on
## Dimorphos, the steering, the last picture, the impact, the measurement and the result. Saves to shots/dart_*.png.
## Run: tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/dartshot.tscn
var g
var n := 0

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/dart_%02d_%s.png" % [dir, n, name])
	print("shot ", n, " ", name)
	n += 1

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func key(k: int) -> void:
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = k
	g.screen._unhandled_input(e)

func until(cond: Callable, limit := 20.0) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < limit * 1000.0:
		await get_tree().process_frame

func _ready() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await wait(1.0)
	g.go("dart", {"back": "menu"})
	await wait(1.5)
	await shot("brief")
	var s = g.screen
	key(KEY_ENTER)
	await wait(2.0)
	await shot("one_dot")
	await until(func(): return s.A.resolved(s.t), 40.0)
	await wait(1.5)
	await shot("two_dots")
	key(KEY_D)
	await wait(0.4)
	key(KEY_ENTER)
	await wait(1.0)
	await shot("locked")
	# a player's hand: a thruster pulse against the miss whenever it drifts (a few a second at most)
	var cool := 0.0
	var shots_at := [-3000.0, -100.0, -15.0, -5.0, -2.0]
	while s.phase == "steer":
		cool -= get_process_delta_time()
		if cool <= 0.0 and s.A.miss(s.t).length() > 20.0:
			s.A.pulse(-s.A.miss(s.t), s.t)
			cool = 0.15
		if not shots_at.is_empty() and s.t >= shots_at[0]:
			shots_at.pop_front()
			await shot("steer_%d" % int(-s.t))
		if s.t >= -2.4 and s.photo_cm < 0.0:
			key(KEY_SPACE)
		await get_tree().process_frame
	await wait(0.5)
	await shot("impact")
	await until(func(): return s.phase == "measure", 10.0)
	await wait(0.5)
	await shot("measure")
	# the rhythm: SPACE as each deep dip crosses the line
	for r in 2:
		await until(func(): return s.round_i == r and not s.round_done, 10.0)
		var shot_taken := false
		while not s.round_done:
			for dh in s.A.dips(r == 1):
				if absf(dh - s.cursor_h) < 0.08 and not s.marks.has(dh) and (s.marks.is_empty() or absf(s.marks[s.marks.size() - 1] - s.cursor_h) > 2.0):
					key(KEY_SPACE)
			if not shot_taken and s.marks.size() == 2:
				shot_taken = true
				await shot("rhythm_%d" % r)
			await get_tree().process_frame
		await wait(1.6)
	await until(func(): return s.result_shown, 10.0)
	await wait(0.8)
	await shot("result")
	print("score ", s._score(), " miss ", s.A.miss(0.0).length(), " photo ", s.photo_cm, " periods ", s.periods)
	get_tree().quit()
