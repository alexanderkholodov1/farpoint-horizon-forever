extends RefCounted
## Mission 5, DART: the approach, the last picture and the measurement, with no screen (issue #49), so a test can
## play them. DART closes in at about 6.58 km/s (S-dart-nssdc); t is seconds to impact (negative before it). DRACO,
## its camera, sees 0.29 degrees with about 0.5 arcsec per pixel (S-dart-nssdc). Didymos is 780 m across, Dimorphos
## 160 m (S-dart-nasa); the distance between them is ours (1.2 km: not found on a NASA page).
## The aim: the miss at impact is the sideways offset now plus the sideways speed times the time left, so a thruster
## pulse early moves it far and late moves it little (straight-line motion; the asteroids' pull is negligible here,
## our simplification). The measurement: Dimorphos's orbit took 11 h 55 min before the impact and 11 h 23 min after,
## plus or minus about 2 min (S-dart-nasa-period); the light curve drawn from it is ours (dips when one asteroid passes
## the other). Data: data/missions/dart.json.
##   var A = Approach.new(); A.update(dt, t); A.pulse(Vector2.LEFT); A.miss(t); A.photo_cm(t); A.curve(h, after)

const DATA_PATH := "res://data/missions/dart.json"

var D: Dictionary = {}
var P: Dictionary = {}
var M: Dictionary = {}
var offset := Vector2.ZERO     ## Sideways offset from Dimorphos's centre now (m).
var vel := Vector2.ZERO        ## Sideways speed (m/s).
var used := 0.0                ## Thruster speed spent (m/s).
var _rng := RandomNumberGenerator.new()
var _noise: PackedFloat32Array = PackedFloat32Array()


func _init(seed := 2022) -> void:
	D = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	P = D.approach
	M = D.measure
	_rng.seed = seed
	# DART starts aimed a little off (our numbers): the miss it would make with no correction
	var r: Array = P.start_miss_m
	var ang := _rng.randf_range(0.0, TAU)
	var miss0 := Vector2(cos(ang), sin(ang)) * _rng.randf_range(float(r[0]), float(r[1]))
	vel = miss0 / -float(P.start_s)
	for i in 4096:
		_noise.append(_rng.randf_range(-1.0, 1.0))


## Distance to Dimorphos at t (km).
func dist_km(t: float) -> float:
	return maxf(0.0, -t * float(P.speed_kms))


## How many screen pixels a length (m) spans on DRACO's view at t, the view 0.29 degrees across the screen.
func px(length_m: float, t: float) -> float:
	var d := dist_km(t) * 1000.0
	if d <= 0.0:
		return INF
	var fov := deg_to_rad(float(P.fov_deg))
	return (length_m / d) / fov * float(P.screen_px)


## The two asteroids are two dots on the view once they are this many pixels apart.
func resolved(t: float) -> bool:
	return px(float(P.separation_km) * 1000.0, t) >= float(P.resolve_px)


## The slow drift of the aim (our simplification), then the motion.
func update(dt: float, _t: float) -> void:
	vel += Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * float(P.drift_ms) * 0.01 * dt
	offset += vel * dt


## One thruster pulse at t: it moves the hit point about "pulse_m" metres the way pushed (our simplification: the
## burn is timed so each pulse shifts the hit by the same amount). False when the pulses are spent.
func pulse(dir: Vector2, t := -100.0) -> bool:
	if used + 1.0 > float(P.budget_pulses) or dir == Vector2.ZERO:
		return false
	used += 1.0
	vel += dir.normalized() * float(P.pulse_m) / maxf(-t, 0.5)
	return true


## Where DART will pass Dimorphos's centre, sideways (m), if nothing changes.
func miss(t: float) -> Vector2:
	return offset + vel * maxf(0.0, -t)


## True if that is on Dimorphos (inside its radius).
func hits(t: float) -> bool:
	return miss(t).length() <= float(P.dimorphos_m) * 0.5


## The sharpness of a picture taken at t: centimetres per pixel (DRACO's 0.5 arcsec pixel at that distance).
func photo_cm(t: float) -> float:
	return dist_km(t) * 1.0e5 * deg_to_rad(float(P.arcsec_px) / 3600.0)


## The pair's light at hour h of the window (1 = full), Dimorphos's orbit before or after the impact: a deep dip each
## orbit and a shallow one half an orbit later (our drawing of a light curve), with a little noise.
func curve(h: float, after: bool, phase_h := 2.3) -> float:
	var per_h := float(M.after_min if after else M.before_min) / 60.0
	var w := float(M.dip_width_min) / 60.0
	var b := 1.0
	var x := fposmod(h - phase_h, per_h)
	for k in [0.0, per_h]:
		b -= float(M.dip_depth) * exp(-pow((x - k) / w, 2.0))
	var x2 := fposmod(h - phase_h - per_h * 0.5, per_h)
	for k in [0.0, per_h]:
		b -= float(M.dip_depth) * 0.45 * exp(-pow((x2 - k) / w, 2.0))
	return b + float(M.noise) * _noise[int(h * 137.0) % _noise.size()]


## The deep dips' times in the window (hours), to check a player's marks.
func dips(after: bool, phase_h := 2.3) -> Array:
	var per_h := float(M.after_min if after else M.before_min) / 60.0
	var out := []
	var h := phase_h
	while h <= float(M.window_h):
		out.append(h)
		h += per_h
	return out


## How good a measured period is (minutes): 1 when right, 0 beyond "good_min" off.
func period_quality(measured_min: float, after: bool) -> float:
	var truth := float(M.after_min if after else M.before_min)
	return clampf(1.0 - absf(measured_min - truth) / float(M.good_min), 0.0, 1.0)


func aim_quality(t: float) -> float:
	return clampf(1.0 - miss(t).length() / (float(P.dimorphos_m) * 0.5), 0.0, 1.0)


## A picture's score: the real last picture's 3 cm per pixel or better is 1; at the start of the photo window, 0.
func photo_quality(cm: float) -> float:
	var worst := photo_cm(-float(P.photo_window_s))
	return clampf((worst - cm) / (worst - 3.2), 0.0, 1.0)


## The mission's result, 0 to 100, from the four stages (weights in the data).
func score(lock_q: float, aim_q: float, photo_q: float, measure_q: float) -> float:
	var w: Dictionary = D.score.weights
	return float(w.lock) * lock_q + float(w.aim) * aim_q + float(w.photo) * photo_q + float(w.measure) * measure_q


func stars_for(total: float) -> int:
	var n := 0
	for k in D.score.stars:
		if total >= float(k):
			n += 1
	return n


## A clock for t: hours, minutes and seconds to impact.
func countdown(t: float) -> String:
	var s := maxf(0.0, -t)
	return "T- %02d:%02d:%02d" % [int(s / 3600.0), int(fmod(s, 3600.0) / 60.0), int(fmod(s, 60.0))]
