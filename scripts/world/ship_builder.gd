extends RefCounted
## Builds the player's craft in 3D from the mission's choices: every part chosen shows. The bus is wrapped in gold
## multi-layer insulation with silver radiators; the components are modeled parts of assets/models/craft_kit.glb
## (assets/source/craft_kit.py), the CubeSats are assets/models/cubesat_3u.glb. Real geometry, simplified.

const SOLAR := preload("res://assets/shaders/solar_cell.gdshader")
const GLOW := preload("res://assets/shaders/engine_glow.gdshader")
const MLI := preload("res://assets/shaders/mli.gdshader")
const KIT := preload("res://assets/models/craft_kit.glb")
const CUBESAT := preload("res://assets/models/cubesat_3u.glb")

static var _kit: Node3D
static var _crinkle: NoiseTexture2D


static func mat(color: Color, metallic := 0.0, rough := 0.5, emission := Color.BLACK, cull_off := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = rough
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = 2.0
	if cull_off:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material, rot := Vector3.ZERO, node_name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = material
	if node_name != "":
		mi.name = node_name
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return add_mesh(parent, b, pos, material, rot)


static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = 24
	return add_mesh(parent, c, pos, material, rot)


static func solar_mat(back := false) -> ShaderMaterial:
	var s := ShaderMaterial.new()
	s.shader = SOLAR
	s.set_shader_parameter("cell_size", Vector2(0.12, 0.06))
	s.set_shader_parameter("back_face", 1.0 if back else 0.0)
	s.set_shader_parameter("cell_tex", _cell_texture())
	return s


static var _cells: ImageTexture
## One solar cell, 64 x 32 px: a dark blue cell with cropped corners and a thin busbar, a pale gap around it. Alpha
## marks the cell (1) from the gap (0), for the shader's shine.
static func _cell_texture() -> ImageTexture:
	if _cells == null:
		var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 64:
				var ex: int = mini(x, 63 - x)
				var ey: int = mini(y, 31 - y)
				var gap: bool = ex < 2 or ey < 2 or ex + ey < 7
				var bus: bool = absi(y - 16) <= 0 and not gap
				var c := Color(0.62, 0.62, 0.6, 0.0)
				if not gap:
					var n := 0.012 * sin(x * 1.7 + y * 0.9)
					c = Color(0.035 + n, 0.055 + n, 0.19 + n * 2.0, 1.0)
				if bus:
					c = Color(0.7, 0.7, 0.72, 0.0)
				img.set_pixel(x, y, c)
		img.generate_mipmaps()
		_cells = ImageTexture.create_from_image(img)
	return _cells


## Crinkled foil: a cellular noise turned into a normal map, made once.
static func mli_mat(color := Color(1.0, 0.7, 0.28)) -> ShaderMaterial:
	if _crinkle == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		n.frequency = 0.035
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 2
		_crinkle = NoiseTexture2D.new()
		_crinkle.width = 256
		_crinkle.height = 256
		_crinkle.seamless = true
		_crinkle.as_normal_map = true
		_crinkle.bump_strength = 6.0
		_crinkle.generate_mipmaps = true
		_crinkle.noise = n
	var s := ShaderMaterial.new()
	s.shader = MLI
	s.set_shader_parameter("foil", color)
	s.set_shader_parameter("crinkle", _crinkle)
	return s


## A modeled component of craft_kit.glb (a copy), standing on `pos` and pointing along `dir`, `size` units across;
## `stretch` lengthens it along `dir`, `spin` turns it about `dir`.
static func part(parent: Node3D, id: String, pos: Vector3, dir: Vector3, size: float, stretch := 1.0, spin := 0.0) -> Node3D:
	if _kit == null:
		_kit = KIT.instantiate()
	var src := _kit.get_node_or_null(id) as Node3D
	var n: Node3D = src.duplicate() if src else Node3D.new()
	n.name = id
	var up := dir.normalized()
	var ref := Vector3.FORWARD if absf(up.dot(Vector3.UP)) > 0.9 else Vector3.UP
	var x := ref.cross(up).normalized()
	var b := Basis(x, up, x.cross(up)).rotated(up, spin)
	n.transform = Transform3D(b.scaled_local(Vector3(size, size * stretch, size)), pos)
	parent.add_child(n)
	return n


static func dish(parent: Node3D, radius: float, pos: Vector3, rot: Vector3, color := Color(0.92, 0.92, 0.9)) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees = rot
	parent.add_child(holder)
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 0.7
	s.is_hemisphere = true
	s.radial_segments = 32
	s.rings = 8
	# la semiesfera apunta hacia arriba: la volteamos para que sea un plato abierto hacia +Y
	add_mesh(holder, s, Vector3(0, radius * 0.35, 0), mat(color, 0.2, 0.35, Color.BLACK, true), Vector3(180, 0, 0))
	cyl(holder, radius * 0.03, radius * 0.03, radius * 0.6, Vector3(0, radius * 0.45, 0), mat(Color(0.3, 0.3, 0.3)))
	add_mesh(holder, _sphere(radius * 0.07), Vector3(0, radius * 0.75, 0), mat(Color(0.2, 0.2, 0.2)))
	return holder


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


## The craft as a Node3D, its front (+Z) carrying the instruments, its back (-Z) the engine and the launch adapter,
## its top (+Y) the antenna. Meta "radius": its size, for the camera.
static func build(m) -> Node3D:
	var root := Node3D.new()
	root.name = "Spacecraft"
	var B: Dictionary = GameData.BUSES[m.bus]
	var P: Dictionary = GameData.PANELS[m.panels]
	var C: Dictionary = GameData.COMMS[m.comms]
	var A: Dictionary = GameData.ADCS[m.adcs]
	var PR: Dictionary = GameData.PROPULSION[m.propulsion]
	var d: Vector3 = B.dims
	var cots: bool = B.cots
	var k: float = d.x   # scale of the details
	var alu := mat(Color(0.74, 0.74, 0.74), 0.9, 0.3)
	var white := mat(Color(0.86, 0.86, 0.84), 0.0, 0.45)
	const OUT_FRONT := Vector3(0, 0, 1)
	const OUT_BACK := Vector3(0, 0, -1)

	# ---------------- the bus
	var bus_g := _grp(root, "bus:" + m.bus)
	if cots:
		_cubesats(bus_g, m, d)
	else:
		box(bus_g, d, Vector3.ZERO, mli_mat())
		# silver optical solar reflector radiators on the top and bottom, the faces that see the least Sun
		var osr := mli_mat(Color(0.85, 0.87, 0.9))
		box(bus_g, Vector3(d.x * 0.82, 0.01, d.z * 0.7), Vector3(0, -d.y / 2.0 - 0.004, -d.z * 0.05), osr)
		box(bus_g, Vector3(d.x * 0.5, 0.01, d.z * 0.4), Vector3(d.x * 0.18, d.y / 2.0 + 0.004, d.z * 0.22), osr)
		# the aluminium frame along the edges
		var e := 0.025 * maxf(k, 0.6)
		for sa in [-1, 1]:
			for sb in [-1, 1]:
				box(bus_g, Vector3(e, e, d.z + e), Vector3(sa * d.x / 2.0, sb * d.y / 2.0, 0), alu)
				box(bus_g, Vector3(d.x + e, e, e), Vector3(0, sa * d.y / 2.0, sb * d.z / 2.0), alu)
				box(bus_g, Vector3(e, d.y + e, e), Vector3(sa * d.x / 2.0, 0, sb * d.z / 2.0), alu)
		# the launch adapter ring at the back, the engine inside it
		part(bus_g, "AdapterRing", Vector3(0, 0, -d.z / 2.0), OUT_BACK, minf(d.x, d.y) * 0.62, 0.8)
		# coarse sun sensors on the top corners
		for sx in [-1, 1]:
			part(bus_g, "SunSensor", Vector3(sx * d.x * 0.4, d.y / 2.0, d.z * 0.42), Vector3.UP, 0.09 * k)
		if m.panels == "body":
			var body_g := _grp(root, "panels:body")
			for sx in [-1, 1]:
				box(body_g, Vector3(d.y * 0.86, 0.01, d.z * 0.86), Vector3(sx * (d.x / 2.0 + 0.008), 0, 0), solar_mat(), Vector3(0, 0, 90))

	# ---------------- solar wings: a drive on each side, a yoke, then panels hinged edge to edge
	var span: float = P.span
	if span > 0.0 and not (cots and m.bus == "cube3"):
		var h: float = d.z * (0.8 if cots else 0.85)
		var yoke_len: float = 0.25 * maxf(k, 0.5)
		var segs := int(ceil(span / 1.3))
		var seg_w := (span - yoke_len) / segs
		var wings_g := _grp(root, "panels:" + m.panels)
		for side in [-1, 1]:
			var wing := Node3D.new()
			wing.name = "Wing" + ("L" if side < 0 else "R")
			wing.position = Vector3(side * d.x / 2.0, 0, 0)
			wings_g.add_child(wing)
			var out := Vector3(side, 0, 0)
			if not cots:
				part(wing, "Sada", Vector3.ZERO, out, 0.12 * k, 0.5)
			var yk := part(wing, "Yoke", out * 0.03, out, yoke_len, 1.0, PI / 2.0)
			yk.scale = Vector3(h * 0.9 / 0.6, yoke_len, yoke_len)
			for sgi in segs:
				var cx: float = side * (yoke_len + seg_w * sgi + seg_w / 2.0)
				box(wing, Vector3(seg_w * 0.985, 0.014, h), Vector3(cx, 0.004, 0), solar_mat())
				box(wing, Vector3(seg_w * 0.985, 0.006, h), Vector3(cx, -0.006, 0), solar_mat(true))
				# frame and the hinges between panels
				for sz in [-1, 1]:
					box(wing, Vector3(seg_w * 0.985, 0.02, 0.012), Vector3(cx, 0, sz * h / 2.0), alu)
				for hz in [-0.3, 0.3]:
					box(wing, Vector3(0.03, 0.03, 0.05), Vector3(side * (yoke_len + seg_w * sgi), 0, hz * h), alu)

	# ---------------- communications
	var comms_g := _grp(root, "comms:" + m.comms)
	if C.dish > 0.0:
		var dr: float = C.dish * maxf(0.6, k * 0.55)
		part(comms_g, "Dish", Vector3(0, d.y / 2.0, -d.z * 0.2), Vector3(0, 1, -0.25), dr)
	else:
		var wire := mat(Color(0.85, 0.85, 0.85), 0.9, 0.2)
		for sx in [-1, 1]:
			cyl(comms_g, 0.006, 0.006, 0.5, Vector3(sx * d.x * 0.35, -d.y / 2.0 - 0.22, d.z * 0.45), wire, Vector3(0, 0, sx * 25))
			cyl(comms_g, 0.006, 0.006, 0.5, Vector3(sx * d.x * 0.35, d.y / 2.0 + 0.22, d.z * 0.45), wire, Vector3(0, 0, -sx * 25))

	# ---------------- instruments on the front (+Z), looking out
	var list: Array = m.instruments
	var n := list.size()
	var cols := int(ceil(sqrt(float(n)))) if n > 0 else 1
	var rows := int(ceil(float(n) / cols)) if n > 0 else 1
	for i in n:
		var id: String = list[i]
		var I: Dictionary = GameData.INSTRUMENTS[id]
		var cx: float = (float(i % cols) - (cols - 1) / 2.0) * d.x / cols
		var cy: float = (float(i / cols) - (rows - 1) / 2.0) * d.y / rows
		var s: float = min(d.x / cols, d.y / rows) * 0.7
		var front := Vector3(cx, cy, d.z / 2.0)
		var ig := _grp(root, "instrument:" + id)
		match I.shape:
			"box":
				if id.begins_with("ir"):
					part(ig, "Radiometer", front, OUT_FRONT, s * 0.9)
				elif id.begins_with("gas"):
					part(ig, "Spectrometer", front, OUT_FRONT, s * 0.9)
				else:
					part(ig, "CamBox", front, OUT_FRONT, s * 0.8)
			"cyl":
				if id.begins_with("gas"):
					part(ig, "Spectrometer", front, OUT_FRONT, s)
				elif id == "gamma":
					cyl(ig, s * 0.36, s * 0.36, s * 0.7, front + Vector3(0, 0, s * 0.35), white, Vector3(90, 0, 0))
					cyl(ig, s * 0.38, s * 0.38, s * 0.06, front + Vector3(0, 0, s * 0.7), alu, Vector3(90, 0, 0))
				else:
					part(ig, "CamTelescope", front, OUT_FRONT, s * 0.95)
			"tube":
				part(ig, "CamTelescope", front, OUT_FRONT, s * 1.05, d.z * 0.9 / (s * 1.05))
			"bigtube":
				_telescope(ig, d)
			"panel":
				var sar := part(ig, "SarPanel", Vector3(0, -d.y / 2.0 - 0.02, 0), Vector3.DOWN, 1.0)
				sar.scale = Vector3(d.x * 1.9, 1.0, d.z * 1.25)
			"dish":
				part(ig, "Dish", Vector3(cx, -d.y / 2.0, cy * 0.5), Vector3.DOWN, s * 0.55)
			"boom":
				part(ig, "Boom", Vector3(-d.x / 2.0, d.y / 2.0, -d.z / 2.0), Vector3(-0.6, 0.5, -0.4), 1.4)

	# ---------------- attitude control: star trackers on the top, angled away from the Sun and the Earth
	if A.level >= 3:
		var adcs_g := _grp(root, "adcs:" + m.adcs)
		for sx in [-1, 1]:
			part(adcs_g, "StarTracker", Vector3(sx * d.x * 0.3, d.y / 2.0, d.z * 0.3), Vector3(sx * 0.35, 1.0, 0.55), 0.16 * k)

	# ---------------- propulsion at the back (-Z)
	if m.propulsion != "none":
		var nz := Node3D.new()
		nz.name = "Thruster"
		nz.position = Vector3(0, 0, -d.z / 2.0)
		_grp(root, "propulsion:" + m.propulsion).add_child(nz)
		var r: float = 0.08 * max(k, 0.5)
		if PR.electric:
			part(nz, "ThrusterIon", Vector3.ZERO, OUT_BACK, r * 2.6)
		else:
			part(nz, "ThrusterChem", Vector3.ZERO, OUT_BACK, r * (2.6 if PR.dv > 500.0 else 1.4))
		var g := ShaderMaterial.new()
		g.shader = GLOW
		g.set_shader_parameter("glow", Color(0.35, 0.6, 1.0) if PR.electric else Color(1.0, 0.6, 0.25))
		var plume := cyl(nz, r * 0.3, r * 0.9, r * 6.0, Vector3(0, 0, -r * 5.0), g, Vector3(-90, 0, 0))
		plume.name = "Plume"
		plume.visible = false

	var radius: float = max(d.length() * 0.6, span + d.x / 2.0 + 0.2)
	root.set_meta("radius", radius)
	var keys: Array = []
	for g in root.get_children():
		if g.has_meta("part_key"):
			keys.append(g.get_meta("part_key"))
	root.set_meta("part_keys", keys)
	return root


## A holder for one chosen part of the craft, named by its key ("panels:dep_m", "instrument:ir_adv"...), so the
## design screen can make a new part arrive and snap, and light the part a problem comes from (scripts/craft/craft_view.gd).
static func _grp(root: Node3D, key: String) -> Node3D:
	var g := Node3D.new()
	g.name = key.replace(":", "_")
	g.set_meta("part_key", key)
	root.add_child(g)
	return g


## CubeSats: the modeled 3U (rails, cells, wings, whips) at the game's size; a 6U is two side by side, a 12U four.
## A 3U with deployable panels opens its own wings; bigger ones carry the game's wings.
static func _cubesats(root: Node3D, m, d: Vector3) -> void:
	var k := d.z / 0.3405   # the model's length to the game's
	var spots: Array = [Vector2.ZERO]
	if m.bus == "cube6":
		spots = [Vector2(-0.5, 0), Vector2(0.5, 0)]
	elif m.bus == "cube12":
		spots = [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]
	var unit := d.y if spots.size() == 2 else (d.x / 2.0 if spots.size() == 4 else d.x)
	for sp in spots:
		var c: Node3D = CUBESAT.instantiate()
		c.rotation_degrees = Vector3(90, 0, 0)
		c.scale = Vector3(unit / 0.1, k, unit / 0.1)
		c.position = Vector3(sp.x * unit, sp.y * unit, 0)
		root.add_child(c)
		var ap := c.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if ap:
			ap.play("deploy")
			ap.seek(3.0 if (m.panels != "body" and m.bus == "cube3") else 0.0, true)
			ap.pause()


## The large infrared observatory: a five-layer sunshield, the segmented gold mirror on its tower, the secondary on
## three struts (JWST-like proportions, simplified).
static func _telescope(root: Node3D, d: Vector3) -> void:
	var alu := mat(Color(0.74, 0.74, 0.74), 0.9, 0.3)
	var mirror := mat(Color(1.0, 0.78, 0.34), 1.0, 0.12)
	var tel := Node3D.new()
	tel.position = Vector3(0, d.y / 2.0 + 0.1, 0)
	root.add_child(tel)
	var shield_m := mat(Color(0.78, 0.66, 0.8), 0.8, 0.22, Color.BLACK, true)
	for layer in 5:
		box(tel, Vector3(d.x * 2.6 - layer * 0.1, 0.008, d.z * 1.7 - layer * 0.08), Vector3(0, layer * 0.05, 0), shield_m)
	var optics := Node3D.new()
	optics.position = Vector3(0, 0.95, -0.1)
	optics.rotation_degrees = Vector3(-20, 0, 0)
	tel.add_child(optics)
	var hexm := CylinderMesh.new()
	hexm.top_radius = 0.26
	hexm.bottom_radius = 0.26
	hexm.height = 0.04
	hexm.radial_segments = 6
	for q in 7:
		var off := Vector2.ZERO if q == 0 else Vector2(cos(q * PI / 3.0 + PI / 6.0), sin(q * PI / 3.0 + PI / 6.0)) * 0.46
		add_mesh(optics, hexm, Vector3(off.x, off.y, 0), mirror, Vector3(90, 0, 0))
	box(optics, Vector3(0.3, 0.9, 0.12), Vector3(0, -0.75, -0.1), mat(Color(0.15, 0.15, 0.17), 0.3, 0.5))
	for sx in [-1, 1]:
		cyl(optics, 0.012, 0.012, 1.2, Vector3(sx * 0.3, 0.0, 0.55), alu, Vector3(90, 0, sx * 14))
	add_mesh(optics, _sphere(0.07), Vector3(0, 0, 1.1), mirror)
