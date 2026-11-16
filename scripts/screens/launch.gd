extends "res://scripts/screens/screen.gd"
## Launch, flown by the pilot (issue #8): the countdown on the pad among the Andes, then the climb to orbit with the
## pilot's panel (scripts/flight/flight_hud.gd): lean the rocket with the arrows to follow the guidance marker, the
## throttle lever, STAGE to drop what is empty. The climb itself is scripts/flight/ascent.gd. Generous: a hands-off
## pilot gets help from the flight computer, a late STAGE is done for you, and a short climb is finished by the
## craft's own engine. Possible on purpose: holding the stick hard across the airflow at max-Q tears the rocket apart.
## The launcher's own failure, when the mission's luck decided it (GameState.last_sim.launch_failed), still happens.
## Then: the craft separates in orbit, and the flight goes on toward the Moon (screen "flight") when the mission
## lands there, or to the operation; after a loss, to the report. The rocket the player built (Space.make_custom_rocket)
## sheds its boosters and stages as it climbs.

const Space := preload("res://scripts/world/space_builder.gd")
const Ship := preload("res://scripts/world/ship_builder.gd")
const RocketDesign := preload("res://scripts/craft/rocket_design.gd")
const Ascent := preload("res://scripts/flight/ascent.gd")
const FlightHud := preload("res://scripts/flight/flight_hud.gd")
const FlightData := preload("res://scripts/flight/flight_data.gd")
const Scene3D := preload("res://scripts/flight/flight_scene.gd")
const Sound := preload("res://scripts/flight/sound.gd")

const VIS := 0.088              ## Scene units per metre near the pad (the launch screen's scale).
const HORIZON_R := 6000.0       ## Radius of the Earth globe under the climb, in scene units.
const COUNTDOWN := 3.0

var rocket: Node3D
var model                        ## The climb (scripts/flight/ascent.gd).
var hud                          ## The pilot's panel (scripts/flight/flight_hud.gd).
var phase := "countdown"         ## countdown, climb, orbit, lost
var phase_t := 0.0
var throttle := 1.0
var stage_wait := 0.0
var dropped: Array = []          ## Stages and boosters falling away: [node, velocity, spin, age].
var horizon: Node3D
var pad: Node3D
var in_space := false
var fail_at := -1.0              ## Mission second the launcher fails at (its luck), or -1.
var leaving := false
var shake := 0.0
var rumble: AudioStreamPlayer
var sfx := {}
var told := {}                   ## Hints already given.
var craft: Node3D
var fairing_off := false         ## The fairing has split in two and drifted away (in orbit, engine off).
var released := false            ## The springs have pushed the craft off the stage.
## The fairing is dropped "once outside the atmosphere"; some rockets drop it after the upper stage's engine cuts off
## [S-wiki-fairing]. Here it opens in orbit, engine off, so the player sees it split and the craft come out.
var drifting: Array = []         ## The fairing's halves drifting away in orbit: [node, velocity, spin axis, spin, age].
var shell_center := Vector3.INF  ## Where the fairing was, in the scene: the craft rides there.
const HALF_SHELL := """shader_type spatial;
render_mode cull_disabled;
uniform float side = 1.0;
uniform vec4 colour : source_color = vec4(0.93, 0.94, 0.96, 1.0);
varying float lx;
void vertex() { lx = VERTEX.x; }
void fragment() {
	if (lx * side < 0.0) { discard; }
	ALBEDO = colour.rgb;
	ROUGHNESS = 0.55;
}
"""
var rocket_h := 6.0
var old_far := 2000.0
var cam_off := Vector3(6.5, 1.5, 11.0)
var cam_aim := Vector3.INF     ## Where the camera looks, from the rocket's base, damped (INF until the first frame).
var cam_t := 0.0               ## Clock of the camera's wobble.
var user_yaw := 0.0            ## How far the player turned the camera around the rocket (radians).
var user_pitch := 0.0          ## ... and raised or lowered it.
var user_zoom := 1.0           ## ... and moved it nearer (below 1) or farther.
var auto_time := true          ## Time picks its own speed until the pilot picks one.
var base_fov := 75.0           ## The camera's field of view on entering, restored on exit.
var smoke: CPUParticles3D       ## Steam and smoke thrown sideways at ignition (the look of #12).


var shown_pitch := 0.0             ## The pitch the rocket is drawn at, easing toward the model's.

func enter(_args: Dictionary) -> void:
	world.cam_free = false
	world.clear_stage()
	var env: Environment = world.world_env.environment
	Space.apply_day(env)
	env.ambient_light_energy = 0.55
	world.cam.far = 6000.0
	world.sun.rotation_degrees = Vector3(-50, -30, 0)
	pad = Space.make_pad()
	world.stage.add_child(pad)
	rocket = Space.make_rocket(mission.launcher)
	rocket.position = Vector3(0, Space.PAD_TOP, 0)
	world.stage.add_child(rocket)
	# the cloud of steam and smoke the deluge water and the exhaust throw sideways at ignition
	smoke = Space.make_pad_smoke()
	smoke.position = Vector3(1.0, 0.5, 0)
	world.stage.add_child(smoke)
	rocket_h = rocket.get_meta("height", 6.0)
	old_far = world.cam.far
	base_fov = world.cam.fov
	world.cam.far = 9000.0
	world.cam.position = Vector3(7, 2.5, 9)
	world.cam.look_at(Vector3(0, 3, 0), Vector3.UP)
	var r: Dictionary = GameState.last_report
	model = Ascent.new()
	model.setup(mission.launcher, float(r.get("mass_total", 500.0)), mission.orbit)
	if GameState.last_sim.get("launch_failed", false):
		fail_at = randf_range(45.0, 110.0)
	horizon = Scene3D.horizon_earth(HORIZON_R)
	horizon.visible = false
	world.stage.add_child(horizon)
	_build_hud()
	for id in ["beep", "clunk", "boom", "alarm", "chime"]:
		sfx[id] = Sound.player(self, id)
	sfx.boom.volume_db = 0.0   # the explosion at full voice (QUIET_DB suits the beeps, not a rocket blowing up)
	rumble = Sound.player(self, "rumble", -40.0)
	GameState.flight["launcher"] = mission.launcher


func exit() -> void:
	world.cam.far = old_far
	world.cam.fov = base_fov


func _build_hud() -> void:
	hud = FlightHud.new()
	add_child(hud)
	hud.build(tr("LAUNCH") + " · " + tr(RocketDesign.launcher(mission.launcher).name), tr("STAGE"),
		tr("← → lean · W S throttle · Space stage"))
	# real time, as the rules ask; the pilot may speed it up to ×10 while the engines burn
	hud.add_time_warp(1.0)
	hud.add_readout("alt", tr("Height"))
	hud.add_readout("speed", tr("Speed"))
	hud.add_gauge("orbit", tr("Speed toward orbit"), 2.0, 2.0, Kit.C_ACCENT)
	hud.add_gauge("fuel", tr("Fuel in this stage"), 2.0, 2.0, Kit.C_GOLD)
	hud.add_gauge("stress", tr("Stress on the structure"), 0.45, 0.85, Kit.C_OK)
	hud.lever.value = 1.0
	hud.throttle_changed.connect(func(v): throttle = v)
	hud.action_pressed.connect(_on_stage)
	hud.autopilot_toggled.connect(func(on): _say_autopilot(on))
	hud.skip_pressed.connect(_skip)
	hud.warp_picked.connect(func(_w): auto_time = false; hud.auto_note = "")
	hud.add_restart()
	hud.restart_pressed.connect(func(): main.go("launch"))   # fly this part again, whatever happened
	hud.set_autopilot(GameState.pilot_bot)
	hud.clock.text = "T-00:03"
	hud.value("alt", "0 m")
	hud.value("speed", "0 m/s")
	if GameState.pilot_bot:
		hud.hint(tr("The bot pilot is flying. Touch the arrows or the throttle to take the controls."))
	else:
		hud.hint(tr("Your rocket, your stick. Lean with ← → to keep the needle on the green marker, W and S move the throttle, Space drops what is empty."))


func process(delta: float) -> void:
	if rocket == null or not is_instance_valid(rocket):
		return
	phase_t += delta
	smoke.emitting = (phase == "countdown" and phase_t > COUNTDOWN - 0.5) or (phase == "climb" and phase_t < 3.0)
	match phase:
		"countdown":
			_countdown()
		"climb":
			_climb(delta)
		"orbit":
			_orbit(delta)
		"lost":
			if phase_t > 4.2 and not leaving:
				leaving = true
				main.go_faded("report", 0.8, 0.6)
	_fall(delta * hud.warp)
	_camera(delta)
	_flames()
	_sound(delta)


func _countdown() -> void:
	var left := COUNTDOWN - phase_t
	var n := int(ceil(left))
	hud.clock.text = "T-00:0%d" % maxi(n, 0)
	if not told.has("count%d" % n) and n > 0:
		told["count%d" % n] = true
		hud.message(str(n), "", Color.WHITE, 0.6)
		sfx.beep.play()
	if left <= 0.0:
		phase = "climb"
		phase_t = 0.0
		hud.message(tr("LIFTOFF!"), tr("Launching east from the equator: the Earth's spin gives you %d m/s for free.") % roundi(model.spin), Color.WHITE, 2.4)
		GameState.flight_moment("launch", {"launcher": mission.launcher})
		shake = 1.0


func _climb(delta: float) -> void:
	var steer := 0.0
	if hud.autopilot:
		if hud.pilot_input():
			hud.set_autopilot(false)
			_say_autopilot(false)
		else:
			steer = clampf((model.marker - model.pitch) * 0.5, -1.0, 1.0)
	if not hud.autopilot:
		steer = hud.steer().x
		throttle = hud.throttle_keys(throttle, delta)
	model.throttle = throttle
	model.autopilot = hud.autopilot
	hud.cap_warp(10.0, tr("engine on"))
	# time by itself: the liftoff in real time, then ten times faster, and back to real time for the moments that
	# need the pilot (a stage nearly empty, a rocket under stress, the last of the climb); a speed the pilot picks stays
	if auto_time:
		var calm: bool = phase_t > 14.0 and model.fuel() > 0.07 and model.stress < Ascent.STRESS_WARN and model.orbit_progress() < 0.97
		var want_w := 10.0 if calm else 1.0
		if hud.warp != want_w:
			hud.set_warp(want_w)
		hud.auto_note = tr("Auto") if want_w > 1.0 else ""
	model.step(delta, steer, hud.warp)
	# staging: the pilot's job; the autopilot does it at once, the flight computer after a few seconds
	if model.wants_stage():
		stage_wait += delta
		hud.action.lit = true
		if not told.has("stage%d%s" % [model.si, model.boosters_attached]):
			told["stage%d%s" % [model.si, model.boosters_attached]] = true
			if model.boosters_attached:
				hud.hint(tr("The boosters are empty. Press STAGE to drop them and fly lighter."))
			else:
				hud.message(tr("OUT OF FUEL · STAGE!"), tr("This stage's tank is empty and its engines went quiet. Press SPACE (or STAGE) to drop it and light the next one."), Kit.C_WARN, 3.5)
				hud.hint(tr("Real rockets drop each empty stage: dead weight would only slow you down. If you wait, the flight computer does it for you."))
				sfx.alarm.play()
		if stage_wait > (0.6 if hud.autopilot else 3.5):
			_on_stage()
			if not hud.autopilot:
				hud.message(tr("STAGE SEPARATION"), tr("The flight computer staged for you."), Kit.C_ACCENT, 2.0)
	else:
		hud.action.lit = false
	_hints()
	_telemetry()
	_place_rocket()
	if fail_at > 0.0 and model.t >= fail_at:
		_explode(tr("LAUNCHER FAILURE"), tr("Not your flying. Rockets fail now and then, which is why their reliability matters."))
		return
	if model.broken or model.crashed:
		_explode(tr("RAPID UNPLANNED DISASSEMBLY"), tr("Steer hard across the airflow at full speed and a rocket comes apart. Impressive, if that was the plan!"))
		GameState.flight["ascent"] = model.summary()
		GameState.end_flight_early(tr("The rocket came apart in flight"), tr("The pilot swung the rocket hard across the airflow while the air pushed hardest, and it broke up. Spectacular, and the craft went with it."))
		return
	if model.orbit:
		_reach_orbit()


func _hints() -> void:
	if model.assisting and not hud.autopilot and not told.has("assist"):
		told["assist"] = true
		hud.hint(tr("The flight computer is holding the marker for you. Steer any time to take over."))
	elif model.h > 7000.0 and model.h < 20000.0 and not told.has("maxq"):
		told["maxq"] = true
		hud.hint(tr("Max-Q, the moment the air pushes hardest. Stay on the green marker or the stress climbs."))
	elif model.h > 45000.0 and not told.has("lean"):
		told["lean"] = true
		hud.hint(tr("The air is thin now. Lean over flat: reaching orbit means flying sideways at about %.1f km/s.") % (sqrt(model.GM / (model.R + 170000.0)) / 1000.0))
	if model.stress > Ascent.STRESS_WARN and not told.has("stress"):
		told["stress"] = true
		hud.message(tr("STRESS!"), tr("Ease back toward the green marker."), Kit.C_BAD, 1.5)
		sfx.alarm.play()


func _telemetry() -> void:
	hud.clock.text = FlightHud.met_text(model.t)
	hud.value("alt", ("%.1f km" % (model.h / 1000.0)) if model.h >= 1000.0 else ("%d m" % int(model.h)))
	# low down the speed a player expects is over the ground (on the pad it is 0); higher up, the orbital speed,
	# which counts the Earth's spin (the free 465 m/s that LIFTOFF! told about)
	var low: bool = model.h < 40000.0
	var gx: float = model.vx - (model.spin if low else 0.0)
	var v: float = sqrt(gx * gx + model.vy * model.vy)
	var vs: String = ("%.2f km/s" % (v / 1000.0)) if v >= 1000.0 else ("%d m/s" % int(v))
	hud.value("speed", vs + ("" if low else "  " + tr("(orbital)")))
	var op: float = model.orbit_progress()
	hud.gauge("orbit", op, "%d %%" % roundi(op * 100.0))
	hud.gauge("fuel", model.fuel(), "%d %%" % roundi(model.fuel() * 100.0))
	var sf: float = model.stress / Ascent.STRESS_BREAK
	hud.gauge("stress", sf, tr("high") if sf >= 0.85 else (tr("rising") if sf >= 0.45 else tr("calm")))
	hud.dial.pitch = model.pitch
	hud.dial.marker = model.marker


## The globe below is drawn as a planet six times smaller seen from the true height: its height AND the ground flown
## over are both multiplied by SCALE_DOWN, so more of the globe shows and its curve reads, while the ground slides by
## at its true rate as seen from the craft (v / h, about 2.5 degrees a second in a 167 km orbit). Our simplification.
const SCALE_DOWN := 6.0


## The rocket's place in the scene: true scale near the pad, compressed higher up (the camera follows it there).
func _place_rocket() -> void:
	var vx: float = _squash(model.x, 1000.0, 0.08) * VIS
	var vy: float = 0.2 + _squash(model.h, 1500.0, 0.1) * VIS
	rocket.position = Vector3(vx, vy, 0)
	# the rocket turns smoothly toward its true attitude (the dial shows the true one)
	shown_pitch = model.pitch if absf(model.pitch - shown_pitch) > 30.0 else lerpf(shown_pitch, model.pitch, clampf(get_process_delta_time() * 3.5, 0.0, 1.0))
	rocket.rotation = Vector3(0, 0, -deg_to_rad(shown_pitch))
	if model.h > 15000.0:
		pad.visible = false
		horizon.visible = true
		# the height is drawn six times higher than it is, so the globe below shows more than a blurry patch
		Scene3D.horizon_place(horizon, rocket.position, HORIZON_R, model.h * SCALE_DOWN, model.R, model.x * SCALE_DOWN)
	# the sky darkens on the way up, and the stars come out in space
	var k: float = clampf(model.h / 45000.0, 0.0, 1.0)
	var env: Environment = world.world_env.environment
	# the haze of the Andes thins as the rocket climbs above the air, and is gone once the globe shows (look, #12)
	# ...with a veil of high haze right where the Andes terrain hands over to the globe at 15 km, so the switch reads
	# as climbing through haze rather than as a cut
	var veil: float = exp(-pow((model.h - 15000.0) / 1800.0, 2.0))
	env.fog_density = lerpf(0.00042, 0.00006, clampf(model.h / 15000.0, 0.0, 1.0)) + veil * 0.0016
	env.fog_enabled = model.h <= 19000.0
	if not in_space:
		var sky_m = env.sky.sky_material
		if sky_m is ProceduralSkyMaterial:
			sky_m.sky_top_color = Color(0.18, 0.4, 0.78).lerp(Color(0, 0, 0.02), k)
			sky_m.sky_horizon_color = Color(0.62, 0.74, 0.88).lerp(Color(0.05, 0.08, 0.15), k)
			# below the horizon line the sky's "ground" shows between it and the globe's limb: the same colour as the
			# horizon, so no grey band appears there (look, #12)
			sky_m.ground_horizon_color = sky_m.sky_horizon_color
			sky_m.ground_bottom_color = sky_m.sky_horizon_color.darkened(0.25)
		env.ambient_light_energy = lerpf(0.55, 0.3, k)
		if model.h > 55000.0:
			in_space = true
			env.sky = Space.make_space_sky()


static func _squash(m: float, knee: float, slope: float) -> float:
	return m if m < knee else knee + (m - knee) * slope


## The chase camera (look by issue #12; flight by #8). It stays on the side it starts on (no swing across the rocket),
## follows and aims with damping so liftoff reads fast but steady, shakes with a smooth low wobble rather than a new
## random jolt every frame, and widens its view a little with speed so the climb still feels quick.
func _camera(delta: float) -> void:
	var cam: Camera3D = world.cam
	if phase == "countdown":
		return
	cam_t += delta
	var rp := rocket.position
	var s := maxf(rocket_h / 6.0, 0.6)
	var hk: float = clampf((model.h - 12000.0) / 40000.0, 0.0, 1.0)
	# higher up the camera moves to the side of the flight's plane (+Z), a little above: the rocket turns in that plane,
	# so from the side its attitude against the horizon reads as it is (from ahead it looked nose-down)
	var want: Vector3 = Vector3(6.5, 1.5, 11.0).lerp(Vector3(1.5, 5.5, 11.5), hk) * s
	if phase == "orbit":
		# in orbit the camera comes near the top of the stage to watch the fairing open and the craft unfold
		want = Vector3(1.2, 6.0, 10.0).lerp(Vector3(0.8, 2.2, 4.2), smoothstep(0.3, 2.0, phase_t)) * s
	if phase == "climb" and phase_t < 4.0:
		# liftoff seen from the pad: the camera stays put a moment, then eases up after the rocket from the same side
		var k: float = smoothstep(0.6, 4.0, phase_t)
		k = k * k * (3.0 - 2.0 * k)
		var target_pos: Vector3 = Vector3(7, 2.5, 9).lerp(rp + want, k)
		cam.position = cam.position.lerp(target_pos, clampf(delta * 6.0, 0.0, 1.0))
		cam_off = cam.position - rp
	else:
		cam_off = cam_off.lerp(want, clampf(delta * 1.2, 0.0, 1.0))
		# the player turns the camera around the rocket (drag, or Q and E) and moves it nearer or farther (the wheel,
		# or the + and - keys); the view the game picks is the starting point, never a cage
		if Input.is_physical_key_pressed(KEY_Q):
			user_yaw -= delta * 1.2
		if Input.is_physical_key_pressed(KEY_E):
			user_yaw += delta * 1.2
		if Input.is_physical_key_pressed(KEY_EQUAL) or Input.is_physical_key_pressed(KEY_KP_ADD):
			user_zoom = maxf(0.4, user_zoom - delta * 0.8)
		if Input.is_physical_key_pressed(KEY_MINUS) or Input.is_physical_key_pressed(KEY_KP_SUBTRACT):
			user_zoom = minf(3.0, user_zoom + delta * 0.8)
		var off: Vector3 = cam_off.rotated(Vector3.UP, user_yaw)
		var flat := Vector3(off.x, 0.0, off.z)
		var len := off.length() * user_zoom
		var elev := clampf(atan2(off.y, flat.length()) + user_pitch, -0.6, 1.35)
		cam.position = rp + (flat.normalized() * cos(elev) + Vector3.UP * sin(elev)) * len
	var shake_now: float = shake + (model.stress / Ascent.STRESS_BREAK * 0.6 if phase == "climb" else 0.0)
	if phase == "climb" and model.h < 3000.0:
		shake_now += throttle * 0.35
	shake = maxf(0.0, shake - delta * 0.8)
	# a smooth wobble: a few slow sines instead of white noise
	var wob := Vector3(sin(cam_t * 11.0) + 0.5 * sin(cam_t * 23.0 + 1.3), sin(cam_t * 9.0 + 0.7) + 0.5 * sin(cam_t * 19.0), 0.0)
	var jitter: Vector3 = wob * shake_now * 0.03 * s
	# the aim is smoothed relative to the rocket, never in the world: at orbital speed a world-space lag left the
	# rocket behind the frame (it moves tens of units a second while the aim caught up)
	var aim_off := rocket.global_transform.basis.y * rocket_h * 0.5
	if phase == "orbit" and craft and is_instance_valid(craft):
		aim_off = aim_off.lerp(craft.global_position - rp, smoothstep(0.3, 2.0, phase_t))
	cam_aim = aim_off if cam_aim == Vector3.INF else cam_aim.lerp(aim_off, clampf(delta * 5.0, 0.0, 1.0))
	cam.look_at(rp + cam_aim + jitter, Vector3.UP)
	# the sense of speed: the view widens a little as the rocket gains speed
	var spd: float = sqrt(model.vx * model.vx + model.vy * model.vy)
	var fov_goal: float = base_fov + clampf(spd / 2500.0, 0.0, 1.0) * 8.0
	cam.fov = lerpf(cam.fov, fov_goal, clampf(delta * 1.5, 0.0, 1.0))


func _flames() -> void:
	var flames := rocket.get_node_or_null("Flames") as Node3D
	if flames == null:
		return
	var on: bool = phase == "climb" and not model.flameout and throttle > 0.02 and model.lifted
	if phase == "countdown":
		on = phase_t > COUNTDOWN - 0.6
	var spread: float = 1.0 + 1.6 * clampf(model.h / 60000.0, 0.0, 1.0)   # the plume opens up in thin air
	flames.visible = on
	flames.scale = Vector3(spread, lerpf(0.45, 1.0, throttle), spread)
	for f in flames.get_children():
		if f is CPUParticles3D:
			if f.has_meta("booster"):
				f.emitting = on and model.boosters_attached and model.booster_fuel > 0.0
			else:
				f.emitting = on


func _sound(delta: float) -> void:
	var loud: bool = phase == "climb" and not model.flameout and model.lifted or (phase == "countdown" and phase_t > COUNTDOWN - 0.6)
	if loud and not rumble.playing:
		rumble.play()
	var air: float = 1.0 - clampf(model.h / 50000.0, 0.0, 0.85)    # the roar fades as the air thins
	var target: float = lerpf(-34.0, -9.0, throttle * air) if loud else -60.0
	rumble.volume_db = lerpf(rumble.volume_db, target, clampf(delta * 4.0, 0.0, 1.0))
	rumble.pitch_scale = 0.75 + 0.35 * throttle + 0.04 * sin(Time.get_ticks_msec() / 370.0)
	if rumble.volume_db < -55.0 and rumble.playing:
		rumble.stop()


func _on_stage() -> void:
	if phase != "climb":
		return
	var what: String = model.stage()
	if what == "":
		return
	stage_wait = 0.0
	hud.action.lit = false
	sfx.clunk.play()
	shake = 0.6
	_visual_stage(what)
	hud.message(tr("BOOSTERS AWAY") if what == "boosters" else tr("STAGE SEPARATION"), "", Kit.C_ACCENT, 1.6)
	GameState.flight_moment("staging", {"what": what, "stage": model.si, "t": roundi(model.t)})
	if what == "stage" and not told.has("why_stage"):
		told["why_stage"] = true
		hud.hint(tr("Staging drops an empty tank and its engines, so the rest of the rocket is lighter and goes faster on the fuel it has left."))


## Drops the boosters or the lowest stage of the rocket the player built; the catalog rockets let out a puff of gas.
func _visual_stage(what: String) -> void:
	var asm := rocket.find_child("Assembled", true, false) as Node3D
	var at := rocket.global_position
	world.stage.add_child(Scene3D.puff(at + rocket.global_transform.basis.y * rocket_h * 0.35, rocket_h * 0.25))
	if asm == null:
		return
	if what == "boosters":
		var b := asm.get_node_or_null("Boosters") as Node3D
		if b:
			_drop(b, Vector3(0, -0.4, 0))
			for f in rocket.get_node("Flames").get_children():
				if f.has_meta("booster"):
					f.queue_free()
	else:
		var s0 := asm.get_node_or_null("Stage%d" % (model.si - 1)) as Node3D
		if s0 and asm.get_child_count() > 1:
			_drop(s0, Vector3(0, -0.8, 0))
			var flames := rocket.get_node("Flames") as Node3D
			flames.position.y = rocket.get_meta("stage1_y", 0.0)


## The fairing splits along its seam and its two halves fall away, one to each side, and the craft that rode inside
## shows on top of the last stage. Its solar wings stay folded until the craft is on its own.
func _drop_fairing() -> void:
	fairing_off = true
	var meshes: Array = []
	for n in rocket.find_children("*", "Node3D", true, false):
		var nm := String(n.name).to_lower()
		if nm.contains("fairing") or nm.contains("seam"):
			if n is MeshInstance3D:
				meshes.append(n)
			for m in n.find_children("*", "MeshInstance3D", true, false):
				if not meshes.has(m):
					meshes.append(m)
	var shader := Shader.new()
	shader.code = HALF_SHELL
	var right: Vector3 = rocket.global_transform.basis.x
	var up: Vector3 = rocket.global_transform.basis.y
	for m in meshes:
		var mi := m as MeshInstance3D
		if not mi.visible:
			continue
		for side in [-1.0, 1.0]:
			var half := MeshInstance3D.new()
			half.mesh = mi.mesh
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("side", side)
			half.material_override = mat
			# the half turns about its own middle, not about the mesh's origin at the foot of the rocket (that swung it
			# in a wide arc up across the screen)
			var pivot := Node3D.new()
			world.stage.add_child(pivot)
			pivot.global_position = mi.global_transform * mi.mesh.get_aabb().get_center()
			pivot.add_child(half)
			half.global_transform = mi.global_transform
			# the halves swing open around their base and drift off sideways, slowly: nothing pulls them down here
			var axis: Vector3 = rocket.global_transform.basis.z.normalized()
			# each half moves a little out to its side and back along the stage, so neither crosses the craft or the text
			drifting.append([pivot, right * side * rocket_h * 0.006 - up * rocket_h * 0.03, axis, -side * 0.12, 0.0])
		if String(mi.name).to_lower().contains("fairing") and not String(mi.name).to_lower().contains("seam"):
			shell_center = mi.global_transform * mi.mesh.get_aabb().get_center()
		mi.visible = false
	_ride_craft()
	sfx.clunk.play()
	hud.message(tr("FAIRING OPEN"), tr("Out of the air, the shell that protected your craft through the climb splits in two and drifts away."), Color.WHITE, 2.4)


## The craft on top of the last stage, where the fairing was, with its wings folded.
func _ride_craft() -> void:
	if craft != null:
		return
	craft = Ship.build(mission)
	var r: float = craft.get_meta("radius")
	craft.scale = Vector3.ONE * (rocket_h * 0.12 / r)
	rocket.add_child(craft)
	craft.rotation = Vector3(PI / 2.0, 0.0, 0.0)   # its wings' faces toward the camera's side, so the unfolding shows
	if shell_center != Vector3.INF:
		craft.global_position = shell_center
	else:
		craft.position = Vector3(0, rocket_h * 0.96, 0)
	for w in craft.find_children("Wing*", "Node3D", true, false):
		(w as Node3D).scale.x = 0.04
	for ap in craft.find_children("*", "AnimationPlayer", true, false):
		var a := ap as AnimationPlayer
		if a.has_animation("deploy"):
			a.play("deploy")
			a.seek(0.0, true)
			a.pause()


## The craft on its own: its wings unfold as on a real deployment, and a CubeSat plays its own deploy.
func _unfold_wings() -> void:
	for w in craft.find_children("Wing*", "Node3D", true, false):
		var n := w as Node3D
		n.create_tween().tween_property(n, "scale:x", 1.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for ap in craft.find_children("*", "AnimationPlayer", true, false):
		var a := ap as AnimationPlayer
		if a.has_animation("deploy"):
			a.play("deploy")


func _drop(n: Node3D, vel: Vector3) -> void:
	var xf := n.global_transform
	n.get_parent().remove_child(n)
	world.stage.add_child(n)
	n.global_transform = xf
	dropped.append([n, vel, randf_range(-0.6, 0.6), 0.0])


func _fall(delta: float) -> void:
	for d in dropped.duplicate():
		var n: Node3D = d[0]
		if not is_instance_valid(n):
			dropped.erase(d)
			continue
		d[3] += delta
		d[1] += Vector3(-0.6, -3.0, 0) * delta
		n.global_position += d[1] * delta
		n.rotate_z(d[2] * delta)
		if d[3] > 6.0:
			n.queue_free()
			dropped.erase(d)


func _reach_orbit() -> void:
	phase = "orbit"
	phase_t = 0.0
	hud.action.lit = false
	var s: Dictionary = model.summary()
	GameState.flight["ascent"] = s
	GameState.flight_moment("orbit", s)
	sfx.chime.play()
	var small := tr("You are falling around the Earth, fast enough to keep missing it.")
	if s.by_craft_mps > 0:
		small = tr("The craft's own engine added the last %d m/s. You are falling around the Earth, fast enough to keep missing it.") % s.by_craft_mps
	hud.message(tr("ORBIT!"), small, Kit.C_OK, 3.5)
	hud.hint(tr("Average distance from the marker %.1f degrees. Fuel left in the last stage %d %%.") % [s.mean_error_deg, roundi(s.fuel_left * 100.0)])


func _orbit(delta: float) -> void:
	# in orbit nothing stops: the stage and the craft keep crossing the sky at orbital speed (7.8 km/s), so the Earth
	# keeps turning beneath them at the speed time runs
	var dt: float = delta * hud.warp
	model.t += dt   # the mission clock keeps running in orbit, and the screen shows it
	hud.clock.text = FlightHud.met_text(model.t)
	model.x += (model.vx - model.spin) * dt
	Scene3D.horizon_place(horizon, rocket.position, HORIZON_R, model.h * SCALE_DOWN, model.R, model.x * SCALE_DOWN)
	# the craft separates: springs push it off the stage at about half a metre a second; the stage turns slowly away
	# engine off, the stage turns to point along its motion (prograde, level in a round orbit) before it lets the craft
	# go, as stages do before a deployment; until the springs fire it carries the craft round with it
	if not released:
		rocket.rotation.z = lerp_angle(rocket.rotation.z, -PI / 2.0, clampf(delta * 1.4, 0.0, 1.0))
	for d in drifting.duplicate():
		var n: Node3D = d[0]
		if not is_instance_valid(n):
			drifting.erase(d)
			continue
		d[4] += delta
		n.global_position += d[1] * delta
		if d[4] < 3.0:   # each half swings open on its own side, then just drifts off
			n.rotate(d[2], d[3] * delta)
		if d[4] > 6.5:
			n.queue_free()
			drifting.erase(d)
	if not fairing_off and phase_t > 0.6:
		_drop_fairing()
	if not released and phase_t > 2.6:
		released = true
		var xf := craft.global_transform
		rocket.remove_child(craft)
		world.stage.add_child(craft)
		craft.global_transform = xf
		craft.position += rocket.global_transform.basis.y * rocket_h * 0.04   # the springs' first push
		world.stage.add_child(Scene3D.puff(craft.position, rocket_h * 0.05))
		get_tree().create_timer(1.2).timeout.connect(func(): if is_instance_valid(craft): _unfold_wings())
		sfx.clunk.play()
		var O: Dictionary = GameData.ORBITS.get(mission.orbit, {})
		var up: String = ""
		if not O.is_empty() and str(O.get("body", "tierra")) == "tierra":
			# real launches stop in a low parking orbit first; the last stage or the craft climbs to the final one later
			up = "  " + tr("From this low parking orbit it climbs on to its own: %s.") % tr(str(O.get("name", "")))
		hud.message(tr("CRAFT AWAY"), tr("Springs push your craft off the rocket's last stage. It is on its own now.") + up, Color.WHITE, 3.5)
	if craft and released:
		var push := rocket.global_transform.basis.y * 0.5 * VIS * dt      # 0.5 m/s, in scene units
		craft.position += push
		rocket.position -= push * 0.3                                    # the heavier stage recoils a little
		craft.rotate_object_local(Vector3.UP, 0.04 * dt)
		rocket.rotate_object_local(Vector3.FORWARD, -0.02 * dt)          # the stage turns away from the craft
	if phase_t > 9.0 and not leaving:
		leaving = true
		var next := "operation"
		if FlightData.has_landing(mission.scenario) and main.SCREENS.has("flight"):
			next = "flight"
		main.go_faded(next, 0.8, 0.8)


func _explode(big_text: String, small_text: String) -> void:
	phase = "lost"
	phase_t = 0.0
	hud.message(big_text, small_text, Kit.C_BAD, 0.0)
	hud.hint("")
	hud.action.lit = false
	GameState.flight_moment("launch_lost", {"t": roundi(model.t), "height_km": snappedf(model.h / 1000.0, 0.1)})
	var pos: Vector3 = rocket.position + rocket.global_transform.basis.y * rocket_h * 0.4
	rocket.visible = false
	var boom := Space.make_explosion()
	boom.position = pos
	boom.scale = Vector3.ONE * maxf(rocket_h / 6.0, 0.6)
	world.stage.add_child(boom)
	for e in boom.get_children():
		(e as CPUParticles3D).emitting = true
	world.stage.add_child(Scene3D.debris(pos, rocket_h * 0.06))
	var flash := OmniLight3D.new()
	flash.position = pos
	flash.light_energy = 16.0
	flash.omni_range = 60.0
	flash.light_color = Color(1, 0.6, 0.3)
	world.stage.add_child(flash)
	flash.create_tween().tween_property(flash, "light_energy", 0.0, 1.5)
	sfx.boom.play()
	rumble.stop()
	shake = 2.0


func _say_autopilot(on: bool) -> void:
	if on:
		hud.hint(tr("Autopilot on. It flies a clean climb; touch any control to fly it yourself."))
	else:
		hud.hint(tr("You have the controls."))


## Skip: the bot pilot flies the rest of the climb at once and the rocket appears in orbit.
func _skip() -> void:
	if phase == "countdown":
		phase = "climb"
		phase_t = 3.0
	if phase != "climb":
		return
	for _i in 6000:
		if model.orbit or model.broken or model.crashed:
			break
		model.throttle = 1.0
		model.step(1.0 / 30.0, clampf((model.marker - model.pitch) * 0.5, -1.0, 1.0), 8.0)
		if model.wants_stage():
			var what: String = model.stage()
			if what != "":
				_visual_stage(what)
				GameState.flight_moment("staging", {"what": what, "stage": model.si, "t": roundi(model.t)})
		if fail_at > 0.0 and model.t >= fail_at:
			break
	throttle = 1.0
	hud.lever.value = 1.0
	_telemetry()
	_place_rocket()
	cam_off = Vector3(-4.0, 3.5, 8.0) * maxf(rocket_h / 6.0, 0.6)


## The mouse turns the camera around the rocket (drag) and moves it nearer or farther (the wheel).
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and (e.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)) != 0:
		user_yaw -= e.relative.x * 0.006
		user_pitch = clampf(user_pitch + e.relative.y * 0.005, -1.2, 1.2)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
		user_zoom = maxf(0.4, user_zoom * 0.9)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		user_zoom = minf(3.0, user_zoom * 1.1)
