extends Node3D
## The 3D world every screen shares: sky, lights, the orbital camera, and the stage (Earth, Moon, orbit, the craft).
## main.gd creates it once and calls update() every frame. A screen picks a ready stage (stage_menu, stage_design,
## stage_orbit, stage_earth) or builds its own on `stage` after clear_stage(), as the launch screen does.
## Builders of the pieces: scripts/world/space_builder.gd (places, rocket) and scripts/world/ship_builder.gd (the craft).

const Mission := preload("res://scripts/core/mission.gd")
const Ship := preload("res://scripts/world/ship_builder.gd")
const Space := preload("res://scripts/world/space_builder.gd")
const CraftView := preload("res://scripts/craft/craft_view.gd")

var world_env: WorldEnvironment
var sun: DirectionalLight3D
var cam: Camera3D

# ---- orbital camera: it circles cam_target at cam_dist; the mouse drags it and the wheel zooms
## False while a screen drives the camera itself (launch): no orbit, no mouse. main.gd resets it on every screen change.
var cam_free := true
var cam_yaw := 0.6
var cam_pitch := -0.25
var cam_dist := 4.0
var cam_dist_goal := 4.0
var cam_target := Vector3.ZERO
var cam_auto := true
var cam_auto_timer := 0.0
var dragging := false
var cam_pitch_max := 1.4    ## How far the drag may tilt the camera (the menu keeps the Earth's poles, where the map pinches, out of view).

# ---- stage: what is shown now; clear_stage() replaces it
var stage: Node3D
var ship: Node3D            ## The craft being designed (stage_design).
var planet: Node3D
var orbit_ship: Node3D      ## The craft circling its orbit (stage_menu, stage_orbit).
var orbit_center := Vector3.ZERO
var orbit_radius := 1.3
var orbit_basis := Basis.IDENTITY
var orbit_angle := 0.0
var orbit_speed := 1.0
## Where the craft really is when its engine could not finish the climb (issue #70): "" on its orbit, "transfer" on
## the ellipse the rocket left it on (GEO), "escape" flying past the Moon. The shape: semi-latus rectum and eccentricity
## of the conic around the body, in its radii (r = p / (1 + e cos angle)).
var orbit_missed := ""
var orbit_p := 1.0
var orbit_e := 0.0
var escape_end := 0.0
var ship_lost := false
var ship_label: Label3D
var cloud_shift := 0.0     ## Drift of the Earth's cloud layer (U of its texture).


func setup() -> void:
	GameState.trace("creando cielo")
	world_env = Space.make_environment()
	add_child(world_env)
	GameState.trace("cielo listo")
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, -60, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20, 120, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.6, 0.75, 1.0)
	add_child(fill)
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 2000.0
	add_child(cam)
	cam.make_current()


## Called by main.gd every frame, before the screen's process().
func update(delta: float) -> void:
	_update_camera(delta)
	_animate_world(delta)


# ===================================================================================== CAMERA AND INPUT
func _update_camera(delta: float) -> void:
	if not dragging:
		cam_auto_timer -= delta
		if cam_auto and cam_auto_timer <= 0.0:
			cam_yaw += delta * 0.12
	cam_dist = lerp(cam_dist, cam_dist_goal, clamp(delta * 3.0, 0.0, 1.0))
	if not cam_free:
		return
	var off := Vector3(cos(cam_pitch) * sin(cam_yaw), -sin(cam_pitch), cos(cam_pitch) * cos(cam_yaw)) * cam_dist
	cam.position = cam_target + off
	cam.look_at(cam_target, Vector3.UP)


var touches := {}          ## Fingers on the screen (index -> position), for the two-finger pinch (issue #76).


func _unhandled_input(event: InputEvent) -> void:
	if not cam_free:
		return
	# two fingers pinch to zoom; one finger drags the camera through the mouse emulation, as the mouse does
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
		return
	if event is InputEventScreenDrag and touches.size() == 2 and touches.has(event.index):
		var keys: Array = touches.keys()
		var other: Vector2 = touches[keys[0] if keys[1] == event.index else keys[1]]
		var before: float = (touches[event.index] as Vector2).distance_to(other)
		var after: float = event.position.distance_to(other)
		touches[event.index] = event.position
		if before > 10.0:
			cam_dist_goal = clampf(cam_dist_goal * before / maxf(after, 1.0), 0.6, 300.0)
		dragging = false
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
			cam_auto_timer = 4.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cam_dist_goal = max(0.6, cam_dist_goal * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam_dist_goal = min(300.0, cam_dist_goal * 1.1)
	elif event is InputEventMouseMotion and dragging:
		# a release over a button or a panel goes to the interface and never reaches here (issue #65): a motion with
		# no button held means the drag is over
		if event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT) == 0:
			dragging = false
			return
		cam_yaw -= event.relative.x * 0.006
		cam_pitch = clamp(cam_pitch + event.relative.y * 0.005, -cam_pitch_max, cam_pitch_max)


## Points the camera's yaw from the sun's side, plus `extra` radians.
func face_sun(extra := 0.8) -> void:
	var sd: Vector3 = sun.global_transform.basis.z
	cam_yaw = atan2(sd.x, sd.z) + extra


func _animate_world(delta: float) -> void:
	# the Sun's direction for the night side of the Earth, and the slow drift of its clouds
	# about 50 m/s along the parallels, a strong high-altitude wind (our value), as a share of the Earth's 40,075 km
	# equator (2 pi x 6,378 km [S-nssdc-planets]); it used to be 0.12 % of the globe a second, some 48 km/s
	cloud_shift = fmod(cloud_shift + delta * 50.0 / 40075000.0, 1.0)
	var sd: Vector3 = sun.global_transform.basis.z
	for m in get_tree().get_nodes_in_group(Space.SUN_LIT):
		var mat := (m as MeshInstance3D).material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("sun_dir", sd)
			mat.set_shader_parameter("cloud_shift", cloud_shift)
	if planet and is_instance_valid(planet):
		var surf: Node3D = planet.get_node_or_null("Surface")
		if surf:
			surf.rotate_y(delta * 0.03)
		var mk: Node3D = planet.get_node_or_null("Surface/Ecuador")
		if mk:
			var outward: Vector3 = mk.global_position - planet.global_position
			mk.get_node("Label").visible = outward.dot(cam.global_position - mk.global_position) > 0.0
		var pulse: Node3D = planet.get_node_or_null("Surface/Ecuador/Pulse")
		if pulse:
			var k := 1.0 + 0.6 * fmod(Time.get_ticks_msec() / 1000.0, 1.5)
			pulse.scale = Vector3.ONE * k
	if orbit_ship and is_instance_valid(orbit_ship) and not ship_lost:
		var rr := orbit_radius
		if orbit_missed != "":
			# Kepler's second law: the craft sweeps the conic faster near the body, slower far out
			var k := 1.0 + orbit_e * cos(orbit_angle)
			if orbit_missed == "transfer":
				orbit_angle += delta * orbit_speed * k * k / pow(1.0 - orbit_e * orbit_e, 1.5)
			else:
				orbit_angle = minf(orbit_angle + delta * maxf(orbit_speed, 0.3) * k * k * 0.6, escape_end)
			rr = orbit_p / (1.0 + orbit_e * cos(orbit_angle))
		else:
			orbit_angle += delta * orbit_speed
		var p := orbit_basis * Vector3(cos(orbit_angle), 0, sin(orbit_angle)) * rr
		var tangent := orbit_basis * Vector3(-sin(orbit_angle), 0, cos(orbit_angle))
		orbit_ship.position = orbit_center + p
		orbit_ship.look_at(orbit_ship.position + tangent, (orbit_basis * Vector3.UP))
		if ship_label and is_instance_valid(ship_label):
			ship_label.position = orbit_ship.position + Vector3(0, 0.12, 0)


# ===================================================================================== STAGES
## Empties the stage and restores the space sky and light.
func clear_stage() -> void:
	if stage and is_instance_valid(stage):
		stage.queue_free()
	stage = Node3D.new()
	add_child(stage)
	ship = null
	planet = null
	orbit_ship = null
	ship_label = null
	ship_lost = false
	cam.h_offset = 0.0
	cam_pitch_max = 1.4
	world_env.environment.sky = Space.make_space_sky()
	world_env.environment.ambient_light_energy = 0.35
	world_env.environment.fog_enabled = false
	world_env.environment.tonemap_exposure = 1.0
	cam.far = 2000.0
	sun.rotation_degrees = Vector3(-30, -60, 0)


## The menu: the Earth on the right with a demo craft circling it.
func stage_menu() -> void:
	clear_stage()
	GameState.trace("creando Tierra")
	planet = Space.make_earth(1.0)
	stage.add_child(planet)
	GameState.trace("Tierra lista")
	var demo = Mission.new()
	demo.from_dict({"bus": "small", "instruments": ["cam_ms", "ir_adv"], "panels": "dep_m", "comms": "xband", "adcs": "rw", "propulsion": "cold"})
	setup_orbit_ship(demo, Vector3.ZERO, 1.35, 98.0, 0.1)
	ship_label.visible = false
	cam_auto = false
	cam_yaw = 0.0
	cam_pitch = -0.12
	cam_dist_goal = 3.6
	cam_dist = 3.6
	# the camera circles the Earth's own centre, so dragging turns the planet in place; the lens is shifted so the
	# Earth sits right of the menu (an off-centre target made the planet swing across the screen when dragged)
	cam_target = Vector3(0, 0.05, 0)
	cam.h_offset = -1.25
	cam_pitch_max = 0.5


## Puts the craft of mission m on a circular orbit (ring, craft, tr("YOUR CRAFT") label); _animate_world moves it.
func setup_orbit_ship(m, center: Vector3, radius: float, incl: float, ship_size: float, nodes_yaw := 0.0) -> void:
	orbit_center = center
	orbit_radius = radius
	var ring := Space.make_orbit_ring(maxf(radius, 0.01), incl, Color(0.4, 0.8, 1.0, 0.45), nodes_yaw)
	ring.position = center
	stage.add_child(ring)
	ring.visible = radius > 0.0
	orbit_basis = ring.basis
	orbit_ship = Ship.build(m)
	var r: float = orbit_ship.get_meta("radius")
	orbit_ship.scale = Vector3.ONE * (ship_size / r)
	stage.add_child(orbit_ship)
	ship_label = Space.make_label(tr("YOUR CRAFT"), Color(0.55, 0.9, 1.0))
	stage.add_child(ship_label)
	orbit_speed = 0.35


## The craft where it really is when its engine could not finish the climb (issue #70), drawn as a conic around the
## body at true scale: for GEO the transfer ellipse the rocket left it on, perigee at a 200 km parking orbit and apogee
## at GEO (Earth's radius 6,371 km [S8]); for the Moon a fly-by that bends round it and leaves (an escape hyperbola,
## eccentricity 1.4: our simplification of "too fast to be held").
func _stage_missed(mission, O: Dictionary, nodes: float, ship_size: float) -> void:
	var color := Color(1.0, 0.66, 0.26, 0.55)   # amber: not the orbit that was planned
	if mission.orbit == "geo":
		planet = Space.make_earth(1.0)
		stage.add_child(planet)
		var rp := 1.0 + 200.0 / 6371.0
		var ra: float = O.radius
		orbit_e = -(ra - rp) / (ra + rp)   # negative: the apogee lies toward the open side of the screen, away from the log
		orbit_p = 2.0 * rp * ra / (rp + ra)
		orbit_missed = "transfer"
		ship_size = 0.2
		cam_dist_goal = ra * 2.0
	else:
		planet = Space.make_moon(1.0)
		stage.add_child(planet)
		var earth := Space.make_earth(1.4, false)
		earth.position = Vector3(-30, 6, -40)
		stage.add_child(earth)
		orbit_e = 1.4
		orbit_p = float(O.radius) * (1.0 + orbit_e)
		orbit_missed = "escape"
		cam_dist_goal = 9.0
	setup_orbit_ship(mission, Vector3.ZERO, 0.0, O.incl, ship_size, nodes)
	# the planned orbit, faint; the real path, amber
	var planned := Space.make_orbit_ring(O.radius, O.incl, Color(0.4, 0.8, 1.0, 0.18), nodes)
	stage.add_child(planned)
	var lim := PI if orbit_missed == "transfer" else acos(-1.0 / orbit_e) * 0.9   # the escape's e is positive
	escape_end = lim
	var path := ImmediateMesh.new()
	path.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 241:
		var a := -lim + 2.0 * lim * i / 240.0
		var r := orbit_p / (1.0 + orbit_e * cos(a))
		path.surface_add_vertex(orbit_basis * Vector3(cos(a), 0, sin(a)) * r)
	path.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	mi.mesh = path
	mi.material_override = mat
	stage.add_child(mi)
	orbit_angle = -lim if orbit_missed == "escape" else 0.0
	orbit_speed = 0.4
	cam_target = Vector3.ZERO
	if orbit_missed == "transfer":
		# the view centres on the whole ellipse (its centre lies a*e from the Earth, toward the apogee), not on the Earth
		var a_axis := orbit_p / (1.0 - orbit_e * orbit_e)
		cam_target = orbit_basis * Vector3(-a_axis * orbit_e, 0, 0)
		cam_dist_goal = a_axis * 3.3
	cam_dist = cam_dist_goal
	cam_auto = true
	cam_pitch = -0.3
	face_sun()


## The design: GameState's craft up close, above the Earth or the Moon.
func stage_design() -> void:
	clear_stage()
	var mission = GameState.mission
	var body: String = GameData.SCENARIOS[mission.scenario].body
	if mission.orbit == "lunar":
		body = "luna"
	if body == "luna":
		planet = Space.make_moon(30.0)
	else:
		planet = Space.make_earth(30.0, false)
	planet.position = Vector3(0, -38, -14)
	stage.add_child(planet)
	cam_auto = true
	cam_pitch = -0.22
	cam_target = Vector3(0, 0, 0)
	face_sun(0.5)
	rebuild_ship()


## Rebuilds the designed craft from GameState's mission (after a part changes).
func rebuild_ship() -> void:
	var old_keys: Array = []
	if ship and is_instance_valid(ship):
		old_keys = ship.get_meta("part_keys", [])
		ship.queue_free()
	ship = Ship.build(GameState.mission)
	stage.add_child(ship)
	# the new part snaps on, and the part a problem comes from glows (C1, scripts/craft/craft_view.gd)
	CraftView.refresh(ship, old_keys, GameState.mission, GameState.mission.compute())
	var r: float = ship.get_meta("radius")
	cam_dist_goal = r * 2.6 + 0.9


## The operation: GameState's craft on its orbit around the Earth, the Moon, or at L2.
func stage_orbit() -> void:
	clear_stage()
	var mission = GameState.mission
	var O: Dictionary = GameData.ORBITS[mission.orbit]
	var ship_size := 0.11
	# The orbit's line of nodes runs obliquely across the first view (about 55 degrees from the line of sight), so an
	# inclined orbit opens towards the player and passes in front of the planet, instead of showing edge-on as a stroke
	# (issue #64: a polar orbit looked like a line off to one side) or face-on as a halo at the limb.
	# Where the nodes lie in reality depends on the hour of launch; the game does not model it, so it picks the view.
	face_sun()
	var nodes := cam_yaw + PI / 2.0 - 0.6
	orbit_missed = ""
	orbit_e = 0.0
	var missed: bool = not bool(GameState.last_report.get("insertion_ok", true))
	if missed and mission.orbit in ["geo", "lunar"]:
		_stage_missed(mission, O, nodes, ship_size)
		return
	if mission.orbit == "lunar":
		planet = Space.make_moon(1.0)
		stage.add_child(planet)
		var earth := Space.make_earth(1.4, false)
		earth.position = Vector3(-30, 6, -40)
		stage.add_child(earth)
		setup_orbit_ship(mission, Vector3.ZERO, O.radius, O.incl, ship_size, nodes)
		cam_target = Vector3.ZERO
		cam_dist_goal = 4.2
	elif mission.orbit == "l2":
		# at true scale, in Earth radii (6,371 km [S8]): L2 1.5 million km from the Earth on the side away from the Sun
		# (235 radii), the halo orbit around it "similar in size to the Moon's orbit around the Earth" (60 radii), one lap
		# in about 6 months [S-webb-orbit]; the Moon's own orbit drawn faint for comparison. The Earth is too small to see
		# from here, so its label marks it (issue #88: L2 was drawn 5.5 radii out, its halo edge-on)
		planet = Space.make_earth(1.0)
		stage.add_child(planet)
		var sun_dir := sun.global_transform.basis.z
		sun_dir.y = 0.0
		sun_dir = sun_dir.normalized()
		var l2: Vector3 = -sun_dir * 235.4
		var across := sun_dir.cross(Vector3.UP).normalized()
		var halo_nodes := atan2(across.x, across.z)   # the halo stands across the Sun-Earth line
		setup_orbit_ship(mission, l2, 60.3, 90.0, 0.9, halo_nodes)
		var moon_ring := Space.make_orbit_ring(60.3, 0.0, Color(1, 1, 1, 0.14))
		stage.add_child(moon_ring)
		var el := Space.make_label(tr("Earth"), Color(0.55, 0.8, 1.0))
		el.position = Vector3(0, 14, 0)
		stage.add_child(el)
		var ml := Space.make_label(tr("The Moon's orbit"), Color(1, 1, 1, 0.6))
		ml.position = -sun_dir * 60.3 + Vector3(0, -6, 0)   # on the ring toward L2, clear of the Earth label and the log
		stage.add_child(ml)
		var l2l := Space.make_label(tr("L2 point · 1.5 million km"), Color(0.85, 0.75, 1.0))
		l2l.position = l2 + Vector3(0, -8, 0)
		stage.add_child(l2l)
		var line := ImmediateMesh.new()
		line.surface_begin(Mesh.PRIMITIVE_LINES)
		line.surface_add_vertex(Vector3.ZERO)
		line.surface_add_vertex(l2)
		line.surface_end()
		var lm := StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.albedo_color = Color(1, 1, 1, 0.12)
		lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var li := MeshInstance3D.new()
		li.mesh = line
		li.material_override = lm
		stage.add_child(li)
		cam_target = l2 * 0.55
		cam_dist_goal = 430.0
	else:
		planet = Space.make_earth(1.0)
		stage.add_child(planet)
		if mission.orbit == "geo":
			ship_size = 0.2
		setup_orbit_ship(mission, Vector3.ZERO, O.radius, O.incl, ship_size, nodes)
		cam_target = Vector3.ZERO
		# a low orbit hugs the planet; GEO, at its true 6.6 Earth radii, needs the camera far enough to hold it all
		cam_dist_goal = 4.2 if O.radius < 2.0 else O.radius * 2.3
	orbit_speed = {"leo": 0.5, "sso": 0.45, "geo": 0.12, "lunar": 0.45, "l2": 0.6}.get(mission.orbit, 0.4)
	cam_dist = cam_dist_goal
	cam_auto = true
	cam_pitch = -0.3
	face_sun()
	if mission.orbit == "l2":
		cam_auto = false
		cam_pitch = -0.45
		face_sun(PI * 0.72)   # from the night side and above: the Earth, the line to L2 and the halo open as an ellipse


## The Earth alone (the report after a launch failure).
func stage_earth() -> void:
	clear_stage()
	planet = Space.make_earth(1.0)
	stage.add_child(planet)
	cam_target = Vector3.ZERO
	cam_dist_goal = 3.4
	cam_auto = true
	face_sun()


## The orbiting craft is lost: it falls (low orbits) and vanishes.
func lose_ship() -> void:
	if orbit_ship == null or ship_lost:
		return
	ship_lost = true
	var tw := create_tween()
	if GameState.mission.orbit == "leo" or GameState.mission.orbit == "sso":
		tw.tween_property(orbit_ship, "position", orbit_ship.position * 0.98, 1.5)
	tw.tween_property(orbit_ship, "scale", Vector3.ONE * 0.0001, 0.6)
