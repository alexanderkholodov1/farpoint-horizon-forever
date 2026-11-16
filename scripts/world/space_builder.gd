extends RefCounted
## Construye los escenarios 3D: cielo estrellado, Tierra, Luna, órbitas, cohete y plataforma de lanzamiento.

const EARTH_SHADER := preload("res://assets/shaders/earth.gdshader")
const CLOUD_SHADER := preload("res://assets/shaders/clouds.gdshader")
const ATMO_SHADER := preload("res://assets/shaders/atmosphere.gdshader")
const MOON_SHADER := preload("res://assets/shaders/moon.gdshader")
const SKY_SHADER := preload("res://assets/shaders/sky.gdshader")
const GLOW := preload("res://assets/shaders/engine_glow.gdshader")
const PARTICLE_SHADER := preload("res://assets/shaders/particle.gdshader")
## NASA textures, made by assets/source/planet_textures.py [S-gibs] [S-moon-kit].
const EARTH_DAY := preload("res://assets/textures/earth_day.jpg")
const EARTH_NIGHT := preload("res://assets/textures/earth_night.jpg")
const EARTH_RELIEF := preload("res://assets/textures/earth_relief.jpg")
const EARTH_CLOUDS := preload("res://assets/textures/earth_clouds.jpg")
const EARTH_REGION_DAY := preload("res://assets/textures/earth_region_day.jpg")
const EARTH_REGION_RELIEF := preload("res://assets/textures/earth_region_relief.jpg")
const EARTH_REGION_CLOUDS := preload("res://assets/textures/earth_region_clouds.jpg")
## Where those cover the globe, in its UV (u0, v0, u1, v1): 92-68 W, 12 N-12 S (planet_textures.py REGION_LONLAT).
## The sharp region: 92 W to 44 W, 12 S to 12 N, east along the launch track (assets/source/planet_textures.py).
const REGION_RECT := Vector4((180.0 - 92.0) / 360.0, (90.0 - 12.0) / 180.0, (180.0 - 44.0) / 360.0, (90.0 + 12.0) / 180.0)
const MOON_COLOR := preload("res://assets/textures/moon_color.jpg")
const MOON_NORMAL := preload("res://assets/textures/moon_normal.jpg")
## Materials in this group get the Sun's direction ("sun_dir") from World every frame, for the night side.
const SUN_LIT := "sun_lit"
const Ship := preload("res://scripts/world/ship_builder.gd")
const RocketDesign := preload("res://scripts/craft/rocket_design.gd")
const FONT := preload("res://assets/fonts/Inter-SemiBold.otf")


static func make_space_sky() -> Sky:
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = SKY_SHADER
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	return sky


static func make_day_sky() -> Sky:
	var sky := Sky.new()
	var p := ProceduralSkyMaterial.new()
	p.sky_top_color = Color(0.12, 0.3, 0.66)
	p.sky_horizon_color = Color(0.68, 0.76, 0.86)
	p.sky_curve = 0.12
	p.ground_bottom_color = Color(0.3, 0.3, 0.26)
	p.ground_horizon_color = Color(0.68, 0.76, 0.86)
	sky.sky_material = p
	return sky


static func make_environment() -> WorldEnvironment:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = make_space_sky()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.3, 0.42)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	we.environment = env
	return we


## Posición sobre una esfera (radio 1) con la misma convención de UV que SphereMesh de Godot.
static func latlon_to_vec(lat_deg: float, lon_deg: float) -> Vector3:
	var u := (lon_deg + 180.0) / 360.0
	var lat := deg_to_rad(lat_deg)
	return Vector3(sin(u * TAU) * cos(lat), sin(lat), cos(u * TAU) * cos(lat))


static func make_earth(radius := 1.0, with_marker := true) -> Node3D:
	var root := Node3D.new()
	root.name = "Earth"
	var surface := Node3D.new()
	surface.name = "Surface"
	root.add_child(surface)
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 128
	s.rings = 64
	var em := ShaderMaterial.new()
	em.shader = EARTH_SHADER
	em.set_shader_parameter("day_tex", EARTH_DAY)
	em.set_shader_parameter("night_tex", EARTH_NIGHT)
	em.set_shader_parameter("relief_tex", EARTH_RELIEF)
	em.set_shader_parameter("cloud_tex", EARTH_CLOUDS)
	em.set_shader_parameter("region_day", EARTH_REGION_DAY)
	em.set_shader_parameter("region_relief", EARTH_REGION_RELIEF)
	em.set_shader_parameter("region_clouds", EARTH_REGION_CLOUDS)
	em.set_shader_parameter("region_rect", REGION_RECT)
	Ship.add_mesh(surface, s, Vector3.ZERO, em).add_to_group(SUN_LIT)
	# nubes
	var cs := SphereMesh.new()
	cs.radius = radius * 1.012
	cs.height = radius * 2.024
	cs.radial_segments = 96
	cs.rings = 48
	var cm := ShaderMaterial.new()
	cm.shader = CLOUD_SHADER
	cm.set_shader_parameter("cloud_tex", EARTH_CLOUDS)
	cm.set_shader_parameter("region_clouds", EARTH_REGION_CLOUDS)
	cm.set_shader_parameter("region_rect", REGION_RECT)
	var cl := Ship.add_mesh(surface, cs, Vector3.ZERO, cm)
	cl.name = "Clouds"
	cl.add_to_group(SUN_LIT)
	# the air: about 100 km thick (1.6 % of the radius), drawn at 3.5 % so it reads at game size
	const ATMO_K := 1.035
	var as_ := SphereMesh.new()
	as_.radius = radius * ATMO_K
	as_.height = radius * 2.0 * ATMO_K
	as_.radial_segments = 128
	as_.rings = 64
	var am := ShaderMaterial.new()
	am.shader = ATMO_SHADER
	am.set_shader_parameter("inner", 1.0 / ATMO_K)
	Ship.add_mesh(root, as_, Vector3.ZERO, am).add_to_group(SUN_LIT)
	# marcador de Ecuador (Quito: -0.2°, -78.5°)
	if with_marker:
		var mk := Node3D.new()
		mk.name = "Ecuador"
		mk.position = latlon_to_vec(-1.5, -78.5) * radius * 1.004
		surface.add_child(mk)
		var dot := Ship.add_mesh(mk, Ship._sphere(radius * 0.018), Vector3.ZERO, Ship.mat(Color(1, 0.85, 0.2), 0.0, 0.5, Color(1.0, 0.7, 0.1)))
		dot.name = "Dot"
		var ring := TorusMesh.new()
		ring.inner_radius = radius * 0.022
		ring.outer_radius = radius * 0.027
		var rm := Ship.add_mesh(mk, ring, Vector3.ZERO, Ship.mat(Color(1, 0.8, 0.2), 0.0, 0.5, Color(1.0, 0.6, 0.1)))
		rm.name = "Pulse"
		mk.basis = Basis(Quaternion(Vector3.UP, mk.position.normalized()))
		var el := make_label("Ecuador", Color(1, 0.85, 0.35))
		el.name = "Label"
		el.position = Vector3(0, radius * 0.09, 0)
		mk.add_child(el)
	return root


static func make_moon(radius := 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Moon"
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 128
	s.rings = 64
	var mm := ShaderMaterial.new()
	mm.shader = MOON_SHADER
	mm.set_shader_parameter("color_tex", MOON_COLOR)
	mm.set_shader_parameter("normal_tex", MOON_NORMAL)
	Ship.add_mesh(root, s, Vector3.ZERO, mm).name = "Surface"
	return root


## A circular orbit of `radius` (in body radii) tilted `incl_deg` from the equator. `nodes_yaw` (radians) turns its line
## of nodes, where it crosses the equator, about the body's axis: a ring seen along that line is a flat stroke.
static func make_orbit_ring(radius: float, incl_deg: float, color: Color, nodes_yaw := 0.0) -> Node3D:
	var pivot := Node3D.new()
	# Godot applies Z (the tilt, about the line of nodes, which starts on +Z) before Y (where that line points)
	pivot.rotation = Vector3(0, nodes_yaw, deg_to_rad(incl_deg if incl_deg <= 90.0 else 180.0 - incl_deg))
	var t := TorusMesh.new()
	# a wider orbit is seen from farther away, so its line grows with it to keep the same width on screen
	var half := 0.004 * maxf(1.0, radius / 1.2)
	t.inner_radius = radius - half
	t.outer_radius = radius + half
	t.rings = 128
	t.ring_segments = 6
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	Ship.add_mesh(pivot, t, Vector3.ZERO, m)
	return pivot


## The material of every particle effect: a soft round puff tinted by each particle's colour (assets/shaders/particle.gdshader,
## which also hides the black discs GL Compatibility draws for particles not yet emitted). Made once and shared.
static var _particle_mat: ShaderMaterial
static func particle_mat(_unshaded := true) -> ShaderMaterial:
	if _particle_mat == null:
		var gt := GradientTexture2D.new()
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		var gg := Gradient.new()
		gg.set_color(0, Color(1, 1, 1, 1))
		gg.set_color(1, Color(1, 1, 1, 0))
		gg.add_point(0.5, Color(1, 1, 1, 0.55))
		gt.gradient = gg
		_particle_mat = ShaderMaterial.new()
		_particle_mat.shader = PARTICLE_SHADER
		_particle_mat.set_shader_parameter("puff", gt)
	return _particle_mat


static func make_label(text: String, color: Color, depth_test := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = FONT
	l.font_size = 30
	l.outline_size = 16
	l.outline_modulate = Color(0.0, 0.01, 0.04, 0.95)   # readable over clouds, the Moon's bright ground and the pad
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0006
	l.no_depth_test = not depth_test
	return l


static func make_flame(scale: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Flame"
	p.amount = 160
	p.lifetime = 0.9
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5) * scale
	q.material = particle_mat()
	p.mesh = q
	p.direction = Vector3(0, -1, 0)
	p.spread = 10.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 7.0 * scale
	p.initial_velocity_max = 10.0 * scale
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.5))
	sc.add_point(Vector2(0.3, 1.2))
	sc.add_point(Vector2(1, 3.0))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	g.set_color(1, Color(0.5, 0.5, 0.52, 0.0))
	g.add_point(0.15, Color(1.0, 0.6, 0.15, 1.0))
	g.add_point(0.4, Color(0.75, 0.72, 0.7, 0.6))
	p.color_ramp = g
	p.emitting = false
	return p


## An engine's flame where there is no air: a short, bright jet that stays with the craft and leaves no smoke
## (smoke is exhaust slowed and cooled by air; in vacuum the gas just spreads and vanishes).
static func make_vacuum_flame(scale: float) -> CPUParticles3D:
	var p := make_flame(scale)
	p.local_coords = true
	p.amount = 90
	p.lifetime = 0.32
	p.spread = 7.0
	p.initial_velocity_min = 11.0 * scale
	p.initial_velocity_max = 15.0 * scale
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.7))
	sc.add_point(Vector2(1, 1.7))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.97, 0.85, 0.95))
	g.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	g.add_point(0.3, Color(1.0, 0.72, 0.3, 0.7))
	p.color_ramp = g
	return p


## The ground cloud at ignition: steam from the sound suppression water and exhaust pushed out along the pad,
## billowing wide and slowly, as in launch footage. Unshaded and casting no shadow: a cloud has no hard silhouette.
static func make_pad_smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "PadSmoke"
	p.amount = 160
	p.lifetime = 4.5
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	q.material = particle_mat()
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4
	# most of it leaves along the flame trench (+X), the rest rolls out over the pad
	p.direction = Vector3(1, 0.25, 0)
	p.spread = 110.0
	p.flatness = 0.7
	p.gravity = Vector3(0, 0.25, 0)
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.5
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.5))
	sc.add_point(Vector2(0.5, 1.5))
	sc.add_point(Vector2(1, 2.4))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.75, 0.0))
	g.add_point(0.1, Color(0.95, 0.94, 0.92, 0.8))
	g.add_point(0.6, Color(0.88, 0.88, 0.87, 0.5))
	g.set_color(g.get_point_count() - 1, Color(0.85, 0.85, 0.85, 0.0))
	p.color_ramp = g
	p.emitting = false
	return p


## A launcher breaking up in flight: a fireball that burns out to black smoke, the smoke cloud that lingers and
## grows, and burning pieces arcing down. Three one-shot emitters; the caller starts them.
static func make_explosion() -> Node3D:
	var root := Node3D.new()
	root.name = "Explosion"
	# fireball: dense, fast, damped, white-hot to orange to soot
	var fire := _burst("Fire", 110, 1.8, 1.0, Vector2(2.0, 2.0), 3.0, 9.0, 5.0)
	var fg := Gradient.new()
	fg.set_color(0, Color(1.0, 0.97, 0.85, 0.95))
	fg.add_point(0.12, Color(1.0, 0.75, 0.3, 0.85))
	fg.add_point(0.35, Color(0.85, 0.32, 0.08, 0.75))
	fg.add_point(0.6, Color(0.22, 0.17, 0.14, 0.7))
	fg.set_color(fg.get_point_count() - 1, Color(0.1, 0.1, 0.1, 0.0))
	fire.color_ramp = fg
	root.add_child(fire)
	# smoke: slower, larger, rising, lingering
	var smoke := _burst("Smoke", 70, 5.0, 1.0, Vector2(3.2, 3.2), 1.5, 4.0, 1.2)
	smoke.gravity = Vector3(0, 0.6, 0)
	var sg := Gradient.new()
	sg.set_color(0, Color(0.5, 0.46, 0.42, 0.0))
	sg.add_point(0.2, Color(0.46, 0.43, 0.4, 0.55))
	sg.add_point(0.6, Color(0.58, 0.57, 0.56, 0.45))
	sg.set_color(sg.get_point_count() - 1, Color(0.6, 0.6, 0.6, 0.0))
	smoke.color_ramp = sg
	root.add_child(smoke)
	# debris: small burning pieces falling in arcs
	var debris := _burst("Debris", 46, 3.2, 1.0, Vector2(0.25, 0.25), 6.0, 13.0, 0.3)
	debris.gravity = Vector3(0, -9.0, 0)
	debris.scale_amount_curve = null
	var dg := Gradient.new()
	dg.set_color(0, Color(1.0, 0.85, 0.5, 1.0))
	dg.add_point(0.3, Color(1.0, 0.5, 0.15, 1.0))
	dg.set_color(dg.get_point_count() - 1, Color(0.25, 0.2, 0.18, 0.0))
	debris.color_ramp = dg
	root.add_child(debris)
	return root


static func _burst(nm: String, amount: int, life: float, explosive: float, size: Vector2, v0: float, v1: float, damp: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = nm
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = explosive
	p.lifetime_randomness = 0.55  # so the puffs age apart and the cloud has depth instead of one flat colour
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := QuadMesh.new()
	q.size = size
	q.material = particle_mat(true)
	p.mesh = q
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.damping_min = damp
	p.damping_max = damp * 1.5
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.4
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.6))
	sc.add_point(Vector2(0.3, 1.5))
	sc.add_point(Vector2(1, 2.6))
	p.scale_amount_curve = sc
	p.emitting = false
	return p


## Modeled launchers (assets/source/launchers.py): which model each launcher flies on, and each model's real height
## in metres and the centre-to-centre offset of its side boosters, as printed by that script.
const LAUNCHER_MODEL := {"ride": "medium", "light": "light", "medium": "medium", "heavy": "heavy"}
const LAUNCHER_MODEL_INFO := {
	"light": {"height": 17.9, "boosters": 0.0},
	"medium": {"height": 70.9, "boosters": 0.0},
	"heavy": {"height": 70.9, "boosters": 4.25},
}


## The launcher on the pad: its model, scaled to the size the launch screen frames (4.8 x the launcher's `height`),
## with a `Flames` child for every engine cluster and the `height` meta. Origin at the base of the first stage.
static func make_rocket(launcher_id: String) -> Node3D:
	if launcher_id == RocketDesign.CUSTOM and RocketDesign.current != null:
		return make_custom_rocket(RocketDesign.current)
	var root := Node3D.new()
	root.name = "Rocket"
	var L: Dictionary = GameData.LAUNCHERS[launcher_id]
	var h: float = L.height
	if launcher_id == "ride":  # rideshare flies on a medium launcher, as before
		h = 1.3
	var key: String = LAUNCHER_MODEL[launcher_id]
	var info: Dictionary = LAUNCHER_MODEL_INFO[key]
	var total := 4.8 * h
	var k: float = total / float(info.height)
	var model: Node3D = load("res://assets/models/launcher_%s.glb" % key).instantiate()
	model.name = "Model"
	model.scale = Vector3.ONE * k
	root.add_child(model)
	var flames := Node3D.new()
	flames.name = "Flames"
	root.add_child(flames)
	var r := 0.16 * h
	var f := make_flame(h)
	f.position = Vector3(0, -0.2 * h, 0)
	flames.add_child(f)
	var gm := ShaderMaterial.new()
	gm.shader = GLOW
	var plume := Ship.cyl(flames, r * 0.7, r * 0.35, 1.2 * h, Vector3(0, -0.8 * h, 0), gm)
	plume.name = "Plume"
	if float(info.boosters) > 0.0:
		for sx in [-1, 1]:
			var fb := make_flame(h)
			fb.position = Vector3(sx * float(info.boosters) * k, -0.2 * h, 0)
			flames.add_child(fb)
	root.set_meta("height", total)
	return root


## The rocket the player assembled (RocketDesign), at the launch screen's scale (0.088 units per metre, the scale of
## the catalog launchers), with Flames under its first stage, flames under each booster, and the meta "height" and
## "stage1_y" (where the second stage's engine fires after separation).
static func make_custom_rocket(design) -> Node3D:
	var root := Node3D.new()
	root.name = "Rocket"
	var k := 0.088
	var asm: Node3D = design.build_model()
	asm.scale = Vector3.ONE * k
	root.add_child(asm)
	var core_r: float = RocketDesign.part(design.stack[0]).family / 2.0
	var h := 1.3 * core_r / 1.85
	var flames := Node3D.new()
	flames.name = "Flames"
	root.add_child(flames)
	var f := make_flame(h)
	f.position = Vector3(0, -0.25, 0)
	flames.add_child(f)
	var gm := ShaderMaterial.new()
	gm.shader = GLOW
	var plume := Ship.cyl(flames, core_r * k * 0.9, core_r * k * 0.45, 1.2 * h, Vector3(0, -0.25 - 0.6 * h, 0), gm)
	plume.name = "Plume"
	var boosters := asm.get_node_or_null("Boosters") as Node3D
	if boosters:
		for b in boosters.get_children():
			var fb := make_flame(h)
			fb.position = Vector3(b.position.x * k, b.position.y * k - 0.1, 0)
			fb.name = "BoosterFlame%d" % flames.get_child_count()
			fb.set_meta("booster", true)
			flames.add_child(fb)
	# where the second stage starts: the top of the first stage
	var st: Array = design.stages()
	var y1 := 0.0
	for id in st[0]:
		y1 += RocketDesign._part_height(id)
	root.set_meta("stage1_y", y1 * k)
	root.set_meta("height", design.height_m() * k)
	return root


## The launch site among the Andes: the modeled pad, tower and pad buildings (assets/models/launch_site.glb, in metres)
## on the real relief around Cotopaxi (assets/textures/terrain_cotopaxi.png, NASA SRTM [S-terrain-tiles]), both at the
## launch screen's scale. The rocket stands on the mount at PAD_TOP.
const SITE := preload("res://assets/models/launch_site.glb")
const TERRAIN_HM := preload("res://assets/textures/terrain_cotopaxi.png")
const TERRAIN_SHADER := preload("res://assets/shaders/terrain.gdshader")
const SITE_K := 0.088                 ## Game units per metre, as the builder and the rockets.
const PAD_TOP := 2.4 * SITE_K         ## Top of the launch mount (launch_site.py MOUNT_H).
const TERRAIN_CELL_M := 191.0         ## Metres between heightmap samples (terrain_cotopaxi.py).
const TERRAIN_PAD := Vector2i(116, 176)   ## The pad's sample (column, row).
const TERRAIN_YAW := 50.0             ## Turns the map so Cotopaxi rises beside the rocket in the launch camera.
static var _terrain_mesh: ArrayMesh
static var _terrain_base := 0.0


static func make_pad() -> Node3D:
	var root := Node3D.new()
	root.name = "Pad"
	var site: Node3D = SITE.instantiate()
	site.scale = Vector3.ONE * SITE_K
	root.add_child(site)
	var t := MeshInstance3D.new()
	t.name = "Terrain"
	t.mesh = _terrain()
	var tm := ShaderMaterial.new()
	tm.shader = TERRAIN_SHADER
	tm.set_shader_parameter("k", SITE_K)
	tm.set_shader_parameter("base_alt", _terrain_base)
	t.material_override = tm
	t.rotation_degrees.y = TERRAIN_YAW
	root.add_child(t)
	return root


## Daylight at 3,300 m: a deep blue sky, a pale hazy horizon, and haze that grows with distance (aerial perspective).
static func apply_day(env: Environment) -> void:
	env.sky = make_day_sky()
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.68, 0.76, 0.86)
	env.fog_density = 0.00042
	env.fog_sky_affect = 0.0
	env.fog_sun_scatter = 0.25
	env.tonemap_exposure = 0.9


## Altitude in metres of one heightmap sample (coded as R * 256 + G).
static func _terrain_alt(img: Image, x: int, y: int) -> float:
	var c := img.get_pixel(clampi(x, 0, img.get_width() - 1), clampi(y, 0, img.get_height() - 1))
	return roundf(c.r * 255.0) * 256.0 + roundf(c.g * 255.0)


## The terrain mesh, built once from the heightmap: the pad's sample at the origin, a disc around the pad levelled to
## the pad's height, normals from the neighbours.
static func _terrain() -> ArrayMesh:
	if _terrain_mesh:
		return _terrain_mesh
	var img: Image = TERRAIN_HM.get_image()
	if img.is_compressed():
		img.decompress()
	var n := img.get_width()
	var base := _terrain_alt(img, TERRAIN_PAD.x, TERRAIN_PAD.y)
	_terrain_base = base
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for y in n:
		for x in n:
			var a := _terrain_alt(img, x, y)
			var r := Vector2(x - TERRAIN_PAD.x, y - TERRAIN_PAD.y).length() * TERRAIN_CELL_M
			a = lerpf(base - 0.6, a, smoothstep(700.0, 1600.0, r))
			hs[y * n + x] = (a - base) * SITE_K
	var cell := TERRAIN_CELL_M * SITE_K
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(n * n)
	norms.resize(n * n)
	uvs.resize(n * n)
	for y in n:
		for x in n:
			var i := y * n + x
			verts[i] = Vector3((x - TERRAIN_PAD.x) * cell, hs[i], (y - TERRAIN_PAD.y) * cell)
			var hl := hs[y * n + maxi(x - 1, 0)]
			var hr := hs[y * n + mini(x + 1, n - 1)]
			var hu := hs[maxi(y - 1, 0) * n + x]
			var hd := hs[mini(y + 1, n - 1) * n + x]
			norms[i] = Vector3(hl - hr, 2.0 * cell, hu - hd).normalized()
			uvs[i] = Vector2(float(x) / (n - 1), float(y) / (n - 1))
	var idx := PackedInt32Array()
	idx.resize((n - 1) * (n - 1) * 6)
	var j := 0
	for y in n - 1:
		for x in n - 1:
			var a0 := y * n + x
			idx[j] = a0
			idx[j + 1] = a0 + 1
			idx[j + 2] = a0 + n
			idx[j + 3] = a0 + 1
			idx[j + 4] = a0 + n + 1
			idx[j + 5] = a0 + n
			j += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	_terrain_mesh = ArrayMesh.new()
	_terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _terrain_mesh
