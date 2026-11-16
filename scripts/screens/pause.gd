extends "res://scripts/screens/screen.gd"
## Overlay: the pause card (issue #65). Esc opens it on the screens of a mission (main.gd PAUSABLE) and stops the
## game's time: the flight, the operation's months and the world stand still (get_tree().paused) while this card keeps
## working (process_mode ALWAYS). Resume, how to play, sound, or back to the menu (asked twice: it ends the mission).
## Esc or Enter resumes.

var menu_btn: Button
var sure := false
var howto: Control


func enter(_args: Dictionary) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Kit.UiSound.play("select")
	var v := Kit.overlay(self, tr("Paused"), 440, 340, _resume)
	v.add_child(Kit.lbl(tr("Time has stopped. Nothing happens to your mission until you come back."), Kit.T_BODY, Kit.C_DIM, Kit.FONT_R, true))
	v.add_child(Kit.spacer(6))
	var resume := Kit.accent_btn(Kit.btn(tr("Resume  (Esc)"), _resume, Kit.T_ACTION), Kit.C_GOLD)
	resume.custom_minimum_size.y = Kit.BTN_H + 8
	v.add_child(resume)
	v.add_child(Kit.btn(tr("How to play"), _howto, Kit.T_BODY))
	var snd := Kit.btn("", func(): pass, Kit.T_BODY)
	var say_sound := func(): snd.text = tr("Sound: off") if Kit.UiSound.is_muted() else tr("Sound: on")
	say_sound.call()
	snd.pressed.connect(func():
		Kit.UiSound.set_muted(not Kit.UiSound.is_muted())
		say_sound.call())
	v.add_child(snd)
	menu_btn = Kit.btn(tr("Back to the menu"), _to_menu, Kit.T_BODY)
	v.add_child(menu_btn)


func _resume() -> void:
	get_tree().paused = false
	queue_free()


func _to_menu() -> void:
	if not sure:   # it ends the mission: ask once more, on the same button
		sure = true
		menu_btn.text = tr("Leave the mission? Click again")
		Kit.accent_btn(menu_btn, Kit.C_BAD)
		return
	get_tree().paused = false
	queue_free()
	go("menu")


func _howto() -> void:
	if howto and is_instance_valid(howto):
		return
	howto = load("res://scripts/screens/howto.gd").new()
	howto.main = main
	howto.world = world
	howto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(howto)
	howto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	howto.enter({})


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.physical_keycode == KEY_ESCAPE or e.physical_keycode == KEY_ENTER or e.physical_keycode == KEY_KP_ENTER:
		if howto and is_instance_valid(howto):
			howto.queue_free()   # Esc closes the help first, then the pause
		else:
			_resume()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if get_tree() and get_tree().paused:
		get_tree().paused = false   # never leave the game frozen behind a card that is gone
