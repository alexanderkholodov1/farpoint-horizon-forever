extends RefCounted
## The ground of the landing: the Moon's south pole around Shackleton's rim, from NASA's LOLA heights [S-lola]
## (data/nasa/lola_south_pole.json, 200 x 200 heights 60 m apart). The tile gives the real hills, the rim and the
## crater; between its points we add small craters and roughness of our own (a game simplification, seeded, so every
## machine gets the same ground) that fade out toward the edge of the detailed area and never touch the target pad.
## Light: the Sun sits 1.5 degrees above the horizon at the pole [S-svs-south-pole], so the ground keeps long shadows;
## `lit` marks the cells the Sun reaches (a ray marched toward the Sun over the tile). The Earth hangs low over the
## side of the tile at row 0 (longitude 0, the near side), and `sees_earth` tells whether a point still has it in view.
## Units: metres. x grows with the tile's columns, z with its rows; y is height above the landing target.
##   const Terrain := preload("res://scripts/flight/terrain.gd")
##   var t := Terrain.new(); t.setup(flight.landing); add_child(t.build_mesh())

const FlightData := preload("res://scripts/flight/flight_data.gd")

const HALF := 24            ## Half the side of the detailed area, in tile cells (24 x 60 m = 1.44 km each way).
const SUB := 4              ## Each tile cell of the detailed area is cut into SUB x SUB quads (15 m).
const DETAIL_SEED := 1969   ## Seed of our own small craters and roughness.
const PAD_CLEAR := 45.0     ## Metres around the target kept free of our own craters.

var h: Array = []           ## Tile heights, rows of metres.
var rows := 0
var cols := 0
var step := 60.0            ## Metres between tile points.
var tr_row := 0             ## The target's row and column in the tile.
var tr_col := 0
var base := 0.0             ## Tile height at the target (the zero of y).
var pole := Vector2.ZERO    ## The pole in local metres (x, z).
var sun_dir := Vector3.UP   ## Unit vector toward the Sun.
var earth_dir := Vector3.UP ## Unit vector toward the Earth.
var lit: PackedFloat32Array ## 1 where the Sun reaches the tile cell, 0 in shadow (rows * cols).
var shadow_pts: PackedVector2Array  ## Local (x, z) of every shadowed cell near the target, for distances.
var craters: Array = []     ## Our own small craters: [x, z, radius, depth].
var noise := FastNoiseLite.new()
var meta := {}


## sweep: the Sun's light over a whole lunar day instead of one moment. At the pole the Sun circles the horizon once a
## month, so `lit` then marks the ground the Sun reaches at some time of the month, and what stays 0 is ground in
## permanent shadow (as Shackleton's floor is). Used by the operation's view of the landed craft (#30).
func setup(landing: Dictionary, sweep := false) -> void:
	var d: Dictionary = FlightData.terrain(str(landing.get("terrain", "data/nasa/lola_south_pole.json")))
	meta = d.get("meta", {})
	h = d.get("heights", [])
	rows = h.size()
	cols = (h[0] as Array).size() if rows > 0 else 0
	step = float(meta.get("spacing_m", 60.0))
	var t: Array = landing.get("target", [rows / 2, cols / 2])
	tr_row = int(t[0])
	tr_col = int(t[1])
	base = float(h[tr_row][tr_col]) if rows > 0 else 0.0
	pole = Vector2((float(meta.get("pole_col", tr_col)) - tr_col) * step, (float(meta.get("pole_row", tr_row)) - tr_row) * step)
	var az: Array = landing.get("sun_azimuth", [-1.0, -1.0])
	var se := deg_to_rad(float(landing.get("sun_elevation_deg", 1.5)))
	var flat := Vector2(float(az[0]), float(az[1])).normalized()
	sun_dir = Vector3(flat.x * cos(se), sin(se), flat.y * cos(se)).normalized()
	var ee := deg_to_rad(float(landing.get("earth_elevation_deg", 3.0)))
	earth_dir = Vector3(0.0, sin(ee), -cos(ee)).normalized()    # row 0 is the near side, toward the Earth
	noise.seed = DETAIL_SEED
	noise.frequency = 1.0 / 90.0
	noise.fractal_octaves = 3
	_make_craters()
	_make_light(sweep)


# ===================================================================================== HEIGHTS
## Raw tile height (metres above the target) at fractional tile coordinates, bilinear between the LOLA points.
func tile_height(row: float, col: float) -> float:
	if rows == 0:
		return 0.0
	row = clampf(row, 0.0, rows - 1.001)
	col = clampf(col, 0.0, cols - 1.001)
	var r0 := int(row)
	var c0 := int(col)
	var fr := row - r0
	var fc := col - c0
	var a: float = lerpf(float(h[r0][c0]), float(h[r0][c0 + 1]), fc)
	var b: float = lerpf(float(h[r0 + 1][c0]), float(h[r0 + 1][c0 + 1]), fc)
	return lerpf(a, b, fr) - base


## Ground height at local x, z (metres): the LOLA tile plus our own detail inside the detailed area.
func height(x: float, z: float) -> float:
	return tile_height(tr_row + z / step, tr_col + x / step) + detail(x, z)


## Our own small craters and roughness at x, z, faded to nothing at the edge of the detailed area.
func detail(x: float, z: float) -> float:
	var edge := HALF * step
	var fade := clampf((edge - maxf(absf(x), absf(z))) / (edge * 0.25), 0.0, 1.0)
	if fade <= 0.0:
		return 0.0
	var pad := clampf((Vector2(x, z).length() - PAD_CLEAR * 0.5) / PAD_CLEAR, 0.0, 1.0)
	var y := noise.get_noise_2d(x, z) * 2.5 * pad
	for c in craters:
		var dx: float = x - c[0]
		var dz: float = z - c[1]
		var r: float = c[2]
		var d2 := dx * dx + dz * dz
		if d2 > r * r * 2.6:
			continue
		var q := sqrt(d2) / r
		if q < 1.0:
			y -= c[3] * (1.0 - q * q)
		y += c[3] * 0.3 * exp(-pow((q - 1.0) / 0.28, 2.0))
	return y * fade


## Slope of the ground at x, z, in degrees.
func slope_deg(x: float, z: float) -> float:
	var e := 2.0
	var gx := (height(x + e, z) - height(x - e, z)) / (2.0 * e)
	var gz := (height(x, z + e) - height(x, z - e)) / (2.0 * e)
	return rad_to_deg(atan(Vector2(gx, gz).length()))


func normal(x: float, z: float) -> Vector3:
	var e := 2.0
	return Vector3(height(x - e, z) - height(x + e, z), 2.0 * e, height(x, z - e) - height(x, z + e)).normalized()


func _make_craters() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DETAIL_SEED
	var edge := HALF * step
	while craters.size() < 26:
		var r := rng.randf_range(8.0, 70.0) if rng.randf() < 0.8 else rng.randf_range(70.0, 140.0)
		var x := rng.randf_range(-edge, edge)
		var z := rng.randf_range(-edge, edge)
		if Vector2(x, z).length() < r * 1.4 + PAD_CLEAR:
			continue
		craters.append([x, z, r, r * rng.randf_range(0.12, 0.2)])


# ===================================================================================== LIGHT
## Marches from each tile cell toward the Sun; a cell is dark when the ground rises above the ray.
func _make_light(sweep := false) -> void:
	lit = PackedFloat32Array()
	lit.resize(rows * cols)
	var flat := Vector2(sun_dir.x, sun_dir.z).normalized()
	var rise := sun_dir.y / Vector2(sun_dir.x, sun_dir.z).length() * step * 1.5
	var turns := 12 if sweep else 1
	for k in turns:
		var d := flat.rotated(TAU * k / turns) * 1.5     # 1.5 cells per march step
		for r in rows:
			for c in cols:
				if lit[r * cols + c] < 1.0 and _ray_clear(r, c, d, rise, 70):
					lit[r * cols + c] = 1.0
	_shade_bowl()
	shadow_pts = PackedVector2Array()
	for r in range(maxi(tr_row - HALF, 0), mini(tr_row + HALF, rows)):
		for c in range(maxi(tr_col - HALF, 0), mini(tr_col + HALF, cols)):
			if lit[r * cols + c] < 0.5:
				shadow_pts.append(Vector2((c - tr_col) * step, (r - tr_row) * step))


func _ray_clear(r: int, c: int, d: Vector2, rise: float, n: int) -> bool:
	var y0: float = float(h[r][c]) + 1.0
	var pc := float(c)
	var pr := float(r)
	for i in range(1, n):
		pc += d.x
		pr += d.y
		var ic := roundi(pc)
		var ir := roundi(pr)
		if ic < 0 or ir < 0 or ic >= cols or ir >= rows:
			return true
		if float(h[ir][ic]) > y0 + rise * i:
			return false
	return true


## How much sunlight reaches local x, z: 0 dark to 1 lit, soft between tile cells.
func light_at(x: float, z: float) -> float:
	var row := clampf(tr_row + z / step, 0.0, rows - 1.001)
	var col := clampf(tr_col + x / step, 0.0, cols - 1.001)
	var r0 := int(row)
	var c0 := int(col)
	var a := lerpf(lit[r0 * cols + c0], lit[r0 * cols + c0 + 1], col - c0)
	var b := lerpf(lit[(r0 + 1) * cols + c0], lit[(r0 + 1) * cols + c0 + 1], col - c0)
	return lerpf(a, b, row - r0)


## Shackleton's interior never sees the Sun ("illuminated rim, shadowed interior" [S-nasa-science]). The tile holds
## only the near part of the crater, so a ray from its floor leaves the tile before meeting the far rim; the bowl is
## therefore taken from the LOLA heights themselves [S-lola]: every cell below the reference sphere that joins the
## deepest point is in shadow. Our simplification of where the crater's shadow ends.
func _shade_bowl() -> void:
	var deepest := 0
	for i in rows * cols:
		if float(h[i / cols][i % cols]) < float(h[deepest / cols][deepest % cols]):
			deepest = i
	var seen := {deepest: true}
	var todo: Array = [deepest]
	while not todo.is_empty():
		var i: int = todo.pop_back()
		lit[i] = 0.0
		var r := i / cols
		var c := i % cols
		for n in [[r - 1, c], [r + 1, c], [r, c - 1], [r, c + 1]]:
			if n[0] < 0 or n[1] < 0 or n[0] >= rows or n[1] >= cols:
				continue
			var j: int = n[0] * cols + n[1]
			if not seen.has(j) and float(h[n[0]][n[1]]) < 0.0:
				seen[j] = true
				todo.append(j)


## Distance in metres from x, z to the nearest shadowed ground near the target (INF when none).
func shadow_distance(x: float, z: float) -> float:
	var best := INF
	var p := Vector2(x, z)
	for s in shadow_pts:
		best = minf(best, p.distance_to(s))
	return best


func pole_distance(x: float, z: float) -> float:
	return Vector2(x, z).distance_to(pole)


## True when the Earth is in view from local position p (metres): no ground rises above the line toward it.
func sees_earth(p: Vector3) -> bool:
	var flat := Vector2(earth_dir.x, earth_dir.z).normalized()
	var rise := earth_dir.y / Vector2(earth_dir.x, earth_dir.z).length()
	var s := 30.0
	for i in range(1, 160):
		var q := Vector2(p.x, p.z) + flat * s * i
		if height(q.x, q.y) > p.y + 1.5 + rise * s * i:
			return false
	return true


# ===================================================================================== MESH
## The ground as one node: the detailed area around the target and the rest of the tile around it, coarser.
func build_mesh() -> Node3D:
	var root := Node3D.new()
	root.name = "LunarGround"
	# the regolith: LOLA's shape and the baked sunlight from the mesh, small craters and grain from the shader
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/shaders/regolith.gdshader")
	var near := MeshInstance3D.new()
	near.mesh = _grid(-HALF, HALF, -HALF, HALF, SUB, false)
	near.material_override = m
	near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(near)
	var far := MeshInstance3D.new()
	far.mesh = _grid(-tr_col, cols - 1 - tr_col, -tr_row, rows - 1 - tr_row, 1, true)
	far.material_override = m
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(far)
	return root


## A grid over tile cells c0..c1 (columns) by r0..r1 (rows), relative to the target, sub quads per cell.
## hole leaves out the cells of the detailed area (the far ring).
func _grid(c0: int, c1: int, r0: int, r1: int, sub: int, hole: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := (c1 - c0) * sub
	var nz := (r1 - r0) * sub
	var cell := step / sub
	for j in nz + 1:
		for i in nx + 1:
			var x := (c0 * sub + i) * cell
			var z := (r0 * sub + j) * cell
			var y := height(x, z) if not hole else tile_height(tr_row + z / step, tr_col + x / step)
			var l := light_at(x, z)
			var tone := 0.9 + 0.1 * noise.get_noise_2d(x * 3.1, z * 3.1)
			st.set_color(Color(tone, tone, tone) * lerpf(0.035, 1.0, l))
			st.add_vertex(Vector3(x, y, z))
	for j in nz:
		for i in nx:
			if hole:
				var cx := c0 + i + 0.5
				var cz := r0 + j + 0.5
				if absf(cx) < HALF and absf(cz) < HALF:
					continue
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			for k in [a, b, c, b, d, c]:
				st.add_index(k)
	st.generate_normals()
	return st.commit()
