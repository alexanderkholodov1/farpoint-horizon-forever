extends "res://scripts/screens/screen.gd"
## The landing at the Moon's south pole, flown by the pilot (issue #8). The ground is NASA's LOLA heights around
## Shackleton's rim (scripts/flight/terrain.gd); the lander falls under the Moon's gravity (scripts/flight/descent.gd).
## The pilot works the throttle (W/S or the lever, Space holds a hover) and pushes across the ground with the arrows.
## Generous: a pilot who lets go of the controls gets the flight computer after a moment, and the bot pilot can fly the
## whole descent. Possible on purpose: holding the engine off all the way down makes a crater.
## Halfway down the 1202 alarm rings, as it did on Apollo 11 [S-alsj-1202]; ground control answers (scripts/flight/ground.gd).
## Touchdown records GameState.flight.landing, settles the extra objectives and goes on to the operation; a crater
## ends the flight early and goes to the report.

const Space := preload("res://scripts/world/space_builder.gd")
const FlightHud := preload("res://scripts/flight/flight_hud.gd")
const FlightData := preload("res://scripts/flight/flight_data.gd")
const Scene3D := preload("res://scripts/flight/flight_scene.gd")
const Sound := preload("res://scripts/flight/sound.gd")
const Terrain := preload("res://scripts/flight/terrain.gd")
const Descent := preload("res://scripts/flight/descent.gd")
const Ground := preload("res://scripts/flight/ground.gd")

const HANDS_OFF := 2.5          ## Seconds without touching anything before the flight computer helps.
const EARTH_DIST := 9000.0      ## Metres to the Earth's globe in the sky (a backdrop: its size is right, not its distance).
const EARTH_ANGLE_DEG := 1.9    ## The Earth's width in the Moon's sky: 12,742 km seen from 384,400 km [S-nssdc-planets].

var land: Dictionary
var terrain
var model
var hud
var lander: Node3D
var flame: CPUParticles3D
var dust: CPUParticles3D
var marker: Node3D
var phase := "descent"          ## descent, down, lost
var phase_t := 0.0
var throttle := 0.0
var idle := 0.0
var helped := false             ## The flight computer is flying (hands off, or the autopilot).
var alarm_rung := false
var leaving := false
var old_far := 2000.0
var old_ambient: Array = []
var sfx := {}
var rumble: AudioStreamPlayer
var told := {}
var shake := 0.0


func enter(_args: Dictionary) -> void:
	land = FlightData.scenario_flight(mission.scenario).get("landing", {})
	world.cam_free = false
	world.clear_stage()
	var env: Environment = world.world_env.environment
	# The Sun only grazes the ground, so a flat plain gets almost no direct light. The eye (and a camera) adapts to
	# that: an even grey fill shows the lit ground, while the shadows the terrain bakes in its colors stay black.
	old_ambient = [env.ambient_light_source, env.ambient_light_color]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.63, 0.66)
	env.ambient_light_energy = 0.6
	old_far = world.cam.far
	world.cam.far = 14000.0
	world.cam.near = 0.2
	terrain = Terrain.new()
	terrain.setup(land)
	world.stage.add_child(terrain.build_mesh())
	world.sun.light_energy = 1.6
	world.sun.basis = Basis.looking_at(-terrain.sun_dir, Vector3.UP)
	var earth := Space.make_earth(EARTH_DIST * tan(deg_to_rad(EARTH_ANGLE_DEG * 0.5)), false)
	earth.position = terrain.earth_dir * EARTH_DIST
	world.stage.add_child(earth)
	model = Descent.new()
	model.setup(land, terrain)
	var tli: Dictionary = GameState.flight.get("tli", {})
	model.spend_fuel(float(tli.get("lander_fuel_used", 0.0)))
	lander = Scene3D.lander(mission, 3.2, Descent.LEG)
	world.stage.add_child(lander)
	flame = Space.make_vacuum_flame(0.45)
	lander.get_node("Nozzle").add_child(flame)
	dust = Scene3D.dust_ring(Vector3.ZERO, 3.0)
	world.stage.add_child(dust)
	marker = _target_marker()
	world.stage.add_child(marker)
	_build_hud()
	for id in ["beep", "clunk", "boom", "alarm", "chime"]:
		sfx[id] = Sound.player(self, id)
	sfx.boom.volume_db = 0.0   # the explosion at full voice (QUIET_DB suits the beeps, not a rocket blowing up)
	rumble = Sound.player(self, "rumble", -40.0)
	throttle = model.hover_throttle() * 0.8
	hud.lever.value = throttle
	_place()
	world.cam.position = lander.position + Vector3(14, 10, 34)
	world.cam.look_at(lander.position, Vector3.UP)
	GameState.flight_moment("descent", {"height_m": roundi(model.altitude())})


func exit() -> void:
	world.cam.far = old_far
	world.cam.near = 0.05
	var env: Environment = world.world_env.environment
	env.ambient_light_source = old_ambient[0]
	env.ambient_light_color = old_ambient[1]


func _build_hud() -> void:
	hud = FlightHud.new()
	add_child(hud)
	hud.build(tr("LANDING") + " · " + tr("Shackleton's rim"), tr("HOVER"),
		tr("W S throttle · arrows push across · Space hover"), true, false)
	hud.add_time_warp(1.0)
	hud.cap_warp(1.0, tr("near the ground"))
	hud.add_readout("alt", tr("Height"))
	hud.add_readout("vs", tr("Falling at"))
	hud.add_readout("hs", tr("Drifting at"))
	hud.add_readout("target", tr("To the target"))
	hud.add_gauge("fuel", tr("Fuel"), 2.0, 2.0, Kit.C_GOLD)
	hud.throttle_changed.connect(_on_lever)
	hud.action_pressed.connect(_hover)
	hud.autopilot_toggled.connect(func(on): hud.hint(tr("Autopilot on. It sets you down on the target; touch any control to fly it yourself.") if on else tr("You have the controls.")))
	hud.skip_pressed.connect(_skip)
	hud.add_restart()
	hud.restart_pressed.connect(func(): main.go("landing"))   # fly this part again, whatever happened
	hud.set_autopilot(GameState.pilot_bot)
	if GameState.pilot_bot:
		hud.hint(tr("The bot pilot is landing. Touch the throttle or the arrows to take the controls."))
	else:
		hud.hint(tr("Fly down to the green ring. More throttle slows your fall; the arrows push you across the ground. Touch down slower than 3 m/s."))
	# the descent from lunar orbit to here is flown by the computer and not shown: say so (#57, "cut without a word")
	hud.message(tr("THE LAST STRETCH"), tr("The computer flew you down from orbit to here. The last few hundred metres are yours."), Kit.C_ACCENT, 3.2)


## A ring of light on the ground around the landing target, so the pilot can see where to go.
func _target_marker() -> Node3D:
	var n := Node3D.new()
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 9.0
	t.outer_radius = 10.0
	t.rings = 48
	ring.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.4, 1.0, 0.55, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = m
	ring.position = Vector3(0, terrain.height(0, 0) + 0.4, 0)
	n.add_child(ring)
	var lbl := Space.make_label(tr("Landing site"), Color(0.5, 1.0, 0.6))
	lbl.position = Vector3(0, terrain.height(0, 0) + 14.0, 0)
	n.add_child(lbl)
	return n


func process(delta: float) -> void:
	phase_t += delta
	match phase:
		"descent":
			_fly(delta)
		"down", "lost":
			if phase_t > 5.5 and not leaving:
				leaving = true
				main.go_faded("report" if phase == "lost" else "operation", 1.0, 0.8)
	_place()
	_camera(delta)
	_effects(delta)


func _fly(delta: float) -> void:
	var steer: Vector2 = hud.steer()
	var touched: bool = hud.pilot_input()
	throttle = hud.throttle_keys(throttle, delta, 0.6)
	if touched:
		idle = 0.0
		if hud.autopilot:
			hud.set_autopilot(false)
			hud.hint(tr("You have the controls."))
	else:
		idle += delta
	var computer: bool = hud.autopilot or idle > HANDS_OFF
	if computer and not helped and not hud.autopilot and not told.has("help"):
		told["help"] = true
		hud.hint(tr("Hands off: the flight computer is holding the descent. Touch any control to fly it again."))
	helped = computer
	if computer:
		var b: Array = model.bot()
		throttle = b[0]
		steer = b[1]
		hud.lever.value = throttle
	model.step(delta, throttle, steer)
	_telemetry()
	_hints()
	if not alarm_rung and model.altitude() < float(land.get("alarm", {}).get("at_height_m", -1.0)):
		_alarm()
	if model.done:
		_touchdown()


func _on_lever(v: float) -> void:
	throttle = v
	idle = 0.0


func _hover() -> void:
	if phase != "descent":
		return
	idle = 0.0
	throttle = model.hover_throttle()
	hud.lever.value = throttle
	hud.message(tr("HOVER"), tr("Engine set to hold you still in the air."), Kit.C_ACCENT, 1.4)


func _telemetry() -> void:
	var alt: float = maxf(model.altitude(), 0.0)
	var vs: float = -model.vel.y
	hud.clock.text = "%d m" % roundi(alt)
	hud.value("alt", "%d m" % roundi(alt))
	var vs_col := Kit.C_OK if vs <= float(land.get("good_mps", 3.0)) else (Kit.C_WARN if vs <= float(land.get("hard_mps", 6.0)) else Kit.C_BAD)
	hud.value("vs", "%.1f m/s" % vs, vs_col if alt < 60.0 else Color.WHITE)
	hud.value("hs", "%.1f m/s" % model.hspeed(), Kit.C_WARN if model.hspeed() > float(land.get("tip_hspeed", 2.5)) and alt < 30.0 else Color.WHITE)
	hud.value("target", "%d m" % roundi(model.target_distance()))
	hud.gauge("fuel", model.fuel, "%d %%" % roundi(model.fuel * 100.0))


func _hints() -> void:
	var alt: float = model.altitude()
	if model.fuel <= 0.0 and not told.has("dry"):
		told["dry"] = true
		hud.message(tr("NO FUEL"), tr("The engine is dry. Brace for touchdown."), Kit.C_BAD, 2.5)
	elif model.fuel < 0.15 and not told.has("fuel"):
		told["fuel"] = true
		hud.hint(tr("Fuel is low. Set down soon: anywhere flat will do."))
	if alt < 80.0 and -model.vel.y > 8.0 and not told.has("fast"):
		told["fast"] = true
		hud.message(tr("TOO FAST"), tr("More throttle, now!"), Kit.C_BAD, 1.6)
		sfx.beep.play()


## The 1202, as on Apollo 11: the computer is overloaded but keeps flying; ground control decides whether to go on.
func _alarm() -> void:
	alarm_rung = true
	var a: Dictionary = land.alarm.duplicate()
	a["phase"] = "landing"
	a["title"] = tr(str(a.get("title", "")))
	a["desc"] = tr(str(a.get("desc", "")))
	sfx.alarm.play()
	hud.message(tr("ALARM %s") % a.get("code", ""), a.title, Kit.C_WARN, 3.0)
	hud.hint(a.desc)
	Ground.ask(self, a, func(answer: Dictionary):
		if phase != "descent":
			return
		GameState.flight["landing_alarm"] = answer
		hud.message(tr("GO!"), str(answer.get("words", "")), Kit.C_OK, 2.5))


func _touchdown() -> void:
	var r: Dictionary = model.result
	phase = "lost" if r.grade == "crater" else "down"
	phase_t = 0.0
	throttle = 0.0
	hud.lever.value = 0.0
	hud.action.lit = false
	hud.hint("")
	r["by_computer"] = helped
	GameState.flight["landing"] = r
	GameState.flight_moment("touchdown", r)
	if r.grade == "crater":
		_crater()
		return
	var words := {
		"soft": [tr("TOUCHDOWN!"), tr("Touchdown at %.1f m/s, as soft as a feather.")],
		"good": [tr("LANDED!"), tr("Touchdown at %.1f m/s. A clean landing.")],
		"firm": [tr("LANDED, FIRMLY"), tr("Touchdown at %.1f m/s. The legs took it.")],
		"rough": [tr("DOWN, A LITTLE BENT"), tr("Touchdown at %.1f m/s. It leans, but it works.")],
	}
	var w: Array = words.get(r.grade, words.good)
	hud.message(w[0], w[1] % r.touchdown_mps + "  " + tr("%d m from the target.") % roundi(r.target_m), Kit.C_OK, 0.0)
	dust.global_position = lander.global_position - Vector3(0, Descent.LEG, 0)
	dust.emitting = true
	sfx.clunk.play()
	sfx.chime.play()
	shake = 0.6
	if r.grade == "rough":
		lander.rotate_object_local(Vector3(1, 0, 0.4).normalized(), deg_to_rad(9.0))
	preload("res://scripts/flight/surface.gd").note_landing(mission, r)
	GameState.settle_extras()
	var met := 0
	for id in GameState.flight.get("extras", {}):
		if GameState.flight.extras[id]:
			met += 1
	if met > 0:
		hud.hint(tr("Extra objectives met: %d. Their photos will come home with the report.") % met)


func _crater() -> void:
	hud.message(tr("NEW CRATER"), tr("Touchdown at %d m/s. Shackleton has one more crater, and it is yours.") % roundi(model.result.touchdown_mps), Kit.C_BAD, 0.0)
	lander.visible = false
	var boom := Space.make_explosion()
	boom.position = lander.position
	boom.scale = Vector3.ONE * 0.8
	world.stage.add_child(boom)
	for e in boom.get_children():
		(e as CPUParticles3D).emitting = true
	world.stage.add_child(Scene3D.debris(lander.position, 0.5))
	sfx.boom.play()
	shake = 2.0
	GameState.end_flight_early(tr("Lost at touchdown"), tr("The lander reached the ground too fast and broke. Next time: more throttle as the ground comes up."), 0.0)


## Skip: the flight computer flies the rest of the descent at once.
func _skip() -> void:
	if phase != "descent":
		return
	for _i in 30 * 400:
		if model.done:
			break
		var b: Array = model.bot()
		model.step(1.0 / 30.0, b[0], b[1])
	helped = true
	_telemetry()
	_touchdown()


func _place() -> void:
	lander.position = model.pos
	if phase == "descent":
		# the lander leans into its side push, as a real one tilts to move across
		var tilt := Vector3(model.vel.z * 0.012, 0, -model.vel.x * 0.012)
		lander.rotation = lander.rotation.lerp(tilt, 0.1)


func _camera(delta: float) -> void:
	var cam: Camera3D = world.cam
	var alt: float = clampf(model.altitude(), 0.0, 400.0)
	var k := clampf(alt / 300.0, 0.0, 1.0)
	var want: Vector3 = model.pos + Vector3(lerpf(7.0, 14.0, k), lerpf(3.0, 10.0, k), lerpf(13.0, 34.0, k))
	var ground_y: float = terrain.height(want.x, want.z) + 2.0
	want.y = maxf(want.y, ground_y)
	cam.position = cam.position.lerp(want, clampf(delta * 2.0, 0.0, 1.0))
	shake = maxf(0.0, shake - delta)
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.15
	cam.look_at(model.pos + Vector3(0, -2.0, 0) + jitter, Vector3.UP)


func _effects(delta: float) -> void:
	var on: bool = phase == "descent" and throttle > 0.02 and model.fuel > 0.0
	flame.emitting = on
	flame.scale = Vector3.ONE * lerpf(0.5, 1.2, throttle)
	var alt: float = model.altitude()
	if phase == "down":
		dust.emitting = phase_t < 1.0
	if phase == "descent":
		dust.global_position = Vector3(model.pos.x, terrain.height(model.pos.x, model.pos.z) + 0.3, model.pos.z)
		dust.emitting = on and alt < 25.0
	if on and not rumble.playing:
		rumble.play()
	var target: float = lerpf(-36.0, -14.0, throttle) if on else -60.0
	rumble.volume_db = lerpf(rumble.volume_db, target, clampf(delta * 5.0, 0.0, 1.0))
	if rumble.volume_db < -55.0 and rumble.playing:
		rumble.stop()
