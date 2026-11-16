extends Node
## Plays chapter 6 alone, intro, mission and outro, for a person to try it (issue #50; needs a window).
## Run: tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/artemis1play.tscn


func _ready() -> void:
	var g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await get_tree().create_timer(1.0).timeout
	g.go("story", {"scenes": load("res://scripts/screens/story.gd").story(["artemis1"]), "back": "menu"})
