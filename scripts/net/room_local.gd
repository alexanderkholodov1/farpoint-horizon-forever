extends "res://scripts/net/room.gd"
## The room on one screen (and the room of a solo player with bots): no network. This machine is the host and the
## state lives in memory; people pass the screen, or one person works with bots. The editor and the desktop builds
## always use this room.


func _init() -> void:
	super()
	mode = "same"
	state.mode = mode
