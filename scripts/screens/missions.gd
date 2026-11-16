extends "res://scripts/screens/screen.gd"
## Missions (CML 1): choose the mission's scientific objective among the scenarios of GameData.SCENARIOS.
## Each mission is a card to pick, as in a game's mission select: a real NASA picture of where it goes, its name, one
## line, and its facts as chips. The whole brief is the card's tooltip and is told again in the design.

## The picture of each mission: [file, the part of it shown (x, y, w, h in its pixels; none = all), caption].
## All are NASA images already in the game and cited in docs/sources.md (the mission photos and the globe textures).
const PICTURES := {
	"volcanes": ["res://assets/photos/volcano_watch/cotopaxi_landsat8_2015-09-15_truecolor.jpg", [], "Cotopaxi · Landsat 8, 2015"],
	"clima": ["res://assets/textures/earth_day.jpg", [740, 840, 620, 380], "The Pacific off Ecuador · Blue Marble"],
	"luna": ["res://assets/textures/moon_color.jpg", [796, 370, 455, 256], "The Moon · Lunar Reconnaissance Orbiter"],
	"telescopio": ["res://assets/photos/telescope/neptune_voyager2_1989.jpg", [170, 330, 640, 330], "Neptune · Voyager 2, 1989"],
	"libre": ["res://assets/textures/earth_night.jpg", [313, 228, 512, 312], "The Americas at night · Black Marble"],
	"moon_south_pole": ["res://assets/photos/moon_south_pole/south_pole_wide_lroc_wac.jpg", [], "The Moon's south pole · LRO"],
}
const PHOTO_H := 150.0

var order: Array = []      ## The missions as shown, for the number keys.
const Progress := preload("res://scripts/core/progress.gd")
const GREY := preload("res://assets/shaders/ui_grey.gdshader")


func enter(_args: Dictionary) -> void:
	var head := Kit.vbox(4)
	if Kit.compact:
		Kit.place(head, 0, 0, 1, 0, 24, 6, -24, 56)
	else:
		Kit.place(head, 0, 0, 1, 0, 50, 30, -50, 130)
	add_child(head)
	var over := Kit.caps(GameData.CML_NAMES[1] + "  ·  " + tr("Every mission starts with a science question"))
	over.add_theme_color_override("font_color", Color(Kit.C_ON_DARK, 0.8))   # straight on the dark scene in both appearances
	Kit.legible(over, 1.4)
	head.add_child(over)
	head.add_child(Kit.legible(Kit.lbl(tr("Choose your mission"), 26 if Kit.compact else 36, Kit.C_ON_DARK, Kit.FONT_T)))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if Kit.compact:
		Kit.place(sc, 0, 0, 1, 1, 24, 62, -24, -54)
	else:
		Kit.place(sc, 0, 0, 1, 1, 50, 130, -50, -76)
	add_child(sc)
	sc.add_child(grid)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mult: float = GameData.DIFFICULTY[GameState.difficulty].budget
	var ids: Array = Progress.ORDER.filter(func(x): return GameData.SCENARIOS.has(x))
	for id in GameData.SCENARIOS:
		if not ids.has(id):
			ids.append(id)
	order = ids
	for id in ids:
		grid.add_child(_card(id, GameData.SCENARIOS[id], mult))
	var back := Kit.btn(tr("◀ Menu"), func(): go("menu"))
	if Kit.compact:
		Kit.place(back, 0, 1, 0, 1, 24, -48, 150, -8)
	else:
		Kit.place(back, 0, 1, 0, 1, 50, -62, 180, -20)
	add_child(back)


func _card(id: String, S: Dictionary, mult: float) -> Control:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := Kit.flat(Kit.C_BG, Kit.C_EDGE, 14, 1, 0, 0)
	pc.add_theme_stylebox_override("panel", sb)
	pc.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW   # the picture takes the card's rounded corners
	pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pc.tooltip_text = _wrapped(S.desc)
	var v := Kit.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(v)
	var P: Array = PICTURES.get(id, [])
	var pic: TextureRect
	if not P.is_empty() and ResourceLoader.exists(P[0]):
		var reg := Rect2()
		if not P[1].is_empty():
			reg = Rect2(P[1][0], P[1][1], P[1][2], P[1][3])
		pic = Kit.cover(load(P[0]), 96.0 if Kit.compact else PHOTO_H, reg)
		v.add_child(pic)
		# the picture's credit, on a dark pill so it reads on any picture
		var cap := PanelContainer.new()
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.add_theme_stylebox_override("panel", Kit.flat(Color(0.0, 0.02, 0.06, 0.62), Color(0, 0, 0, 0), 9, 0, 9, 3))
		cap.add_child(Kit.lbl("NASA · " + tr(P[2]), Kit.T_CAPS, Kit.C_ON_DARK, Kit.FONT_B))
		pic.add_child(cap)
		cap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	# a mission that is not open yet: its picture in grey under a lock, and what opens it
	var lock: String = Progress.locked_by(id, S)
	var grey := false
	if lock != "":
		if pic:
			var lp := PanelContainer.new()
			lp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lp.add_theme_stylebox_override("panel", Kit.flat(Color(0.0, 0.02, 0.06, 0.7), Color(Kit.C_ON_DARK, 0.35), 14, 1, 14, 6))
			lp.add_child(Kit.lbl(tr("LOCKED"), Kit.T_SMALL, Kit.C_ON_DARK, Kit.spaced(Kit.FONT_B, 3)))
			pic.add_child(lp)
			lp.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
		pc.mouse_default_cursor_shape = Control.CURSOR_ARROW
		sb.bg_color = Color(0.2, 0.2, 0.2)   # a grey card, opaque
		sb.border_color = Color(0.45, 0.45, 0.45)
		grey = true
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 14)
	v.add_child(pad)
	var t := Kit.vbox(6)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(t)
	var kind := Kit.caps("%d  ·  %s" % [order.find(id) + 1, S.type])
	kind.add_theme_color_override("font_color", Kit.C_GOLD)
	t.add_child(kind)
	t.add_child(Kit.lbl(S.name, 18 if Kit.compact else 22, Kit.C_TEXT, Kit.FONT_T, true))
	var line := Kit.lbl(_first_sentence(S.desc), Kit.T_SMALL + 1, Kit.C_DIM, Kit.FONT_R, true)
	line.visible = not Kit.compact   # on a phone the picture and the name say it; the rest is in the design
	line.max_lines_visible = 2
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.add_child(line)
	var chips := HFlowContainer.new()   # wraps instead of widening the card (a phone has three narrow columns)
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 4)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(chips)
	if lock != "":
		chips.add_child(Kit.chip(tr("Coming soon") if lock == "soon" else tr("Finish “%s” first") % GameData.SCENARIOS[lock].name, Kit.C_DIM))
		if grey:   # the whole card in grey: the picture, the words, the chips
			var gm := ShaderMaterial.new()
			gm.shader = GREY
			pc.material = gm
			for c in pc.find_children("*", "CanvasItem", true, false):
				(c as CanvasItem).use_parent_material = true
	else:
		if Progress.is_done(id):
			chips.add_child(Kit.chip("✓ " + tr("Done"), Kit.C_OK))
		chips.add_child(Kit.chip(tr("Budget %s") % Kit.money(S.budget * mult), Kit.C_GOLD))
		chips.add_child(Kit.chip(tr("Must work %d+ years") % S.min_years))
	# every card answers a click: an open one starts its mission, a locked one says what opens it
	pc.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Kit.UiSound.play("click")
			_choose(id))
	# the card answers the pointer: its edge lights in the brand's amber and the picture comes closer
	pc.mouse_entered.connect(func():
		sb.border_color = Kit.C_GOLD
		sb.set_border_width_all(2)
		if pic:
			pic.pivot_offset = pic.size * 0.5
			pic.create_tween().tween_property(pic, "scale", Vector2(1.06, 1.06), 0.25).set_trans(Tween.TRANS_SINE))
	pc.mouse_exited.connect(func():
		sb.border_color = Kit.C_EDGE
		sb.set_border_width_all(1)
		if pic:
			pic.create_tween().tween_property(pic, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE))
	return pc


## The keyboard: 1 to 6 choose a mission that is open, Backspace or Escape go back to the menu.
func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = e.physical_keycode
	if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < order.size():
		Kit.UiSound.play("click")
		_choose(order[k - KEY_1])   # a locked one says what opens it
	elif k == KEY_BACKSPACE or k == KEY_ESCAPE:
		go("menu")
	else:
		return
	get_viewport().set_input_as_handled()


## The brief's first sentence, the card's one line.
func _first_sentence(text: String) -> String:
	var i := text.find(". ")
	return text if i < 0 else text.substr(0, i + 1)


## The whole brief as a tooltip, broken into short lines.
func _wrapped(text: String) -> String:
	var out := ""
	var n := 0
	for w in text.split(" "):
		if n + w.length() > 62:
			out += "\n"
			n = 0
		out += w + " "
		n += w.length() + 1
	return out.strip_edges()


func _choose(id: String) -> void:
	var lock: String = Progress.locked_by(id, GameData.SCENARIOS[id])
	if lock != "":   # a locked card answers: what opens it, and where "All open" is for a demo
		var why: String = tr("Coming soon") if lock == "soon" else tr("Finish “%s” first to open it") % GameData.SCENARIOS[lock].name
		toast("🔒 " + why + "  ·  " + tr("Settings → All open unlocks every mission"), Kit.C_WARN)
		return
	GameState.start_mission(id)
	go("design", {"step": 0})
