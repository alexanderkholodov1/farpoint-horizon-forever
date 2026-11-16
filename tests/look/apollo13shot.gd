extends Node
## A look at mission 1's adapter game (issue #45; development only, needs a window): played on its own with a wrong
## part, the tape on the timing ring and the win, then from the story's "Your turn" card on into the outro.
## Saves to shots/a13_*.png. Run: tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/apollo13shot.tscn
var g
var n := 0

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/a13_%02d_%s.png" % [dir, n, name])
	print("shot ", n, " ", name)
	n += 1

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func key(k: int) -> void:
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = k
	g.screen._unhandled_input(e)

## Presses Space when the ring is on the circle.
func tape() -> void:
	var s = g.screen
	while true:
		var rem: float = 1.0 - s.ring_t / (s.RING_PERIOD * 0.8)
		if absf(rem) < 0.05:
			break
		await get_tree().process_frame
	key(KEY_SPACE)

func _ready() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await wait(1.0)
	# the danger zone and past the line (the gauge pushed up for the pictures)
	g.go("apollo13", {"back": "menu"})
	await wait(1.0)
	g.screen.A.co2 = 0.86
	await wait(1.2)
	await shot("danger")
	g.screen.A.co2 = 0.995
	await wait(3.5)
	await shot("lost")
	g.go("apollo13", {"back": "menu"})
	await wait(1.5)
	await shot("start")
	key(KEY_5)                       # the food packet: wrong
	await wait(0.3)
	await shot("wrong")
	await wait(1.6)
	key(KEY_1)                       # cardboard
	await wait(0.8)
	await shot("cardboard")
	key(KEY_2)                       # bag
	await wait(0.8)
	key(KEY_3)                       # tape
	await wait(0.4)
	await shot("tape_ring")
	for i in 3:
		await tape()
		await wait(0.15)
	await wait(0.5)
	await shot("taped")
	key(KEY_4)                       # hose: done
	await wait(0.9)
	await shot("win")
	await wait(3.0)
	await shot("photo")
	# from the story: the "Your turn" card, the game with the crew, then the outro
	g.go("story", {"scenes": ["apollo13/mission", "apollo13/fixed"], "back": "menu"})
	await wait(2.0)
	await shot("story_card")
	g.screen.dialogue._input(_enter())
	await wait(2.0)
	await shot("campaign_start")
	for id in [KEY_1, KEY_2, KEY_3]:
		key(id)
		await wait(0.6)
	for i in 3:
		await tape()
		await wait(0.15)
	key(KEY_4)
	await wait(1.2)
	await shot("campaign_win")
	await wait(3.0)
	key(KEY_ENTER)
	await wait(2.5)
	await shot("outro")
	get_tree().quit()

func _enter() -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = KEY_ENTER
	return e
