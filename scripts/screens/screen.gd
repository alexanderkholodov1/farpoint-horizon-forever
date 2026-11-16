extends Control
## The base every screen and overlay extends: `extends "res://scripts/screens/screen.gd"`.
## A screen is a full-window Control that main.gd creates on `main.go(id, args)` and frees on the next go(): its UI is
## its children, so leaving the screen removes its UI. An overlay (main.overlay(id)) is the same, drawn on top of the
## current screen; it closes itself with queue_free().
##
## Life of a screen: main.gd sets `main` and `world`, adds it, calls enter(args); then process(delta) every frame
## (after the world's camera); exit() just before it is freed. Shared state lives in the autoload GameState.
## Do not `await` in a screen after a call that may change screen: the screen is freed at the end of that frame.

const Kit := preload("res://scripts/ui/kit.gd")
const World := preload("res://scripts/world/world.gd")

var main            ## The flow controller (scripts/core/main.gd): go(), go_faded(), overlay(), launch(), fade().
var world: World    ## The 3D world (scripts/world/world.gd): camera, stage, the craft.

## The mission being designed (shortcut for GameState.mission).
var mission:
	get:
		return GameState.mission
	set(value):
		GameState.mission = value


## Builds the screen. args are the ones given to main.go().
func enter(_args: Dictionary) -> void:
	pass


## Called just before the screen is freed.
func exit() -> void:
	pass


## Called every frame while this is the current screen.
func process(_delta: float) -> void:
	pass


func go(id: String, args := {}) -> void:
	main.go(id, args)


## Removes this screen's UI (to draw it again).
func clear() -> void:
	for c in get_children():
		c.queue_free()


func toast(text: String, col := Kit.C_ACCENT, time := 2.5) -> void:
	Kit.toast(self, text, col, time)
