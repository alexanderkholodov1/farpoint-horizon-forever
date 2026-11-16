extends RefCounted
## A rocket the player assembles from parts (data/parts.json, models in assets/parts/): what it is, what it can do, and
## its 3D model. Used by the builder screen, by the mission model (as the launcher "custom") and by the launch screen.
##
## The stack is a list of part ids from the bottom up. Decouplers split it into stages: a stage is everything from the
## part above the previous decoupler up to and including the next decoupler (the top stage carries the fairing and the
## craft). Boosters, if any, are a pair strapped to the first stage and burn together with it.
##
## The performance is the rocket equation [S10] integrated over the burn, stage by stage, with boosters burning in
## parallel with the first stage until they are empty. The first stage uses the mean of its sea-level and vacuum
## values (it starts in air and ends near vacuum); upper stages use vacuum values. A sea-level engine keeps its mass
## flow in vacuum, so its vacuum thrust is its sea-level thrust x Isp_vac / Isp_sl. Simplified: no trajectory; the
## losses to gravity and drag are inside the delta-v targets [S-delta-v]; the fairing is carried to the end (conservative).

const PARTS_PATH := "res://data/parts.json"
const CUSTOM := "custom"   ## The launcher id the mission uses for the player's rocket.
const SELF_PATH := "res://scripts/craft/rocket_design.gd"

static var _data: Dictionary = {}
static var current = null   ## The rocket the player built for this mission (an instance of this script), or null.

var stack: Array = []      ## Part ids, bottom to top.
var boosters := ""         ## Part id of the booster pair strapped to the first stage, or "".


# ===================================================================================== DATA
static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PARTS_PATH, FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text())
	return _data


static func part(id: String) -> Dictionary:
	return data().parts[id]


static func from_preset(preset_id: String):
	var p: Dictionary = data().presets[preset_id]
	var d = load(SELF_PATH).new()
	d.stack = p.stack.duplicate()
	d.boosters = p.boosters
	return d


func copy():
	var d = load(SELF_PATH).new()
	d.stack = stack.duplicate()
	d.boosters = boosters
	return d


# ===================================================================================== STRUCTURE
## Stages from the bottom: each an Array of part ids.
func stages() -> Array:
	var out: Array = [[]]
	for id in stack:
		out[-1].append(id)
		if part(id).category == "decoupler":
			out.append([])
	if out[-1].is_empty() and out.size() > 1:
		out.pop_back()
	return out


## Problems that stop the rocket from flying, in plain words. Empty when it can fly.
func problems() -> Array:
	var out: Array = []
	if stack.is_empty():
		return ["Add parts, starting with engines at the bottom."]
	var st := stages()
	for i in st.size():
		var s: Array = st[i]
		var has_engine := false
		var has_tank := false
		for id in s:
			has_engine = has_engine or part(id).category == "engine"
			has_tank = has_tank or part(id).category == "tank"
		if not has_engine:
			out.append("Stage %d has no engine." % (i + 1))
		if not has_tank:
			out.append("Stage %d has no fuel tank." % (i + 1))
	if part(stack[0]).category != "engine":
		out.append("The bottom part must be an engine.")
	if part(stack[0]).get("vacuum_only", false):
		out.append("The bottom engine only works in vacuum: it cannot lift off from the ground.")
	if part(stack[-1]).category != "fairing":
		out.append("Put a fairing on top to protect the craft.")
	return out


func total_cost() -> float:
	var c := 0.0
	for id in stack:
		c += part(id).cost_musd
	if boosters != "":
		c += part(boosters).cost_musd * part(boosters).get("count", 1)
	return c


func mass_kg(payload_kg := 0.0) -> float:
	var m := payload_kg
	for id in stack:
		m += part(id).dry_kg + part(id).get("propellant_kg", 0.0)
	if boosters != "":
		var b := part(boosters)
		m += (b.dry_kg + b.propellant_kg) * b.get("count", 1)
	return m


func height_m() -> float:
	var h := 0.0
	for id in stack:
		h += _part_height(id)
	return h


## Thrust at liftoff over weight. Above 1 the rocket rises; real rockets lift off at about 1.2 to 1.5.
func liftoff_twr(payload_kg := 0.0) -> float:
	if stack.is_empty():
		return 0.0
	var f := 0.0
	for id in stages()[0]:
		f += part(id).get("thrust_sl_kn", 0.0)
	if boosters != "":
		f += part(boosters).thrust_sl_kn * part(boosters).get("count", 1)
	return f * 1000.0 / (mass_kg(payload_kg) * float(data().g0))


# ===================================================================================== PERFORMANCE
## Delta-v in m/s with payload_kg on top, and the delta-v of each stage.
func performance(payload_kg := 0.0) -> Dictionary:
	var g0: float = data().g0
	var st := stages()
	var m := mass_kg(payload_kg)
	var per_stage: Array = []
	var total := 0.0
	var b := part(boosters) if boosters != "" else {}
	var b_count: float = b.get("count", 0)
	var b_prop: float = b.get("propellant_kg", 0.0) * b_count
	for i in st.size():
		var s: Array = st[i]
		var thrust := 0.0   # N
		var mdot := 0.0     # kg/s
		var prop := 0.0
		var dry := 0.0
		for id in s:
			var p := part(id)
			prop += p.get("propellant_kg", 0.0)
			dry += p.dry_kg
			if p.category == "engine":
				var f_n := _engine_thrust(p, i == 0) * 1000.0
				thrust += f_n
				mdot += f_n / (_engine_isp(p, i == 0) * g0)
		var dv := 0.0
		if thrust > 0.0 and prop > 0.0:
			# boosters burn in parallel with the first stage
			if i == 0 and b_prop > 0.0:
				var fb: float = b.thrust_sl_kn * 1000.0 * b_count * (1.0 + b.isp_vac_s / b.isp_sl_s) / 2.0
				var mdot_b: float = fb / ((b.isp_sl_s + b.isp_vac_s) / 2.0 * g0)
				var t_b: float = b_prop / mdot_b
				var t_core := prop / mdot
				var t := minf(t_b, t_core)
				dv += _burn_dv(m, thrust + fb, mdot + mdot_b, t)
				m -= (mdot + mdot_b) * t
				prop -= mdot * t
				m -= b.dry_kg * b_count + maxf(0.0, b_prop - mdot_b * t)   # boosters drop (with any fuel left)
			dv += _burn_dv(m, thrust, mdot, prop / mdot)
			m -= prop
		else:
			m -= prop   # a stage that cannot burn drops its fuel with it
		m -= dry
		per_stage.append(dv)
		total += dv
	return {"dv": total, "stages": per_stage}


## Most payload (kg) this rocket can send toward `orbit` (a key of data().targets); 0 if it cannot fly.
func capacity_kg(orbit: String) -> float:
	if not problems().is_empty() or liftoff_twr(0.0) < 1.0:
		return 0.0
	var target: float = data().targets[orbit]
	if performance(0.0).dv < target:
		return 0.0
	var lo := 0.0
	var hi := 200000.0
	for _i in 40:
		var mid := (lo + hi) / 2.0
		if performance(mid).dv >= target and liftoff_twr(mid) >= 1.0:
			lo = mid
		else:
			hi = mid
	return floorf(lo)


## The launcher entry the mission model reads (same fields as GameData.LAUNCHERS).
func launcher_info() -> Dictionary:
	var cap := {}
	for o in data().targets:
		if o.begins_with("_"):
			continue
		cap[o] = capacity_kg(o)
	return {"name": "Your rocket", "cap": cap, "cost_per_kg": 0.0, "cost": total_cost(), "min_cost": 0.0,
		"fail": float(data().failure_chance.value), "delay": 0.1,
		"desc": "The rocket you assembled, part by part.", "height": 1.3}


## The launcher entry for a launcher id, the player's rocket included.
static func launcher(id: String) -> Dictionary:
	if id == CUSTOM and current != null:
		return current.launcher_info()
	return GameData.LAUNCHERS[id if GameData.LAUNCHERS.has(id) else "medium"]


# ===================================================================================== 3D
## The assembled rocket at real size (metres), origin at the bottom of the stack. Its children are "Stage0",
## "Stage1"... (each with its parts) and "Boosters", so a stage can be dropped by detaching its node.
func build_model() -> Node3D:
	var root := Node3D.new()
	root.name = "Assembled"
	var y := 0.0
	var st := stages()
	var first_tank_y := -1.0
	for i in st.size():
		var sn := Node3D.new()
		sn.name = "Stage%d" % i
		root.add_child(sn)
		for id in st[i]:
			var inst := _instance(id)
			var bottom := _attach(inst, "Attach_Bottom")
			inst.position = Vector3(0, y - bottom, 0)
			sn.add_child(inst)
			if i == 0 and first_tank_y < 0.0 and part(id).category == "tank":
				first_tank_y = y
			y += _attach(inst, "Attach_Top") - bottom
	if boosters != "":
		var bn := Node3D.new()
		bn.name = "Boosters"
		root.add_child(bn)
		var core_r: float = part(stack[0]).family / 2.0
		for s in [-1.0, 1.0]:
			var b := _instance(boosters)
			b.position = Vector3(s * (core_r + 3.71 / 2.0 + 0.4), maxf(first_tank_y, 0.0) - 3.0, 0)
			bn.add_child(b)
	return root


func _instance(id: String) -> Node3D:
	var n: Node3D = load(part(id).model).instantiate()
	n.name = id
	return n


static func _attach(n: Node3D, which: String) -> float:
	var a := n.find_child(which, true, false) as Node3D
	return a.position.y if a else 0.0


static var _heights := {}
static func _part_height(id: String) -> float:
	if not _heights.has(id):
		var n: Node3D = load(part(id).model).instantiate()
		_heights[id] = _attach(n, "Attach_Top") - _attach(n, "Attach_Bottom")
		n.free()
	return _heights[id]


static func _engine_thrust(p: Dictionary, first_stage: bool) -> float:
	if p.get("vacuum_only", false):
		return p.thrust_vac_kn * (0.0 if first_stage else 1.0)
	var vac: float = p.thrust_sl_kn * p.isp_vac_s / p.isp_sl_s
	return (p.thrust_sl_kn + vac) / 2.0 if first_stage else vac


static func _engine_isp(p: Dictionary, first_stage: bool) -> float:
	if p.get("vacuum_only", false):
		return p.isp_vac_s
	return (p.isp_sl_s + p.isp_vac_s) / 2.0 if first_stage else p.isp_vac_s


## Rocket equation over a burn of t seconds from mass m0 with constant thrust and mass flow [S10].
static func _burn_dv(m0: float, thrust: float, mdot: float, t: float) -> float:
	if mdot <= 0.0 or t <= 0.0:
		return 0.0
	var ve := thrust / mdot
	var m1 := maxf(m0 - mdot * t, 1.0)
	return ve * log(m0 / m1)
