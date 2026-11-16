extends RefCounted
## The trip from Earth orbit to the Moon, as numbers: no screen, so the flight screen and tests/ci/flight.gd fly the same
## physics. Real time in seconds; the screen chooses how fast it runs (its time warp).
##   - The Earth and the Moon pull the craft (their GM and size from NSSDC [S-nssdc-planets]). The frame is centred on
##     the Earth, which itself falls toward the Moon, so the Moon's pull on the Earth is subtracted (the indirect term).
##   - The Moon is where JPL Horizons puts it on the day of the flight [S-horizons]: one row per day from 15 November
##     2026, joined smoothly with the velocities of each row (cubic Hermite).
##   - Our simplifications: everything in the plane of the ecliptic (the Moon's 5 degree tilt left out), the Sun's pull
##     left out, the engine always pointed exactly along or against the motion.
##   - The engines burn by the rocket equation [S10]: push = thrust / mass, and the mass falls as propellant burns, so
##     a burn starts gentle and ends hard. Two engines (data/engines.json): the departure stage for the burn to the Moon,
##     the craft's own engine for the correction and the braking (Apollo 11's, [S-afj11-tli] [S-afj11-loi]).
## Positions and speeds are floats (64-bit): Vector2 is 32-bit, which loses metres at the Moon's distance.
##   const Transfer := preload("res://scripts/flight/transfer.gd")

const FlightData := preload("res://scripts/flight/flight_data.gd")
const DAY := 86400.0
const ENGINES := "res://data/engines.json"
const PERISELENE := 110000.0    ## Height over the Moon the planners aim for, metres (Apollo's lunar orbits were about this).
const SOI := 6.61e7         ## The Moon's sphere of influence, metres: inside it the Moon's pull wins.

var mu_e := 3.986e14
var mu_m := 4.905e12
var r_e := 6.371e6
var r_m := 1.7374e6
var rows: Array = []
var t := 0.0                ## Seconds since 15 November 2026 00:00 UTC.
var x := 0.0                ## The craft, metres from the Earth's centre, in the ecliptic.
var y := 0.0
var vx := 0.0
var vy := 0.0
var dv_used := 0.0          ## Speed the engine has added so far, m/s.
var engines: Dictionary = {}    ## data/engines.json entries, each with its own "mass_kg" that falls as it burns.
var engine := "departure"   ## The engine that fires now: "departure" until the burn to the Moon ends, then "craft".
var g0 := 9.80665


func setup() -> void:
	mu_e = FlightData.gm("earth")
	mu_m = FlightData.gm("moon")
	r_e = FlightData.radius_m("earth")
	r_m = FlightData.radius_m("moon")
	rows = FlightData.moon_rows()
	var f := FileAccess.open(ENGINES, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f != null else null
	if d is Dictionary:
		g0 = float(d.get("g0", g0))
		engines = d.get("entries", {}).duplicate(true)
	else:
		push_error("Transfer: cannot read " + ENGINES)
	use_engine("departure")


## Picks the engine that fires next (a key of data/engines.json). The departure stage is dropped after its burn.
func use_engine(id: String) -> void:
	engine = id


func _eng() -> Dictionary:
	return engines.get(engine, {"thrust_n": 1.0e6, "isp_s": 420.0, "mass_kg": 1.2e5})


## The push at this throttle now, m/s2: thrust / mass [S10].
func accel(throttle := 1.0) -> float:
	var e := _eng()
	return float(e.thrust_n) * throttle / float(e.mass_kg)


## Seconds a full-throttle burn of dv m/s takes from now: the propellant the rocket equation asks for [S10]
## (m0 (1 - e^(-dv/ve)), ve = Isp g0) over the mass flow (thrust / ve).
func burn_time(dv: float) -> float:
	var e := _eng()
	var ve: float = float(e.isp_s) * g0
	return float(e.mass_kg) * (1.0 - exp(-absf(dv) / ve)) / (float(e.thrust_n) / ve)


## Puts the craft on a circular orbit of radius r (metres) at angle a (radians, counterclockwise as the Moon goes).
func place_circular(r: float, a: float, time: float) -> void:
	t = time
	var v := sqrt(mu_e / r)
	x = r * cos(a)
	y = r * sin(a)
	vx = -v * sin(a)
	vy = v * cos(a)


# ===================================================================================== THE MOON
## The Moon's position at time `time`, metres from the Earth's centre: [x, y].
func moon(time: float) -> Array:
	if rows.size() < 2:
		var a := TAU * time / (27.32 * DAY)
		return [3.844e8 * cos(a), 3.844e8 * sin(a)]
	var i := clampi(int(floor(time / DAY)), 0, rows.size() - 2)
	var s := (time - i * DAY) / DAY
	var a0: Dictionary = rows[i]
	var a1: Dictionary = rows[i + 1]
	var s2 := s * s
	var s3 := s2 * s
	var h00 := 2.0 * s3 - 3.0 * s2 + 1.0
	var h10 := s3 - 2.0 * s2 + s
	var h01 := -2.0 * s3 + 3.0 * s2
	var h11 := s3 - s2
	var mx := (h00 * float(a0.x_km) + h10 * DAY * float(a0.vx_km_s) + h01 * float(a1.x_km) + h11 * DAY * float(a1.vx_km_s)) * 1000.0
	var my := (h00 * float(a0.y_km) + h10 * DAY * float(a0.vy_km_s) + h01 * float(a1.y_km) + h11 * DAY * float(a1.vy_km_s)) * 1000.0
	return [mx, my]


## The Moon's velocity at `time`, m/s: [vx, vy].
func moon_vel(time: float) -> Array:
	var a := moon(time - 30.0)
	var b := moon(time + 30.0)
	return [(b[0] - a[0]) / 60.0, (b[1] - a[1]) / 60.0]


# ===================================================================================== MOTION
## Gravity at (px, py) at time `time`: [ax, ay].
func gravity(px: float, py: float, time: float) -> Array:
	var m := moon(time)
	var r2 := px * px + py * py
	var r3 := r2 * sqrt(r2)
	var dx: float = px - m[0]
	var dy: float = py - m[1]
	var d2 := dx * dx + dy * dy
	var d3 := d2 * sqrt(d2)
	var m2: float = m[0] * m[0] + m[1] * m[1]
	var m3 := m2 * sqrt(m2)
	return [-mu_e * px / r3 - mu_m * dx / d3 - mu_m * m[0] / m3, -mu_e * py / r3 - mu_m * dy / d3 - mu_m * m[1] / m3]


## One Runge-Kutta step of h seconds for state s = [x, y, vx, vy] at time `time`, with a steady push (ux, uy) m/s2.
func _rk4(s: Array, time: float, h: float, ux := 0.0, uy := 0.0) -> Array:
	var k1 := _deriv(s, time, ux, uy)
	var k2 := _deriv(_add(s, k1, h * 0.5), time + h * 0.5, ux, uy)
	var k3 := _deriv(_add(s, k2, h * 0.5), time + h * 0.5, ux, uy)
	var k4 := _deriv(_add(s, k3, h), time + h, ux, uy)
	var out: Array = []
	for i in 4:
		out.append(s[i] + h / 6.0 * (k1[i] + 2.0 * k2[i] + 2.0 * k3[i] + k4[i]))
	return out


func _deriv(s: Array, time: float, ux: float, uy: float) -> Array:
	var g := gravity(s[0], s[1], time)
	return [s[2], s[3], g[0] + ux, g[1] + uy]


func _add(s: Array, k: Array, h: float) -> Array:
	return [s[0] + k[0] * h, s[1] + k[1] * h, s[2] + k[2] * h, s[3] + k[3] * h]


## A step size that keeps the motion smooth: a small share of the time to cross the distance to the nearer body.
func _h(s: Array, time: float) -> float:
	var m := moon(time)
	var r := sqrt(s[0] * s[0] + s[1] * s[1])
	var d := sqrt((s[0] - m[0]) * (s[0] - m[0]) + (s[1] - m[1]) * (s[1] - m[1]))
	var v := maxf(sqrt(s[2] * s[2] + s[3] * s[3]), 1.0)
	return clampf(0.02 * minf(r, d) / v, 0.5, 900.0)


## Moves the craft `dt` seconds. thrust: 0..1 of the engine's full thrust; dir: 1 along the motion (relative to the Earth, or to the
## Moon when moon_frame), -1 against it.
func advance(dt: float, thrust := 0.0, dir := 1.0, moon_frame := false) -> void:
	var left := dt
	while left > 1e-6:
		var s := [x, y, vx, vy]
		var h := minf(_h(s, t), left)
		if thrust > 0.0:
			h = minf(h, 2.0)
		var ux := 0.0
		var uy := 0.0
		if thrust > 0.0:
			var rvx := vx
			var rvy := vy
			if moon_frame:
				var mv := moon_vel(t)
				rvx -= mv[0]
				rvy -= mv[1]
			var vl := maxf(sqrt(rvx * rvx + rvy * rvy), 1e-6)
			# the push at the step's middle mass (steps of at most 2 s, so the error is tiny), then the mass burned
			var e := _eng()
			var mdot: float = float(e.thrust_n) * thrust / (float(e.isp_s) * g0)
			var a: float = float(e.thrust_n) * thrust / (float(e.mass_kg) - mdot * h * 0.5)
			e.mass_kg = float(e.mass_kg) - mdot * h
			ux = dir * a * rvx / vl
			uy = dir * a * rvy / vl
			dv_used += a * h
		s = _rk4(s, t, h, ux, uy)
		x = s[0]
		y = s[1]
		vx = s[2]
		vy = s[3]
		t += h
		left -= h


## Adds a change of speed along the motion (relative to the Earth) at once: dv m/s, negative slows down. Our
## simplification for the small mid-course correction (about 50 m/s, some 25 s of the craft's engine in a coast of
## days); the engine's mass still falls by the rocket equation [S10].
func kick(dv: float) -> void:
	var v := sqrt(vx * vx + vy * vy)
	vx += dv * vx / v
	vy += dv * vy / v
	dv_used += absf(dv)
	var e := _eng()
	e.mass_kg = float(e.mass_kg) * exp(-absf(dv) / (float(e.isp_s) * g0))


# ===================================================================================== WHERE IT GOES
## Where the craft goes without the engine from state s = [x, y, vx, vy] at `time`, for at most `horizon` seconds:
## {"points": PackedVector2Array (metres, every step), "times": PackedFloat64Array, "closest" (metres from the Moon's
## centre), "t_closest" (absolute), "side" (+1 or -1: which side of the Moon it passes), "v_rel" (speed past the Moon,
## m/s), "impact" (it hits the Moon), "moon_at" ([x, y] of the Moon at the closest moment)}.
## While the craft is still bound to the Earth below the Moon's distance (mid-burn), one lap is enough: max_laps stops
## the prediction after that many turns around the Earth (0: no limit).
func predict(s: Array, time: float, horizon := 7.0 * DAY, keep := true, max_laps := 1.0) -> Dictionary:
	var pts := PackedVector2Array()
	var ts := PackedFloat64Array()
	var best := INF
	var best_t := time
	var best_s := s
	var t0 := time
	var impact := false
	var swept := 0.0
	var ang0 := atan2(s[1], s[0])
	while time - t0 < horizon:
		var h := _h(s, time)
		s = _rk4(s, time, h)
		time += h
		if keep:
			pts.append(Vector2(s[0], s[1]))
			ts.append(time)
		var ang := atan2(s[1], s[0])
		swept += absf(wrapf(ang - ang0, -PI, PI))
		ang0 = ang
		if max_laps > 0.0 and swept > TAU * max_laps:
			break
		var m := moon(time)
		var d := sqrt((s[0] - m[0]) * (s[0] - m[0]) + (s[1] - m[1]) * (s[1] - m[1]))
		if d < best:
			best = d
			best_t = time
			best_s = s
		elif best < SOI and d > best * 1.3:
			break        # past the Moon and leaving
		if d < r_m:
			impact = true
			break
		if s[0] * s[0] + s[1] * s[1] < r_e * r_e or s[0] * s[0] + s[1] * s[1] > 6.4e8 * 6.4e8:
			break
	var m := moon(best_t)
	var mv := moon_vel(best_t)
	var rx: float = best_s[0] - m[0]
	var ry: float = best_s[1] - m[1]
	var rvx: float = best_s[2] - mv[0]
	var rvy: float = best_s[3] - mv[1]
	return {"points": pts, "times": ts, "closest": best, "t_closest": best_t, "side": 1.0 if rx * rvy - ry * rvx > 0.0 else -1.0,
		"v_rel": sqrt(rvx * rvx + rvy * rvy), "impact": impact, "moon_at": m}


## The closest pass with a sign: + on one side of the Moon, - on the other, so a search can aim between them.
func signed_pass(p: Dictionary) -> float:
	return float(p.side) * float(p.closest)


## The state now: [x, y, vx, vy].
func state() -> Array:
	return [x, y, vx, vy]


## The state of a craft on a circular orbit of radius r that reaches angle a after time `from`, kicked by dv along its
## motion there: [state, time]. The angle now is a_now; the orbit's angular speed n. A departure sooner than
## min_wait seconds waits one more lap.
func departure(r: float, a_now: float, a: float, from: float, dv: float, min_wait := 0.0) -> Array:
	var n := sqrt(mu_e / (r * r * r))
	var wait := wrapf(a - a_now, 0.0, TAU) / n
	if wait < min_wait:
		wait += TAU / n
	var v := sqrt(mu_e / r) + dv
	return [[r * cos(a), r * sin(a), -v * sin(a), v * cos(a)], from + wait]


## Height of a pass over the Moon's surface, metres.
func pass_height(p: Dictionary) -> float:
	return float(p.closest) - r_m


## Speed to slow down at the closest pass to stay in a circular orbit around the Moon, m/s.
func capture_dv(p: Dictionary) -> float:
	return float(p.v_rel) - sqrt(mu_m / float(p.closest))


## Relative to the Moon now: {"r" metres, "v" m/s, "radial" m/s (+ going away), "energy" (negative: bound to it)}.
func about_moon() -> Dictionary:
	var m := moon(t)
	var mv := moon_vel(t)
	var rx: float = x - m[0]
	var ry: float = y - m[1]
	var rvx: float = vx - mv[0]
	var rvy: float = vy - mv[1]
	var r := sqrt(rx * rx + ry * ry)
	var v := sqrt(rvx * rvx + rvy * rvy)
	return {"r": r, "v": v, "radial": (rx * rvx + ry * rvy) / r, "energy": v * v / 2.0 - mu_m / r}


# ===================================================================================== PLANNING
## The planners' job: where on the parking orbit (radius r, the craft at angle a_now at time `from`) to fire a burn
## of dv so the craft passes PERISELENE over the Moon. Scans the lap every `step_deg`, then halves the bracket where
## the pass changes side, around the closest one. Returns {"angle", "time" (of the burn), "pass" (predict())} or {}.
## A whole search is about 150 predictions; the screen spreads it over frames with plan_start() and plan_work().
func plan_departure(r: float, a_now: float, from: float, dv: float, step_deg := 3.0, min_wait := 0.0) -> Dictionary:
	var job := plan_start(r, a_now, from, dv, step_deg, min_wait)
	while not plan_work(job, 1.0e9):
		pass
	return job.result


func plan_start(r: float, a_now: float, from: float, dv: float, step_deg := 3.0, min_wait := 0.0) -> Dictionary:
	return {"r": r, "a_now": a_now, "from": from, "dv": dv, "step": deg_to_rad(step_deg), "k": 0, "min_wait": min_wait,
		"scan": [], "lo": 0.0, "hi": 0.0, "f_lo": 0.0, "halvings": 0, "stage": "scan", "result": {}}


## Works on a plan for about `budget_ms` milliseconds. True when it is done (job.result is {} when no pass was found).
func plan_work(job: Dictionary, budget_ms: float) -> bool:
	var t_end := Time.get_ticks_msec() + budget_ms
	var goal := r_m + PERISELENE
	while Time.get_ticks_msec() < t_end:
		if job.stage == "scan":
			var a: float = job.a_now + job.step * (job.k + 1)
			job.scan.append([a, _miss(job, a)])
			job.k += 1
			if job.step * job.k >= TAU:
				job.stage = "bracket"
		elif job.stage == "bracket":
			# where the pass changes side near the Moon, the one that passes closest
			var best := INF
			var sc: Array = job.scan
			for i in sc.size() - 1:
				var f0: float = sc[i][1] - goal
				var f1: float = sc[i + 1][1] - goal
				if f0 * f1 < 0.0 and absf(sc[i][1]) < SOI and absf(sc[i + 1][1]) < SOI:
					var near := minf(absf(f0), absf(f1))
					if near < best:
						best = near
						job.lo = sc[i][0]
						job.hi = sc[i + 1][0]
						job.f_lo = f0
			if best == INF:
				return true
			job.stage = "halve"
		else:
			var mid: float = (job.lo + job.hi) * 0.5
			var fm: float = _miss(job, mid) - goal
			if fm * job.f_lo < 0.0:
				job.hi = mid
			else:
				job.lo = mid
				job.f_lo = fm
			job.halvings += 1
			if job.halvings >= 26:
				var a: float = (job.lo + job.hi) * 0.5
				var dep := departure(job.r, job.a_now, a, job.from, job.dv, job.min_wait)
				job.result = {"angle": wrapf(a, 0.0, TAU), "time": dep[1], "pass": predict(dep[0], dep[1])}
				return true
	return false


func _miss(job: Dictionary, a: float) -> float:
	var dep := departure(job.r, job.a_now, a, job.from, job.dv, job.min_wait)
	return signed_pass(predict(dep[0], dep[1], 7.0 * DAY, false))


## The mid-course correction: the change of speed along the motion (at most `limit` m/s either way) that brings the
## pass to PERISELENE from the state now. Returns {"dv", "pass"} or {} when none within the limit.
func plan_correction(limit := 60.0) -> Dictionary:
	var goal := r_m + PERISELENE
	var s0 := state()
	var f := func(dv: float) -> float:
		var v := sqrt(s0[2] * s0[2] + s0[3] * s0[3])
		var s := [s0[0], s0[1], s0[2] + dv * s0[2] / v, s0[3] + dv * s0[3] / v]
		return signed_pass(predict(s, t, 7.0 * DAY, false)) - goal
	var best := {}
	var prev_dv := -limit
	var prev_f: float = f.call(prev_dv)
	var dv := -limit
	while dv < limit:
		dv = minf(dv + 2.0, limit)
		var fv: float = f.call(dv)
		if prev_f * fv < 0.0 and (best.is_empty() or absf(dv) < absf(float(best.dv))):
			var lo := prev_dv
			var hi := dv
			var flo := prev_f
			for _i in 22:
				var mid := (lo + hi) * 0.5
				var fm: float = f.call(mid)
				if fm * flo < 0.0:
					hi = mid
				else:
					lo = mid
					flo = fm
			best = {"dv": (lo + hi) * 0.5}
		prev_dv = dv
		prev_f = fv
	if best.is_empty():
		return {}
	var v := sqrt(s0[2] * s0[2] + s0[3] * s0[3])
	var s := [s0[0], s0[1], s0[2] + best.dv * s0[2] / v, s0[3] + best.dv * s0[3] / v]
	best["pass"] = predict(s, t)
	return best


## The orbit around the Moon from the state now, as two bodies: {"low", "high"} heights over its surface, metres
## (high is INF while the craft is not bound to the Moon).
func moon_orbit() -> Dictionary:
	var m := moon(t)
	var mv := moon_vel(t)
	var rx: float = x - m[0]
	var ry: float = y - m[1]
	var rvx: float = vx - mv[0]
	var rvy: float = vy - mv[1]
	var r := sqrt(rx * rx + ry * ry)
	var energy := (rvx * rvx + rvy * rvy) / 2.0 - mu_m / r
	var h := rx * rvy - ry * rvx
	var e := sqrt(maxf(1.0 + 2.0 * energy * h * h / (mu_m * mu_m), 0.0))
	if energy >= 0.0:
		return {"low": h * h / mu_m / (1.0 + e) - r_m, "high": INF}
	var a := -mu_m / (2.0 * energy)
	return {"low": a * (1.0 - e) - r_m, "high": a * (1.0 + e) - r_m}
