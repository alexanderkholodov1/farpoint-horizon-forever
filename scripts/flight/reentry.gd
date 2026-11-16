extends RefCounted
## Coming home (issue #67): the re-entry as numbers, no screen, so tests/ci/reentry.gd plays the same rules the screen
## shows. Two parts:
##   - the plasma: the capsule hits the air at its real speed; the angle drifts and the player holds it inside the
##     corridor (too steep: too hot; too shallow: it skips off the air). Here the radio blackout plays in about 24 s;
##     Apollo 13's lasted from 19 s to 3 min 38 s after entry [S-afj13-return].
##   - the parachutes: the height falls; the drogues open at 24,000 ft, the mains at 10,000 ft [S-apollo13-return].
## Never a fail screen: time outside the corridor and late chutes only cost stars.
##   const Reentry := preload("res://scripts/flight/reentry.gd")
##   var r := Reentry.new("apollo13"); r.step(delta, push)   # push -1, 0 or 1

const DATA := "res://data/reentry.json"
const TOP_FT := 30000.0                ## Height the parachute part starts from.

var D: Dictionary
var phase := "plasma"                  ## "plasma", "chutes", then "splash".
var t := 0.0                           ## Seconds in the current phase.
var angle := 0.0                       ## Flight path angle, degrees (negative: down into the air).
var drift := 0.0                       ## Degrees a second the angle is drifting now.
var inside_s := 0.0                    ## Seconds of the plasma spent inside the corridor.
var height_ft := TOP_FT
var drogue_err := -1.0                 ## Feet from the right height when the drogues were called; -1 not yet.
var main_err := -1.0
var rng := RandomNumberGenerator.new()


func _init(id := "apollo13", seed_value := -1) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	D = d.entries[id]
	angle = float(D.start_deg)
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	drift = _new_drift()


func _new_drift() -> float:
	return rng.randf_range(-1.0, 1.0) * float(D.drift_deg_s)


## Speed now in mph: the real entry speed, falling through the plasma as the air brakes the capsule.
func speed_mph() -> float:
	var v0: float = float(D.speed_mph) if D.has("speed_mph") else float(D.speed_fts) * 3600.0 / 5280.0
	if phase == "plasma":
		return lerpf(v0, 300.0, clampf(t / float(D.plasma_s), 0.0, 1.0))
	return lerpf(300.0, 20.0, clampf(1.0 - height_ft / TOP_FT, 0.0, 1.0))


func in_corridor() -> bool:
	return angle >= float(D.corridor_deg[0]) and angle <= float(D.corridor_deg[1])


## "steep" or "shallow" when outside the corridor, else "".
func off_side() -> String:
	if angle < float(D.corridor_deg[0]):
		return "steep"
	if angle > float(D.corridor_deg[1]):
		return "shallow"
	return ""


## 0..1: how hot the shield glows (the plasma's light): more when steep, fading as it slows.
func heat() -> float:
	if phase != "plasma":
		return 0.0
	var steep := clampf((float(D.corridor_deg[1]) - angle) / 4.0, 0.2, 1.0)
	return steep * (1.0 - clampf(t / float(D.plasma_s), 0.0, 1.0) * 0.7)


## The radio blackout, in the game's compressed time (the real one runs 19 s to 3 min 38 s after entry).
func blackout() -> bool:
	if phase != "plasma":
		return false
	if D.has("blackout_from"):   # a craft whose blackout is given as a share of the plasma
		var f := t / float(D.plasma_s)
		return f >= float(D.blackout_from) and f <= float(D.blackout_to)
	var k := float(D.plasma_s) / float(D.blackout_end_s)
	return t >= float(D.blackout_start_s) * k


## One step: delta seconds, push -1 (steeper), 0 or +1 (shallower).
func step(delta: float, push := 0) -> void:
	t += delta
	match phase:
		"plasma":
			if rng.randf() < delta * 0.8:
				drift = _new_drift()
			angle += (drift + float(push) * float(D.push_deg_s)) * delta
			angle = clampf(angle, -12.0, -1.0)
			if in_corridor():
				inside_s += delta
			if t >= float(D.plasma_s):
				phase = "chutes"
				t = 0.0
		"chutes":
			# the drogues slow the fall, the mains slow it far more
			var rate := TOP_FT / float(D.fall_s)
			if drogue_err >= 0.0:
				rate *= 0.75
			if main_err >= 0.0:
				rate *= 0.45
			height_ft = maxf(0.0, height_ft - rate * delta)
			# a chute nobody called opens late on its own, at its height minus the window
			if drogue_err < 0.0 and height_ft <= float(D.drogue_ft) - float(D.window_ft):
				drogue_err = float(D.window_ft)
			if main_err < 0.0 and height_ft <= float(D.main_ft) - float(D.window_ft):
				main_err = float(D.window_ft)
			if height_ft <= 0.0:
				phase = "splash"


## The player calls the next chute (key 1 for the drogues, 2 for the mains). Returns what it opened, or "".
func call_chute() -> String:
	if phase != "chutes":
		return ""
	if drogue_err < 0.0:
		drogue_err = absf(height_ft - float(D.drogue_ft))
		return "drogue"
	if main_err < 0.0:
		main_err = absf(height_ft - float(D.main_ft))
		return "main"
	return ""


## 0..1 for a chute called err feet from its height (1 on the mark, 0 at the window's edge or later).
func chute_quality(err: float) -> float:
	return clampf(1.0 - err / float(D.window_ft), 0.0, 1.0) if err >= 0.0 else 0.0


func corridor_quality() -> float:
	return clampf(inside_s / maxf(float(D.plasma_s), 0.001), 0.0, 1.0)


## 1 to 3 stars: half for the corridor, a quarter for each chute. Coming home is always at least one star.
func stars() -> int:
	var q := 0.5 * corridor_quality() + 0.25 * chute_quality(drogue_err) + 0.25 * chute_quality(main_err)
	return 3 if q >= 0.8 else (2 if q >= 0.5 else 1)
