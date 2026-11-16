extends "res://scripts/screens/screen.gd"
## Mission 6, Artemis I (November 16 to December 11, 2022): "Everything we learned" (issue #50). The crew ride hidden in
## Commander Moonikin Campos's seat. Three stages, each part of the result, and the far point between them:
## (1) Launch from Pad 39B: SPACE on the zero; through Max Q hold the throttle in the band (W/S); B when the boosters
## burn out (2 min 12 s), C when the core stage is empty (8 min 03 s). Mission time shown faster, said on screen.
## (2) The outbound powered flyby, about 81 miles above the Moon: hold SPACE to burn from 2,128 mph, let go near
## 5,102; then catch the Earth in the camera frame as it comes out beside the Moon. NASA's own picture of the far
## point, 268,563 miles from Earth, follows. (3) Re-entry at Mach 32: keep the angle in the corridor (W/S) through the
## plasma, then the drogues (1) and the mains (2) on their calls, and splashdown off San Diego.
## Out of the corridor: lose screen. Rules: scripts/missions/artemis1/flight.gd; data: data/missions/artemis1.json.

const TouchKeys := preload("res://scripts/ui/touch_keys.gd")
const Progress := preload("res://scripts/story/campaign_progress.gd")
const Flight := preload("res://scripts/missions/artemis1/flight.gd")
const Sets := preload("res://scripts/story/sets.gd")
const Space := preload("res://scripts/world/space_builder.gd")
const Sound := preload("res://scripts/flight/sound.gd")
const CuyActor := preload("res://scripts/story/cuy_actor.gd")
## The same flight as the game's own launches (Missions): the climb's physics and the pilot's panel.
const Ascent := preload("res://scripts/flight/ascent.gd")
const FlightHud := preload("res://scripts/flight/flight_hud.gd")
const Scene3D := preload("res://scripts/flight/flight_scene.gd")
const VIS := 0.92              ## Scene units per metre near the pad (the SLS drawn here is about 98 m tall).
const HORIZON_R := 6000.0
const ORION_KG := 26520.0      ## Orion at launch, as the payload for the climb (ours: about 26.5 t).

var Fl: Flight
var T: Dictionary
var campaign := false
var then_scenes: Array = []
var back := "menu"
var saved := {}
var phase := "brief"           ## brief, count, ascent, flyby, earth, far, entry, chutes, splash, done, lost
var phase_t := 0.0
var _t := 0.0
var shake := 0.0
var result_shown := false
var thump: AudioStreamPlayer
var roar: AudioStreamPlayer
# launch
var met := 0.0                 ## Mission elapsed time (s).
var ignite_q := -1.0
var throttle := 1.0
var maxq_sum := 0.0
var maxq_n := 0
var model                        ## The climb (scripts/flight/ascent.gd), as in the game's own launches.
var hud                          ## The pilot's panel (scripts/flight/flight_hud.gd).
var horizon: Node3D
var stage_wait := 0.0
var shown_pitch := 0.0
var in_space := false
var stages_dropped := 0
var pilot_warp := false        ## The pilot picked how fast time runs: the screen stops choosing for them.
var stars: Node3D              ## The stars over the night pad (they follow the camera).
var clouds: Node3D
var pad_smoke: CPUParticles3D
var pflames: Array = []        ## The particle fire: [core, booster left, booster right, upper stage].
var fire_light: OmniLight3D
var cam_focus := 45.0
var cam_off := Vector3.INF          ## Where along the stack the camera looks (units up from its base).
var alarm: AudioStreamPlayer
var beep: AudioStreamPlayer
var alarm_t := 0.0
var red: ColorRect
var said_count := {}
var KSC := Vector2(28.61, -80.6)   ## Launch Pad 39B, Kennedy Space Center (latitude, longitude; degrees).
var rocket: Node3D
var boosters: Array = []
var core: Node3D
var flames: Array = []
var ground: Node3D
# flyby
var speed := 0.0
var burning := false
var burn_q := -1.0
var earth_q := -1.0
var moon: MeshInstance3D
var earth: Node3D
var orion: Node3D
var earth_a := 0.0
# re-entry
var angle := -6.0
var drift := 0.0
var corr_sum := 0.0
var corr_n := 0
var out_t := 0.0
var alt_km := 0.0
var mach := 32.0
var drogue_q := -1.0
var main_q := -1.0
var capsule: Node3D
var plasma: MeshInstance3D
var chutes: Array = []
# interface
var head_title: Label
var clock_lbl: Label
var clock_sub: Label
var speed_lbl: Label
var who_chip: PanelContainer
var radio: Label
var hint: Label
var hint_panel: PanelContainer
var big: Label
var big_sub: Label
var shout_panel: PanelContainer
var now_lbl: Label
var now_panel: PanelContainer
var bubble: Label
var flash: ColorRect
var gauge: Control
var gauge_panel: PanelContainer
var gauge_cap: Label
var frame_box: Control
var stage_rows: Array = []
var stage_names: Array = []
var photo_layer: Control
var brief: Control
var lose_layer: Control


func enter(args: Dictionary) -> void:
	campaign = args.get("campaign", false)
	then_scenes = args.get("then", [])
	back = args.get("back", "menu")
	Fl = Flight.new()
	T = Fl.D.texts
	saved = Sets.save_world(world)
	world.cam_free = false
	thump = Sound.player(self, "thud", -2.0)
	alarm = Sound.player(self, "alarm")
	beep = Sound.player(self, "beep")
	roar = Sound.player(self, "rumble", -4.0)
	_build_ui()
	_build_launch()
	_say("Wayra", tr("Pad 39B. Everyone in the seat? Campos does not mind the company."))
	_show_brief()
	_phone_layout()
	TouchKeys.attach(self)


func exit() -> void:
	if beat_dialogue and is_instance_valid(beat_dialogue):
		beat_dialogue.queue_free()
	Engine.time_scale = 1.0
	Sets.restore_world(world, saved)


# ===================================================================================== THE WORLDS
func _soft_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = Sets.soft_glow()
	m.albedo_color = c
	return m


func _glow(parent: Node3D, size: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var g := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	g.mesh = q
	g.material_override = _soft_mat(c)
	g.position = pos
	parent.add_child(g)
	return g


## Orion: the crew module (a cone), its service module and four solar wings. Shapes only, no markings.
func _orion(parent: Node3D) -> Node3D:
	var o := Node3D.new()
	parent.add_child(o)
	Sets.cyl(o, 0.55, 1.6, 1.1, Vector3(0, 0.55, 0), Sets.mat(Color(0.85, 0.86, 0.88), 0.45, 0.2), 32)
	Sets.cyl(o, 1.6, 1.6, 0.12, Vector3(0, -0.06, 0), Sets.mat(Color(0.35, 0.25, 0.18), 0.9), 32)
	Sets.cyl(o, 1.5, 1.5, 1.9, Vector3(0, -1.1, 0), Sets.mat(Color(0.82, 0.82, 0.84), 0.4, 0.5), 32)
	Sets.cyl(o, 0.35, 0.7, 0.8, Vector3(0, -2.4, 0), Sets.mat(Color(0.3, 0.3, 0.32), 0.4, 0.7), 16)
	var cell := Sets.mat(Color(0.1, 0.12, 0.25), 0.25, 0.6)
	for i in 4:
		var a := i * TAU / 4.0 + PI / 4.0
		var w := Sets.box(o, Vector3(0.9, 0.06, 6.5), Vector3(sin(a) * 4.8, -1.4, cos(a) * 4.8), cell)
		w.rotation.y = a
	return o


func _clear() -> void:
	world.clear_stage()
	boosters.clear()
	flames.clear()
	chutes.clear()


func _build_launch() -> void:
	_clear()
	var env: Environment = world.world_env.environment
	# 1:47 a.m. in Florida: a starry night sky from the first second, the pad lit by its floodlights
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var ps := ProceduralSkyMaterial.new()
	ps.sky_top_color = Color(0.03, 0.05, 0.14)
	ps.sky_horizon_color = Color(0.16, 0.2, 0.36)
	ps.sky_curve = 0.12
	ps.ground_horizon_color = Color(0.16, 0.2, 0.36)
	ps.ground_bottom_color = Color(0.02, 0.03, 0.06)
	ps.sun_angle_max = 1.0
	sky.sky_material = ps
	env.sky = sky
	env.background_energy_multiplier = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.14, 0.18, 0.3)
	env.fog_density = 0.00025
	env.fog_sky_affect = 0.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.65)
	env.ambient_light_energy = 0.6
	env.glow_enabled = true
	world.sun.light_energy = 0.4
	world.sun.light_color = Color(0.8, 0.85, 1.0)
	world.sun.rotation_degrees = Vector3(-35, 40, 0)
	world.cam.fov = 50.0
	world.cam.near = 0.1
	world.cam.far = 20000.0
	var st: Node3D = world.stage
	ground = Node3D.new()
	st.add_child(ground)
	# the Florida coast: scrubland around the pad, the Atlantic to the east (+x), the pad's concrete and flame trench
	Sets.box(ground, Vector3(1600, 0.2, 4000), Vector3(-500, -0.1, 0), Sets.mat(Color(0.12, 0.15, 0.11), 1.0))
	Sets.box(ground, Vector3(2600, 0.2, 4000), Vector3(1600, -0.3, 0), Sets.mat(Color(0.03, 0.07, 0.13), 0.15, 0.3))
	Sets.box(ground, Vector3(60, 0.2, 60), Vector3(0, 0.0, 0), Sets.mat(Color(0.42, 0.42, 0.43), 0.9))
	Sets.box(ground, Vector3(30, 1.0, 30), Vector3(0, 0.5, 0), Sets.mat(Color(0.5, 0.5, 0.51), 0.9))
	Sets.box(ground, Vector3(10, 1.2, 40), Vector3(0, 0.3, 0), Sets.mat(Color(0.15, 0.15, 0.16), 0.9))
	# lightning masts and a water tower around the pad, as at a real pad (shapes only)
	for q in [Vector3(-40, 0, -35), Vector3(40, 0, -35), Vector3(0, 0, 45)]:
		Sets.cyl(ground, 0.5, 0.9, 90, q + Vector3(0, 45, 0), Sets.mat(Color(0.7, 0.7, 0.72), 0.6, 0.4), 8)
		_glow(ground, 3.0, q + Vector3(0, 91, 0), Color(1, 0.2, 0.15, 0.9))
	Sets.cyl(ground, 6, 6, 8, Vector3(-60, 26, 30), Sets.mat(Color(0.85, 0.85, 0.85), 0.6), 24)
	Sets.cyl(ground, 0.8, 0.8, 22, Vector3(-60, 11, 30), Sets.mat(Color(0.6, 0.6, 0.62), 0.6, 0.4), 8)
	# the tower and the lights of the pad at night (1:47 a.m.)
	var steel := Sets.mat(Color(0.55, 0.3, 0.2), 0.6, 0.5)
	Sets.box(ground, Vector3(3, 70, 3), Vector3(-8, 36, 0), steel)
	for h in [20.0, 40.0, 58.0]:
		Sets.box(ground, Vector3(6, 0.6, 1.2), Vector3(-5.5, h, 0), steel)
	for p in [Vector3(25, 2, 25), Vector3(-25, 2, 25), Vector3(25, 2, -25), Vector3(-25, 2, -25)]:
		Sets.omni(ground, p + Vector3(0, 20, 0), Color(1.0, 0.88, 0.7), 9.0, 140.0)
		_glow(ground, 8.0, p + Vector3(0, 20, 0), Color(1, 0.9, 0.7, 0.9))
	# floodlights pointed at the rocket, as at a real night launch
	for a in [0.6, 2.4, 4.2]:
		var sp := SpotLight3D.new()
		sp.position = Vector3(cos(a) * 70.0, 6.0, sin(a) * 70.0)
		sp.light_color = Color(0.95, 0.95, 1.0)
		sp.light_energy = 14.0
		sp.spot_range = 220.0
		sp.spot_angle = 18.0
		ground.add_child(sp)
		sp.look_at_from_position(sp.position, Vector3(0, 45, 0), Vector3.UP)
	# SLS: the orange core stage, two white boosters, Orion and its launch abort tower on top
	rocket = Node3D.new()
	rocket.position = Vector3(0, 1.0, 0)
	st.add_child(rocket)
	core = Node3D.new()
	rocket.add_child(core)
	Sets.cyl(core, 2.8, 2.8, 64, Vector3(0, 32, 0), Sets.mat(Color(0.85, 0.45, 0.15), 0.8), 32)
	for i in 4:
		var a := i * TAU / 4.0
		Sets.cyl(core, 0.4, 0.8, 2.2, Vector3(sin(a) * 1.4, -0.8, cos(a) * 1.4), Sets.mat(Color(0.25, 0.25, 0.27), 0.4, 0.7), 12)
	var upper := Node3D.new()
	upper.name = "Upper"
	rocket.add_child(upper)
	Sets.cyl(upper, 1.7, 2.8, 4, Vector3(0, 66, 0), Sets.mat(Color(0.9, 0.9, 0.9), 0.5), 32)
	Sets.cyl(upper, 1.7, 1.7, 8, Vector3(0, 72, 0), Sets.mat(Color(0.88, 0.88, 0.9), 0.5), 32)
	Sets.cyl(upper, 0.1, 1.7, 5, Vector3(0, 78.5, 0), Sets.mat(Color(0.92, 0.92, 0.93), 0.5), 32)
	Sets.cyl(upper, 0.12, 0.12, 6, Vector3(0, 84, 0), Sets.mat(Color(0.9, 0.9, 0.9), 0.5), 8)
	for sx in [-1.0, 1.0]:
		var b := Node3D.new()
		b.position = Vector3(sx * 4.3, 0, 0)
		rocket.add_child(b)
		Sets.cyl(b, 1.85, 1.85, 54, Vector3(0, 28, 0), Sets.mat(Color(0.95, 0.95, 0.95), 0.6), 24)
		Sets.cyl(b, 0.1, 1.85, 5, Vector3(0, 57.5, 0), Sets.mat(Color(0.95, 0.95, 0.95), 0.6), 24)
		Sets.cyl(b, 1.2, 1.9, 3, Vector3(0, -0.5, 0), Sets.mat(Color(0.3, 0.3, 0.32), 0.5, 0.6), 16)
		boosters.append(b)
	# the fire: a glow under each engine and booster, and a long plume
	for x in [-4.3, 0.0, 4.3]:
		var f := _glow(rocket, 14.0 if x != 0.0 else 9.0, Vector3(x, -4, 0), Color(1.0, 0.7, 0.3, 0.0))
		flames.append(f)
		var pl := _glow(rocket, 26.0, Vector3(x, -16, 0), Color(1.0, 0.55, 0.2, 0.0))
		pl.scale = Vector3(0.6, 1.8, 1)
		flames.append(pl)
	var fl := Sets.omni(rocket, Vector3(0, -6, 0), Color(1.0, 0.7, 0.4), 0.0, 260.0)
	fl.name = "FireLight"
	fire_light = fl
	# the real fire: particles under the core's four engines and each booster (the game's own flames), and the upper
	# stage's engine for later
	pflames.clear()
	for x in [0.0, -4.3, 4.3]:
		var pf := Space.make_flame(5.5 if x == 0.0 else 4.5)
		pf.position = Vector3(x, -2.0, 0)
		pf.amount = 120
		if x == 0.0:
			core.add_child(pf)
		else:
			(boosters[0] if x < 0.0 else boosters[1]).add_child(pf)
			pf.position = Vector3(0, -2.0, 0)
		pflames.append(pf)
	var uf := Space.make_vacuum_flame(2.5)
	uf.position = Vector3(0, 61.0, 0)
	rocket.get_node("Upper").add_child(uf)
	pflames.append(uf)
	# steam and smoke from the deluge water, thrown sideways across the pad at ignition
	pad_smoke = _smoke()
	pad_smoke.position = Vector3(0, 3, 0)
	ground.add_child(pad_smoke)
	_night_dressing()


## A grey cloud of steam and smoke that rolls out across the pad.
func _smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 70
	p.lifetime = 6.0
	p.emitting = false
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(26, 26)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Sets.soft_glow()
	q.material = m
	p.mesh = q
	p.direction = Vector3(1, 0.15, 0)
	p.spread = 180.0
	p.flatness = 0.85
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 60.0
	p.damping_min = 6.0
	p.damping_max = 10.0
	p.gravity = Vector3(0, 2.0, 0)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 3.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 2.2))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.75, 0.45, 0.7))
	g.set_color(1, Color(0.3, 0.32, 0.38, 0.0))
	g.add_point(0.2, Color(0.75, 0.72, 0.7, 0.55))
	p.color_ramp = g
	return p


## The night around the pad: stars, low clouds, the lights of the Space Coast, so it is a place and not a void.
func _night_dressing() -> void:
	var st: Node3D = world.stage
	var rng := RandomNumberGenerator.new()
	rng.seed = 1116
	# the stars, on a dome that travels with the camera
	stars = Node3D.new()
	st.add_child(stars)
	var smm := MultiMesh.new()
	smm.transform_format = MultiMesh.TRANSFORM_3D
	smm.use_colors = true
	var sq := QuadMesh.new()
	sq.size = Vector2(14, 14)
	smm.mesh = sq
	smm.instance_count = 900
	for i in 900:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.05, 1.0), rng.randf_range(-1, 1)).normalized()
		smm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * rng.randf_range(0.4, 1.4)), d * 15000.0))
		var b := rng.randf_range(0.4, 1.0)
		smm.set_instance_color(i, Color(b, b, b * rng.randf_range(0.9, 1.1), 1.0))
	var sm := MultiMeshInstance3D.new()
	sm.multimesh = smm
	var mat := _soft_mat(Color(1, 1, 1, 1))
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = false
	sm.material_override = mat
	stars.add_child(sm)
	# low clouds, a few hundred metres to three kilometres up, that the rocket climbs through
	clouds = Node3D.new()
	st.add_child(clouds)
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	cm.albedo_texture = Sets.soft_glow()
	cm.albedo_color = Color(0.32, 0.36, 0.5, 0.55)
	for i in 34:
		var c := MeshInstance3D.new()
		var q := QuadMesh.new()
		var w := rng.randf_range(250, 700)
		q.size = Vector2(w, w * 0.45)
		c.mesh = q
		c.material_override = cm
		var x := rng.randf_range(-3000, 3000)
		var z := rng.randf_range(-3000, 1800)
		if absf(x) < 200 and absf(z) < 200:
			x += 400
		c.position = Vector3(x, rng.randf_range(700, 1600), z)
		clouds.add_child(c)
	# the Space Coast's lights to the west, the Atlantic dark to the east
	var lmm := MultiMesh.new()
	lmm.transform_format = MultiMesh.TRANSFORM_3D
	lmm.use_colors = true
	var lq := QuadMesh.new()
	lq.size = Vector2(9, 9)
	lmm.mesh = lq
	lmm.instance_count = 700
	for i in 700:
		var pos := Vector3(rng.randf_range(-2400, -150), 1.0, rng.randf_range(-2600, 2600))
		lmm.set_instance_transform(i, Transform3D(Basis(), pos))
		lmm.set_instance_color(i, Color(1.0, rng.randf_range(0.55, 0.8), 0.35, rng.randf_range(0.4, 1.0)))
	var lm := MultiMeshInstance3D.new()
	lm.multimesh = lmm
	var lmat := _soft_mat(Color(1, 1, 1, 1))
	lmat.vertex_color_use_as_albedo = true
	lm.material_override = lmat
	ground.add_child(lm)


func _build_flyby() -> void:
	_clear()
	var env: Environment = world.world_env.environment
	env.background_mode = Environment.BG_SKY
	env.sky = Space.make_space_sky()
	env.background_energy_multiplier = 1.0
	env.ambient_light_energy = 0.15
	world.sun.light_energy = 2.0
	world.sun.light_color = Color(1, 0.98, 0.95)
	world.sun.rotation_degrees = Vector3(-15, -60, 0)
	world.cam.fov = 55.0
	world.cam.far = 50000.0
	var st: Node3D = world.stage
	# the Moon below: 1,737 km of radius, Orion 81 miles (130 km) up; units of 1 km
	moon = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1737.0
	sm.height = 3474.0
	sm.radial_segments = 192
	sm.rings = 96
	moon.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.albedo_texture = Space.MOON_COLOR
	mm.albedo_color = Color(0.85, 0.85, 0.85)
	mm.roughness = 1.0
	moon.material_override = mm
	moon.position = Vector3(0, -1737.0 - 130.0, 0)
	st.add_child(moon)
	# the Earth, far away (scaled with its distance for the view: true angular size, about 2 degrees)
	earth = Node3D.new()
	st.add_child(earth)
	var e := MeshInstance3D.new()
	var es := SphereMesh.new()
	es.radius = 1.0
	es.height = 2.0
	es.radial_segments = 64
	es.rings = 32
	e.mesh = es
	var em := StandardMaterial3D.new()
	em.albedo_texture = Space.EARTH_DAY
	em.roughness = 0.8
	e.material_override = em
	earth.add_child(e)
	earth.scale = Vector3.ONE * 380.0
	earth.visible = false
	orion = _orion(st)
	orion.scale = Vector3.ONE * 0.6
	orion.rotation = Vector3(0, 0, -PI / 2)
	var burn := _glow(orion, 9.0, Vector3(0, -4.5, 0), Color(0.6, 0.8, 1.0, 0.0))
	burn.name = "Burn"


func _build_entry() -> void:
	_clear()
	var env: Environment = world.world_env.environment
	env.background_mode = Environment.BG_SKY
	env.sky = Space.make_space_sky()
	env.ambient_light_energy = 0.25
	world.sun.light_energy = 1.8
	world.sun.rotation_degrees = Vector3(-30, 20, 0)
	world.cam.fov = 50.0
	world.cam.near = 0.05
	world.cam.far = 50000.0
	var st: Node3D = world.stage
	var e := MeshInstance3D.new()
	var es := SphereMesh.new()
	es.radius = 6371.0
	es.height = 12742.0
	es.radial_segments = 192
	es.rings = 96
	e.mesh = es
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.albedo_texture = Space.EARTH_DAY
	em.albedo_color = Color(1.5, 1.55, 1.65)
	e.material_override = em
	e.position = Vector3(0, -6371.0 - 120.0, 0)
	e.rotation = Vector3(0.25, -1.9, 0.0)
	e.name = "Earth"
	st.add_child(e)
	capsule = Node3D.new()
	st.add_child(capsule)
	var cm := Node3D.new()
	capsule.add_child(cm)
	Sets.cyl(cm, 0.55, 1.6, 1.1, Vector3(0, 0.55, 0), Sets.mat(Color(0.8, 0.8, 0.82), 0.45, 0.2), 32)
	Sets.cyl(cm, 1.6, 1.6, 0.14, Vector3(0, -0.07, 0), Sets.mat(Color(0.3, 0.2, 0.15), 0.9), 32)
	cm.rotation.x = PI * 0.55
	plasma = _glow(capsule, 7.0, Vector3(0, -0.6, -1.4), Color(1.0, 0.5, 0.2, 0.0))
	for i in 3:
		var c := Node3D.new()
		c.position = Vector3((i - 1) * 2.4, 9.0, 0)
		c.visible = false
		capsule.add_child(c)
		var dome := Sets.ball(c, 2.2, Vector3.ZERO, Sets.mat(Color(0.95, 0.5, 0.2) if i != 1 else Color(0.95, 0.95, 0.95), 0.8), Vector3(1, 0.45, 1))
		dome.name = "Dome"
		for k in 6:
			var a := k * TAU / 6.0
			Sets.rope(c, Vector3(sin(a) * 2.0, -0.5, cos(a) * 2.0), Vector3(-(i - 1) * 2.4, -8.6, 0), 0.03, Sets.mat(Color(0.9, 0.9, 0.9), 0.6))
		chutes.append(c)


# ===================================================================================== THE INTERFACE
func _card() -> PanelContainer:
	var p := Kit.panel_box(12)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _build_ui() -> void:
	frame_box = PhotoFrame.new()
	frame_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_box.visible = false
	add_child(frame_box)
	var head := Kit.vbox(2)
	Kit.place(head, 0, 0, 0, 0, Kit.MARGIN, Kit.MARGIN, 600, 100)
	add_child(head)
	var over := Kit.caps(tr("Mission 6 · Artemis I · November 16, 2022"))
	over.add_theme_color_override("font_color", Color(Kit.C_ON_DARK, 0.8))
	head.add_child(over)
	head_title = Kit.lbl(tr("Everything we learned"), Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T)
	head.add_child(head_title)
	var stp := _card()
	Kit.place(stp, 0, 0, 0, 0, Kit.MARGIN, 120, Kit.MARGIN + 10, 130)
	add_child(stp)
	var stv := Kit.vbox(4)
	stp.add_child(stv)
	stv.add_child(Kit.caps(tr("The mission")))
	for nm in [tr("Launch"), tr("Around the Moon"), tr("Home at Mach 32")]:
		stage_names.append(nm)
		var l := Kit.lbl(nm, Kit.T_BODY, Kit.C_DIM, Kit.FONT_B)
		stv.add_child(l)
		stage_rows.append(l)
	var cp := Kit.panel_box(Kit.PAD)
	Kit.place(cp, 0.5, 0, 0.5, 0, -200, Kit.MARGIN, 200, Kit.MARGIN + 130)
	add_child(cp)
	var cv := Kit.vbox(0)
	cp.add_child(cv)
	var cap_l := Kit.caps(tr("Mission time"))
	cap_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(cap_l)
	clock_lbl = Kit.lbl("T- 00:00:05", Kit.T_CLOCK + 6, Kit.C_GOLD, Kit.font_num())
	clock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(clock_lbl)
	clock_sub = Kit.lbl("", Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B)
	clock_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(clock_sub)
	speed_lbl = Kit.lbl(tr("Real time"), Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R)
	speed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(speed_lbl)
	var hp := Kit.panel_box(Kit.PAD)
	Kit.place(hp, 1, 0, 1, 0, -Kit.MARGIN - 430, Kit.MARGIN, -Kit.MARGIN, Kit.MARGIN + 60)
	add_child(hp)
	var hv := Kit.vbox(Kit.GAP)
	hp.add_child(hv)
	var hh := Kit.hbox(Kit.GAP)
	hv.add_child(hh)
	who_chip = Kit.chip("Wayra", Kit.C_ACCENT)
	hh.add_child(who_chip)
	hh.add_child(Kit.lbl(tr("In Campos's seat"), Kit.T_SMALL, Kit.C_DIM))
	radio = Kit.lbl("", Kit.T_ACTION - 2, Kit.C_TEXT, Kit.FONT_B, true)
	radio.custom_minimum_size.x = 380
	hv.add_child(radio)
	# the gauge on the right: Max Q, the burn's speed, the corridor, the height
	gauge_panel = _card()
	Kit.place(gauge_panel, 1, 1, 1, 1, -Kit.MARGIN - 300, -Kit.MARGIN - 430, -Kit.MARGIN, -Kit.MARGIN)
	add_child(gauge_panel)
	var gv := Kit.vbox(6)
	gauge_panel.add_child(gv)
	gauge_cap = Kit.caps("")
	gv.add_child(gauge_cap)
	gauge = Gauge.new()
	gauge.custom_minimum_size = Vector2(276, 360)
	gv.add_child(gauge)
	gauge_panel.visible = false
	hint = Kit.lbl("", Kit.T_ACTION, Kit.C_ON_DARK, Kit.FONT_B, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_panel = _card()
	Kit.place(hint_panel, 0, 1, 0, 1, Kit.MARGIN, -130, Kit.MARGIN + 700, -Kit.MARGIN)
	hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_panel.add_child(hint)
	add_child(hint_panel)
	shout_panel = _card()
	Kit.place(shout_panel, 0.5, 0, 0.5, 0, -10, Kit.MARGIN + 176, 10, Kit.MARGIN + 186)
	shout_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(shout_panel)
	var sb := Kit.vbox(2)
	shout_panel.add_child(sb)
	big = Kit.lbl("", Kit.T_SHOUT, Kit.C_GOLD, Kit.FONT_T)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sb.add_child(big)
	big_sub = Kit.lbl("", Kit.T_ACTION, Kit.C_TEXT, Kit.FONT_B)
	big_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sb.add_child(big_sub)
	now_panel = _card()
	Kit.place(now_panel, 0.5, 1, 0.5, 1, -10, -300, 10, -290)
	now_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(now_panel)
	now_lbl = Kit.lbl("", Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T)
	now_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	now_panel.add_child(now_lbl)
	bubble = Kit.lbl("", Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T)
	Kit.place(bubble, 0.5, 0.5, 0.5, 0.5, 110, -40, 700, 20)
	bubble.add_theme_constant_override("outline_size", 8)
	bubble.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	add_child(bubble)
	red = ColorRect.new()
	red.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	red.color = Color(0.9, 0.05, 0.02, 0.0)
	add_child(red)
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 1, 1, 0)
	add_child(flash)


func _say(who: String, text: String) -> void:
	radio.text = text
	var l := who_chip.get_child(0) as Label
	if l:
		l.text = who


func _shout(a: String, b := "", col := Kit.C_GOLD) -> void:
	big.text = a
	big_sub.text = b
	big.add_theme_color_override("font_color", col)
	big_t = 0.0


var big_t := 0.0


func _pop(text: String, col: Color) -> void:
	bubble.text = text
	bubble.add_theme_color_override("font_color", col)
	bubble.pivot_offset = Vector2(0, 30)
	bubble.scale = Vector2(1.5, 1.5)
	bubble.modulate.a = 1.0
	var tw := bubble.create_tween()
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.8)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.4)


func _grade(q: float) -> void:
	if q > 0.85:
		_pop(tr("PERFECT!"), Kit.C_GOLD)
		Kit.UiSound.play("success")
	elif q > 0.45:
		_pop(tr("Good!"), Kit.C_GOLD)
		Kit.UiSound.play("snap")
	else:
		_pop(tr("Late!") if q > 0.0 else tr("Missed!"), Kit.C_BAD)
		Kit.UiSound.play("error")


func _show_brief() -> void:
	brief = Control.new()
	brief.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(brief)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brief.add_child(shade)
	var p := Kit.panel_box(Kit.PAD)
	Kit.place(p, 0.5, 0.5, 0.5, 0.5, -440, -260, 440, 260)
	brief.add_child(p)
	var v := Kit.vbox(Kit.GAP)
	p.add_child(v)
	v.add_child(Kit.caps(tr("How to play")))
	v.add_child(Kit.lbl(tr("Everything we learned"), Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T))
	for row in [["1", tr("Launch"), tr("SPACE on the zero. Then fly it as in Missions: lean with ← → onto the green marker, W/S throttle, SPACE drops the boosters and the core stage.")],
			["2", tr("Around the Moon"), tr("Hold SPACE to burn, let go in the gold band. Then SPACE when the Earth is in the frame.")],
			["3", tr("Home at Mach 32"), tr("Keep the angle in the corridor (W/S). Then 1 for the drogues and 2 for the mains.")]]:
		var h := Kit.hbox(Kit.PAD)
		v.add_child(h)
		h.add_child(Kit.lbl(row[0], Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T))
		var tv := Kit.vbox(0)
		h.add_child(tv)
		tv.add_child(Kit.lbl(row[1], Kit.T_ACTION - 2, Kit.C_TEXT, Kit.FONT_B))
		var d := Kit.lbl(row[2], Kit.T_BODY, Kit.C_DIM, Kit.FONT_R, true)
		d.custom_minimum_size.x = 640
		tv.add_child(d)
	var go_btn := Kit.btn(tr("Start  ·  Enter"), _start, Kit.T_BODY)
	Kit.accent_btn(go_btn, Kit.C_GOLD)
	v.add_child(go_btn)
	go_btn.grab_focus()


func _start() -> void:
	if phase != "brief":
		return
	if brief and is_instance_valid(brief):
		brief.queue_free()
	phase = "count"
	phase_t = 0.0
	met = -10.0
	hint.text = tr(T.ignite)
	_say("Wayra", tr("Terminal count. All stations, go for launch."))


# ===================================================================================== STAGE 1: LAUNCH
func _ignite() -> void:
	if ignite_q >= 0.0:
		return
	ignite_q = Fl.ignite_quality(met)
	_grade(ignite_q)
	now_lbl.text = ""
	met = 0.0
	phase = "ascent"
	phase_t = 0.0
	shake = 1.0
	_start_climb()
	flash.color = Color(1, 0.8, 0.5, 0.5)
	roar.play()
	thump.play()
	_shout(tr("Liftoff!"), tr("1:47 a.m. EST, Launch Pad 39B."))
	_say("Inti", tr("Ooooh. That is a lot more rocket than I remember."))
	hint.text = ""


## The climb, flown as in the game's own launches: the physics of scripts/flight/ascent.gd (a heavy launcher with its
## boosters, Orion on top), the pilot's panel of scripts/flight/flight_hud.gd: lean with the arrows to keep the needle
## on the green marker, W and S on the throttle, SPACE drops the boosters and then the core stage when they are empty;
## the flight computer helps a hands-off pilot. Steering hard across the air at Max Q tears the rocket apart.
func _start_climb() -> void:
	model = Ascent.new()
	model.setup("heavy", ORION_KG, "leo")
	hud = FlightHud.new()
	add_child(hud)
	move_child(hud, flash.get_index())
	hud.build(tr("LAUNCH") + " · SLS · Artemis I", tr("STAGE"), tr("← → lean · W S throttle · Space stage"))
	hud.add_time_warp(1.0)
	hud.add_readout("alt", tr("Height"))
	hud.add_readout("speed", tr("Speed"))
	hud.add_gauge("orbit", tr("Speed toward orbit"), 2.0, 2.0, Kit.C_ACCENT)
	hud.add_gauge("fuel", tr("Fuel in this stage"), 2.0, 2.0, Kit.C_GOLD)
	hud.add_gauge("stress", tr("Stress on the structure"), 0.45, 0.85, Kit.C_OK)
	hud.lever.value = 1.0
	hud.throttle_changed.connect(func(v): throttle = v)
	hud.action_pressed.connect(_on_stage)
	hud.warp_picked.connect(func(_w): pilot_warp = true)
	hud.set_autopilot(false)
	hud.hint(tr("Lean with ← → to keep the needle on the green marker, W and S move the throttle, Space drops what is empty."))
	# the Earth under the climb, seen from above Florida (with its clouds), from about 17 km up
	horizon = Space.make_earth(HORIZON_R, false)
	horizon.set_meta("base", Basis(Quaternion(Space.latlon_to_vec(KSC.x, KSC.y).normalized(), Vector3.UP)))
	horizon.visible = false
	world.stage.add_child(horizon)
	# the story's own panels step aside for the pilot's
	gauge_panel.visible = false
	hint.text = ""


func _climb(delta: float) -> void:
	var steer := 0.0
	if hud.autopilot:
		if hud.pilot_input():
			hud.set_autopilot(false)
		else:
			steer = clampf((model.marker - model.pitch) * 0.5, -1.0, 1.0)
	if not hud.autopilot:
		steer = hud.steer().x
		throttle = hud.throttle_keys(throttle, delta)
	model.throttle = throttle
	model.autopilot = hud.autopilot
	hud.cap_warp(10.0, tr("engine on"))
	# time runs by itself: liftoff and Max Q in real time, then ten times faster, real time again for each staging
	var calm: bool = model.t > 75.0 and model.fuel() > 0.07 and model.stress < Ascent.STRESS_WARN and model.orbit_progress() < 0.97 and not model.wants_stage()
	var want_w := 10.0 if calm else 1.0
	# the pilot's own choice of ×1 or ×10 stays; until they choose, the screen picks
	if not pilot_warp and hud.warp != want_w:
		hud.set_warp(want_w)
	# the tension: alarms and a red edge while the stress is high
	alarm_t -= delta
	var hot: bool = model.stress > Ascent.STRESS_WARN
	if hot and alarm_t <= 0.0:
		alarm_t = 1.1
		alarm.play()
	red.color.a = lerpf(red.color.a, (0.18 + 0.1 * sin(_t * 12.0)) if hot else 0.0, clampf(delta * 6.0, 0.0, 1.0))
	model.step(delta, steer, hud.warp)
	met = model.t
	if model.wants_stage():
		stage_wait += delta
		hud.action.lit = true
		now_lbl.text = tr("BOOSTERS EMPTY: SPACE!") if model.boosters_attached else tr("CORE STAGE EMPTY: SPACE!")
		now_lbl.add_theme_color_override("font_color", Kit.C_GOLD)
		if stage_wait > 4.0:
			_on_stage()
			hud.message(tr("STAGE SEPARATION"), tr("The flight computer staged for you."), Kit.C_ACCENT, 2.0)
	else:
		hud.action.lit = false
		if now_lbl.text.ends_with(": SPACE!"):
			now_lbl.text = ""
	if model.h > 7000.0 and model.h < 20000.0 and not _told.has("maxq"):
		_told["maxq"] = true
		hud.hint(tr("Max Q: the air pushes hardest. Stay on the green marker or the stress climbs."))
		_say("Rumi", tr("Max Q. Keep her straight. Straight!"))
	if model.stress > Ascent.STRESS_WARN:
		shake = maxf(shake, 0.4)
	# telemetry, as in the game's launches
	hud.clock.text = FlightHud.met_text(model.t)
	hud.value("alt", ("%.1f km" % (model.h / 1000.0)) if model.h >= 1000.0 else ("%d m" % int(model.h)))
	var v: float = sqrt(model.vx * model.vx + model.vy * model.vy)
	hud.value("speed", ("%.2f km/s" % (v / 1000.0)) if v >= 1000.0 else ("%d m/s" % int(v)))
	hud.gauge("orbit", model.orbit_progress(), "%d %%" % roundi(model.orbit_progress() * 100.0))
	hud.gauge("fuel", model.fuel(), "%d %%" % roundi(model.fuel() * 100.0))
	var sf: float = model.stress / Ascent.STRESS_BREAK
	hud.gauge("stress", sf, tr("high") if sf >= 0.85 else (tr("rising") if sf >= 0.45 else tr("calm")))
	hud.dial.pitch = model.pitch
	hud.dial.marker = model.marker
	_place_rocket(delta)
	if model.broken or model.crashed:
		_lose(tr("The rocket came apart."), tr("Steered hard across the air at Max Q. That is not how it went: SLS flew straight and true. Try again."))
		return
	if model.orbit:
		_reach_orbit()


var _told := {}


static func _squash(m: float, knee: float, slope: float) -> float:
	return m if m < knee else knee + (m - knee) * slope


func _place_rocket(delta: float) -> void:
	rocket.position = Vector3(_squash(model.x, 1000.0, 0.08) * VIS, 1.0 + _squash(model.h, 1500.0, 0.1) * VIS, 0)
	shown_pitch = lerpf(shown_pitch, model.pitch, clampf(delta * 3.5, 0.0, 1.0))
	rocket.rotation = Vector3(0, 0, -deg_to_rad(shown_pitch))
	var on: bool = model.lifted and not model.flameout and throttle > 0.02
	for i in flames.size():
		var f: MeshInstance3D = flames[i]
		if is_instance_valid(f) and f.visible:
			(f.material_override as StandardMaterial3D).albedo_color.a = (0.85 + 0.15 * sin(_t * 40.0 + i)) * throttle if on else 0.0
			f.scale.y = (1.8 if i % 2 == 1 else 1.0) * (1.0 + 0.8 * clampf(model.h / 40000.0, 0.0, 1.0))
	# the particle fire: the core and boosters while attached, the upper stage's after the core is gone
	var core_on: bool = core != null and core.get_parent() == rocket
	pflames[0].emitting = on and core_on
	pflames[1].emitting = on and model.boosters_attached
	pflames[2].emitting = on and model.boosters_attached
	pflames[3].emitting = on and not core_on
	var spread: float = 1.0 + 1.8 * clampf(model.h / 50000.0, 0.0, 1.0)   # the plume opens up in thin air
	for k in 3:
		(pflames[k] as Node3D).scale = Vector3(spread, 1.0, spread)
	fire_light.light_energy = (8.0 + randf_range(-1.5, 1.5)) * throttle if on else 0.0
	pad_smoke.emitting = model.t < 9.0
	if stars:
		stars.position = world.cam.global_position
	# from about 17 km the ground gives way to the whole Earth below, with its clouds; the night sky turns to space
	if model.h > 17000.0:
		ground.visible = false
		clouds.visible = false
		horizon.visible = true
		var base: Basis = horizon.get_meta("base")
		horizon.position = rocket.position - Vector3(0, HORIZON_R * (model.R + model.h * 6.0) / model.R, 0)
		horizon.basis = Basis(Vector3(0, 0, 1), model.x / model.R) * base
	var env: Environment = world.world_env.environment
	env.fog_density = lerpf(0.00025, 0.0, clampf(model.h / 12000.0, 0.0, 1.0))
	if model.h > 30000.0 and not in_space:
		in_space = true
		env.fog_enabled = false
		env.sky = Space.make_space_sky()
		stars.visible = false
	for b in boosters:
		if b.get_parent() != rocket:
			b.position += Vector3(signf(b.position.x - rocket.position.x) * 8.0, -25.0, 0) * delta
			b.rotation.z += 0.6 * delta
	if core and core.get_parent() != rocket:
		core.position += Vector3(0, -30.0, 0) * delta
		core.rotation.z += 0.3 * delta


func _on_stage() -> void:
	if phase != "ascent" or model == null:
		return
	var what: String = model.stage()
	if what == "":
		return
	stage_wait = 0.0
	hud.action.lit = false
	now_lbl.text = ""
	Kit.UiSound.play("whoosh")
	flash.color = Color(1, 0.9, 0.7, 0.3)
	shake = 0.6
	stages_dropped += 1
	if what == "boosters":
		for b in boosters:
			var g := (b as Node3D).global_transform
			rocket.remove_child(b)
			world.stage.add_child(b)
			(b as Node3D).global_transform = g
		for i in [0, 1, 4, 5]:
			flames[i].visible = false
		hud.message(tr("BOOSTERS AWAY"), tr("Two minutes and twelve seconds, on the real flight."), Kit.C_ACCENT, 2.0)
		_say("Killa", tr("Boosters away! The real ones went at two minutes and twelve seconds."))
	elif core and core.get_parent() == rocket:
		var g2 := core.global_transform
		rocket.remove_child(core)
		world.stage.add_child(core)
		core.global_transform = g2
		hud.message(tr("CORE STAGE AWAY"), tr("Eight minutes and three seconds, on the real flight."), Kit.C_ACCENT, 2.0)
		for i in [2, 3]:
			flames[i].visible = false
		cam_focus = 72.0
		_say("Rumi", tr("Core stage away. The upper stage takes us on."))


func _reach_orbit() -> void:
	var sm: Dictionary = model.summary()
	launch_aim = clampf(1.0 - float(sm.get("mean_error_deg", 10.0)) / 10.0, 0.0, 1.0)
	hud.message(tr("ORBIT!"), tr("Now the upper stage pushes us toward the Moon."), Kit.C_OK, 3.0)
	_shout(tr("Orbit!"), tr("Next: the push toward the Moon."))
	_say("Inti", tr("We are in orbit! Campos did not even blink."))
	Kit.UiSound.play("success")
	for f in flames:
		f.visible = false
	phase = "to_moon"
	phase_t = 0.0


var launch_aim := 0.0


func _launch_q() -> float:
	# the ignition on the zero, how close the needle stayed to the marker, and the staging done by the pilot
	return (maxf(ignite_q, 0.0) + launch_aim * 2.0 + clampf(stages_dropped / 2.0, 0.0, 1.0)) / 4.0


# ===================================================================================== STAGE 2: AROUND THE MOON
func _start_flyby() -> void:
	_build_flyby()
	phase = "flyby"
	phase_t = 0.0
	head_title.text = tr("Around the Moon")
	speed = float(Fl.F.before_mph)
	gauge_panel.visible = true
	gauge_cap.text = tr("Orion's speed")
	(gauge as Gauge).mode = "burn"
	hint.text = tr(T.burn)
	clock_lbl.text = tr("Flight day 6")
	clock_sub.text = tr("81 miles above the Moon")
	speed_lbl.text = tr("Real time")
	_shout(tr("Five days later..."), tr("November 21, 2022: the far side of the Moon."))
	_say("Killa", tr("Look down! The far side! Craters on craters!"))


func _flyby(delta: float) -> void:
	var F: Dictionary = Fl.F
	burning = burn_q < 0.0 and phase_t > 2.5 and Input.is_physical_key_pressed(KEY_SPACE)
	if burning:
		speed += float(F.burn_rate_mph_s) * delta
		shake = 0.25
		if not roar.playing:
			roar.play()
	elif roar.playing:
		roar.stop()
	(orion.get_node("Burn").material_override as StandardMaterial3D).albedo_color.a = (0.9 + 0.1 * sin(_t * 40.0)) if burning else 0.0
	(gauge as Gauge).value = speed
	(gauge as Gauge).target = float(F.after_mph)
	(gauge as Gauge).band = float(F.band_mph)
	clock_sub.text = tr("%s mph · 81 miles above the Moon") % _num(speed)
	if burn_q < 0.0 and phase_t > 2.5:
		now_lbl.text = tr("HOLD SPACE: BURN!") if speed < float(F.after_mph) - float(F.band_mph) else tr("LET GO!")
		now_lbl.add_theme_color_override("font_color", Kit.C_GOLD if speed < float(F.after_mph) - float(F.band_mph) else Kit.C_OK)
	if burn_q < 0.0 and speed > float(F.before_mph) + 20.0 and not burning:
		burn_q = Fl.burn_quality(speed)
		_grade(burn_q)
		now_lbl.text = ""
		_say("Rumi", tr("%s mph. The real burn: 2,128 to 5,102.") % _num(speed))
	if speed > float(F.after_mph) + float(F.band_mph) * 2.5 and burn_q < 0.0:
		burn_q = 0.0
		_grade(0.0)
		now_lbl.text = ""
	# the surface rushes below, faster with the speed
	moon.rotate_z(delta * speed / 2128.0 * 0.012)
	world.cam.position = Vector3(-70.0, 45.0, 30.0)
	world.cam.look_at(Vector3(400.0, -150.0, 0.0), Vector3.UP)
	orion.position = Vector3(-40.0, 30.0, 18.0)
	if burn_q >= 0.0 and phase_t > 1.0:
		_start_earth()


func _start_earth() -> void:
	phase = "earth"
	phase_t = 0.0
	earth.visible = true
	earth_a = 0.0
	frame_box.visible = true
	hint.text = tr(T.earth)
	gauge_panel.visible = false
	_say("Inti", tr("Earth is coming up from behind the Moon! Get the picture!"))


func _earth(delta: float) -> void:
	# the Earth slides out from behind the Moon's edge and across the frame
	earth_a += delta
	var p := Vector3(8000.0, -1400.0 + earth_a * 520.0, -2600.0 + earth_a * 1400.0)
	earth.position = p
	earth.rotate_y(delta * 0.1)
	moon.rotate_z(delta * 0.03)
	world.cam.position = Vector3(-70.0, 45.0, 30.0)
	world.cam.look_at(Vector3(8000.0, 400.0, 0.0), Vector3.UP)
	var on := world.cam.unproject_position(p)
	var c := get_viewport().get_visible_rect().size * 0.5
	(frame_box as PhotoFrame).hot = on.distance_to(c) < 90.0
	now_lbl.text = tr("SPACE: PICTURE!") if (frame_box as PhotoFrame).hot else ""
	if earth_a > 5.5 and earth_q < 0.0:
		earth_q = 0.0
		_grade(0.0)
		_start_far()


func _snap_earth() -> void:
	if earth_q >= 0.0:
		return
	var on := world.cam.unproject_position(earth.position)
	var c := get_viewport().get_visible_rect().size * 0.5
	earth_q = clampf(1.0 - on.distance_to(c) / 160.0, 0.0, 1.0)
	flash.color = Color(1, 1, 1, 0.6)
	Kit.UiSound.play("snap")
	_grade(earth_q)
	get_tree().create_timer(1.0).timeout.connect(_start_far)


## The far point: NASA's own picture from Orion, 268,563 miles from Earth.
func _start_far() -> void:
	if phase == "far":
		return
	phase = "far"
	phase_t = 0.0
	frame_box.visible = false
	now_lbl.text = ""
	hint.text = ""
	photo_layer = Control.new()
	photo_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(photo_layer)
	move_child(photo_layer, flash.get_index())
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	photo_layer.add_child(shade)
	var p := Kit.panel_box(Kit.PAD)
	Kit.place(p, 0.5, 0.5, 0.5, 0.5, -460, -250, 460, 270)
	photo_layer.add_child(p)
	var v := Kit.vbox(Kit.GAP)
	p.add_child(v)
	v.add_child(Kit.caps(tr("Flight day 13 · the far point")))
	v.add_child(Kit.lbl(tr("268,563 miles from Earth"), Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T))
	var img := TextureRect.new()
	img.texture = load(Fl.D.far.photo)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(880, 330)
	v.add_child(img)
	v.add_child(Kit.lbl(tr("The real picture, from Orion: the Moon and, beyond it, the Earth. Farther than any craft built for people had gone.") + "  ·  " + Fl.D.far.credit, Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))
	photo_layer.modulate.a = 0.0
	photo_layer.create_tween().tween_property(photo_layer, "modulate:a", 1.0, 0.8)
	Kit.UiSound.play("fanfare")
	_say("Rumi", tr("Campos's seat has never been this far from home. Nobody's has."))


func _far_to_home() -> void:
	if phase != "far":
		return
	if photo_layer and is_instance_valid(photo_layer):
		photo_layer.queue_free()
	_cabin_beat([["killa", "point", "happy", tr("Look out the window: the Earth and the Moon, the same size. We are that far.")],
			["inti", "scared", "scared", tr("And now we go back. Into the fire. At Mach thirty-two.")],
			["rumi", "shrug", "flat", tr("The heat shield does the work. We just sit still. Like Campos.")]],
			func(): _go_map(2))


func _go_map(step: int) -> void:
	if step == 1:
		phase = "map_x"
		return
	phase = "map"
	phase_t = 0.0
	_show_map(2, tr("Next: home"), tr("A second flyby of the Moon on December 5 turns Orion for home. Six days later it meets the Earth's air at 24,581 mph, Mach 32, over the Pacific Ocean, and has to come down off the coast of San Diego, in California."), _start_entry)


# ===================================================================================== THE CREW BETWEEN THE STAGES
var beat_lines: Array = []
var beat_i := -1
var beat_next: Callable
var beat_actors := {}
var beat_cam := [Vector3.ZERO, Vector3.ZERO]


## A short moment inside Orion: the cuyes hidden in Campos's seat say a line each about what just happened and what
## comes next (the story's set "orion_cabin"), then the mission goes on.
func _cabin_beat(lines: Array, next: Callable) -> void:
	if hud and is_instance_valid(hud):
		hud.queue_free()
		hud = null
	red.color.a = 0.0
	gauge_panel.visible = false
	now_lbl.text = ""
	hint.text = ""
	big.text = ""
	big_sub.text = ""
	roar.stop()
	beat_lines = lines
	beat_next = next
	beat_i = -1
	_clear()
	var S: Dictionary = Sets.build("orion_cabin", world)
	beat_actors.clear()
	for id in ["inti", "killa", "rumi"]:
		var a = CuyActor.new()
		a.id = id
		world.stage.add_child(a)
		a.scale = Vector3.ONE * float(S.get("actor_scale", 1.0))
		a.global_position = S.marks[id].pos
		a.rotation.y = S.marks[id].yaw
		beat_actors[id] = a
	var c: Dictionary = S.cams.wide
	beat_cam = [c.from, c.to]
	world.cam.position = c.from
	world.cam.look_at(c.to, Vector3.UP)
	flash.color = Color(0, 0, 0, 1.0)
	phase = "beat"
	phase_t = 0.0
	beat_t = 0.0
	_beat_next_line()


func _beat_next_line() -> void:
	# the lines in the story's own card at the bottom (portrait, name, station), as in every other chapter
	var ls := []
	for L in beat_lines:
		ls.append({"who": L[0], "text": L[3], "mood": L[2]})
	var d = load("res://scripts/story/dialogue.gd").new()
	d.lines = ls
	d.line_started.connect(func(i, _l): _beat_act(i))
	d.finished.connect(func(_skipped): _beat_done())
	main.add_child(d)
	beat_dialogue = d


var beat_dialogue: Node
var beat_t := 0.0


func _beat_act(i: int) -> void:
	for k in beat_actors:
		beat_actors[k].talking = false
	var L: Array = beat_lines[i]
	var a = beat_actors[L[0]]
	a.act = L[1]
	a.set_mood(L[2])
	a.talking = true


func _beat_done() -> void:
	beat_dialogue = null
	for k in beat_actors:
		beat_actors[k].talking = false
	var n := beat_next
	n.call()


func _beat(delta: float) -> void:
	beat_t += delta
	# a slow push in on the seat, the crew peeking out of it
	world.cam.position = world.cam.position.lerp(beat_cam[0] + (beat_cam[1] - beat_cam[0]) * 0.12, clampf(delta * 0.3, 0.0, 1.0))
	world.cam.look_at(beat_cam[1], Vector3.UP)


# ===================================================================================== THE JOURNEY MAP
var map_layer: Control
var map_next: Callable


## Where we are in the whole trip: the Earth, the Moon, the path out around the far side and back, Orion on it.
func _show_map(step: int, title: String, text: String, next: Callable) -> void:
	map_next = next
	map_layer = Control.new()
	map_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(map_layer)
	move_child(map_layer, flash.get_index())
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.03, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_layer.add_child(shade)
	var p := Kit.panel_box(Kit.PAD)
	Kit.place(p, 0.5, 0.5, 0.5, 0.5, -560, -300, 560, 300)
	map_layer.add_child(p)
	var v := Kit.vbox(Kit.GAP)
	p.add_child(v)
	v.add_child(Kit.caps(tr("The journey · %d of 3") % (step + 1)))
	v.add_child(Kit.lbl(title, Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T))
	var m := JourneyMap.new()
	m.step = step
	m.custom_minimum_size = Vector2(1080, 300)
	v.add_child(m)
	var t := Kit.lbl(text, Kit.T_BODY + 1, Kit.C_TEXT, Kit.FONT_R, true)
	t.custom_minimum_size.x = 1060
	v.add_child(t)
	var go_btn := Kit.btn(tr("Continue  ·  Enter"), _map_go, Kit.T_BODY)
	Kit.accent_btn(go_btn, Kit.C_GOLD)
	v.add_child(go_btn)
	go_btn.grab_focus()
	map_layer.modulate.a = 0.0
	map_layer.create_tween().tween_property(map_layer, "modulate:a", 1.0, 0.5)
	hint.text = ""
	now_lbl.text = ""
	big.text = ""
	big_sub.text = ""


func _map_go() -> void:
	if phase != "map":
		return
	if map_layer and is_instance_valid(map_layer):
		map_layer.queue_free()
	phase = "between"
	map_next.call()


func _flyby_q() -> float:
	return (maxf(burn_q, 0.0) + maxf(earth_q, 0.0)) / 2.0


# ===================================================================================== STAGE 3: HOME AT MACH 32
func _start_entry() -> void:
	if photo_layer and is_instance_valid(photo_layer):
		photo_layer.queue_free()
	if map_layer and is_instance_valid(map_layer):
		map_layer.queue_free()
	_build_entry()
	phase = "entry"
	phase_t = 0.0
	head_title.text = tr("Home at Mach 32")
	angle = -6.0
	alt_km = 120.0
	gauge_panel.visible = true
	gauge_cap.text = tr("The re-entry corridor")
	(gauge as Gauge).mode = "corridor"
	hint.text = tr(T.corridor)
	clock_lbl.text = tr("Flight day 26")
	_shout(tr("December 11, 2022"), tr("24,581 mph. Mach 32. The heat shield faces the fire."))
	_say("Wayra", tr("Into the corridor. Not too steep, not too shallow."))
	roar.play()


func _entry(delta: float) -> void:
	var R: Dictionary = Fl.R
	var k := clampf(phase_t / float(R.time_s), 0.0, 1.0)
	# the angle drifts (the air's push changes, our simplification); W/S lift and lower the nose
	drift = lerpf(drift, randf_range(-1.0, 1.0), delta * 1.2)
	var push := 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		push += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		push -= 1.0
	angle += (drift * float(R.drift_deg_s) * (1.0 + k) + push * float(R.push_deg_s)) * delta
	angle = clampf(angle, -12.0, -1.0)
	var q := Fl.corridor_quality(angle)
	corr_sum += q
	corr_n += 1
	if not Fl.in_corridor(angle):
		out_t += delta
		now_lbl.text = tr("TOO STEEP! (W)") if angle < -6.0 else tr("TOO SHALLOW! (S)")
		now_lbl.add_theme_color_override("font_color", Kit.C_BAD)
		shake = 0.5
		if out_t > 1.8:
			_lose(tr(T.lost_corridor), tr(T.lost_corridor_sub))
			return
	else:
		out_t = maxf(0.0, out_t - delta)
		now_lbl.text = tr("IN THE CORRIDOR") if q > 0.4 else tr("Careful...")
		now_lbl.add_theme_color_override("font_color", Kit.C_OK if q > 0.4 else Kit.C_GOLD)
	(gauge as Gauge).mode = "corridor"
	(gauge as Gauge).value = angle
	mach = lerpf(32.0, 1.2, k)
	alt_km = lerpf(120.0, 12.0, k)
	clock_sub.text = tr("Mach %d · %d km up · over the Pacific") % [int(mach), int(alt_km)]
	_home_tag()
	speed_lbl.text = tr("Shown 40 times faster")
	(plasma.material_override as StandardMaterial3D).albedo_color.a = clampf(1.0 - absf(k - 0.45) * 1.8, 0.0, 1.0) * (0.85 + 0.15 * sin(_t * 30.0))
	plasma.scale = Vector3.ONE * (1.0 + 0.1 * sin(_t * 23.0))
	shake = maxf(shake, 0.3 * clampf(1.0 - absf(k - 0.45) * 2.0, 0.0, 1.0))
	capsule.position = Vector3(0, alt_km, 0)
	capsule.rotation.z = deg_to_rad(angle) * 3.0
	world.cam.position = capsule.position + Vector3(-9.0, 3.0, 9.0)
	world.cam.look_at(capsule.position + Vector3(4, -2, 0), Vector3.UP)
	if k >= 1.0:
		_start_chutes()


## Where Orion is going: San Diego's coast, ahead on the curve of the Earth, with a marker of constant size.
var home_lbl: Label


func _home_tag() -> void:
	if home_lbl == null:
		home_lbl = Kit.lbl(tr("▼ San Diego · Pacific Ocean"), Kit.T_BODY, Kit.C_GOLD, Kit.FONT_B)
		home_lbl.add_theme_constant_override("outline_size", 6)
		home_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		add_child(home_lbl)
		move_child(home_lbl, hint_panel.get_index())
	var c := Vector3(0, -6371.0 - 120.0, 0)
	var ahead := c + (capsule.position + Vector3(900, -120, -500) - c).normalized() * 6371.0
	home_lbl.visible = phase == "entry" and not world.cam.is_position_behind(ahead)
	if home_lbl.visible:
		home_lbl.position = world.cam.unproject_position(ahead) - Vector2(home_lbl.size.x * 0.5, home_lbl.size.y)


func _start_chutes() -> void:
	if home_lbl:
		home_lbl.visible = false
	phase = "chutes"
	phase_t = 0.0
	now_lbl.text = ""
	roar.stop()
	(plasma.material_override as StandardMaterial3D).albedo_color.a = 0.0
	(gauge as Gauge).mode = "height"
	gauge_cap.text = tr("Height")
	hint.text = tr("The parachutes: 1 for the drogues, 2 for the mains, each on its mark.")
	_say("Killa", tr("Through the fire! Now the parachutes!"))


func _chutes(delta: float) -> void:
	var R: Dictionary = Fl.R
	var rate := 0.55 if drogue_q < 0.0 else (0.32 if main_q < 0.0 else 0.18)
	alt_km = maxf(0.0, alt_km - rate * delta)
	(gauge as Gauge).value = alt_km
	clock_sub.text = tr("%.1f km up") % alt_km
	speed_lbl.text = tr("Real time, near enough")
	if drogue_q < 0.0:
		now_lbl.text = tr(T.drogue).to_upper() if absf(alt_km - float(R.drogue_km)) < float(R.call_window_km) else ""
		if alt_km < float(R.drogue_km) - float(R.call_window_km):
			_drogue()
	elif main_q < 0.0:
		now_lbl.text = tr(T.main).to_upper() if absf(alt_km - float(R.main_km)) < float(R.call_window_km) else ""
		if alt_km < float(R.main_km) - float(R.call_window_km):
			_main()
	now_lbl.add_theme_color_override("font_color", Kit.C_GOLD)
	capsule.position = Vector3(0, alt_km * 3.0, 0)
	capsule.rotation.z = lerpf(capsule.rotation.z, 0.0, delta)
	world.cam.position = capsule.position + Vector3(-20.0, 2.0, 20.0)
	world.cam.look_at(capsule.position + Vector3(0, 5, 0), Vector3.UP)
	for c in chutes:
		if c.visible:
			c.scale = c.scale.lerp(Vector3.ONE, delta * 3.0)
	if alt_km <= 0.0:
		_splash()


func _drogue() -> void:
	drogue_q = Fl.chute_quality(alt_km, float(Fl.R.drogue_km))
	_grade(drogue_q)
	Kit.UiSound.play("whoosh")
	chutes[1].visible = true
	chutes[1].scale = Vector3.ONE * 0.1
	(chutes[1].get_node("Dome") as MeshInstance3D).scale = Vector3(0.45, 0.3, 0.45)
	now_lbl.text = ""


func _main() -> void:
	main_q = Fl.chute_quality(alt_km, float(Fl.R.main_km))
	_grade(main_q)
	Kit.UiSound.play("whoosh")
	chutes[1].visible = false
	for i in [0, 1, 2]:
		chutes[i].visible = true
		chutes[i].scale = Vector3.ONE * 0.1
		(chutes[i].get_node("Dome") as MeshInstance3D).scale = Vector3(1, 0.45, 1)
	now_lbl.text = ""
	_say("Inti", tr("Three big ones! I love parachutes. I take back everything I said about airbags."))


func _splash() -> void:
	phase = "splash"
	phase_t = 0.0
	now_lbl.text = ""
	hint.text = ""
	gauge_panel.visible = false
	flash.color = Color(0.7, 0.85, 1.0, 0.7)
	thump.play()
	Kit.UiSound.play("fanfare")
	var env: Environment = world.world_env.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.12, 0.2)
	world.sun.rotation_degrees = Vector3(-70, 30, 0)
	var sea := Sets.box(world.stage, Vector3(3000, 0.2, 3000), capsule.position + Vector3(0, -0.5, 0), Sets.mat(Color(0.1, 0.25, 0.4), 0.25, 0.2))
	sea.name = "Sea"
	var ship := Node3D.new()
	ship.position = capsule.position + Vector3(260, 0, -420)
	world.stage.add_child(ship)
	Sets.box(ship, Vector3(60, 6, 12), Vector3(0, 3, 0), Sets.mat(Color(0.45, 0.47, 0.5), 0.7, 0.3))
	Sets.box(ship, Vector3(14, 10, 9), Vector3(-8, 11, 0), Sets.mat(Color(0.5, 0.52, 0.55), 0.7, 0.3))
	Sets.box(ship, Vector3(3, 14, 3), Vector3(-8, 23, 0), Sets.mat(Color(0.4, 0.42, 0.45), 0.7, 0.3))
	_shout(tr("Splashdown!"), tr("12:40 p.m. EST, December 11, 2022, off San Diego."))
	_say("Wayra", tr("Twenty-five days, ten hours, fifty-three minutes. Welcome home, all of you."))


func _entry_q() -> float:
	var c := corr_sum / corr_n if corr_n > 0 else 0.0
	return (c * 2.0 + maxf(drogue_q, 0.0) + maxf(main_q, 0.0)) / 4.0


func _score() -> float:
	return Fl.score(_launch_q(), _flyby_q(), _entry_q())


# ===================================================================================== THE END
func _lose(a: String, b: String) -> void:
	if hud and is_instance_valid(hud):
		hud.queue_free()
		hud = null
	phase = "lost"
	phase_t = 0.0
	roar.stop()
	Kit.UiSound.play("error")
	hint.text = ""
	now_lbl.text = ""
	gauge_panel.visible = false
	lose_layer = Control.new()
	lose_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(lose_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.0, 0.0, 0.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lose_layer.add_child(shade)
	shade.create_tween().tween_property(shade, "color:a", 0.78, 1.0)
	var v := Kit.vbox(Kit.GAP)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.modulate.a = 0.0
	lose_layer.add_child(v)
	var l1 := Kit.lbl(a, Kit.T_SHOUT, Kit.C_BAD, Kit.FONT_T)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l1)
	var l2 := Kit.lbl(b, Kit.T_ACTION, Kit.C_ON_DARK, Kit.FONT_B, true)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l2.custom_minimum_size.x = 900
	v.add_child(l2)
	var row := Kit.hbox(Kit.GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var again := Kit.btn(tr("Try again  ·  Enter"), _again, Kit.T_BODY)
	Kit.accent_btn(again, Kit.C_GOLD)
	row.add_child(again)
	v.create_tween().tween_property(v, "modulate:a", 1.0, 0.6).set_delay(0.5)
	again.grab_focus()


func _again() -> void:
	go("artemis1", {"campaign": campaign, "then": then_scenes, "back": back})


func _continue() -> void:
	if not then_scenes.is_empty():
		go("story", {"scenes": then_scenes, "back": back})
	else:
		go(back)


func _show_result() -> void:
	result_shown = true
	big.text = ""
	big_sub.text = ""
	var total := _score()
	if total < float(Fl.D.score.need):
		_lose(tr(T.few), tr(T.few_sub) + "\n" + tr("Result: %d%% of %d%% needed.") % [int(total), int(Fl.D.score.need)])
		result_shown = false
		return
	var shade := ColorRect.new()
	shade.color = Kit.C_SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var p := Kit.panel_box(Kit.PAD)
	Kit.place(p, 0.5, 0.5, 0.5, 0.5, -440, -270, 440, 270)
	add_child(p)
	var v := Kit.vbox(Kit.GAP)
	p.add_child(v)
	v.add_child(Kit.caps(tr("Mission 6 · done · the crew is home")))
	var stars := Fl.stars_for(total)
	var new_patch := Progress.earn("artemis1", stars)
	var sh := Kit.hbox(Kit.PAD)
	v.add_child(sh)
	sh.add_child(Kit.lbl("★".repeat(stars) + "☆".repeat(3 - stars), Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T))
	sh.add_child(Kit.lbl("%d%%" % int(total), Kit.T_CLOCK, Kit.C_TEXT, Kit.FONT_T))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	v.add_child(grid)
	for row in [[tr("Launch"), "%d%%" % int(_launch_q() * 100.0)], [tr("Around the Moon"), "%d%%" % int(_flyby_q() * 100.0)],
			[tr("Home at Mach 32"), "%d%%" % int(_entry_q() * 100.0)]]:
		grid.add_child(Kit.lbl(row[0], Kit.T_BODY, Kit.C_DIM, Kit.FONT_R))
		grid.add_child(Kit.lbl(row[1], Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B))
	# the collectibles: this mission's patch, and the campaign's trophy once all six are home
	var award := Kit.hbox(Kit.GAP)
	v.add_child(award)
	award.add_child(Kit.lbl("★", Kit.T_CLOCK + 6, Kit.C_GOLD, Kit.FONT_T))
	var av := Kit.vbox(0)
	award.add_child(av)
	if Progress.all_done():
		av.add_child(Kit.lbl(tr("Trophy earned: Campos's seat!"), Kit.T_ACTION, Kit.C_GOLD, Kit.FONT_B))
		av.add_child(Kit.lbl(tr("All six mission patches: the whole campaign, 1970 to 2022. See them in Campaign."), Kit.T_SMALL + 1, Kit.C_DIM, Kit.FONT_R, true))
	else:
		av.add_child(Kit.lbl(tr("Patch earned: Artemis I") if new_patch else tr("Artemis I patch: your best kept"), Kit.T_ACTION, Kit.C_GOLD, Kit.FONT_B))
		av.add_child(Kit.lbl(tr("%d of 6 patches. Earn all six for the trophy: see them in Campaign.") % Progress.count(), Kit.T_SMALL + 1, Kit.C_DIM, Kit.FONT_R, true))
	if Progress.all_done():
		Kit.UiSound.play("fanfare")
	v.add_child(Kit.rule())
	for F in Fl.D.facts:
		var fh := Kit.hbox(Kit.GAP)
		fh.add_child(Kit.chip("NASA", Kit.C_GOLD))
		var fl := Kit.lbl(tr(F.text), Kit.T_SMALL + 1, Kit.C_DIM, Kit.FONT_R, true)
		fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fl.custom_minimum_size.x = 680
		fh.add_child(fl)
		v.add_child(fh)
	var row2 := Kit.hbox(Kit.GAP)
	v.add_child(row2)
	var go_on := Kit.btn(tr("Continue  ·  Enter"), _continue, Kit.T_BODY)
	Kit.accent_btn(go_on, Kit.C_GOLD)
	row2.add_child(go_on)
	row2.add_child(Kit.btn(tr("Play again  ·  R"), _again, Kit.T_BODY))
	go_on.grab_focus()


func _num(x: float) -> String:
	var s := str(int(round(x)))
	if s.length() > 3:
		s = s.substr(0, s.length() - 3) + "," + s.substr(s.length() - 3)
	return s


# ===================================================================================== EVERY FRAME
func process(delta: float) -> void:
	_t += delta
	phase_t += delta
	big_t += delta
	flash.color.a = maxf(0.0, flash.color.a - delta * 1.2)
	if big_t > 3.5 and big.text != "" and phase not in ["splash", "done"]:
		big.text = ""
		big_sub.text = ""
	match phase:
		"brief", "count":
			if phase == "count":
				met += delta
				var n := int(ceil(-met))
				now_lbl.text = tr("T- %d") % n if met < 0.0 else tr("IGNITION: SPACE!")
				now_lbl.add_theme_color_override("font_color", Kit.C_GOLD)
				clock_lbl.text = "T- 00:00:%02d" % maxi(n, 0)
				if n > 0 and not said_count.has(n):
					said_count[n] = true
					beep.play()
					shake = 0.08 * (11 - n) / 10.0
					match n:
						9:
							_say("Rumi", tr("Tanks pressed. Everything is green."))
						7:
							_say("Killa", tr("Campos, sit still. We are right behind you."))
						5:
							_say("Inti", tr("Five... four... I am not nervous. I am counting."))
						3:
							_say("Wayra", tr("Engines start!"))
					if n <= 6:
						pad_smoke.emitting = true
				if n <= 6:
					fire_light.light_energy = (6.0 - float(n)) * 1.2
					for k in [0]:
						pflames[k].emitting = n <= 6
				if met > 1.0:
					ignite_q = 0.0
					_grade(0.0)
					ignite_q = -1.0
					_ignite()
			# the countdown: a slow push in on the rocket, under the stars
			var push := clampf((met + 10.0) / 10.0, 0.0, 1.0) if phase == "count" else 0.0
			world.cam.position = Vector3(150, 25, 260).lerp(Vector3(70, 16, 120), smoothstep(0.0, 1.0, push))
			world.cam.look_at(Vector3(0, 40, 0), Vector3.UP)
			if stars:
				stars.position = world.cam.global_position
		"ascent":
			_climb(delta)
			clock_lbl.text = Fl.met(met)
			clock_sub.text = tr("Space Launch System, from Pad 39B")
			var rp := rocket.global_position
			var up := rocket.global_transform.basis.y
			var hk: float = clampf(model.h / 40000.0, 0.0, 1.0) if model else 0.0
			var want := Vector3(110, 25, 190).lerp(Vector3(90, 70, 130), hk)
			if cam_focus > 50.0:
				# only the upper stage and Orion now: closer, and on them
				want = Vector3(30, 26, 52)
			if phase_t < 5.0:
				# liftoff seen from the ground, the whole pad and the rocket in view, then the camera follows
				want = want.lerp(Vector3(150, 20 - rp.y + 30.0, 260), 1.0 - smoothstep(1.0, 5.0, phase_t))
			# the camera keeps its place relative to the rocket (never lagging behind it at speed), easing between views
			cam_off = want if cam_off == Vector3.INF else cam_off.lerp(want, clampf(delta * 2.0, 0.0, 1.0))
			world.cam.position = rp + cam_off
			var look := rp + up * cam_focus
			if cam_focus > 50.0:
				look -= Vector3(0, 10, 0)    # a little below the stage, so the Earth shows under it
			world.cam.look_at(look, Vector3.UP)
			world.cam.fov = 50.0
		"to_moon":
			if phase_t > 3.0:
				if hud and is_instance_valid(hud):
					hud.queue_free()
					hud = null
				_cabin_beat([["inti", "cheer", "happy", tr("Orbit! Did you feel that? I felt that in my whiskers.")],
						["rumi", "work", "pleased", tr("Upper stage healthy. In ninety minutes it fires again, and we leave the Earth.")],
						["killa", "point", "happy", tr("Next stop: the far side of the Moon. Nobody has seen it from this seat.")]],
						func(): _go_map(1))
		"beat":
			_beat(delta)
		"map_wait":
			pass
		"map_x":
			phase = "map"
			phase_t = 0.0
			_show_map(1, tr("Next: to the Moon"), tr("From orbit, the upper stage fires once more and sends Orion toward the Moon: the trans-lunar injection, 1 hour and 29 minutes after liftoff. Five days later Orion passes 81 miles above the far side of the Moon, and fires its own engine to swing out past it."), _start_flyby)
		"map":
			pass
		"flyby":
			_flyby(delta)
		"earth":
			_earth(delta)
		"far":
			if phase_t > 6.0:
				_far_to_home()
		"entry":
			_entry(delta)
		"chutes":
			_chutes(delta)
		"splash":
			world.cam.position = capsule.position + Vector3(-20.0, 3.0, 20.0)
			world.cam.look_at(capsule.position + Vector3(0, 5, 0), Vector3.UP)
			capsule.position.y = -0.2 + 0.3 * sin(_t * 1.5)
			if phase_t > 4.0 and not result_shown:
				_cabin_beat([["inti", "cheer", "happy", tr("Splashdown! We are floating! I love floating.")],
						["killa", "cheer", "happy", tr("Twenty-five days. The Moon and back. With Campos.")],
						["rumi", "wave", "pleased", tr("Next time, people sit in these seats. We just tested them first.")]],
						func(): phase = "done"; _show_result())
	_stages_ui()
	if shake > 0.0:
		world.cam.rotate_object_local(Vector3.UP, deg_to_rad(randf_range(-1, 1) * shake * 0.6))
		world.cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(randf_range(-1, 1) * shake * 0.6))
		shake = maxf(0.0, shake - delta * 1.5)
	hint_panel.visible = hint.text != ""
	shout_panel.visible = big.text != ""
	big_sub.visible = big_sub.text != ""
	now_panel.visible = now_lbl.text != ""


func _stages_ui() -> void:
	var cur := 0
	match phase:
		"brief", "count", "ascent":
			cur = 0
		"to_moon", "flyby", "earth", "far":
			cur = 1
		"entry", "chutes":
			cur = 2
		_:
			cur = 3
	for i in stage_rows.size():
		var l: Label = stage_rows[i]
		l.text = ("✓  " if i < cur else ("▶  " if i == cur else "·  ")) + stage_names[i]
		l.add_theme_color_override("font_color", Kit.C_OK if i < cur else (Kit.C_GOLD if i == cur else Kit.C_DIM))


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = e.physical_keycode
	if result_shown:
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			_continue()
		elif k == KEY_R:
			_again()
		else:
			return
	elif phase == "lost":
		if k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_R:
			_again()
		else:
			return
	elif phase == "brief" and (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE):
		_start()
	elif phase == "count" and k == KEY_SPACE:
		_ignite()
	elif phase == "earth" and k == KEY_SPACE:
		_snap_earth()
	elif phase == "far" and (k == KEY_ENTER or k == KEY_SPACE) and phase_t > 1.5:
		_far_to_home()
	elif phase == "map" and (k == KEY_ENTER or k == KEY_SPACE) and phase_t > 0.8:
		_map_go()
	elif phase == "chutes" and k == KEY_1 and drogue_q < 0.0:
		_drogue()
	elif phase == "chutes" and k == KEY_2 and drogue_q >= 0.0 and main_q < 0.0:
		_main()
	elif k == KEY_ESCAPE:
		go(back)
	else:
		return
	get_viewport().set_input_as_handled()


# ===================================================================================== DRAWINGS
## The camera frame for the Earth's picture: gold when the Earth is inside it.
class PhotoFrame extends Control:
	var hot := false

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var col := Kit.C_GOLD if hot else Color(1, 1, 1, 0.7)
		var w := 180.0
		var h := 120.0
		for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var p := c + Vector2(w * s.x, h * s.y)
			draw_line(p, p - Vector2(40 * s.x, 0), col, 3.0)
			draw_line(p, p - Vector2(0, 40 * s.y), col, 3.0)
		draw_circle(c, 3.0, col)


## One gauge, four readings: Max Q's push with its band, the burn's speed with its gold band, the re-entry angle in
## its corridor, the height with the parachute marks.
class Gauge extends Control:
	var mode := "maxq"
	var value := 0.0
	var target := 5102.0
	var band := 160.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _y(v: float, lo: float, hi: float) -> float:
		return size.y - 20.0 - (clampf(v, lo, hi) - lo) / (hi - lo) * (size.y - 40.0)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, 0.9))
		var x0 := size.x * 0.35
		var x1 := size.x * 0.65
		var lo := 0.0
		var hi := 1.0
		var g0 := 0.0
		var g1 := 0.0
		var text := ""
		match mode:
			"maxq":
				lo = 0.0
				hi = 1.4
				g0 = 0.55
				g1 = 0.85
				text = "%d%%" % int(value / 1.4 * 100.0)
			"burn":
				lo = 2000.0
				hi = 6000.0
				g0 = target - band
				g1 = target + band
				text = "%d mph" % int(value)
			"corridor":
				lo = -12.0
				hi = -1.0
				g0 = -7.5
				g1 = -4.5
				text = "%.1f°" % value
			"height":
				lo = 0.0
				hi = 12.0
				text = "%.1f km" % value
		draw_rect(Rect2(x0, 20, x1 - x0, size.y - 40), Color(0.1, 0.12, 0.18))
		if mode != "height":
			draw_rect(Rect2(x0, _y(g1, lo, hi), x1 - x0, _y(g0, lo, hi) - _y(g1, lo, hi)), Color(Kit.C_OK, 0.35) if mode != "burn" else Color(Kit.C_GOLD, 0.4))
		else:
			for m in [[7.6, TranslationServer.translate("Drogues")], [2.9, TranslationServer.translate("Mains")]]:
				var yy := _y(m[0], lo, hi)
				draw_line(Vector2(x0 - 10, yy), Vector2(x1 + 10, yy), Kit.C_GOLD, 2.0)
				draw_string(Kit.FONT_B, Vector2(x1 + 14, yy + 5), m[1], HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_GOLD)
		var y := _y(value, lo, hi)
		draw_colored_polygon(PackedVector2Array([Vector2(x0 - 16, y - 9), Vector2(x0 - 2, y), Vector2(x0 - 16, y + 9)]), Kit.C_TEXT)
		draw_line(Vector2(x0, y), Vector2(x1, y), Kit.C_TEXT, 3.0)
		draw_string(Kit.FONT_T, Vector2(8, size.y - 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_ACTION, Kit.C_TEXT)
		if mode == "corridor":
			draw_string(Kit.FONT_B, Vector2(x1 + 6, _y(-2.0, lo, hi)), TranslationServer.translate("skips off"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_BAD)
			draw_string(Kit.FONT_B, Vector2(x1 + 6, _y(-11.0, lo, hi)), TranslationServer.translate("too hot"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_BAD)


## The whole trip on one line: the Earth on the left, the Moon on the right, the path out and around the far side
## and back (drawn for the game, not to scale: the Moon is 239,000 miles away), Orion's place on it.
class JourneyMap extends Control:
	var step := 0
	var t := 0.0

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _p(a: float) -> Vector2:
		var e := Vector2(size.x * 0.14, size.y * 0.55)
		var m := Vector2(size.x * 0.8, size.y * 0.5)
		if a < 0.45:
			var k := a / 0.45
			return e.lerp(m + Vector2(-60, -70), k) + Vector2(0, -sin(k * PI) * 55.0)
		if a < 0.6:
			var k2 := (a - 0.45) / 0.15
			var ang := lerpf(PI * 0.6, -PI * 0.6, k2)
			return m + Vector2(cos(ang) * 95.0, -sin(ang) * 85.0)
		var k3 := (a - 0.6) / 0.4
		return (m + Vector2(-60, 70)).lerp(e + Vector2(0, 20), k3) + Vector2(0, sin(k3 * PI) * 55.0)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, 0.9))
		var e := Vector2(size.x * 0.14, size.y * 0.55)
		var m := Vector2(size.x * 0.8, size.y * 0.5)
		draw_circle(e, 34.0, Color(0.25, 0.5, 0.9))
		draw_arc(e, 37.0, 0, TAU, 48, Color(0.6, 0.8, 1.0, 0.5), 2.0)
		draw_circle(m, 14.0, Color(0.75, 0.75, 0.75))
		draw_string(Kit.FONT_B, e + Vector2(-20, 58), TranslationServer.translate("Earth"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_TEXT)
		draw_string(Kit.FONT_B, m + Vector2(-18, 36), TranslationServer.translate("Moon"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_TEXT)
		var done_to: float = [0.03, 0.5, 0.97][clampi(step, 0, 2)]
		var prev := _p(0.0)
		for i in range(1, 121):
			var a := i / 120.0
			var q := _p(a)
			draw_line(prev, q, Kit.C_GOLD if a <= done_to else Color(1, 1, 1, 0.25), 3.0 if a <= done_to else 2.0)
			prev = q
		draw_string(Kit.FONT_B, e + Vector2(-40, -48), TranslationServer.translate("Launch · Nov 16"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_DIM)
		draw_string(Kit.FONT_B, m + Vector2(-60, -100), TranslationServer.translate("Far side · Nov 21"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_DIM)
		draw_string(Kit.FONT_B, e + Vector2(40, 84), TranslationServer.translate("Splashdown · Dec 11"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_DIM)
		draw_string(Kit.FONT_B, Vector2(size.x * 0.5 - 120, size.y - 10), TranslationServer.translate("Drawn for the game, not to scale"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL - 2, Kit.C_DIM)
		var start: float = [0.0, 0.03, 0.5][clampi(step, 0, 2)]
		var o := _p(lerpf(start, done_to, fmod(t * 0.25, 1.0)))
		draw_circle(o, 7.0, Color(1, 1, 1))
		draw_arc(o, 12.0 + 3.0 * sin(t * 6.0), 0, TAU, 24, Kit.C_GOLD, 2.0)


## The buttons a phone needs now (scripts/ui/touch_keys.gd): the climb has the pilot's own panel; the rest, only what
## each moment asks for.
func touch_keys() -> Array:
	match phase:
		"count":
			return [[tr("IGNITION"), KEY_SPACE, "right"]]
		"flyby":
			if burn_q < 0.0:
				return [[tr("BURN (hold)"), KEY_SPACE, "right"]]
		"earth":
			return [[tr("PHOTO"), KEY_SPACE, "right"]]
		"far":
			return [[tr("Continue"), KEY_ENTER, "right"]]
		"entry":
			return [["▲", KEY_W, "left"], ["▼", KEY_S, "left"]]
		"chutes":
			if drogue_q < 0.0:
				return [[tr("1 DROGUES"), KEY_1, "right"]]
			if main_q < 0.0:
				return [[tr("2 MAINS"), KEY_2, "right"]]
	return []


## A phone in landscape (Kit.compact): fewer panels and nothing over anything. The stage list goes (the step is in the
## title and the call to act), the radio keeps one short line at the top right, the line of what to do sits in the
## middle above the touch buttons (scripts/ui/touch_keys.gd), and the big call to act just above it.
func _phone_layout() -> void:
	if not Kit.compact:
		return
	if not stage_rows.is_empty():
		(stage_rows[0] as Control).get_parent().get_parent().visible = false
	var radio_card: Control = radio.get_parent().get_parent()
	Kit.place(radio_card, 1, 0, 1, 0, -Kit.MARGIN - 330, Kit.MARGIN, -Kit.MARGIN, Kit.MARGIN + 50)
	radio.custom_minimum_size.x = 300
	radio.add_theme_font_size_override("font_size", Kit.T_BODY)
	Kit.place(hint_panel, 0.5, 1, 0.5, 1, -250, -150, 250, -96)
	hint.add_theme_font_size_override("font_size", Kit.T_BODY)
	Kit.place(now_panel, 0.5, 1, 0.5, 1, -10, -210, 10, -160)
	now_lbl.add_theme_font_size_override("font_size", Kit.T_ACTION + 2)
	Kit.place(gauge_panel, 1, 1, 1, 1, -Kit.MARGIN - 200, -Kit.MARGIN - 330, -Kit.MARGIN, -Kit.MARGIN - 96)
	gauge.custom_minimum_size = Vector2(180, 220)
