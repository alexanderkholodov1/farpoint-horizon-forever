extends Node
## A look at the story (issue #66; development only, needs a window): chapter 1 played through on the story stage,
## a screenshot at every beat (title cards, each line while it is spoken, the launch, the splashdown), then a scene
## over the design with the live portrait. Saves to shots/story_*.png.
## Run: tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/storyshot.tscn
const Dialogue := preload("res://scripts/story/dialogue.gd")
var g
var n := 0

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/story_%02d_%s.png" % [dir, n, name])
	print("shot ", n, " ", name)
	n += 1

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func enter(d) -> void:
	if d == null or not is_instance_valid(d):
		return
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = KEY_ENTER
	d._input(e)

func _ready() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await wait(1.0)
	g.go("crew_gallery")
	await wait(1.5)
	await shot("crew")
	g.go("story", {"scenes": load("res://scripts/screens/story.gd").story(), "back": "crew_gallery"})
	var guard := 0
	while g.screen and g.screen.get_script().resource_path.ends_with("story.gd") and guard < 200:
		guard += 1
		var d = g.screen.dialogue
		if d == null or not is_instance_valid(d) or d.at < 0:
			await wait(0.1)
			continue
		var at: int = d.at
		var L: Dictionary = d.lines[at]
		var tag := ("%s_%d" % [g.screen.scenes[g.screen.scene_at], at]).replace("/", "-")
		if L.has("title") and not L.has("who"):
			await wait(1.6)
			await shot(tag + "_title")
			enter(d)
		elif not L.has("who"):
			var w: float = L.get("wait", 2.0)
			await wait(minf(w * 0.5, 2.0))
			await shot(tag + "_beat")
			if w >= 5.0:
				await wait(w * 0.5)
				await shot(tag + "_beat2")
			while is_instance_valid(d) and d.at == at:
				await wait(0.1)
		else:
			await wait(1.0)
			await shot(tag + "_" + str(L.who))
			enter(d)
			await wait(0.6)
			enter(d)
		await wait(0.15)
	# a scene over the design, with the live portrait
	GameState.start_solo()
	GameState.start_mission("volcanes")
	g.go("design", {"step": 0})
	await wait(1.0)
	var d2 = Dialogue.play(g, "apollo13", "problem")
	enter(d2)
	await wait(1.4)
	await shot("design_live")
	d2._end(true)
	get_tree().quit()
