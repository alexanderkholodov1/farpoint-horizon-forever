extends CanvasLayer
## The ground-control desk (issue #9): what the ground-control station does during the flight, over the flight's own
## screens. When a person holds the station it opens its mini-games at the real moments: "Find the carrier" when the
## craft leaves for the Moon (scripts/minigames/carrier.gd) and the 1202 during the descent (scripts/minigames/triage.gd,
## as GameState.ground_answer). When a bot holds it, Wayra does the same work and says so. Solving adds a bonus to the
## flight (GameState.flight.ground, counted by settle_extras); missing it costs nothing.
## In the months of operation (issue #63) it opens two more, while the time-lapse waits: "Hand it over" in the first
## month for a craft beyond the Earth's orbits (scripts/minigames/handoff.gd), and "Read the squiggles" after the first
## month whose log tells of a trouble it has a case for (scripts/minigames/telemetry.gd), or by mid-mission if none came.
##   preload("res://scripts/minigames/desk.gd").install(main)   # main.gd, when a flight begins

const Kit := preload("res://scripts/ui/kit.gd")
const Dsn := preload("res://scripts/minigames/dsn.gd")
const Carrier := preload("res://scripts/minigames/carrier.gd")
const Triage := preload("res://scripts/minigames/triage.gd")
const Handoff := preload("res://scripts/minigames/handoff.gd")
const Telemetry := preload("res://scripts/minigames/telemetry.gd")
const Transfer := preload("res://scripts/flight/transfer.gd")
const Bots := preload("res://scripts/crew/bots.gd")
const UNIX_DAY0 := 1794700800          ## 15 November 2026 00:00 UTC: time zero of scripts/flight/transfer.gd.
const CARRIER_AFTER_S := 1800.0        ## Mission seconds after the burn to the Moon: far enough for the Deep Space Network.
const MONTH_S := 30.44 * 86400.0
const FAR_ORBITS := ["lunar", "l2"]    ## Craft the Deep Space Network follows; nearer ones use other stations.
const SQUIGGLES_BY := 0.45             ## Share of the mission by which "Read the squiggles" opens if no trouble came.
const ENDS := ["report", "menu", "ranking", "team", "missions", "design"]

var main
var human := false
var root: Control
var panel: PanelContainer
var tli_t := -1.0
var carrier_done := false
var handoff_done := false
var squiggles_done := false
var busy := false                      ## A game of the operation is open: the operation's time-lapse waits for it.


static func install(m) -> void:
	var old: Node = m.get_node_or_null("GroundDesk")
	if old:
		old.name = "GroundDeskOld"
		old.queue_free()
	var d = load("res://scripts/minigames/desk.gd").new()
	d.main = m
	d.name = "GroundDesk"
	m.add_child(d)


func _ready() -> void:
	layer = 6
	var room = GameState.room
	human = room != null and not room.is_bot("ground") and (not room.is_online() or room.mine("ground"))
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Kit.build_theme()
	add_child(root)
	GameState.ground_answer = _answer if human else Callable()
	GameState.flight_event.connect(_on_event)


func _exit_tree() -> void:
	if GameState.flight_event.is_connected(_on_event):
		GameState.flight_event.disconnect(_on_event)
	if GameState.ground_answer.is_valid() and GameState.ground_answer.get_object() == self:
		GameState.ground_answer = Callable()


func _on_event(kind: String, data: Dictionary) -> void:
	match kind:
		"tli":
			tli_t = float(data.get("met_s", -1.0))
			var fl = _flight()
			if fl:
				tli_t = fl.m.t
		"touchdown", "impact", "launch_lost":
			_close()


func _process(_delta: float) -> void:
	if main == null or not is_instance_valid(main) or main.screen_id in ENDS:
		queue_free()
		return
	var fl = _flight()
	if fl == null and panel and is_instance_valid(panel) and panel.get_child_count() > 0 and panel.get_child(0) is Carrier:
		panel.get_child(0)._finish("bot")      # the trip is over: Wayra locks it
	if fl and tli_t >= 0.0 and not carrier_done and fl.phase == "coast" and fl.m.t - tli_t >= CARRIER_AFTER_S:
		carrier_done = true
		_open_carrier(fl)
	if main.screen_id == "operation" and main.screen and not busy:
		_operation(main.screen)


## The flight screen while it shows the trip, or null.
func _flight():
	if main.screen_id == "flight" and main.screen and "m" in main.screen and main.screen.m:
		return main.screen
	return null


# ===================================================================================== THE CARRIER
func _open_carrier(fl) -> void:
	var m = fl.m
	var unix: float = UNIX_DAY0 + m.t
	var st: Dictionary = Dsn.best_station(unix, m.x, m.y)
	var dist: float = sqrt(m.x * m.x + m.y * m.y)
	var v: float = Dsn.radial(m.x, m.y, m.vx, m.vy)
	# the tone as the pass begins: time may run thousands of times faster meanwhile, and a line that races across
	# the waterfall could not be tuned (our simplification: the real tone drifts by a few hertz a second)
	var f0 := Dsn.doppler_hz(v)
	var f_now := func() -> float: return f0
	if not human:
		var words := tr("%s: %s has the craft's carrier, %d° up. Light time %.2f s.") % [Bots.NAMES.ground, st.name, roundi(st.elev), Dsn.light_s(dist)]
		Kit.toast(root, words, Kit.C_ACCENT, 3.5)
		_record("carrier", {"by": "bot", "bonus": 0, "station": st.id})
		return
	var g = Carrier.new()
	g.setup(st, f_now, Dsn.light_s(dist), v)
	g.done.connect(func(r: Dictionary):
		r["station"] = st.id
		_record("carrier", r)
		_close_later(r))
	_show(g)


# ===================================================================================== THE 1202
## GameState.ground_answer while a person holds the station: the failure's mini-game, then done(answer).
func _answer(failure: Dictionary, done: Callable) -> void:
	if str(failure.get("code", "")) != "1202":
		done.call({"go": true, "by": "bot", "bonus": 0, "words": tr("Ground here. We're go, keep flying.")})
		return
	var g = Triage.new()
	g.say = func(text: String, col: Color): Kit.toast(root, text, col, 1.2)
	g.setup(failure)
	g.done.connect(func(r: Dictionary):
		_record("1202", r)
		done.call(r)
		_close_later(r))
	_show(g)


# ===================================================================================== THE OPERATION (#63)
## Called each frame of the operation while no game is open: opens the next game when its moment has come.
func _operation(op) -> void:
	if not ("shown_month" in op) or op.leaving or is_instance_valid(op.alert):
		return
	var month: int = op.shown_month
	var sim: Dictionary = GameState.last_sim
	if month < 1 or sim.is_empty() or month >= int(sim.get("months", 0)):
		return
	var mission = GameState.mission
	if not handoff_done:
		handoff_done = true
		if mission.orbit in FAR_ORBITS or op.landed:
			_open_handoff(mission, month, op.landed)
			return
	if squiggles_done:
		return
	var c := {}
	var after := ""
	for e in sim.get("events", []):
		if int(e.month) >= 1 and int(e.month) <= month and e.kind != "good":
			c = Telemetry.case_for(str(e.title))
			if not c.is_empty():
				after = str(e.title)
				break
	if c.is_empty() and month >= maxi(2, int(sim.months * SQUIGGLES_BY)):
		c = Telemetry.fallback()
		after = tr("a burst of static on the screens")
	if c.is_empty():
		return
	squiggles_done = true
	_open_squiggles(c, after)


## Where the craft is in the sky (right ascension, declination) at a Unix time: the Moon from JPL Horizons
## (scripts/flight/transfer.gd, its days of data held at the last one), or for L2 the point opposite the Sun, whose
## ecliptic longitude comes from the U.S. Naval Observatory's low-precision formula [S-usno-sun].
static func sky_of(orbit: String, t_s: float) -> Vector2:
	if orbit == "l2":
		var d := t_s / 86400.0 + (UNIX_DAY0 / 86400.0 + 2440587.5 - 2451545.0)
		var g := deg_to_rad(357.529 + 0.98560028 * d)
		var lam := 280.459 + 0.98564736 * d + 1.915 * sin(g) + 0.020 * sin(2.0 * g)
		return Dsn.equatorial(fposmod(lam + 180.0, 360.0))
	var tr_m = Transfer.new()
	tr_m.setup()
	var last: float = maxf(0.0, (tr_m.rows.size() - 2) * Transfer.DAY)
	var p: Array = tr_m.moon(clampf(t_s, 0.0, last))
	return Dsn.equatorial(rad_to_deg(atan2(float(p[1]), float(p[0]))))


func _open_handoff(mission, month: int, landed: bool) -> void:
	var t_s := month * MONTH_S
	var target := tr("the Moon") if mission.orbit == "lunar" or landed else tr("your craft")
	if not human:
		Kit.toast(root, tr("%s: the dishes are passing %s from one to the next as the Earth turns.") % [Bots.NAMES.ground, target], Kit.C_ACCENT, 3.5)
		_record("handoff", {"by": "bot", "bonus": 0})
		return
	var g = Handoff.new()
	g.setup(sky_of(mission.orbit, t_s), UNIX_DAY0 + t_s, target)
	busy = true
	g.done.connect(func(r: Dictionary):
		busy = false
		_record("handoff", r)
		_close_later(r))
	_show(g, true)


func _open_squiggles(c: Dictionary, after: String) -> void:
	if not human:
		Kit.toast(root, tr("%s read the telemetry and sent the fix: %s.") % [Bots.NAMES.ground, tr(str(c.fixes[0]))], Kit.C_ACCENT, 3.5)
		_record("squiggles", {"by": "bot", "bonus": 0, "case": c.id})
		return
	var g = Telemetry.new()
	g.setup(c, Telemetry.channels(), after)
	busy = true
	g.done.connect(func(r: Dictionary):
		busy = false
		_record("squiggles", r)
		_close_later(r, 5.0))   # time to read the real story
	_show(g, true)


# ===================================================================================== PANEL AND RESULTS
func _show(game: Control, centred := false) -> void:
	_close()
	panel = Kit.panel_box(Kit.PAD)
	if Kit.compact or centred:   # on a phone in the middle, over the scene: there is no free corner
		var down := 0 if Kit.compact else 50   # in the operation, clear of the log's toasts under the top bar
		Kit.place(panel, 0.5, 0.5, 0.5, 0.5, -212, down, 212, down)
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	else:
		Kit.place(panel, 0, 0, 0, 0, Kit.MARGIN, 446, Kit.MARGIN + 424, 446)   # under the time panel, clear of the messages and the controls
	panel.add_child(game)
	root.add_child(panel)
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.3)
	Kit.UiSound.play("notify")


func _close_later(r: Dictionary, hold := 2.2) -> void:
	var p := panel
	if p == null:
		return
	if r.get("by", "") == "bot":
		Kit.toast(root, str(r.get("words", "")), Kit.C_ACCENT, 2.5)
	var tw := p.create_tween()
	tw.tween_interval(hold)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		if panel == p:
			panel = null
		p.queue_free())


func _close() -> void:
	if panel and is_instance_valid(panel):
		panel.queue_free()
	panel = null


## Keeps what ground control did in GameState.flight.ground ({"bonus", "done": {id: result}}) and, when a person
## solved it, tells it in the mission's log as good news.
func _record(id: String, r: Dictionary) -> void:
	var g: Dictionary = GameState.flight.get("ground", {"bonus": 0, "done": {}})
	g.done[id] = r
	g.bonus = int(g.bonus) + int(r.get("bonus", 0))
	GameState.flight["ground"] = g
	# a landed mission settled its bonus at touchdown (GameState.settle_extras): one won in the operation adds to it
	if GameState.flight.has("extras") and id in ["handoff", "squiggles"]:
		GameState.flight["bonus"] = int(GameState.flight.get("bonus", 0)) + int(r.get("bonus", 0))
	if r.get("by", "") == "player" and GameState.last_sim.has("events"):
		var titles := {"carrier": tr("Ground control · carrier locked"), "1202": tr("Ground control · go on the 1202"),
			"handoff": tr("Ground control · handed over without a gap"), "squiggles": tr("Ground control · telemetry read and fixed")}
		var month := 0
		if main and is_instance_valid(main) and main.screen_id == "operation" and "shown_month" in main.screen:
			month = int(main.screen.shown_month)
		GameState.last_sim.events.append({"month": month, "kind": "good", "title": titles.get(id, id), "text": str(r.get("words", ""))})
	GameState.flight_moment("ground", {"id": id, "by": r.get("by", ""), "bonus": int(r.get("bonus", 0))})
