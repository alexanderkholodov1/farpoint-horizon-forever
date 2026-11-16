extends VBoxContainer
## Ground control's mini-game "Read the squiggles" (issue #63): after a bad month, four telemetry channels scroll by
## and one of them is wrong. The player finds it, then picks the fix from three. Each case is a real story of flight
## controllers reading their screens (Apollo 12's "SCE to AUX", Voyager 1's memory chip, Kepler's wheels), from
## data/ground_telemetry.json with its source; the waveforms are drawn by the game, not real data.
## Generous: a wrong pick only lowers the bonus, and Wayra can take it at any time.
##   var g := Telemetry.new(); g.setup(case_dict, channels_dict, event_title); g.done.connect(...)

signal done(result: Dictionary)

const Kit := preload("res://scripts/ui/kit.gd")
const DATA := "res://data/ground_telemetry.json"
const BONUS_MAX := 120
const BONUS_MIN := 40
const SLIP := 30                       ## Bonus lost per wrong pick.
const GIVE_UP_S := 90.0
const SAMPLES := 90                    ## Points per strip.
const SAMPLE_S := 0.08                 ## Real seconds between points.

var case := {}
var chans: Array = []                  ## The four channel dicts on screen, each with its "id".
var bad := 0                           ## Index into chans of the channel that is wrong.
var stage := "find"                    ## "find", then "fix", then "done".
var slips := 0
var t := 0.0
var sample_t := 0.0
var phase := 0.0
var finished := false
var hist: Array = []                   ## Per channel, its last SAMPLES values scaled 0..1.
var strips: Array = []                 ## Per channel: {"box": Control, "val": Label}
var status: Label
var step_lbl: Label
var fixes_box: VBoxContainer
var fix_order: Array = []
var rng := RandomNumberGenerator.new()


## The case for a mission-log event title (as shown, already translated), or {}: the first case one of whose "match"
## titles is that title. A %s in a match stands for anything.
static func case_for(title: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not d is Dictionary:
		return {}
	for c in d.cases:
		for m in c.match:
			var key := TranslationServer.translate(m)
			if key.contains("%s") and title.begins_with(key.get_slice("%s", 0)):
				return c
			if title == key:
				return c
	return {}


static func fallback() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	for c in d.cases:
		if c.get("fallback", false):
			return c
	return {}


static func channels() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return d.channels if d is Dictionary else {}


func setup(c: Dictionary, all_channels: Dictionary, after: String, seed_value := -1) -> void:
	case = c
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for id in c.channels:
		var ch: Dictionary = all_channels[id].duplicate()
		ch["id"] = id
		chans.append(ch)
	bad = c.channels.find(c.bad)
	add_theme_constant_override("separation", Kit.GAP)
	custom_minimum_size = Vector2(480, 0)
	add_child(Kit.caps(tr("Ground control · Telemetry")))
	add_child(Kit.lbl(tr("Read the squiggles"), Kit.T_VALUE, Kit.C_TEXT, Kit.FONT_B))
	add_child(Kit.lbl(tr("After \"%s\", one of these readings from the craft looks wrong.") % after, Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))
	step_lbl = Kit.caps("")
	add_child(step_lbl)
	status = Kit.lbl(tr("Watch the lines: which one is not behaving? Click it."), Kit.T_BODY, Kit.C_ACCENT, Kit.FONT_R, true)
	add_child(status)
	for i in chans.size():
		hist.append([])
		for k in SAMPLES:
			_sample(i, k * SAMPLE_S)
		var row := Kit.hbox(Kit.GAP)
		add_child(row)
		var name_l := Kit.lbl(tr(chans[i].name), Kit.T_SMALL, Kit.C_TEXT, Kit.FONT_B)
		name_l.custom_minimum_size.x = 150
		row.add_child(name_l)
		var box := Control.new()
		box.custom_minimum_size = Vector2(220, 38)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		box.draw.connect(_draw_strip.bind(i))
		box.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				pick_channel(i)
			elif e is InputEventScreenTouch and e.pressed:
				pick_channel(i))
		row.add_child(box)
		var val := Kit.lbl("", Kit.T_SMALL, Kit.C_DIM, Kit.font_num())
		val.custom_minimum_size.x = 70
		row.add_child(val)
		strips.append({"box": box, "val": val})
	fixes_box = Kit.vbox(Kit.GAP)
	add_child(fixes_box)
	var acts := Kit.hbox(Kit.GAP)
	add_child(acts)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acts.add_child(sp)
	acts.add_child(Kit.btn(tr("Wayra, take it"), func(): _finish("bot"), Kit.T_SMALL))
	_step_text()
	_values()


func _step_text() -> void:
	step_lbl.text = tr("Step 1 of 2 · find the line that is wrong") if stage == "find" else (tr("Step 2 of 2 · send the fix") if stage == "fix" else tr("Done"))


## A new value for channel i at time s (seconds), scaled 0..1 for its strip. The bad channel follows the case's
## pattern; the others wander gently around their middle.
func _sample(i: int, s: float) -> void:
	var v := 0.5 + 0.18 * sin(s * 1.7 + i * 2.1) + rng.randf_range(-0.04, 0.04)
	if i == bad:
		match str(case.pattern):
			"garble":   # the same scrambled block over and over (Voyager 1, 2023)
				var k := int(s / SAMPLE_S) % 6
				v = [0.1, 0.9, 0.2, 0.95, 0.05, 0.7][k]
			"sag":      # deeper every eclipse
				var orbit := fmod(s, 2.4)
				var depth := minf(0.15 + s * 0.012, 0.45)
				v = 0.75 - (depth if orbit > 1.5 else 0.0) + rng.randf_range(-0.02, 0.02)
			"spikes":   # friction catching the wheel
				v = 0.5 + (rng.randf_range(0.3, 0.45) * (1 if rng.randf() < 0.5 else -1) if rng.randf() < 0.18 else rng.randf_range(-0.03, 0.03))
			"step":     # the supply dropped; everything it feeds goes noisy
				v = 0.12 + rng.randf_range(-0.05, 0.05)
	elif str(case.pattern) == "step":
		v += rng.randf_range(-0.2, 0.2)   # Apollo 12: the other readings scrambled too
	hist[i].append(clampf(v, 0.02, 0.98))
	if hist[i].size() > SAMPLES:
		hist[i].pop_front()


func _values() -> void:
	for i in chans.size():
		var ch: Dictionary = chans[i]
		var v: float = hist[i][hist[i].size() - 1]
		var txt: String
		if str(ch.unit) == "":
			txt = tr("FAULT") if i == bad else tr("GOOD")
		else:
			var span: float = maxf(float(ch.wave) * 4.0, float(ch.base) * 0.4)
			var real: float = float(ch.base) + (v - 0.5) * span
			txt = ("%d " % roundi(real) if absf(real) >= 100.0 else "%.1f " % real) + str(ch.unit)
		strips[i].val.text = txt


func _process(delta: float) -> void:
	if not finished:
		step(delta)


## One step of the game, delta in real seconds (tests call it too).
func step(delta: float) -> void:
	if finished:
		return
	t += delta
	sample_t += delta
	while sample_t >= SAMPLE_S:
		sample_t -= SAMPLE_S
		phase += SAMPLE_S
		for i in chans.size():
			_sample(i, SAMPLES * SAMPLE_S + phase)
	_values()
	for s in strips:
		s.box.queue_redraw()
	if t >= GIVE_UP_S:
		_finish("bot")


func _draw_strip(i: int) -> void:
	var box: Control = strips[i].box
	var w := box.size.x
	var h := box.size.y
	var picked := stage != "find" and i == bad
	box.draw_rect(Rect2(Vector2.ZERO, box.size), Color(Kit.C_BG, 0.85))
	box.draw_rect(Rect2(Vector2.ZERO, box.size), Color(Kit.C_BAD if picked else Kit.C_ACCENT, 0.35), false, 1.0)
	var pts := PackedVector2Array()
	var hs: Array = hist[i]
	for k in hs.size():
		pts.append(Vector2(w * k / float(SAMPLES - 1), h - float(hs[k]) * h))
	if pts.size() >= 2:
		box.draw_polyline(pts, Kit.C_BAD if picked else Kit.C_OK, 1.5, true)


## The player points at channel i as the one that is wrong.
func pick_channel(i: int) -> bool:
	if finished or stage != "find":
		return false
	if i != bad:
		slips += 1
		_say(tr("%s looks normal: it wanders inside its usual range. Look again.") % tr(chans[i].name), Kit.C_WARN)
		return false
	stage = "fix"
	_step_text()
	_say(tr(str(case.why_bad)) + " " + tr("What do you send up?"), Kit.C_GOLD)
	fix_order = [0, 1, 2]
	fix_order.shuffle()
	for k in fix_order:
		var b := Kit.btn(tr(str(case.fixes[k])), func(): pick_fix(k), Kit.T_SMALL)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fixes_box.add_child(b)
	return true


## The player sends fix k (an index into the case's fixes; 0 is the right one).
func pick_fix(k: int) -> bool:
	if finished or stage != "fix":
		return false
	if k != 0:
		slips += 1
		_say(tr("The command went up, and the line still looks wrong. Try another."), Kit.C_WARN)
		return false
	_finish("player")
	return true


func _say(text: String, col: Color) -> void:
	status.text = text
	status.add_theme_color_override("font_color", Kit.ink(col))


func _finish(by: String) -> void:
	if finished:
		return
	finished = true
	stage = "done"
	_step_text()
	for b in fixes_box.get_children():
		b.queue_free()
	var bonus := 0
	if by == "player":
		bonus = maxi(BONUS_MAX - SLIP * slips, BONUS_MIN)
		_say(tr("Fixed: the line settles. +%d") % bonus, Kit.C_OK)
	fixes_box.add_child(Kit.lbl(tr(str(case.story)), Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))
	var words := tr("%s: back to normal after \"%s\".") % [tr(chans[bad].name), tr(str(case.fixes[0]))]
	done.emit({"go": true, "by": by, "bonus": bonus, "words": words, "case": str(case.id), "slips": slips, "secs": roundi(t)})
