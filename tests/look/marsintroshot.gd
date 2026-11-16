extends Node
## A look at mission 3's story intro (development only, needs a window): every line of the intro and the Your turn
## card, until the mission screen opens. Saves to shots/mi_*.png and quits.
## Run: tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/marsintroshot.tscn
var g
var n := 0

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/mi_%02d_%s.png" % [dir, n, name])
	print("shot ", n, " ", name)
	n += 1

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func _ready() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await wait(1.0)
	g.go("story", {"scenes": ["pathfinder/intro", "pathfinder/mission"], "back": "menu"})
	var guard := 0
	while guard < 40 and g.screen_id == "story":
		guard += 1
		var d = g.screen.dialogue
		if d == null or not is_instance_valid(d) or d.at < 0:
			await wait(0.2)
			continue
		var at: int = d.at
		var L: Dictionary = d.lines[at]
		var tag := "%s_%d" % [g.screen.scenes[g.screen.scene_at].replace("/", "-"), at]
		if not L.has("who"):
			await wait(minf(float(L.get("wait", 2.0)) * 0.6, 3.0))
			await shot(tag)
			while is_instance_valid(d) and d.at == at and g.screen_id == "story":
				await wait(0.1)
		else:
			await wait(1.3)
			await shot(tag + "_" + str(L.who))
			var e := InputEventKey.new()
			e.pressed = true
			e.physical_keycode = KEY_ENTER
			d._input(e)
			await wait(0.4)
			if is_instance_valid(d) and d.at == at:
				d._input(e)
		await wait(0.1)
	await wait(1.0)
	await shot("mission_screen")
	get_tree().quit()
