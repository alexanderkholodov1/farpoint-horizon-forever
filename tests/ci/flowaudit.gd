extends SceneTree
## The flow audit's numbers (issue #57): the durations the game computes, checked against the real ones a player may
## know. The climb to orbit [S-nasa-crew10], the trip to the Moon [S-apollo11], a lap of a low lunar orbit and the
## periods the design and the operation screens show (Kepler's third law with the NSSDC constants [S-nssdc-planets]).
## The audit itself, played screen by screen, is docs/state/flow-audit.md.
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/flowaudit.gd
## check: flow audit: 0 failure

const Ascent := preload("res://scripts/flight/ascent.gd")
const Transfer := preload("res://scripts/flight/transfer.gd")
const FlightData := preload("res://scripts/flight/flight_data.gd")

## A Falcon 9 reaches orbit (SECO-1) about nine minutes after liftoff [S-nasa-crew10]; the game's launchers are of that
## kind, so a climb flown by the flight computer must end within these bounds (seconds).
const CLIMB_S := [420.0, 600.0]
## Apollo 11 entered lunar orbit about 76 hours after launch [S-apollo11]; from the burn to the Moon (about three hours
## after launch) that is about 73 hours. Bounds for the game's coast, burn to closest pass (hours).
const TRIP_H := [60.0, 96.0]
## A lap of a 100-110 km lunar orbit takes about two hours (Kepler with [S-nssdc-planets]); the game says "a lap about
## every two hours" when the craft is captured.
const LUNAR_LAP_MIN := [110.0, 125.0]

var failures := 0


func _initialize() -> void:
	_climb()
	_trip()
	_periods()
	print("flow audit: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures += 1


## Seconds of mission time a circular orbit of height h over a body of radius r and GM mu takes for a lap.
func _period_s(mu: float, r: float, h: float) -> float:
	var a := r + h
	return TAU * sqrt(a * a * a / mu)


## The climb, flown by the flight computer's rule (keep the marker) at the screen's ×10, staging when asked.
func _climb() -> void:
	for l in ["light", "medium", "heavy"]:
		var a = Ascent.new()
		a.setup(l, 2000.0, "lunar")
		var dt := 1.0 / 60.0
		for _i in 60 * 200:
			a.step(dt, clampf((a.marker - a.pitch) * 0.5, -1.0, 1.0), 10.0)
			if a.wants_stage():
				a.stage()
			if a.orbit or a.broken or a.crashed:
				break
		print("climb ", l, ": ", snappedf(a.t, 0.1), " s to ", "orbit" if a.orbit else "no orbit")
		_check(a.orbit and a.t >= CLIMB_S[0] and a.t <= CLIMB_S[1],
			"the %s launcher reaches orbit in %d-%d s, like a real climb (about nine minutes)" % [l, CLIMB_S[0], CLIMB_S[1]])


## The trip the planners give for the burn the game asks for, from the burn to the closest pass over the Moon.
func _trip() -> void:
	var m = Transfer.new()
	m.setup()
	var rp: float = m.r_e + 166000.0
	var t0 := 13.0 * 3600.0
	m.place_circular(rp, 0.0, t0)
	var dv := 3150.0
	var plan: Dictionary = m.plan_departure(rp, 0.0, t0, dv, 3.0, m.burn_time(dv) * 0.5 + 240.0)
	_check(not plan.is_empty(), "the planners find a departure")
	if plan.is_empty():
		return
	var trip_h: float = (float(plan.pass.t_closest) - float(plan.time)) / 3600.0
	print("trip: ", snappedf(trip_h, 0.1), " h from the burn to the pass")
	_check(trip_h >= TRIP_H[0] and trip_h <= TRIP_H[1], "the coast to the Moon takes about three days (%d-%d h)" % [TRIP_H[0], TRIP_H[1]])


## The periods the player reads: the lap of the lunar orbit after the capture, and every Earth or lunar orbit of
## data/orbits.json against Kepler at the height in its name.
func _periods() -> void:
	var mu_m := FlightData.gm("moon")
	var r_m := FlightData.radius_m("moon")
	var lap_min := _period_s(mu_m, r_m, Transfer.PERISELENE) / 60.0
	print("lunar lap at ", roundi(Transfer.PERISELENE / 1000.0), " km: ", snappedf(lap_min, 0.1), " min")
	_check(lap_min >= LUNAR_LAP_MIN[0] and lap_min <= LUNAR_LAP_MIN[1], "a lap of the lunar orbit takes about two hours")
	var orbits: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orbits.json")).entries
	var rx := RegEx.new()
	rx.compile(r"\(([0-9,]+) km\)")
	for id in orbits:
		var o: Dictionary = orbits[id]
		var found := rx.search(str(o.name))
		if found == null:
			continue   # a point (L2), not a circular orbit
		var h := float(found.get_string(1).replace(",", "")) * 1000.0
		var on_moon := str(o.get("body", "")) == "luna"
		var mu := mu_m if on_moon else FlightData.gm("earth")
		var r := r_m if on_moon else FlightData.radius_m("earth")
		var real_min := _period_s(mu, r, h) / 60.0
		var shown := float(o.period_min)
		print("orbit ", id, ": shows ", shown, " min, Kepler ", snappedf(real_min, 0.1), " min")
		_check(absf(shown - real_min) / real_min < 0.03, "the %s period on screen is within 3 %% of the real one" % id)
