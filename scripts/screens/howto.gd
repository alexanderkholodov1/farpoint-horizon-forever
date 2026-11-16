extends "res://scripts/screens/screen.gd"
## Overlay: how to play, at a glance (issue #82): five short cards, one idea each with its drawing, and the words a
## newcomer may not know on a tab of their own (data/glossary.json, issue #69). Opened with main.overlay("howto") (the
## menu) or from the pause card. Esc, Enter or Backspace close it; 1 and 2 switch the tabs.

const PartIcon := preload("res://scripts/ui/part_icon.gd")
const Glossary := preload("res://scripts/ui/glossary.gd")
## [drawing, title, one line]
const STEPS := [
	["star", "Pick a mission", "Each one answers a real science question."],
	["bus", "Build your craft", "One question at a time. The ★ option is the best fit."],
	["rocket", "Launch", "Arrows lean the rocket. Space drops an empty stage."],
	["orbit", "Fly it", "Plan, give the GO; the flight computer flies the burns."],
	["camera", "Get your science", "Your craft works for months and sends real NASA photos home."],
]

var body: VBoxContainer
var tabs: HBoxContainer
var tab := 0


func enter(_args: Dictionary) -> void:
	var v := Kit.overlay(self, tr("How to play"), 900, 560, queue_free)
	tabs = Kit.segmented()
	v.add_child(tabs)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	body = Kit.vbox(Kit.GAP)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	v.add_child(Kit.lbl(tr("Enter goes on · Backspace goes back · Esc pauses a mission · Esc or Enter closes this"), Kit.T_SMALL, Kit.C_DIM))
	_show(0)


func _show(i: int) -> void:
	tab = i
	for c in tabs.get_children():
		c.queue_free()
	tabs.add_child(Kit.choice(tr("How it works"), i == 0, func(): _show(0), 180))
	tabs.add_child(Kit.choice(tr("Words"), i == 1, func(): _show(1), 180))
	for c in body.get_children():
		c.queue_free()
	if i == 0:
		for s in STEPS:
			body.add_child(_card(s[0], tr(s[1]), tr(s[2])))
	else:
		for e in Glossary.all():
			body.add_child(_word(tr(str(e.term)), tr(str(e.meaning))))


## One idea: its drawing, a short title, one line.
func _card(kind: String, title: String, line: String) -> Control:
	var p := Kit.tile(Kit.C_LINE, 14, 8)
	var h := Kit.hbox(16)
	p.add_child(h)
	var icon := PartIcon.new()
	icon.kind = kind
	icon.k = 0.7
	h.add_child(icon)
	var t := Kit.vbox(2)
	t.alignment = BoxContainer.ALIGNMENT_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	t.add_child(Kit.lbl(title, Kit.T_VALUE, Kit.C_TEXT, Kit.FONT_B))
	t.add_child(Kit.lbl(line, Kit.T_BODY, Kit.C_DIM, Kit.FONT_R, true))
	return p


## One word and what it means.
func _word(term: String, meaning: String) -> Control:
	var h := Kit.hbox(14)
	var t := Kit.lbl(term, Kit.T_BODY, Kit.C_ACCENT, Kit.FONT_B)
	t.custom_minimum_size.x = 170
	t.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(t)
	h.add_child(Kit.lbl(meaning, Kit.T_BODY, Kit.C_TEXT, Kit.FONT_R, true))
	return h


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = e.physical_keycode
	if k in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_BACKSPACE]:
		queue_free()
	elif k == KEY_1 or k == KEY_2:
		_show(k - KEY_1)
	else:
		return
	get_viewport().set_input_as_handled()
