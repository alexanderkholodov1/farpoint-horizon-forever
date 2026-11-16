extends "res://scripts/screens/screen.gd"
## Overlay: the credits (issue #14), told like the end of a film rather than a bibliography. The title and the arc, the
## two people who made the game with their links, a nod to the four bots, what it is built with, the AI that helped,
## and the sources behind every number, folded by section so they open on a click. Everything comes from
## data/credits.json (tools/content/credits.py, from docs/sources.md and the README; tests/ci/credits.gd keeps it in step).
## Opened with main.overlay("credits").

const CREDITS_PATH := "res://data/credits.json"
const Horizon := preload("res://scripts/ui/horizon.gd")
const Bots := preload("res://scripts/crew/bots.gd")

var reveal: Array = []        ## Blocks that fade and rise in, one after another.


var scroll: ScrollContainer


## The keys (issue #58): Esc or Backspace close; the arrows, Page Up / Page Down, Home and End move through the list.
func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed:
		return
	var k: int = e.physical_keycode
	if k == KEY_ESCAPE or k == KEY_BACKSPACE:
		queue_free()
	elif scroll and k in [KEY_DOWN, KEY_UP, KEY_PAGEDOWN, KEY_PAGEUP, KEY_HOME, KEY_END]:
		var step: int = {KEY_DOWN: 60, KEY_UP: -60, KEY_PAGEDOWN: 520, KEY_PAGEUP: -520, KEY_HOME: -1000000, KEY_END: 1000000}[k]
		scroll.scroll_vertical = maxi(0, scroll.scroll_vertical + step)
	else:
		return
	get_viewport().set_input_as_handled()


func enter(_args: Dictionary) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CREDITS_PATH))
	var shade := ColorRect.new()
	shade.color = Kit.C_SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var panel := Kit.panel_box(Kit.PAD)
	if Kit.compact:
		Kit.place(panel, 0, 0, 1, 1, Kit.MARGIN, Kit.MARGIN, -Kit.MARGIN, -Kit.MARGIN)
	else:
		Kit.place(panel, 0.5, 0, 0.5, 1, -560, Kit.MARGIN, 560, -Kit.MARGIN)
	add_child(panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	scroll = sc
	var box := Kit.vbox(Kit.GAP * 2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	var close := Kit.btn(tr("Close ×") + "  ·  Esc", queue_free, Kit.T_BODY)
	if Kit.compact:
		Kit.place(close, 1, 0, 1, 0, -150, Kit.MARGIN + 8, -Kit.MARGIN - 8, Kit.MARGIN + 8 + Kit.BTN_H)
	else:
		Kit.place(close, 0.5, 0, 0.5, 0, 404, Kit.MARGIN + 14, 520, Kit.MARGIN + 14 + Kit.BTN_H)
	add_child(close)

	_hero(box)
	_people(box, data.get("people", []))
	_made_with(box, data.get("built_with", []))
	_ai(box, data.get("ai_note", []), data.get("ai", []))
	_sources(box, data.get("sections", []), int(data.get("count", 0)))
	_ending(box)

	# entrance: each block fades and rises in after the one before
	for i in reveal.size():
		var c: Control = reveal[i]
		c.modulate.a = 0.0
		var tw := c.create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ===================================================================================== BLOCKS
func _hero(box: VBoxContainer) -> void:
	var v := Kit.vbox(4)
	box.add_child(v)
	reveal.append(v)
	v.add_child(_head(tr("Credits")))
	var arc := Horizon.new()
	arc.custom_minimum_size = Vector2(0, 40)
	arc.thickness = 2.5
	arc.sun_at = 0.4
	arc.progress = 0.0
	v.add_child(arc)
	arc.create_tween().tween_property(arc, "progress", 1.0, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var h := Kit.hbox(12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	h.add_child(Kit.lbl("Farpoint", Kit.T_SHOUT, Kit.C_TEXT, Kit.FONT_T))
	var hz := Kit.lbl("HORIZON", Kit.T_SHOUT, Kit.C_ACCENT, _spaced(Kit.FONT_B, 8))
	h.add_child(hz)
	var sub := Kit.lbl(tr("A space mission you design, launch and fly yourself. Made in Quito, Ecuador, on the line of the equator, for the 2026 NASA Space Apps Challenge."), Kit.T_LEAD, Kit.C_DIM, Kit.FONT_R, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)


func _people(box: VBoxContainer, people: Array) -> void:
	var v := Kit.vbox(Kit.GAP)
	box.add_child(v)
	reveal.append(v)
	v.add_child(_head(tr("Made by")))
	var row := Kit.hbox(Kit.GAP * 2)
	v.add_child(row)
	var cols := [Kit.C_ACCENT, Kit.C_GOLD]
	for i in people.size():
		var P: Dictionary = people[i]
		var col: Color = cols[i % cols.size()]
		var t := Kit.tile(col, Kit.PAD, Kit.PAD)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		var tv := Kit.vbox(6)
		t.add_child(tv)
		# an initials badge in the person's colour
		var hb := Kit.hbox(Kit.GAP)
		tv.add_child(hb)
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", Kit.flat(col, Color(0, 0, 0, 0), 26, 0, 0, 0))
		badge.custom_minimum_size = Vector2(52, 52)
		var ini := Kit.lbl(_initials(P.name), Kit.T_VALUE, Color(0.03, 0.06, 0.13), Kit.FONT_T)
		ini.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ini.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(ini)
		hb.add_child(badge)
		var nv := Kit.vbox(0)
		nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(nv)
		nv.add_child(Kit.lbl(P.name, Kit.T_STAT + 8, Kit.C_TEXT, Kit.FONT_T, true))
		nv.add_child(Kit.lbl("SK-Horizons · Quito", Kit.T_BODY, col, Kit.FONT_B))
		tv.add_child(Kit.lbl(_cap(P.role), Kit.T_LEAD + 1, Kit.C_TEXT, Kit.FONT_R, true))
		var links := Kit.hbox(6)
		tv.add_child(links)
		for L in P.get("links", []):
			var url: String = L.url
			links.add_child(Kit.btn(L.label + "  ↗", func(): OS.shell_open(url), Kit.T_BODY))


func _made_with(box: VBoxContainer, lines: Array) -> void:
	var v := Kit.vbox(Kit.GAP)
	box.add_child(v)
	reveal.append(v)
	v.add_child(_head(tr("Made with")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", Kit.GAP)
	grid.add_theme_constant_override("v_separation", Kit.GAP)
	v.add_child(grid)
	for line in lines:
		# "Engine: Godot Engine (https://...) (MIT)." -> a bold head and the rest
		var head: String = line.get_slice(":", 0)
		var rest: String = line.substr(head.length() + 1).strip_edges() if line.find(":") >= 0 else ""
		var t := Kit.tile(Kit.C_LINE)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(t)
		var tv := Kit.vbox(2)
		t.add_child(tv)
		tv.add_child(Kit.lbl(head, Kit.T_LEAD, Kit.C_TEXT, Kit.FONT_B, true))
		if rest != "":
			tv.add_child(_rich(rest, Kit.T_BODY, Kit.C_DIM))


func _ai(box: VBoxContainer, notes: Array, agents: Array) -> void:
	var v := Kit.vbox(Kit.GAP)
	box.add_child(v)
	reveal.append(v)
	v.add_child(_head(tr("With a little help")))
	if notes.size() > 0:
		v.add_child(_rich(notes[0], Kit.T_BODY, Kit.C_TEXT))
	for a in agents:
		v.add_child(_rich("•  " + a, Kit.T_BODY, Kit.C_DIM))
	for i in range(1, notes.size()):
		v.add_child(_rich(notes[i], Kit.T_BODY, Kit.C_DIM))


## A section's heading: the kit's spaced capitals, at a size read from across a room (the credits are read on a video too).
func _head(text: String) -> Label:
	var l := Kit.caps(text)
	l.add_theme_font_size_override("font_size", Kit.T_BODY)
	l.add_theme_color_override("font_color", Kit.ink(Kit.C_ACCENT))
	return l


func _sources(box: VBoxContainer, sections: Array, count: int) -> void:
	var v := Kit.vbox(Kit.GAP)
	box.add_child(v)
	reveal.append(v)
	v.add_child(_head(tr("The sources behind every number") + " · " + str(count)))
	v.add_child(Kit.lbl(tr("Every value, map, photo and model that is not ours comes from somewhere real. Open a section to see where."), Kit.T_LEAD, Kit.C_DIM, Kit.FONT_R, true))
	for sec in sections:
		var head := Kit.btn("▸  %s   ·   %d" % [sec.title, sec.entries.size()], func(): pass, Kit.T_BODY)
		head.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(head)
		var body := Kit.vbox(6)
		body.visible = false
		v.add_child(body)
		for e in sec.entries:
			body.add_child(_rich("[b]%s[/b]   %s" % [e.id, _links(_esc(e.text))], Kit.T_BODY, Kit.C_TEXT, false))
		var title: String = sec.title
		var n: int = sec.entries.size()
		head.pressed.connect(func():
			body.visible = not body.visible
			head.text = ("▾  " if body.visible else "▸  ") + "%s   ·   %d" % [title, n])


func _ending(box: VBoxContainer) -> void:
	var v := Kit.vbox(6)
	box.add_child(v)
	reveal.append(v)
	v.add_child(Kit.spacer(Kit.GAP))
	var arc := Horizon.new()
	arc.custom_minimum_size = Vector2(0, 30)
	arc.sun_at = 0.6
	v.add_child(arc)
	var thanks := Kit.lbl(tr("Thank you for flying with us."), Kit.T_STAT, Kit.C_TEXT, Kit.FONT_T)
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(thanks)
	var fine := Kit.lbl(tr("Farpoint HORIZON uses NASA's open data. NASA does not endorse it."), Kit.T_BODY, Kit.C_DIM)
	fine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(fine)
	v.add_child(Kit.spacer(Kit.GAP))


# ===================================================================================== HELPERS
## A wrapped rich-text paragraph whose links open in the browser.
func _rich(t: String, size := Kit.T_BODY, col := Kit.C_TEXT, escape := true) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.selection_enabled = true
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", size)
	rt.add_theme_font_size_override("bold_font_size", size)
	rt.add_theme_color_override("default_color", col)
	rt.text = _links(_esc(t)) if escape else t
	rt.meta_clicked.connect(func(meta): OS.shell_open(str(meta)))
	return rt


static func _initials(name: String) -> String:
	var out := ""
	for w in name.split(" ", false):
		out += w.substr(0, 1)
	return out.substr(0, 2).to_upper()


static func _cap(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1)


static func _spaced(font: Font, px: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = font
	f.spacing_glyph = px
	return f


## BBCode-safe: a literal "[" in a source would start a tag.
static func _esc(t: String) -> String:
	return t.replace("[", "[lb]")


## Every http(s) address becomes a link in the accent colour.
static func _links(t: String) -> String:
	var rx := RegEx.new()
	rx.compile(r"https?://[^\s)\]]+[^\s)\].,;]")
	var out := ""
	var at := 0
	var col := Kit.C_ACCENT.to_html(false)
	for m in rx.search_all(t):
		out += t.substr(at, m.get_start() - at)
		out += "[url=%s][color=#%s]%s[/color][/url]" % [m.get_string(), col, m.get_string()]
		at = m.get_end()
	return out + t.substr(at)
