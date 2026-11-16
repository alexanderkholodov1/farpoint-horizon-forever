extends RefCounted
## The climb to orbit the pilot flies on the launch screen. The rocket is a point over a round Earth: thrust along its
## pitch, gravity, and the sideways speed that makes the ground fall away (an orbit is falling around the planet fast
## enough to keep missing it). Each stage burns like the rocket equation says [S10]; Earth's gravity and size come from
## the fact sheet [S-nssdc-planets]. The guidance marker is a gravity turn: straight up, then leaning over as the air
## thins, then flat and fast at about 170 km.
##
## Simplified, and labeled as ours: no drag on speed (air only matters for the stress on the structure, dynamic
## pressure times the angle between where the rocket points and where it moves); the climb's delta-v budget is
## the usual 9.3 to 10 km/s to low orbit [S-delta-v] plus the rocket's own margin; every stage has the same exhaust
## speed; boosters add thrust for the first 40 % of the first stage.
## Time is real: the climb takes the eight minutes or so a real one does. The screen may run it faster with the flight
## panel's time warp (at most ×10 with the engines on); step() takes the real seconds and the warp. The pilot's own
## pace (how long the hands were off the stick) is counted in real seconds, the rocket's in mission seconds.

const FlightData := preload("res://scripts/flight/flight_data.gd")
const ROCKET_DESIGN := "res://scripts/craft/rocket_design.gd"   # loaded when needed: it names GameData

const ORBIT_ALT := 120000.0      ## Lowest height (m) that counts as an orbit.
const BUDGET := 10000.0          ## Climb delta-v (m/s) of a rocket with no margin [S-delta-v].
const STRESS_WARN := 220.0       ## kPa x degrees: the stress gauge turns red.
const STRESS_BREAK := 520.0      ## Above this for BREAK_TIME mission seconds the rocket breaks up.
const BREAK_TIME := 7.2
const STEER_RATE := 1.75         ## Degrees per mission second while the pilot holds a steering key (a real rocket
                                 ## pitches over at about a degree a second).
const ASSIST_AFTER := 2.5        ## Real seconds with hands off the stick before the flight computer holds the marker.
const ASSIST_RATE := 0.875       ## Degrees per mission second the flight computer turns at most.

var R: float
var GM: float
var g0: float
var h := 0.0                     ## Height (m).
var x := 0.0                     ## Distance downrange over the ground (m).
var vx := 0.0                    ## Sideways (orbital) speed, m/s, counting the Earth's spin.
var spin := 0.0                  ## The Earth's spin at the equator, m/s: a free start toward the east.
var vy := 0.0                    ## Vertical speed, m/s.
var t := 0.0                     ## Mission seconds since liftoff.
var pitch := 0.0                 ## Where the rocket points, degrees from straight up toward downrange.
var marker := 0.0                ## Where the guidance wants it to point (smoothed).
var throttle := 1.0
var stages: Array = []           ## [{"name", "dv", "twr", "ve", "used", "tb"}] bottom to top.
var si := 0                      ## Current stage.
var boosters_attached := false
var booster_fuel := 0.0          ## 1 full, 0 empty.
var flameout := false            ## The current stage is empty and waits for STAGE.
var lifted := false
var orbit := false
var by_craft := 0.0              ## m/s the craft's own engine added to finish the climb (0 if the rocket did it all).
var broken := false              ## Torn apart by stress.
var crashed := false             ## Fell back to the ground.
var stress := 0.0                ## kPa x degrees.
var max_stress := 0.0
var red_time := 0.0
var err_sum := 0.0
var err_time := 0.0
var fuel_dropped := 0.0          ## Share of stages dropped with fuel still in them (staged early).
var hands_off := 0.0             ## Real seconds since the pilot last steered.
var assisting := false           ## The flight computer is holding the marker for a hands-off pilot.
var helped_time := 0.0           ## Game seconds above 800 m flown by the flight computer or the autopilot.
var autopilot := false           ## Set by the screen while the autopilot (or the bot pilot) flies.


## Sets up the rocket of a mission: its launcher id and the craft's mass on top (kg).
func setup(launcher_id: String, payload_kg: float, target_orbit: String) -> void:
	R = FlightData.radius_m("earth")
	GM = FlightData.gm("earth")
	g0 = FlightData.gravity("earth")
	# 2 pi x equatorial radius / sidereal day, both from the Earth's fact sheet [S-nssdc-planets]: about 465 m/s
	spin = TAU * FlightData.fact("earth", "equatorial_radius_km", 6378.137) * 1000.0 / (FlightData.fact("earth", "sidereal_rotation_h", 23.9345) * 3600.0)
	vx = spin
	var fractions: Array = [0.39, 0.61]
	var twr := 1.4
	var margin := 0.04
	var with_boosters := launcher_id == "heavy"
	var RocketDesign = load(ROCKET_DESIGN) if launcher_id == "custom" else null
	if RocketDesign != null and RocketDesign.current != null:
		var d = RocketDesign.current
		var perf: Dictionary = d.performance(payload_kg)
		var total: float = perf.dv
		if total > 0.0 and perf.stages.size() > 0:
			fractions = []
			for dv in perf.stages:
				fractions.append(float(dv) / total)
		twr = clampf(d.liftoff_twr(payload_kg), 1.15, 1.9)
		var need: float = RocketDesign.data().targets.get(target_orbit, 9400.0)
		margin = clampf((total - need) / maxf(need, 1.0), 0.0, 0.08)
		with_boosters = d.boosters != ""
	stages = []
	var budget := BUDGET * (1.0 + margin)
	for i in fractions.size():
		var dv: float = maxf(float(fractions[i]) * budget, 150.0)
		var st := {"name": "stage%d" % i, "dv": dv, "twr": twr if i == 0 else 0.85, "ve": 3000.0 if i == 0 else 3400.0, "used": 0.0}
		var mr: float = exp(dv / st.ve)
		st.tb = st.ve * (mr - 1.0) / (mr * st.twr * g0)   # burn time at full throttle (s)
		st.tau = st.tb * mr / (mr - 1.0)
		stages.append(st)
	boosters_attached = with_boosters
	booster_fuel = 1.0 if with_boosters else 0.0


## The guidance marker for the present state, degrees from vertical.
func guidance() -> float:
	if h < 800.0:
		return 0.0
	# lying flat by 96 km and a flight computer that follows briskly: a hands-off climb reaches its orbit's height
	# without overshooting it and falling back (it used to climb 50 km too high and come down for three minutes)
	var tgt := 90.0 * minf(1.0, sqrt((h - 800.0) / 95000.0))
	if h > 60000.0:
		# a gentle target: the vertical speed that would bring it to 190 km in a minute and a half, followed softly, so
		# the climb levels off into its orbit (about 172 km) without nodding up and down or pointing at the Earth
		var want_vy := (190000.0 - h) / 90.0
		var t2 := clampf(90.0 + (vy - want_vy) * 0.06, 60.0, 100.0)
		tgt = lerpf(tgt, t2, smoothstep(60000.0, 90000.0, h))
	return clampf(tgt, 0.0, 100.0)


## Advances the climb by dt real seconds at a time warp of `warp` (mission seconds per real second). steer is -1, 0
## or 1 (the pilot's keys).
func step(dt: float, steer: float, warp := 1.0) -> void:
	if orbit or broken or crashed:
		return
	hands_off = 0.0 if steer != 0.0 else hands_off + dt
	assisting = hands_off > ASSIST_AFTER and lifted
	dt *= warp           # from here on, mission seconds
	if assisting:
		pitch += clampf((marker - pitch) * 0.3, -ASSIST_RATE, ASSIST_RATE) * dt
	pitch = clampf(pitch + steer * STEER_RATE * dt, -30.0, 150.0)
	var n := int(ceil(dt / 0.1))
	var mdt := dt / n
	for _i in n:
		_physics(mdt)
	marker = lerpf(marker, guidance(), clampf(dt * 0.375, 0.0, 1.0))
	if h > 800.0:
		err_sum += absf(pitch - marker) * dt
		err_time += dt
		if assisting or autopilot:
			helped_time += dt
	# stress on the structure
	if stress > STRESS_BREAK:
		red_time += dt
		if red_time > BREAK_TIME:
			broken = true
	else:
		red_time = maxf(0.0, red_time - dt * 2.0)


func _physics(dt: float) -> void:
	var st: Dictionary = stages[si]
	var a := 0.0
	if not flameout:
		a = throttle * st.ve / (st.tau - st.used)
		st.used += throttle * dt
		if st.used >= st.tb:
			st.used = st.tb
			flameout = true
	if boosters_attached:
		if booster_fuel > 0.0:
			a += throttle * 0.45 * g0
			booster_fuel -= throttle * dt / (0.4 * float(stages[0].tb))
		else:
			a *= 0.92   # empty boosters are dead weight until they are dropped
	var r := R + h
	var g := GM / (r * r) - vx * vx / r
	if not lifted:
		if a <= g:
			return
		lifted = true
	var th := deg_to_rad(pitch)
	vx += a * sin(th) * dt
	vy += (a * cos(th) - g) * dt
	h += vy * dt
	x += (vx - spin) * dt
	t += dt
	var ax_ := vx - spin   # speed against the air, which turns with the Earth
	var v := sqrt(ax_ * ax_ + vy * vy)
	var q := 0.5 * 1.225 * exp(-h / 7500.0) * v * v / 1000.0
	var gamma := rad_to_deg(atan2(ax_, vy)) if v > 30.0 else pitch
	stress = q * absf(pitch - gamma)
	max_stress = maxf(max_stress, stress)
	if h < 0.0:
		h = 0.0
		if vy < -5.0:
			crashed = true
		vy = 0.0
	if h >= ORBIT_ALT and vx >= sqrt(GM / r):
		orbit = true
		return
	# the last stage is empty: the craft's own engine finishes the job if the climb is nearly there
	if flameout and si == stages.size() - 1 and not orbit and h > 60000.0:
		by_craft = maxf(0.0, sqrt(GM / r) - vx)
		vx = sqrt(GM / r)
		h = maxf(h, ORBIT_ALT)
		orbit = true


## Drops what is spent: the boosters first, then the current stage. Returns "boosters", "stage" or "".
func stage() -> String:
	if boosters_attached:
		boosters_attached = false
		return "boosters"
	if si < stages.size() - 1:
		var st: Dictionary = stages[si]
		fuel_dropped += (st.tb - st.used) / st.tb
		si += 1
		flameout = false
		return "stage"
	return ""


## Share of the current stage's fuel left, 0 to 1.
func fuel() -> float:
	var st: Dictionary = stages[si]
	return clampf((st.tb - st.used) / st.tb, 0.0, 1.0)


## Speed toward an orbit at this height, 0 to 1.
func orbit_progress() -> float:
	return clampf(vx / sqrt(GM / (R + h)), 0.0, 1.0)


func mean_error() -> float:
	return err_sum / err_time if err_time > 0.0 else 0.0


## True when staging now would help: boosters empty, or the current stage empty.
func wants_stage() -> bool:
	return (boosters_attached and booster_fuel <= 0.0) or (flameout and si < stages.size() - 1)


## What the climb did, for GameState.flight.ascent.
func summary() -> Dictionary:
	return {"orbit": orbit, "mean_error_deg": snappedf(mean_error(), 0.1), "own_share": snappedf(1.0 - helped_time / maxf(err_time, 0.001), 0.01), "max_stress": snappedf(max_stress, 1.0),
		"fuel_left": snappedf(fuel(), 0.01), "fuel_dropped": snappedf(fuel_dropped, 0.01), "by_craft_mps": roundi(by_craft),
		"height_km": snappedf(h / 1000.0, 0.1), "time_s": roundi(t), "broken": broken, "crashed": crashed}
