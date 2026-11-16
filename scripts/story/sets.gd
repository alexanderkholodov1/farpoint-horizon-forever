extends RefCounted
## The story's sets (issue #66), built from primitives and the game's own pieces (the Andes relief, the Earth, the Moon,
## flames and smoke): the Andes at night, Launch Pad 39A with a Saturn V, inside Odyssey (the command module), inside
## Aquarius (the lunar module, powered down), Mission Control in Houston, and the Pacific at splashdown.
## No logos, insignia or mission identifiers are drawn (AGENTS.md); the craft are shapes and colours only.
## One unit is about 0.3 m, a cuy's height, so the craft and rooms keep their true size around the crew; the Saturn V's
## stages follow NASA's Saturn V dimensions only roughly (a set, not a model to measure).
## build(id, world) fills world.stage and returns the set: "marks" (where each cuy stands: [x, y, z, yaw]), "cast"
## (who is on this set), "cams" (named shots: from, to, and optionally from2/to2 and time for a move), "act" (the
## crew's body there: float in the capsules), and nodes the stage animates ("rocket", "capsule", "fire_light"...).
##   var S = Sets.build("pad", world)

const Space := preload("res://scripts/world/space_builder.gd")
const K := 3.33              ## Units per metre on the sets.


static func build(id: String, world) -> Dictionary:
	world.clear_stage()
	# every set starts from the same camera and look: a mission before it may have changed them (DART's camera
	# brings the near plane to a few centimetres; left so, the next scenes lose their depth and draw black on the web)
	world.cam.near = 0.05
	world.cam.far = 3000.0
	world.cam.fov = 50.0
	world.sun.light_energy = 0.0
	world.sun.shadow_enabled = true
	world.sun.light_cull_mask = 0xFFFFF
	var env: Environment = world.world_env.environment
	env.adjustment_enabled = false
	env.background_mode = Environment.BG_SKY
	env.glow_enabled = true
	env.fog_enabled = false
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var S: Dictionary
	match id:
		"andes":
			S = _andes(world, env)
		"pad":
			S = _pad(world, env)
		"capsule":
			S = _capsule(world, env, false)
		"lm":
			S = _capsule(world, env, true)
		"houston":
			S = _houston(world, env)
		"ocean":
			S = _ocean(world, env)
		"hubble":
			S = _hubble(world, env)
		"mars":
			S = _mars(world, env)
		"mars_approach":
			S = _mars_approach(world, env)
		"crew_ship":
			S = _crew_ship(world, env)
		"lcross_space":
			S = _lcross_space(world, env)
		"dart_space":
			S = _dart_space(world, env)
		"orion_cabin":
			S = _orion_cabin(world, env)
		_:
			S = _andes(world, env)
	S["id"] = id
	return S


## What the sets change in the shared world, to put back when the story or a mission leaves (save_world, then
## restore_world with what it returned).
static func save_world(world) -> Dictionary:
	var out := {}
	var env: Environment = world.world_env.environment
	for k in ["background_mode", "background_color", "background_energy_multiplier", "ambient_light_source",
			"ambient_light_color", "ambient_light_energy", "fog_enabled", "fog_density", "fog_light_color", "glow_enabled",
			"tonemap_exposure", "sky", "adjustment_enabled", "adjustment_saturation"]:
		out["env." + k] = env.get(k)
	for k in ["light_energy", "light_color", "rotation_degrees", "shadow_enabled", "light_cull_mask"]:
		out["sun." + k] = world.sun.get(k)
	out["fov"] = world.cam.fov
	out["far"] = world.cam.far
	out["near"] = world.cam.near
	return out


static func restore_world(world, saved: Dictionary) -> void:
	world.clear_stage()
	var env: Environment = world.world_env.environment
	for k in saved:
		if k.begins_with("env."):
			env.set(k.substr(4), saved[k])
		elif k.begins_with("sun."):
			world.sun.set(k.substr(4), saved[k])
	world.cam.fov = saved.get("fov", 50.0)
	world.cam.far = saved.get("far", 2000.0)
	world.cam.near = saved.get("near", 0.05)


# ===================================================================================== HELPERS
static func mat(c: Color, rough := 0.7, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


static func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func cyl(parent: Node3D, r_top: float, r_bottom: float, h: float, pos: Vector3, m: Material, seg := 48) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = seg
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


static func ball(parent: Node3D, r: float, pos: Vector3, m: Material, squash := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.material_override = m
	mi.position = pos
	mi.scale = squash
	parent.add_child(mi)
	return mi


static func omni(parent: Node3D, pos: Vector3, c: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng
	parent.add_child(l)
	return l


static func shader_mat(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## The Moon as it looks from the ground or through a window: its real map (assets/textures/moon_color.jpg), lit evenly.
static func bright_moon(r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 64
	s.rings = 32
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = Space.MOON_COLOR
	m.albedo_color = Color(1.1, 1.1, 1.05)
	mi.material_override = m
	mi.rotation.y = PI
	return mi


## A thin cylinder from a to b (parachute lines, cables).
static func rope(parent: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> MeshInstance3D:
	var mi := cyl(parent, r, r, (b - a).length(), (a + b) * 0.5, m, 4)
	mi.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	return mi


## A soft daylight sky over the sea or the Florida coast (the game's own day sky is the deep blue of 3,300 m).
static func low_sky() -> Sky:
	var sky := Sky.new()
	var p := ProceduralSkyMaterial.new()
	p.sky_top_color = Color(0.36, 0.55, 0.8)
	p.sky_horizon_color = Color(0.78, 0.84, 0.9)
	p.sky_curve = 0.18
	p.ground_bottom_color = Color(0.25, 0.3, 0.35)
	p.ground_horizon_color = Color(0.78, 0.84, 0.9)
	sky.sky_material = p
	return sky


## Puts every mesh under n on layer 2 as well, so a light that lights only layer 2 reaches it.
static func layer2(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = 3
	for c in n.get_children():
		layer2(c)


## A soft round glow texture (white at the centre, clear at the edge), for flashes and engine glows.
static func soft_glow() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


static func marks(list: Dictionary) -> Dictionary:
	var out := {}
	for k in list:
		var a: Array = list[k]
		out[k] = {"pos": Vector3(a[0], a[1], a[2]), "yaw": deg_to_rad(a[3])}
	return out


# ===================================================================================== THE ANDES AT NIGHT
## A clearing on the paramo below Cotopaxi (the game's real relief, NASA SRTM [S-terrain-tiles]), under a big Moon,
## around a small fire.
static func _andes(world, env: Environment) -> Dictionary:
	var st: Node3D = world.stage
	env.sky = Space.make_space_sky()
	env.background_energy_multiplier = 0.8
	env.ambient_light_color = Color(0.32, 0.38, 0.6)
	env.ambient_light_energy = 0.45
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.08, 0.14)
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.0
	# moonlight
	world.sun.light_energy = 0.8
	world.sun.light_color = Color(0.62, 0.72, 1.0)
	world.sun.rotation_degrees = Vector3(-32, 160, 0)
	var t := MeshInstance3D.new()
	t.mesh = Space._terrain()
	var tm := ShaderMaterial.new()
	tm.shader = Space.TERRAIN_SHADER
	tm.set_shader_parameter("k", Space.SITE_K)
	tm.set_shader_parameter("base_alt", Space._terrain_base)
	t.material_override = tm
	t.rotation_degrees.y = Space.TERRAIN_YAW + 180.0
	t.position.y = -0.05
	st.add_child(t)
	# the clearing: grass, rocks
	var grass := MeshInstance3D.new()
	var gd := CylinderMesh.new()
	gd.top_radius = 9.0
	gd.bottom_radius = 9.5
	gd.height = 0.1
	grass.mesh = gd
	grass.material_override = mat(Color(0.33, 0.33, 0.18), 0.95)
	grass.position.y = -0.05
	st.add_child(grass)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rock := mat(Color(0.24, 0.24, 0.25), 0.95)
	for i in 14:
		var a := rng.randf() * TAU
		var r := rng.randf_range(2.6, 8.0)
		var rk := ball(st, rng.randf_range(0.15, 0.5), Vector3(cos(a) * r, -0.05, sin(a) * r - 1.0), rock, Vector3(1.0, rng.randf_range(0.55, 0.9), rng.randf_range(0.7, 1.2)))
		rk.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf())
	# paramo grass: tufts of thin blades
	var blade := mat(Color(0.36, 0.38, 0.2), 1.0)
	var dry := mat(Color(0.5, 0.46, 0.27), 1.0)
	for i in 70:
		var a := rng.randf() * TAU
		var r := rng.randf_range(1.0, 8.5)
		var at := Vector3(cos(a) * r, 0.0, sin(a) * r - 1.0)
		for b in 7:
			var hgt := rng.randf_range(0.18, 0.38)
			var c := cyl(st, 0.0, 0.012, hgt, at + Vector3(rng.randf_range(-0.06, 0.06), hgt * 0.5, rng.randf_range(-0.06, 0.06)), blade if rng.randf() < 0.6 else dry, 3)
			c.rotation = Vector3(rng.randf_range(-0.45, 0.45), 0, rng.randf_range(-0.45, 0.45))
	# the fire: logs, flame, a warm flickering light
	var fire := Node3D.new()
	fire.position = Vector3(1.9, 0, 0.9)
	st.add_child(fire)
	var log_m := mat(Color(0.28, 0.17, 0.1), 0.9)
	for i in 3:
		var l := cyl(fire, 0.06, 0.06, 0.7, Vector3(0, 0.07, 0), log_m, 8)
		l.rotation = Vector3(PI / 2, i * 1.05, 0)
	ball(fire, 0.12, Vector3(0, 0.08, 0), mat(Color(1.0, 0.45, 0.1), 0.5, 0.0, 3.0))
	var flame := Space.make_flame(0.22)
	flame.direction = Vector3(0, 1, 0)
	flame.initial_velocity_min = 0.6
	flame.initial_velocity_max = 1.2
	flame.lifetime = 0.7
	flame.emitting = true
	fire.add_child(flame)
	var fl := omni(fire, Vector3(0, 0.6, 0), Color(1.0, 0.62, 0.3), 2.6, 7.0)
	fl.shadow_enabled = true
	# the old radio by Wayra: a wooden box, a dial, a long antenna
	var radio := Node3D.new()
	radio.position = Vector3(1.55, 0, 0.75)
	radio.rotation.y = -0.6
	st.add_child(radio)
	box(radio, Vector3(0.5, 0.32, 0.26), Vector3(0, 0.16, 0), mat(Color(0.42, 0.26, 0.14), 0.7))
	box(radio, Vector3(0.3, 0.14, 0.02), Vector3(-0.05, 0.2, 0.135), mat(Color(1.0, 0.75, 0.35), 0.4, 0.0, 1.5))
	var knob := cyl(radio, 0.04, 0.04, 0.04, Vector3(0.17, 0.18, 0.14), mat(Color(0.1, 0.1, 0.1), 0.4), 12)
	knob.rotation.x = PI / 2
	var ant := cyl(radio, 0.006, 0.006, 0.9, Vector3(0.18, 0.75, -0.05), mat(Color(0.75, 0.75, 0.78), 0.3, 0.8), 6)
	ant.rotation.z = -0.35
	# the Moon, big and low over the mountains
	var moon := bright_moon(12.0)
	moon.position = Vector3(-35, 42, -150)
	st.add_child(moon)
	return {
		"marks": marks({"killa": [-0.5, 0, 0.0, 10], "inti": [0.35, 0, -0.25, -5], "rumi": [-1.25, 0, 0.35, 25], "wayra": [1.2, 0, 0.45, -40]}),
		"cast": ["rumi", "killa", "inti", "wayra"],
		"cams": {
			"wide": {"from": Vector3(0.3, 1.0, 4.4), "to": Vector3(0, 0.6, 0)},
			"moon": {"from": Vector3(0.6, 0.35, 2.6), "to": Vector3(0, 0.7, 0), "from2": Vector3(0.2, 0.5, 2.2), "to2": Vector3(-7, 9, -30), "time": 6.0},
			"behind": {"from": Vector3(0.2, 0.9, -2.2), "to": Vector3(-8, 11, -30), "from2": Vector3(0.1, 1.2, -2.6)},
		},
		"act": "idle",
		"fire_light": fl,
		"moon": moon,
	}


# ===================================================================================== LAUNCH PAD 39A
## Florida, a clear morning; a Saturn V on its launch platform beside the tower, the crew small among the pad's crates.
static func _pad(world, env: Environment) -> Dictionary:
	var st: Node3D = world.stage
	Space.apply_day(env)
	env.sky = low_sky()
	env.glow_enabled = false
	env.fog_density = 0.00035   # light haze: from the far camera the pad must not wash out white (#97)
	env.fog_light_color = Color(0.62, 0.74, 0.88)
	env.ambient_light_color = Color(0.62, 0.68, 0.78)
	env.ambient_light_energy = 0.35
	world.sun.light_energy = 1.0
	world.sun.light_color = Color(1.0, 0.95, 0.86)
	world.sun.rotation_degrees = Vector3(-38, -35, 0)
	var gm := mat(Color(0.24, 0.3, 0.16), 1.0)
	gm.metallic_specular = 0.05
	var ground := box(st, Vector3(3000, 0.2, 2100), Vector3(0, -0.1, 450), gm)
	ground.name = "Ground"
	# Florida's coast behind the pad: a strip of beach, then the Atlantic to the horizon
	box(st, Vector3(3000, 0.2, 60), Vector3(0, -0.08, -630), mat(Color(0.82, 0.76, 0.6), 1.0))
	var sea := mat(Color(0.08, 0.3, 0.48), 0.25)
	box(st, Vector3(6000, 0.2, 3000), Vector3(0, -0.3, -2160), sea)
	# the crawlerway: the gravel road the rocket rolled out on, running toward the camera
	box(st, Vector3(40, 0.25, 1000), Vector3(0, 0.0, 420), mat(Color(0.46, 0.44, 0.4), 1.0))
	# scrub and palmettos for scale
	var scrub := mat(Color(0.16, 0.24, 0.1), 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 39
	for i in 90:
		var p := Vector3(rng.randf_range(-900, 900), 0, rng.randf_range(-560, 900))
		if absf(p.x) < 140 and p.z < 60:
			continue   # keep the pad clear
		if absf(p.x) < 30:
			continue   # and the crawlerway
		ball(st, rng.randf_range(4, 11), p, scrub, Vector3(1.0, 0.55, 1.0))
	var concrete := mat(Color(0.55, 0.54, 0.51), 0.9)
	box(st, Vector3(220, 0.3, 220), Vector3(0, 0.0, -90), concrete)
	# the launch platform and the tower beside it
	var ml := mat(Color(0.42, 0.43, 0.45), 0.8, 0.3)
	box(st, Vector3(48 * K, 7.6 * K, 41 * K), Vector3(0, 3.8 * K, -90), ml)
	var red := mat(Color(0.48, 0.13, 0.08), 0.8, 0.2)
	var tower := Node3D.new()
	tower.position = Vector3(16 * K, 7.6 * K, -90)
	st.add_child(tower)
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			box(tower, Vector3(0.8 * K, 120 * K, 0.8 * K), Vector3(cx * 5 * K, 60 * K, cz * 5 * K), red)
	for i in 30:
		box(tower, Vector3(11 * K, 0.5 * K, 11 * K), Vector3(0, i * 4 * K, 0), red)
		var d := box(tower, Vector3(14 * K, 0.4 * K, 0.4 * K), Vector3(0, i * 4 * K + 2 * K, 5 * K), red)
		d.rotation.z = 0.28 if i % 2 == 0 else -0.28
	for h in [62.0, 78.0, 95.0, 104.0]:
		box(tower, Vector3(9 * K, 1.2 * K, 1.4 * K), Vector3(-9 * K, h * K, 0), red)
	# the Saturn V
	var rocket := _saturn()
	rocket.position = Vector3(0, 7.6 * K, -90)
	st.add_child(rocket)
	var flames := Node3D.new()
	flames.name = "Flames"
	rocket.add_child(flames)
	for ex in [-1, 0, 1]:
		for ez in ([-1, 1] if ex != 0 else [0]):
			var f := Space.make_flame(9.0)
			f.position = Vector3(ex * 3.2 * K, -2 * K, ez * 3.2 * K)
			flames.add_child(f)
	var smoke := Space.make_pad_smoke()
	smoke.scale = Vector3.ONE * 18.0
	smoke.position = Vector3(0, 6 * K, -90)
	st.add_child(smoke)
	# the crew's corner: crates, a cart and a big roll of tape
	var wood := mat(Color(0.55, 0.42, 0.26), 0.85)
	box(st, Vector3(2.2, 1.5, 1.6), Vector3(-2.2, 0.75, -1.6), wood)
	box(st, Vector3(1.6, 1.1, 1.3), Vector3(-0.7, 0.55, -2.4), wood)
	box(st, Vector3(1.2, 0.9, 1.0), Vector3(2.4, 0.45, -1.8), wood, Vector3(0, 0.4, 0))
	var tape := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.25
	tor.outer_radius = 0.48
	tape.mesh = tor
	tape.material_override = mat(Color(0.7, 0.72, 0.75), 0.35, 0.5)
	tape.position = Vector3(-1.5, 0.1, 0.5)
	st.add_child(tape)
	return {
		"marks": marks({"inti": [0.3, 0, 0.2, 0], "killa": [-0.4, 0, 0.0, 15], "rumi": [-1.5, 0, 0.5, 20], "wayra": [1.2, 0, 0.4, -20]}),
		"cast": ["rumi", "killa", "inti"],
		"cams": {
			"wide": {"from": Vector3(0.6, 0.8, 4.2), "to": Vector3(0, 0.8, -2)},
			"pad_wide": {"from": Vector3(330, 30, 760), "to": Vector3(0, 160, -90), "from2": Vector3(280, 25, 680), "time": 8.0},
			"rocket_up": {"from": Vector3(1.0, 0.25, 3.0), "to": Vector3(0, 0.7, 0), "from2": Vector3(0.6, 0.15, 3.6), "to2": Vector3(0, 300, -90), "time": 7.0},
			"launch": {"from": Vector3(330, 20, 760), "to": Vector3(0, 180, -90), "track": "rocket", "offset": Vector3(0, 180, 0)},
		},
		"act": "idle",
		"rocket": rocket,
		"smoke": smoke,
		"tape": tape,
	}


## A Saturn V as a stack of shapes: the first stage with its black roll pattern and fins, the second stage, the third,
## the instrument ring, the adapter that hides the lunar module, the service and command modules, the escape tower.
static func _saturn() -> Node3D:
	var r := Node3D.new()
	r.name = "Rocket"
	var white := mat(Color(0.93, 0.93, 0.9), 0.55)
	var black := mat(Color(0.08, 0.08, 0.09), 0.6)
	var steel := mat(Color(0.6, 0.6, 0.62), 0.4, 0.6)
	var y := 0.0
	# engine bells
	for ex in [-1, 0, 1]:
		for ez in ([-1, 1] if ex != 0 else [0]):
			cyl(r, 0.9 * K, 1.9 * K, 5.8 * K, Vector3(ex * 3.2 * K, 2.9 * K - 5.8 * K, ez * 3.2 * K), black, 24)
	# first stage: white with a black quarter pattern, fins
	var s1 := cyl(r, 5.05 * K, 5.05 * K, 42 * K, Vector3(0, 21 * K, 0), white, 64)
	s1.name = "S1"
	for q in 4:
		var panel := box(r, Vector3(5.0 * K, 14 * K, 0.4 * K), Vector3(0, 0, 0), black)
		var ang := q * PI / 2 + PI / 4
		panel.position = Vector3(sin(ang) * 3.7 * K, (7 if q % 2 == 0 else 35) * K, cos(ang) * 3.7 * K)
		panel.rotation.y = ang
	cyl(r, 5.1 * K, 5.1 * K, 1.4 * K, Vector3(0, 41.4 * K, 0), black, 64)
	for q in 4:
		var fin := box(r, Vector3(0.6 * K, 8 * K, 4.5 * K), Vector3(0, 0, 0), white)
		var a2 := q * PI / 2
		fin.position = Vector3(sin(a2) * 6.6 * K, 3.5 * K, cos(a2) * 6.6 * K)
		fin.rotation.y = a2
	y = 42 * K
	cyl(r, 5.05 * K, 5.05 * K, 5.5 * K, Vector3(0, y + 2.75 * K, 0), white, 64)
	y += 5.5 * K
	cyl(r, 5.05 * K, 5.05 * K, 24.8 * K, Vector3(0, y + 12.4 * K, 0), white, 64)
	y += 24.8 * K
	cyl(r, 3.3 * K, 5.05 * K, 5.0 * K, Vector3(0, y + 2.5 * K, 0), white, 64)
	y += 5.0 * K
	cyl(r, 3.3 * K, 3.3 * K, 17.8 * K, Vector3(0, y + 8.9 * K, 0), white, 48)
	cyl(r, 3.32 * K, 3.32 * K, 4 * K, Vector3(0, y + 2 * K, 0), black, 48)
	y += 17.8 * K
	cyl(r, 3.3 * K, 3.3 * K, 1.0 * K, Vector3(0, y + 0.5 * K, 0), steel, 48)
	y += 1.0 * K
	cyl(r, 1.95 * K, 3.3 * K, 8.5 * K, Vector3(0, y + 4.25 * K, 0), white, 48)
	y += 8.5 * K
	cyl(r, 1.95 * K, 1.95 * K, 7.5 * K, Vector3(0, y + 3.75 * K, 0), white, 48)
	y += 7.5 * K
	cyl(r, 0.3 * K, 1.95 * K, 3.5 * K, Vector3(0, y + 1.75 * K, 0), white, 48)
	y += 3.5 * K
	cyl(r, 0.08 * K, 0.08 * K, 7 * K, Vector3(0, y + 3.5 * K, 0), steel, 8)
	cyl(r, 0.25 * K, 0.4 * K, 3 * K, Vector3(0, y + 8 * K, 0), white, 16)
	cyl(r, 0.0, 0.25 * K, 1.5 * K, Vector3(0, y + 10.2 * K, 0), white, 16)
	return r


# ===================================================================================== ODYSSEY AND AQUARIUS
## Inside a capsule: the crew float in front of the instrument panel; a window shows the Earth (Odyssey) or the Moon
## (Aquarius, dark and cold, its power turned down).
static func _capsule(world, env: Environment, lm: bool) -> Dictionary:
	var st: Node3D = world.stage
	env.sky = Space.make_space_sky()
	env.background_energy_multiplier = 1.0
	env.ambient_light_color = Color(0.55, 0.6, 0.7) if not lm else Color(0.35, 0.42, 0.6)
	env.ambient_light_energy = 0.35 if not lm else 0.22
	world.sun.light_energy = 1.4
	world.sun.light_color = Color(1.0, 0.97, 0.92)
	world.sun.rotation_degrees = Vector3(-15, 55, 0)
	var shell := mat(Color(0.46, 0.47, 0.45) if not lm else Color(0.3, 0.33, 0.38), 0.85)
	var panel_m := mat(Color(0.33, 0.35, 0.36) if not lm else Color(0.24, 0.26, 0.29), 0.6, 0.2)
	var dark := mat(Color(0.08, 0.08, 0.09), 0.5)
	var room := Node3D.new()
	st.add_child(room)
	# back: the main panel in three angled parts, covered in switches, gauges and lamps
	var rng := RandomNumberGenerator.new()
	rng.seed = 13 if not lm else 31
	var lamps: Array = []
	for i in 3:
		var part := Node3D.new()
		part.position = Vector3((i - 1) * 3.6, 1.6, -2.4 + (0.9 if i != 1 else 0.0))
		part.rotation.y = (1 - i) * 0.45
		part.rotation.x = -0.25
		room.add_child(part)
		box(part, Vector3(3.6, 2.6, 0.3), Vector3.ZERO, panel_m)
		for gx in 9:
			for gy in 6:
				var p := Vector3(-1.5 + gx * 0.375, -1.05 + gy * 0.42, 0.17)
				var kind := rng.randi() % 5
				if kind <= 1:
					var sw := cyl(part, 0.02, 0.025, 0.14, p + Vector3(0, 0, 0.06), mat(Color(0.85, 0.85, 0.82), 0.3, 0.7), 6)
					sw.rotation.x = PI / 2 + rng.randf_range(-0.5, 0.5)
					box(part, Vector3(0.12, 0.12, 0.02), p, dark)
				elif kind == 2:
					var g := cyl(part, 0.12, 0.12, 0.04, p, dark, 20)
					g.rotation.x = PI / 2
					var face := cyl(part, 0.1, 0.1, 0.02, p + Vector3(0, 0, 0.025), mat(Color(0.9, 0.9, 0.85), 0.5, 0.0, 0.15), 20)
					face.rotation.x = PI / 2
				elif kind == 3:
					var c: Color = [Color(1, 0.25, 0.15), Color(0.3, 1, 0.4), Color(1, 0.75, 0.2), Color(0.5, 0.75, 1)][rng.randi() % 4]
					var lamp := box(part, Vector3(0.14, 0.09, 0.03), p, mat(c, 0.4, 0.0, 1.6 if not lm else 0.5))
					lamps.append(lamp)
				else:
					box(part, Vector3(0.3, 0.16, 0.03), p, mat(Color(0.1, 0.12, 0.1), 0.4, 0.0, 0.0))
	# the master alarm: a red lamp the stage lights when the alarm sounds
	var alarm_lamp := box(room, Vector3(0.5, 0.22, 0.05), Vector3(0, 3.05, -2.25), mat(Color(1, 0.15, 0.1), 0.4, 0.0, 0.2))
	# floor of couches below, a hatch ring above, the curved hull around
	var fabric := mat(Color(0.5, 0.52, 0.5), 0.95)
	for i in 3:
		box(room, Vector3(1.6, 0.4, 4.0), Vector3((i - 1) * 1.9, -1.0, 0.4), fabric)
	var hull := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 2.5
	hm.bottom_radius = 6.5
	hm.height = 6.5
	hm.radial_segments = 48
	hm.cap_top = false
	hm.cap_bottom = false
	hull.mesh = hm
	var hullm := shell.duplicate() as StandardMaterial3D
	hullm.cull_mode = BaseMaterial3D.CULL_FRONT
	hull.material_override = hullm
	hull.position = Vector3(0, 1.8, 0)
	room.add_child(hull)
	var hatch := MeshInstance3D.new()
	var ht := TorusMesh.new()
	ht.inner_radius = 0.7
	ht.outer_radius = 0.9
	hatch.mesh = ht
	hatch.material_override = mat(Color(0.5, 0.5, 0.52), 0.4, 0.6)
	hatch.position = Vector3(0, 4.9, 0)
	room.add_child(hatch)
	# a window: a lit frame on the left wall; through it, the Earth (Odyssey) or the Moon (Aquarius)
	var win := Node3D.new()
	win.position = Vector3(-4.2, 2.0, 0.6)
	win.rotation.y = PI / 2 - 0.3
	room.add_child(win)
	var frame := MeshInstance3D.new()
	var ft := TorusMesh.new()
	ft.inner_radius = 0.75
	ft.outer_radius = 0.95
	frame.mesh = ft
	frame.rotation.x = PI / 2
	frame.material_override = mat(Color(0.3, 0.3, 0.32), 0.5, 0.5)
	win.add_child(frame)
	var look_out := Vector3(-0.955, 0.0, -0.296)        # the window's outward direction (the wall's turn)
	var outside: Node3D
	if lm:
		outside = bright_moon(22.0)
	else:
		outside = Space.make_earth(18.0, false)
	outside.position = Vector3(-4.3, 2.0, 0.6) + look_out * 150.0 + Vector3(0, 6, 8)
	st.add_child(outside)
	# the Sun lights only what is outside: inside, the cabin's own lamps do
	layer2(outside)
	world.sun.light_cull_mask = 2
	if not lm:
		world.planet = outside
	# the cabin lights
	var flood := omni(room, Vector3(0, 3.6, 2.5), Color(0.95, 0.97, 1.0) if not lm else Color(0.6, 0.7, 1.0), 1.6 if not lm else 0.7, 12.0)
	flood.shadow_enabled = true
	omni(room, Vector3(0, 1.4, -1.5), Color(0.7, 0.85, 1.0), 0.6 if not lm else 0.25, 5.0)
	# the hull hides the window's view of space: open it there
	hullm.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	hull.visible = false
	var back := box(room, Vector3(16, 9, 0.2), Vector3(0, 2, -3.4), shell)
	back.name = "Back"
	box(room, Vector3(16, 0.2, 10), Vector3(0, -1.3, 0), shell)
	box(room, Vector3(16, 0.2, 10), Vector3(0, 5.6, 0), shell)
	box(room, Vector3(0.2, 9, 10), Vector3(5.6, 2, 0), shell)
	# the left wall with the window's hole: four pieces around it
	var wl := Node3D.new()
	wl.position = Vector3(-4.3, 2.0, 0.6)
	wl.rotation.y = -0.3
	room.add_child(wl)
	box(wl, Vector3(0.2, 9, 4), Vector3(0, 0, -2.9), shell)
	box(wl, Vector3(0.2, 9, 4), Vector3(0, 0, 2.9), shell)
	box(wl, Vector3(0.2, 3.6, 1.8), Vector3(0, 2.7, 0), shell)
	box(wl, Vector3(0.2, 3.6, 1.8), Vector3(0, -2.7, 0), shell)
	var locker := mat(Color(0.52, 0.53, 0.5) if not lm else Color(0.36, 0.38, 0.42), 0.6, 0.3)
	for lx in 3:
		for ly in 3:
			box(room, Vector3(0.15, 0.9, 1.2), Vector3(5.45, 0.2 + ly * 1.1, -1.6 + lx * 1.4), locker)
	var fl := 1.0 if not lm else 0.0
	return {
		"marks": marks({"rumi": [-1.15, 0.35, 0.3, 15], "killa": [-0.35, 0.75, 0.0, 5], "inti": [0.45, 0.45, -0.1, -5], "wayra": [1.2, 0.6, 0.3, -20]}),
		"cast": ["rumi", "killa", "inti"],
		"cams": {
			"wide": {"from": Vector3(0.2, 1.5, 4.6), "to": Vector3(0, 1.1, 0)},
			"window": {"from": Vector3(0.6, 1.5, 2.6), "to": Vector3(-1.0, 1.2, 0), "from2": Vector3(-1.6, 2.05, 1.2), "to2": Vector3(-4.3, 2.0, 0.6) + Vector3(-0.955, 0.0, -0.296) * 150.0 + Vector3(0, 6, 8), "time": 5.0},
		},
		"act": "float",
		"lamps": lamps,
		"alarm_lamp": alarm_lamp,
		"flood": flood,
		"flood_energy": flood.light_energy * fl + (0.7 if lm else 0.0),
	}


# ===================================================================================== MISSION CONTROL
## Houston: three rows of consoles under their screens, the big wall screens in front with the path to the Moon and
## back; Wayra on duty at the front row.
static func _houston(world, env: Environment) -> Dictionary:
	var st: Node3D = world.stage
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_color = Color(0.5, 0.48, 0.45)
	env.ambient_light_energy = 0.6
	var room := Node3D.new()
	st.add_child(room)
	var carpet := mat(Color(0.2, 0.22, 0.26), 1.0)
	var wall := mat(Color(0.3, 0.3, 0.28), 0.9)
	var console := mat(Color(0.5, 0.53, 0.5), 0.7, 0.1)
	var dark := mat(Color(0.08, 0.09, 0.1), 0.5)
	box(room, Vector3(40, 0.2, 40), Vector3(0, -0.1, 0), carpet)
	box(room, Vector3(40, 16, 0.3), Vector3(0, 8, -16), wall)
	box(room, Vector3(40, 0.3, 40), Vector3(0, 14, 0), mat(Color(0.18, 0.18, 0.17), 1.0))
	for sx in [-1, 1]:
		box(room, Vector3(0.3, 16, 40), Vector3(sx * 18, 8, 0), wall)
	var screen := shader_mat("""
shader_type spatial;
render_mode unshaded;
uniform vec3 tint = vec3(0.55, 1.0, 0.7);
uniform float seed = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float row = floor(uv.y * 14.0);
	float col = floor(uv.x * 28.0);
	float on = step(0.45, h(vec2(row, col))) * step(0.12, fract(uv.y * 14.0)) * step(fract(uv.y * 14.0), 0.7);
	on *= step(h(vec2(row, 3.0)) * 0.9, uv.x);
	float blink = step(0.5, fract(TIME * 0.7 + h(vec2(row, 9.0))));
	on *= mix(1.0, blink, step(0.93, h(vec2(row, 5.0))));
	ALBEDO = tint * (0.12 + on * 0.9);
	EMISSION = tint * on * 0.8;
}
""")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var wayra_desk := Vector3.ZERO
	for row in 3:
		var z := 1.5 + row * 4.0
		var floor_y := row * 0.8
		if row > 0:
			box(room, Vector3(30, floor_y, 4.0), Vector3(0, floor_y / 2.0, z), carpet)
		for c in 5:
			var x := (c - 2) * 5.2
			var desk := Node3D.new()
			desk.position = Vector3(x, floor_y, z)
			room.add_child(desk)
			box(desk, Vector3(4.8, 2.5, 1.6), Vector3(0, 1.25, 0), console)
			box(desk, Vector3(4.8, 0.12, 1.0), Vector3(0, 2.56, 1.0), console)
			var hood := box(desk, Vector3(4.8, 1.7, 0.9), Vector3(0, 3.3, -0.25), console)
			hood.rotation.x = 0.3
			for s in 2:
				var sm := screen.duplicate() as ShaderMaterial
				sm.set_shader_parameter("seed", rng.randf() * 100.0)
				sm.set_shader_parameter("tint", Vector3(0.55, 1.0, 0.7) if rng.randf() < 0.7 else Vector3(1.0, 0.95, 0.85))
				var q := MeshInstance3D.new()
				var qm := QuadMesh.new()
				qm.size = Vector2(1.6, 1.1)
				q.mesh = qm
				q.material_override = sm
				q.position = Vector3(-1.0 + s * 2.0, 3.35, 0.24)
				q.rotation.x = -0.3
				desk.add_child(q)
			for b in 10:
				box(desk, Vector3(0.14, 0.05, 0.14), Vector3(-2.0 + b * 0.44, 2.63, 1.2), mat([Color(1, 0.8, 0.3), Color(0.3, 0.9, 1), Color(1, 0.3, 0.2)][b % 3], 0.4, 0.0, 1.2))
			if row == 0 and c == 2:
				wayra_desk = Vector3(x, floor_y + 2.62, z + 1.0)
			if row == 0 and c == 2:
				omni(desk, Vector3(0, 3.8, 1.6), Color(1.0, 0.85, 0.65), 1.2, 5.0)
	# the wall screens: the path to the Moon and back in the middle, data at the sides
	var path := shader_mat("""
shader_type spatial;
render_mode unshaded;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(2.0, 1.0);
	vec3 c = vec3(0.02, 0.04, 0.09);
	vec2 e = vec2(-0.72, 0.0);
	vec2 m = vec2(0.78, 0.0);
	c += vec3(0.3, 0.6, 1.0) * smoothstep(0.075, 0.06, length(p - e));
	c += vec3(0.75) * smoothstep(0.04, 0.03, length(p - m));
	// a free-return figure eight: out above, around the Moon, back below
	float t = atan(p.y, p.x - 0.03);
	float best = 1.0;
	for (int i = 0; i < 120; i++) {
		float a = float(i) / 120.0 * 6.2831;
		vec2 q = vec2(0.03 + 0.78 * cos(a), 0.18 * sin(2.0 * a));
		best = min(best, length(p - q));
	}
	c += vec3(1.0, 0.75, 0.3) * smoothstep(0.012, 0.004, best);
	float a2 = fract(TIME * 0.05) * 6.2831;
	vec2 craft = vec2(0.03 + 0.78 * cos(a2), 0.18 * sin(2.0 * a2));
	c += vec3(1.0, 0.95, 0.7) * smoothstep(0.03, 0.015, length(p - craft));
	ALBEDO = c;
	EMISSION = c * 0.9;
}
""")
	for i in 3:
		var big := MeshInstance3D.new()
		var bq := QuadMesh.new()
		bq.size = Vector2(9.0, 4.8) if i == 1 else Vector2(6.0, 4.0)
		big.mesh = bq
		if i == 1:
			big.material_override = path
		else:
			var sm2 := screen.duplicate() as ShaderMaterial
			sm2.set_shader_parameter("seed", 40.0 + i)
			sm2.set_shader_parameter("tint", Vector3(0.6, 0.8, 1.0))
			big.material_override = sm2
		big.position = Vector3((i - 1) * 10.5, 8.0, -15.8)
		room.add_child(big)
		box(room, Vector3(bq.size.x + 0.4, bq.size.y + 0.4, 0.1), Vector3((i - 1) * 10.5, 8.0, -15.9), dark)
	for lx in [-10, 0, 10]:
		for lz in [-6, 4, 12]:
			omni(room, Vector3(lx, 12.5, lz), Color(1.0, 0.92, 0.8), 1.5, 14.0)
	var mk := wayra_desk
	return {
		"marks": {"wayra": {"pos": mk + Vector3(0.4, 0, -0.1), "yaw": 0.0}, "killa": {"pos": mk + Vector3(-1.2, 0, 0), "yaw": 0.2},
			"rumi": {"pos": mk + Vector3(1.6, 0, 0), "yaw": -0.2}, "inti": {"pos": mk + Vector3(-0.4, 0, 0), "yaw": 0.0}},
		"cast": ["wayra"],
		"cams": {
			"wide": {"from": mk + Vector3(1.5, 2.5, 7.5), "to": mk + Vector3(0, 1.5, -6)},
			"room": {"from": Vector3(9, 9, 14), "to": Vector3(0, 6, -14), "from2": Vector3(4, 6, 10), "to2": mk + Vector3(0, 0.6, 0), "time": 6.0},
		},
		"act": "idle",
	}


# ===================================================================================== HUBBLE IN THE BAY
## STS-61, December 1993: Hubble stands upright in Endeavour's payload bay, the Earth below, the Sun bright. True
## size around the crew: Hubble is 13.2 m long and 4.2 m wide [S-hubble-sm1]; the bay about 18 m long. "spots" are
## where each part of the five spacewalks goes (data/missions/sts61.json), in the set's own coordinates.
static func _hubble(world, env: Environment) -> Dictionary:
	var st: Node3D = world.stage
	env.sky = Space.make_space_sky()
	env.background_energy_multiplier = 1.0
	env.ambient_light_color = Color(0.55, 0.62, 0.8)
	env.ambient_light_energy = 0.4
	world.sun.light_energy = 1.6
	world.sun.light_color = Color(1.0, 0.97, 0.92)
	world.sun.rotation_degrees = Vector3(-35, 35, 0)
	world.cam.far = 6000.0
	# the Earth below, filling the lower sky
	var earth: Node3D = Space.make_earth(1500.0, false)
	earth.position = Vector3(0, -1620, -300)
	earth.rotation_degrees = Vector3(0, 80, 20)
	st.add_child(earth)
	world.planet = earth
	# the payload bay: a white floor, the side walls, the open doors, the tail at the back
	var white := mat(Color(0.7, 0.7, 0.68), 0.7)
	var lining := mat(Color(0.62, 0.62, 0.6), 0.95)
	var bay := Node3D.new()
	bay.name = "Bay"
	st.add_child(bay)
	box(bay, Vector3(16, 1.0, 62), Vector3(0, -1.0, 0), lining)
	for sx in [-1, 1]:
		box(bay, Vector3(1.0, 6, 62), Vector3(sx * 8.5, 1.5, 0), white)
		# the doors open all the way, lying out flat beside the bay, as in the photos of shuttle servicing missions
		var door := box(bay, Vector3(0.4, 15, 62), Vector3(sx * 16.0, 0.6, 0), white)
		door.rotation.z = sx * -1.5
	box(bay, Vector3(4, 22, 14), Vector3(0, 9, 40), white)
	# the berthing platform and Hubble standing on it
	var hub := Node3D.new()
	hub.name = "Hubble"
	hub.position = Vector3(0, 1.5, -6)
	st.add_child(hub)
	cyl(hub, 6.5, 6.5, 1.2, Vector3(0, -0.6, 0), mat(Color(0.5, 0.52, 0.55), 0.5, 0.6), 48)
	var foil := mat(Color(0.8, 0.8, 0.82), 0.3, 0.85)
	var dark := mat(Color(0.12, 0.13, 0.15), 0.6, 0.3)
	cyl(hub, 7.3, 7.3, 11.0, Vector3(0, 5.5, 0), foil, 64)          # the aft shroud: the instruments' bays
	cyl(hub, 6.9, 7.3, 2.0, Vector3(0, 12.0, 0), foil, 64)
	cyl(hub, 6.9, 6.9, 30.0, Vector3(0, 28.0, 0), foil, 64)          # the light shield and the mirror's tube
	cyl(hub, 7.0, 7.0, 0.4, Vector3(0, 43.0, 0), dark, 64)
	var door := cyl(hub, 7.0, 7.0, 0.3, Vector3(0, 0, 0), foil, 48)   # the aperture door, open
	door.position = Vector3(0, 46.5, -6.5)
	door.rotation.x = -1.2
	for i in 8:
		var a := i * TAU / 8.0
		box(hub, Vector3(0.15, 10.5, 0.15), Vector3(sin(a) * 7.32, 5.5, cos(a) * 7.32), dark)
	# the equipment bay doors (gyros, fuses, the computer), and the radial bay of the camera
	box(hub, Vector3(4.0, 5.0, 0.4), Vector3(0, 17.0, 7.0), mat(Color(0.7, 0.7, 0.72), 0.4, 0.7))
	var camera_bay := box(hub, Vector3(0.6, 6.0, 5.0), Vector3(-7.2, 5.5, 0), mat(Color(0.86, 0.86, 0.9), 0.35, 0.3))
	camera_bay.name = "CameraBay"
	# two high-gain antennas on booms
	for sx in [-1, 1]:
		box(hub, Vector3(0.3, 0.3, 9.0), Vector3(sx * 3.0, 24.0, -11.0), dark)
		var dish := ball(hub, 2.2, Vector3(sx * 3.0, 24.0, -15.5), mat(Color(0.9, 0.9, 0.88), 0.4), Vector3(1, 1, 0.25))
		dish.rotation.x = 0.3
	# the solar arrays: two wings on masts; the old ones until the second spacewalk
	var wings := Node3D.new()
	wings.name = "Wings"
	hub.add_child(wings)
	_wings(wings, Color(0.25, 0.22, 0.45))
	# the magnetometers at the top
	var top := Node3D.new()
	top.name = "Magnetometers"
	top.position = Vector3(0, 44.0, 0)
	hub.add_child(top)
	# the robot arm, from the bay's side up toward Hubble
	var arm_m := mat(Color(0.9, 0.9, 0.88), 0.5)
	rope(st, Vector3(7.5, 1.5, 14), Vector3(5, 18, 8), 0.5, arm_m)
	rope(st, Vector3(5, 18, 8), Vector3(3.5, 9, 3), 0.45, arm_m)
	var spots := {
		"rsu": Vector3(0, 17.0, 7.6), "ecu": Vector3(1.2, 17.6, 7.6), "fuses": Vector3(-1.2, 16.4, 7.6),
		"arrays": Vector3(9.0, 24.0, 0), "wfpc2": Vector3(-7.8, 5.5, 0), "magnetometers": Vector3(0, 44.8, 2.0),
		"costar": Vector3(0, 0.6, 7.6), "coprocessor": Vector3(0.6, 18.4, 7.6), "sade": Vector3(-0.6, 15.6, 7.6),
		"ghrs": Vector3(7.6, 4.5, 0), "covers": Vector3(1.0, 44.8, -1.0),
	}
	for k in spots:
		spots[k] = hub.position + spots[k]
	return {
		"marks": marks({"inti": [2.6, 16.5, 9.0, -15], "rumi": [-2.6, 15.6, 9.4, 15], "killa": [0.2, 17.6, 10.6, 0], "wayra": [0, 0, 20, 180]}),
		"cast": ["rumi", "killa", "inti"],
		"cams": {
			"wide": {"from": Vector3(12, 22, 34), "to": Vector3(0, 18, -6)},
			"hubble_up": {"from": Vector3(26, 10, 44), "to": Vector3(0, 6, -6), "from2": Vector3(32, 22, 64), "to2": Vector3(0, 40, -6), "time": 8.0},
			"earth": {"from": Vector3(-20, 30, 40), "to": Vector3(0, -60, -200), "from2": Vector3(-14, 38, 30), "to2": Vector3(0, 20, -6), "time": 8.0},
		},
		"act": "float",
		"hubble": hub,
		"wings": wings,
		"spots": spots,
		"camera_bay": camera_bay,
	}


## Hubble's two solar wings on their masts; `cell` is the colour of the cells.
static func _wings(parent: Node3D, cell: Color) -> void:
	var cm := mat(cell, 0.35, 0.5)
	var gold := mat(Color(0.85, 0.65, 0.25), 0.4, 0.8)
	# see-through when the camera works behind them (scripts/screens/sts61.gd fades them)
	for m in [cm, gold]:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	parent.set_meta("mats", [cm, gold])
	for sx in [-1, 1]:
		rope(parent, Vector3(sx * 7.0, 24.0, 0), Vector3(sx * 9.5, 24.0, 0), 0.25, gold)
		box(parent, Vector3(0.12, 40.0, 8.0), Vector3(sx * 9.8, 24.0, 0), cm)
		for k in 6:
			box(parent, Vector3(0.16, 0.18, 8.1), Vector3(sx * 9.8, 6.0 + k * 7.2, 0), gold)


# ===================================================================================== ARES VALLIS, MARS
## July 4, 1997: Ares Vallis, an old flood plain, under a butterscotch sky (colours from NASA's PIA00621), rocks
## everywhere, two low hills on the horizon. One unit is one metre here (the descent needs room); the lander's airbag
## ball is 5.2 m across, the parachute 12.5 m, the bridle 20 m (S-mpf-nssdc), Sojourner 30 cm tall (S-mpf-nasa).
static func _mars(world, env: Environment) -> Dictionary:
	var st: Node3D = world.stage
	var sky := Sky.new()
	var p := ProceduralSkyMaterial.new()
	p.sky_top_color = Color(0.5, 0.38, 0.3)
	p.sky_horizon_color = Color(0.82, 0.64, 0.46)
	p.sky_curve = 0.25
	# below the horizon the sky takes the haze's colour, so wherever the ground ends it melts into it (#97: seen
	# from 1.6 km up in the descent, the plain read as a square patch over a dark band)
	p.ground_bottom_color = Color(0.78, 0.6, 0.45)
	p.ground_horizon_color = Color(0.82, 0.64, 0.46)
	p.sun_angle_max = 8.0
	sky.sky_material = p
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.glow_enabled = false
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.6, 0.45)
	env.fog_density = 0.0007   # the ground shows through the dust from the top of the descent; its edge, 12 km off, never
	env.fog_sky_affect = 0.0
	env.ambient_light_color = Color(0.85, 0.66, 0.5)
	env.ambient_light_energy = 0.5
	world.sun.light_energy = 1.2
	world.sun.light_color = Color(1.0, 0.9, 0.78)
	world.sun.rotation_degrees = Vector3(-40, 30, 0)
	world.cam.far = 6000.0
	# the ground: a wide plain with soft swells, rust and ochre
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(24000, 24000)   # to the haze in every direction, even from the top of the descent
	pm.subdivide_width = 400
	pm.subdivide_depth = 400
	ground.mesh = pm
	ground.material_override = shader_mat("""
shader_type spatial;
varying vec3 wp;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// flat where the craft lands and the ball bounces and rolls (a corridor along +x); the swells only far off,
	// so the ground the ball meets is the ground drawn
	float d = length(vec2(max(max(-120.0 - w.x, w.x - 900.0), 0.0), w.z));
	VERTEX.y += (n(w.xz * 0.004) - 0.5) * 18.0 * smoothstep(160.0, 600.0, d);
	wp = w;
}
void fragment() {
	float a = n(wp.xz * 0.05) * 0.6 + n(wp.xz * 0.6) * 0.3 + n(wp.xz * 4.0) * 0.1;
	vec3 rust = vec3(0.56, 0.34, 0.2);
	vec3 ochre = vec3(0.7, 0.5, 0.32);
	vec3 dark = vec3(0.36, 0.22, 0.14);
	ALBEDO = mix(mix(dark, rust, smoothstep(0.2, 0.6, a)), ochre, smoothstep(0.6, 0.95, a));
	ROUGHNESS = 0.95;
}
""")
	st.add_child(ground)
	# the rocks of the flood plain: many small, some big (the ball steers around those)
	var rng := RandomNumberGenerator.new()
	rng.seed = 70497
	var rock_m := mat(Color(0.42, 0.3, 0.24), 0.9)
	var rock_d := mat(Color(0.3, 0.22, 0.18), 0.9)
	var rocks := []
	# many rocks in two batches of one low-poly shape each (a few draw calls, not hundreds)
	var lump := SphereMesh.new()
	lump.radius = 1.0
	lump.height = 2.0
	lump.radial_segments = 9
	lump.rings = 5
	var batches := []
	for m in [rock_m, rock_d]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = lump
		mm.instance_count = 260
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = m
		st.add_child(mi)
		batches.append(mm)
	for mm in batches:
		for i in mm.instance_count:
			var r := rng.randf_range(0.08, 0.5)
			var pos := Vector3(rng.randf_range(-60, 260), r * 0.25, rng.randf_range(-70, 70))
			var bs := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rng.randf_range(0.8, 1.5), rng.randf_range(0.5, 0.9), rng.randf_range(0.8, 1.4)) * r)
			mm.set_instance_transform(i, Transform3D(bs, pos))
	for i in 24:
		var r := rng.randf_range(1.4, 2.6)
		var pos := Vector3(rng.randf_range(20, 240), 0, rng.randf_range(-14, 14))
		var big := MeshInstance3D.new()
		big.mesh = lump
		big.material_override = rock_d
		big.position = pos + Vector3(0, r * 0.3, 0)
		big.scale = Vector3(1.2, 0.7, 1.0) * r
		st.add_child(big)
		rocks.append({"pos": pos, "r": r})
	# the two low hills on the horizon
	for hp in [Vector3(1400, -60, -900), Vector3(1700, -70, -650)]:
		ball(st, 260.0, hp, mat(Color(0.6, 0.44, 0.32), 1.0), Vector3(1.4, 0.45, 1.0))
	# the descent: the backshell under its parachute, the bridle, the lander and its airbag ball
	var craft := Node3D.new()
	craft.name = "Craft"
	st.add_child(craft)
	var shell := Node3D.new()
	shell.name = "Backshell"
	craft.add_child(shell)
	cyl(shell, 0.4, 1.3, 1.0, Vector3(0, 0.5, 0), mat(Color(0.85, 0.85, 0.82), 0.5, 0.3), 32)
	var chute := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 6.25
	cm.height = 6.25
	cm.is_hemisphere = true
	chute.mesh = cm
	chute.material_override = shader_mat("""
shader_type spatial;
render_mode cull_disabled;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float a = atan(lp.z, lp.x);
	float band = step(0.5, fract(a / 6.2831 * 10.0));
	ALBEDO = mix(vec3(0.95, 0.93, 0.88), vec3(0.95, 0.55, 0.15), band);
	ROUGHNESS = 0.9;
}
""")
	chute.position = Vector3(0, 16, 0)
	shell.add_child(chute)
	var line_m := mat(Color(0.9, 0.88, 0.8), 0.8)
	for i in 10:
		var a := i * TAU / 10.0
		rope(shell, Vector3(sin(a) * 6.0, 16, cos(a) * 6.0), Vector3(0, 1.0, 0), 0.03, line_m)
	var rockets := Node3D.new()
	rockets.name = "Rockets"
	shell.add_child(rockets)
	for i in 3:
		var a := i * TAU / 3.0
		var f := Space.make_flame(0.9)
		f.position = Vector3(sin(a) * 0.9, -0.1, cos(a) * 0.9)
		rockets.add_child(f)
	var bridle := MeshInstance3D.new()
	bridle.name = "Bridle"
	var bm := CylinderMesh.new()
	bm.top_radius = 0.04
	bm.bottom_radius = 0.04
	bm.height = 1.0
	bridle.mesh = bm
	bridle.material_override = mat(Color(0.95, 0.85, 0.3), 0.6)
	craft.add_child(bridle)
	var lander := Node3D.new()
	lander.name = "Lander"
	craft.add_child(lander)
	cyl(lander, 0.0, 0.9, 1.0, Vector3.ZERO, mat(Color(0.75, 0.7, 0.6), 0.5, 0.4), 3)
	var bag := MeshInstance3D.new()
	bag.name = "Airbags"
	var bs := SphereMesh.new()
	bs.radius = 2.6
	bs.height = 5.2
	bag.mesh = bs
	bag.material_override = shader_mat("""
shader_type spatial;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec3 d = normalize(lp);
	float lobes = smoothstep(0.75, 0.95, abs(sin(atan(d.z, d.x) * 2.0)) * (1.0 - abs(d.y)));
	float seam = smoothstep(0.03, 0.0, abs(fract((d.y + 1.0) * 3.0) - 0.5) - 0.47);
	ALBEDO = mix(vec3(0.93, 0.9, 0.82), vec3(0.75, 0.72, 0.65), lobes * 0.6 + seam * 0.4);
	ROUGHNESS = 0.85;
}
""")
	bag.visible = false
	lander.add_child(bag)
	# the landed lander: three petals open around the base, the airbags pulled in, the rear ramp, Sojourner
	var base := Node3D.new()
	base.name = "Base"
	base.visible = false
	st.add_child(base)
	var petal_m := mat(Color(0.55, 0.3, 0.2), 0.6, 0.3)
	var cell_m := mat(Color(0.12, 0.14, 0.2), 0.3, 0.5)
	var petals := []
	for i in 3:
		var pv := Node3D.new()
		pv.rotation.y = i * TAU / 3.0
		base.add_child(pv)
		var pet := Node3D.new()
		pet.position = Vector3(0, 0.15, 0.55)
		pv.add_child(pet)
		var tri := cyl(pet, 0.0, 1.2, 0.06, Vector3(0, 0, 0.6), petal_m, 3)
		tri.rotation.y = PI
		cyl(pet, 0.0, 1.05, 0.065, Vector3(0, 0.01, 0.6), cell_m, 3).rotation.y = PI
		pet.rotation.x = -1.2
		petals.append(pet)
	cyl(base, 0.55, 0.55, 0.3, Vector3(0, 0.15, 0), mat(Color(0.8, 0.78, 0.72), 0.5, 0.4), 3)
	for i in 5:
		# the airbags pulled in lie in low heaps behind the lander (the camera and the ramp are in front, toward +z)
		var a := PI * 0.55 + i * PI * 0.22
		var heap := ball(base, rng.randf_range(0.22, 0.3), Vector3(sin(a) * 1.9, 0.1, cos(a) * 1.9), mat(Color(0.74, 0.7, 0.62), 1.0), Vector3(1.3, 0.6, 1.0))
		heap.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		heap.name = "Heap%d" % i
	var ramp := Node3D.new()
	ramp.name = "Ramp"
	# the rear ramp: from the petal's edge (about 0.19 m up) down to the ground, tilted 20 degrees (S-mpf-nasa), so
	# its far end rests on the ground; its length follows from those two (0.19 / sin 20 = 0.55 m)
	ramp.position = Vector3(0, RAMP_LEN * sin(deg_to_rad(20.0)), 1.65)
	base.add_child(ramp)
	for sx in [-0.17, 0.17]:
		var rail := box(ramp, Vector3(0.05, 0.03, RAMP_LEN), Vector3(sx, 0, RAMP_LEN * 0.5), mat(Color(0.75, 0.75, 0.78), 0.4, 0.7))
		rail.name = "Rail"
	ramp.rotation.x = deg_to_rad(20.0)
	var rover := Node3D.new()
	rover.name = "Sojourner"
	base.add_child(rover)
	box(rover, Vector3(0.48, 0.12, 0.62), Vector3(0, 0.2, 0), mat(Color(0.85, 0.82, 0.7), 0.5, 0.4))
	box(rover, Vector3(0.48, 0.02, 0.62), Vector3(0, 0.27, 0), cell_m)
	var wheel_m := mat(Color(0.55, 0.56, 0.6), 0.35, 0.8)
	var bar_m := mat(Color(0.7, 0.7, 0.72), 0.4, 0.7)
	for sx in [-0.29, 0.29]:
		for wz in [-0.25, 0.0, 0.25]:
			var wh := cyl(rover, 0.065, 0.065, 0.09, Vector3(sx, 0.065, wz), wheel_m, 16)
			wh.rotation.z = PI / 2
			for k in 6:
				var cleat := box(rover, Vector3(0.095, 0.012, 0.02), Vector3(sx, 0.065, wz) + Vector3(0, sin(k * PI / 3.0), cos(k * PI / 3.0)) * 0.066, mat(Color(0.3, 0.3, 0.32), 0.6))
				cleat.rotation.x = -k * PI / 3.0
		# the rocker-bogie: bars from the body down to the wheels
		rope(rover, Vector3(sx * 0.85, 0.2, -0.05), Vector3(sx, 0.07, -0.25), 0.012, bar_m)
		rope(rover, Vector3(sx * 0.85, 0.2, -0.05), Vector3(sx, 0.14, 0.12), 0.012, bar_m)
		rope(rover, Vector3(sx, 0.14, 0.12), Vector3(sx, 0.07, 0.0), 0.012, bar_m)
		rope(rover, Vector3(sx, 0.14, 0.12), Vector3(sx, 0.07, 0.25), 0.012, bar_m)
	rope(rover, Vector3(0.18, 0.28, -0.2), Vector3(0.18, 0.55, -0.22), 0.006, bar_m)
	ball(rover, 0.015, Vector3(0.18, 0.56, -0.22), bar_m)
	rover.position = Vector3(0, RAMP_LEN * sin(deg_to_rad(20.0)) + 0.01, 1.25)
	return {
		"marks": marks({"inti": [-1.1, 0.0, 1.0, 40], "killa": [1.2, 0.0, 0.9, -40], "rumi": [-1.55, 0.0, 1.45, 55], "wayra": [1.1, 0.0, -0.8, -30]}),
		"actor_scale": 0.3,
		"cast": ["rumi", "killa", "inti"],
		"cams": {
			"wide": {"from": Vector3(1.4, 0.9, 3.6), "to": Vector3(0, 0.25, 0)},
			"plain": {"from": Vector3(-6, 3, 14), "to": Vector3(60, 8, -40), "from2": Vector3(-3, 1.6, 6), "to2": Vector3(0, 0.3, 0), "time": 7.0},
		},
		"act": "idle",
		"craft": craft,
		"shell": shell,
		"chute": chute,
		"rockets": rockets,
		"bridle": bridle,
		"lander": lander,
		"airbags": bag,
		"base": base,
		"petals": petals,
		"ramp": ramp,
		"rover": rover,
		"rocks": rocks,
	}


# ===================================================================================== MARS AHEAD
## Seven months out, Mars ahead: the cruise stage (solar cells on a ring) over the aeroshell that hides the lander,
## the crew floating beside it at their true size (one unit is one metre; the cuyes are about 30 cm).
const RAMP_LEN := 0.55               ## Mars Pathfinder's rear ramp in the set (m): petal edge to the ground at 20 deg.
const CABIN := Vector3(40, 0, 40)    ## Where the room inside the folded lander sits, apart from the craft outside.


static func _mars_approach(world, env: Environment) -> Dictionary:
	var st: Node3D = world.stage
	env.sky = Space.make_space_sky()
	env.background_energy_multiplier = 1.0
	env.glow_enabled = true
	env.ambient_light_color = Color(0.6, 0.6, 0.7)
	env.ambient_light_energy = 0.35
	world.sun.light_energy = 1.5
	world.sun.light_color = Color(1.0, 0.97, 0.92)
	world.sun.rotation_degrees = Vector3(-20, 140, 0)
	world.cam.far = 6000.0
	var planet := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 300.0
	sm.height = 600.0
	sm.radial_segments = 96
	sm.rings = 48
	planet.mesh = sm
	planet.material_override = shader_mat("""
shader_type spatial;
varying vec3 lp;
float h(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float n(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1,0,0)), f.x), mix(h(i + vec3(0,1,0)), h(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h(i + vec3(0,0,1)), h(i + vec3(1,0,1)), f.x), mix(h(i + vec3(0,1,1)), h(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() { lp = VERTEX / 300.0; }
void fragment() {
	float a = n(lp * 3.0) * 0.55 + n(lp * 9.0) * 0.3 + n(lp * 27.0) * 0.15;
	vec3 c = mix(vec3(0.42, 0.22, 0.13), vec3(0.78, 0.48, 0.3), smoothstep(0.3, 0.75, a));
	c = mix(c, vec3(0.95, 0.93, 0.9), smoothstep(0.82, 0.9, abs(lp.y)));
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
""")
	planet.position = Vector3(-260, -60, -900)
	st.add_child(planet)
	var craft := Node3D.new()
	craft.name = "Cruise"
	st.add_child(craft)
	var spin := Node3D.new()
	craft.add_child(spin)
	# the cruise stage: a ring of solar cells with a metal rim and struts
	cyl(spin, 1.3, 1.3, 0.12, Vector3(0, 0.45, 0), mat(Color(0.75, 0.75, 0.78), 0.4, 0.7), 48)
	cyl(spin, 1.24, 1.24, 0.03, Vector3(0, 0.52, 0), mat(Color(0.1, 0.13, 0.25), 0.25, 0.6), 48)
	for i in 12:
		var a := i * TAU / 12.0
		var strip := box(spin, Vector3(0.02, 0.035, 1.2), Vector3(sin(a) * 0.62, 0.53, cos(a) * 0.62), mat(Color(0.85, 0.65, 0.25), 0.4, 0.8))
		strip.rotation.y = a
	cyl(spin, 0.18, 0.18, 0.4, Vector3(0, 0.75, 0), mat(Color(0.7, 0.7, 0.72), 0.4, 0.7), 16)
	var dish := ball(spin, 0.28, Vector3(0, 1.0, 0), mat(Color(0.92, 0.92, 0.9), 0.4), Vector3(1, 0.3, 1))
	dish.name = "Dish"
	# the backshell and the heat shield, the lander folded inside
	cyl(spin, 0.4, 1.32, 0.9, Vector3(0, -0.05, 0), mat(Color(0.86, 0.84, 0.78), 0.45, 0.3), 48)
	cyl(spin, 1.33, 1.05, 0.28, Vector3(0, -0.62, 0), mat(Color(0.42, 0.27, 0.17), 0.85), 48)
	craft.rotation = Vector3(0.35, 0, 0.25)
	# the glow of entry, wrapped around the heat shield (shown by the story's "fireball")
	# a soft glow facing the camera, hot at its heart, and a trail of fading glows behind the craft; one material, so
	# the story's fade (its alpha) drives them all (#97: it read as a flat orange egg with stars showing through)
	var plasma := MeshInstance3D.new()
	var pq := QuadMesh.new()
	pq.size = Vector2(3.4, 3.4)
	plasma.mesh = pq
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pmat.billboard_keep_scale = true
	pmat.albedo_texture = soft_glow()
	pmat.albedo_color = Color(1.0, 0.5, 0.18, 0.0)
	plasma.material_override = pmat
	plasma.position = Vector3(0, -1.5, 0)
	plasma.scale = Vector3(1.5, 2.0, 1.5)
	craft.add_child(plasma)
	for i in 5:
		var tq := MeshInstance3D.new()
		var tm := QuadMesh.new()
		tm.size = Vector2(1.0, 1.0) * (2.8 - i * 0.4)
		tq.mesh = tm
		tq.material_override = pmat
		tq.position = Vector3(0, 0.9 + i * 0.85, 0)
		plasma.add_child(tq)
	# inside: the crew ride in the folded lander, a small warm room among the airbags and the folded petals, a little
	# window toward Mars (the room sits apart from the craft drawn outside, so each shot shows one or the other)
	var room := Node3D.new()
	room.position = CABIN
	st.add_child(room)
	var lining := mat(Color(0.86, 0.82, 0.72), 0.95)
	var petal := mat(Color(0.55, 0.3, 0.2), 0.6, 0.3)
	var n := 14
	for i in n:
		var ang := i * TAU / n
		var dir := Vector3(sin(ang), 0, cos(ang))
		# the window: an opening on the side that faces Mars (toward -z)
		if dir.z < -0.85:
			continue
		var panel := box(room, Vector3(0.52, 1.3, 0.06), dir * 1.1 + Vector3(0, 0.6, 0), lining if i % 3 != 0 else petal)
		panel.look_at_from_position(panel.position + room.position, room.position + Vector3(0, 0.6, 0), Vector3.UP)
	cyl(room, 1.15, 1.15, 0.06, Vector3(0, -0.03, 0), mat(Color(0.4, 0.38, 0.36), 0.7, 0.4), 32)
	cyl(room, 1.15, 1.15, 0.06, Vector3(0, 1.28, 0), lining, 32)
	var frame := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.24
	tm.outer_radius = 0.32
	frame.mesh = tm
	frame.material_override = mat(Color(0.6, 0.6, 0.64), 0.4, 0.7)
	frame.position = Vector3(0, 0.62, -1.08)
	frame.rotation.x = PI / 2
	room.add_child(frame)
	box(room, Vector3(0.9, 0.5, 0.06), Vector3(0, 1.05, -1.1), lining)
	box(room, Vector3(0.9, 0.32, 0.06), Vector3(0, 0.16, -1.1), lining)
	box(room, Vector3(0.3, 0.45, 0.06), Vector3(-0.45, 0.62, -1.1), lining)
	box(room, Vector3(0.3, 0.45, 0.06), Vector3(0.45, 0.62, -1.1), lining)
	for i in 5:
		var aa := 0.6 + i * 1.0
		ball(room, 0.22, Vector3(sin(aa) * 0.85, 0.2, cos(aa) * 0.85), lining, Vector3(1.4, 0.8, 1.0))
	var cabin_light := omni(room, Vector3(0, 1.0, 0.2), Color(1.0, 0.82, 0.6), 1.1, 3.0)
	# the window's glow when the craft enters the atmosphere (the story's "heat")
	var glow := MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(0.5, 0.5)
	glow.mesh = gq
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(1.0, 0.45, 0.12, 0.0)
	glow.material_override = gm
	glow.position = Vector3(0, 0.62, -1.06)
	room.add_child(glow)
	var heat_light := omni(room, Vector3(0, 0.62, -0.8), Color(1.0, 0.45, 0.15), 0.0, 3.0)
	return {
		"marks": marks({"inti": [CABIN.x - 0.35, 0.0, CABIN.z + 0.1, 180], "killa": [CABIN.x + 0.05, 0.0, CABIN.z - 0.15, 180], "rumi": [CABIN.x + 0.4, 0.0, CABIN.z + 0.15, 180], "wayra": [0, 0, 3, 0]}),
		"cast": ["rumi", "killa", "inti"],
		"actor_scale": 0.3,
		"cams": {
			"wide": {"from": CABIN + Vector3(0.2, 0.75, -0.85), "to": CABIN + Vector3(0, 0.3, 0.2)},
			"window": {"from": CABIN + Vector3(0.15, 0.6, 0.8), "to": CABIN + Vector3(0, 0.55, -1.1), "from2": CABIN + Vector3(0.05, 0.62, 0.2), "to2": Vector3(-260, -60, -900), "time": 6.0},
			"approach": {"from": Vector3(2.5, 1.8, 4.5), "to": Vector3(0, 0.5, 0), "from2": Vector3(1.4, 1.2, 2.6), "to2": Vector3(-260, -60, -900), "time": 7.0},
			"behind": {"from": Vector3(0.6, 2.4, 3.2), "to": Vector3(-260, -60, -900)},
			"entry": {"from": Vector3(4.5, 2.0, 3.5), "to": Vector3(0, 0, 0), "track": "cruise", "offset": Vector3.ZERO},
		},
		"act": "idle",
		"cruise": craft,
		"cruise_spin": spin,
		"plasma": plasma,
		"cabin_light": cabin_light,
		"heat_light": heat_light,
		"window_glow": glow,
	}


# ===================================================================================== THE CREW'S SHIP
## Where the crew stand to be met (The crew screen): the bay of a spaceship, our own design, not a real craft. A metal
## floor, ribs along the hull, consoles with screens at the sides, light strips above, and a wide window behind with
## the Earth below and the stars. The crew stand on the floor (y 0) along x.
static func _crew_ship(world, env: Environment) -> Dictionary:
	var st: Node3D = world.stage
	env.sky = Space.make_space_sky()
	env.background_energy_multiplier = 1.0
	env.glow_enabled = true
	env.ambient_light_color = Color(0.55, 0.62, 0.78)
	env.ambient_light_energy = 0.45
	world.sun.light_energy = 1.2
	world.sun.light_color = Color(1.0, 0.95, 0.88)
	world.sun.rotation_degrees = Vector3(-25, 30, 0)
	world.cam.far = 3000.0
	var hull := mat(Color(0.32, 0.35, 0.4), 0.55, 0.6)
	var dark := mat(Color(0.12, 0.13, 0.16), 0.6, 0.4)
	var trim := mat(Color(1.0, 0.66, 0.26), 0.4, 0.2, 1.4)
	var bay := Node3D.new()
	st.add_child(bay)
	# the floor: plates with a lit edge
	box(bay, Vector3(16, 0.2, 9), Vector3(0, -0.1, -1.0), dark)
	for i in 8:
		box(bay, Vector3(1.9, 0.02, 7.5), Vector3(-7.0 + i * 2.0, 0.01, -1.0), hull)
	box(bay, Vector3(16, 0.03, 0.06), Vector3(0, 0.02, 2.6), trim)
	# the back wall with the wide window: four pieces around the opening, a frame
	var wall_z := -4.2
	box(bay, Vector3(16, 1.0, 0.3), Vector3(0, 0.5, wall_z), hull)
	box(bay, Vector3(16, 1.2, 0.3), Vector3(0, 4.4, wall_z), hull)
	box(bay, Vector3(2.0, 5.0, 0.3), Vector3(-7.0, 2.5, wall_z), hull)
	box(bay, Vector3(2.0, 5.0, 0.3), Vector3(7.0, 2.5, wall_z), hull)
	for x in [-6.0, -3.0, 0.0, 3.0, 6.0]:
		box(bay, Vector3(0.18, 2.8, 0.36), Vector3(x, 2.4, wall_z), dark)
	box(bay, Vector3(12.2, 0.12, 0.4), Vector3(0, 1.0, wall_z + 0.05), trim)
	# ribs along the hull, and the ceiling with its light strips
	for x in [-7.5, -5.0, -2.5, 0.0, 2.5, 5.0, 7.5]:
		box(bay, Vector3(0.3, 5.0, 0.3), Vector3(x, 2.5, -3.9), dark)
		box(bay, Vector3(0.3, 0.3, 7.0), Vector3(x, 5.0, -0.6), dark)
	box(bay, Vector3(16, 0.2, 7.5), Vector3(0, 5.2, -0.6), hull)
	for z in [-2.4, 0.4]:
		box(bay, Vector3(14, 0.05, 0.25), Vector3(0, 5.08, z), mat(Color(0.85, 0.92, 1.0), 0.3, 0.0, 2.2))
	# consoles at the sides, their screens alive
	var screen := shader_mat("""
shader_type spatial;
render_mode unshaded;
uniform float seed = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453); }
void fragment() {
	float row = floor(UV.y * 10.0);
	float on = step(0.4, h(vec2(row, floor(UV.x * 20.0)))) * step(0.15, fract(UV.y * 10.0)) * step(fract(UV.y * 10.0), 0.7);
	on *= step(h(vec2(row, 2.0)) * 0.8, UV.x);
	vec3 tint = mix(vec3(0.47, 0.72, 1.0), vec3(1.0, 0.66, 0.26), step(0.8, h(vec2(row, 7.0))));
	ALBEDO = tint * (0.1 + on * 0.9);
	EMISSION = tint * on * 0.9;
}
""")
	for sx in [-1, 1]:
		var desk := Node3D.new()
		desk.position = Vector3(sx * 5.6, 0, -1.6)
		desk.rotation.y = -sx * 0.5
		bay.add_child(desk)
		box(desk, Vector3(2.4, 1.0, 0.9), Vector3(0, 0.5, 0), hull)
		var top := box(desk, Vector3(2.4, 0.08, 0.9), Vector3(0, 1.05, 0.1), dark)
		top.rotation.x = 0.35
		for k in 2:
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(1.0, 0.6)
			q.mesh = qm
			var sm := screen.duplicate() as ShaderMaterial
			sm.set_shader_parameter("seed", float(k + (sx + 1) * 3))
			q.material_override = sm
			q.position = Vector3(-0.55 + k * 1.1, 1.65, -0.3)
			q.rotation.x = -0.25
			desk.add_child(q)
	# the Earth outside, below the window, and the stars of the sky
	var earth: Node3D = Space.make_earth(40.0, false)
	earth.position = Vector3(10, -34, -95)
	st.add_child(earth)
	world.planet = earth
	omni(bay, Vector3(0, 4.2, 1.0), Color(0.9, 0.95, 1.0), 1.4, 12.0)
	omni(bay, Vector3(0, 1.5, 3.0), Color(1.0, 0.85, 0.7), 0.6, 8.0)
	return {"marks": {}, "cast": [], "cams": {}, "act": "idle"}


# ===================================================================================== THE PACIFIC
## Splashdown near Samoa: an ocean that moves, a recovery ship far away, the command module coming down under three
## parachutes, and a raft where the crew wait.
static func _ocean(world, env: Environment) -> Dictionary:
	var st: Node3D = world.stage
	Space.apply_day(env)
	env.sky = low_sky()
	env.glow_enabled = false
	env.fog_density = 0.00025   # a low camera over water: little haze, or sea and ship wash out white (#97)
	env.fog_light_color = Color(0.55, 0.7, 0.88)
	env.ambient_light_color = Color(0.7, 0.78, 0.9)
	env.ambient_light_energy = 0.65
	world.sun.light_energy = 1.05
	env.ambient_light_energy = 0.45
	world.sun.light_color = Color(1.0, 0.96, 0.88)
	world.sun.rotation_degrees = Vector3(-30, 40, 0)
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2400, 2400)
	pm.subdivide_width = 260
	pm.subdivide_depth = 260
	water.mesh = pm
	water.material_override = shader_mat("""
shader_type spatial;
render_mode cull_disabled;
varying vec3 wp;
float wave(vec2 p, vec2 d, float f, float a, float s) { return a * sin(dot(p, d) * f + TIME * s); }
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float hgt = wave(w.xz, normalize(vec2(1.0, 0.3)), 0.35, 0.16, 1.1) + wave(w.xz, normalize(vec2(-0.4, 1.0)), 0.6, 0.08, 1.7)
		+ wave(w.xz, normalize(vec2(0.7, -0.8)), 1.3, 0.035, 2.4);
	VERTEX.y += hgt;
	wp = w;
}
void fragment() {
	vec3 n = normalize(cross(dFdx(wp), dFdy(wp)));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	float crest = smoothstep(0.12, 0.2, wp.y);
	ALBEDO = mix(mix(vec3(0.01, 0.14, 0.28), vec3(0.08, 0.32, 0.5), fres), vec3(0.85, 0.9, 0.95), crest * 0.5);
	ROUGHNESS = 0.22;
	SPECULAR = 0.3;   // the deep Pacific blue, not a mirror of the pale sky
}
""")
	st.add_child(water)
	# the recovery ship on the horizon
	var grey := mat(Color(0.5, 0.52, 0.55), 0.8, 0.2)
	var ship := Node3D.new()
	ship.position = Vector3(-140, 0, -420)
	ship.rotation.y = 0.3
	st.add_child(ship)
	# USS Iwo Jima: a flat-topped helicopter carrier, a grey hull, a darker deck, the island to starboard, a pointed bow
	box(ship, Vector3(180 / 2.0, 10, 30 / 2.0), Vector3(0, 4, 0), grey)
	box(ship, Vector3(180 / 2.0, 1, 34 / 2.0), Vector3(0, 9.5, 0), mat(Color(0.32, 0.33, 0.35), 0.9))
	box(ship, Vector3(14, 14, 5), Vector3(20, 17, 6), grey)
	box(ship, Vector3(6, 10, 3), Vector3(22, 28, 6), grey)
	var bow := box(ship, Vector3(14, 10, 14), Vector3(-45, 4, 0), grey, Vector3(0, PI / 4.0, 0))
	bow.scale.z = 0.75
	box(ship, Vector3(184 / 2.0, 1.2, 31 / 2.0), Vector3(0, 0.6, 0), mat(Color(0.25, 0.08, 0.06), 0.9))   # the red waterline
	# the command module, coming down under its parachutes
	var cm := Node3D.new()
	cm.name = "Capsule"
	cm.position = Vector3(-16, 0, -26)
	st.add_child(cm)
	var shell := mat(Color(0.5, 0.42, 0.32), 0.6, 0.3)   # scorched by the re-entry, not a mirror of the sky
	cyl(cm, 0.35 * K, 1.95 * K, 3.2 * K, Vector3(0, 1.6 * K - 0.8, 0), shell, 48)
	cyl(cm, 1.98 * K, 1.9 * K, 0.4 * K, Vector3(0, -0.8, 0), mat(Color(0.3, 0.24, 0.18), 0.9), 48)
	var collar := MeshInstance3D.new()
	var ct := TorusMesh.new()
	ct.inner_radius = 1.85 * K
	ct.outer_radius = 2.25 * K
	collar.mesh = ct
	collar.material_override = mat(Color(0.95, 0.55, 0.1), 0.7)
	collar.position.y = -0.3
	cm.add_child(collar)
	var chutes := Node3D.new()
	chutes.name = "Chutes"
	chutes.position.y = 3.2 * K
	cm.add_child(chutes)
	var canopy_m := shader_mat("""
shader_type spatial;
render_mode cull_disabled;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float a = atan(lp.z, lp.x);
	float band = step(0.5, fract(a / 6.2831 * 12.0));
	ALBEDO = mix(vec3(0.95, 0.94, 0.9), vec3(0.85, 0.2, 0.15), band);
	ROUGHNESS = 0.9;
}
""")
	var line_m := mat(Color(0.9, 0.9, 0.85), 0.8)
	for i in 3:
		var c := Node3D.new()
		var ang := i * TAU / 3.0
		c.position = Vector3(sin(ang) * 9.0, 36.0, cos(ang) * 9.0)
		chutes.add_child(c)
		var dome := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 9.0
		sm.height = 9.0
		sm.is_hemisphere = true
		dome.mesh = sm
		dome.material_override = canopy_m
		c.add_child(dome)
		for l in 8:
			var la := l * TAU / 8.0
			rope(c, Vector3(sin(la) * 8.8, 0, cos(la) * 8.8), -c.position, 0.04, line_m)
	# the raft: a yellow ring where the cuyes stand
	var raft := Node3D.new()
	raft.position = Vector3(1.0, 0, 0)
	st.add_child(raft)
	var rim := MeshInstance3D.new()
	var rt := TorusMesh.new()
	rt.inner_radius = 1.45
	rt.outer_radius = 1.9
	rim.mesh = rt
	rim.material_override = mat(Color(0.95, 0.62, 0.12), 0.7)
	rim.position.y = 0.15
	raft.add_child(rim)
	cyl(raft, 1.6, 1.6, 0.1, Vector3(0, 0.03, 0), mat(Color(0.9, 0.55, 0.1), 0.8), 32)
	var splash := Space.make_pad_smoke()
	splash.direction = Vector3(0, 1, 0)
	splash.spread = 60.0
	splash.scale = Vector3.ONE * 3.0
	splash.position = Vector3(-16, 0, -26)
	st.add_child(splash)
	return {
		"marks": marks({"killa": [0.9, 0.1, 0.35, -10], "inti": [1.7, 0.1, -0.2, -20], "rumi": [0.15, 0.1, 0.2, 15], "wayra": [1.4, 0.1, 0.9, -30]}),
		"cast": ["rumi", "killa", "inti"],
		"cams": {
			"wide": {"from": Vector3(3.2, 1.5, 6.5), "to": Vector3(-2.5, 1.6, -8)},
			"descent": {"from": Vector3(20, 3, 45), "to": Vector3(-16, 30, -26), "track": "capsule", "offset": Vector3(0, 16, 0)},
		},
		"act": "idle",
		"capsule": cm,
		"chutes": chutes,
		"splash": splash,
		"raft": raft,
	}


# ===================================================================================== LCROSS ON THE WAY TO THE MOON
## LCROSS, October 2009: the shepherding craft riding on the empty Centaur upper stage, the Moon's south pole ahead
## (its real map, assets/textures/moon_color.jpg, S-moon-kit), the Sun low. Shapes only, no markings. The Centaur is about
## 3 m wide and 12.7 m long (a set, not a model to measure); the shepherding craft is a ring with its instruments.
## A second pair farther off, apart, for the separation shot (each shot shows one or the other). Nobody is on board:
## the crew fly it from mission control.
static func _lcross_stack(parent: Node3D, at: Vector3, apart: float) -> Node3D:
	var root := Node3D.new()
	root.position = at
	parent.add_child(root)
	var foil := mat(Color(0.86, 0.84, 0.8), 0.35, 0.6)
	var dark := mat(Color(0.2, 0.2, 0.22), 0.6, 0.4)
	var centaur := Node3D.new()
	root.add_child(centaur)
	cyl(centaur, 5.0, 5.0, 34.0, Vector3(0, 0, 0), foil, 32)
	cyl(centaur, 5.0, 3.2, 4.0, Vector3(0, -19.0, 0), dark, 32)
	cyl(centaur, 1.4, 2.6, 4.5, Vector3(0, -23.0, 0), mat(Color(0.35, 0.33, 0.32), 0.5, 0.7), 24)
	cyl(centaur, 4.2, 5.0, 2.0, Vector3(0, 18.0, 0), dark, 32)
	var shep := Node3D.new()
	shep.position = Vector3(0, 21.5 + apart, 0)
	root.add_child(shep)
	cyl(shep, 3.0, 3.0, 2.2, Vector3.ZERO, mat(Color(0.7, 0.7, 0.72), 0.4, 0.7), 24)
	for i in 6:
		var ang := i * TAU / 6.0
		var b := box(shep, Vector3(2.0, 2.0, 1.4), Vector3(sin(ang) * 3.4, 0, cos(ang) * 3.4), mat(Color(0.82, 0.68, 0.3), 0.4, 0.8) if i % 2 == 0 else foil)
		b.rotation.y = ang
	# the instruments' little cameras on top, looking ahead
	for i in 4:
		cyl(shep, 0.35, 0.35, 0.9, Vector3(-1.2 + i * 0.8, 1.5, 0.6), dark, 12)
	box(shep, Vector3(6.0, 0.15, 3.0), Vector3(0, 1.2, -2.6), mat(Color(0.1, 0.13, 0.25), 0.25, 0.6))
	# the shepherding craft's engine glow, for its delay burn after separation
	var burn := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(5.0, 5.0)
	burn.mesh = bq
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bm.albedo_texture = soft_glow()
	bm.albedo_color = Color(0.6, 0.8, 1.0, 0.0)
	burn.material_override = bm
	burn.position = Vector3(0, 2.2, 0)
	burn.name = "Burn"
	shep.add_child(burn)
	shep.name = "Shepherd"
	root.rotation = Vector3(-1.2, 0.5, 0.0)
	return root


static func _lcross_space(world, env: Environment) -> Dictionary:
	var st: Node3D = world.stage
	env.sky = Space.make_space_sky()
	env.background_energy_multiplier = 1.0
	env.glow_enabled = true
	env.ambient_light_color = Color(0.55, 0.58, 0.7)
	env.ambient_light_energy = 0.3
	world.sun.light_energy = 1.6
	world.sun.light_color = Color(1.0, 0.97, 0.93)
	world.sun.rotation_degrees = Vector3(-8, 75, 0)
	world.cam.far = 9000.0
	var moon := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 900.0
	sm.height = 1800.0
	sm.radial_segments = 128
	sm.rings = 64
	moon.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.albedo_texture = Space.MOON_COLOR
	mm.albedo_color = Color(0.8, 0.8, 0.8)
	mm.roughness = 1.0
	moon.material_override = mm
	moon.position = Vector3(0, -1150, -1500)
	moon.rotation = Vector3(-0.9, 0, 0)
	st.add_child(moon)
	var stack := _lcross_stack(st, Vector3.ZERO, 0.0)
	var apart := _lcross_stack(st, Vector3(400, 0, 0), 0.0)
	# the flash of the Centaur's impact, far below at the south pole (the story's "moonflash")
	# on the shadowed side, where Cabeus lies in the dark: the flash stands out
	var at := moon.position + Vector3(-0.5, 0.72, 0.48).normalized() * 902.0
	var flash := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(90, 90)
	flash.mesh = fq
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.albedo_texture = soft_glow()
	fm.no_depth_test = true
	fm.albedo_color = Color(1.0, 0.92, 0.75, 0.0)
	flash.material_override = fm
	flash.position = at
	st.add_child(flash)
	return {
		"marks": marks({"inti": [0, 0, 600, 0], "killa": [2, 0, 600, 0], "rumi": [4, 0, 600, 0], "wayra": [6, 0, 600, 0]}),
		"cast": [],
		"cams": {
			"approach": {"from": Vector3(60, 30, 80), "to": Vector3(0, -200, -1500), "from2": Vector3(35, 12, 55), "to2": Vector3(0, -300, -1500), "time": 7.0},
			"stack": {"from": Vector3(40, 22, 45), "to": Vector3(0, 5, 0), "from2": Vector3(28, 8, 52), "to2": Vector3(0, 0, 0), "time": 8.0},
			"separate": {"from": Vector3(470, 25, 70), "to": Vector3(400, 0, 0), "from2": Vector3(455, 8, 60), "to2": Vector3(400, -10, -20), "time": 6.0},
			"far": {"from": at + Vector3(160, 260, 520), "to": at, "from2": at + Vector3(110, 170, 340), "to2": at, "time": 6.0},
		},
		"sep_shep": apart.get_node("Shepherd"),
		"sep_burn": apart.get_node("Shepherd/Burn"),
		"moon_flash": flash,
		"act": "idle",
		"stack": stack,
		"apart": apart,
	}


# ===================================================================================== DART AT THE TWIN ASTEROIDS
## DART, September 2022: the craft (a box with two long solar wings and its camera's tube, shapes only, no markings)
## closing on Dimorphos (160 m) and Didymos (780 m) [S-dart-nasa]; the little LICIACube behind it. One unit is
## about 0.3 m, so the asteroids are huge beside the craft, as they were. The distance between the asteroids is ours.
## "moon_flash" and "ejecta" are the impact the story shows (its "moonflash").
static func rock_mat(seed: float) -> ShaderMaterial:
	return shader_mat("""
shader_type spatial;
uniform float seed = %f;
varying vec3 lp;
float h(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719)) + seed) * 43758.5453); }
float n(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1,0,0)), f.x), mix(h(i + vec3(0,1,0)), h(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h(i + vec3(0,0,1)), h(i + vec3(1,0,1)), f.x), mix(h(i + vec3(0,1,1)), h(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float lumps(vec3 p) { return n(p * 2.0) * 0.5 + n(p * 5.0) * 0.3 + n(p * 13.0) * 0.2; }
void vertex() {
	lp = VERTEX;
	VERTEX += NORMAL * (lumps(normalize(VERTEX) * 3.0) - 0.5) * 0.28 * length(VERTEX);
}
// a rubble pile: boulders of many sizes, each a lit dome with a shadow on its far side
vec2 cellp(vec3 p, out float rad) {
	vec3 i = floor(p);
	float best = 9.0; float r = 0.0; vec2 out_v = vec2(9.0, 0.0);
	for (int z = -1; z <= 1; z++) for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec3 c = i + vec3(float(x), float(y), float(z));
		vec3 o = vec3(h(c), h(c + 7.1), h(c + 3.3));
		float rr = 0.25 + 0.3 * h(c + 11.0);
		float d = length(p - c - o) / rr;
		if (d < best) { best = d; r = rr; out_v = vec2(d, (p - c - o).x / rr); }
	}
	rad = r;
	return out_v;
}
void fragment() {
	vec3 q = normalize(lp);
	float g = n(q * 9.0) * 0.6 + n(q * 23.0) * 0.4;
	float shade = 0.0;
	float rad;
	for (int k = 0; k < 3; k++) {
		float sc = 6.0 * pow(2.7, float(k));
		vec2 c = cellp(q * sc, rad);
		if (c.x < 1.0) {
			shade += (0.35 * (1.0 - c.x) - 0.45 * smoothstep(0.2, 0.9, c.y) * smoothstep(1.0, 0.7, c.x)) / float(k + 1);
		}
	}
	ALBEDO = vec3(0.32, 0.3, 0.28) * clamp(0.6 + 0.6 * g + shade, 0.15, 1.6);
	ROUGHNESS = 1.0;
}
""" % seed)


static func _dart_craft(parent: Node3D, at: Vector3, scale_: float) -> Node3D:
	var c := Node3D.new()
	c.position = at
	c.scale = Vector3.ONE * scale_
	parent.add_child(c)
	var foil := mat(Color(0.8, 0.66, 0.3), 0.35, 0.8)
	box(c, Vector3(4.0, 4.3, 4.3), Vector3.ZERO, foil)
	cyl(c, 0.7, 0.7, 2.4, Vector3(0, 0, -3.2), mat(Color(0.2, 0.2, 0.22), 0.4, 0.6), 16).rotation.x = PI / 2
	var cell := mat(Color(0.1, 0.12, 0.25), 0.25, 0.6)
	for sx in [-1.0, 1.0]:
		var wing := box(c, Vector3(26.0, 0.12, 4.0), Vector3(sx * 15.5, 0, 0.6), cell)
		wing.rotation.z = 0.05 * sx
		box(c, Vector3(26.0, 0.18, 0.2), Vector3(sx * 15.5, 0.02, 2.6), mat(Color(0.7, 0.7, 0.72), 0.4, 0.7))
	return c


static func _dart_space(world, env: Environment) -> Dictionary:
	var st: Node3D = world.stage
	env.sky = Space.make_space_sky()
	env.background_energy_multiplier = 1.0
	env.glow_enabled = true
	env.ambient_light_color = Color(0.5, 0.52, 0.6)
	env.ambient_light_energy = 0.25
	world.sun.light_energy = 1.8
	world.sun.light_color = Color(1.0, 0.97, 0.93)
	world.sun.rotation_degrees = Vector3(-25, 60, 0)
	world.cam.far = 20000.0
	# the pair: Didymos 780 m (2600 units), Dimorphos 160 m (533 units)
	var pair := Node3D.new()
	pair.position = Vector3(0, 0, -6000)
	st.add_child(pair)
	var did := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 1300.0
	dm.height = 2300.0
	dm.radial_segments = 96
	dm.rings = 48
	did.mesh = dm
	did.material_override = rock_mat(1.7)
	did.position = Vector3(-3500, -600, -2500)
	pair.add_child(did)
	var dimo := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 266.0
	mm.height = 230.0
	mm.radial_segments = 64
	mm.rings = 32
	dimo.mesh = mm
	dimo.material_override = rock_mat(4.2)
	pair.add_child(dimo)
	var dart := _dart_craft(st, Vector3(0, 0, 0), 1.0)
	dart.rotation.y = 0.15
	var licia := box(st, Vector3(0.7, 1.0, 1.4), Vector3(14, -4, 40), mat(Color(0.75, 0.75, 0.78), 0.4, 0.7))
	box(licia, Vector3(3.0, 0.05, 1.2), Vector3(0, 0, 0), mat(Color(0.1, 0.12, 0.25), 0.25, 0.6))
	# the impact on Dimorphos, toward the camera's side
	var hit_at := pair.position + Vector3(0, 40, 250)
	var flash := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(500, 500)
	flash.mesh = fq
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.albedo_texture = soft_glow()
	fm.no_depth_test = true
	fm.albedo_color = Color(1.0, 0.92, 0.75, 0.0)
	flash.material_override = fm
	flash.position = hit_at
	st.add_child(flash)
	var ej := CPUParticles3D.new()
	ej.emitting = false
	ej.one_shot = true
	ej.amount = 400
	ej.lifetime = 9.0
	ej.explosiveness = 0.85
	ej.direction = Vector3(0, 0.15, 1)
	ej.spread = 40.0
	ej.initial_velocity_min = 40.0
	ej.initial_velocity_max = 160.0
	ej.gravity = Vector3.ZERO
	ej.damping_min = 2.0
	ej.damping_max = 6.0
	ej.scale_amount_min = 4.0
	ej.scale_amount_max = 14.0
	var eq := QuadMesh.new()
	eq.size = Vector2(2, 2)
	ej.mesh = eq
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	em.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	em.albedo_texture = soft_glow()
	em.albedo_color = Color(0.85, 0.8, 0.72, 0.8)
	ej.material_override = em
	ej.position = hit_at
	st.add_child(ej)
	var dp := pair.position
	return {
		"marks": marks({"inti": [0, 0, 900, 0], "killa": [2, 0, 900, 0], "rumi": [4, 0, 900, 0], "wayra": [6, 0, 900, 0]}),
		"cast": [],
		"cams": {
			"approach": {"from": Vector3(25, 10, 45), "to": dp, "from2": Vector3(18, 6, 30), "to2": dp, "time": 7.0},
			"craft": {"from": Vector3(-55, 30, 70), "to": Vector3(0, 0, -6), "from2": Vector3(-40, 20, 52), "to2": Vector3(0, 0, -6), "time": 7.0},
			"pair": {"from": dp + Vector3(1500, 900, 5200), "to": dp + Vector3(-1500, -300, -1200), "from2": dp + Vector3(900, 500, 3900), "to2": dp + Vector3(-1200, -300, -1200), "time": 8.0},
			"licia": {"from": dp + Vector3(1100, 500, 1600), "to": hit_at + Vector3(0, 0, 300), "from2": dp + Vector3(700, 300, 1300), "to2": hit_at + Vector3(0, 0, 400), "time": 8.0},
		},
		"act": "idle",
		"moon_flash": flash,
		"ejecta": ej,
	}


# ===================================================================================== INSIDE ORION, ARTEMIS I
## Artemis I, 2022: inside Orion, no crew aboard but a manikin, Commander Moonikin Campos, in the commander's seat, in
## an orange survival suit [S-artemis-campos]; the cuyes ride hidden in his seat. Screens on the panel, four windows,
## the Moon or the Earth outside. Shapes only, no markings; one unit is about 0.3 m. "outside" is the body in the
## window (the story's "earthset": the Moon, then the Earth).
static func _orion_cabin(world, env: Environment) -> Dictionary:
	var st: Node3D = world.stage
	env.sky = Space.make_space_sky()
	env.background_energy_multiplier = 1.0
	env.ambient_light_color = Color(0.6, 0.62, 0.7)
	env.ambient_light_energy = 0.35
	world.sun.light_energy = 1.3
	world.sun.light_color = Color(1.0, 0.97, 0.92)
	world.sun.rotation_degrees = Vector3(-20, 40, 0)
	var room := Node3D.new()
	st.add_child(room)
	var wall := mat(Color(0.82, 0.83, 0.82), 0.8)
	var dark := mat(Color(0.08, 0.09, 0.1), 0.5)
	# the panel with three glass screens
	var panel := Node3D.new()
	panel.position = Vector3(0, 2.3, -4.2)
	panel.rotation.x = -0.35
	room.add_child(panel)
	box(panel, Vector3(6.4, 1.8, 0.3), Vector3.ZERO, mat(Color(0.25, 0.27, 0.3), 0.6, 0.3))
	for i in 3:
		box(panel, Vector3(1.7, 1.15, 0.05), Vector3((i - 1) * 2.05, 0.05, 0.17), mat([Color(0.15, 0.45, 0.8), Color(0.2, 0.7, 0.45), Color(0.85, 0.6, 0.2)][i], 0.3, 0.0, 0.9))
	# outside, apart from the room: Orion and its four wings over the Moon (each shot shows one or the other)
	var out := Node3D.new()
	out.position = Vector3(400, 0, 0)
	st.add_child(out)
	cyl(out, 1.8, 5.2, 3.6, Vector3(0, 1.8, 0), mat(Color(0.85, 0.86, 0.88), 0.45, 0.2), 32)
	cyl(out, 5.0, 5.0, 6.0, Vector3(0, -3.0, 0), mat(Color(0.82, 0.82, 0.84), 0.4, 0.5), 32)
	cyl(out, 1.2, 2.3, 2.6, Vector3(0, -7.3, 0), mat(Color(0.3, 0.3, 0.32), 0.4, 0.7), 16)
	for i in 4:
		var a := i * TAU / 4.0 + PI / 4.0
		var wing := box(out, Vector3(3.0, 0.15, 20.0), Vector3(sin(a) * 15.0, -4.0, cos(a) * 15.0), mat(Color(0.1, 0.12, 0.25), 0.25, 0.6))
		wing.rotation.y = a
	out.rotation = Vector3(0.5, 0.3, 1.2)
	var outside := bright_moon(260.0)
	outside.position = Vector3(400, -320, -700)
	st.add_child(outside)
	# the seats: the commander's, with Campos in it; two empty
	var seat_m := mat(Color(0.3, 0.32, 0.35), 0.8)
	for i in 3:
		box(room, Vector3(1.5, 0.3, 2.6), Vector3((i - 1) * 1.8, 0.0, 0.3), seat_m)
		var back_ := box(room, Vector3(1.5, 1.8, 0.3), Vector3((i - 1) * 1.8, 0.9, 1.6), seat_m)
		back_.rotation.x = 0.4
	# Commander Moonikin Campos: an orange suit, a white helmet with a dark visor
	var suit := mat(Color(0.95, 0.45, 0.12), 0.85)
	var c := Node3D.new()
	c.position = Vector3(0, 0.3, 0.6)
	room.add_child(c)
	ball(c, 0.55, Vector3(0, 0.75, 0.55), suit, Vector3(1.0, 1.4, 0.7))
	ball(c, 0.42, Vector3(0, 1.75, 0.75), mat(Color(0.95, 0.95, 0.95), 0.4))
	ball(c, 0.3, Vector3(0, 1.75, 0.45), mat(Color(0.05, 0.06, 0.08), 0.1, 0.6), Vector3(1.1, 0.8, 0.5))
	for sx in [-1.0, 1.0]:
		ball(c, 0.18, Vector3(sx * 0.55, 0.65, 0.3), suit, Vector3(1, 2.4, 1))
		ball(c, 0.2, Vector3(sx * 0.28, 0.2, -0.4), suit, Vector3(1, 1, 3.0))
	# the hull around
	var hull := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 2.2
	hm.bottom_radius = 5.5
	hm.height = 6.0
	hm.radial_segments = 48
	hm.cap_top = false
	hm.cap_bottom = false
	hull.mesh = hm
	var hullm := wall.duplicate() as StandardMaterial3D
	hullm.cull_mode = BaseMaterial3D.CULL_DISABLED
	hull.material_override = hullm
	hull.position = Vector3(0, 2.5, -0.8)
	hull.scale = Vector3(1.35, 1.0, 1.35)
	room.add_child(hull)
	box(room, Vector3(12, 0.2, 12), Vector3(0, -0.3, 0), dark)
	omni(room, Vector3(0, 4.5, 1.0), Color(1.0, 0.95, 0.88), 1.4, 9.0)
	omni(room, Vector3(0, 2.4, -2.0), Color(0.5, 0.75, 1.0), 0.6, 5.0)
	return {
		"marks": marks({"inti": [-1.0, 0.15, 0.1, 190], "killa": [0.0, 2.25, 1.35, 180], "rumi": [1.0, 0.15, 0.1, 170], "wayra": [6, 0, 6, 0]}),
		"cast": ["rumi", "killa", "inti"],
		"actor_scale": 0.55,
		"cams": {
			"wide": {"from": Vector3(1.6, 2.4, -3.4), "to": Vector3(0, 1.3, 0.6)},
			"campos": {"from": Vector3(0.5, 1.9, -1.9), "to": Vector3(0, 1.7, 0.9), "from2": Vector3(1.4, 2.3, -3.2), "to2": Vector3(0, 1.4, 0.8), "time": 6.0},
			"window": {"from": Vector3(470, 40, 110), "to": Vector3(400, -40, -200), "from2": Vector3(445, 25, 70), "to2": Vector3(400, -60, -300), "time": 7.0},
		},
		"act": "idle",
		"outside": outside,
	}
