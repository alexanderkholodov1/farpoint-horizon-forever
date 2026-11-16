extends VBoxContainer
## Ground control's mini-game "Hand it over" (issue #63): the Earth turns under the craft, and the Deep Space Network
## complex that hears it sinks toward its horizon. Before it sets, the player hands the craft to the next complex,
## which has just risen. Three complexes about 120 degrees apart in longitude, so one always sees a far craft
## [S-dsn-facts]; their places [S-dsn-sites] and the sky's turning (sidereal time [S-usno-gast]) are real, from
## scripts/minigames/dsn.gd. One turn of the Earth plays in about 45 seconds, said on screen.
## Generous: a dish that sets before the handoff only costs part of the bonus, and Wayra can take it at any time.
##   var g := Handoff.new(); g.setup(ra_dec, unix0, target_name); g.done.connect(...)

signal done(result: Dictionary)

const Kit := preload("res://scripts/ui/kit.gd")
const Dsn := preload("res://scripts/minigames/dsn.gd")
const SIDEREAL_DAY_S := 86164.0905     ## One turn of the Earth against the stars [S-usno-gast].
const DAY_REAL_S := 30.0               ## Real seconds one turn of the Earth takes in the game.
const WARP := SIDEREAL_DAY_S / DAY_REAL_S
const SETTING_DEG := 25.0              ## Below this, and sinking, the dish is setting: time to hand over.
const HANDOFFS := 3                    ## Handoffs to win: once round the world.
const BONUS_CLEAN := 40                ## Per handoff made while the old dish still heard the craft.
const BONUS_LATE := 15                 ## Per contact picked up again after a gap.
const GIVE_UP_S := 90.0

var ra_dec := Vector2.ZERO             ## Where the craft is in the sky (right ascension, declination; degrees).
var unix0 := 0.0
var target := ""
var t := 0.0                           ## Real seconds since the game opened.
var holder := -1                       ## Index into Dsn.STATIONS of the complex that has the craft, -1 in a gap.
var clean := 0
var late := 0
var gap_s := 0.0                       ## Simulated seconds without contact.
var finished := false
var elev: Array = [0.0, 0.0, 0.0]
var prev_elev: Array = [0.0, 0.0, 0.0]
var globe: Control
var status: Label
var rows: Array = []                   ## Per station: {"bar": ProgressBar, "deg": Label, "btn": Button}
var count_lbl: Label


func setup(sky: Vector2, unix_start: float, target_name: String) -> void:
	ra_dec = sky
	unix0 = calm_start(sky, unix_start)
	target = target_name
	add_theme_constant_override("separation", Kit.GAP)
	custom_minimum_size = Vector2(400, 0)
	add_child(Kit.caps(tr("Ground control · Deep Space Network")))
	var th := Kit.hbox(Kit.GAP)
	add_child(th)
	var title := Kit.lbl(tr("Hand it over"), Kit.T_VALUE, Kit.C_TEXT, Kit.FONT_B)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(title)
	count_lbl = Kit.lbl("", Kit.T_BODY, Kit.C_DIM, Kit.font_num())
	th.add_child(count_lbl)
	var intro := tr("The Earth turns, so each dish sees %s for only part of the day. Before the dish that has it sets, hand it to one that has just risen. Here a whole turn of the Earth takes %d seconds.") % [target, roundi(DAY_REAL_S)]
	if Kit.compact:   # a phone: the short version, so the panel fits the screen's height
		intro = tr("Before the dish that has %s sets, hand it to one that has risen.") % target
	add_child(Kit.lbl(intro, Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))
	status = Kit.lbl("", Kit.T_BODY, Kit.C_ACCENT, Kit.FONT_B, true)
	add_child(status)
	globe = Control.new()
	globe.custom_minimum_size = Vector2(400, 96 if Kit.compact else 170)
	globe.draw.connect(_draw_globe)
	add_child(globe)
	if not Kit.compact:
		add_child(Kit.lbl(tr("Seen from above the North Pole. Green: the dish that has it · blue: can see it · grey: below its horizon."), Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))
	for i in Dsn.STATIONS.size():
		var st: Dictionary = Dsn.STATIONS[i]
		var r := Kit.hbox(Kit.GAP)
		add_child(r)
		var name_l := Kit.lbl(st.name, Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B)
		name_l.custom_minimum_size.x = 96
		r.add_child(name_l)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 90.0
		bar.custom_minimum_size = Vector2(0, 10)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(bar)
		var deg := Kit.lbl("", Kit.T_SMALL, Kit.C_DIM, Kit.font_num())
		deg.custom_minimum_size.x = 104
		r.add_child(deg)
		var b := Kit.btn(tr("Hand over"), func(): hand_to(i), Kit.T_SMALL)
		r.add_child(b)
		rows.append({"bar": bar, "deg": deg, "btn": b})
	var acts := Kit.hbox(Kit.GAP)
	add_child(acts)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acts.add_child(sp)
	acts.add_child(Kit.btn(tr("Wayra, take it"), func(): _finish("bot"), Kit.T_SMALL))
	_measure()
	prev_elev = elev.duplicate()
	holder = _highest()
	_show()


## The first moment from `from` (within a day) when the highest complex has the craft 40° up or more and rising, so
## the game opens calm and the player watches a dish sink before acting.
static func calm_start(sky: Vector2, from: float) -> float:
	for k in 288:
		var u := from + k * 300.0
		var best := -90.0
		var best_i := 0
		for i in Dsn.STATIONS.size():
			var e := Dsn.elevation(Dsn.STATIONS[i], u, sky)
			if e > best:
				best = e
				best_i = i
		if best >= 40.0 and Dsn.elevation(Dsn.STATIONS[best_i], u + 300.0, sky) > best:
			return u
	return from


## The simulated time now (Unix seconds).
func unix() -> float:
	return unix0 + t * WARP


func _measure() -> void:
	for i in Dsn.STATIONS.size():
		elev[i] = Dsn.elevation(Dsn.STATIONS[i], unix(), ra_dec)


func _highest() -> int:
	var best := 0
	for i in elev.size():
		if elev[i] > elev[best]:
			best = i
	return best


func is_up(i: int) -> bool:
	return float(elev[i]) > Dsn.MIN_ELEV_DEG


## True when station i is low and still sinking: the moment to hand the craft over.
func is_setting(i: int) -> bool:
	return float(elev[i]) < SETTING_DEG and float(elev[i]) < float(prev_elev[i])


func _process(delta: float) -> void:
	if not finished:
		step(delta)


## One step of the game, delta in real seconds (tests call it too).
func step(delta: float) -> void:
	if finished:
		return
	t += delta
	prev_elev = elev.duplicate()
	_measure()
	if holder >= 0 and not is_up(holder):
		holder = -1    # the dish set with the craft still on it: contact lost until someone picks it up
	if holder < 0:
		gap_s += delta * WARP
	if t >= GIVE_UP_S:
		_finish("bot")
		return
	_show()
	globe.queue_redraw()


## The player hands the craft to station i. It counts only when i can see the craft and the one that has it is setting
## (or has set): handing over a dish that still has the craft high in its sky achieves nothing.
func hand_to(i: int) -> bool:
	if finished or i == holder:
		return false
	var st: Dictionary = Dsn.STATIONS[i]
	if not is_up(i):
		_say(tr("%s can't see %s yet: it is below its horizon.") % [st.name, target], Kit.C_WARN)
		return false
	if holder >= 0 and not is_setting(holder):
		_say(tr("%s still has it %d° up. Wait until it starts to set.") % [Dsn.STATIONS[holder].name, roundi(elev[holder])], Kit.C_WARN)
		return false
	if holder >= 0:
		clean += 1
	else:
		late += 1
	holder = i
	Kit.UiSound.play("notify")
	if clean + late >= HANDOFFS:
		_finish("player")
	else:
		_say(tr("%s has it. Handoff %d of %d.") % [st.name, clean + late, HANDOFFS], Kit.C_OK)
	return true


func _say(text: String, col: Color) -> void:
	status.text = text
	status.add_theme_color_override("font_color", Kit.ink(col))


## The rows and the advice: which dish has it, how high, and what to do now.
func _show() -> void:
	count_lbl.text = "%d / %d" % [clean + late, HANDOFFS]
	for i in rows.size():
		var r: Dictionary = rows[i]
		var e: float = elev[i]
		r.bar.value = clampf(e, 0.0, 90.0)
		r.deg.text = "%d°" % roundi(e) if e > 0.0 else tr("below horizon")
		var mine := i == holder
		r.bar.modulate = Kit.C_OK if mine else (Kit.C_ACCENT if is_up(i) else Color(1, 1, 1, 0.35))
		var moment: bool = not mine and is_up(i) and (holder < 0 or is_setting(holder))
		r.btn.visible = not mine and is_up(i)
		r.btn.disabled = not moment
		r.btn.text = tr("Hand over ▶") if moment else tr("Can see it")
		for st in ["normal", "hover", "pressed"]:
			r.btn.remove_theme_stylebox_override(st)
		if moment:
			Kit.accent_btn(r.btn, Kit.C_GOLD)
		r.deg.text = (tr("has it · ") if mine else "") + r.deg.text
	if finished:
		return
	if holder < 0:
		var up := -1
		for i in elev.size():
			if is_up(i):
				up = i
		if up >= 0:
			_say(tr("Contact lost! %s can see it: hand it over.") % Dsn.STATIONS[up].name, Kit.C_BAD)
		else:
			_say(tr("Contact lost. Wait for a dish to rise."), Kit.C_BAD)
	elif is_setting(holder):
		var other := false
		for i in elev.size():
			if i != holder and is_up(i):
				other = true
		if other:
			_say(tr("%s is setting (%d°). Hand it to a dish that has risen.") % [Dsn.STATIONS[holder].name, roundi(elev[holder])], Kit.C_GOLD)
		else:
			_say(tr("%s is setting (%d°). The next dish hasn't risen yet: get ready.") % [Dsn.STATIONS[holder].name, roundi(elev[holder])], Kit.C_ACCENT)
	else:
		_say(tr("%s has %s, %d° up. Watch it sink.") % [Dsn.STATIONS[holder].name, target, roundi(elev[holder])], Kit.C_ACCENT)


## The Earth seen from above its north pole, turning; each complex where it is now, and the arrow to the craft.
## A dish sees the craft while the craft's arrow is above its horizon (the line through it, square to the radius).
func _draw_globe() -> void:
	var s := globe.size
	var c := Vector2(s.x * 0.5, s.y * 0.5)
	var r := s.y * 0.3
	var gmst := Dsn.gmst_deg(unix())
	# in this view the craft's right ascension is a fixed direction, and the ground turns under it
	var to_craft := Vector2.from_angle(deg_to_rad(-ra_dec.x))
	globe.draw_circle(c, r, Color(0.13, 0.32, 0.6))
	globe.draw_arc(c, r, 0.0, TAU, 64, Color(Kit.C_ACCENT, 0.6), 1.5, true)
	var reach: float = minf(s.y * 0.5 - 26.0, s.x * 0.5 - 70.0) / maxf(absf(to_craft.y), 0.001)
	var tip := c + to_craft * clampf(reach, r + 30.0, s.x * 0.5 - 70.0)
	globe.draw_line(c + to_craft * (r + 6.0), tip, Color(Kit.C_GOLD, 0.8), 2.0, true)
	globe.draw_circle(tip, 5.0, Kit.C_GOLD)
	var f := Kit.font_num()
	globe.draw_string(f, tip + Vector2(-60, -10 if to_craft.y <= 0.0 else 22), target, HORIZONTAL_ALIGNMENT_CENTER, 120, Kit.T_SMALL, Kit.C_GOLD)
	for i in Dsn.STATIONS.size():
		var st: Dictionary = Dsn.STATIONS[i]
		var a := deg_to_rad(-(gmst + float(st.lon)))
		var p := c + Vector2.from_angle(a) * r
		var col: Color = Kit.C_OK if i == holder else (Kit.C_ACCENT if is_up(i) else Color(1, 1, 1, 0.35))
		if i == holder:
			globe.draw_line(p, p + (tip - p).normalized() * 30.0, Color(Kit.C_OK, 0.8), 2.0, true)
		globe.draw_circle(p, 6.0 if i == holder else 4.5, col)
		var out := Vector2.from_angle(a) * 16.0
		globe.draw_string(f, p + out + Vector2(-40, 5), st.name, HORIZONTAL_ALIGNMENT_CENTER, 80, Kit.T_SMALL, col)


func _finish(by: String) -> void:
	if finished:
		return
	finished = true
	var bonus := 0
	if by == "player":
		bonus = clean * BONUS_CLEAN + late * BONUS_LATE
		_say(tr("Once round the world without dropping it. +%d") % bonus, Kit.C_OK)
	var words := tr("Goldstone, Madrid, Canberra: the dishes passed %s from one to the next as the Earth turned.") % target
	done.emit({"go": true, "by": by, "bonus": bonus, "words": words, "clean": clean, "late": late, "secs": roundi(t)})
