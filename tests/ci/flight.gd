extends SceneTree
## The pilot's flight, played by scripted hands (issue #8): the climb to orbit flown by the bot pilot, by a sloppy
## pilot and by one who tries to break the rocket; the landing flown by the bot, by players with slow reflexes, and
## by one who never touches the throttle. Prints what happened; fails if the generous cases do not end well or the
## deliberate ones do not end badly.
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/flight.gd
## check: flight test: 0 failure

const Ascent := preload("res://scripts/flight/ascent.gd")
const GD := preload("res://scripts/core/game_data.gd")
const Terrain := preload("res://scripts/flight/terrain.gd")
const Descent := preload("res://scripts/flight/descent.gd")
const Transfer := preload("res://scripts/flight/transfer.gd")
const FlightData := preload("res://scripts/flight/flight_data.gd")

var failures := 0


func _initialize() -> void:
	_ascent_cases()
	_landing_cases()
	_transfer_cases()
	print("flight test: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures += 1


## Flies a climb with a pilot function f(a) -> steer, staging when asked. Returns the summary.
func _fly(launcher: String, pilot: Callable, stage_delay := 0.5) -> Dictionary:
	var a = Ascent.new()
	a.setup(launcher, 2000.0, "lunar")
	var dt := 1.0 / 60.0
	var wait := 0.0
	for _i in 60 * 120:
		a.step(dt, pilot.call(a), 8.0)    # a player at ×8 time warp
		if a.wants_stage():
			wait += dt
			if wait > stage_delay:
				a.stage()
				wait = 0.0
		if a.orbit or a.broken or a.crashed:
			break
	var s: Dictionary = a.summary()
	s.game_s = a.t / 8.0
	return s


func _ascent_cases() -> void:
	var bot := func(a): return clampf((a.marker - a.pitch) * 0.5, -1.0, 1.0)
	for l in ["light", "medium", "heavy"]:
		var s := _fly(l, bot)
		print("bot ", l, " ", s)
		_check(s.orbit and not s.broken, "the bot pilot reaches orbit on the %s launcher" % l)
	# a lazy pilot who only steers every few seconds, late
	var lazy := func(a): return clampf(a.marker - a.pitch - 8.0, -1.0, 1.0) if int(a.t) % 40 < 8 else 0.0
	var s2 := _fly("medium", lazy, 3.0)
	print("lazy ", s2)
	_check(s2.orbit and not s2.broken, "a lazy pilot still reaches orbit")
	# a pilot who does nothing at all
	var idle := func(_a): return 0.0
	var s3 := _fly("medium", idle, 3.0)
	print("idle ", s3)
	_check(s3.orbit and not s3.broken and float(s3.own_share) == 0.0, "a pilot who does nothing still reaches orbit: the flight computer flies it")
	# someone who holds the stick hard over at max-Q on purpose
	var wild := func(a): return 1.0 if a.h > 6000.0 else 0.0
	var s4 := _fly("medium", wild)
	print("wild ", s4)
	_check(s4.broken or s4.crashed, "holding the stick hard over at max-Q breaks the rocket")


## Flies the landing with a pilot function f(d) -> [throttle, steer]; a pilot who lets go for HANDS_OFF seconds gets
## the flight computer, as on the landing screen. Returns the touchdown result.
func _land(pilot: Callable, terrain, help := true) -> Dictionary:
	var d = Descent.new()
	d.setup(FlightData.scenario_flight("moon_south_pole").landing, terrain)
	var dt := 1.0 / 30.0
	var idle := 0.0
	for _i in 30 * 400:
		var a: Array = pilot.call(d)
		if a.is_empty():
			idle += dt
		else:
			idle = 0.0
		if a.is_empty() or (help and idle > 2.5):
			a = d.bot() if (help or not a.is_empty()) else [0.0, Vector2.ZERO]
		d.step(dt, a[0], a[1])
		if d.done:
			break
	return d.result


func _landing_cases() -> void:
	var t0 := Time.get_ticks_msec()
	var terrain = Terrain.new()
	terrain.setup(FlightData.scenario_flight("moon_south_pole").landing)
	print("terrain ready in ", Time.get_ticks_msec() - t0, " ms; shadow cells near the target ", terrain.shadow_pts.size(),
		"; target slope ", snappedf(terrain.slope_deg(0, 0), 0.1), " deg; earth in view at the target ", terrain.sees_earth(Vector3(0, 2, 0)))
	_check(terrain.slope_deg(0, 0) < 8.0, "the landing target is flat enough to land on")
	var bot := func(d): return d.bot()
	var r1 := _land(bot, terrain)
	print("bot lander ", r1)
	_check(r1.get("landed", false) and r1.grade in ["soft", "good"], "the bot lander sets down softly")
	_check(float(r1.get("target_m", 999.0)) < 60.0, "the bot lander lands near the target")
	# a slow pilot: only touches the throttle every few seconds, late, and never steers
	var slow := func(d):
		if int(d.t) % 6 < 2:
			return [0.9 if d.vel.y < -4.0 else 0.2, Vector2.ZERO]
		return []
	var r2 := _land(slow, terrain)
	print("slow pilot ", r2)
	_check(r2.get("landed", false), "a slow pilot still lands")
	# someone who never touches anything at all: the flight computer lands
	var idle := func(_d): return []
	var r3 := _land(idle, terrain)
	print("idle pilot ", r3)
	_check(r3.get("landed", false), "a pilot who never touches anything still lands")
	# someone who holds the engine off on purpose all the way down
	var off := func(_d): return [0.0, Vector2.ZERO]
	var r4 := _land(off, terrain)
	print("engine off ", r4)
	_check(r4.get("grade", "") == "crater", "holding the engine off all the way down makes a crater")


## The trip to the Moon against real numbers (issue #8): the parking orbit's period, the planners' departure, a burn
## flown as the flight computer flies it, the mid-course correction and the capture into lunar orbit.
func _transfer_cases() -> void:
	var m = Transfer.new()
	m.setup()
	var rp: float = m.r_e + 166000.0
	var t0 := 13.0 * 3600.0
	var period := TAU * sqrt(rp * rp * rp / m.mu_e)
	print("parking orbit: ", snappedf(period / 60.0, 0.1), " min, ", snappedf(sqrt(m.mu_e / rp), 1.0), " m/s")
	_check(period > 87.0 * 60.0 and period < 89.0 * 60.0, "a low Earth orbit takes about 88 minutes")
	m.place_circular(rp, 0.0, t0)
	var dv := 3150.0
	var plan: Dictionary = m.plan_departure(rp, 0.0, t0, dv, 3.0, m.burn_time(dv) * 0.5 + 240.0)
	_check(not plan.is_empty(), "the planners find a departure that meets the Moon")
	if plan.is_empty():
		return
	var trip_h: float = (float(plan.pass.t_closest) - float(plan.time)) / 3600.0
	print("plan: burn at ", snappedf(rad_to_deg(plan.angle), 0.01), " deg, pass ", roundi(m.pass_height(plan.pass) / 1000.0), " km, trip ", snappedf(trip_h, 0.1), " h")
	_check(absf(m.pass_height(plan.pass) - Transfer.PERISELENE) < 5000.0, "the plan passes about 110 km over the Moon")
	_check(trip_h > 60.0 and trip_h < 100.0, "the trip takes three to four days, like Apollo's")
	m.advance(float(plan.time) - m.burn_time(dv) * 0.5 - m.t)
	var t_b: float = m.t
	while m.dv_used < dv:
		m.advance(minf(0.5, (dv - m.dv_used) / m.accel()), 1.0)
	var burn_s: float = m.t - t_b
	var v: float = sqrt(m.vx * m.vx + m.vy * m.vy)
	print("burn: ", roundi(burn_s), " s to ", roundi(v), " m/s")
	_check(burn_s > 330.0 and burn_s < 365.0 and v > 10600.0 and v < 10950.0, "the burn takes about Apollo 11's 5 min 47 s [S-afj11-tli] and leaves at about 10.8 km/s")
	m.use_engine("craft")
	m.advance(6.0 * 3600.0)
	var c: Dictionary = m.plan_correction()
	_check(not c.is_empty() and absf(float(c.dv)) < 100.0, "a mid-course correction under 100 m/s brings the pass to 110 km")
	if c.is_empty():
		return
	m.kick(c.dv)
	var p: Dictionary = m.predict(m.state(), m.t)
	var cap_s: float = m.burn_time(m.capture_dv(p))
	m.advance(float(p.t_closest) - cap_s * 0.5 - m.t)
	var used0: float = m.dv_used
	var t_c: float = m.t
	while m.moon_orbit().high > 160000.0:
		m.advance(0.5, 1.0, -1.0, true)
	var o: Dictionary = m.moon_orbit()
	print("correction ", snappedf(float(c.dv), 0.1), " m/s; capture ", roundi(m.dv_used - used0), " m/s in ", roundi(m.t - t_c), " s into ", roundi(o.low / 1000.0), " x ", roundi(o.high / 1000.0), " km")
	# Apollo 11's braking burn: 889 m/s in 6 min 2 s with the service module's engine [S-afj11-loi]
	_check(m.t - t_c > 300.0 and m.t - t_c < 450.0, "the braking burn takes about six minutes, as Apollo 11's did")
	_check(o.low > 50000.0 and o.high < 200000.0, "the capture burn leaves a low orbit around the Moon")
