extends RefCounted
## The crew's bots: they take every station no player holds and work like teammates. When the step of a bot's station
## comes, the bot picks what suits the mission, says why in one short line, and at the review it signs off.
##
## How a bot decides: every choice is tested with Mission.compute() on a copy of the design, so a bot only picks what
## the same rules the players face accept. The steps run in a fixed order (CHAIN); a bot plans the steps from its own
## onward on the copy and adopts only its own fields, so its pick already counts the parts that come after it (the
## power bot sizes the panels for the radio the ground bot will choose). Steps a person has touched are never
## overwritten. A bot can be wrong in taste, never in the rules, and it never blames the player.
##
## The lines are English msgids (translated with TranslationServer on the reader's side, so a room with players in two
## languages works); their arguments are numbers or "kind:id" references that each reader resolves in its own catalogs.
## All numbers and rules come from the game's data (data/*.json), which cite their sources.

const GD := preload("res://scripts/core/game_data.gd")
## Loaded when first used: a script started with -s is compiled before the autoloads Mission refers to exist.
static var _mission_script: GDScript

## The cuyes of the story hold the stations nobody takes (docs/design/crew/README.md): each one the station it has in
## the story, with its portrait (assets/story/portraits/).
const NAMES := {"engineer": "Rumi", "scientist": "Killa", "pilot": "Inti", "ground": "Wayra"}
const PORTRAITS := {"engineer": "res://assets/story/portraits/rumi.png", "scientist": "res://assets/story/portraits/killa.png",
	"pilot": "res://assets/story/portraits/inti.png", "ground": "res://assets/story/portraits/wayra.png"}
## The order of the steps in the game (data/steps.json); each entry is a step id of data/steps.json.
const CHAIN := ["orbita", "plataforma", "instrumentos", "energia", "comunicaciones", "control", "lanzador"]
## A step id the bots know how to decide is in CHAIN; a bot that meets any other step (the steps change as parts move
## into the builder) skips it: no change, no line. Who holds a step comes from data/steps.json, never from here.
## The order in which a plan works the parts out, by what each depends on.
const PLAN := ["orbita", "plataforma", "instrumentos", "comunicaciones", "control", "energia", "lanzador"]


## What the bot does at `step_id`: {"patch": {mission fields it changes}, "line": {"t", "a"}}.
## m is the design as it is now (a Mission); touched maps the step ids a person has edited.
static func act(step_id: String, m, touched: Dictionary) -> Dictionary:
	if not CHAIN.has(step_id):
		return {"patch": {}, "line": {}}
	var c = _copy(m)
	_plan(c, step_id, touched)
	var patch := {}
	var before: Dictionary = m.to_dict()
	var after: Dictionary = c.to_dict()
	for k in _fields(step_id):
		if after[k] != before[k]:
			patch[k] = after[k]
	return {"patch": patch, "line": _line(step_id, c)}


## The bot signs off at the review unless something blocks the launch. r is Mission.compute() of the design.
static func review(station: String, r: Dictionary) -> Dictionary:
	if r.fatal:
		return {"sign": false, "line": {"t": "Something in the review is still red. Fix it and I will sign right away.", "a": []}}
	var variant := _variant("revision" + station, 2)
	if r.goals.get(station, false):
		return {"sign": true, "line": {"t": ["My goal is met. Signed, and I am already humming the countdown.", "All my numbers are green. Signed. Let it fly."][variant], "a": []}}
	return {"sign": true, "line": {"t": ["My goal is not fully met, but nothing blocks the launch, and flying teaches more than waiting. Signed.", "Not perfect, and that is fine: there is no perfect design. Signed."][variant], "a": []}}


## The text of a line in the current language.
static func say(line: Dictionary) -> String:
	var args: Array = []
	for a in line.get("a", []):
		args.append(_resolve(a))
	var t: String = TranslationServer.translate(line.get("t", ""))
	return t % args if args.size() > 0 else t


static func _resolve(a) -> Variant:
	if a is String and ":" in a:
		var kind: String = a.get_slice(":", 0)
		var id: String = a.get_slice(":", 1)
		if kind == "instruments":
			var names: Array = []
			for i in id.split(","):
				names.append(GD.INSTRUMENTS[i].name if GD.INSTRUMENTS.has(i) else i)
			return ", ".join(PackedStringArray(names))
		var cat := {"orbit": GD.ORBITS, "bus": GD.BUSES, "instrument": GD.INSTRUMENTS, "panels": GD.PANELS, "battery": GD.BATTERIES,
			"comms": GD.COMMS, "adcs": GD.ADCS, "propulsion": GD.PROPULSION, "launcher": GD.LAUNCHERS}
		if cat.has(kind) and cat[kind].has(id):
			return cat[kind][id].name
	return a


# ===================================================================================== PLAN
static func _copy(m):
	if _mission_script == null:
		_mission_script = load("res://scripts/core/mission.gd")
	var c = _mission_script.new()
	c.from_dict(m.to_dict())
	return c


static func _fields(step_id: String) -> Array:
	return {"orbita": ["orbit"], "plataforma": ["bus"], "instrumentos": ["instruments"], "energia": ["panels", "battery"],
		"comunicaciones": ["comms"], "control": ["adcs", "propulsion", "redundancy", "shielding"],
		"lanzador": ["launcher", "years"]}.get(step_id, [])


## Plans the design from `from_step` on over the copy c. Steps before it are decided and stay as they are; later steps a
## person touched stay too. The plan runs in the order the parts depend on each other (PLAN), not the order of the steps.
static func _plan(c, from_step: String, touched: Dictionary) -> void:
	for id in PLAN:
		if _skipped(id, from_step, touched):
			continue
		if id == "plataforma":
			_pick_bus(c, from_step, touched)
		else:
			_apply(c, id)


static func _skipped(id: String, from_step: String, touched: Dictionary) -> bool:
	if id == from_step:
		return false
	return CHAIN.find(id) < CHAIN.find(from_step) or touched.get(id, false)


static func _apply(c, id: String) -> void:
	match id:
		"orbita": _pick_orbit(c)
		"instrumentos": _pick_instruments(c)
		"comunicaciones": _pick_comms(c)
		"control": _pick_control(c)
		"energia": _pick_power(c)
		"lanzador": _pick_launcher(c)


## The smallest platform on which the rest of the plan closes: no red item and a reserve of at least 10 %.
static func _pick_bus(c, from_step: String, touched: Dictionary) -> void:
	var best := ""
	var best_score := -INF
	for b in GD.BUSES:
		var t = _copy(c)
		t.bus = b
		for id in PLAN:
			if id != "plataforma" and not _skipped(id, from_step, touched) and id != "orbita":
				_apply(t, id)
		var r: Dictionary = t.compute()
		var score: float = r.reserve - (10.0 if r.fatal else 0.0)
		if not r.fatal and r.reserve >= 0.10:
			best = b
			break
		if score > best_score:
			best_score = score
			best = b
	c.bus = best
	# The bus changed what the later steps should pick, so they follow it.
	for id in PLAN:
		if id != "plataforma" and id != "orbita" and not _skipped(id, from_step, touched):
			_apply(c, id)


static func _pick_orbit(c) -> void:
	var S: Dictionary = GD.SCENARIOS[c.scenario]
	var best := ""
	var best_m := -1.0
	for o in GD.ORBITS:
		var mult: float = S.orbit_mult.get(o, 0.0)
		if mult > best_m + 0.001 or (absf(mult - best_m) <= 0.001 and GD.ORBITS[o].insert_dv < GD.ORBITS[best].insert_dv):
			best = o
			best_m = mult
	c.orbit = best


static func _relevance(S: Dictionary, I: Dictionary) -> float:
	var default_rel: float = S.get("default_relevance", 0.1)
	if S.relevance.is_empty():
		return default_rel
	var rel := 0.0
	for t in I.tags:
		rel = maxf(rel, S.relevance.get(t, default_rel))
	return rel


static func _pick_instruments(c) -> void:
	var S: Dictionary = GD.SCENARIOS[c.scenario]
	var B: Dictionary = GD.BUSES[c.bus]
	var chosen: Array = []
	for n in S.needs:
		var covered := false
		for id in chosen:
			for t in GD.INSTRUMENTS[id].tags:
				if n.any.has(t):
					covered = true
		if covered:
			continue
		var pick := ""
		for i in GD.INSTRUMENTS:
			var I: Dictionary = GD.INSTRUMENTS[i]
			var hit := false
			for t in I.tags:
				if n.any.has(t):
					hit = true
			if not hit or I.size > B.max_size:
				continue
			if pick == "" or _rank(S, I) > _rank(S, GD.INSTRUMENTS[pick]):
				pick = i
		if pick != "" and chosen.size() < B.slots:
			chosen.append(pick)
	# One extra instrument when the platform has a free slot and a useful one fits, if the design still closes with it.
	var extra := ""
	if chosen.size() < B.slots and chosen.size() < 3:
		for i in GD.INSTRUMENTS:
			var I: Dictionary = GD.INSTRUMENTS[i]
			if chosen.has(i) or I.size > B.max_size or _relevance(S, I) < 0.5:
				continue
			if extra == "" or _rank(S, I) > _rank(S, GD.INSTRUMENTS[extra]):
				extra = i
	if extra != "":
		var t = _copy(c)
		t.instruments = chosen + [extra]
		for id in ["comunicaciones", "control", "energia", "lanzador"]:
			_apply(t, id)
		var r: Dictionary = t.compute()
		if not r.fatal and r.reserve >= 0.15:
			chosen.append(extra)
	c.instruments = chosen


## What a careful scientist ranks by: relevance for the goal first, then science per month, then cost and mass.
static func _rank(S: Dictionary, I: Dictionary) -> float:
	return _relevance(S, I) * 10.0 + I.sci / 100.0 - I.cost * 0.01 - I.mass * 0.001


static func _pick_comms(c) -> void:
	var pick := ""
	for k in GD.COMMS:
		pick = k
		c.comms = k
		if c.compute().data_ratio >= 1.15:
			break
	c.comms = pick


static func _pick_control(c) -> void:
	c.years = maxi(c.years, GD.SCENARIOS[c.scenario].min_years)
	var pick := ""
	for a in GD.ADCS:
		pick = a
		c.adcs = a
		if c.compute().pointing_bad.is_empty():
			break
	c.adcs = pick
	pick = ""
	for p in GD.PROPULSION:
		pick = p
		c.propulsion = p
		var r: Dictionary = c.compute()
		if r.dv_have >= r.dv_need:
			break
	c.propulsion = pick
	var rad: int = GD.ORBITS[c.orbit].radiation
	c.shielding = rad >= 2
	c.redundancy = rad >= 3


static func _pick_power(c) -> void:
	var pick := ""
	for p in GD.PANELS:
		pick = p
		c.panels = p
		if c.compute().power_margin >= 0.2:
			break
	c.panels = pick
	pick = ""
	for b in GD.BATTERIES:
		pick = b
		c.battery = b
		if c.compute().battery_ratio >= 1.1:
			break
	c.battery = pick


static func _pick_launcher(c) -> void:
	if c.launcher == "custom":
		return   # the player built a rocket (RocketDesign.CUSTOM): a bot never swaps it for a catalog one
	c.years = maxi(c.years, GD.SCENARIOS[c.scenario].min_years)
	var pick := ""
	var pick_cost := INF
	for l in GD.LAUNCHERS:
		c.launcher = l
		var r: Dictionary = c.compute()
		if r.launch_cap > 0.0 and r.launch_cap >= r.mass_total and r.cost.launch < pick_cost:
			pick = l
			pick_cost = r.cost.launch
	if pick == "":
		pick = GD.LAUNCHERS.keys()[GD.LAUNCHERS.size() - 1]
	c.launcher = pick


# ===================================================================================== WORDS
static func _variant(key: String, n: int) -> int:
	return absi(key.hash()) % n


## One short, friendly line about what the bot chose and why.
static func _line(step_id: String, c) -> Dictionary:
	var v := _variant(step_id + c.scenario, 2)
	var S: Dictionary = GD.SCENARIOS[c.scenario]
	match step_id:
		"orbita":
			var mult: float = S.orbit_mult.get(c.orbit, 0.0)
			return {"t": ["I chose %s: for this goal it multiplies the science by %.1f. Fewer burns, fewer prayers.",
				"%s it is, with science at x%.1f. The best seat in the house for this goal."][v], "a": ["orbit:" + c.orbit, mult]}
		"plataforma":
			return {"t": ["I picked %s: the smallest platform where everything fits and the budget still sleeps. Bigger is not better, just heavier.",
				"%s. It carries what the mission needs and not a gram of ego."][v], "a": ["bus:" + c.bus]}
		"instrumentos":
			if c.instruments.is_empty():
				return {"t": "No instrument is needed for this goal, so I left the shelf alone.", "a": []}
			return {"t": ["I put on board: %s. They cover what the goal asks for, and nothing else wants a ride.",
				"On the list: %s. Each one earns its slot."][v], "a": ["instruments:" + ",".join(PackedStringArray(c.instruments))]}
		"energia":
			return {"t": ["%s with %s: enough power for the whole mission, shadow included. Nobody likes working in the dark.",
				"Panels %s and battery %s. We keep the lights on, even behind the Earth."][v], "a": ["panels:" + c.panels, "battery:" + c.battery]}
		"comunicaciones":
			return {"t": ["I chose %s: it sends down everything the instruments make. Data that never reaches Earth is data lost.",
				"%s, because the science only counts once Earth has heard it."][v], "a": ["comms:" + c.comms]}
		"control":
			return {"t": ["I set %s for pointing and %s for the burns. Enough to arrive and stay, with a little to spare.",
				"%s keeps us aimed and %s gets us there. Simple, and it fits."][v], "a": ["adcs:" + c.adcs, "propulsion:" + c.propulsion]}
		"lanzador":
			return {"t": ["%s: the cheapest rocket that can lift us to this orbit, for %d year(s) of mission. We do not hire more rocket than we need.",
				"%s is the one. It lifts the craft, it fits the wallet, and %d year(s) of work are ahead."][v], "a": ["launcher:" + c.launcher, c.years]}
	return {"t": "Done.", "a": []}
