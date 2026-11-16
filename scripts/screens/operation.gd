extends "res://scripts/screens/screen.gd"
## Operation: the months of GameState.last_sim play back (the mission log, the time and science bars) while the craft
## is shown where it really is (issue #30):
##   - landed (GameState.flight.landing): the lander standing where it touched down, on NASA's LOLA ground at
##     Shackleton's rim [S-lola]. At the pole the Sun circles the horizon once a lunar day, so its light sweeps round
##     the ground month by month, while the crater's interior stays in permanent shadow [S-nasa-science] and the Earth
##     hangs low over the near side;
##   - in orbit: the craft on its orbit, turning at its true period (data/orbits.json, period_min) at the speed time
##     runs; when that would be a blur, the orbit is drawn as a ring and the screen says how many laps a second it is.
## Space weather (issue #90): when a storm on NOAA's scales reaches the craft [S-noaa-scales], time stops and an alert
## card asks what to do (safe mode or keep working, each with its real cost and its chance of damage); the months from
## the storm on are simulated again with the answer (mission.simulate is the same for the same seed and choices).
## Ground control's games of the operation (issue #63, scripts/minigames/desk.gd) hold the time-lapse while open.
## The time panel says in words how fast time runs (the rule of AGENTS.md: real time, said on screen). At the end (or
## when the craft is lost) it fades to the report.

const FlightData := preload("res://scripts/flight/flight_data.gd")
const Surface := preload("res://scripts/flight/surface.gd")

const MONTH_S := 30.44 * 86400.0    ## A calendar month in seconds (the mission log counts calendar months).
const MONTH_REAL_S := 1.2           ## Real seconds one month takes at the slowest speed (slow enough to read the log).
const LUNAR_DAY_S := 29.53 * 86400.0   ## The Sun circles the pole's horizon once a lunar day.
const SPEEDS := [1.0, 3.0, 10.0]
const BLUR_LAPS := 0.5              ## Laps a second above which an orbit is drawn as a ring instead of a moving craft.
const MAX_ASKS := 1                 ## The player sets a storm rule once; every later storm follows it (#99).

var months_total := 0
var base := 1.0                     ## Months per MONTH_REAL_S at ×1 (a long mission plays a little faster).
var speed := 1.0                    ## Months per MONTH_REAL_S now.
var month_f := 0.0                  ## Playback position in months; 9999 jumps to the end.
var shown_month := -1
var shown_events := 0
var end_t := -1.0                   ## Seconds since the last month was shown (-1 before).
var leaving := false
var month_lbl: Label
var time_bar: ProgressBar
var sci_bar: ProgressBar
var sci_lbl: Label
var log_box: VBoxContainer
var log_scroll: ScrollContainer
var time_note: Label
var orbit_note: Label
var speed_btns: Array = []

var landed := false
var land: Dictionary
var surface                         ## scripts/flight/surface.gd, when the craft landed
var lander: Node3D
var lost_shown := false
var sun_held := false               ## The Sun's circling would strobe at this speed: it is held still, and the screen says so.
var choices := {}                   ## Month -> "safe" or "keep": the player's answers to the space weather alerts.
var alert: Control                  ## The space weather alert card while it waits for an answer.
var alert_month := 0


func enter(_args: Dictionary) -> void:
	months_total = mission.years * 12
	base = maxf(1.0, months_total / 36.0)
	speed = base
	land = GameState.flight.get("landing", {})
	landed = bool(land.get("landed", false)) and FlightData.has_landing(mission.scenario)
	if landed:
		Surface.note_landing(mission, land)
		surface = Surface.new()
		surface.build(world, mission, land)
		lander = surface.lander
	else:
		world.stage_orbit()
	_build_ui()
	_set_speed(0)


func exit() -> void:
	if surface:
		surface.restore()


# ===================================================================================== THE LANDER ON THE GROUND
# ===================================================================================== THE PANELS
func _build_ui() -> void:
	# the top bar: what this is, the month, time and science
	var top := Kit.panel_box(Kit.PAD)
	Kit.place(top, 0, 0, 1, 0, 330 if Kit.compact else 480, Kit.MARGIN, -Kit.MARGIN, 0)
	add_child(top)
	var tv := Kit.vbox(Kit.GAP)
	top.add_child(tv)
	var th := Kit.hbox(10)
	tv.add_child(th)
	# what the player is looking at, in one line
	tv.add_child(Kit.lbl(tr("A time-lapse of your mission at work: the months go by, the log tells what happens and the science adds up."), Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))
	tv.move_child(tv.get_child(tv.get_child_count() - 1), 1)
	var where: String = tr("On the Moon · Shackleton's rim") if landed else GameData.ORBITS[mission.orbit].name
	var tt := Kit.caps(tr("Operations") + " · " + where)
	tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tt.clip_text = true   # a long orbit name is cut, never pushes the bar past the screen (issue #93)
	tt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	th.add_child(tt)
	month_lbl = Kit.lbl(tr("Month 0 of %d") % months_total, Kit.T_VALUE, Kit.C_TEXT, Kit.font_num())
	th.add_child(month_lbl)
	time_bar = ProgressBar.new()
	time_bar.show_percentage = false
	time_bar.custom_minimum_size = Vector2(0, 8)
	time_bar.max_value = months_total
	tv.add_child(time_bar)
	var sh := Kit.hbox(12)
	tv.add_child(sh)
	sh.add_child(Kit.lbl(tr("Science"), Kit.T_BODY, Kit.C_DIM))
	sci_bar = ProgressBar.new()
	sci_bar.show_percentage = false
	sci_bar.custom_minimum_size = Vector2(0, 12)
	sci_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sci_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var S: Dictionary = GameData.SCENARIOS[mission.scenario]
	sci_bar.max_value = S.science_target
	sci_bar.add_theme_stylebox_override("fill", Kit.flat(Kit.C_OK, Color(0, 0, 0, 0), 4, 0, 0, 0))
	sh.add_child(sci_bar)
	sci_lbl = Kit.lbl("0 / %d" % int(S.science_target), Kit.T_BODY, Kit.C_TEXT, Kit.font_num())
	sh.add_child(sci_lbl)
	# the mission log
	var log_p := Kit.panel_box(Kit.PAD)
	Kit.place(log_p, 0, 0, 0, 1, Kit.MARGIN, Kit.MARGIN, 320 if Kit.compact else 456, -Kit.MARGIN)
	add_child(log_p)
	var lv := Kit.vbox(Kit.GAP)
	log_p.add_child(lv)
	lv.add_child(Kit.caps(tr("Mission log")))
	lv.add_child(Kit.rule())
	log_scroll = ScrollContainer.new()
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(log_scroll)
	log_box = Kit.vbox(8)
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_scroll.add_child(log_box)
	# time: how fast it runs, in words, and the report
	var tp := Kit.panel_box(Kit.PAD)
	if Kit.compact:
		Kit.place(tp, 1, 1, 1, 1, -400, -Kit.MARGIN, -Kit.MARGIN, -Kit.MARGIN)
		tp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		Kit.place(tp, 1, 1, 1, 1, -520, -236, -Kit.MARGIN, -Kit.MARGIN)
	add_child(tp)
	var tb := Kit.vbox(Kit.GAP)
	tp.add_child(tb)
	tb.add_child(Kit.caps(tr("Time")))
	var row := Kit.segmented()
	tb.add_child(row)
	for i in SPEEDS.size():
		var b := Kit.choice("×%d" % int(SPEEDS[i]), false, func(): _set_speed(i), 80)
		speed_btns.append(b)
		row.add_child(b)
	time_note = Kit.lbl("", Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true)
	tb.add_child(time_note)
	orbit_note = Kit.lbl("", Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true)
	tb.add_child(orbit_note)
	var rep := Kit.accent_btn(Kit.btn(tr("See report ▶▶"), func(): month_f = 9999.0, Kit.T_BODY), Kit.C_GOLD)
	rep.custom_minimum_size.y = Kit.BTN_H
	tb.add_child(rep)


## Speed i of SPEEDS: the time note says how fast that is, and an orbit turns at its true pace (or becomes a ring).
## The keyboard: 1, 2 and 3 set how fast the months go by, Enter jumps to the report.
func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = e.physical_keycode
	if is_instance_valid(alert):   # the alert card: 1 safe mode, 2 keep working
		if k == KEY_1 or k == KEY_2:
			_answer("safe" if k == KEY_1 else "keep")
			get_viewport().set_input_as_handled()
		return
	if k >= KEY_1 and k <= KEY_3:
		_set_speed(k - KEY_1)
	elif k == KEY_ENTER or k == KEY_KP_ENTER:
		month_f = 9999.0
	else:
		return
	get_viewport().set_input_as_handled()


func _set_speed(i: int) -> void:
	speed = SPEEDS[i] * base
	for k in speed_btns.size():
		var b: Button = speed_btns[k]
		for st in ["normal", "hover", "pressed"]:
			b.remove_theme_stylebox_override(st)
		b.remove_theme_color_override("font_color")
		if k == i:
			Kit.accent_btn(b, Kit.C_ACCENT)
	var per_month := MONTH_REAL_S / speed
	var warp := MONTH_S * speed / MONTH_REAL_S
	time_note.text = tr("A month every %.1f s: time runs %s times faster than real.") % [per_month, _big(warp)]
	if landed:
		var sun_laps := warp / LUNAR_DAY_S
		sun_held = sun_laps > BLUR_LAPS
		if sun_held:
			orbit_note.text = tr("The Sun circles the pole's horizon once a lunar day: %s turns a second at this speed, a flicker, so it is held still.") % _big(sun_laps)
		else:
			orbit_note.text = tr("At the pole the Sun circles the horizon once a lunar day (29.5 days), so its light sweeps round the ground; the crater's floor never sees it.")
		return
	if world.orbit_missed == "escape":
		world.orbit_speed = 0.4
		orbit_note.text = tr("Your craft could not brake at the Moon: it swung past it and sails on into space (amber). The faint ring is the orbit it was meant to reach.")
		return
	var period_s := float(GameData.ORBITS[mission.orbit].get("period_min", 90.0)) * 60.0
	if world.orbit_missed == "transfer":
		# the transfer ellipse from 200 km to GEO: a = 24,371 km, period 2 pi sqrt(a^3 / GM), GM 398,600 km3/s2 [S8]
		period_s = TAU * sqrt(pow(24371.0, 3.0) / 398600.0)
	var laps := warp / period_s
	if world.orbit_missed == "transfer":
		world.orbit_speed = TAU * minf(laps, 0.25)
		orbit_note.text = tr("Without an engine your craft never climbed to GEO: it stays on the transfer orbit the rocket left it on (amber), from 200 km up to 35,786 km and back every %s, crossing the radiation belts. The faint ring is GEO.") % _span(period_s)
		return
	if laps > BLUR_LAPS:
		world.orbit_speed = 0.0
		orbit_note.text = tr("Your craft laps its orbit every %s. At this speed that is %s laps each second, a blur, so the orbit is drawn as a ring.") % [_span(period_s), _big(laps)]
	else:
		world.orbit_speed = TAU * laps
		orbit_note.text = tr("Your craft laps its orbit every %s: one lap every %.1f s at this speed.") % [_span(period_s), 1.0 / laps]


func process(delta: float) -> void:
	if surface and is_instance_valid(lander):
		surface.place_sun(month_f * MONTH_S if month_f < 9000.0 and not sun_held else 0.0)
		surface.camera(delta)
	var sim: Dictionary = GameState.last_sim
	if sim.is_empty() or leaving or is_instance_valid(alert):
		return
	var desk = main.get_node_or_null("GroundDesk")
	if desk and desk.busy:   # ground control has a game open (#63): the months wait for it
		return
	# a slow frame (the scene loading, a hitch) never skips months: what happens in them, and ground control's games
	# (#63), get their turn
	month_f += minf(delta, 0.1) * speed / MONTH_REAL_S
	var target := int(floor(month_f))
	var months: int = sim.months
	var events: Array = sim.events
	while shown_month < min(target, months):
		var st := _storm_at(sim, shown_month + 1)
		if not st.is_empty() and not choices.has(st.month):
			if choices.size() >= MAX_ASKS or month_f >= 9000.0:
				_standing_rule(st)   # no card: the flight rule the player set, and the months go on
				return
			month_f = float(st.month)
			_ask(st)
			return
		shown_month += 1
		while shown_events < events.size() and events[shown_events].month <= shown_month:
			_log_event(events[shown_events])
			shown_events += 1
		if shown_month > 0 and shown_month <= sim.timeline.size():
			var s: float = sim.timeline[shown_month - 1]
			sci_bar.value = s
			sci_lbl.text = "%d / %d" % [int(s), int(GameData.SCENARIOS[mission.scenario].science_target)]
		month_lbl.text = tr("Month %d of %d") % [shown_month, months_total]
		time_bar.value = shown_month
	if shown_month >= months and end_t < 0.0:
		while shown_events < events.size():
			_log_event(events[shown_events])
			shown_events += 1
		end_t = 0.0
		if sim.status == "lost" or months < months_total:
			_lose()
	if end_t >= 0.0:
		end_t += delta
		if end_t > (2.5 if month_f < 9000.0 else 0.3):
			leaving = true
			main.go_faded("report", 0.8, 0.6)


# ===================================================================================== SPACE WEATHER
func _storm_at(sim: Dictionary, m: int) -> Dictionary:
	for st in sim.get("storms", []):
		if st.month == m:
			return st
	return {}


## The alert card: what is coming, what it does to this craft, how rare it is, and the two answers with their cost.
func _ask(st: Dictionary) -> void:
	alert_month = st.month
	var v := Kit.overlay(self, tr("A storm from the Sun!"), 720.0, 430.0, func(): _answer("safe"))
	alert = v.get_parent().get_parent()
	v.add_child(Kit.lbl(tr("Choose your storm rule"), Kit.T_LEAD, Kit.C_WARN, Kit.FONT_B, true))
	v.add_child(Kit.lbl(tr("Now and then the Sun throws out storms of fast particles that can damage a spacecraft. Choose once what your craft does when one hits: mission control will do the same at every storm for the rest of the mission."), Kit.T_BODY, Kit.C_TEXT, Kit.FONT_R, true))
	var often := {4: tr("About 100 storms this strong come in an 11-year solar cycle."),
		5: tr("Only about 4 storms this strong come in an 11-year solar cycle.")} if st.kind == "G" else {3: tr("About 10 storms this strong come in an 11-year solar cycle."),
		4: tr("Only about 3 storms this strong come in an 11-year solar cycle.")}
	v.add_child(Kit.lbl(tr("Coming now, in month %d: %s.") % [st.month, st.name] + " " + str(often[int(st.level)]) + " " + tr("Source: NOAA's space weather scales."), Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))
	var row := Kit.hbox(Kit.GAP * 2)
	v.add_child(row)
	_option(row, tr("Safe mode · 1"), tr("Hide: instruments off while each storm lasts. Safer, but half of that month's data is lost."), st.p_safe, Kit.C_ACCENT, func(): _answer("safe"))
	_option(row, tr("Keep working · 2"), tr("Keep observing: every bit of data kept, with more risk of damage."), st.p_keep, Kit.C_GOLD, func(): _answer("keep"))
	v.add_child(Kit.lbl(tr("If you close this card, mission control picks safe mode."), Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))


func _option(row: HBoxContainer, title: String, text: String, p: float, col: Color, cb: Callable) -> void:
	var box := Kit.vbox(Kit.GAP)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	var b := Kit.accent_btn(Kit.btn(title, cb, Kit.T_ACTION), col)
	b.custom_minimum_size.y = Kit.BTN_H + 8
	box.add_child(b)
	box.add_child(Kit.lbl(text, Kit.T_BODY, Kit.C_TEXT, Kit.FONT_R, true))
	box.add_child(Kit.lbl(tr("Chance of damage: %s") % Kit.pct(p), Kit.T_BODY, Kit.C_WARN if p >= 0.2 else Kit.C_DIM, Kit.FONT_B, true))


## The answer: the months from the storm on are simulated again with it; the log already shown stays as it is.
func _answer(c: String) -> void:
	if not is_instance_valid(alert):
		return
	alert.queue_free()
	alert = null
	_resimulate(alert_month, c)


## A storm after the player's storm rule (#99): mission control answers it as the player last did, the log tells it
## ("You kept the craft working...") and the months go on. Real flight teams work by such standing rules (the "flight rule" of the alert card).
func _standing_rule(st: Dictionary) -> void:
	var last := "safe"
	var m := -1
	for k in choices:
		if int(k) > m:
			m = int(k)
			last = choices[k]
	_resimulate(st.month, last)


func _resimulate(month: int, c: String) -> void:
	alert_month = month
	choices[month] = c
	var old: Dictionary = GameState.last_sim
	var s: Dictionary = mission.simulate(int(old.get("seed", 0)), choices)
	var evs: Array = []
	for e in old.events:
		if e.month < alert_month:
			evs.append(e)
	for e in s.events:
		if e.month >= alert_month:
			evs.append(e)
	s.events = evs
	GameState.last_sim = s


## The craft stops working: in orbit it fades away; on the ground the lander goes dark where it stands.
func _lose() -> void:
	if lost_shown:
		return
	lost_shown = true
	if not landed:
		world.lose_ship()
		return
	for mi in lander.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).transparency = 0.0
		mi.create_tween().tween_property(mi, "transparency", 0.55, 1.5)


func _log_event(e: Dictionary) -> void:
	var col: Color = Kit.C_OK if e.kind == "good" else (Kit.C_BAD if e.kind == "bad" else Kit.C_ACCENT)
	var pc := Kit.tile(col, 12, 9)
	var v := Kit.vbox(2)
	pc.add_child(v)
	v.add_child(Kit.lbl(tr("Month %d · %s") % [e.month, e.title], Kit.T_BODY, Kit.ink(col), Kit.FONT_B, true))
	v.add_child(Kit.lbl(e.text, Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))
	log_box.add_child(pc)
	pc.modulate.a = 0.0
	pc.create_tween().tween_property(pc, "modulate:a", 1.0, 0.4)
	if e.kind != "info" and month_f < 9000.0 and not Kit.compact:   # on a phone the log says it; a toast would cover it
		Kit.toast(self, e.title, col, 1.8, 196.0)   # below the top bar, never over the science
	# scroll to the newest entry once the log has its new size (next frame); freed with the screen if it leaves first
	if not get_tree().process_frame.is_connected(_scroll_log_to_end):
		get_tree().process_frame.connect(_scroll_log_to_end, CONNECT_ONE_SHOT)


func _scroll_log_to_end() -> void:
	log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)


## 3757000 as "3.8 million", 680 as "680".
func _big(v: float) -> String:
	if v >= 1.0e6:
		return tr("%.1f million") % (v / 1.0e6)
	if v >= 1000.0:
		return "%d,%03d" % [int(v / 1000.0), int(fmod(v, 1000.0))]
	return "%d" % roundi(v) if v >= 10.0 else "%.1f" % v


## A period in words: "92 min", "24 h", "6 months".
func _span(s: float) -> String:
	if s < 3.0 * 3600.0:
		return tr("%d min") % roundi(s / 60.0)
	if s < 3.0 * 86400.0:
		return tr("%d h") % roundi(s / 3600.0)
	if s < 60.0 * 86400.0:
		return tr("%d days") % roundi(s / 86400.0)
	return tr("%d months") % roundi(s / MONTH_S)
