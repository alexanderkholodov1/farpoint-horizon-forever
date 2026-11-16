extends RefCounted
## Mission 3, Mars Pathfinder: the descent and the bounces, with no screen (issue #47), so a test can fly them.
## Real time from the radar's first echo at 1.6 km, under the parachute at about 70 m/s; the airbags inflate on their
## own about 10 s before landing; the player fires the three solid rockets (best at 98 m) and cuts the 20 m bridle
## (best at 21.5 m); the airbag ball falls under Mars's gravity (3.71 m/s2) and hits the ground. The real impact was
## 18 m/s (S-mpf-nssdc). Too fast (our limit, 26 m/s) and the airbags burst: lost. The lander swings on its bridle;
## firing while it swings throws the ball sideways. Data: data/missions/pathfinder.json.
##   var L = Landing.new(); L.update(dt, steer); L.fire(); L.cut()

const DATA_PATH := "res://data/missions/pathfinder.json"

var D: Dictionary = {}
var alt := 0.0                 ## The lander's height above the ground (m).
var vz := 0.0                  ## Its speed down (m/s).
var t := 0.0
var airbags := false
var fired := false
var fire_alt := -1.0
var burn := 0.0                ## Seconds the rockets have burned.
var released := false
var cut_alt := -1.0
var swing := 0.0               ## The lander's angle on the bridle (radians).
var swing_v := 0.0
var fire_swing := 0.0
var landed := false
var impact := 0.0
var burst := false
var tangled := false           ## The ground came before the bridle was cut.
var _gust := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	D = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	alt = D.descent.start_alt
	vz = D.descent.chute_speed
	_rng.seed = 1997


## steer: the player's push against the swing, -1 to 1.
func update(dt: float, steer := 0.0) -> void:
	if landed:
		return
	t += dt
	var De: Dictionary = D.descent
	# the swing: a pendulum on the 20 m bridle, pushed by gusts, steadied by the player
	_gust = lerpf(_gust, _rng.randf_range(-1.0, 1.0), dt * 0.8)
	if not released:
		var w2 := float(De.g) / float(De.bridle_m)
		var acc := -w2 * swing - 0.25 * swing_v + _gust * 0.35 + steer * 0.9
		swing_v += acc * dt
		swing = clampf(swing + swing_v * dt, -0.7, 0.7)
	# the rockets slow the descent while they burn; after the cut the ball falls freely
	if fired and burn < float(De.rocket_time) and not released:
		burn += dt
		vz -= float(De.rocket_accel) * dt
	if released or (fired and burn >= float(De.rocket_time)):
		vz += float(De.g) * dt
	alt -= vz * dt
	if not airbags and vz > 0.0 and alt / vz <= float(De.airbag_lead_s):
		airbags = true
	if alt <= 0.0:
		alt = 0.0
		landed = true
		# the impact counts the sideways speed too (the wind, and a crooked push from the rockets)
		impact = Vector2(vz, roll_speed()).length()
		tangled = not released
		burst = impact > float(De.burst_speed) or not airbags or tangled


func fire() -> bool:
	if fired or landed:
		return false
	fired = true
	fire_alt = alt
	fire_swing = swing
	return true


func cut() -> bool:
	if released or landed:
		return false
	released = true
	cut_alt = alt
	return true


## Seconds left to the ground at the present speed (for the screen).
func seconds_to_ground() -> float:
	return alt / maxf(vz, 0.1)


## How sideways the ball leaves: a crooked lander when the rockets fired throws it.
func roll_speed() -> float:
	return float(D.descent.roll_base) + absf(fire_swing) * float(D.descent.roll_per_rad)


## The bounce heights: about 12 m first, then smaller each time, at least another 15 (S-mpf-nssdc).
func bounce_heights() -> Array:
	var B: Dictionary = D.bounces
	var out := []
	var h := float(B.first_height) * clampf(impact / float(D.descent.real_impact), 0.6, 1.3)
	for i in int(B.count) + 1:
		out.append(h)
		h *= float(B.keep)
	return out


## Stars, 1 to 3: landed (1), an impact within 3 m/s of the real 18, rockets fired steady (swing under 10 degrees).
func stars(rocks_hit: int) -> int:
	var s := 1
	if absf(impact - float(D.descent.real_impact)) < 3.0:
		s += 1
	if absf(fire_swing) < deg_to_rad(10.0) and rocks_hit == 0:
		s += 1
	return s
