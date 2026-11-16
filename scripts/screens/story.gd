extends "res://scripts/screens/screen.gd"
## The story stage (issue #66): a chapter played as a short film, scene by scene, on its own sets
## (scripts/story/sets.gd): the Andes at night, the launch pad, inside the capsules, Mission Control, the Pacific.
## The cuyes (scripts/story/cuy_actor.gd) stand on their marks, walk, gesture, float in zero gravity and talk with
## their mouths moving; the others turn their heads toward whoever speaks. The camera glides from shot to shot (it
## cuts only when the place changes or a line asks for it), follows whoever moves, and drifts a little, as a hand-held
## camera does. Cinema bars, title cards with the date and the place, a narrator.
## A line may carry stage directions: "set" (go to a place), "cast" (who is there), "place" ({id: [x, y, z, yaw]}),
## "moves" ({id: [x, z]}: walk there), "act" (the speaker's body) and "acts" ({id: act}), "mood" and "all" (moods),
## "shot" (close, two, low, wide, or a camera of the set by name) with "cut", and "fx" (shake, alarm, dim, calm,
## liftoff, splashdown). A line with "wait" and no words lets the stage play.
## Enter or a click goes on, Esc skips to the end. args: {"chapter": "apollo13", "scenes": [...], "back": screen id}; a
## scene may be "chapter/scene", so one film can run on from the prologue into a mission (story(): the whole story).

const CuyActor := preload("res://scripts/story/cuy_actor.gd")
const Dialogue := preload("res://scripts/story/dialogue.gd")
const Sets := preload("res://scripts/story/sets.gd")
const CREW := ["rumi", "killa", "inti", "wayra"]
const BAR := 0.11            ## The black bars, as a fraction of the window's height.
const GLIDE := 1.8           ## How quickly the camera glides to a new shot (higher is quicker).

var chapter := "apollo13"
var scenes: Array = []
var back := "crew_gallery"
var actors := {}
var cast_root: Node3D
var S := {}                  ## The set on stage (Sets.build).
var set_id := ""
var dialogue: Node
var scene_at := -1
var bars: Array = []
var flash: ColorRect
var vignette: ColorRect
var alarm_light: OmniLight3D
var shot := {}               ## The shot now: {"kind", "who", "other", "t0", ...}.
var cam_pos := Vector3.ZERO
var cam_look := Vector3.ZERO
var snap := true
var shake := 0.0
var rumble := 0.0
var alarm := false
var dim := 0.0
var dim_goal := 0.0
var side := 1.0
var last_speaker := ""
var liftoff := -1.0          ## Seconds since ignition (-1: on the pad).
var rocket_v := 0.0
var splash_t := -1.0         ## Seconds since the capsule started coming down (-1: not yet).
var splashed := false        ## The capsule is on the water (kept when the film cuts away and back).
var _t := 0.0
var _saved := {}
var heat := false              ## Mars entry: the cabin's window glows and shakes (Mars's chapter).
var sep_t := -1.0              ## Seconds since the shepherding craft let the Centaur go (LCROSS's chapter).
var mflash_t := -1.0           ## Seconds since the Centaur's flash on the Moon (LCROSS's chapter).
var fireball_t := -1.0         ## Seconds since the craft outside started its plunge into Mars's air.


func enter(args: Dictionary) -> void:
	chapter = args.get("chapter", "apollo13")
	back = args.get("back", "crew_gallery")
	scenes = args.get("scenes", [])
	if scenes.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/%s.json" % chapter))
		scenes = data.get("order", data.scenes.keys()) if data is Dictionary else []
	_save_world()
	world.cam_free = false
	world.cam.fov = 40.0
	cast_root = Node3D.new()
	cast_root.name = "Cast"
	world.add_child(cast_root)
	for id in CREW:
		var a = CuyActor.new()
		a.id = id
		cast_root.add_child(a)
		actors[id] = a
	_build_ui()
	_next_scene()


## What the sets change in the shared world, put back when the film ends.
## The story so far, in order: the prologue, then each chapter (its intro, the mission, its outro), as scene refs.
static func story(chapters := ["prologue", "apollo13", "sts61", "pathfinder", "lcross", "dart", "artemis1"]) -> Array:
	var out := []
	for c in chapters:
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/%s.json" % c))
		if data is Dictionary:
			for sc in data.get("order", []):
				out.append("%s/%s" % [c, sc])
	return out


func _save_world() -> void:
	var env: Environment = world.world_env.environment
	for k in ["background_mode", "background_color", "background_energy_multiplier", "ambient_light_source",
			"ambient_light_color", "ambient_light_energy", "fog_enabled", "fog_density", "fog_light_color", "glow_enabled",
			"tonemap_exposure"]:
		_saved["env." + k] = env.get(k)
	for k in ["light_energy", "light_color", "rotation_degrees", "shadow_enabled", "light_cull_mask"]:
		_saved["sun." + k] = world.sun.get(k)
	_saved["fov"] = world.cam.fov


func _restore_world() -> void:
	var env: Environment = world.world_env.environment
	for k in _saved:
		if k.begins_with("env."):
			env.set(k.substr(4), _saved[k])
		elif k.begins_with("sun."):
			world.sun.set(k.substr(4), _saved[k])
	world.cam.fov = _saved.get("fov", 50.0)


func _build_ui() -> void:
	vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.color = Color(0.9, 0.05, 0.03, 0.0)
	add_child(vignette)
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1.0, 0.97, 0.9, 1.0)       # starts white: the film fades in
	add_child(flash)
	for top in [true, false]:
		var r := ColorRect.new()
		r.color = Color.BLACK
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.anchor_right = 1.0
		r.anchor_top = 0.0 if top else 1.0
		r.anchor_bottom = 0.0 if top else 1.0
		add_child(r)
		bars.append(r)
	flash.color = Color(0, 0, 0, 1)
	var skip := Kit.lbl(tr("Esc skips"), Kit.T_CAPS, Color(1, 1, 1, 0.45), Kit.spaced(Kit.FONT_B, 2))
	Kit.place(skip, 1, 0, 1, 0, -200, 14, -Kit.MARGIN, 40)
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(skip)


func _next_scene() -> void:
	scene_at += 1
	if scene_at >= scenes.size():
		_leave()
		return
	dialogue = Dialogue.new()
	var ref: String = scenes[scene_at]
	var ch := chapter
	if "/" in ref:
		ch = ref.get_slice("/", 0)
		ref = ref.get_slice("/", 1)
	dialogue.lines = Dialogue.load_scene(ch, ref)
	dialogue.live = false
	dialogue.show_portrait = false
	dialogue.line_started.connect(_on_line)
	var play := ""
	for L in dialogue.lines:
		play = str(L.get("play", play))
	dialogue.finished.connect(func(skipped: bool):
		if play != "":
			_play(play)
		elif skipped:
			_skip()
		else:
			_next_scene())
	main.add_child(dialogue)


## Esc skips the film up to the next mission to play (a mission is never skipped), or to the end.
func _skip() -> void:
	for i in range(scene_at + 1, scenes.size()):
		var ref: String = scenes[i]
		var ch := chapter
		if "/" in ref:
			ch = ref.get_slice("/", 0)
			ref = ref.get_slice("/", 1)
		for L in Dialogue.load_scene(ch, ref):
			if L.has("play"):
				scene_at = i
				_play(str(L.play))
				return
	_leave()


## A scene with "play" hands over to that mission's screen; the scenes after it play when the mission is done.
func _play(id: String) -> void:
	if cast_root and is_instance_valid(cast_root):
		cast_root.queue_free()
	world.clear_stage()
	_restore_world()
	go(id, {"campaign": true, "then": scenes.slice(scene_at + 1), "back": back})


func _leave() -> void:
	if cast_root and is_instance_valid(cast_root):
		cast_root.queue_free()
	world.clear_stage()
	_restore_world()
	go(back)


# ===================================================================================== THE SCRIPT
## Each line: where we are, who is there and what they do, where the camera goes, what happens.
func _on_line(_i: int, L: Dictionary) -> void:
	var who := str(L.get("who", ""))
	if L.has("set") and str(L.set) != set_id:
		_go_to_set(str(L.set))
	if L.has("cast"):
		for k in actors:
			actors[k].visible = k in L.cast
	if L.has("place"):
		for k in L.place:
			var a: Array = L.place[k]
			actors[k].global_position = Vector3(a[0], a[1], a[2])
			actors[k].rotation.y = deg_to_rad(a[3])
			actors[k].walk_to = null
	if L.has("moves"):
		for k in L.moves:
			var m: Array = L.moves[k]
			var y: float = actors[k].global_position.y
			actors[k].move_to(Vector3(m[0], y, m[1]), deg_to_rad(m[2]) if m.size() > 2 else null)
	var default_act: String = S.get("act", "idle")
	if L.has("acts"):
		for k in L.acts:
			actors[k].act = str(L.acts[k])
	if actors.has(who):
		actors[who].act = str(L.get("act", actors[who].act if actors[who].act != "walk" else default_act))
	if L.has("all"):
		for k in actors:
			actors[k].set_mood(str(L.all))
	if actors.has(who):
		actors[who].set_mood(str(L.get("mood", "")))
	for k in actors:
		actors[k].talking = false
	_fx(str(L.get("fx", "")))
	var kind := str(L.get("shot", "close" if actors.has(who) else "wide"))
	if not actors.has(who) and kind in ["close", "two", "low"]:
		kind = "wide"
	if L.get("cut", false):
		snap = true
	_frame(kind, who)
	if actors.has(who):
		last_speaker = who


func _go_to_set(id: String) -> void:
	set_id = id
	S = Sets.build(id, world)
	alarm_light = OmniLight3D.new()
	alarm_light.omni_range = 9.0
	alarm_light.light_color = Color(1.0, 0.16, 0.1)
	alarm_light.light_energy = 0.0
	alarm_light.position = Vector3(0, 3.0, 1.0)
	world.stage.add_child(alarm_light)
	alarm = false
	heat = false
	fireball_t = -1.0
	sep_t = -1.0
	mflash_t = -1.0
	rumble = 0.0
	dim = 0.0
	dim_goal = 0.0
	liftoff = -1.0
	rocket_v = 0.0
	splash_t = -1.0
	if S.has("capsule"):
		if splashed:
			S.capsule.position.y = 0.0
			S.chutes.visible = false
		else:
			S.capsule.position.y = 90.0      # still high up, under its parachutes
	var cast: Array = S.get("cast", CREW)
	# a mission's own pieces stay out of the story's scenes; a landed lander shows
	if S.has("craft"):
		(S.craft as Node3D).visible = false
	if S.has("base"):
		(S.base as Node3D).visible = true
		for p in S.get("petals", []):
			(p as Node3D).rotation.x = 0.0
	var sc: float = S.get("actor_scale", 1.0)
	for k in actors:
		var a = actors[k]
		a.scale = Vector3.ONE * sc
		a.visible = k in cast
		var mk: Dictionary = S.marks.get(k, {"pos": Vector3.ZERO, "yaw": 0.0})
		a.global_position = mk.pos
		a.rotation.y = mk.yaw
		a.walk_to = null
		a.face_yaw = null
		a.act = S.get("act", "idle")
	snap = true


func _fx(fx: String) -> void:
	match fx:
		"shake":
			shake = 1.4
			flash.color = Color(1.0, 0.97, 0.9, 0.9)
			Kit.UiSound.play("snap", 0.0)
			Kit.UiSound.play("error", 0.0)
			for k in actors:
				actors[k].shake(1.4)
		"alarm":
			alarm = true
		"dim":
			dim_goal = 0.7
		"calm":
			alarm = false
			dim_goal = 0.0 if set_id != "lm" else dim_goal
		"liftoff":
			liftoff = 0.0
			if S.has("rocket"):
				for f in S.rocket.get_node("Flames").get_children():
					f.emitting = true
			if S.has("smoke"):
				S.smoke.emitting = true
			Kit.UiSound.play("whoosh", 0.0)
		"splashdown":
			splash_t = 0.0
		"heat":
			# entering Mars's air: the window glows orange, the cabin shakes and rumbles
			heat = true
			shake = 0.8
			Kit.UiSound.play("whoosh", 0.0)
			for k in actors:
				actors[k].shake(2.5)
		"fireball":
			heat = true
			fireball_t = 0.0
			Kit.UiSound.play("whoosh", 0.0)
		"separate":
			sep_t = 0.0
			Kit.UiSound.play("snap", 0.0)
		"moonflash":
			mflash_t = 0.0
			if S.has("ejecta"):
				(S.ejecta as CPUParticles3D).restart()
				(S.ejecta as CPUParticles3D).emitting = true
			flash.color = Color(1.0, 0.97, 0.9, 0.35)
			Kit.UiSound.play("whoosh", 0.0)


## Sets the shot the camera glides to.
func _frame(kind: String, who: String) -> void:
	if kind == "close" and who != last_speaker:
		side = -side
	shot = {"kind": kind, "who": who, "other": last_speaker, "t0": _t}
	for k in actors:
		var a = actors[k]
		if k == who or not actors.has(who):
			a.look_target = null if k == who else a.look_target
		else:
			a.look_target = actors[who].face_point()


## Where the camera wants to be now, for the shot (shots of a cuy follow the cuy as it moves).
func _shot_goal() -> Array:
	var kind: String = shot.get("kind", "wide")
	var who: String = shot.get("who", "")
	var cams: Dictionary = S.get("cams", {})
	if cams.has(kind) or not actors.has(who):
		var c: Dictionary = cams.get(kind, cams.get("wide", {"from": Vector3(0, 1, 4), "to": Vector3(0, 0.6, 0)}))
		if c.has("track") and S.has(c.track):
			return [c.from, (S[c.track] as Node3D).global_position + c.get("offset", Vector3.ZERO)]
		if c.has("from2"):
			var k := smoothstep(0.0, 1.0, clampf((_t - shot.get("t0", 0.0)) / float(c.get("time", 6.0)), 0.0, 1.0))
			return [c.from.lerp(c.from2, k), c.to.lerp(c.get("to2", c.to), k)]
		var push := 1.0 - exp(-(_t - shot.get("t0", 0.0)) * 0.15)
		var f: Vector3 = c.from
		return [f + (c.to - f) * 0.12 * push, c.to]
	var a = actors[who]
	var face: Vector3 = a.face_point()
	var sc: float = S.get("actor_scale", 1.0)
	var fwd: Vector3 = a.global_transform.basis.z.normalized() * sc
	var right := fwd.cross(Vector3.UP).normalized()
	var push2 := 1.0 - exp(-(_t - shot.get("t0", 0.0)) * 0.25)
	match kind:
		"two":
			var other: String = shot.get("other", "")
			var b: Vector3 = actors[other].face_point() if actors.has(other) and other != who else face + right * 0.6
			var mid := (face + b) * 0.5
			return [mid + fwd * (2.2 - 0.2 * push2) + Vector3(0, 0.1, 0) * sc, mid - Vector3(0, 0.14, 0) * sc]
		"low":
			return [face + fwd * (1.6 - 0.2 * push2) + right * 0.2 * side * sc + Vector3(0, -0.32, 0) * sc, face - Vector3(0, 0.08, 0) * sc]
		_:
			return [face + fwd * (1.55 - 0.25 * push2) + right * 0.22 * side * sc + Vector3(0, 0.02, 0) * sc, face - Vector3(0, 0.13, 0) * sc]


func process(delta: float) -> void:
	_t += delta
	# the bars close in, the film fades in from black
	var h := get_viewport_rect().size.y * BAR * clampf(_t * 1.2, 0.0, 1.0)
	bars[0].offset_bottom = h
	bars[1].offset_top = -h
	flash.color.a = maxf(0.0, flash.color.a - delta * (0.8 if _t < 2.0 else 2.6))
	# where the camera is going, and how: a cut, or a glide
	var g := _shot_goal()
	var turn := (cam_look - cam_pos).normalized().dot((g[1] - g[0]).normalized())
	if snap or cam_pos.distance_to(g[0]) > 12.0 or turn < 0.6:     # too far or too wide a turn to glide: cut
		cam_pos = g[0]
		cam_look = g[1]
		snap = false
	else:
		var k := 1.0 - exp(-delta * GLIDE)
		cam_pos = cam_pos.lerp(g[0], k)
		cam_look = cam_look.lerp(g[1], k * 1.3)
	shake = maxf(0.0, shake - delta)
	var jolt := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * (0.05 * shake * shake + 0.02 * rumble)
	var drift := Vector3(sin(_t * 0.6), sin(_t * 0.83) * 0.6, sin(_t * 0.47) * 0.4) * 0.012
	world.cam.position = cam_pos + drift + jolt
	if not world.cam.position.is_equal_approx(cam_look):
		world.cam.look_at(cam_look + jolt * 0.5, Vector3.UP)
	# the speaker's mouth, the speaker's eyes on the camera
	if dialogue and is_instance_valid(dialogue) and actors.has(dialogue.speaker):
		var a = actors[dialogue.speaker]
		a.talking = dialogue.writing()
		a.look_target = world.cam.global_position
	_animate_set(delta)


## The set's own life: the fire, the alarm, the power going down, the launch, the splashdown.
func _animate_set(delta: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	# LCROSS: the shepherding craft lets go of the Centaur, then fires its engine to fall behind (its delay burn)
	if S.has("sep_shep"):
		var sh: Node3D = S.sep_shep
		var k := 0.0
		if sep_t >= 0.0:
			sep_t += delta
			k = smoothstep(0.0, 4.5, sep_t)
		sh.position.y = 21.5 + 26.0 * k
		var bm := (S.sep_burn as MeshInstance3D).material_override as StandardMaterial3D
		bm.albedo_color.a = (0.75 + 0.25 * sin(_t * 40.0)) if sep_t > 0.6 and sep_t < 3.6 else 0.0
	# LCROSS: the Centaur's flash at the bottom of Cabeus, seen from far above
	if S.has("moon_flash"):
		var fl: MeshInstance3D = S.moon_flash
		var a := 0.0
		if mflash_t >= 0.0:
			mflash_t += delta
			a = clampf(mflash_t / 0.15, 0.0, 1.0) * clampf(1.0 - (mflash_t - 0.15) / 3.0, 0.0, 1.0)
			fl.scale = Vector3.ONE * (0.4 + mflash_t * 0.5)
		(fl.material_override as StandardMaterial3D).albedo_color.a = a
	# on the way to Mars: the craft turns slowly in the sunlight; at entry it glows and plunges
	if S.has("cruise_spin"):
		(S.cruise_spin as Node3D).rotate_y(delta * 0.25)
	if S.has("plasma"):
		var pm := (S.plasma as MeshInstance3D).material_override as StandardMaterial3D
		pm.albedo_color.a = lerpf(pm.albedo_color.a, (0.42 + 0.12 * sin(_t * 25.0)) if fireball_t >= 0.0 else 0.0, clampf(delta * 3.0, 0.0, 1.0))
		(S.plasma as Node3D).scale = Vector3(1.5, 2.0, 1.5) * (1.0 + 0.06 * sin(_t * 31.0))
	if fireball_t >= 0.0 and S.has("cruise"):
		fireball_t += delta
		var c: Node3D = S.cruise
		var to_mars := (Vector3(-260, -60, -900) - c.global_position).normalized()
		c.global_position += to_mars * delta * (0.6 + fireball_t * 0.8)
		rumble = 0.4
	if S.has("window_glow"):
		var wg := (S.window_glow as MeshInstance3D).material_override as StandardMaterial3D
		wg.albedo_color.a = lerpf(wg.albedo_color.a, (0.75 + 0.25 * sin(_t * 18.0)) if heat else 0.0, clampf(delta * 3.0, 0.0, 1.0))
		(S.heat_light as OmniLight3D).light_energy = lerpf((S.heat_light as OmniLight3D).light_energy, (1.8 + randf_range(-0.4, 0.4)) if heat else 0.0, clampf(delta * 6.0, 0.0, 1.0))
		(S.cabin_light as OmniLight3D).light_energy = 1.1 * (0.55 if heat and randf() < 0.1 else 1.0)
		if heat:
			rumble = maxf(rumble, 0.35)
	if alarm_light:
		alarm_light.light_energy = lerpf(alarm_light.light_energy, (2.4 * pulse) if alarm else 0.0, clampf(delta * 8.0, 0.0, 1.0))
	vignette.color.a = lerpf(vignette.color.a, (0.12 * pulse) if alarm else 0.0, clampf(delta * 8.0, 0.0, 1.0))
	if S.has("alarm_lamp"):
		var am := (S.alarm_lamp as MeshInstance3D).material_override as StandardMaterial3D
		am.emission_energy_multiplier = (4.0 * pulse) if alarm else 0.2
	dim = lerpf(dim, dim_goal, clampf(delta * 1.2, 0.0, 1.0))
	if S.has("flood"):
		S.flood.light_energy = float(S.flood_energy) * (1.0 - dim)
	if S.has("fire_light"):
		S.fire_light.light_energy = 2.4 + sin(_t * 13.0) * 0.25 + sin(_t * 7.3) * 0.35 + randf_range(-0.15, 0.15)
	if S.has("rocket") and liftoff >= 0.0:
		liftoff += delta
		rumble = clampf(liftoff * 0.6, 0.0, 1.0) * clampf(3.0 - liftoff * 0.25, 0.0, 1.0)
		if liftoff > 2.0:                   # the hold-down arms let go after the engines build up thrust
			rocket_v += delta * (4.0 + liftoff * 2.5)
			S.rocket.position.y += rocket_v * delta
	if S.has("capsule"):
		var cm: Node3D = S.capsule
		if splash_t >= 0.0:
			splash_t += delta
			if cm.position.y > 0.0:
				cm.position.y = maxf(0.0, cm.position.y - delta * 9.0)
				if cm.position.y == 0.0:
					splashed = true
					S.splash.emitting = true
					shake = 0.6
					Kit.UiSound.play("snap", 0.0)
			else:
				# the parachutes, cut loose, drift off and settle into the water
				var ch: Node3D = S.chutes
				ch.position = ch.position.lerp(Vector3(18, -9, 6), delta * 0.5)
				ch.scale.y = lerpf(ch.scale.y, 0.05, delta * 0.8)
				ch.visible = ch.position.y > -8.0
		if cm.position.y <= 0.0:
			cm.position.y = sin(_t * 1.1) * 0.12
			cm.rotation.z = sin(_t * 0.8) * 0.04
	if S.has("raft"):
		var bob := sin(_t * 1.3 + 1.0) * 0.08
		S.raft.position.y = bob
		for k in ["rumi", "killa", "inti"]:
			var mk: Dictionary = S.marks.get(k, {})
			if mk and actors[k].walk_to == null:
				actors[k].global_position.y = mk.pos.y + bob
