extends RefCounted
## The craft in the design screen as a thing the player assembles (C1, issue #6): a part just chosen arrives from
## outside the craft and snaps into place with a click, and the part a problem comes from glows (red when it blocks
## the launch, amber when it only costs science), so the consequence of a choice shows on the craft itself.
## The craft is built by scripts/world/ship_builder.gd, which puts every chosen part in a holder with a "part_key" meta
## ("panels:dep_m", "instrument:ir_adv", "comms:xband"...). scripts/world/world.gd calls refresh() after each rebuild.

const ALERT := preload("res://assets/shaders/part_alert.gdshader")
const MARKER := preload("res://assets/shaders/part_marker.gdshader")
const UiSound := preload("res://scripts/ui/ui_sound.gd")
const RED := Color(1.0, 0.28, 0.24)
const AMBER := Color(1.0, 0.72, 0.2)
const SNAP_TIME := 0.5   ## Seconds a new part takes to arrive and settle.


## Animates the parts of `ship` that were not in `old_keys`, then lights the parts of the problems in `r`
## (Mission.compute()). On the first build (no old keys) nothing flies in: the craft is simply there.
static func refresh(ship: Node3D, old_keys: Array, m, r: Dictionary) -> void:
	if not old_keys.is_empty():
		var radius: float = ship.get_meta("radius", 1.0)
		var any := false
		for g in _holders(ship):
			var key: String = g.get_meta("part_key")
			# a part of the same kind changed (a bigger dish, other panels) or a new one appeared
			if not old_keys.has(key):
				_fly_in(ship, g, radius)
				any = true
		if any:
			UiSound.play("snap", 0.08)
	for g in _holders(ship):
		var level := trouble(g.get_meta("part_key"), m, r)
		if level != "":
			_alert(ship, g, RED if level == "fatal" else AMBER)


## "fatal", "warn" or "" for the part `key` of mission m with report r: which part a check of mission.gd comes from.
static func trouble(key: String, m, r: Dictionary) -> String:
	var kind := key.get_slice(":", 0)
	var id := key.get_slice(":", 1)
	var B: Dictionary = GameData.BUSES[m.bus]
	match kind:
		"bus":
			if r.mass_total > B.max or m.instruments.size() > B.slots:
				return "fatal"
		"instrument":
			if GameData.INSTRUMENTS.has(id) and GameData.INSTRUMENTS[id].size > B.max_size:
				return "fatal"
			if r.pointing_bad.has(GameData.INSTRUMENTS.get(id, {}).get("name", "")):
				return "warn"
		"panels":
			if r.power_margin < 0.0 or r.battery_ratio < 1.0:
				return "warn"
		"comms":
			if r.data_ratio < 1.0:
				return "warn"
		"adcs":
			if not r.pointing_bad.is_empty():
				return "warn"
		"propulsion":
			if not r.insertion_ok:
				return "warn"
	return ""


static func _holders(ship: Node3D) -> Array:
	var out: Array = []
	for g in ship.get_children():
		if g.has_meta("part_key"):
			out.append(g)
	return out


## The part flies in from outside along the line from the craft's centre through the part, a little small, and
## settles with a short overshoot: the "snap" of the design criteria (200-600 ms).
static func _fly_in(ship: Node3D, g: Node3D, radius: float) -> void:
	var c := _centre(ship, g)
	var dir := c.normalized() if c.length() > 0.001 else Vector3.UP
	var rest_pos := g.position
	g.position = rest_pos + dir * radius * 1.4
	g.scale = Vector3.ONE * 0.85
	var tw := g.create_tween().set_parallel(true)
	tw.tween_property(g, "position", rest_pos, SNAP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(g, "scale", Vector3.ONE, SNAP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The middle of a holder's meshes in the craft's space: each mesh's own box centre, carried up through the local
## transforms (global transforms are not settled yet in the frame the craft is built).
static func _centre(_ship: Node3D, g: Node3D) -> Vector3:
	return g.transform * _local_centre(g)


## The middle of a holder's meshes in the holder's own space.
static func _local_centre(g: Node3D) -> Vector3:
	var acc := [Vector3.ZERO, 0]
	for c in g.get_children():
		if c is Node3D:
			_gather(c, (c as Node3D).transform, acc)
	return acc[0] / acc[1] if acc[1] > 0 else Vector3.ZERO


static func _gather(n: Node, xf: Transform3D, acc: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		acc[0] += xf * (n as MeshInstance3D).mesh.get_aabb().get_center()
		acc[1] += 1
	for c in n.get_children():
		if c is Node3D:
			_gather(c, xf * (c as Node3D).transform, acc)


## The part glows at its edges and a ring marks it, drawn over the craft so it shows from any side.
static func _alert(ship: Node3D, g: Node3D, col: Color) -> void:
	var m := ShaderMaterial.new()
	m.shader = ALERT
	m.set_shader_parameter("tint", col)
	for mi in g.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = m
	# parts in two halves (the solar wings) get a ring on each half, so the mark sits on the part, not between them
	var spots: Array = [g]
	var wings: Array = g.get_children().filter(func(c): return c is Node3D and String(c.name).begins_with("Wing"))
	if not wings.is_empty():
		spots = wings
	for spot in spots:
		_ring(ship, spot, col)


static func _ring(ship: Node3D, spot: Node3D, col: Color) -> void:
	var q := QuadMesh.new()
	var rr: float = ship.get_meta("radius", 1.0)
	q.size = Vector2.ONE * clampf(rr * 0.35, 0.18, 0.8)
	var rm := ShaderMaterial.new()
	rm.shader = MARKER
	rm.set_shader_parameter("tint", col)
	q.material = rm
	var ring := MeshInstance3D.new()
	ring.name = "TroubleRing"
	ring.mesh = q
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = _local_centre(spot)   # on the part, so it arrives with it
	spot.add_child(ring)
