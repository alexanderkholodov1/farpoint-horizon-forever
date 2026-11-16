extends RefCounted
## 3D pieces of the pilot's flight that the shared builders do not have: the Earth seen from the climb, a puff of
## gas at staging, flying debris, dust. Everything static; each returns a node for the screen to add to world.stage.
## The look of the places themselves (pad, Earth, Moon) stays in scripts/world/space_builder.gd.
##   const Scene3D := preload("res://scripts/flight/flight_scene.gd")

const Space := preload("res://scripts/world/space_builder.gd")
const Ship := preload("res://scripts/world/ship_builder.gd")


## The Earth under a rocket in the climb: a globe of radius r (scene units), turned so that Ecuador is straight below.
## The screen moves it every frame (horizon_place) so the horizon dips as it would at that height.
static func horizon_earth(r: float) -> Node3D:
	var e := Space.make_earth(r, false)
	e.name = "HorizonEarth"
	# Quito, the spaceport, on top; east (where the rocket flies) along the scene's +X, north into the screen, so the
	# ground and its clouds slide under the rocket the way it flies
	var up := Space.latlon_to_vec(-0.2, -78.5).normalized()
	var east := (Space.latlon_to_vec(-0.2, -78.4) - Space.latlon_to_vec(-0.2, -78.6)).normalized()
	east = (east - up * east.dot(up)).normalized()
	var south := east.cross(up)
	var to_planet := Basis(east, up, south)          # scene X, Y, Z in the planet's own frame
	e.set_meta("base", to_planet.transposed())
	e.basis = e.get_meta("base")
	return e


## Places the horizon globe under `at` for a height h (m) over a planet of radius R (m), having flown x m downrange.
static func horizon_place(e: Node3D, at: Vector3, r: float, h: float, R: float, x: float) -> void:
	e.position = at - Vector3(0, r * (R + maxf(h, 0.0)) / R, 0)
	var base: Basis = e.get_meta("base")
	e.basis = Basis(Vector3(0, 0, 1), x / R) * base


## A short white puff of gas (staging, a thruster), at pos, size about `s` units.
static func puff(pos: Vector3, s: float, col := Color(0.92, 0.94, 1.0, 0.8)) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 60
	p.lifetime = 1.4
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(s, s)
	q.material = Space.particle_mat()
	p.mesh = q
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = s * 0.6
	p.initial_velocity_max = s * 2.2
	p.damping_min = s * 0.8
	p.damping_max = s * 1.6
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.8
	var g := Gradient.new()
	g.set_color(0, col)
	g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = g
	p.emitting = true
	return p


## A burst of dark fragments flying out from pos (an explosion's debris), each about `s` units.
static func debris(pos: Vector3, s: float, count := 24) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = count
	p.lifetime = 3.5
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	var b := BoxMesh.new()
	b.size = Vector3(s, s * 0.3, s * 0.6)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.19, 0.18)
	m.metallic = 0.6
	m.roughness = 0.5
	b.material = m
	p.mesh = b
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3(0, -s * 6.0, 0)
	p.initial_velocity_min = s * 6.0
	p.initial_velocity_max = s * 16.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.particle_flag_rotate_y = true
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.4
	p.emitting = true
	return p


## A ring of dust thrown out along the ground around pos (a lander's engine near the surface, or the touchdown).
static func dust_ring(pos: Vector3, s: float, amount := 140) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = 2.2
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(s, s)
	q.material = Space.particle_mat(false)
	p.mesh = q
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = s * 0.6
	p.emission_ring_inner_radius = s * 0.2
	p.emission_ring_height = 0.0
	p.direction = Vector3(1, 0.08, 0)
	p.spread = 180.0
	p.flatness = 0.92
	p.gravity = Vector3.ZERO       # no air: the dust flies straight and does not billow
	p.initial_velocity_min = s * 6.0
	p.initial_velocity_max = s * 14.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 2.0
	var g := Gradient.new()
	g.set_color(0, Color(0.62, 0.6, 0.57, 0.55))
	g.set_color(1, Color(0.5, 0.49, 0.47, 0.0))
	p.color_ramp = g
	p.emitting = false
	return p


## The lander: the team's own craft (Ship.build) riding on a descent stage of our own design: an octagonal deck wrapped
## in gold foil, four splayed legs with footpads, and the engine bell underneath. About `size` metres across; the
## footpads sit Descent.LEG metres below the node's origin. The engine bell's mouth is the child "Nozzle".
static func lander(m, size := 3.2, leg := 1.6) -> Node3D:
	var root := Node3D.new()
	root.name = "Lander"
	var foil := Ship.mli_mat()
	var metal := Ship.mat(Color(0.62, 0.62, 0.64), 0.85, 0.35)
	var dark := Ship.mat(Color(0.16, 0.16, 0.17), 0.6, 0.5)
	var deck := CylinderMesh.new()
	deck.top_radius = size * 0.42
	deck.bottom_radius = size * 0.42
	deck.height = size * 0.32
	deck.radial_segments = 8
	Ship.add_mesh(root, deck, Vector3(0, -leg * 0.25, 0), foil)
	Ship.cyl(root, size * 0.12, size * 0.2, size * 0.26, Vector3(0, -leg * 0.25 - size * 0.27, 0), dark)
	var nozzle := Node3D.new()
	nozzle.name = "Nozzle"
	nozzle.position = Vector3(0, -leg * 0.25 - size * 0.4, 0)
	root.add_child(nozzle)
	for i in 4:
		var a := PI * 0.25 + i * PI * 0.5
		var out := Vector3(cos(a), 0, sin(a))
		var top := out * size * 0.38 + Vector3(0, -leg * 0.15, 0)
		var foot := out * size * 0.78 + Vector3(0, -leg, 0)
		var mid := (top + foot) * 0.5
		var strut := Ship.cyl(root, size * 0.025, size * 0.025, top.distance_to(foot), mid, metal)
		var ay := (foot - top).normalized()           # the strut's own axis runs from the deck to the footpad
		var ax := ay.cross(Vector3.UP).normalized()
		strut.basis = Basis(ax, ay, ax.cross(ay))
		Ship.cyl(root, size * 0.11, size * 0.13, size * 0.03, foot + Vector3(0, size * 0.015, 0), metal)
	var craft := Ship.build(m)
	var r: float = craft.get_meta("radius", 1.0)
	craft.scale = Vector3.ONE * (size * 0.4 / maxf(r, 0.01))
	# the craft sits on the lander's deck on an adapter cone, as a payload on its stage (it floated above it before)
	var deck_top := -leg * 0.25 + size * 0.16
	Ship.cyl(root, size * 0.09, size * 0.24, size * 0.2, Vector3(0, deck_top + size * 0.1, 0), metal)
	Ship.cyl(root, size * 0.25, size * 0.25, size * 0.02, Vector3(0, deck_top + size * 0.01, 0), dark)
	craft.position = Vector3(0, deck_top + size * 0.2, 0)
	root.add_child(craft)
	return root
