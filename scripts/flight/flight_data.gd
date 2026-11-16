extends RefCounted
## The numbers the pilot's flight reads from NASA data at run time, and the flight block of a scenario.
##   const FlightData := preload("res://scripts/flight/flight_data.gd")
## Earth's and the Moon's gravity and size come from the NSSDC fact sheets [S-nssdc-planets]
## (data/nasa/nssdc_factsheets.json); the Moon's distance and direction on the day of the flight from JPL Horizons
## [S-horizons] (data/nasa/horizons_moon.json); the landing ground from LOLA [S-lola] (data/nasa/lola_south_pole.json).
## All static, so scripts started with -s can use it too.

const GD := preload("res://scripts/core/game_data.gd")
const FACTS := "res://data/nasa/nssdc_factsheets.json"
const MOON_EPHEMERIS := "res://data/nasa/horizons_moon.json"

static var _cache := {}


static func _json(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var out := {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			out = d
	else:
		push_error("FlightData: cannot open " + path)
	_cache[path] = out
	return out


## A value of a body's fact sheet [S-nssdc-planets], or `fallback` if the file lacks it.
static func fact(body: String, key: String, fallback: float) -> float:
	var b: Dictionary = _json(FACTS).get("bodies", {}).get(body, {})
	return float(b.get(key, {}).get("value", fallback))


## Surface gravity in m/s2: the Moon 1.62, the Earth 9.82 [S-nssdc-planets].
static func gravity(body: String) -> float:
	return fact(body, "gravity_m_s2", 1.62 if body == "moon" else 9.82)


## Mean radius in metres [S-nssdc-planets].
static func radius_m(body: String) -> float:
	return fact(body, "mean_radius_km", 1737.4 if body == "moon" else 6371.0) * 1000.0


## GM in m3/s2 [S-nssdc-planets] (the fact sheet gives 10^6 km3/s2).
static func gm(body: String) -> float:
	return fact(body, "gm_1e6_km3_s2", 0.0049 if body == "moon" else 0.3986) * 1.0e15


## The Moon `day` days after the first row of the ephemeris (2026-11-15, the day of the flight) [S-horizons]:
## {"distance_km", "dir" (unit Vector3, ecliptic x, y, z), "date"}.
static func moon_at(day := 0) -> Dictionary:
	var rows: Array = _json(MOON_EPHEMERIS).get("moon", [])
	if rows.is_empty():
		return {"distance_km": 384400.0, "dir": Vector3(1, 0, 0), "date": ""}
	var r: Dictionary = rows[clampi(day, 0, rows.size() - 1)]
	var v := Vector3(r.x_km, r.y_km, r.z_km)
	return {"distance_km": v.length(), "dir": v.normalized(), "date": str(r.date).substr(0, 11)}


## The Moon's rows from JPL Horizons [S-horizons], one per day from 2026-11-15 00:00 UTC, positions in km and
## velocities in km/s (x, y, z in the ecliptic, from the Earth's centre).
static func moon_rows() -> Array:
	return _json(MOON_EPHEMERIS).get("moon", [])


## The flight block of a scenario (data/scenarios.json, `flight`), or {} when its mission has no pilot's flight.
static func scenario_flight(scenario_id: String) -> Dictionary:
	if not GD.SCENARIOS.has(scenario_id):
		return {}
	return GD.SCENARIOS[scenario_id].get("flight", {})


## True when the scenario flies on to the Moon and lands (it has a landing block).
static func has_landing(scenario_id: String) -> bool:
	return scenario_flight(scenario_id).has("landing")


## The LOLA landing tile [S-lola]: {"meta": {...}, "heights": [[metres]]}.
static func terrain(path: String) -> Dictionary:
	return _json("res://" + path if not path.begins_with("res://") else path)
