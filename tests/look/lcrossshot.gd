extends Node
## A look at mission 4 (issue #48; development only, needs a window): an aim outside Cabeus (lost), then one into
## its dark floor, the fast-forward, the Centaur falling ahead, its impact, the four minutes with readings taken on
## the plume, the end and the result. Saves to shots/lcross_*.png and always quits.
## Run: tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/lcrossshot.tscn
var g
var n := 0

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/lcross_%02d_%s.png" % [dir, n, name])
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

## Burns toward a goal on the map until it is reached or the budget ends.
func steer_to(s, goal: Vector2) -> void:
	for i in 80:
		var d: Vector2 = goal - s.I.point
		if d.length() < 5.0:
			return
		var k := KEY_D if absf(d.x) > absf(d.y) and d.x > 0 else (KEY_A if absf(d.x) > absf(d.y) else (KEY_S if d.y > 0 else KEY_W))
		key(k)
		await get_tree().process_frame

func _ready() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await wait(1.0)
	g.go("lcross", {"back": "menu"})
	await wait(1.5)
	await shot("brief")
	key(KEY_ENTER)
	await wait(0.8)
	await shot("aim_start")
	# let it go where it was aimed: outside Cabeus
	var s0 = g.screen
	if s0.I.verdict() == "in":
		s0.I.point += Vector2(0, 120)
	key(KEY_ENTER)
	await until(func(): return s0.phase == "lost", 60.0)
	await wait(1.6)
	await shot("missed")
	key(KEY_ENTER)
	await wait(1.5)
	# aimed right
	var s = g.screen
	key(KEY_ENTER)
	await wait(0.5)
	await steer_to(s, s.I.cabeus + Vector2(-28, 0))
	await wait(0.5)
	await shot("aim_done")
	key(KEY_ENTER)
	await wait(2.0)
	await shot("warp")
	await until(func(): return s.phase == "fall", 30.0)
	# the instruments: a player presses each number when it lights up (misses the third on purpose)
	var shot_arm := false
	while s.phase == "fall":
		if s.arm_i >= 0 and s.armed[s.arm_i] == "" and s.arm_i != 2:
			await wait(0.4)
			if not shot_arm:
				shot_arm = true
				await shot("arm")
			key(KEY_1 + s.arm_i)
		await get_tree().process_frame
	await wait(0.2)
	await shot("impact")
	# the flash: SPACE near its peak
	await until(func(): return s.phase_t >= 0.65, 5.0)
	await shot("flash")
	key(KEY_SPACE)
	await until(func(): return s.phase == "four", 10.0)
	# the four minutes (shown 4 times faster); the harness keeps the crosshair on the plume and reads in the flashes
	var t0 := Time.get_ticks_msec()
	var shots_at := [1.2, 6.0, 20.0, 40.0, 58.0]
	while s.phase == "four" and Time.get_ticks_msec() - t0 < 120000:
		# a player's hand: turn toward the nearest glint, catch it once inside the crosshair
		var ng = s._nearest_glint()
		if ng[0] != null:
			var c: Vector2 = get_viewport().get_visible_rect().size * 0.5
			var p: Vector2 = s.world.cam.unproject_position(ng[0].pos) - c
			s.aim_off += Vector2(p.x, -p.y) * s.world.cam.fov / 900.0 * 0.12
			if float(ng[1]) < 50.0:
				key(KEY_SPACE)
		else:
			s.aim_off = s.aim_off.lerp(Vector2.ZERO, 0.03)
		var el := (Time.get_ticks_msec() - t0) / 1000.0
		if not shots_at.is_empty() and el >= shots_at[0]:
			shots_at.pop_front()
			await shot("four_%d" % int(s.t))
		await get_tree().process_frame
	# the dive: steer the miss back to the crater
	var dive_shot := false
	while s.phase == "dive":
		s._mouse = -s.dive_p * 30.0
		if not dive_shot and s.phase_t > 3.0:
			dive_shot = true
			await shot("dive")
		await get_tree().process_frame
	await wait(1.0)
	await shot("end")
	await until(func(): return s.result_shown, 10.0)
	await wait(0.8)
	await shot("result")
	print("readings ", s.I.readings, " data ", s._data(), " armed ", s._armed_n(), " flash ", s.flash_q, " dive ", s._dive_q())
	get_tree().quit()
