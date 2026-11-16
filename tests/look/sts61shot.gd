extends Node
## A look at mission 2 (issue #46; development only, needs a window): the five spacewalks (a wrong part, the cloth,
## a spacewalk that runs out and is tried again), the first image brought into focus, the photo; then the story's
## intro, the Your turn card and the outro. Saves to shots/s61_*.png.
## Run: tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/sts61shot.tscn
var g
var n := 0

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/s61_%02d_%s.png" % [dir, n, name])
	print("shot ", n, " ", name)
	n += 1

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func key(k: int) -> void:
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = k
	g.screen._unhandled_input(e)

func pick(id: String) -> void:
	var s = g.screen
	var i: int = s.keys.find(id)
	key(KEY_1 + i)

## Does the job in the panel: halfway (for a picture), then to the end.
func fit(name := "") -> void:
	var w = g.screen.work
	await wait(0.6)
	match w.mode:
		"drag":
			w.key_space()
		"screw":
			w._turn(TAU * 4.5)
		"unroll":
			w._pull(0.45, 200.0)
		"slide":
			w.depth = 0.5
			w.offset = 0.9
		"aim":
			w.angles[0] = w.targets[0] - 0.12
	await wait(0.5)
	if name != "":
		await shot("job_" + name)
	match w.mode:
		"drag":
			while not w.done:
				w.key_space()
				await wait(0.05)
		_:
			w._finish()
	await wait(0.8)

func _ready() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await wait(1.0)
	g.go("sts61", {"back": "menu"})
	await wait(2.0)
	await shot("walk1")
	pick("cloth")
	await wait(0.4)
	await shot("cloth")
	await wait(1.6)
	pick(g.screen.W.needed())
	await wait(0.5)
	await shot("in_hand")
	await fit("screw")
	await wait(0.4)
	await shot("fitted")
	# let spacewalk one run out
	g.screen.W.left = 2.0
	await wait(2.6)
	await shot("lost")
	key(KEY_ENTER)
	await wait(1.5)
	var w := 0
	while not g.screen.W.done():
		if g.screen.phase == "walks" and g.screen.W.picked == "":
			pick(g.screen.W.needed())
			await wait(0.6)
			var nm: String = g.screen.W.picked
			await fit(nm if nm in ["fuses", "arrays", "wfpc2", "costar", "magnetometers", "ghrs"] else "")
			await wait(0.3)
		elif g.screen.phase == "between":
			if w < 2:
				await shot("between")
			w += 1
			await wait(2.6)
		else:
			await wait(0.2)
	await wait(3.0)
	await shot("focus_start")
	g.screen.dial = g.screen.target - 0.2
	await wait(0.3)
	await shot("focus_near")
	g.screen.dial = g.screen.target
	await wait(1.0)
	await shot("sharp")
	await wait(2.6)
	await shot("photo")
	# the story around it
	g.go("story", {"scenes": ["sts61/intro"], "back": "menu"})
	var d = null
	for i in 8:
		await wait(1.6 if i == 0 else 1.3)
		await shot("intro_%d" % i)
		if not g.screen.get_script().resource_path.ends_with("story.gd"):
			break
		d = g.screen.dialogue
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
