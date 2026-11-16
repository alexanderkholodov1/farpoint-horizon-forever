extends Node
## Plays chapter 4 alone, from its intro through the mission to its outro, for a person to try it (issue #48;
## development only, needs a window; does not quit by itself).
## Run: tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/lcrossplay.tscn


func _ready() -> void:
	var g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await get_tree().create_timer(1.0).timeout
	g.go("story", {"scenes": load("res://scripts/screens/story.gd").story(["lcross"]), "back": "menu"})
