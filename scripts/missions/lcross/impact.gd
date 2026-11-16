extends RefCounted
## Mission 4, LCROSS: the aim and the four minutes, with no screen (issue #48), so a test can play them.
## The map is NASA's LROC mosaic of the south pole seen from above (S-lroc-wac): azimuthal equidistant, the pole at its
## centre, 11 degrees of latitude to its edge, 0 degrees of longitude up and east clockwise; on the Moon (radius
## 1737.4 km, S-nssdc-planets) one pixel is about 0.67 km. Cabeus sits at 85.33 S, 42.13 W, 100.6 km across
## (S-cabeus-gazetteer). Places are km on the map: x to the right, y down, the pole at (0, 0).
## The aim: a small burn of v (m/s) at separation moves the impact point by v times the time left, 9 h 41 min 19.5 s
## from 01:50 UT to 11:31:19.5 UT (S-lcross-nssdc): the straight-line rule for a fall seen this far out (our
## simplification). The impact: the Centaur and then the shepherding craft fall at about 2.5 km/s (S-lcross-nssdc;
## 9,000 km/h, S-lcross-nasa), 256.6 s apart. The plume: ejecta thrown up at speeds we chose (no plume height was found
## on a NASA page), falling back under the Moon's gravity (1.62 m/s2, S-nssdc-planets); seen only once above the crater's
## shadow (our height for it). Data: data/missions/lcross.json.
##   var I = Impact.new(); I.nudge(Vector2(1, 0)); I.verdict(); I.lit(t); I.read(t, err_deg)

const DATA_PATH := "res://data/missions/lcross.json"

var D: Dictionary = {}
var A: Dictionary = {}
var P: Dictionary = {}
var km_px := 0.0               ## Kilometres per pixel of the map.
var cabeus := Vector2.ZERO     ## Cabeus's centre on the map (km).
var cabeus_r := 0.0            ## Its radius (km).
var point := Vector2.ZERO      ## Where the Centaur will hit (km).
var used := 0.0                ## Speed spent on the aim (m/s).
var readings := 0              ## Good readings saved.
var tries := 0
var last_read := -999.0
var busy_until := -999.0       ## A reading out of a flash pauses the instruments until then.
var pulses: Array = []         ## The flashes of the water's mark: [start, end] in s after the impact.
var used_pulse := {}           ## Flashes already read (one reading each).
var _ups: PackedFloat32Array = PackedFloat32Array()
var _sides: PackedVector2Array = PackedVector2Array()
var _img: Image
const N := 360                 ## Ejecta grains in the plume.


func _init(seed := 2009) -> void:
	D = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	A = D.aim
	P = D.impact
	var R := float(A.moon_radius_km)
	km_px = PI * R / 180.0 * float(A.map_half_deg) / (float(A.map_px) * 0.5)
	cabeus = latlon_km(float(A.cabeus_lat), float(A.cabeus_lon))
	cabeus_r = float(A.cabeus_d_km) * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# the Centaur starts aimed near Cabeus, off by the navigation's error (our numbers)
	var off: Array = A.start_off_km
	var ang := rng.randf_range(0.0, TAU)
	point = cabeus + Vector2(cos(ang), sin(ang)) * rng.randf_range(float(off[0]), float(off[1]))
	var up: Array = P.ejecta_up_kms
	for i in N:
		_ups.append(lerpf(float(up[0]), float(up[1]), pow(rng.randf(), 0.7)))
		var a := rng.randf_range(0.0, TAU)
		_sides.append(Vector2(cos(a), sin(a)) * rng.randf() * float(P.ejecta_side_kms))
	# the flashes: clumps of ejecta crossing the instruments' view (our simplification), at uneven gaps
	var gap: Array = P.pulse_gap_s
	var t := float(P.pulse_first_s)
	while t < float(P.pulse_end_s):
		pulses.append([t, t + float(P.pulse_len_s)])
		t += float(P.pulse_len_s) + rng.randf_range(float(gap[0]), float(gap[1]))


## A place on the Moon (degrees, south negative, east positive) as km on the map.
func latlon_km(lat: float, lon: float) -> Vector2:
	var R := float(A.moon_radius_km)
	var d := deg_to_rad(90.0 + lat) * R
	return Vector2(sin(deg_to_rad(lon)), -cos(deg_to_rad(lon))) * d


## km on the map to the map's pixel.
func km_to_px(p: Vector2) -> Vector2:
	return p / km_px + Vector2.ONE * float(A.map_px) * 0.5


## One small burn: dir is the direction on the map (unit steps). Returns false when the budget is spent.
func nudge(dir: Vector2) -> bool:
	var dv := float(A.nudge_ms)
	if used + dv > float(A.budget_ms) + 0.001 or dir == Vector2.ZERO:
		return false
	used += dv
	point += dir.normalized() * dv * float(A.seconds_left) / 1000.0
	return true


## How bright the map is at a place (0 black, 1 white): the shadow is the dark.
func brightness(p: Vector2) -> float:
	if _img == null:
		var tex := load(A.map) as Texture2D
		_img = tex.get_image()
		if _img.is_compressed():
			_img.decompress()
	var px := km_to_px(p)
	var x := clampi(int(px.x), 0, _img.get_width() - 1)
	var y := clampi(int(px.y), 0, _img.get_height() - 1)
	# the average around the point (a few km), so one bright pebble does not decide
	var s := 0.0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			s += _img.get_pixel(clampi(x + dx, 0, _img.get_width() - 1), clampi(y + dy, 0, _img.get_height() - 1)).get_luminance()
	return s / 25.0


## "in" (the shadowed floor of Cabeus), "sunlit" (inside, in the sunlight) or "missed" (outside Cabeus).
func verdict() -> String:
	if point.distance_to(cabeus) > cabeus_r:
		return "missed"
	return "in" if brightness(point) <= float(A.dark_max) else "sunlit"


## The shepherding craft's height above the ground, t seconds after the Centaur's impact (km).
func shepherd_alt(t: float) -> float:
	return maxf(0.0, float(P.speed_kms) * (float(P.gap_s) - t))


## The Centaur's height, t seconds after its impact (negative before) (km).
func centaur_alt(t: float) -> float:
	return maxf(0.0, -float(P.speed_kms) * t)


## Where grain i of the plume is, t seconds after the impact: x and z sideways, y up (km). y < 0: back on the ground.
func grain(i: int, t: float) -> Vector3:
	var g := float(P.g_moon)
	return Vector3(_sides[i].x * t, _ups[i] * t - 0.5 * g * t * t, _sides[i].y * t)


## The part of the plume up in the sunlight, t seconds after the impact (0 to 1).
func lit(t: float) -> float:
	if t <= 0.0:
		return 0.0
	var n := 0
	for i in N:
		if grain(i, t).y > float(P.sunlit_km):
			n += 1
	return float(n) / N


## The plume's middle, where the instruments look (km above the impact point).
func plume_mid(t: float) -> Vector3:
	var s := Vector3.ZERO
	var n := 0
	for i in N:
		var p := grain(i, t)
		if p.y > float(P.sunlit_km):
			s += p
			n += 1
	return s / n if n > 0 else Vector3(0, float(P.sunlit_km), 0)


## The flash at t (its index), or -1 between flashes.
func pulse_at(t: float) -> int:
	for i in pulses.size():
		if t >= float(pulses[i][0]) and t <= float(pulses[i][1]):
			return i
	return -1


## How strong the water's mark is at t, 0 to 1 (a flash rises and falls).
func flash(t: float) -> float:
	var i := pulse_at(t)
	if i < 0 or lit(t) < 0.12:
		return 0.0
	var k := (t - float(pulses[i][0])) / float(P.pulse_len_s)
	return sin(k * PI)


## A reading at t (s after the impact), the instruments err_deg off the plume: "good", "early" (no flash: the
## instruments pause), "dark" (off target), "faint" (not enough plume in the sunlight), "again" (this flash is read
## already) or "" (still busy).
func read(t: float, err_deg: float) -> String:
	if t - last_read < float(P.cool_s) or t < busy_until:
		return ""
	last_read = t
	tries += 1
	var i := pulse_at(t)
	if i < 0:
		busy_until = t + float(P.miss_cool_s)
		return "early"
	if used_pulse.has(i):
		return "again"
	if err_deg > float(P.aim_deg):
		return "dark"
	if lit(t) < 0.12:
		return "faint"
	used_pulse[i] = true
	readings += 1
	return "good"


## A glint of dust caught instead of ice: no water, and the instruments pause.
func dust(t: float) -> void:
	busy_until = t + float(P.miss_cool_s) * 0.5
	tries += 1


## How well the flash was caught: 1 at its peak, 0 beyond the tolerance (s after the impact, real seconds).
func flash_quality(press_s: float) -> float:
	var S: Dictionary = D.stages
	return clampf(1.0 - absf(press_s - float(S.flash_peak_s)) / float(S.flash_tol_s), 0.0, 1.0)


## The data sent home, 0 to 100: the instruments on, the flash, the ice, the dive (weights in the data).
func data(armed: int, flash_q: float, dive_q: float) -> float:
	var S: Dictionary = D.stages
	var w: Dictionary = S.weights
	var ice := minf(float(readings) / float(S.ice_full), 1.0)
	return float(w.instruments) * armed / float(S.instruments.size()) + float(w.flash) * flash_q + float(w.ice) * ice + float(w.dive) * clampf(dive_q, 0.0, 1.0)


func stars_for(total: float) -> int:
	var n := 0
	for k in D.stages.stars:
		if total >= float(k):
			n += 1
	return n


func stars() -> int:
	var s: Array = P.stars
	var n := 0
	for k in s:
		if readings >= int(k):
			n += 1
	return n


## UT as text, t seconds after the Centaur's impact (11:31:19.5 UT).
func ut(t: float) -> String:
	var s := 11 * 3600 + 31 * 60 + 19.5 + t
	s = fposmod(s, 86400.0)
	return "%02d:%02d:%04.1f UT" % [int(s / 3600.0), int(fmod(s, 3600.0) / 60.0), fmod(s, 60.0)]
