extends Node
## The menu and its sections as a stranger sees them (issue #82). Development harness; needs a window.
var g


func _ready() -> void:
	get_tree().create_timer(40.0).timeout.connect(func(): get_tree().quit())
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await _wait(1.5)
	await _shot("menu")
	g.overlay("howto")
	await _wait(0.6)
	await _shot("howto")
	g.screen.get_children()[-1]._show(1) if false else null
	for o in g.find_children("*", "", true, false):
		if o.has_method("_word"):
			o._show(1)
	await _wait(0.4)
	await _shot("words")
	g.go("menu", {"settings": true})
	await _wait(0.8)
	await _shot("settings")
	print("menushot: done")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/menu_%s.png" % [dir, name])
