extends RefCounted
## Mission 6, Artemis I: the scoring rules of its three stages, with no screen (issue #50), so a test can check them
## against NASA's numbers. Launch: boosters off at 2 min 12 s, core stage off at 8 min 03 s [S-artemis-timeline].
## Flyby: from 2,128 to 5,102 mph about 81 miles above the Moon [S-artemis-timeline]. Re-entry: 24,581 mph, Mach 32
## [S-artemis-timeline]; the corridor and the parachute heights are ours. Data: data/missions/artemis1.json.

const DATA_PATH := "res://data/missions/artemis1.json"

var D: Dictionary = {}
var L: Dictionary = {}
var F: Dictionary = {}
var R: Dictionary = {}


func _init() -> void:
	D = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	L = D.launch
	F = D.flyby
	R = D.reentry


## A press on a call at mission time t: 1 on the moment, 0 at the window's edge.
func call_quality(t: float, at: float) -> float:
	return clampf(1.0 - absf(t - at) / float(L.call_window_s), 0.0, 1.0)


## The ignition: 1 right on the zero, 0 a second off.
func ignite_quality(off_s: float) -> float:
	return clampf(1.0 - absf(off_s), 0.0, 1.0)


## The burn: 1 when the speed ends on 5,102 mph, 0 beyond the band.
func burn_quality(mph: float) -> float:
	return clampf(1.0 - absf(mph - float(F.after_mph)) / float(F.band_mph), 0.0, 1.0)


## The re-entry angle's quality at a moment: 1 in the corridor's middle, 0 at its edges.
func corridor_quality(deg: float) -> float:
	var a: Array = R.corridor_deg
	var mid := (float(a[0]) + float(a[1])) * 0.5
	var half := (float(a[1]) - float(a[0])) * 0.5
	return clampf(1.0 - absf(deg - mid) / half, 0.0, 1.0)


func in_corridor(deg: float) -> bool:
	var a: Array = R.corridor_deg
	return deg >= float(a[0]) - 1.5 and deg <= float(a[1]) + 1.5


## A parachute call at height km: 1 on the mark, 0 at the window's edge.
func chute_quality(km: float, at_km: float) -> float:
	return clampf(1.0 - absf(km - at_km) / float(R.call_window_km), 0.0, 1.0)


func score(launch_q: float, flyby_q: float, reentry_q: float) -> float:
	var w: Dictionary = D.score.weights
	return float(w.launch) * launch_q + float(w.flyby) * flyby_q + float(w.reentry) * reentry_q


func stars_for(total: float) -> int:
	var n := 0
	for k in D.score.stars:
		if total >= float(k):
			n += 1
	return n


## Mission elapsed time as text.
func met(s: float) -> String:
	s = maxf(s, 0.0)
	return "T+ %02d:%02d:%02d" % [int(s / 3600.0), int(fmod(s, 3600.0) / 60.0), int(fmod(s, 60.0))]


## Miles per hour as km/h, for the Spanish speakers who think in km.
static func mph_kmh(mph: float) -> float:
	return mph * 1.609344
