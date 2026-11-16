extends RefCounted
## The landing, as numbers: a lander falling under the Moon's gravity (1.62 m/s2 [S-nssdc-planets]) with a main
## engine the pilot throttles and small side thrusters that push it across the ground. No screen, no nodes, so the
## landing screen and tests/ci/flight.gd fly the same thing. Every value of the flight comes from the scenario's
## `flight.landing` block (data/scenarios.json): where it starts, the engine, the fuel and the touchdown bands.
## The lander's engine and fuel are game values (they are not a real lander's): the descent takes a minute or two,
## from about 430 m up and 600 m out: only the last part of a real powered descent, compressed (our simplification).
##   const Descent := preload("res://scripts/flight/descent.gd")
##   var d := Descent.new(); d.setup(landing, terrain); d.step(dt, throttle, steer)

const FlightData := preload("res://scripts/flight/flight_data.gd")

const LEG := 1.6           ## Metres from the lander's centre down to its footpads.
const SIDE_FUEL := 0.15    ## Fuel the side thrusters burn at full push, as a share of the main engine's.

var terrain                ## scripts/flight/terrain.gd
var land: Dictionary
var g := 1.62
var pos := Vector3.ZERO    ## Metres, in the terrain's frame (y above the target).
var vel := Vector3.ZERO
var fuel := 1.0            ## Share of the fuel left.
var fuel_s := 60.0         ## Seconds of fuel at full throttle.
var engine := 4.0          ## m/s2 at full throttle.
var side := 1.2            ## m/s2 of the side thrusters.
var throttle := 0.0
var t := 0.0
var done := false
var result := {}           ## Filled at touchdown, see touchdown().
var earth_lost := false    ## The Earth went out of view at some moment of the descent.
var _earth_t := 0.0


func setup(landing: Dictionary, terrain_) -> void:
	land = landing
	terrain = terrain_
	g = FlightData.gravity("moon")
	var o: Array = landing.get("start_offset_m", [0.0, 430.0, 620.0])
	pos = Vector3(float(o[0]), float(o[1]), float(o[2]))
	var v: Array = landing.get("start_velocity", [0.0, -9.0, -13.0])
	vel = Vector3(float(v[0]), float(v[1]), float(v[2]))
	fuel_s = float(landing.get("fuel_s", 60.0))
	engine = float(landing.get("engine_accel", 4.0))
	side = float(landing.get("side_accel", 1.2))


## Less fuel to start with (a burn toward the Moon that missed asks the lander for a correction): share 0..1.
func spend_fuel(share: float) -> void:
	fuel = clampf(fuel - share, 0.15, 1.0)


## Height of the footpads above the ground right below.
func altitude() -> float:
	return pos.y - LEG - terrain.height(pos.x, pos.z)


func hspeed() -> float:
	return Vector2(vel.x, vel.z).length()


func target_distance() -> float:
	return Vector2(pos.x, pos.z).length()


## The throttle that holds the lander still in the air.
func hover_throttle() -> float:
	return g / engine


## One step: throttle 0..1, steer x (across, -1..1) and y (forward, toward -z, -1..1).
func step(dt: float, throttle_: float, steer: Vector2) -> void:
	if done:
		return
	t += dt
	throttle = clampf(throttle_, 0.0, 1.0) if fuel > 0.0 else 0.0
	var push := Vector2(steer.x, -steer.y).limit_length(1.0) if fuel > 0.0 else Vector2.ZERO
	var acc := Vector3(push.x * side, throttle * engine - g, push.y * side)
	vel += acc * dt
	pos += vel * dt
	fuel = maxf(fuel - (throttle + push.length() * SIDE_FUEL) * dt / fuel_s, 0.0)
	_earth_t += dt
	if _earth_t > 0.5:
		_earth_t = 0.0
		if not terrain.sees_earth(pos):
			earth_lost = true
	if altitude() <= 0.0:
		touchdown()


## The lander touches the ground: grades it and fills `result`.
##   grade: "soft" (at most soft_mps), "good", "firm" (at most hard_mps), "rough" (harder, or it tipped over on a
##   slope or sliding sideways: bent, but it works), "crater" (faster than crater_mps: lost).
func touchdown() -> void:
	done = true
	var vs := -vel.y
	var hs := hspeed()
	var sl: float = terrain.slope_deg(pos.x, pos.z)
	pos.y = terrain.height(pos.x, pos.z) + LEG
	var grade := "rough"
	if vs > float(land.get("crater_mps", 12.0)):
		grade = "crater"
	elif hs > float(land.get("tip_hspeed", 2.5)) or sl > float(land.get("tip_slope_deg", 12.0)) or vs > float(land.get("hard_mps", 6.0)):
		grade = "rough"
	elif vs <= float(land.get("soft_mps", 1.5)):
		grade = "soft"
	elif vs <= float(land.get("good_mps", 3.0)):
		grade = "good"
	else:
		grade = "firm"
	if not terrain.sees_earth(pos):
		earth_lost = true
	result = {
		"landed": grade != "crater",
		"x": snappedf(pos.x, 0.1),      # where it stands, metres from the target in the terrain's frame
		"z": snappedf(pos.z, 0.1),
		"grade": grade,
		"touchdown_mps": snappedf(vs, 0.01),
		"side_mps": snappedf(hs, 0.01),
		"slope_deg": snappedf(sl, 0.1),
		"target_m": snappedf(target_distance(), 0.1),
		"pole_m": snappedf(terrain.pole_distance(pos.x, pos.z), 0.1),
		"shadow_edge_m": snappedf(terrain.shadow_distance(pos.x, pos.z), 0.1),
		"fuel_left": snappedf(fuel, 0.001),
		"contact_kept": not earth_lost,
		"time_s": snappedf(t, 0.1),
	}


## The bot lander (and the flight computer that helps a pilot who lets go): comes down over the target, slowing as it
## nears the ground, and sets down at about 1 m/s. Returns [throttle, steer].
func bot() -> Array:
	var alt := altitude()
	var want_v := -clampf(0.7 + alt * 0.09, 0.8, 22.0)
	var to := -Vector2(pos.x, pos.z)
	var want_h := to.limit_length(clampf(sqrt(to.length() * side) * 0.8, 0.0, 14.0))
	if to.length() > 25.0 and alt < 70.0:
		want_v = clampf((50.0 - alt) * 0.25, -2.0, 2.0)    # not over the target yet: hold height
	if alt < 15.0:
		want_h = to.limit_length(minf(to.length() * 0.2, 0.6))
	var dh := (want_h - Vector2(vel.x, vel.z)) * 0.9
	var th := (g + (want_v - vel.y) * 1.4) / engine
	return [clampf(th, 0.0, 1.0), Vector2(dh.x, -dh.y).limit_length(1.0)]
