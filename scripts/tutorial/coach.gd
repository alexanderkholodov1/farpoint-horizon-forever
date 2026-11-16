extends CanvasLayer
## The first mission, guided (C9, issue #14): a crew member rides along over the real game and, on each screen and
## design step, says what it is about in plain words and lights the option or button to press next. It changes
## nothing in the game: it only reads which screen is showing and points. The tips are data (data/tutorial.json).
## Started from the menu (start()); it leaves on its own back at the menu, or when the player ends it.
##   const Coach := preload("res://scripts/tutorial/coach.gd")
##   Coach.start(main)

const TIPS_PATH := "res://data/tutorial.json"
const Kit := preload("res://scripts/ui/kit.gd")
const Bots := preload("res://scripts/crew/bots.gd")
const UiSound := preload("res://scripts/ui/ui_sound.gd")

var main
var tips := {}                 ## ctx -> tip
var ctx := ""
var dismissed := {}            ## ctx -> true, tips the player closed
var card: PanelContainer
var rings: Array = []          ## Highlight panels, one per lit target.
var lit_targets: Array = []    ## The texts of what is lit, to find it again when its list is rebuilt.
var lit_col := Color.WHITE
var relight_t := 0.0
var lit: Array = []            ## The controls they follow.
var t := 0.0
var last_q := -1               ## The design question the targets were last lit for.


## Opens the guided first mission: the player holds every station, the Moon's south pole is chosen, design begins.
static func start(m) -> void:
	var c = load("res://scripts/tutorial/coach.gd").new()
	c.main = m
	c.name = "Coach"
	m.add_child(c)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TIPS_PATH))
	GameState.start_solo()
	GameState.start_mission(String(data.get("scenario", "moon_south_pole")))
	m.go("design", {"step": 0})


func _ready() -> void:
	layer = 5
	process_priority = 100   # after the screen has moved its lists this frame, so the frames never lag behind a scroll
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TIPS_PATH))
	for tip in data.get("tips", []):
		tips[tip.ctx] = tip


func _process(delta: float) -> void:
	t += delta
	if main == null or not is_instance_valid(main):
		return
	var id: String = main.screen_id
	if id == "menu":
		queue_free()
		return
	var now := id
	if id == "design" and main.screen and "step_idx" in main.screen:
		now = "design:%d" % main.screen.step_idx
	if now != ctx:
		ctx = now
		_show()
	# a step of the design may hold more than one question: light the tip's targets again on each new one
	var sub: int = int(main.screen.get("q")) if main.screen and id == "design" and main.screen.get("q") != null else -1
	if sub != last_q:
		last_q = sub
		if tips.has(ctx) and not dismissed.has(ctx) and card and is_instance_valid(card):
			_relight()
	_follow()


# ===================================================================================== THE CARD
func _show() -> void:
	if card and is_instance_valid(card):
		card.queue_free()
	_clear_rings()
	if not tips.has(ctx) or dismissed.has(ctx):
		return
	var tip: Dictionary = tips[ctx]
	var R: Dictionary = GameData.ROLES.get(tip.who, {})
	var col: Color = R.get("color", Kit.C_ACCENT)
	card = Kit.panel_box(Kit.PAD)
	card.add_theme_stylebox_override("panel", Kit.flat(Kit.C_BG, col, 14, 2, Kit.PAD, Kit.PAD * 0.8))
	card.material = Kit.frost()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	card.tree_exited.connect(root.queue_free)
	var in_design := ctx.begins_with("design") or ctx == "builder"
	if in_design:
		# over the 3D view, between the design screen's option list (left) and its board (right), below the craft's name and mass
		Kit.place(card, 0.5, 0, 0.5, 0, -285, 124, 375, 124)
	else:
		# in flight the centre and the bottom belong to the flight panel's own call-outs: the free top-right corner
		Kit.place(card, 1, 0, 1, 0, -Kit.MARGIN - 360, 90, -Kit.MARGIN, 90)
	root.add_child(card)
	var v := Kit.vbox(Kit.GAP * 0.6)
	card.add_child(v)
	var head := Kit.hbox(Kit.GAP)
	v.add_child(head)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", Kit.flat(col, Color(0, 0, 0, 0), 18, 0, 0, 0))
	badge.custom_minimum_size = Vector2(36, 36)
	var ini := Kit.lbl(String(Bots.NAMES.get(tip.who, "?")).substr(0, 1), Kit.T_BODY, Color(0.03, 0.06, 0.13), Kit.FONT_T)
	ini.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ini.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(ini)
	head.add_child(badge)
	var hv := Kit.vbox(0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	hv.add_child(Kit.lbl(tr(tip.title), Kit.T_LEAD, Kit.C_TEXT, Kit.FONT_B))
	hv.add_child(Kit.lbl("%s · %s" % [Bots.NAMES.get(tip.who, ""), R.get("name", "")], Kit.T_SMALL, col, Kit.FONT_B))
	head.add_child(Kit.btn(tr("Got it"), func(): dismissed[ctx] = true; _show(), Kit.T_SMALL))
	v.add_child(Kit.lbl(tr(tip.text), Kit.T_BODY, Kit.C_TEXT, Kit.FONT_R, true))
	var end := Kit.btn(tr("End the guided mission"), func(): queue_free(), Kit.T_SMALL)
	end.flat = true
	end.size_flags_horizontal = Control.SIZE_SHRINK_END
	end.add_theme_color_override("font_color", Kit.C_DIM)
	v.add_child(end)
	# it slides down into place
	card.modulate.a = 0.0
	card.position.y -= 16
	var tw := card.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.35)
	tw.tween_property(card, "position:y", card.position.y + 16, 0.35)
	UiSound.play("notify")
	if not in_design:
		# it steps aside on its own, so it never sits over the flight
		var shown := ctx
		get_tree().create_timer(12.0).timeout.connect(func():
			if ctx == shown and card and is_instance_valid(card):
				card.create_tween().tween_property(card, "modulate:a", 0.0, 0.8).finished.connect(card.queue_free))
	# light the targets (a frame later, once the screen has laid itself out)
	await get_tree().process_frame
	await get_tree().process_frame
	_light(tip.get("targets", []), col)


# ===================================================================================== THE LIGHTS
func _relight() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if tips.has(ctx):
		_light(tips[ctx].get("targets", []), Kit.C_GOLD)


func _light(targets: Array, col: Color) -> void:
	_clear_rings()
	lit_targets = targets
	lit_col = col
	for txt in targets:
		var c := _find(tr(txt))
		if c == null:
			continue
		var sc := _scroll_of(c)
		if sc:
			sc.ensure_control_visible(c)
		var ring := Panel.new()
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := Kit.flat(Color(Kit.C_GOLD.r, Kit.C_GOLD.g, Kit.C_GOLD.b, 0.08), Kit.C_GOLD, 10, 3, 0, 0)
		sb.shadow_color = Color(Kit.C_GOLD.r, Kit.C_GOLD.g, Kit.C_GOLD.b, 0.45)
		sb.shadow_size = 10
		ring.add_theme_stylebox_override("panel", sb)
		add_child(ring)
		rings.append(ring)
		lit.append(c)


func _follow() -> void:
	# the screen rebuilt its list (a choice, "Show all"): find the lit options again, so a frame never stays behind
	# on a freed or moved control
	relight_t -= get_process_delta_time()
	for c in lit:
		if not is_instance_valid(c) and relight_t <= 0.0:
			relight_t = 0.3
			_light(lit_targets, lit_col)
			break
	for i in rings.size():
		var ring: Panel = rings[i]
		var c: Control = lit[i]
		if not is_instance_valid(c) or not c.is_visible_in_tree():
			ring.visible = false
			continue
		var r := c.get_global_rect().grow(5)
		var sc := _scroll_of(c)
		# a frame is shown only while its option is whole inside its list: it never floats over the panel's edge
		ring.visible = sc == null or sc.get_global_rect().grow(6).encloses(r)
		ring.position = r.position
		ring.size = r.size
		ring.modulate.a = 0.75 + 0.25 * sin(t * 5.0)


func _clear_rings() -> void:
	for r in rings:
		if is_instance_valid(r):
			r.queue_free()
	rings.clear()
	lit.clear()


## The visible button whose text is `txt`, or the option card holding a label with it (cards show "○ Name").
func _find(txt: String) -> Control:
	var root: Control = main.root_ui
	for n in root.find_children("*", "Button", true, false):
		var b := n as Button
		if b.is_visible_in_tree() and b.text.strip_edges() == txt:
			return b
	for n in root.find_children("*", "Label", true, false):
		var l := n as Label
		if not l.is_visible_in_tree():
			continue
		var s := l.text.trim_prefix("○ ").trim_prefix("● ").strip_edges()
		if s == txt:
			var p: Node = l
			while p and not (p is PanelContainer):
				p = p.get_parent()
			return p if p else l
	return null


func _scroll_of(c: Control) -> ScrollContainer:
	var p := c.get_parent()
	while p:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null
