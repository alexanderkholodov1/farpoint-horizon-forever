extends "res://scripts/screens/screen.gd"
## The story's chapter select (issue #43): the six NASA missions the cuyes were at, in the order they happened. "Play
## the whole story" plays the prologue and every chapter in a row; each card plays its chapter (its intro film, its
## mission, its outro), and "Mission only" plays the mission without the story (a team decision, #43). The chapters,
## their dates and their pictures are in data/chapters.json.

const DATA := "res://data/chapters.json"
const Story := preload("res://scripts/screens/story.gd")
const PHOTO_H := 132.0

var chapters: Array = []


func enter(_args: Dictionary) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	chapters = d.get("chapters", []) if d is Dictionary else []
	var veil := ColorRect.new()   # the globe stays behind, dimmed, so its orbit lines never cross the cards
	veil.color = Color(0.0, 0.01, 0.04, 0.6)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var head := Kit.vbox(4)
	if Kit.compact:
		Kit.place(head, 0, 0, 1, 0, 24, 6, -24, 70)
	else:
		Kit.place(head, 0, 0, 1, 0, 50, 30, -50, 150)
	add_child(head)
	var over := Kit.caps(tr("The story") + "  ·  " + tr("Six real NASA missions, in the order they happened"))
	over.add_theme_color_override("font_color", Color(Kit.C_ON_DARK, 0.8))
	Kit.legible(over, 1.4)
	head.add_child(over)
	head.add_child(Kit.legible(Kit.lbl(tr("The cuyes who were there"), 26 if Kit.compact else 36, Kit.C_ON_DARK, Kit.FONT_T)))
	var sub := Kit.lbl(tr("History as NASA tells it: the cuyes help, panic and joke, and the real events decide the outcome."), Kit.T_BODY, Color(Kit.C_ON_DARK, 0.75), Kit.FONT_R, true)
	Kit.legible(sub, 1.2)
	sub.visible = not Kit.compact
	head.add_child(sub)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if Kit.compact:
		Kit.place(sc, 0, 0, 1, 1, 24, 76, -24, -54)
	else:
		Kit.place(sc, 0, 0, 1, 1, 50, 160, -50, -76)
	add_child(sc)
	sc.add_child(grid)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in chapters.size():
		grid.add_child(_card(i, chapters[i]))

	var bar := Kit.hbox(12)
	if Kit.compact:
		Kit.place(bar, 0, 1, 1, 1, 24, -48, -24, -8)
	else:
		Kit.place(bar, 0, 1, 1, 1, 50, -62, -50, -20)
	add_child(bar)
	bar.add_child(Kit.btn(tr("◀ Menu"), func(): go("menu")))
	bar.add_child(Kit.btn(tr("The crew and your patches"), func(): go("crew_gallery")))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	bar.add_child(Kit.accent_btn(Kit.btn(tr("▶  Play the whole story") + "  ·  Enter", _play_all, Kit.T_BODY), Kit.C_GOLD))


func _card(i: int, C: Dictionary) -> Control:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", Kit.flat(Kit.C_BG, Kit.C_EDGE, 14, 1, 0, 0))
	pc.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW   # the picture takes the card's rounded corners
	var v := Kit.vbox(0)
	pc.add_child(v)
	var h: float = 40.0 if Kit.compact else PHOTO_H   # a phone: a strip of the picture, so both rows of chapters fit
	var path: String = C.get("picture", "")
	if path != "" and ResourceLoader.exists(path):
		var pic := Kit.cover(load(path), h)
		v.add_child(pic)
		var cap := PanelContainer.new()
		cap.add_theme_stylebox_override("panel", Kit.flat(Color(0.0, 0.02, 0.06, 0.62), Color(0, 0, 0, 0), 9, 0, 9, 3))
		cap.add_child(Kit.lbl("NASA · " + tr(C.caption), Kit.T_CAPS, Kit.C_ON_DARK, Kit.FONT_B))
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(cap)
		cap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 10)
		cap.visible = not Kit.compact
	else:   # no NASA picture of this one in the game yet: the space of the others, dark
		var blank := ColorRect.new()
		blank.color = Color(0.02, 0.04, 0.09)
		blank.custom_minimum_size = Vector2(0, h)
		v.add_child(blank)
	var t := Kit.vbox(6)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 14 if Kit.compact else 18)
	pad.add_child(t)
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(pad)
	var kind := Kit.caps("%d  ·  %s" % [i + 1, tr(C.year)])
	kind.add_theme_color_override("font_color", Kit.C_GOLD)
	t.add_child(kind)
	t.add_child(Kit.lbl(tr(C.name), 18 if Kit.compact else 22, Kit.C_TEXT, Kit.FONT_T, true))
	var line := Kit.lbl(tr(C.line), Kit.T_SMALL + 1, Kit.C_DIM, Kit.FONT_R, true)
	line.visible = not Kit.compact
	t.add_child(line)
	var push := Control.new()   # the buttons sit on the card's floor, level across a row of cards
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.add_child(push)
	var row := Kit.hbox(8)
	t.add_child(row)
	row.add_child(Kit.accent_btn(Kit.btn(tr("▶ Play the chapter"), func(): _play_chapter(C.id), Kit.T_SMALL + 1), Kit.C_GOLD))
	# a phone: the shorter word, so the third column is not cut at the screen's edge
	row.add_child(Kit.btn(tr("Mission") if Kit.compact else tr("Mission only"), func(): _play_mission(C.id), Kit.T_SMALL + 1))
	return pc


func _play_all() -> void:
	Kit.UiSound.play("click")
	go("story", {"scenes": Story.story(), "back": "chapters"})


func _play_chapter(id: String) -> void:
	Kit.UiSound.play("click")
	var list := [id]
	if id == "apollo13":   # the prologue (who the cuyes are) plays once, before the first chapter
		list = ["prologue", id]
	go("story", {"scenes": Story.story(list), "back": "chapters"})


func _play_mission(id: String) -> void:
	Kit.UiSound.play("click")
	go(id, {"back": "chapters"})   # Esc and the end of the game come back here, not to the main menu (#97)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
		_play_all()
	elif e.keycode == KEY_ESCAPE:
		Kit.UiSound.play("click")
		go("menu")
	elif e.keycode >= KEY_1 and e.keycode <= KEY_6 and e.keycode - KEY_1 < chapters.size():
		_play_chapter(chapters[e.keycode - KEY_1].id)
