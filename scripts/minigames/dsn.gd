extends RefCounted
## The Deep Space Network as numbers, for ground control (issue #9): which of its three complexes sees the craft now,
## how high, how long the light takes, and how far the craft's motion shifts its tone (Doppler). No screen, so
## tests/ci/ground.gd checks the same numbers the mini-game shows.
##   const Dsn := preload("res://scripts/minigames/dsn.gd")
##   var best: Dictionary = Dsn.best_station(unix_time, craft_x, craft_y)
## Our simplifications: the craft's direction is taken from the Earth's centre (no parallax, fine beyond a few Earth
## radii), and the trip lies in the ecliptic like scripts/flight/transfer.gd.

const C := 299792458.0                 ## m/s, the speed of light (exact by definition) [S-codata-c].
const X_BAND_HZ := 8.4e9               ## Deep-space X-band downlink: our figure of about 8.4 GHz; the bands are in [S-descanso-bands].
const OBLIQUITY_DEG := 23.44           ## Tilt of the Earth's axis to the ecliptic [S-usno-gast].
const MIN_ELEV_DEG := 6.0              ## A dish tracks above about this height; lower, the ground and air get in the way (our simplification).

## The three complexes, about 120 degrees apart in longitude so one always sees a far craft [S-dsn-facts].
## Latitude and east longitude in degrees [S-dsn-sites].
const STATIONS := [
	{"id": "goldstone", "name": "Goldstone", "place": "California", "lat": 35.42667, "lon": -116.89, "dish": "DSS-14, 70 m"},
	{"id": "madrid", "name": "Madrid", "place": "Spain", "lat": 40.43139, "lon": -4.24806, "dish": "DSS-63, 70 m"},
	{"id": "canberra", "name": "Canberra", "place": "Australia", "lat": -35.40139, "lon": 148.98167, "dish": "DSS-43, 70 m"},
]


## Greenwich mean sidereal time in degrees at a Unix time (seconds) [S-usno-gast]:
## GMST = 18.697374558 + 24.06570982441908 D hours, D the days since 2000 January 1, 12h UT.
static func gmst_deg(unix: float) -> float:
	var d := unix / 86400.0 + 2440587.5 - 2451545.0
	return fposmod((18.697374558 + 24.06570982441908 * d) * 15.0, 360.0)


## Right ascension and declination (degrees) of a direction in the ecliptic plane at ecliptic longitude lam (degrees).
static func equatorial(lam_deg: float) -> Vector2:
	var lam := deg_to_rad(lam_deg)
	var eps := deg_to_rad(OBLIQUITY_DEG)
	var ra := atan2(cos(eps) * sin(lam), cos(lam))
	var dec := asin(sin(eps) * sin(lam))
	return Vector2(fposmod(rad_to_deg(ra), 360.0), rad_to_deg(dec))


## Height (degrees) of the direction (ra, dec) over the horizon of a station at a Unix time.
static func elevation(st: Dictionary, unix: float, ra_dec: Vector2) -> float:
	var h := deg_to_rad(gmst_deg(unix) + float(st.lon) - ra_dec.x)
	var phi := deg_to_rad(float(st.lat))
	var dec := deg_to_rad(ra_dec.y)
	return rad_to_deg(asin(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(h)))


## The complex that sees the craft highest, with its height: station dict plus "elev". x, y in metres, ecliptic,
## from the Earth's centre (scripts/flight/transfer.gd).
static func best_station(unix: float, x: float, y: float) -> Dictionary:
	var rd := equatorial(rad_to_deg(atan2(y, x)))
	var best := {}
	for st in STATIONS:
		var e := elevation(st, unix, rd)
		if best.is_empty() or e > float(best.elev):
			best = st.duplicate()
			best["elev"] = e
	best["up"] = float(best.elev) > MIN_ELEV_DEG
	return best


## Seconds the light takes to cross distance_m one way.
static func light_s(distance_m: float) -> float:
	return distance_m / C


## The craft's speed along the line of sight (m/s, positive going away).
static func radial(x: float, y: float, vx: float, vy: float) -> float:
	var r := sqrt(x * x + y * y)
	return (x * vx + y * vy) / maxf(r, 1.0)


## How far the craft's tone moves from its X-band frequency (Hz): lower when it goes away (v/c, first order).
static func doppler_hz(radial_mps: float) -> float:
	return -X_BAND_HZ * radial_mps / C
