extends Node3D
## A cuy on stage (issue #66): one crew model brought to life. The rigged model (assets/models/crew/crew_<id>_rig.glb,
## made by assets/source/crew_rig.py: hips, spine, arms, hands, legs, feet) moves its arms and legs; the face keeps its
## separate parts (brows, eyes, glints, mouth and its corners; assets/source/crew_*.py), so the actor blinks, raises or
## knits its brows, smiles or frowns and opens its mouth while it talks; the head nods, tilts and turns toward whoever
## speaks, and rides the spine.
## What the body does is an act (ACTS: idle, talk, wave, point, cheer, scared, hips, shrug, think, work, float, hide,
## walk), and how the face looks is a mood (MOODS); both blend smoothly into the next. move_to() walks the cuy to a
## mark. Each cuy has its own way of being (PERSONALITY): Rumi barely moves, Killa tilts her head at everything, Inti
## bounces with pride, Wayra is slow and sleepy.
##   var a = CuyActor.new(); a.id = "killa"; add_child(a); a.set_mood("worried"); a.act = "think"; a.talking = true

## Parts that move with the head (the start of each node's name).
const HEAD_PARTS := ["Head", "Brow", "Eye", "Glint", "Mouth", "Nose", "Whisker", "Ear", "Lid", "Tuft", "Goggle",
	"Headband", "CupRim", "Mic"]

## What a mood does to the face. brow: inner ends up (+) or down (-); brow_y: brows raised; eye: how open (1 = as
## modelled); smile: mouth corners up (+) or down (-); tilt, nod: the head (radians); lean: the body forward; bounce:
## how lively the idle is.
const MOODS := {
	"neutral": {"brow": 0.0, "brow_y": 0.0, "eye": 1.0, "smile": 0.0, "tilt": 0.0, "nod": 0.0, "lean": 0.0, "bounce": 1.0},
	"happy": {"brow": 0.15, "brow_y": 0.006, "eye": 0.75, "smile": 1.0, "tilt": 0.08, "nod": -0.05, "lean": 0.0, "bounce": 1.6},
	"pleased": {"brow": 0.1, "brow_y": 0.004, "eye": 0.6, "smile": 0.8, "tilt": 0.1, "nod": 0.0, "lean": 0.0, "bounce": 1.2},
	"proud": {"brow": -0.1, "brow_y": 0.004, "eye": 0.85, "smile": 0.7, "tilt": 0.0, "nod": -0.14, "lean": -0.06, "bounce": 1.3},
	"curious": {"brow": 0.25, "brow_y": 0.008, "eye": 1.15, "smile": 0.25, "tilt": 0.22, "nod": 0.04, "lean": 0.05, "bounce": 1.2},
	"alert": {"brow": 0.3, "brow_y": 0.012, "eye": 1.3, "smile": -0.4, "tilt": 0.0, "nod": -0.04, "lean": 0.04, "bounce": 1.4},
	"worried": {"brow": 0.55, "brow_y": 0.006, "eye": 1.1, "smile": -0.8, "tilt": -0.1, "nod": 0.08, "lean": 0.03, "bounce": 0.8},
	"scared": {"brow": 0.6, "brow_y": 0.014, "eye": 1.35, "smile": -1.0, "tilt": 0.0, "nod": 0.1, "lean": -0.08, "bounce": 0.6},
	"calm": {"brow": 0.0, "brow_y": 0.0, "eye": 0.8, "smile": 0.2, "tilt": 0.0, "nod": 0.02, "lean": 0.0, "bounce": 0.7},
	"determined": {"brow": -0.45, "brow_y": -0.003, "eye": 0.85, "smile": -0.1, "tilt": 0.0, "nod": 0.06, "lean": 0.07, "bounce": 1.0},
	"flat": {"brow": -0.05, "brow_y": -0.004, "eye": 0.55, "smile": -0.1, "tilt": 0.0, "nod": 0.02, "lean": 0.0, "bounce": 0.4},
	"sleepy": {"brow": 0.1, "brow_y": -0.004, "eye": 0.4, "smile": 0.05, "tilt": -0.12, "nod": 0.12, "lean": 0.0, "bounce": 0.5},
	"tired": {"brow": 0.3, "brow_y": -0.004, "eye": 0.5, "smile": -0.3, "tilt": -0.08, "nod": 0.15, "lean": 0.04, "bounce": 0.5},
	"relieved": {"brow": 0.35, "brow_y": 0.004, "eye": 0.55, "smile": 0.9, "tilt": 0.12, "nod": -0.06, "lean": -0.03, "bounce": 1.1},
	"thoughtful": {"brow": 0.2, "brow_y": 0.003, "eye": 0.75, "smile": 0.1, "tilt": 0.18, "nod": -0.1, "lean": 0.0, "bounce": 0.7},
	"dreamy": {"brow": 0.2, "brow_y": 0.006, "eye": 0.7, "smile": 0.6, "tilt": 0.15, "nod": -0.22, "lean": -0.04, "bounce": 0.6},
}

## What an act does to the body: each arm's elevation (radians from horizontal: -1.3 hangs, 0 is straight out, 1.2 is
## up), reach (toward the front) and swing (forward and back), the legs' swing, the spine's lean and twist. A key that
## ends in "_w" is how far that value waves, at the act's "rate" (Hz). r and l are the cuy's right and left arms.
const ACTS := {
	"idle": {"re": -1.2, "le": -1.2, "rr": 0.15, "lr": 0.15},
	"talk": {"re": -0.55, "le": -1.1, "rr": 0.75, "lr": 0.2, "re_w": 0.25, "rr_w": 0.2, "rate": 1.3},
	"wave": {"re": 1.1, "le": -1.2, "rr": 0.25, "lr": 0.15, "re_w": 0.0, "rs_w": 0.0, "wave": 1.0},
	"point": {"re": 0.05, "le": -1.2, "rr": 1.35, "lr": 0.15, "spine_y": -0.15},
	"cheer": {"re": 1.15, "le": 1.15, "rr": 0.2, "lr": 0.2, "re_w": 0.2, "le_w": 0.2, "rate": 2.4},
	"scared": {"re": 0.35, "le": 0.35, "rr": 1.25, "lr": 1.25, "lean": -0.12, "re_w": 0.06, "le_w": 0.06, "rate": 7.0},
	"hips": {"re": -0.75, "le": -0.75, "rr": -0.35, "lr": -0.35, "lean": -0.08},
	"shrug": {"re": -0.25, "le": -0.25, "rr": 0.75, "lr": 0.75, "lean": -0.04},
	"think": {"re": 0.55, "le": -0.95, "rr": 1.65, "lr": 0.7, "lean": 0.04},
	"work": {"re": -0.2, "le": -0.2, "rr": 1.35, "lr": 1.35, "lean": 0.12, "re_w": 0.18, "le_w": 0.18, "rate": 3.0},
	"float": {"re": -0.15, "le": -0.15, "rr": 0.25, "lr": 0.25, "legs": -0.35, "re_w": 0.2, "le_w": 0.2, "rate": 0.35},
	"hide": {"re": 0.5, "le": 0.5, "rr": 1.55, "lr": 1.55, "lean": 0.25},
	"walk": {"re": -1.25, "le": -1.25, "rr": 0.1, "lr": 0.1, "walk": 1.0},
}

## Each cuy's way of being: how much they move (sway), how often they blink, how open their eyes are at rest, the mood
## they fall back to, how fast they talk and walk.
const PERSONALITY := {
	"rumi": {"sway": 0.35, "blink": 5.5, "eye": 0.8, "rest": "flat", "talk": 0.7, "stride": 0.9},
	"killa": {"sway": 1.0, "blink": 3.0, "eye": 1.05, "rest": "curious", "talk": 1.0, "stride": 1.15},
	"inti": {"sway": 1.2, "blink": 3.5, "eye": 1.0, "rest": "proud", "talk": 1.1, "stride": 1.0},
	"wayra": {"sway": 0.6, "blink": 4.5, "eye": 0.85, "rest": "sleepy", "talk": 0.8, "stride": 0.8},
}

var id := "rumi"
var talking := false         ## While true the mouth flaps and the hands gesture.
var look_target = null       ## A global point the head turns toward (null: straight ahead).
var act := "idle"            ## What the body does (a key of ACTS).
var mood := ""
var model: Node3D
var skel: Skeleton3D
var head: Node3D             ## The pivot at the neck that carries every head part.
var head_rest := Transform3D.IDENTITY
var brows: Array = []        ## [node, rest position, side (-1 right, +1 left)]
var eyes: Array = []         ## [node, rest scale]
var corners: Array = []      ## [node, rest position, side]
var glints: Array = []
var mouth_open: MeshInstance3D
var mouth_rest := Vector3.ZERO
var p := {}                  ## The face now (eased toward the mood).
var goal := {}
var body := {}               ## The body now (eased toward the act).
var bones := {}              ## Bone name -> index.
var arm_e0 := {}             ## The rest elevation of each arm ("l", "r").
var walk_to = null           ## A global point the cuy walks to (null: stays).
var walk_speed := 0.55
var face_yaw = null          ## The yaw to turn to once there (null: keep).
var _t := 0.0
var _blink_in := 2.0
var _blink := 0.0
var _hop := 0.0
var _shake := 0.0
var _flap := 0.0
var _phase := 0.0
var _stride := 0.0
var _walking := 0.0
var _head_h := 0.3
var _face_z := 0.2


func _ready() -> void:
	var path := "res://assets/models/crew/crew_%s_rig.glb" % id
	if not ResourceLoader.exists(path):
		path = "res://assets/models/crew/crew_%s_meshy.glb" % id
	if not ResourceLoader.exists(path):
		return
	model = load(path).instantiate()
	paint(model)
	add_child(model)
	_phase = float(hash(id) % 100) / 10.0
	var found := model.find_children("*", "Skeleton3D", true, false)
	if not found.is_empty():
		skel = found[0]
		for i in skel.get_bone_count():
			bones[skel.get_bone_name(i)] = i
		for s in ["l", "r"]:
			var tag := "L" if s == "l" else "R"
			if bones.has("arm." + tag) and bones.has("hand." + tag):
				var a := _rest("arm." + tag).origin
				var w := _rest("hand." + tag).origin
				arm_e0[s] = atan2(w.y - a.y, absf(w.x - a.x))
	_rig_head()
	set_mood(PERSONALITY.get(id, {}).get("rest", "neutral"))
	p = goal.duplicate()
	body = _act_goal(0.0)


## Sets the mood (a key of MOODS; an unknown one is the cuy's resting mood). Glad moods make a hop; scared ones a tremble.
func set_mood(m: String) -> void:
	if not MOODS.has(m):
		m = PERSONALITY.get(id, {}).get("rest", "neutral")
	if m == mood:
		return
	mood = m
	goal = MOODS[m].duplicate()
	goal.eye *= PERSONALITY.get(id, {}).get("eye", 1.0)
	if m in ["happy", "relieved", "proud", "pleased"]:
		hop()
	elif m in ["scared", "alert"]:
		_shake = 0.6


func hop() -> void:
	_hop = 1.0


func shake(t := 0.8) -> void:
	_shake = t


## Walks to a global point (on the cuy's own ground level), then turns to `yaw` if given.
func move_to(point: Vector3, yaw = null) -> void:
	walk_to = point
	face_yaw = yaw


## Where the cuy's face is (for the camera).
func face_point() -> Vector3:
	if head:
		return head.global_transform * Vector3(0, _head_h * 0.45, _face_z)
	return global_position + Vector3(0, 0.75, 0)


func _rig_head() -> void:
	var meshes: Array = model.find_children("*", "MeshInstance3D", true, false)
	var head_mi: MeshInstance3D = null
	for mi in meshes:
		if (mi as Node).name == "Head":
			head_mi = mi
	if head_mi == null:
		return
	var hb := _box(head_mi)
	_head_h = hb.size.y
	head = Node3D.new()
	head.name = "HeadPivot"
	model.add_child(head)
	head.position = Vector3(hb.get_center().x, hb.position.y + hb.size.y * 0.12, hb.get_center().z - hb.size.z * 0.1)
	head_rest = head.transform
	_face_z = hb.end.z - head.position.z
	for mi in meshes:
		var n: String = (mi as Node).name
		var ok := false
		for k in HEAD_PARTS:
			if n.begins_with(k):
				ok = true
		if not ok or mi.get_parent() is BoneAttachment3D:
			continue
		var g: Transform3D = _local(mi)
		mi.get_parent().remove_child(mi)
		head.add_child(mi)
		mi.transform = head.transform.affine_inverse() * g
		var side := -1.0 if mi.position.x < 0.0 else 1.0
		if n.begins_with("Brow"):
			brows.append([mi, mi.position, side])
		elif n.begins_with("Eye"):
			eyes.append([mi, mi.scale])
		elif n.begins_with("Glint"):
			glints.append(mi)
		elif n.begins_with("MouthL"):
			corners.append([mi, mi.position, side])
		elif n == "Mouth":
			mouth_rest = mi.position
	# a dark open mouth just under the line of the lips, shown while talking
	mouth_open = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 16
	sm.rings = 8
	mouth_open.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.22, 0.05, 0.07)
	mm.roughness = 0.8
	mouth_open.material_override = mm
	mouth_open.position = mouth_rest + Vector3(0, -0.016, 0.004)
	mouth_open.scale = Vector3(0.03, 0.0, 0.012)
	head.add_child(mouth_open)


## The node's transform relative to the model.
func _local(n: Node3D) -> Transform3D:
	var t := n.transform
	var q := n.get_parent()
	while q and q != model:
		if q is Node3D:
			t = (q as Node3D).transform * t
		q = q.get_parent()
	return t


func _box(mi: MeshInstance3D) -> AABB:
	return _local(mi) * mi.get_aabb()


## A bone's rest in model space.
func _rest(name: String) -> Transform3D:
	return _local(skel) * skel.get_bone_global_rest(bones[name])


## Poses a bone: its rest, turned by `rot` (in model space) about its own head, carried by its parent's pose.
func _pose(name: String, rot: Basis, shift := Vector3.ZERO) -> void:
	if not bones.has(name):
		return
	var b: int = bones[name]
	var M := _local(skel)
	var Mi := M.affine_inverse()
	var G := skel.get_bone_global_rest(b)
	var par := skel.get_bone_parent(b)
	var Pp := skel.get_bone_global_pose(par) if par >= 0 else Transform3D.IDENTITY
	var Pr := skel.get_bone_global_rest(par) if par >= 0 else Transform3D.IDENTITY
	var R := (Mi.basis * rot * M.basis).orthonormalized()
	var pivot := G.origin
	var turn := Transform3D(R, pivot - R * pivot + Mi.basis * shift)
	var desired := (Pp * Pr.affine_inverse()) * turn * G
	var local := Pp.affine_inverse() * desired
	skel.set_bone_pose_rotation(b, local.basis.get_rotation_quaternion())
	skel.set_bone_pose_position(b, local.origin)


## The body values an act asks for now (with its waves at time t).
func _act_goal(t: float) -> Dictionary:
	var A: Dictionary = ACTS.get(act, ACTS.idle)
	var rate: float = A.get("rate", 1.0)
	var out := {}
	for k in ["re", "le", "rr", "lr", "lean", "spine_y", "legs"]:
		out[k] = float(A.get(k, 0.0))
		var w: float = A.get(k + "_w", 0.0)
		if w != 0.0:
			out[k] += w * sin(t * TAU * rate + (PI if k.begins_with("l") else 0.0))
	return out


func _process(delta: float) -> void:
	if model == null:
		return
	_t += delta
	var per: Dictionary = PERSONALITY.get(id, {})
	var sway: float = per.get("sway", 1.0)
	var k := clampf(delta * 6.0, 0.0, 1.0)
	for key in goal:
		p[key] = lerpf(p.get(key, goal[key]), goal[key], k)
	_walk(delta, per)
	# the body eases toward the act; talking adds a hand gesture to an idle body
	var want := _act_goal(_t)
	if talking and act == "idle":
		var g := _act_goal(_t)
		var T: Dictionary = ACTS.talk
		g.re = T.re + T.re_w * sin(_t * TAU * T.rate)
		g.rr = T.rr + T.rr_w * sin(_t * TAU * T.rate * 0.7)
		want = g
	var kb := clampf(delta * 4.0, 0.0, 1.0)
	for key in want:
		body[key] = lerpf(body.get(key, want[key]), want[key], kb)
	_face(delta, per)
	_body(sway)
	_head(k, sway)


## Walking to a mark: turn toward it, stride, arrive, turn to face the scene.
func _walk(delta: float, per: Dictionary) -> void:
	var moving := false
	if walk_to != null:
		var to: Vector3 = (walk_to as Vector3) - global_position
		to.y = 0.0
		if to.length() > 0.03:
			moving = true
			var yaw := atan2(to.x, to.z)
			rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 6.0, 0.0, 1.0))
			global_position += to.normalized() * minf(to.length(), walk_speed * delta * per.get("stride", 1.0))
		else:
			walk_to = null
	if not moving and face_yaw != null:
		rotation.y = lerp_angle(rotation.y, float(face_yaw), clampf(delta * 4.0, 0.0, 1.0))
	_walking = lerpf(_walking, 1.0 if moving else 0.0, clampf(delta * 8.0, 0.0, 1.0))
	if moving:
		_stride += delta * 7.0 * per.get("stride", 1.0)


func _face(delta: float, per: Dictionary) -> void:
	if head == null:
		return
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink = 1.0
		_blink_in = per.get("blink", 4.0) * randf_range(0.6, 1.4)
	_blink = maxf(0.0, _blink - delta * 7.0)
	var shut := 1.0 - (1.0 if _blink > 0.5 else 0.0)
	# the mouth while talking: open and close on an uneven beat, like syllables
	var flap_goal := 0.0
	if talking:
		flap_goal = (0.5 + 0.5 * sin(_t * 17.0 * per.get("talk", 1.0))) * (0.6 + 0.4 * sin(_t * 5.3 + 1.0))
	_flap = lerpf(_flap, flap_goal, clampf(delta * 20.0, 0.0, 1.0))
	for b in brows:
		var node: Node3D = b[0]
		node.position = b[1] + Vector3(0, p.brow_y + _flap * 0.002, 0)
		node.rotation.z = -b[2] * p.brow * 0.6
	for e in eyes:
		var s: Vector3 = e[1]
		(e[0] as Node3D).scale = Vector3(s.x, s.y * maxf(0.06, p.eye * shut), s.z)
	for gl in glints:
		(gl as Node3D).visible = p.eye * shut > 0.35
	for c in corners:
		var node: Node3D = c[0]
		node.position = c[1] + Vector3(c[2] * absf(p.smile) * 0.002, p.smile * 0.006, 0)
		node.rotation.z = c[2] * p.smile * 0.45
	mouth_open.visible = _flap > 0.05
	mouth_open.scale = Vector3(0.026 + _flap * 0.012, 0.004 + _flap * 0.03, 0.012)


func _body(sway: float) -> void:
	# whole body: breathing, a hop, a tremble, the bob of the steps, and floating in zero gravity
	_hop = maxf(0.0, _hop - get_process_delta_time() * 2.2)
	var jump: float = sin((1.0 - _hop) * PI) * 0.07 * p.bounce if _hop > 0.0 else 0.0
	_shake = maxf(0.0, _shake - get_process_delta_time())
	var tremble := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.006 * _shake
	var breath: float = sin(_t * 2.0 + _phase) * 0.012 * p.bounce
	var step_bob := absf(sin(_stride)) * 0.03 * _walking
	var drift := Vector3.ZERO
	if act == "float":
		drift = Vector3(sin(_t * 0.4 + _phase) * 0.03, sin(_t * 0.6 + _phase) * 0.05, 0)
	model.position = Vector3(0, jump + step_bob, 0) + tremble + drift
	model.scale = Vector3(1.0 - breath * 0.4, 1.0 + breath, 1.0 - breath * 0.4)
	model.rotation.z = sin(_t * 0.3 + _phase) * 0.12 if act == "float" else sin(_stride) * 0.04 * _walking
	if skel == null:
		model.rotation.x = p.lean
		return
	var lean: float = p.lean + body.lean + sin(_t * 1.1 + _phase) * 0.01 * sway + 0.08 * _walking
	var swing := sin(_stride) * 0.55 * _walking
	_pose("hips", Basis(Vector3.UP, sin(_stride) * 0.08 * _walking))
	_pose("spine", Basis.from_euler(Vector3(lean, body.spine_y - sin(_stride) * 0.1 * _walking, sin(_t * 0.9 + _phase) * 0.02 * sway)))
	# legs: swing about the hips' side axis (forward is a negative turn about +X)
	var legs: float = body.legs
	_pose("leg.L", Basis(Vector3.RIGHT, -swing + legs + (sin(_t * 0.5) * 0.15 if act == "float" else 0.0)))
	_pose("leg.R", Basis(Vector3.RIGHT, swing + legs - (sin(_t * 0.5) * 0.15 if act == "float" else 0.0)))
	_pose("foot.L", Basis.IDENTITY)
	_pose("foot.R", Basis.IDENTITY)
	# arms: from their rest slope to the act's elevation, then toward the front, then the walk's swing
	for s in ["l", "r"]:
		var tag := "L" if s == "l" else "R"
		var side := 1.0 if s == "l" else -1.0
		var e: float = body[s + "e"]
		var reach: float = body[s + "r"]
		if act == "wave" and s == "r":
			e += sin(_t * TAU * 1.6) * 0.3
		var arm_swing := (-swing if s == "l" else swing) * 0.7
		var rz := Basis(Vector3.BACK, side * (e - float(arm_e0.get(s, -0.4))))
		var ry := Basis(Vector3.UP, -side * reach)
		var rx := Basis(Vector3.RIGHT, -arm_swing)
		_pose("arm." + tag, rx * ry * rz)
		_pose("hand." + tag, Basis.IDENTITY)


func _head(k: float, sway: float) -> void:
	if head == null:
		return
	var yaw := 0.0
	if look_target != null:
		var to: Vector3 = model.global_transform.affine_inverse() * (look_target as Vector3)
		to -= head_rest.origin
		yaw = clampf(atan2(to.x, to.z), -0.75, 0.75)
	var hy := lerp_angle(head.get_meta("yaw", 0.0), yaw + sin(_t * 0.7 + _phase) * 0.05 * sway, k * 0.6)
	head.set_meta("yaw", hy)
	var rot := Basis.from_euler(Vector3(p.nod + _flap * 0.04 + sin(_t * 1.3 + _phase) * 0.015 * sway, hy, p.tilt + sin(_t * 0.9 + _phase) * 0.04 * sway))
	var carry := Transform3D.IDENTITY
	if skel and bones.has("spine"):
		var b: int = bones.spine
		var M := _local(skel)
		carry = M * skel.get_bone_global_pose(b) * skel.get_bone_global_rest(b).affine_inverse() * M.affine_inverse()
	head.transform = carry * Transform3D(rot, head_rest.origin)


## The fur and the coat's lining are painted on the meshes' vertices (assets/source/crew_*.py): the imported materials
## need to be told to show them. glTF keeps vertex colours linear; this renderer shows them as they are, so they are
## brought back to sRGB.
static func paint(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var src: Mesh = mi.mesh
		var painted := false
		for k in src.get_surface_count():
			var cols = src.surface_get_arrays(k)[Mesh.ARRAY_COLOR]
			painted = painted or (cols != null and cols.size() > 0)
		if painted:
			var out := ArrayMesh.new()
			var skinned := false
			for k in src.get_surface_count():
				var arrays: Array = src.surface_get_arrays(k)
				skinned = skinned or arrays[Mesh.ARRAY_BONES] != null
				var mat := mi.get_active_material(k)
				var cols = arrays[Mesh.ARRAY_COLOR]
				if cols != null and cols.size() > 0:
					var c2 := PackedColorArray()
					c2.resize(cols.size())
					for i in cols.size():
						c2[i] = cols[i].linear_to_srgb()
					arrays[Mesh.ARRAY_COLOR] = c2
					if mat is StandardMaterial3D:
						mat = mat.duplicate()
						mat.vertex_color_use_as_albedo = true
						mat.albedo_color = Color.WHITE
				var flags := 0
				out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
				out.surface_set_material(out.get_surface_count() - 1, mat)
			mi.mesh = out
	for c in n.get_children():
		paint(c)
