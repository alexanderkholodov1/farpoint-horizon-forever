extends Node
## The words a newcomer meets (issue #69): the orbit and radio questions of the design, an option pointed at, and how
## to play's list of words. Development harness; needs a window. Screenshots in shots/words_*.png.
var g


func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func(): get_tree().quit())
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await _wait(1.2)
	GameState.start_solo()
	GameState.start_mission("volcanes")
	g.go("design", {"step": 0})
	await _wait(0.8)
	g.screen._show(1)   # where it will fly
	await _wait(0.6)
	_point("Over the poles")
	await _wait(0.4)
	await _shot("orbit")
	g.screen._show(6)   # the antenna
	await _wait(0.6)
	_point("Fast radio")
	await _wait(0.4)
	await _shot("radio")
	g.go("menu")
	await _wait(0.6)
	g.overlay("howto")
	await _wait(0.6)
	var rt: RichTextLabel = g.screen.find_children("*", "RichTextLabel", true, false)[0]
	rt.scroll_to_line(rt.get_line_count() - 1)
	await _wait(0.3)
	await _shot("howto")
	print("wordsshot: done")
	get_tree().quit()


func _point(t: String) -> void:
	for l in g.find_children("*", "Label", true, false):
		if l.is_visible_in_tree() and t in l.text:
			var p: Node = l
			while p and not (p is PanelContainer):
				p = p.get_parent()
			if p:
				p.mouse_entered.emit()
			return
	print("not found: ", t)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/words_%s.png" % [dir, name])
