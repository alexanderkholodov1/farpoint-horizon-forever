extends SceneTree
## Renders icon.svg at 512 px to shots/icon.png to look at it (development only).
func _initialize() -> void:
	var img := Image.new()
	img.load_svg_from_string(FileAccess.get_file_as_string("res://icon.svg"), 4.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	img.save_png(ProjectSettings.globalize_path("res://shots/icon.png"))
	var small := Image.new()
	small.load_svg_from_string(FileAccess.get_file_as_string("res://icon.svg"), 0.25)
	small.resize(32, 32)
	small.save_png(ProjectSettings.globalize_path("res://shots/icon32.png"))
	quit()
