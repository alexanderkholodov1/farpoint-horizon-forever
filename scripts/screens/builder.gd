extends "res://scripts/screens/screen.gd"
## The rocket builder (issue #6), guided: the rocket is built one choice at a time, from the ground up, and it can
## never grow without end. Each step shows only the few parts that fit there (the same width as the engines chosen
## first), as large tiles with a drawing, a name and two facts; the rest is told when a tile is pointed at.
##   engines -> fuel tank -> an upper stage or none (its interstage comes with it) -> its tank -> boosters or none
##   -> the fairing that closes it.
## Top: the steps, the current one lit; a done step can be clicked to choose again. Centre: the rocket in 3D at real
## proportions on the pad; a new part drops onto the stack and snaps. Right: "Will it fly?", three answers (lifts
## off, reaches the orbit, carries the craft) with the numbers behind them when pointed at.
## "Use this rocket" makes it the mission's launcher (RocketDesign.CUSTOM) and goes back to the launcher step.
## args: {"back_step": index of GameData.STEPS to return to}.

const Space := preload("res://scripts/world/space_builder.gd")
const RocketDesign := preload("res://scripts/craft/rocket_design.gd")
const PartIcon := preload("res://scripts/ui/part_icon.gd")

const SCALE := 0.088          ## Metres to world units, as the launch screen draws its rockets.
const NONE := "none"          ## A step answered with "no" (no upper stage, no boosters).
## The steps in order: [slot, short name for the top row, the question, what it is about].
const STEPS := [
	["e1", "Engines", "Pick the engines", "They lift everything off the ground. Bigger engines make a bigger rocket."],
	["t1", "Fuel tank", "Pick the fuel tank", "More fuel is more speed, and more weight to lift."],
	["e2", "Upper stage", "Add an upper stage?", "A second, lighter stage lights up high and takes your craft to orbit. Almost every real rocket has one."],
	["t2", "Its tank", "Pick the upper stage's tank", "Up there every kilo counts: a small tank goes a long way."],
	["bo", "Boosters", "Strap on boosters?", "Two solid rockets on the sides: an enormous push for the first two minutes."],
	["fa", "Fairing", "Close it with the fairing", "The shell that protects your craft through the air. It opens above the atmosphere."],
]

var design                    ## The rocket being built (RocketDesign); always made from `slots`.
var slots := {"e1": "", "t1": "", "e2": "", "t2": "", "bo": "", "fa": ""}
var at := 0                   ## Index in _order() of the step being chosen; _order().size() when all are done.
var back_step := 0
var model: Node3D
var snap_node: Node3D         ## The part that just snapped, animated in process().
var snap_t := 1.0
var left_box: VBoxContainer
var right_box: VBoxContainer
var steps_row: HBoxContainer
var info_title: Label
var info_body: Label
var fly_btn: Button
var picks: Array = []          ## What each tile on screen does, in order (the number keys choose them).


var left_panel: Control       ## On a phone the three columns are measured every frame (issue #93).
var right_panel: Control
var hint_panel: Control
var bar_panel: Control

func enter(args: Dictionary) -> void:
	back_step = args.get("back_step", 0)
	design = RocketDesign.current.copy() if RocketDesign.current != null else RocketDesign.new()
	world.clear_stage()
	var env: Environment = world.world_env.environment
	Space.apply_day(env)
	world.cam.far = 6000.0
	env.ambient_light_energy = 0.6
	world.sun.rotation_degrees = Vector3(-42, -35, 0)
	world.stage.add_child(Space.make_pad())
	world.cam_free = true
	world.cam_auto = false
	world.cam_yaw = 0.7
	world.cam_pitch = -0.12
	_build_ui()
	_rebuild(false)


# ===================================================================================== THE STEPS
## The steps that apply now: the upper stage's tank only with an upper stage, boosters only where a pair exists
## for this width.
func _order() -> Array:
	var out: Array = []
	for s in STEPS:
		if s[0] == "t2" and (slots.e2 == "" or slots.e2 == NONE):
			continue
		if s[0] == "bo" and slots.e1 != "" and _options("bo").size() < 2:
			continue
		out.append(s)
	return out


func _family() -> float:
	return float(RocketDesign.part(slots.e1).family) if slots.e1 != "" else 0.0


## The parts that fit a step (ids; NONE where the step may be skipped).
func _options(slot: String) -> Array:
	var want := {"e1": "engine", "t1": "tank", "e2": "engine", "t2": "tank", "bo": "booster", "fa": "fairing"}
	var out: Array = []
	var parts: Dictionary = RocketDesign.data().parts
	for id in parts:
		var P: Dictionary = parts[id]
		if P.category != want[slot]:
			continue
		if slot != "e1" and float(P.family) != _family():
			continue
		if P.category == "engine" and bool(P.get("vacuum_only", false)) != (slot == "e2"):
			continue
		out.append(id)
	if slot == "e2" or slot == "bo":
		out.append(NONE)
	return out


## Reads the slots from a design's stack (a ready rocket, the rocket of an earlier visit).
func _read_slots() -> void:
	for k in slots:
		slots[k] = ""
	var upper := false
	for id in design.stack:
		match RocketDesign.part(id).category:
			"engine":
				slots["e2" if upper else "e1"] = id
			"tank":
				slots["t2" if upper else "t1"] = id
			"decoupler":
				upper = true
			"fairing":
				slots.fa = id
	if slots.fa != "":   # a closed rocket answered every question
		if slots.e2 == "":
			slots.e2 = NONE
		slots.bo = design.boosters if design.boosters != "" else NONE
	elif design.boosters != "":
		slots.bo = design.boosters
	at = _first_open()


## Writes the slots into the design: the stack from the ground up, the interstage coming with the upper stage.
func _write_design() -> void:
	design.stack = []
	for k in ["e1", "t1"]:
		if slots[k] != "":
			design.stack.append(slots[k])
	if slots.e2 != "" and slots.e2 != NONE:
		for id in RocketDesign.data().parts:
			var P: Dictionary = RocketDesign.part(id)
			if P.category == "decoupler" and float(P.family) == _family():
				design.stack.append(id)
		design.stack.append(slots.e2)
		if slots.t2 != "":
			design.stack.append(slots.t2)
	if slots.fa != "":
		design.stack.append(slots.fa)
	design.boosters = slots.bo if slots.bo != NONE else ""


func _first_open() -> int:
	var order := _order()
	for i in order.size():
		if slots[order[i][0]] == "":
			return i
	return order.size()


func _complete() -> bool:
	return _first_open() == _order().size()


# ===================================================================================== ACTIONS
## The player chose a part (or NONE) for a step.
func _pick(slot: String, id: String) -> void:
	if slot == "e1" and slots.e1 != id:
		for k in slots:   # another width: nothing chosen before fits it
			slots[k] = ""
	if slot == "e2" and id == NONE:
		slots.t2 = ""
	slots[slot] = id
	Kit.UiSound.play("snap", 0.08)
	_write_design()
	at = _first_open()
	_rebuild(id != NONE and slot != "bo", false)


## Puts a part where it belongs (used by the scripted walkthroughs).
func _add(id: String) -> void:
	var cat: String = RocketDesign.part(id).category
	var slot := ""
	match cat:
		"engine":
			slot = "e2" if RocketDesign.part(id).get("vacuum_only", false) else "e1"
		"tank":
			slot = "t1" if slots.t1 == "" else "t2"
		"booster":
			slot = "bo"
		"fairing":
			slot = "fa"
	if slot != "":
		_pick(slot, id)


func _preset(pid: String) -> void:
	design = RocketDesign.from_preset(pid)
	Kit.UiSound.play("snap", 0.08)
	_rebuild(false)


func _use() -> void:
	if not _complete():
		toast(tr("Finish the steps first: %s.") % tr(_order()[at][2]), Kit.C_WARN)
		return
	RocketDesign.current = design.copy()
	mission.launcher = RocketDesign.CUSTOM
	go("design", {"step": back_step})


## The keyboard: 1 to 9 choose a part, Enter flies the rocket, Backspace goes back to the design.
func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = e.physical_keycode
	if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < picks.size():
		picks[k - KEY_1].call()
	elif k == KEY_ENTER or k == KEY_KP_ENTER:
		_use()
	elif k == KEY_BACKSPACE:
		go("design", {"step": back_step})
	else:
		return
	get_viewport().set_input_as_handled()


# ===================================================================================== UI
func _build_ui() -> void:
	clear()
	# ---------- top: the steps
	var sp := Kit.panel_box(8)
	Kit.place(sp, 0.5, 0, 0.5, 0, 0, 6 if Kit.compact else 14, 0, 6 if Kit.compact else 14)
	sp.grow_horizontal = Control.GROW_DIRECTION_BOTH   # as wide as its steps, centred
	add_child(sp)
	steps_row = Kit.hbox(6)
	sp.add_child(steps_row)
	# ---------- left: the step's question and its few parts
	var lp := Kit.panel_box(Kit.PAD)
	Kit.place(lp, 0, 0, 0, 1, Kit.MARGIN, 64 if Kit.compact else 84, 362 if Kit.compact else 476, -Kit.MARGIN)
	add_child(lp)
	left_panel = lp
	left_box = Kit.vbox(Kit.GAP)
	if Kit.compact:   # on a phone the step's parts scroll inside their panel instead of running off the screen
		var lsc := ScrollContainer.new()
		lsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lsc.add_child(left_box)
		lp.add_child(lsc)
	else:
		lp.add_child(left_box)
	# ---------- right: will it fly?
	var rp := Kit.panel_box(Kit.PAD)
	Kit.place(rp, 1, 0, 1, 0, -306 if Kit.compact else -364, 64 if Kit.compact else 84, -Kit.MARGIN, 64 if Kit.compact else 84)   # grows to its content
	add_child(rp)
	right_panel = rp
	right_box = Kit.vbox(Kit.GAP)
	rp.add_child(right_box)
	# ---------- bottom centre: what the pointed thing is, and the actions
	var hb: Array = Kit.hint_box()
	var ip: Control = hb[0]
	if Kit.compact:
		Kit.place(ip, 0, 1, 1, 1, 400, -70, -314, -70)
		ip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		Kit.place(ip, 0, 1, 1, 1, 496, -214, -388, -110)
	add_child(ip)
	hint_panel = ip
	info_body = hb[1]
	info_body.add_theme_font_size_override("font_size", Kit.T_BODY)
	var bp := Kit.panel_box(6 if Kit.compact else 10)
	if Kit.compact:   # the middle column of a phone, between the question and the board
		Kit.place(bp, 0, 1, 1, 1, 400, -62, -314, -Kit.MARGIN)
	else:
		Kit.place(bp, 0, 1, 1, 1, 496, -96, -388, -Kit.MARGIN)
	add_child(bp)
	bar_panel = bp
	var bar := Kit.hbox(10)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bp.add_child(bar)
	var back := Kit.btn(tr("◀") if Kit.compact else tr("◀ Back"), func(): go("design", {"step": back_step}), Kit.T_BODY, 48 if Kit.compact else 150)
	back.custom_minimum_size.y = Kit.BTN_H + 8
	bar.add_child(back)
	fly_btn = Kit.btn(tr("Use this rocket ▶"), _use, Kit.T_ACTION, 200 if Kit.compact else 280)
	fly_btn.custom_minimum_size.y = Kit.BTN_H + 8
	bar.add_child(fly_btn)


func _say(title: String, text: String) -> void:
	info_body.text = (title + "\n" if title != "" else "") + text


func _fill_steps() -> void:
	for c in steps_row.get_children():
		c.queue_free()
	var order := _order()
	for i in order.size():
		var done: bool = slots[order[i][0]] != ""
		var b := Kit.choice(("✓ " if done and i != at else "%d  " % (i + 1)) + tr(order[i][1]), i == at, func():
			at = i
			_fill_left()
			_fill_steps())
		b.disabled = not done and i != at   # a step opens when the ones before it are answered
		if i == at:
			Kit.accent_btn(b, Kit.C_GOLD)
		steps_row.add_child(b)


func _fill_left() -> void:
	picks = []
	for c in left_box.get_children():
		c.queue_free()
	var order := _order()
	if at >= order.size():
		left_box.add_child(Kit.caps(tr("Your rocket")))
		left_box.add_child(Kit.lbl(tr("Ready on the pad"), Kit.T_STAT, Kit.C_GOLD, Kit.FONT_T, true))
		left_box.add_child(Kit.lbl(tr("Drag to look at it from every side, then fly it. Click a part to change it."), Kit.T_BODY, Kit.C_DIM, Kit.FONT_R, true))
		for i in order.size():   # what it is made of, from the ground up: each part opens its step again
			var sl: String = order[i][0]
			var row := _tile(sl, slots[sl], true)
			row.gui_input.connect(func(e: InputEvent):
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
					at = i
					_fill_left()
					_fill_steps())
			left_box.add_child(row)
		_say("", tr("Point at a part or an answer to know more."))
	else:
		var S: Array = order[at]
		left_box.add_child(Kit.caps(tr("Step %d of %d") % [at + 1, order.size()]))
		left_box.add_child(Kit.lbl(tr(S[2]), Kit.T_STAT, Kit.C_GOLD, Kit.FONT_T, true))
		left_box.add_child(Kit.lbl(tr(S[3]), Kit.T_BODY, Kit.C_DIM, Kit.FONT_R, true))
		for id in _options(S[0]):
			left_box.add_child(_tile(S[0], id))
		_say("", tr("Point at a part to know more. Click it to put it on the rocket."))
	# a ready rocket, for who would rather start from one
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_box.add_child(gap)
	left_box.add_child(Kit.rule())
	left_box.add_child(Kit.caps(tr("Or take a ready rocket")))
	var presets := HFlowContainer.new()
	presets.add_theme_constant_override("h_separation", 6)
	presets.add_theme_constant_override("v_separation", 6)
	left_box.add_child(presets)
	for pid in ["light", "medium", "heavy"]:
		var p: Dictionary = RocketDesign.data().presets[pid]
		var b := Kit.btn(tr(p.name), func(): _preset(pid), Kit.T_SMALL)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		presets.add_child(b)


## One part to choose: its drawing, its name and two facts. Pointing at it tells the rest.
func _tile(slot: String, id: String, summary := false) -> Control:
	var chosen: bool = slots[slot] == id and not summary
	var pc := PanelContainer.new()
	var sb := Kit.flat(Kit.C_CARD_SEL if chosen else Kit.C_CARD, Kit.C_GOLD if chosen else Kit.C_LINE, 12, 2 if chosen else 1, 12, 12)
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var h := Kit.hbox(12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(h)
	var icon := PartIcon.new()
	if summary:
		icon.small = true
	icon.kind = "none" if id == NONE else ("upper" if slot == "e2" else str(RocketDesign.part(id).category))
	h.add_child(icon)
	var v := Kit.vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	var title := ""
	var more := ""
	var chips := Kit.hbox(6)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if id == NONE:
		title = tr("No upper stage") if slot == "e2" else tr("No boosters")
		more = tr("Simpler and cheaper, but one stage alone rarely reaches orbit.") if slot == "e2" else tr("Nothing on the sides: lighter and cheaper.")
		chips.add_child(Kit.chip(Kit.money(0.0), Kit.C_GOLD))
	else:
		var P: Dictionary = RocketDesign.part(id)
		title = tr(P.name)
		more = tr(P.desc) + "\n" + _part_line(P) + "  ·  " + tr("A real part: its sources are in the Credits")
		chips.add_child(Kit.chip(Kit.money(P.cost_musd * float(P.get("count", 1) if P.category == "booster" else 1)), Kit.C_GOLD))
		chips.add_child(Kit.chip(_fact(P)))
	v.add_child(Kit.lbl(title, Kit.T_BODY if summary else Kit.T_LEAD, Kit.C_TEXT, Kit.FONT_B, true))
	if summary:
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		chips.queue_free()
	else:
		v.add_child(chips)
	if not summary:
		picks.append(func(): _pick(slot, id))
		pc.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_pick(slot, id))
	pc.mouse_entered.connect(func():
		sb.border_color = Kit.C_GOLD
		_say(title, more))
	pc.mouse_exited.connect(func(): sb.border_color = Kit.C_GOLD if chosen else Kit.C_LINE)
	return pc


## The one fact that matters most about a part, for its chip.
func _fact(P: Dictionary) -> String:
	if P.has("thrust_sl_kn"):
		return tr("%s kN of push") % _num(P.thrust_sl_kn * float(P.get("count", 1) if P.category == "booster" else 1))
	if P.has("thrust_vac_kn"):
		return tr("%s kN of push") % _num(P.thrust_vac_kn)
	if P.has("propellant_kg"):
		return tr("%s of fuel") % Kit.kg(P.propellant_kg)
	return "%.1f m" % P.family


func _fill_right() -> void:
	for c in right_box.get_children():
		c.queue_free()
	var r: Dictionary = mission.compute()
	var craft_kg: float = r.mass_total
	var O: Dictionary = GameData.ORBITS[mission.orbit]
	right_box.add_child(Kit.caps(tr("Will it fly?")))
	if not _complete():
		for q in [tr("Lifts off"), tr("Reaches %s") % O.short, tr("Carries your craft")]:
			right_box.add_child(_answer(q, "", 0, tr("Finish the rocket to know.")))
	else:
		var cap: float = design.capacity_kg(mission.orbit)
		var perf: Dictionary = design.performance(craft_kg)
		var twr: float = design.liftoff_twr(craft_kg)
		var target: float = RocketDesign.data().targets[mission.orbit]
		right_box.add_child(_answer(tr("Lifts off"), tr("pushes %.2f× its weight") % twr, 1 if twr >= 1.15 else (0 if twr >= 1.0 else -1),
			tr("Thrust against weight at liftoff: above 1 it rises; real rockets leave the pad at 1.2 to 1.5.")))
		right_box.add_child(_answer(tr("Reaches %s") % O.short, tr("%.1f of %.1f km/s") % [perf.dv / 1000.0, target / 1000.0], 1 if perf.dv >= target else -1,
			tr("The speed the rocket can gain with your craft on top, against the speed this orbit asks for (air and gravity losses included).")))
		right_box.add_child(_answer(tr("Carries your craft"), tr("up to %s · yours %s") % [Kit.kg(cap), Kit.kg(craft_kg)], 1 if cap >= craft_kg and cap > 0.0 else -1,
			tr("The heaviest craft this rocket can take to this orbit, against the craft you designed.")))
	var facts := Kit.hbox(6)
	right_box.add_child(facts)
	facts.add_child(Kit.chip(Kit.money(design.total_cost()), Kit.C_GOLD))
	if not design.stack.is_empty():
		facts.add_child(Kit.chip(tr("%.0f m tall") % design.height_m()))
		facts.add_child(Kit.chip(Kit.kg(design.mass_kg(craft_kg))))
	var ready: bool = _complete()
	if ready:
		Kit.accent_btn(fly_btn, Kit.C_GOLD)
	else:
		for k in ["normal", "hover", "pressed"]:
			fly_btn.remove_theme_stylebox_override(k)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			fly_btn.remove_theme_color_override(k)


## One answer of "Will it fly?": a mark, the question, the short number. state: 1 yes, 0 barely, -1 no.
func _answer(question: String, value: String, state: int, explain: String) -> Control:
	var col: Color = Kit.C_DIM if value == "" else (Kit.C_OK if state > 0 else (Kit.C_WARN if state == 0 else Kit.C_BAD))
	var pc := Kit.tile(col, 12, 10)
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	var h := Kit.hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(h)
	h.add_child(Kit.lbl("○" if value == "" else ("✓" if state > 0 else ("!" if state == 0 else "✗")), Kit.T_STAT, col, Kit.FONT_T))
	var v := Kit.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(Kit.lbl(question, Kit.T_LEAD, Kit.C_TEXT, Kit.FONT_B))
	if value != "":
		v.add_child(Kit.lbl(value, Kit.T_SMALL, col, Kit.FONT_R))
	pc.mouse_entered.connect(func(): _say(question, explain))
	return pc


func _part_line(P: Dictionary) -> String:
	var each := tr(" each") if P.category == "booster" else ""
	var bits: Array = [Kit.kg(P.dry_kg + P.get("propellant_kg", 0.0)) + each]
	if P.has("thrust_sl_kn"):
		bits.append("%s kN%s" % [_num(P.thrust_sl_kn), each])
	elif P.has("thrust_vac_kn"):
		bits.append(tr("%s kN in vacuum") % _num(P.thrust_vac_kn))
	if P.has("isp_vac_s"):
		bits.append("Isp %d s" % int(P.isp_vac_s))
	bits.append("%.1f m" % P.family)
	return " · ".join(bits)


func _sources_line(P: Dictionary) -> String:
	var s := tr("Sources: ") + ", ".join(P.sources)
	if not P.get("estimate", []).is_empty():
		s += ". " + tr("Our estimate: ") + ", ".join(P.estimate).replace("_musd", "").replace("_kg", "").replace("_", " ")
	return s


static func _num(x: float) -> String:
	var s := str(int(round(x)))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += " "
		out += s[i]
	return out


# ===================================================================================== 3D
## Draws the rocket again from `design` (and reads the steps from it). snap: the top part drops in and settles.
func _rebuild(snap: bool, reread := true) -> void:
	if reread:   # the design came from outside (a ready rocket): the steps follow it
		_read_slots()
	if model and is_instance_valid(model):
		model.queue_free()
	model = Node3D.new()
	model.position = Vector3(0, Space.PAD_TOP, 0)
	world.stage.add_child(model)
	var assembled: Node3D = design.build_model()
	assembled.scale = Vector3.ONE * SCALE
	model.add_child(assembled)
	var h: float = maxf(design.height_m() * SCALE, 1.0)
	world.cam_target = Vector3(0, 0.2 + h * 0.5, 0)
	world.cam_dist_goal = clampf(h * 1.25, 2.5, 12.0)
	snap_node = null
	if snap and not design.stack.is_empty():
		var top_stage: Node3D = assembled.get_child(design.stages().size() - 1)
		if top_stage.get_child_count() > 0:
			snap_node = top_stage.get_child(top_stage.get_child_count() - 1)
			snap_t = 0.0
	_fill_steps()
	_fill_left()
	_fill_right()


func process(delta: float) -> void:
	if Kit.compact and is_instance_valid(bar_panel):   # on a phone the middle column is measured (issue #93)
		Kit.fit_middle(left_panel, right_panel, hint_panel, bar_panel)
	if snap_node and is_instance_valid(snap_node) and snap_t < 1.0:
		# the new part drops from above and settles with a small spring (about 0.45 s)
		snap_t = minf(1.0, snap_t + delta / 0.45)
		var e := 1.0 - pow(1.0 - snap_t, 3.0)
		var bounce := sin(snap_t * PI * 2.5) * (1.0 - snap_t) * 0.12
		snap_node.set_meta("rest_y", snap_node.get_meta("rest_y", snap_node.position.y))
		var rest: float = snap_node.get_meta("rest_y")
		snap_node.position.y = rest + (1.0 - e) * 25.0 + bounce * 10.0
