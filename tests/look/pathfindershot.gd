extends Node
## A look at mission 3 (issue #47; development only, needs a window): a descent that bursts (no rockets), then one
## flown right (steady, rockets at 98 m, cut at 21.5 m), the bounces, the petals, Sojourner down the ramp, the first
## wheel and the photos; then the story's intro. Saves to shots/mpf_*.png and always quits.
## Run: tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/pathfindershot.tscn
var g
var n := 0

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/mpf_%02d_%s.png" % [dir, n, name])
	print("shot ", n, " ", name)
	n += 1

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func key(k: int) -> void:
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = k
	g.screen._unhandled_input(e)

## Waits until cond() is true, at most `limit` seconds (so the harness never hangs).
func until(cond: Callable, limit := 20.0) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < limit * 1000.0:
		await get_tree().process_frame

func _ready() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await wait(1.0)
	# a descent with no rockets: the airbags burst
	g.go("pathfinder", {"back": "menu"})
	await wait(1.5)
	await shot("brief")
	key(KEY_ENTER)
	await wait(1.0)
	await shot("descent_start")
	print("fps ", Engine.get_frames_per_second())
	g.screen.L.alt = 60.0
	var s0 = g.screen
	await until(func(): return s0.phase == "lost")
	await wait(1.6)
	await shot("burst")
	key(KEY_ENTER)
	await wait(1.5)
	# flown right
	var s = g.screen
	key(KEY_ENTER)
	await wait(0.5)
	s.L.alt = 300.0
	await until(func(): return s.L.airbags)
	await wait(0.4)
	await shot("airbags")
	await until(func(): return s.L.alt <= 120.0)
	await shot("get_ready")
	await until(func(): return s.L.alt <= 98.0)
	await shot("rockets_now")
	key(KEY_SPACE)
	await wait(0.3)
	await shot("rockets")
	await until(func(): return s.L.alt <= 22.5)
	await shot("cut_now")
	key(KEY_C)
	await wait(0.4)
	await shot("cut")
	await until(func(): return s.phase != "descent")
	print("phase after landing ", s.phase, " impact ", s.L.impact)
	await wait(0.3)
	await shot("impact")
	await wait(3.0)
	await shot("bouncing")
	await until(func(): return s.phase != "bounce", 60.0)
	await wait(1.5)
	await shot("rest_petals")
	await until(func(): return s.phase != "deflate")
	await wait(0.5)
	await shot("ramp_start")
	var guard := 0
	while s.phase == "ramp" and guard < 400:
		guard += 1
		s.ramp_s = minf(1.0, s.ramp_s + 0.01)
		s.ramp_off = 0.0
		if absf(s.ramp_s - 0.5) < 0.006:
			await shot("ramp_half")
		await get_tree().process_frame
	await wait(0.6)
	await shot("wheel")
	await wait(3.0)
	await shot("photo")
	g.go("story", {"scenes": ["pathfinder/intro", "pathfinder/mission", "pathfinder/outro"], "back": "menu"})
	for i in 13:
		await wait(1.6 if i == 0 else 1.3)
		await shot("intro_%d" % i)
		if not g.screen.get_script().resource_path.ends_with("story.gd"):
			break
		var d = g.screen.dialogue
		if d == null or not is_instance_valid(d):
			break
		var e := InputEventKey.new()
		e.pressed = true
		e.physical_keycode = KEY_ENTER
		d._input(e)
		await wait(0.3)
		if is_instance_valid(d):
			d._input(e)
	get_tree().quit()
