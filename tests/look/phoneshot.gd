extends Node
## The six chapters' mini-games on a phone in landscape (issue #91, the campaign's part; development only, needs a
## window): each at the moment it needs the player, with its touch buttons. Saves shots/phone_*.png and always quits.
## Run: FIT_CSS_H=390 TOUCH_KEYS=1 tools/dev/godot.sh --path . --resolution 844x390 res://tests/look/phoneshot.tscn
var g
var n := 0

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/phone_%02d_%s.png" % [dir, n, name])
	print("shot ", n, " ", name)
	n += 1

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func key(k: int) -> void:
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = k
	g.screen._unhandled_input(e)

func _ready() -> void:
	get_tree().create_timer(400.0).timeout.connect(func(): get_tree().quit())
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await wait(1.5)
	g.go("chapters")
	await wait(1.2)
	await shot("chapters")
	g.go("apollo13", {"back": "menu"})
	await wait(2.0)
	await shot("apollo13")
	g.go("sts61", {"back": "menu"})
	await wait(2.0)
	await shot("sts61")
	g.go("pathfinder", {"back": "menu"})
	await wait(1.5)
	await shot("mpf_brief")
	key(KEY_ENTER)
	await wait(2.0)
	await shot("mpf_descent")
	g.go("lcross", {"back": "menu"})
	await wait(1.5)
	await shot("lc_brief")
	key(KEY_ENTER)
	await wait(1.0)
	await shot("lc_aim")
	g.go("dart", {"back": "menu"})
	await wait(1.5)
	key(KEY_ENTER)
	await wait(1.0)
	g.screen.t = -5200.0
	await wait(1.0)
	await shot("dart_find")
	g.go("artemis1", {"back": "menu"})
	await wait(1.5)
	await shot("art_brief")
	g.screen._start()
	await wait(3.0)
	await shot("art_count")
	g.screen.met = -0.1
	await wait(0.5)
	key(KEY_SPACE)
	await wait(3.0)
	await shot("art_climb")
	get_tree().quit()
