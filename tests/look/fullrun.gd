extends Node
## The whole story played through as a player would (development only, needs a window): The crew screen, then the
## prologue and every chapter with its mission played right, from the menu's crew screen back to it. A screenshot at
## every new screen, every title card, the first line of every scene, key moments of each mission and every few
## seconds; a timeout so it always ends. Saves to shots/full_*.png.
## Run: tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/fullrun.tscn
var g
var n := 0
var t0 := 0
var last_shot := 0.0
var last_tag := ""

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/full_%03d_%s.png" % [dir, n, name])
	print("shot ", n, " ", name, "  t=", int(secs()), " fps=", Engine.get_frames_per_second())
	n += 1
	last_shot = secs()

func secs() -> float:
	return (Time.get_ticks_msec() - t0) / 1000.0

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func key(k: int, target = null) -> void:
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = k
	if target == null:
		target = g.screen
	if target.has_method("_unhandled_input"):
		target._unhandled_input(e)

func enter_dialogue(d) -> void:
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = KEY_ENTER
	d._input(e)

func _ready() -> void:
	t0 = Time.get_ticks_msec()
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await wait(1.0)
	g.go("crew_gallery")
	await wait(2.0)
	await shot("crew")
	g.screen._focus(1)
	await wait(1.5)
	await shot("crew_killa")
	# FULLRUN_SCENES="pathfinder/intro,pathfinder/mission,pathfinder/outro" plays only those scenes
	var only := OS.get_environment("FULLRUN_SCENES")
	var scenes: Array = Array(only.split(",")) if only != "" else load("res://scripts/screens/story.gd").story()
	g.go("story", {"scenes": scenes, "back": "crew_gallery"})
	var last_screen := ""
	var started := false
	while secs() < 1500.0:
		var id: String = g.screen_id
		if id != last_screen:
			last_screen = id
			await wait(1.2)
			await shot("screen_" + id)
		if id == "crew_gallery" and started:
			break
		started = true
		match id:
			"story":
				await _story_step()
			"apollo13":
				await _apollo13()
			"sts61":
				await _sts61()
			"pathfinder":
				await _pathfinder()
			"lcross":
				await _lcross()
			"dart":
				await _dart()
			"artemis1":
				await _artemis1()
			"reentry":
				await _reentry()
			_:
				await wait(0.5)
	await shot("end")
	print("fullrun done in ", int(secs()), " s, ", n, " shots")
	get_tree().quit()

func _story_step() -> void:
	var s = g.screen
	var d = s.dialogue
	if d == null or not is_instance_valid(d) or d.at < 0:
		await wait(0.2)
		return
	var at: int = d.at
	var L: Dictionary = d.lines[at]
	var tag := ("%s_%d" % [s.scenes[s.scene_at], at]).replace("/", "-")
	if L.has("title") and not L.has("who"):
		await wait(1.4)
		await shot(tag + "_title")
		if L.has("play"):
			enter_dialogue(d)
			await wait(1.0)
			return
		enter_dialogue(d)
	elif not L.has("who"):
		await wait(minf(float(L.get("wait", 2.0)) * 0.5, 3.0))
		await shot(tag + "_beat")
		while is_instance_valid(d) and d.at == at:
			await wait(0.1)
	else:
		await wait(1.1)
		if at == 0 or (L.has("set") and str(L.set) != last_tag) or secs() - last_shot > 6.0:
			await shot(tag + "_" + str(L.who))
		last_tag = str(L.get("set", last_tag))
		if is_instance_valid(d) and d.at == at:
			enter_dialogue(d)
			await wait(0.5)
		if is_instance_valid(d) and d.at == at:
			enter_dialogue(d)
	await wait(0.15)

func _apollo13() -> void:
	var s = g.screen
	await wait(1.0)
	await shot("a13_start")
	var steps := 0
	while is_instance_valid(s) and not s.A.done and not s.A.lost and steps < 20:
		steps += 1
		var id: String = s.A.needed()
		key(KEY_1 + s.part_keys.find(id))
		await wait(0.6)
		while is_instance_valid(s) and s.taping:
			if absf(1.0 - s.ring_t / (s.RING_PERIOD * 0.8)) < 0.05:
				key(KEY_SPACE)
				await wait(0.2)
			await get_tree().process_frame
	await wait(1.0)
	await shot("a13_win")
	await wait(3.0)
	await shot("a13_photo")
	key(KEY_ENTER)
	await wait(1.0)

func _sts61() -> void:
	var s = g.screen
	await wait(1.0)
	await shot("s61_start")
	var guard := 0
	while is_instance_valid(s) and not s.W.done() and guard < 200:
		guard += 1
		if s.phase == "walks" and s.W.picked == "":
			key(KEY_1 + s.keys.find(s.W.needed()))
			await wait(0.7)
			var w = s.work
			if w.mode in ["unroll", "slide", "aim", "screw"] and secs() - last_shot > 4.0:
				await shot("s61_job_" + w.mode)
			if w.mode == "drag":
				while not w.done:
					w.key_space()
					await wait(0.08)
			else:
				w._finish()
			await wait(0.8)
		else:
			await wait(0.3)
	await wait(3.0)
	await shot("s61_focus")
	s.dial = s.target
	await wait(1.5)
	await shot("s61_sharp")
	var t := secs()
	while is_instance_valid(s) and not s.photo_shown and secs() - t < 10.0:
		await get_tree().process_frame
	await shot("s61_photo")
	key(KEY_ENTER)
	await wait(1.0)

func _pathfinder() -> void:
	var s = g.screen
	await wait(1.5)
	await shot("mpf_brief")
	key(KEY_ENTER)
	await wait(0.5)
	await shot("mpf_descent")
	var t := secs()
	while is_instance_valid(s) and s.L.alt > 98.0 and secs() - t < 60.0:
		await get_tree().process_frame
	key(KEY_SPACE)
	await wait(0.3)
	await shot("mpf_rockets")
	while is_instance_valid(s) and s.L.alt > 21.5 and secs() - t < 70.0:
		await get_tree().process_frame
	key(KEY_C)
	t = secs()
	while is_instance_valid(s) and s.phase == "descent" and secs() - t < 20.0:
		await get_tree().process_frame
	await wait(2.5)
	await shot("mpf_bounce")
	t = secs()
	while is_instance_valid(s) and s.phase in ["bounce", "deflate"] and secs() - t < 60.0:
		await get_tree().process_frame
	await shot("mpf_ramp")
	while is_instance_valid(s) and s.phase == "ramp":
		s.ramp_s = minf(1.0, s.ramp_s + 0.008)
		s.ramp_off = 0.0
		await get_tree().process_frame
	await wait(0.6)
	await shot("mpf_wheel")
	t = secs()
	while is_instance_valid(s) and not s.photo_shown and secs() - t < 10.0:
		await get_tree().process_frame
	await shot("mpf_photo")
	key(KEY_ENTER)
	await wait(1.0)


func _until(cond: Callable, limit := 30.0) -> void:
	var t := secs()
	while not cond.call() and secs() - t < limit:
		await get_tree().process_frame


func _lcross() -> void:
	var s = g.screen
	await wait(1.5)
	await shot("lc_brief")
	key(KEY_ENTER)
	await wait(0.5)
	# aim at the dark floor, let it go
	var goal: Vector2 = s.I.cabeus + Vector2(-28, 0)
	for i in 80:
		var d: Vector2 = goal - s.I.point
		if d.length() < 5.0:
			break
		key(KEY_D if absf(d.x) > absf(d.y) and d.x > 0 else (KEY_A if absf(d.x) > absf(d.y) else (KEY_S if d.y > 0 else KEY_W)))
		await get_tree().process_frame
	await shot("lc_aim")
	key(KEY_ENTER)
	await _until(func(): return s.phase == "fall", 30.0)
	while is_instance_valid(s) and s.phase == "fall":
		if s.arm_i >= 0 and s.armed[s.arm_i] == "":
			await wait(0.3)
			key(KEY_1 + s.arm_i)
		await get_tree().process_frame
	await _until(func(): return s.phase_t >= 0.65, 5.0)
	key(KEY_SPACE)
	await shot("lc_flash")
	var took := false
	if is_instance_valid(s) and s.phase == "four":
		await wait(4.0)
		await shot("lc_plume")
	while is_instance_valid(s) and s.phase == "four":
		took = true
		var ng = s._nearest_glint()
		if ng[0] != null and ng[0].ice:
			var c: Vector2 = get_viewport().get_visible_rect().size * 0.5
			var p: Vector2 = s.world.cam.unproject_position(ng[0].pos) - c
			# a quick hand: turn most of the way to the glint each frame, press once it is well inside
			s.aim_off += Vector2(p.x, -p.y) * s.world.cam.fov / get_viewport().get_visible_rect().size.y * 0.6
			if float(ng[1]) < float(s.I.P.hit_px) * 0.6:
				key(KEY_SPACE)
				if not took:
					took = true
					await shot("lc_ice")
		await get_tree().process_frame
	# the ice is skipped here (the automatic hand is too slow for it; a person plays it): its readings are given
	s.I.readings = maxi(s.I.readings, int(s.I.D.stages.ice_full))
	while is_instance_valid(s) and s.phase == "dive":
		s._mouse = -s.dive_p * 30.0
		await get_tree().process_frame
	await _until(func(): return s.result_shown, 15.0)
	await wait(0.6)
	await shot("lc_result")
	key(KEY_ENTER)
	await wait(1.0)


func _dart() -> void:
	var s = g.screen
	await wait(1.5)
	await shot("dart_brief")
	key(KEY_ENTER)
	await _until(func(): return s.A.resolved(s.t), 60.0)
	await wait(1.0)
	await shot("dart_two_dots")
	key(KEY_D)
	await wait(0.3)
	key(KEY_ENTER)
	var cool := 0.0
	var took := false
	while is_instance_valid(s) and s.phase == "steer":
		cool -= get_process_delta_time()
		if cool <= 0.0 and s.A.miss(s.t).length() > 20.0:
			s.A.pulse(-s.A.miss(s.t), s.t)
			cool = 0.15
		if not took and s.t >= -4.0:
			took = true
			await shot("dart_close")
		if s.t >= -2.4 and s.photo_cm < 0.0:
			key(KEY_SPACE)
		await get_tree().process_frame
	await _until(func(): return s.phase == "measure", 15.0)
	for r in 2:
		await _until(func(): return s.round_i == r and not s.round_done, 10.0)
		while is_instance_valid(s) and not s.round_done:
			for dh in s.A.dips(r == 1):
				if absf(dh - s.cursor_h) < 0.08 and (s.marks.is_empty() or absf(s.marks[s.marks.size() - 1] - s.cursor_h) > 2.0):
					key(KEY_SPACE)
			await get_tree().process_frame
		if r == 1:
			await wait(0.6)
			await shot("dart_32_minutes")
		await wait(1.6)
	await _until(func(): return s.result_shown, 15.0)
	await wait(0.6)
	await shot("dart_result")
	key(KEY_ENTER)
	await wait(1.0)


func _artemis1() -> void:
	var s = g.screen
	await wait(1.5)
	await shot("art_brief")
	s._start()
	await _until(func(): return s.met >= -0.05, 10.0)
	key(KEY_SPACE)
	await wait(1.0)
	await shot("art_liftoff")
	# the climb as in Missions: the game's own flight computer flies it; the stages drop when empty
	if s.hud:
		s.hud.set_autopilot(true)
	var took_q := false
	while is_instance_valid(s) and s.phase == "ascent":
		if s.model and s.model.wants_stage():
			s._on_stage()
		if not took_q and s.model and s.model.h > 9000.0:
			took_q = true
			await shot("art_maxq")
		await get_tree().process_frame
	await _until(func(): return s.phase == "beat", 20.0)
	await _pass_beats(s)
	await _until(func(): return s.phase == "map", 20.0)
	await wait(1.5)
	await shot("map_to_moon")
	s._map_go()
	await _until(func(): return s.phase == "flyby", 10.0)
	await wait(3.0)
	var e := InputEventKey.new()
	e.physical_keycode = KEY_SPACE
	e.keycode = KEY_SPACE
	e.pressed = true
	Input.parse_input_event(e)
	await _until(func(): return s.speed >= 5095.0, 10.0)
	var e2 := e.duplicate()
	e2.pressed = false
	Input.parse_input_event(e2)
	await shot("art_flyby")
	await _until(func(): return s.phase == "earth" and s.frame_box.hot, 12.0)
	key(KEY_SPACE)
	await _until(func(): return s.phase == "far", 8.0)
	await wait(1.5)
	await shot("art_far")
	await _until(func(): return s.phase == "beat", 20.0)
	await _pass_beats(s)
	await _until(func(): return s.phase == "map", 20.0)
	await wait(1.5)
	await shot("map_home")
	s._map_go()
	await _until(func(): return s.phase == "entry", 12.0)
	var took := false
	while is_instance_valid(s) and s.phase == "entry":
		s.angle = lerpf(s.angle, -6.0, 0.08)
		if not took and s.phase_t > 8.0:
			took = true
			await shot("art_entry")
		await get_tree().process_frame
	await _until(func(): return absf(s.alt_km - 7.6) < 0.05, 30.0)
	key(KEY_1)
	await _until(func(): return absf(s.alt_km - 2.9) < 0.05, 30.0)
	key(KEY_2)
	await wait(2.0)
	await shot("art_chutes")
	await _until(func(): return s.phase == "beat", 20.0)
	await _pass_beats(s)
	await _until(func(): return s.result_shown, 40.0)
	await wait(0.6)
	await shot("art_result")
	key(KEY_ENTER)
	await wait(1.0)

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


## Apollo 13's way home (#67): hold the corridor's middle, open each chute on its mark, then continue.
func _reentry() -> void:
	var s = g.screen
	var R = s.R
	var mid := (float(R.D.corridor_deg[0]) + float(R.D.corridor_deg[1])) * 0.5
	var shot_b := false
	while is_instance_valid(s) and g.screen == s and R.phase != "splash":
		if R.phase == "plasma":
			s.push = 1 if R.angle < mid - 0.3 else (-1 if R.angle > mid + 0.3 else 0)
			if R.blackout() and not shot_b:
				shot_b = true
				await shot("reentry_blackout")
		elif (R.drogue_err < 0.0 and R.height_ft <= float(R.D.drogue_ft)) or (R.drogue_err >= 0.0 and R.main_err < 0.0 and R.height_ft <= float(R.D.main_ft)):
			s._chute()
		await wait(0.02)
	await wait(1.5)
	await shot("reentry_splash")
	if is_instance_valid(s) and g.screen == s:
		s._continue()
