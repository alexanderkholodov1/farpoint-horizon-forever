extends "res://scripts/screens/screen.gd"
## Design (CML 2-4), guided as the rocket builder is: the craft is designed one question at a time. Each question
## shows only the options that make sense here, as tiles with a drawing, a name and two facts; the rest is told when
## a tile is pointed at. The best fit carries a star, so a player who is lost can follow the stars.
##   Mission: its extra goals, where it flies · Craft: its body, its instruments · Power: panels, battery · Systems: antenna, pointing,
##   engine · Rocket: the launcher (or build your own) · Launch: the review, years, extras, LAUNCH!
## Top: the six stages, the current one lit; a stage already reached can be clicked. Centre: the craft in 3D.
## Right: the mission board as seven short answers (budget, mass, power, battery, data, fuel, science).
## The questions map onto the eight steps of GameData.STEPS (who decides each, what the crew's bots choose), which
## stay as they were: args {"step": index of GameData.STEPS} opens that step's first question, as show_step(i) does.

const RocketDesign := preload("res://scripts/craft/rocket_design.gd")
const Bots := preload("res://scripts/crew/bots.gd")
const PartIcon := preload("res://scripts/ui/part_icon.gd")
const Progress := preload("res://scripts/core/progress.gd")
const Objectives := preload("res://scripts/flight/objectives.gd")
const Glossary := preload("res://scripts/ui/glossary.gd")

const STAGES := ["Mission", "Craft", "Power", "Systems", "Rocket", "Launch"]
## The questions in order: [id, the GameData.STEPS id it belongs to, stage, the question, what it is about].
const QUESTIONS := [
	["goals", "orbita", 0, "Which extra goals will you go for?", "Each one you meet adds points and brings a photo home. Missing one never takes anything away."],
	["orbit", "orbita", 0, "Where will it fly?", "The orbit decides what your craft sees, how long it talks to Earth and how hard it is to get there."],
	["bus", "plataforma", 1, "How big is your craft?", "The body holds everything. Bigger carries more instruments, and costs and weighs more."],
	["instruments", "instrumentos", 1, "What will it carry?", "The instruments do the science. Pick the ones that meet the goals, then continue."],
	["panels", "energia", 2, "Pick the solar panels", "They make the power for everything on board."],
	["battery", "energia", 2, "Pick the battery", "It keeps the craft alive in the shadow, where the panels make nothing."],
	["comms", "comunicaciones", 3, "Pick the antenna", "Every picture has to come home. A faster antenna sends more data each day."],
	["adcs", "control", 3, "How will it point?", "Sharp pictures need a steady aim."],
	["propulsion", "control", 3, "Pick its engine", "It moves the craft to its orbit and holds it there."],
	["launcher", "lanzador", 4, "Pick the rocket", "The farther the destination, the less a rocket can carry."],
	["review", "revision", 5, "Ready to launch?", "Fix what is red. Amber costs science but still flies."],
]
const YEARS := [1, 2, 3, 5, 7, 10]

static var _mission_id := 0     ## The mission the progress below belongs to.
static var _reached := 0        ## The furthest question reached in it.
static var _auto := {}          ## Questions whose answer the game chose (the player never picked one): they follow the craft.

var q := 0                      ## Index in QUESTIONS of the question shown.
var step_idx := 0               ## Index in GameData.STEPS of that question's step (the coach reads it).
var show_all := false           ## Instruments: also the ones of little use here.
var left_box: VBoxContainer
var board: VBoxContainer
var stages_row: HBoxContainer
var info_body: Label
var main_btn: Button
var back_btn: Button
var picks: Array = []             ## What each tile on screen does, in order (the number keys choose them).
var later: Array = []             ## Notices to show once the screen is drawn ([text, colour]): drawing clears the screen.
var last_problems := {}           ## The problems shown last time, by title (to tell what a new choice broke).


var left_panel: Control       ## On a phone the three columns are measured every frame (issue #93).
var board_panel: Control
var hint_panel: Control
var bar_panel: Control
var resources_panel: Control

func enter(args: Dictionary) -> void:
	GameState.room.changed.connect(_on_room_changed)
	if mission.get_instance_id() != _mission_id:
		_mission_id = mission.get_instance_id()
		_reached = 0
		_auto = {}
	show_step(args.get("step", 0))


func exit() -> void:
	if GameState.room.changed.is_connected(_on_room_changed):
		GameState.room.changed.disconnect(_on_room_changed)


## Somebody else changed the room (a teammate online, or the host's bots): draw the question again.
func _on_room_changed(by_me: bool) -> void:
	if not by_me and is_inside_tree():
		_show.call_deferred(q)


## Opens the first question of step `idx` of GameData.STEPS.
func show_step(idx: int) -> void:
	var id: String = GameData.STEPS[clampi(idx, 0, GameData.STEPS.size() - 1)].id
	for i in QUESTIONS.size():
		if QUESTIONS[i][1] == id:
			_show(i)
			return
	_show(0)


# ===================================================================================== THE SCREEN
## Draws the screen at question i.
func _show(i: int) -> void:
	q = clampi(i, _first_q(), QUESTIONS.size() - 1)
	var first_visit := q > _reached
	_reached = maxi(_reached, q)
	var Q: Array = QUESTIONS[q]
	if first_visit and GameState.room.can_edit(_step_of(Q[1]).role):
		_start_on_best(Q[0])
	if GameState.room.can_edit(_step_of(Q[1]).role):
		_follow_the_craft()
	for k in GameData.STEPS.size():
		if GameData.STEPS[k].id == Q[1]:
			step_idx = k
	GameState.room.enter_step(Q[1])   # the bot that holds this step's station decides now
	clear()
	picks = []
	if not world.stage or world.ship == null:
		world.stage_design()
	var r: Dictionary = mission.compute()
	_tell_new_problems(r, Q[0])
	var STEP: Dictionary = GameData.STEPS[step_idx]
	var room = GameState.room
	# ---------- top: the stages
	var sp := Kit.panel_box(8)
	Kit.place(sp, 0.5, 0, 0.5, 0, 0, 6 if Kit.compact else 14, 0, 6 if Kit.compact else 14)
	sp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(sp)
	stages_row = Kit.hbox(6)
	sp.add_child(stages_row)
	for s in STAGES.size():
		var first := _first_of(s)
		var b := Kit.choice(("✓ " if first < _reached and s != Q[2] else "%d  " % (s + 1)) + tr(STAGES[s]), s == Q[2], func(): _show(first))
		b.disabled = first > _reached
		if s == Q[2]:
			Kit.accent_btn(b, Kit.C_GOLD)
		stages_row.add_child(b)
	# ---------- left: the question and its options
	var lp := Kit.panel_box(Kit.PAD)
	Kit.place(lp, 0, 0, 0, 1, Kit.MARGIN, 64 if Kit.compact else 84, 362 if Kit.compact else 476, -Kit.MARGIN)
	add_child(lp)
	left_panel = lp
	var lv := Kit.vbox(Kit.GAP)
	lp.add_child(lv)
	lv.add_child(Kit.caps(GameData.SCENARIOS[mission.scenario].name + "  ·  " + Kit.kg(r.mass_total)))
	lv.add_child(Kit.lbl(tr(Q[3]), Kit.T_STAT, Kit.C_GOLD, Kit.FONT_T, true))
	lv.add_child(Kit.lbl(tr(Q[4]), Kit.T_BODY, Kit.C_DIM, Kit.FONT_R, true))
	var said: Dictionary = room.state.bot_lines.get(STEP.id, {})
	if room.is_bot(STEP.role) and STEP.id != "revision":
		if said.has("line"):
			lv.add_child(Kit.lbl(room.holder_name(STEP.role) + ": " + Bots.say(said.line), Kit.T_SMALL, Kit.C_TEXT, Kit.FONT_R, true))
	elif not room.can_edit(STEP.role):
		lv.add_child(Kit.lbl(tr("This is %s's station. You can watch their choices here.") % room.holder_name(STEP.role), Kit.T_SMALL, Kit.C_WARN, Kit.FONT_B, true))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(sc)
	left_box = Kit.vbox(8)
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(left_box)
	# ---------- right: the mission board
	var rp := Kit.panel_box(Kit.PAD)
	Kit.place(rp, 1, 0, 1, 0, -306 if Kit.compact else -364, 64 if Kit.compact else 84, -Kit.MARGIN, 64 if Kit.compact else 84)   # grows to its content
	rp.grow_horizontal = Control.GROW_DIRECTION_BEGIN     # to the left, never past the window's edge
	add_child(rp)
	board_panel = rp
	board = Kit.vbox(6)
	rp.add_child(board)
	# ---------- bottom centre: what the pointed thing is, and the actions
	var hb: Array = Kit.hint_box()
	var ip: Control = hb[0]
	if Kit.compact:
		Kit.place(ip, 0, 1, 1, 1, 400, -70, -314, -70)
	else:
		Kit.place(ip, 0, 1, 1, 1, 496, -110, -388, -110)
	ip.grow_vertical = Control.GROW_DIRECTION_BEGIN   # grows up with what it says, never under the buttons
	add_child(ip)
	hint_panel = ip
	info_body = hb[1]
	info_body.add_theme_font_size_override("font_size", Kit.T_BODY)
	_say("", tr("Point at an option to know more. Keys: 1 to 9 choose, Enter goes on, Backspace goes back."))
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
	var menu := Kit.btn(tr("Menu"), func(): go("menu"), Kit.T_BODY, 0 if Kit.compact else 100)
	menu.custom_minimum_size.y = Kit.BTN_H + 8
	bar.add_child(menu)
	var back := Kit.btn(tr("◀") if Kit.compact else tr("◀ Back"), func(): _show(q - 1), Kit.T_BODY, 48 if Kit.compact else 130)
	back.custom_minimum_size.y = Kit.BTN_H + 8
	back.disabled = q <= _first_q()
	back_btn = back
	bar.add_child(back)
	if Q[0] == "review":
		main_btn = Kit.accent_btn(Kit.btn(tr("LAUNCH!"), func(): main.launch(), Kit.T_ACTION, 0 if Kit.compact else 260), Kit.C_GOLD)
		main_btn.disabled = not GameState.can_launch(r)
		if main_btn.disabled:
			main_btn.modulate.a = 0.45
	else:
		main_btn = Kit.accent_btn(Kit.btn(tr("Continue ▶"), _next, Kit.T_ACTION, 0 if Kit.compact else 260), Kit.C_GOLD)
	main_btn.custom_minimum_size.y = Kit.BTN_H + 8
	bar.add_child(main_btn)
	_fill_question(Q[0], r)
	_fill_board(r)
	_fill_resources(r)
	for n in later:   # notices from this redraw's own changes, shown now that the screen is drawn
		toast(n[0], n[1], 3.5)
	later = []
	if not room.can_edit(STEP.role):
		left_box.modulate.a = 0.6
		for c in left_box.find_children("*", "Control", true, false):
			if c is Button:
				c.disabled = true
			elif c is PanelContainer:
				c.mouse_filter = Control.MOUSE_FILTER_IGNORE


## The first question: the extra goals when this mission offers any, else the orbit.
func _first_q() -> int:
	return 0 if not mission.extras_offered.is_empty() else 1


func _first_of(stage: int) -> int:
	for i in QUESTIONS.size():
		if QUESTIONS[i][2] == stage:
			return i
	return 0


## The step of GameData.STEPS with this id.
func _step_of(id: String) -> Dictionary:
	for k in GameData.STEPS.size():
		if GameData.STEPS[k].id == id:
			return GameData.STEPS[k]
	return GameData.STEPS[0]


## The index in QUESTIONS of the question with this id (-1 if none).
func _q_index(id: String) -> int:
	for i in QUESTIONS.size():
		if QUESTIONS[i][0] == id:
			return i
	return -1


## The best fit of a one-choice question for the craft as it is now: the cheapest option that is enough for its own
## need and keeps the craft within its body's mass limit (a best fit must never be what blocks the launch). When no
## option does both, the cheapest that is enough; "" when nothing is enough, or for other questions.
func _best_for(id: String, r: Dictionary) -> String:
	var O: Dictionary = GameData.ORBITS[mission.orbit]
	match id:
		"panels":
			var need: float = r.power_load * 1.15 / maxf(0.01, 1.0 - O.eclipse_frac)
			return _best("panels", GameData.PANELS, func(P): return P.power >= need, "cost")
		"battery":
			return _best("battery", GameData.BATTERIES, func(BT): return BT.wh * 0.6 >= r.battery_need, "cost")
		"comms":
			return _best("comms", GameData.COMMS, func(C): return _down(C) >= r.data_gen, "cost")
		"adcs":
			return _best("adcs", GameData.ADCS, func(A): return A.level >= r.pointing_need, "cost_pct")
		"propulsion":
			# to the Moon the trip brakes into orbit (and lands) with minutes of strong thrust: an electric engine pushes
			# gently for months, so it is never the star there, however light it is (#57: the south pole's best fit was
			# the ion engine, and the flight then flew a chemical burn the player never chose)
			var strong: bool = mission.orbit == "lunar"
			return _best("propulsion", GameData.PROPULSION, func(PR): return PR.dv >= r.dv_need and not (strong and bool(PR.electric)), "mass_pct")
	return ""


## What an antenna sends down per day in this orbit, GB.
func _down(C: Dictionary) -> float:
	var O: Dictionary = GameData.ORBITS[mission.orbit]
	return C.rate * O.comm_factor * O.contact_min * 60.0 / 8.0 / 1000.0


## True when choosing option `id` for `field` keeps the craft within its body's mass limit.
func _keeps_mass(field: String, id: String) -> bool:
	var old = mission.get(field)
	mission.set(field, id)
	var r2: Dictionary = mission.compute()
	mission.set(field, old)
	return r2.mass_total <= GameData.BUSES[mission.bus].max


## The cheapest body that holds instrument `id` and every instrument already chosen ("" if none does).
func _body_for(id: String) -> String:
	var need: int = GameData.INSTRUMENTS[id].size
	for j in mission.instruments:
		need = maxi(need, int(GameData.INSTRUMENTS[j].size))
	var best := ""
	for b in GameData.BUSES:
		var B: Dictionary = GameData.BUSES[b]
		if B.max_size >= need and B.slots >= mission.instruments.size() + 1 and (best == "" or B.cost < GameData.BUSES[best].cost):
			best = b
	return best


## A question seen for the first time starts on its best fit, so a player who only presses Continue never builds a
## craft that falls short without knowing it.
func _start_on_best(id: String) -> void:
	var b := _best_for(id, mission.compute())
	if b != "":
		_auto[id] = true
	if b != "" and str(mission.get(id)) != b:
		mission.set(id, b)
		GameState.room.design_edited(QUESTIONS[q][1])
		world.rebuild_ship()


## The answers the game chose follow the craft as it changes: when a later choice needs more (a faster antenna draws
## more power), they move to the new best fit; and a craft that outgrew its body moves to a body that holds it.
## Both say so. What the player chose is never changed.
func _follow_the_craft() -> void:
	var said := ""
	for id in _auto.keys():
		var r: Dictionary = mission.compute()
		var b := _best_for(id, r)
		if b == "" or str(mission.get(id)) == b or _enough(id, r, str(mission.get(id))):
			continue
		mission.set(id, b)
		said = tr("Your choices changed what the craft needs, so its %s moved to the new best fit.") % tr(STAGES[QUESTIONS[_q_index(id)][2]])
	var r2: Dictionary = mission.compute()
	if r2.mass_total > GameData.BUSES[mission.bus].max:
		var grown := ""
		for b in GameData.BUSES:
			var B: Dictionary = GameData.BUSES[b]
			var need := 0
			for j in mission.instruments:
				need = maxi(need, int(GameData.INSTRUMENTS[j].size))
			if B.max >= r2.mass_total * 1.15 and B.slots >= mission.instruments.size() and B.max_size >= need 					and (grown == "" or B.cost < GameData.BUSES[grown].cost):
				grown = b
		if grown != "" and grown != mission.bus:
			mission.bus = grown
			said = tr("Your craft outgrew its body (%s), so it moved to %s.") % [Kit.kg(r2.mass_total), GameData.BUSES[grown].name]
	if said != "":
		GameState.room.design_edited(QUESTIONS[q][1])
		world.rebuild_ship()
		_later(said, Kit.C_ACCENT)


## True when option `value` is enough for question `id` with the craft as it is.
func _enough(id: String, r: Dictionary, value: String) -> bool:
	var O: Dictionary = GameData.ORBITS[mission.orbit]
	match id:
		"panels":
			return GameData.PANELS[value].power >= r.power_load * 1.15 / maxf(0.01, 1.0 - O.eclipse_frac)
		"battery":
			return GameData.BATTERIES[value].wh * 0.6 >= r.battery_need
		"comms":
			return _down(GameData.COMMS[value]) >= r.data_gen
		"adcs":
			return GameData.ADCS[value].level >= r.pointing_need
		"propulsion":
			return GameData.PROPULSION[value].dv >= r.dv_need
	return true


## A choice can break something decided earlier (a faster antenna needs more power): say what, and where to fix it.
func _tell_new_problems(r: Dictionary, here: String) -> void:
	var now := {}
	for c in r.checks:
		if c.level != "ok":
			now[c.title] = c
	if not last_problems.is_empty():
		for t in now:
			var c: Dictionary = now[t]
			var at := _q_index(str(c.get("at", "")))
			if not last_problems.has(t) and at >= 0 and at < q and c.at != here:
				_later(tr("%s · fix it in %s (click it on the board)") % [t, tr(STAGES[QUESTIONS[at][2]])], Kit.C_BAD if c.level == "fatal" else Kit.C_WARN)
				break
	last_problems = now


## A notice shown once the screen is drawn again (drawing clears whatever is on it).
func _later(text: String, col: Color) -> void:
	later.append([text, col])


func _say(title: String, text: String) -> void:
	if info_body and is_instance_valid(info_body):
		info_body.text = (title + "\n" if title != "" else "") + text


## Continue: the next question, except past "What will it carry?" with nothing on board, which is never what a player
## means (#57, #97: a beginner pressing Continue reached the launch with no science and a blocked craft).
func _next() -> void:
	if QUESTIONS[q][0] == "instruments" and mission.instruments.is_empty() and GameState.room.can_edit(_step_of(QUESTIONS[q][1]).role):
		Kit.UiSound.play("error")
		Kit.toast(self, tr("Pick at least one instrument: it is what does the science. The ones marked Key fit the goals."), Kit.C_WARN, 3.0)
		return
	_show(q + 1)


## After a choice: approvals are void, the craft is rebuilt (unless rebuild_3d is false), and the screen goes on to
## the next question (advance) or stays on this one.
func on_change(rebuild_3d := true, advance := false) -> void:
	_auto.erase(QUESTIONS[q][0])   # the player chose this one: it is theirs now, the game never changes it
	GameState.room.design_edited(QUESTIONS[q][1])
	if rebuild_3d:
		world.rebuild_ship()
	GameState.changed.emit()
	_show(q + 1 if advance else q)


## The keyboard: 1 to 9 choose an option, Enter goes on (or launches), Backspace goes back.
func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = e.physical_keycode
	if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < picks.size():
		Kit.UiSound.play("click")
		picks[k - KEY_1].call()
	elif k == KEY_ENTER or k == KEY_KP_ENTER:
		if main_btn and is_instance_valid(main_btn) and not main_btn.disabled:
			main_btn.pressed.emit()
	elif k == KEY_BACKSPACE:
		if back_btn and is_instance_valid(back_btn) and not back_btn.disabled:
			back_btn.pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()


# ===================================================================================== TILES
## One option: its drawing, its name, two facts and a mark (the best fit, enough, too little). Pointing at it tells
## the rest. dim: it cannot be chosen here.
func _tile(kind: String, title: String, facts: Array, chosen: bool, on_click: Callable, more: String, mark := "", mark_col := Kit.C_DIM, dim := false) -> Control:
	var pc := PanelContainer.new()
	var sb := Kit.flat(Kit.C_CARD_SEL if chosen else Kit.C_CARD, Kit.C_GOLD if chosen else Kit.C_LINE, 12, 2 if chosen else 1, 12, 9)
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var h := Kit.hbox(12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(h)
	var icon := PartIcon.new()
	icon.kind = kind
	icon.k = 0.75
	h.add_child(icon)
	var v := Kit.vbox(5)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(Kit.lbl(("● " if chosen else "") + title, Kit.T_BODY + 1, Kit.C_TEXT, Kit.FONT_B, true))
	picks.append(on_click)
	if picks.size() <= 9:   # its key, as on a keycap
		var key := Kit.lbl(str(picks.size()), Kit.T_CAPS, Kit.C_DIM, Kit.FONT_B)
		key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(key)
	var chips := HFlowContainer.new()
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 4)
	v.add_child(chips)
	for i in facts.size():
		chips.add_child(Kit.chip(str(facts[i]), Kit.C_GOLD if i == 0 else Kit.C_ACCENT))
	if mark != "":
		chips.add_child(Kit.chip(mark, mark_col))
	if dim:
		pc.modulate.a = 0.5
	pc.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Kit.UiSound.play("click")
			on_click.call())
	var words: String = Glossary.notes(title, 1)   # the word in its name a newcomer may not know (issue #69)
	pc.mouse_entered.connect(func():
		sb.border_color = Kit.C_GOLD
		_say(title, more + ("\n" + words if words != "" else "")))
	pc.mouse_exited.connect(func(): sb.border_color = Kit.C_GOLD if chosen else Kit.C_LINE)
	return pc


## The mark of an option that is enough or not; `best` is the cheapest one that is enough.
func _fit(ok: bool, best: bool, short_word: String, light := true) -> Array:
	if ok and not light and not best:   # enough, but it would push the craft past its body's limit
		return [tr("Too heavy for this body"), Kit.C_WARN]
	if not _guided():   # past the first mission the choice is the player's: only what falls short is said
		return ["", Kit.C_DIM] if ok else [short_word, Kit.C_WARN]
	if best:
		return ["★ " + tr("Best fit"), Kit.C_OK]
	return [tr("Enough"), Kit.C_DIM] if ok else [short_word, Kit.C_WARN]


## The first mission (and the guided one) point at the best fit; from the second on the player decides alone.
func _guided() -> bool:
	return mission.scenario == Progress.ORDER[0] or main.has_node("Coach")


## The id of the cheapest option of `table` for which enough.call(entry) is true ("" if none); cost by `cost_key`.
func _best(field: String, table: Dictionary, enough: Callable, cost_key: String) -> String:
	var best := ""
	var best_any := ""
	for id in table:
		if not enough.call(table[id]):
			continue
		if best_any == "" or float(table[id][cost_key]) < float(table[best_any][cost_key]):
			best_any = id
		if _keeps_mass(field, id) and (best == "" or float(table[id][cost_key]) < float(table[best][cost_key])):
			best = id
	return best if best != "" else best_any


# ===================================================================================== QUESTIONS
func _fill_question(id: String, r: Dictionary) -> void:
	var S: Dictionary = GameData.SCENARIOS[mission.scenario]
	var O: Dictionary = GameData.ORBITS[mission.orbit]
	match id:
		"goals":
			var all: Dictionary = Objectives.all()
			left_box.add_child(Kit.lbl(tr("%d of %d chosen") % [mission.extras.size(), mission.extras_offered.size()], Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B))
			for e in mission.extras_offered:
				var E: Dictionary = all.get(e, {})
				if E.is_empty():
					continue
				var has: bool = mission.extras.has(e)
				var card := _tile("star", E.name, [tr("+%d points") % int(E.points)], has, func():
					if has:
						mission.extras.erase(e)
					else:
						mission.extras.append(e)
					on_change(false), E.desc, tr("Going for it") if has else "", Kit.C_OK)
				if E.has("how"):   # what to choose or do to reach it, on the card itself (#98)
					var how := Kit.lbl(tr("How: %s") % tr(str(E.how)), Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true)
					how.mouse_filter = Control.MOUSE_FILTER_IGNORE
					card.get_child(0).get_child(1).add_child(how)
				left_box.add_child(card)
		"orbit":
			var top := 0.0
			for o in GameData.ORBITS:
				top = maxf(top, S.orbit_mult.get(o, 0.0))
			for o in GameData.ORBITS:
				var OO: Dictionary = GameData.ORBITS[o]
				var m: float = S.orbit_mult.get(o, 0.0)
				if m <= 0.0 and mission.orbit != o:
					continue   # an orbit that cannot serve this goal is not offered
				var view_word: String = tr("Best view of the target") if m >= top else tr("%d %% less science") % roundi((1.0 - m / maxf(top, 0.001)) * 100.0)
				var reach_word: String = tr("The rocket takes it there") if OO.insert_dv <= 0.0 else tr("Its own engine adds %d m/s") % int(OO.insert_dv)
				left_box.add_child(_tile("orbit", OO.name, [view_word, reach_word], mission.orbit == o, func():
					mission.orbit = o
					world.stage_design()
					on_change(false), OO.desc + "\n" + (tr("Shadow up to %s a day, only near the equinoxes") % Kit.mins(OO.eclipse_min) if o == "geo" else tr("Shadow %s per lap") % Kit.mins(OO.eclipse_min)) + " · " + tr("Contact %s per day · speed change to get there %d m/s") % [Kit.mins(OO.contact_min), int(OO.insert_dv)],
					"★ " + tr("Best fit") if m >= top and _guided() else "", Kit.C_OK))
		"bus":
			# once the craft has parts, each body says whether it can carry them (its mass and its instruments)
			var weigh: bool = _reached > _q_index("instruments")
			for b in GameData.BUSES:
				var B: Dictionary = GameData.BUSES[b]
				var small: bool = weigh and (B.max < r.mass_total or B.slots < mission.instruments.size())
				var bmark: String = (tr("Too small for your craft") if small else tr("Carries it")) if weigh else ""
				left_box.add_child(_tile("bus", B.name, [Kit.money(B.cost), (tr("Holds 1 instrument") if B.slots == 1 else tr("Holds %d instruments") % B.slots)], mission.bus == b, func(): mission.bus = b; on_change(true),
					B.desc + "\n" + tr("Max load %s · %d slot(s) · instruments up to “%s” · %s") % [Kit.kg(B.max), B.slots, GameData.SIZE_NAMES[B.max_size], Kit.money(B.cost)],
					bmark, Kit.C_WARN if small else Kit.C_DIM))
		"instruments":
			var B: Dictionary = GameData.BUSES[mission.bus]
			var over: bool = mission.instruments.size() > B.slots
			left_box.add_child(Kit.lbl(tr("%d of %d places used") % [mission.instruments.size(), B.slots], Kit.T_BODY, Kit.C_BAD if over else Kit.C_TEXT, Kit.FONT_B))
			for n in r.needs:
				left_box.add_child(Kit.lbl(("✓ " if n.ok else "○ ") + n.label, Kit.T_SMALL + 1, Kit.C_OK if n.ok else Kit.C_WARN, Kit.FONT_B, true))
			var default_rel: float = S.get("default_relevance", 0.1)
			var hidden := 0
			for i in GameData.INSTRUMENTS:
				var I: Dictionary = GameData.INSTRUMENTS[i]
				var rel := 0.0
				for t in I.tags:
					rel = max(rel, S.relevance.get(t, default_rel))
				if S.relevance.is_empty():
					rel = default_rel
				var fits: bool = I.size <= B.max_size
				var has: bool = mission.instruments.has(i)
				# only what helps here and fits this body, unless the player asks for all of them
				# (a key instrument that needs a bigger body stays in view, dimmed, so the player learns why)
				if not has and not show_all and not S.relevance.is_empty() and (rel < 0.5 or (not fits and rel < 0.95)):
					hidden += 1
					continue
				var mark := "★ " + tr("Key") if rel >= 0.95 else (tr("Useful") if rel >= 0.5 else tr("Minor use"))
				if not fits:
					mark = tr("Needs a bigger body")
				left_box.add_child(_tile("camera", I.name, [Kit.money(I.cost), Kit.kg(I.mass)], has, func():
					if not has and not fits:
						# it does not fit this body: grow the craft to the cheapest body that holds it and everything chosen
						var grown := _body_for(i)
						if grown == "":
							toast(tr("%s doesn't fit on %s") % [I.name, B.name], Kit.C_BAD)
							return
						mission.bus = grown
						_later(tr("Your craft grew to %s so the %s fits.") % [GameData.BUSES[grown].name, I.name], Kit.C_ACCENT)
					mission.toggle_instrument(i)
					on_change(), I.desc + "\n" + tr("%s · %s · %s per day · %s · %s pointing") % [Kit.kg(I.mass), Kit.watts(I.power), Kit.gb(I.data), Kit.money(I.cost), [tr("free"), tr("coarse"), tr("fine"), tr("precise")][I.pointing]],
					mark, Kit.C_OK if rel >= 0.95 and fits else (Kit.C_WARN if not fits else Kit.C_DIM), not fits))
			if hidden > 0 or show_all:
				var more := Kit.btn(tr("Show the useful ones only") if show_all else tr("Show all %d instruments") % GameData.INSTRUMENTS.size(), func():
					show_all = not show_all
					_show(q), Kit.T_SMALL)
				more.flat = true
				left_box.add_child(more)
		"panels":
			var need: float = r.power_load * 1.15 / maxf(0.01, 1.0 - O.eclipse_frac)
			left_box.add_child(Kit.lbl(tr("Your craft needs %s of panels.") % Kit.watts(need), Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B, true))
			var best := _best_for("panels", r)
			for p in GameData.PANELS:
				var P: Dictionary = GameData.PANELS[p]
				var f: Array = _fit(P.power >= need, p == best, tr("Too little"), _keeps_mass("panels", p))
				left_box.add_child(_tile("panel", P.name, [Kit.money(P.cost), Kit.watts(P.power)], mission.panels == p, func(): mission.panels = p; on_change(true),
					P.desc + "\n" + tr("%s in sunlight · %s · %s") % [Kit.watts(P.power), Kit.kg(P.mass), Kit.money(P.cost)], f[0], f[1]))
		"battery":
			left_box.add_child(Kit.lbl(tr("In the shadow it needs %.0f Wh.") % r.battery_need, Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B, true))
			var best := _best_for("battery", r)
			for b in GameData.BATTERIES:
				var BT: Dictionary = GameData.BATTERIES[b]
				var ok: bool = BT.wh * 0.6 >= r.battery_need
				var f: Array = _fit(ok, b == best, tr("Falls short"), _keeps_mass("battery", b))
				left_box.add_child(_tile("battery", BT.name, [Kit.money(BT.cost), "%d Wh" % int(BT.wh)], mission.battery == b, func(): mission.battery = b; on_change(true),
					BT.desc + "\n" + "%s · %s" % [Kit.kg(BT.mass), Kit.money(BT.cost)] + " · " + tr("Only 60 % of a battery is used, so it lasts many cycles."), f[0], f[1]))
		"comms":
			left_box.add_child(Kit.lbl(tr("Your instruments make %s per day.") % Kit.gb(r.data_gen), Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B, true))
			var best := _best_for("comms", r)
			for c in GameData.COMMS:
				var C: Dictionary = GameData.COMMS[c]
				var d: float = _down(C)
				var f: Array = _fit(d >= r.data_gen, c == best, tr("Too slow"), _keeps_mass("comms", c))
				left_box.add_child(_tile("antenna", C.name, [Kit.money(C.cost), tr("sends %s a day") % Kit.gb(d)], mission.comms == c, func(): mission.comms = c; on_change(true),
					C.desc + "\n" + tr("Sends %s per day · %s · %s · %s") % [Kit.gb(d), Kit.kg(C.mass), Kit.watts(C.power), Kit.money(C.cost)], f[0], f[1]))
		"adcs":
			var best := _best_for("adcs", r)
			for a in GameData.ADCS:
				var A: Dictionary = GameData.ADCS[a]
				var f: Array = _fit(A.level >= r.pointing_need, a == best, tr("Too coarse"))
				left_box.add_child(_tile("wheel", A.name, [tr("+%s cost") % Kit.pct(A.cost_pct), [tr("coarse"), tr("coarse"), tr("fine"), tr("precise")][clampi(A.level, 0, 3)]], mission.adcs == a, func(): mission.adcs = a; on_change(true),
					A.desc + "\n" + tr("Your instruments need pointing level %d.") % r.pointing_need + " " + tr("Level %d · %s of the platform's cost") % [A.level, Kit.pct(A.cost_pct)], f[0], f[1]))
		"propulsion":
			left_box.add_child(Kit.lbl(tr("It needs %d m/s for this orbit and %d years.") % [int(r.dv_need), mission.years], Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B, true))
			var best := _best_for("propulsion", r)
			for p in GameData.PROPULSION:
				var PR: Dictionary = GameData.PROPULSION[p]
				var f: Array = _fit(PR.dv >= r.dv_need, p == best, tr("Too little"), _keeps_mass("propulsion", p))
				left_box.add_child(_tile("none" if PR.dv <= 0.0 else "thruster", PR.name, [tr("+%s mass") % Kit.pct(PR.mass_pct), "%d m/s" % int(PR.dv)], mission.propulsion == p, func(): mission.propulsion = p; on_change(true),
					PR.desc + "\n" + tr("Can change its speed by %d m/s · fuel ≈ %s of the mass") % [int(PR.dv), Kit.pct(PR.mass_pct)], f[0], f[1]))
		"launcher":
			left_box.add_child(Kit.lbl(tr("Your craft weighs %s and goes to %s.") % [Kit.kg(r.mass_total), O.short], Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B, true))
			var own := _tile("rocket", tr("Build your own rocket"), [tr("Engines, tanks, stages: your design")], false, func(): go("builder", {"back_step": step_idx}),
				tr("Put a rocket together from real parts, from the engines up, and see if it can lift your craft."), tr("The fun one"), Kit.C_GOLD)
			var own_sb := Kit.flat(Color(Kit.C_GOLD, 0.14), Kit.C_GOLD, 12, 2, 12, 12)
			own_sb.shadow_color = Color(Kit.C_GOLD, 0.35)
			own_sb.shadow_size = 8
			own.add_theme_stylebox_override("panel", own_sb)
			left_box.add_child(own)
			if RocketDesign.current != null:
				var CL: Dictionary = RocketDesign.current.launcher_info()
				var ccap: float = CL.cap[mission.orbit]
				var cok: bool = ccap >= r.mass_total and ccap > 0.0
				left_box.add_child(_tile("rocket", tr(CL.name), [Kit.money(CL.cost), tr("lifts %s") % Kit.kg(ccap)], mission.launcher == RocketDesign.CUSTOM, func(): mission.launcher = RocketDesign.CUSTOM; on_change(false),
					tr(CL.desc), tr("Fits") if cok else (tr("Can't reach") if ccap <= 0.0 else tr("Too heavy")), Kit.C_OK if cok else Kit.C_WARN, ccap <= 0.0))
			var cost_of := func(L: Dictionary) -> float: return max(L.min_cost, L.cost + L.cost_per_kg * r.mass_total)
			var best := ""
			for l in GameData.LAUNCHERS:
				var L: Dictionary = GameData.LAUNCHERS[l]
				if L.cap[mission.orbit] >= r.mass_total and (best == "" or cost_of.call(L) < cost_of.call(GameData.LAUNCHERS[best])):
					best = l
			for l in GameData.LAUNCHERS:
				var L: Dictionary = GameData.LAUNCHERS[l]
				var cap: float = L.cap[mission.orbit]
				if cap <= 0.0 and mission.launcher != l:
					continue   # a rocket that cannot reach this orbit is not offered
				var f: Array = _fit(cap >= r.mass_total, l == best, tr("Too heavy"))
				left_box.add_child(_tile("rocket", L.name, [Kit.money(cost_of.call(L)), tr("lifts %s") % Kit.kg(cap)], mission.launcher == l, func(): mission.launcher = l; on_change(false),
					L.desc + "\n" + tr("Up to %s to %s · %s · reliability %s") % [Kit.kg(cap), O.short, Kit.money(cost_of.call(L)), Kit.pct(1.0 - L.fail)], f[0], f[1]))
		"review":
			_fill_review(r)


func _fill_review(r: Dictionary) -> void:
	var S: Dictionary = GameData.SCENARIOS[mission.scenario]
	var O: Dictionary = GameData.ORBITS[mission.orbit]
	var order := {"fatal": 0, "warn": 1, "ok": 2}
	var checks: Array = r.checks.duplicate()
	checks.sort_custom(func(a, b): return order[a.level] < order[b.level])
	var fine := 0
	for c in checks:
		if c.level == "ok":
			fine += 1
			continue
		var col: Color = Kit.C_BAD if c.level == "fatal" else Kit.C_WARN
		var pc := Kit.tile(col, 12, 8)
		pc.mouse_filter = Control.MOUSE_FILTER_STOP
		var row := Kit.hbox(8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.add_child(row)
		row.add_child(Kit.lbl(("✗ " if c.level == "fatal" else "! ") + c.title, Kit.T_BODY, col, Kit.FONT_B, true))
		var at: int = _q_index(str(c.get("at", "")))
		if at >= 0:
			row.add_child(Kit.lbl(tr("Fix in %s ▶") % tr(STAGES[QUESTIONS[at][2]]), Kit.T_SMALL, Kit.C_TEXT, Kit.FONT_B))
			pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			pc.gui_input.connect(func(e: InputEvent):
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
					Kit.UiSound.play("click")
					_show(at))
		pc.mouse_entered.connect(func(): _say(c.title, c.detail))
		left_box.add_child(pc)
	if fine == checks.size():
		left_box.add_child(Kit.lbl("✓ " + tr("All systems go"), Kit.T_VALUE, Kit.C_OK, Kit.FONT_T))
	elif fine > 0:
		left_box.add_child(Kit.lbl("✓ " + tr("%d other things are fine") % fine, Kit.T_SMALL + 1, Kit.C_OK, Kit.FONT_B))
	# how long it works, and what protects it
	left_box.add_child(Kit.spacer(2))
	left_box.add_child(Kit.caps(tr("Years of work · at least %d") % S.min_years))
	var yh := Kit.segmented()
	left_box.add_child(yh)
	for y in YEARS:
		var b := Kit.choice(str(y), mission.years == y, func(): mission.years = y; on_change(false))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		yh.add_child(b)
	left_box.add_child(Kit.caps(tr("Extras")))
	left_box.add_child(_tile("spare", tr("Backup parts"), [tr("+20 % cost"), tr("+10 % mass")], mission.redundancy, func(): mission.redundancy = not mission.redundancy; on_change(),
		tr("Doubles critical components (computer, wheels). If something fails, the backup takes over.")))
	left_box.add_child(_tile("shield", tr("Radiation shielding"), [tr("+5 % cost"), tr("+4 % mass")], mission.shielding, func(): mission.shielding = not mission.shielding; on_change(),
		tr("Plates that shield the electronics from particles from the Sun and the radiation belts. Key far from Earth.")))
	_say("", tr("More years means more science, and more cost (%s per year) and fuel.") % Kit.money(O.ops * GameData.BUSES[mission.bus].ops_mult))
	# the crew's sign-off, when friends hold stations
	var room = GameState.room
	if GameState.team_mode:
		left_box.add_child(Kit.caps(tr("Crew sign-off")))
		for role in GameData.ROLE_ORDER:
			var R: Dictionary = GameData.ROLES[role]
			var ok: bool = r.goals[role]
			var pc := Kit.tile(R.color, 10.0, 8.0)
			var h := Kit.hbox(8)
			pc.add_child(h)
			var v := Kit.vbox(1)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(v)
			v.add_child(Kit.lbl(room.holder_name(role) + " · " + R.name, Kit.T_SMALL + 1, R.color, Kit.FONT_B, true))
			v.add_child(Kit.lbl(("✓ " if ok else "✗ ") + R.goal, Kit.T_SMALL, Kit.C_OK if ok else Kit.C_WARN, Kit.FONT_R, true))
			var approved: bool = GameState.approvals.get(role, false)
			var b := Kit.btn(tr("Approved ✓") if approved else (tr("Approve") if ok else tr("Approve anyway")), func():
				room.sign(role, not GameState.approvals.get(role, false))
				_show(q), Kit.T_SMALL)
			b.disabled = not room.can_edit(role) or room.is_bot(role)
			if approved:
				Kit.accent_btn(b, Kit.C_OK)
			h.add_child(b)
			left_box.add_child(pc)
		if not r.fatal and not GameState.crew_ready():
			left_box.add_child(Kit.lbl(tr("The whole crew still has to sign off."), Kit.T_SMALL + 1, Kit.C_WARN, Kit.FONT_B, true))


# ===================================================================================== YOUR RESOURCES
## Bottom right: what the player has and how much of it the craft already uses, as bars that fill up (the board
## above says whether each is fine; this says how much is left). A bar past its end turns red.
func _fill_resources(r: Dictionary) -> void:
	var p := Kit.panel_box(16)
	Kit.place(p, 1, 1, 1, 1, -306 if Kit.compact else -364, -Kit.MARGIN, -Kit.MARGIN, -Kit.MARGIN)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	resources_panel = p
	var v := Kit.vbox(7)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	v.add_child(Kit.caps(tr("Your resources")))
	var B: Dictionary = GameData.BUSES[mission.bus]
	_meter(v, tr("Money"), r.cost_total, r.budget, tr("%s left of %s") % [Kit.money(maxf(0.0, r.budget - r.cost_total)), Kit.money(r.budget)], true)
	_meter(v, tr("Weight"), r.mass_total, r.mass_limit, tr("%s of %s") % [Kit.kg(r.mass_total), Kit.kg(r.mass_limit)], true)
	_meter(v, tr("Instrument places"), mission.instruments.size(), B.slots, tr("%d of %d used") % [mission.instruments.size(), B.slots], true)
	if _reached >= _q_index("panels"):
		_meter(v, tr("Power"), r.power_load, r.power_gen, tr("uses %s of %s") % [Kit.watts(r.power_load), Kit.watts(r.power_gen)], true)
	if _reached >= _q_index("comms"):
		_meter(v, tr("Data link"), r.data_gen, r.data_down, tr("%s of %s a day") % [Kit.gb(r.data_gen), Kit.gb(r.data_down)], true)


## One resource: its name, how much is used of what there is (in words), and a bar.
func _meter(parent: VBoxContainer, label: String, used: float, have: float, words: String, _less_is_better: bool) -> void:
	var f: float = used / maxf(have, 0.0001)
	var col: Color = Kit.C_ACCENT if f <= 0.85 else (Kit.C_WARN if f <= 1.0 else Kit.C_BAD)
	var h := Kit.hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(h)
	var n := Kit.lbl(label, Kit.T_SMALL + 1, Kit.C_TEXT, Kit.FONT_B)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	h.add_child(Kit.lbl(words, Kit.T_SMALL, Kit.ink(col) if f > 0.85 else Kit.C_DIM, Kit.font_num()))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(0, 8)
	bar.max_value = 1.0
	bar.value = clampf(f, 0.0, 1.0)
	bar.add_theme_stylebox_override("background", Kit.flat(Kit.C_LINE, Color(0, 0, 0, 0), 4, 0, 0, 0))
	bar.add_theme_stylebox_override("fill", Kit.flat(col, Color(0, 0, 0, 0), 4, 0, 0, 0))
	parent.add_child(bar)


# ===================================================================================== THE MISSION BOARD
## Seven short answers: what the craft uses against what it has (the numbers after _row's text are the index in
## QUESTIONS of the question that decides each: until it is reached the row is grey). Pointing at one tells the numbers behind it.
func _fill_board(r: Dictionary) -> void:
	var S: Dictionary = GameData.SCENARIOS[mission.scenario]
	board.add_child(Kit.caps(tr("Mission board")))
	_row(tr("Budget"), tr("costs %s · you have %s") % [Kit.money(r.cost_total), Kit.money(r.budget)], r.cost_total / r.budget, 0.9,
		tr("Covers building, launch (%s) and operations for %d years (%s).") % [Kit.money(r.cost.launch), mission.years, Kit.money(r.cost.ops)] + " " + (tr("Reserve %s") % Kit.pct(r.reserve) if r.reserve >= 0.0 else tr("Over budget!")))
	_row(tr("Mass"), tr("weighs %s · limit %s") % [Kit.kg(r.mass_total), Kit.kg(r.mass_limit)], r.mass_total / max(0.001, r.mass_limit), 0.9,
		tr("Limit") + " · " + tr("platform %s · rocket %s") % [Kit.kg(r.mass_bus_max), Kit.kg(r.launch_cap) if r.launch_cap > 0.0 else tr("can't reach")] + ". " + tr("Instruments %s · power %s · fuel %s · platform %s.") % [Kit.kg(r.mass.instruments), Kit.kg(r.mass.power), Kit.kg(r.mass.propellant), Kit.kg(r.mass.bus)], false, 2)
	_row(tr("Power"), tr("uses %s · makes %s") % [Kit.watts(r.power_load), Kit.watts(r.power_gen)], r.power_load / max(0.001, r.power_gen), 0.87,
		tr("Draw against the panels' average generation (counting shadow).") + " " + tr("Margin %s") % Kit.pct(r.power_margin), false, 4)
	_row(tr("Battery"), tr("needs %d Wh · holds %d Wh") % [int(r.battery_need), int(r.battery_wh)], r.battery_need / max(0.001, r.battery_wh), 0.85, tr("Energy needed to cross the shadow."), false, 5)
	_row(tr("Data"), tr("makes %s · sends %s a day") % [Kit.gb(r.data_gen), Kit.gb(r.data_down)], r.data_gen / max(0.0001, r.data_down), 0.9, tr("Data made against what the antenna can send down."), false, 6)
	_row(tr("Fuel"), tr("needs %d m/s · has %d m/s") % [int(r.dv_need), int(r.dv_have)], r.dv_need / max(0.001, r.dv_have) if r.dv_have > 0.0 else (0.0 if r.dv_need <= 0.0 else 2.0), 0.9, tr("Change of speed needed to get there and hold the orbit."), false, 8)
	var sf: float = r.expected_science / S.science_target
	_row(tr("Science"), tr("%d points · goal %d") % [int(r.expected_science), int(S.science_target)], sf, 0.0, tr("An estimate with no surprises."), true, 3)
	var nf := 0
	var nw := 0
	for c in r.checks:
		var at := _q_index(str(c.get("at", "")))
		if at > _reached or (at < 0 and _reached < _q_index("review")):
			continue   # a step not reached yet is not a fault yet
		if c.level == "fatal":
			nf += 1
		elif c.level == "warn":
			nw += 1
	var facts := Kit.hbox(6)
	board.add_child(facts)
	if nf > 0:
		var fix := Kit.chip("✗ " + tr("%d to fix") % nf, Kit.C_BAD)
		fix.mouse_filter = Control.MOUSE_FILTER_STOP
		fix.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		fix.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				for c in r.checks:
					if c.level == "fatal" and _q_index(str(c.get("at", ""))) >= 0:
						_show(_q_index(str(c.at)))
						return)
		facts.add_child(fix)
	if nw > 0:
		facts.add_child(Kit.chip("! " + tr("%d warning(s)") % nw, Kit.C_WARN))
	if nf == 0 and nw == 0 and _reached >= _q_index("review"):
		facts.add_child(Kit.chip("✓ " + tr("Ready to fly"), Kit.C_OK))


## One answer of the board. frac = use / what there is; above 1 is red (too much: it cannot fly like this), above
## warn amber; more_is_better flips it. A row whose question (index from_q in QUESTIONS) has not been reached yet, or
## that nothing provides yet, is grey: not chosen, which is not a fault.
func _row(label: String, value: String, frac: float, warn: float, explain: String, more_is_better := false, from_q := -1) -> void:
	var state := 1
	if more_is_better:
		state = 1 if frac >= 0.8 else (0 if frac >= 0.4 else -1)
	elif frac > 1.0:
		state = -1
	elif frac > warn:
		state = 0
	var pending: bool = (from_q >= 0 and _reached < from_q) or (more_is_better and mission.instruments.is_empty())
	if more_is_better and state < 0:
		state = 0   # little science is a cost, never a fault: amber, not red
	if pending and Kit.compact:
		return   # on a phone the board shows only what is decided: a row not chosen yet would push the resources off
	var col: Color = Kit.C_OK if state > 0 else (Kit.C_WARN if state == 0 else Kit.C_BAD)
	var why := explain
	if pending:
		col = Kit.C_DIM
		value = tr("not chosen yet")
		why = tr("You have not chosen this yet: it comes in a later step.") + " " + explain
	elif state < 0 and not more_is_better:
		why = tr("Too much: %s over what you have") % Kit.pct(frac - 1.0) + ". " + explain
	var flagged: bool = state <= 0 and not pending
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.add_theme_stylebox_override("panel", Kit.flat(Color(col, 0.1) if state < 0 and not pending else Kit.C_CARD, Color(col, 0.45 if flagged else 0.0), 8, 1, 10, 5))
	var v := Kit.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(v)
	var h := Kit.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	h.add_child(Kit.lbl("○" if pending else ("✓" if state > 0 else ("!" if state == 0 else "✗")), Kit.T_LEAD, col, Kit.FONT_T))
	h.add_child(Kit.lbl(label, Kit.T_BODY, Kit.C_DIM if pending else Kit.C_TEXT, Kit.FONT_B))
	var val := Kit.lbl(value, Kit.T_SMALL, col if flagged else Kit.C_DIM)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(val)
	pc.mouse_entered.connect(func(): _say(label, why))
	if from_q >= 0 and from_q <= _reached and from_q != q:
		pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pc.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				Kit.UiSound.play("click")
				_show(from_q))
	board.add_child(pc)


## On a phone nothing covers anything (issue #93): the hint and the bar take the real gap between the columns, and the
## resource bars give way when the board above needs the room (the board says the same in words).
func process(_delta: float) -> void:
	if not Kit.compact or not is_instance_valid(bar_panel) or not is_instance_valid(board_panel):
		return
	if is_instance_valid(resources_panel):
		var need: float = resources_panel.size.y
		var room: float = get_viewport_rect().size.y - Kit.MARGIN - board_panel.get_global_rect().end.y - 8.0
		resources_panel.visible = need <= room
	# the middle column ends where the nearer of the right panels begins
	var right: Control = board_panel
	if is_instance_valid(resources_panel) and resources_panel.visible and resources_panel.get_global_rect().position.x < board_panel.get_global_rect().position.x:
		right = resources_panel
	Kit.fit_middle(left_panel, right, hint_panel, bar_panel)
