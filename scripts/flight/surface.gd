extends RefCounted
## The landed craft on the ground, for the screens after a landing (the operation, the report): the lander where it
## touched down (GameState.flight.landing) on NASA's LOLA ground at Shackleton's rim [S-lola], the light of a whole
## lunar day (Shackleton's interior in permanent shadow [S-nasa-science]), the Earth low over the near side, and a
## slow walk of the camera around the lander. The Sun circles the horizon once a lunar day (29.53 days, the synodic
## month [S-nssdc-planets]); place_sun(t) puts it where it is t seconds into the mission.
##   var s := Surface.new(); s.build(world, mission, landing)   ...   s.place_sun(t); s.camera(delta)   ...   s.restore()

const Space := preload("res://scripts/world/space_builder.gd")
const FlightData := preload("res://scripts/flight/flight_data.gd")
const Scene3D := preload("res://scripts/flight/flight_scene.gd")
const Terrain := preload("res://scripts/flight/terrain.gd")
const Descent := preload("res://scripts/flight/descent.gd")

const LUNAR_DAY_S := 29.53 * 86400.0    ## From one sunrise to the next on the Moon [S-nssdc-planets].
const EARTH_DIST := 9000.0              ## Metres to the Earth's globe in the sky (a backdrop: true angular size, not distance).
const EARTH_ANGLE_DEG := 1.9            ## The Earth's width in the Moon's sky [S-nssdc-planets].

var world
var terrain
var lander: Node3D
var sun_az0 := Vector2(-1, -1)
var sun_elev := 1.5
var cam_ang := 0.6
var cam_dist := 15.0
var _old_far := 2000.0
var _old_ambient: Array = []


## Builds the scene on world.stage (cleared first) for the mission and its landing record.
func build(world_, mission, landing: Dictionary) -> void:
	world = world_
	var fl: Dictionary = FlightData.scenario_flight(mission.scenario).landing
	world.cam_free = false
	world.clear_stage()
	var env: Environment = world.world_env.environment
	_old_ambient = [env.ambient_light_source, env.ambient_light_color]
	# the Sun only grazes the ground; an even grey fill shows the lit ground, the baked shadows stay black
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.63, 0.66)
	env.ambient_light_energy = 0.6
	_old_far = world.cam.far
	world.cam.far = 14000.0
	terrain = Terrain.new()
	terrain.setup(fl, true)          # the light of a whole month: what stays dark is permanent shadow
	world.stage.add_child(terrain.build_mesh())
	var az: Array = fl.get("sun_azimuth", [-1.0, -1.0])
	sun_az0 = Vector2(float(az[0]), float(az[1])).normalized()
	sun_elev = float(fl.get("sun_elevation_deg", 1.5))
	world.sun.light_energy = 1.6
	var earth := Space.make_earth(EARTH_DIST * tan(deg_to_rad(EARTH_ANGLE_DEG * 0.5)), false)
	earth.position = terrain.earth_dir * EARTH_DIST
	world.stage.add_child(earth)
	lander = Scene3D.lander(mission, 3.2, Descent.LEG)
	var x := float(landing.get("x", 0.0))
	var z := float(landing.get("z", 0.0))
	lander.position = Vector3(x, terrain.height(x, z) + Descent.LEG, z)
	if landing.get("grade", "") == "rough":
		lander.rotate_object_local(Vector3(1, 0, 0.4).normalized(), deg_to_rad(9.0))
	world.stage.add_child(lander)
	place_sun(0.0)
	camera(0.0)


## The Sun low on the horizon, t seconds into the mission (its azimuth turns once a lunar day).
func place_sun(t: float) -> void:
	var a := sun_az0.rotated(TAU * t / LUNAR_DAY_S)
	var e := deg_to_rad(sun_elev)
	var to_sun := Vector3(a.x * cos(e), sin(e), a.y * cos(e)).normalized()
	world.sun.basis = Basis.looking_at(-to_sun, Vector3.UP)


## A slow walk around the lander at eye height.
func camera(delta: float) -> void:
	cam_ang += delta * 0.09
	var p: Vector3 = lander.position
	var want := p + Vector3(cos(cam_ang) * cam_dist, 0.0, sin(cam_ang) * cam_dist)
	want.y = maxf(terrain.height(want.x, want.z) + 2.2, p.y + 1.2)
	world.cam.position = want
	world.cam.look_at(p + Vector3(0, 0.6, 0), Vector3.UP)


## The mission log says "In orbit" for month 0, as for any mission; a craft that landed says where and how it landed
## (the operation's log and the report read the same events). Safe to call more than once.
static func note_landing(mission, landing: Dictionary) -> void:
	var orbit_title: String = TranslationServer.translate("In orbit at %s") % GameData.ORBITS[mission.orbit].short
	for e in GameState.last_sim.get("events", []):
		if e.month == 0 and e.title == orbit_title:
			e.title = TranslationServer.translate("Landed at Shackleton's rim")
			e.text = TranslationServer.translate("Touchdown at %.1f m/s, %d m from the target. The lander is working.") % [float(landing.get("touchdown_mps", 0.0)), roundi(float(landing.get("target_m", 0.0)))]


## Puts back what build() changed in the shared world (call from the screen's exit()).
func restore() -> void:
	if world == null:
		return
	world.cam.far = _old_far
	var env: Environment = world.world_env.environment
	env.ambient_light_source = _old_ambient[0]
	env.ambient_light_color = _old_ambient[1]
