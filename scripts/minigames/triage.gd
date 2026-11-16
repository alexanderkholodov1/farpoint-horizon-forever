extends VBoxContainer
## Ground control's mini-game "1202" (issue #9): during the descent the guidance computer has more jobs than work
## slots, as on Apollo 11, where needless rendezvous-radar jobs filled them [S-alsj-1202]. The player sheds the
## radar's jobs and keeps the landing's, then calls go. A full tray is a restart: the real computer dropped the low
## work and kept flying, so here it only costs bonus. Built only from scripts/ui/kit.gd.
## Our simplification: four slots (the real Executive had a few more) and a job every 0.7 s.

signal done(result: Dictionary)

const Kit := preload("res://scripts/ui/kit.gd")
const SLOTS := 4
const EVERY_S := 0.7
const LONG_S := 20.0         ## After this, ground calls go anyway (as Houston did within seconds).
const SHED_FOR_GO := 4       ## Radar jobs shed before go can be called.
const JOB_S := 1.6           ## The landing's jobs finish and free their slot after this (the radar's never do).
## kind -> [label, keep]: the landing's jobs stay, the radar's can go.
const JOBS := {
	"radar": ["Radar", false],
	"guide": ["Guidance", true],
	"throttle": ["Throttle", true],
	"display": ["Display", true],
}

var t := 0.0
var next_t := 0.4
var tray: Array = []         ## kinds, oldest first
var ages: Array = []         ## seconds each job in the tray has run
var shed := 0
var restarts := 0
var slips := 0
var over := false
var row: HBoxContainer
var status: Label
var go_btn: Button
var rng := RandomNumberGenerator.new()
var say := Callable()        ## func(text, color): a short message (the desk shows it as a toast).


func setup(alarm: Dictionary) -> void:
	add_theme_constant_override("separation", Kit.GAP)
	custom_minimum_size = Vector2(400, 0)
	add_child(Kit.caps(tr("Ground control · alarm %s") % str(alarm.get("code", "1202"))))
	add_child(Kit.lbl(tr("Too many jobs for the computer"), Kit.T_VALUE, Kit.C_TEXT, Kit.FONT_B))
	add_child(Kit.lbl(tr("The lander's computer has only a few work slots. The rendezvous radar keeps sending jobs the landing does not need. Click the radar's jobs to shed them; keep the landing's. Then call go."), Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))
	row = Kit.hbox(Kit.GAP)
	row.custom_minimum_size.y = 74
	add_child(row)
	status = Kit.lbl("", Kit.T_BODY, Kit.C_ACCENT, Kit.FONT_R, true)
	add_child(status)
	var acts := Kit.hbox(Kit.GAP)
	add_child(acts)
	go_btn = Kit.accent_btn(Kit.btn(tr("GO on that alarm"), func(): call_go(), Kit.T_BODY, 200), Kit.C_GOLD)
	go_btn.disabled = true
	acts.add_child(go_btn)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acts.add_child(sp)
	acts.add_child(Kit.btn(tr("Wayra, take it"), func(): _finish("bot"), Kit.T_SMALL))
	rng.randomize()
	_draw_tray()


func _process(delta: float) -> void:
	if status == null or over:
		return
	step(delta)


## One step, delta in real seconds (tests call it too).
func step(delta: float) -> void:
	t += delta
	var freed := false
	for i in range(tray.size() - 1, -1, -1):
		ages[i] += delta
		if JOBS[tray[i]][1] and ages[i] >= JOB_S:
			tray.remove_at(i)
			ages.remove_at(i)
			freed = true
	if freed:
		_draw_tray()
	if t >= next_t:
		next_t += EVERY_S
		var roll := rng.randf()
		add_job("radar" if roll < 0.6 else ["guide", "throttle", "display"][rng.randi() % 3])
	go_btn.disabled = shed < SHED_FOR_GO
	status.text = tr("Radar jobs shed: %d of %d · restarts: %d") % [shed, SHED_FOR_GO, restarts] if shed < SHED_FOR_GO \
		else tr("The landing's jobs have room. Call go!")
	if t >= LONG_S:
		_finish("player" if shed >= SHED_FOR_GO else "bot")


func add_job(kind: String) -> void:
	if tray.size() >= SLOTS:
		# a restart: the computer drops the low work and keeps the landing's, as the real one did
		restarts += 1
		var kept: Array = []
		for k in tray:
			if JOBS[k][1]:
				kept.append(k)
		tray = kept
		ages.resize(tray.size())
		ages.fill(0.0)
		_say(tr("1202! Restart: low jobs dropped, the landing goes on."), Kit.C_WARN)
	tray.append(kind)
	ages.append(0.0)
	_draw_tray()


func click(i: int) -> void:
	if over or i < 0 or i >= tray.size():
		return
	if JOBS[tray[i]][1]:
		slips += 1
		_say(tr("Keep that one: the landing needs it."), Kit.C_BAD)
		return
	tray.remove_at(i)
	ages.remove_at(i)
	shed += 1
	_draw_tray()


func call_go() -> void:
	if shed >= SHED_FOR_GO:
		_finish("player")


func _draw_tray() -> void:
	if row == null:
		return
	for c in row.get_children():
		c.queue_free()
	for i in SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(88, 70)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", Kit.T_SMALL)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if i < tray.size():
			var keep: bool = JOBS[tray[i]][1]
			b.text = tr(JOBS[tray[i]][0])
			Kit.accent_btn(b, Kit.C_ACCENT.darkened(0.25) if keep else Kit.C_WARN)
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			b.pressed.connect(click.bind(i))
		else:
			b.text = tr("free")
			b.disabled = true
		row.add_child(b)


func _say(text: String, col: Color) -> void:
	if say.is_valid():
		say.call(text, col)


func bonus() -> int:
	return maxi(30, 100 - 20 * restarts - 10 * slips)


func _finish(by: String) -> void:
	if over:
		return
	over = true
	var b := bonus() if by == "player" else 0
	var words := tr("Ground here. We're go on that alarm, keep flying.")
	if by == "player":
		words = tr("Ground here: radar jobs shed, the landing has its slots. We're go! +%d") % b
	status.text = words
	go_btn.disabled = true
	done.emit({"go": true, "by": by, "bonus": b, "words": words, "secs": roundi(t)})
