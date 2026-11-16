extends "res://scripts/screens/screen.gd"
## Mission 2, STS-61 (December 1993): "Glasses for a telescope" (issue #46). Hubble stands in Endeavour's payload bay
## over the Earth. (1) Five spacewalks: Wayra reads each step, the player takes the real part from the toolbox
## (keys 1-6 or a click), then does the job with the hands (scripts/missions/sts61/work_panel.gd: turn bolts out,
## drag pieces into slots, unroll the solar blanket, slide the camera along its rails, aim COSTAR's mirrors) while the
## cuyes float at the spot and the part goes into place in 3D;
## each spacewalk has its own clock, its real length run fast (said on screen); a wrong part costs seconds, and when
## the clock runs out that spacewalk is tried again. (2) The first image: the player turns the correction (arrows,
## wheel or drag) until M100's stars snap to points; then NASA's real images of M100 before and after.
## Rules: scripts/missions/sts61/spacewalks.gd; data: data/missions/sts61.json. Inside the story it is reached from
## the "Your turn" card (args {"campaign": true, "then": [scene refs], "back": id}) and the outro follows.

const TouchKeys := preload("res://scripts/ui/touch_keys.gd")
const Progress := preload("res://scripts/story/campaign_progress.gd")
const Spacewalks := preload("res://scripts/missions/sts61/spacewalks.gd")
const Sets := preload("res://scripts/story/sets.gd")
const CuyActor := preload("res://scripts/story/cuy_actor.gd")
const Instruments := preload("res://scripts/flight/instruments.gd")
const WorkPanel := preload("res://scripts/missions/sts61/work_panel.gd")
const Sound := preload("res://scripts/flight/sound.gd")
const RING_PERIOD := 1.4
const TOOLBOX := 6
const FOCUS := """
shader_type canvas_item;
uniform sampler2D before_tex;
uniform sampler2D after_tex;
uniform float sharp = 0.0;
uniform float blur = 1.0;
void fragment() {
	vec2 px = vec2(1.0 / 480.0) * blur * 9.0;
	vec3 a = vec3(0.0);
	float n = 0.0;
	for (int i = -2; i <= 2; i++) {
		for (int j = -2; j <= 2; j++) {
			a += texture(after_tex, UV + vec2(float(i), float(j)) * px).rgb;
			n += 1.0;
		}
	}
	a /= n;
	vec3 b = texture(before_tex, UV).rgb;
	COLOR = vec4(mix(b, a, sharp), 1.0);
}
"""

var W: Spacewalks
var campaign := false
var then_scenes: Array = []
var back := "menu"
var S := {}
var saved := {}
var actors := {}
var clock: Label
var clock_cap: Label
var clock_note: Label
var houston: Label
var step_rows: Array = []
var walk_dots: Array = []
var toolbox_row: HBoxContainer
var toolbox_panel: PanelContainer
var tiles := {}
var keys: Array = []
var ring: Control
var ring_t := 0.0
var msg: Label
var msg_sub: Label
var flash: ColorRect
var penalty: Label
var tick: AudioStreamPlayer
var heart: AudioStreamPlayer
var cam_pos := Vector3.ZERO
var cam_look := Vector3.ZERO
var held: Node3D               ## The part in hand, floating by the spot.
var held_from := Vector3.ZERO
var work: Control              ## The hands-on job of the part in hand.
var work_box: PanelContainer
var glow: MeshInstance3D       ## The ring of light where the part goes.
var phase := "walks"           ## walks, between, lost, focus, done
var phase_t := 0.0
var _last_sec := -1
var _said := {}
var _heart_t := 0.0
var _t := 0.0
# the first image
var focus_box: Control
var focus_img: TextureRect
var dial := 0.0
var target := 0.7
var lock_t := 0.0
var dial_bar: ProgressBar
var sharp_lbl: Label
var photo_shown := false


func enter(args: Dictionary) -> void:
	campaign = args.get("campaign", false)
	then_scenes = args.get("then", [])
	back = args.get("back", "menu")
	W = Spacewalks.new()
	saved = Sets.save_world(world)
	world.cam_free = false
	world.cam.fov = 45.0
	S = Sets.build("hubble", world)
	for id in ["inti", "rumi", "killa"]:
		var a = CuyActor.new()
		a.id = id
		world.stage.add_child(a)
		a.act = "float"
		actors[id] = a
	actors.killa.global_position = Vector3(6.5, 4.0, 6.0)
	glow = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.15
	glow.mesh = tm
	glow.material_override = Sets.mat(Kit.C_GOLD, 0.4, 0.0, 3.0)
	world.stage.add_child(glow)
	tick = Sound.player(self, "beep", -14.0)
	heart = Sound.player(self, "thud", -9.0)
	_build_ui()
	_start_walk()
	cam_pos = _cam_goal()[0]
	cam_look = _cam_goal()[1]
	TouchKeys.attach(self)


func exit() -> void:
	Engine.time_scale = 1.0
	Sets.restore_world(world, saved)


# ===================================================================================== THE INTERFACE
func _build_ui() -> void:
	var head := Kit.vbox(2)
	Kit.place(head, 0, 0, 0, 0, Kit.MARGIN, Kit.MARGIN, 520, 100)
	add_child(head)
	var over := Kit.caps(tr("Mission 2 · STS-61 · December 1993"))
	over.add_theme_color_override("font_color", Color(Kit.C_ON_DARK, 0.75))
	head.add_child(over)
	head.add_child(Kit.lbl(tr("Glasses for a telescope"), Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T))
	# the clock of this spacewalk
	var cp := Kit.panel_box(Kit.PAD)
	Kit.place(cp, 0.5, 0, 0.5, 0, -190, Kit.MARGIN, 190, Kit.MARGIN + 130)
	add_child(cp)
	var cv := Kit.vbox(0)
	cp.add_child(cv)
	clock_cap = Kit.caps("")
	clock_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(clock_cap)
	clock = Kit.lbl("", Kit.T_CLOCK + 16, Kit.C_GOLD, Kit.font_num())
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(clock)
	clock_note = Kit.lbl("", Kit.T_SMALL, Kit.C_DIM)
	clock_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(clock_note)
	var dots := Kit.hbox(6)
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_child(dots)
	for i in W.walks().size():
		var d := Kit.lbl("●", Kit.T_BODY, Kit.C_DIM)
		dots.add_child(d)
		walk_dots.append(d)
	penalty = Kit.lbl("", Kit.T_ACTION, Kit.C_BAD, Kit.FONT_T)
	Kit.place(penalty, 0.5, 0, 0.5, 0, 200, Kit.MARGIN + 30, 340, Kit.MARGIN + 70)
	penalty.add_theme_constant_override("outline_size", 8)
	penalty.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	add_child(penalty)
	# Wayra on the radio
	var hp := Kit.panel_box(Kit.PAD)
	Kit.place(hp, 1, 0, 1, 0, -Kit.MARGIN - 430, Kit.MARGIN, -Kit.MARGIN, Kit.MARGIN + 60)
	add_child(hp)
	var hv := Kit.vbox(Kit.GAP)
	hp.add_child(hv)
	var hh := Kit.hbox(Kit.GAP)
	hv.add_child(hh)
	hh.add_child(Kit.chip("Wayra", Kit.C_ACCENT))
	hh.add_child(Kit.lbl(tr("Mission Control, on the radio"), Kit.T_SMALL, Kit.C_DIM))
	houston = Kit.lbl("", Kit.T_ACTION - 2, Kit.C_TEXT, Kit.FONT_B, true)
	houston.custom_minimum_size.x = 380
	hv.add_child(houston)
	hv.add_child(Kit.rule())
	for i in 3:
		var row := Kit.lbl("", Kit.T_BODY, Kit.C_DIM, Kit.FONT_R, true)
		hv.add_child(row)
		step_rows.append(row)
	# the toolbox
	toolbox_panel = Kit.panel_box(Kit.PAD)
	Kit.place(toolbox_panel, 0.5, 1, 0.5, 1, -560, -210, 560, -Kit.MARGIN)
	toolbox_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(toolbox_panel)
	var tv := Kit.vbox(Kit.GAP)
	toolbox_panel.add_child(tv)
	tv.add_child(Kit.caps(tr("The toolbox · press 1 to 6 or click")))
	toolbox_row = Kit.hbox(Kit.GAP)
	tv.add_child(toolbox_row)
	ring = Instruments.TimingRing.new()
	Kit.place(ring, 0.5, 0.5, 0.5, 0.5, -320, -230, 320, 250)
	add_child(ring)
	work_box = Kit.panel_box(8)
	Kit.place(work_box, 0.5, 1, 0.5, 1, -388, -362, 388, -Kit.MARGIN)
	work_box.visible = false
	add_child(work_box)
	work = WorkPanel.new()
	work_box.add_child(work)
	work.finished.connect(_on_work_done)
	msg = Kit.lbl("", Kit.T_SHOUT, Kit.C_GOLD, Kit.FONT_T)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Kit.place(msg, 0, 0.5, 1, 0.5, 0, -300, 0, -230)
	msg.add_theme_constant_override("outline_size", 12)
	msg.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	msg.visible = false
	add_child(msg)
	msg_sub = Kit.lbl("", Kit.T_ACTION, Kit.C_ON_DARK, Kit.FONT_B)
	msg_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Kit.place(msg_sub, 0, 0.5, 1, 0.5, 0, -226, 0, -190)
	msg_sub.add_theme_constant_override("outline_size", 8)
	msg_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	msg_sub.visible = false
	add_child(msg_sub)
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 1, 1, 0)
	add_child(flash)


func _part(id: String) -> Dictionary:
	for P in W.D.parts:
		if P.id == id:
			return P
	return {}


## The toolbox of this spacewalk: its parts, others from the mission, and Killa's lens cloth, in a shuffled order.
func _fill_toolbox() -> void:
	for c in toolbox_row.get_children():
		c.queue_free()
	tiles.clear()
	keys.clear()
	var ids: Array = W.current_walk().steps.map(func(st): return st.part)
	var rng := RandomNumberGenerator.new()
	rng.seed = 61 + W.walk * 7
	var others: Array = W.D.parts.map(func(P): return P.id).filter(func(x): return not ids.has(x) and x != "cloth")
	while ids.size() < TOOLBOX - 1 and not others.is_empty():
		ids.append(others.pop_at(rng.randi() % others.size()))
	ids.append("cloth")
	for i in ids.size():
		var j := rng.randi() % ids.size()
		var tmp = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	for i in ids.size():
		keys.append(ids[i])
		var t := _tile(i + 1, _part(ids[i]))
		toolbox_row.add_child(t)
		tiles[ids[i]] = t


func _tile(n: int, P: Dictionary) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Kit.flat(Kit.C_CARD, Kit.C_EDGE, 10, 1, 8, 8))
	pc.custom_minimum_size = Vector2(170, 0)
	pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pc.tooltip_text = tr(P.line)
	pc.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_pick(P.id))
	var v := Kit.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(v)
	var icon := PartIcon.new()
	icon.part = P.id
	icon.custom_minimum_size = Vector2(150, 62)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon)
	var name_l := Kit.lbl("%d  %s" % [n, tr(P.name)], Kit.T_BODY - 1, Kit.C_TEXT, Kit.FONT_B, true)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	return pc


func _start_walk() -> void:
	var Wk := W.current_walk()
	phase = "walks"
	_said.clear()
	_fill_toolbox()
	clock_cap.text = tr("Spacewalk %d of 5") % (W.walk + 1) + "  ·  " + str(Wk.crew)
	clock_note.text = tr("Its real length, %s, run %d times faster") % [_hm(float(Wk.minutes)), int(round(W.speed()))]
	for i in walk_dots.size():
		walk_dots[i].add_theme_color_override("font_color", Kit.C_OK if i < W.walk else (Kit.C_GOLD if i == W.walk else Kit.C_DIM))
	_show_step()


func _show_step() -> void:
	var cur := W.current()
	houston.text = tr(str(cur.get("houston", "")))
	var Wk := W.current_walk()
	for i in step_rows.size():
		var row: Label = step_rows[i]
		if Wk.is_empty() or i >= Wk.steps.size():
			row.text = ""
			continue
		var nm := tr(_part(Wk.steps[i].part).name)
		if i < W.step:
			row.text = "✓  " + nm
			row.add_theme_color_override("font_color", Kit.C_OK)
		elif i == W.step:
			row.text = "▶  " + nm
			row.add_theme_color_override("font_color", Kit.C_GOLD)
		else:
			row.text = "·  " + nm
			row.add_theme_color_override("font_color", Kit.C_DIM)
	# the crew go to the spot; the light marks it
	var spot: Vector3 = S.spots.get(W.needed(), Vector3.ZERO)
	var out := _outward(spot)
	glow.global_position = spot + out * 0.3
	out = _view(out)
	glow.look_at(spot + out * 2.0, Vector3.UP if absf(out.y) < 0.9 else Vector3.RIGHT)
	glow.rotate_object_local(Vector3.RIGHT, PI / 2)
	var side := out.cross(Vector3.UP).normalized()
	# they float there on their tethers (no walking in space)
	var marks := {"inti": spot + out * 1.6 + side * 1.0 + Vector3(0, -0.6, 0), "rumi": spot + out * 1.8 - side * 1.1 + Vector3(0, -0.9, 0)}
	for k in marks:
		var a = actors[k]
		a.create_tween().tween_property(a, "global_position", marks[k], 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var face: Vector3 = spot - marks[k]
		a.rotation.y = atan2(face.x, face.z)
		a.look_target = spot


## The direction from Hubble's axis out through a spot (up for the top).
func _outward(spot: Vector3) -> Vector3:
	var hub: Vector3 = (S.hubble as Node3D).global_position
	var d := spot - hub
	if d.y > 43.0:
		return Vector3(0, 0.35, 1).normalized()
	d.y = 0.0
	return d.normalized() if d.length() > 0.1 else Vector3(0, 0, 1)


## Where the camera and the crew look at a spot from: straight out, except on Hubble's sides, where the solar wings
## stand, which are seen from the front at an angle so no wing comes between the camera and the work.
func _view(out: Vector3) -> Vector3:
	if absf(out.x) > 0.6:
		return (out * 0.55 + Vector3(0, 0, 1)).normalized()
	return out


func _cam_goal() -> Array:
	if phase == "focus" or phase == "done":
		return [Vector3(26, 30, 60), Vector3(0, 22, -6)]
	var spot: Vector3 = S.spots.get(W.needed(), Vector3(0, 20, -6))
	var out := _view(_outward(spot))
	var side := out.cross(Vector3.UP).normalized()
	if absf(out.y) > 0.9:
		side = Vector3.RIGHT
	# while working, the camera comes closer and looks a little above the panel
	var near := 11.0 if work_box and work_box.visible else 15.0
	return [spot + out * near + side * 4.0 + Vector3(0, 4.0, 0), spot + Vector3(0, -2.5, 0)]


static func _hm(minutes: float) -> String:
	var m := int(ceil(minutes))
	return "%d h %02d min" % [m / 60, m % 60]


# ===================================================================================== PLAY
func _pick(id: String) -> void:
	if phase != "walks":
		return
	var r := W.pick(id)
	var pc: PanelContainer = tiles.get(id)
	match r:
		"ok":
			Kit.UiSound.play("select")
			houston.text = tr("In hand. Now do the job: the panel shows how.")
			_hold(id)
			var st := W.current()
			work.setup(str(st.get("do", "drag")), int(st.get("count", 1)), PART_COLOURS.get(id, Color(0.8, 0.8, 0.8)), tr(_part(id).name))
			toolbox_panel.visible = false
			work_box.visible = true
			if id == "arrays":
				# the old wings come off; the new ones grow as the blanket is unrolled
				var wings: Node3D = S.wings
				for c in wings.get_children():
					c.queue_free()
				Sets._wings(wings, Color(0.12, 0.2, 0.5))
				wings.scale = Vector3(1, 0.05, 1)
				held.visible = false
		"wrong", "cloth":
			Kit.UiSound.play("error")
			houston.text = tr(W.D.cloth if r == "cloth" else W.D.wrong)
			if r == "cloth":
				actors.killa.set_mood("happy")
				actors.killa.act = "wave"
			penalty.text = "-%d s" % int(W.WRONG_COST)
			penalty.modulate.a = 1.0
			penalty.position.y = Kit.MARGIN + 30
			var pt := penalty.create_tween()
			pt.tween_property(penalty, "position:y", Kit.MARGIN + 70, 1.2)
			pt.parallel().tween_property(penalty, "modulate:a", 0.0, 1.2)
			if pc:
				var tw := pc.create_tween()
				for k in 3:
					tw.tween_property(pc, "position:x", pc.position.x + 8, 0.04)
					tw.tween_property(pc, "position:x", pc.position.x - 8, 0.04)
				tw.tween_property(pc, "position:x", pc.position.x, 0.04)
			get_tree().create_timer(1.8).timeout.connect(func():
				if is_inside_tree() and phase == "walks" and W.picked == "":
					_show_step()
					actors.killa.act = "float")


## The part, as a small box of its colour, floats out to the spot with the crew.
func _hold(id: String) -> void:
	if held and is_instance_valid(held):
		held.queue_free()
	held = Node3D.new()
	world.stage.add_child(held)
	var spot: Vector3 = S.spots.get(id, Vector3.ZERO)
	var out := _outward(spot)
	held_from = spot + _view(out) * 2.4 + Vector3(0, 0.6, 0)
	held.global_position = held_from
	var col: Color = PART_COLOURS.get(id, Color(0.8, 0.8, 0.8))
	if id == "arrays":
		Sets.box(held, Vector3(0.2, 3.0, 1.2), Vector3.ZERO, Sets.mat(col, 0.4, 0.4))
	else:
		Sets.box(held, Vector3(1.2, 0.8, 0.8), Vector3.ZERO, Sets.mat(col, 0.4, 0.5))
	held.scale = Vector3.ONE * 0.01
	held.create_tween().tween_property(held, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)


const PART_COLOURS := {"rsu": Color(0.85, 0.75, 0.4), "ecu": Color(0.6, 0.7, 0.8), "fuses": Color(0.9, 0.4, 0.3),
	"arrays": Color(0.15, 0.22, 0.5), "wfpc2": Color(0.9, 0.9, 0.95), "magnetometers": Color(0.7, 0.7, 0.75),
	"costar": Color(0.85, 0.85, 0.8), "coprocessor": Color(0.3, 0.6, 0.35), "sade": Color(0.75, 0.7, 0.55),
	"ghrs": Color(0.8, 0.6, 0.35), "covers": Color(0.95, 0.95, 0.95)}


## The job is done: the part is in. A clean job counts as perfect.
func _on_work_done(mistakes: int) -> void:
	var grade := "perfect" if mistakes == 0 else ("good" if mistakes <= 2 else "late")
	(ring as Instruments.TimingRing).grade(tr(grade.to_upper()), Kit.C_OK if grade == "perfect" else (Kit.C_ACCENT if grade == "good" else Kit.C_WARN))
	get_tree().create_timer(0.5).timeout.connect(_apply_work.bind(grade))


func _apply_work(grade: String) -> void:
	if not is_inside_tree() or W.picked == "":
		return
	work_box.visible = false
	toolbox_panel.visible = true
	var id := W.picked
	var r := W.press(grade)
	_fit(id)
	match r:
		"next":
			_show_step()
		"walk":
			_walk_done(false)
		"all":
			_walk_done(true)


func _press() -> void:
	var rem := 1.0 - ring_t / (RING_PERIOD * 0.8)
	var grade := "late"
	var col := Kit.C_WARN
	if absf(rem) <= 0.08:
		grade = "perfect"
		col = Kit.C_OK
	elif absf(rem) <= 0.2:
		grade = "good"
		col = Kit.C_ACCENT
	(ring as Instruments.TimingRing).grade(tr(grade.to_upper()), col)
	Kit.UiSound.play("snap")
	var id := W.picked
	var r := W.press(grade)
	_fit(id)
	match r:
		"next":
			_show_step()
		"walk":
			_walk_done(false)
		"all":
			_walk_done(true)


## The part slides into its place; the new solar arrays replace the old.
func _fit(id: String) -> void:
	if held and is_instance_valid(held):
		var h := held
		var spot: Vector3 = S.spots.get(id, h.global_position)
		var tw := h.create_tween()
		tw.tween_property(h, "global_position", spot, 0.35).set_trans(Tween.TRANS_QUAD)
		if id != "arrays":
			tw.tween_property(h, "scale", Vector3.ONE * 0.6, 0.2)
		else:
			tw.tween_callback(h.queue_free)
		held = null
	if id == "arrays":
		var wings: Node3D = S.wings
		wings.create_tween().tween_property(wings, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_QUAD)
	for k in ["inti", "rumi"]:
		actors[k].hop()


func _walk_done(all: bool) -> void:
	phase = "between"
	phase_t = 0.0
	Kit.UiSound.play("success", 0.0)
	msg.text = tr(W.D.walk_done) % W.walk
	msg_sub.text = tr("All five: Hubble is fixed. Now the first image.") if all else tr("Back to the airlock. Next: spacewalk %d.") % (W.walk + 1)
	msg.visible = true
	msg_sub.visible = true
	msg.pivot_offset = Vector2(msg.size.x * 0.5, 30)
	msg.scale = Vector2(0.6, 0.6)
	msg.create_tween().tween_property(msg, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK)
	for k in actors:
		actors[k].act = "cheer"
		actors[k].set_mood("happy")
	(ring as Instruments.TimingRing).active = false


var lose_layer: Control


## Out of time: the screen goes dark and red, the crew slump, and the spacewalk is tried again.
func _lose() -> void:
	phase = "lost"
	phase_t = 0.0
	Kit.UiSound.play("error", 0.0)
	if held and is_instance_valid(held):
		held.queue_free()
	houston.text = tr("Press Enter to try this spacewalk again.")
	for k in actors:
		actors[k].set_mood("tired")
		actors[k].act = "hide"
	lose_layer = Control.new()
	lose_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(lose_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.0, 0.0, 0.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lose_layer.add_child(shade)
	shade.create_tween().tween_property(shade, "color:a", 0.78, 1.0)
	var v := Kit.vbox(Kit.GAP)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.modulate.a = 0.0
	lose_layer.add_child(v)
	var big := Kit.lbl(tr(W.D.lost), Kit.T_SHOUT, Kit.C_BAD, Kit.FONT_T)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var sub := Kit.lbl(tr(W.D.lost_sub), Kit.T_ACTION, Kit.C_ON_DARK, Kit.FONT_B, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.custom_minimum_size.x = 900
	v.add_child(sub)
	var row := Kit.hbox(Kit.GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var again := Kit.btn(tr("Try again  ·  Enter"), _retry, Kit.T_BODY)
	Kit.accent_btn(again, Kit.C_GOLD)
	row.add_child(again)
	v.create_tween().tween_property(v, "modulate:a", 1.0, 0.7).set_delay(0.6)
	again.grab_focus()


func _retry() -> void:
	if lose_layer and is_instance_valid(lose_layer):
		lose_layer.queue_free()
	W.retry()
	msg.visible = false
	msg_sub.visible = false
	msg.add_theme_color_override("font_color", Kit.C_GOLD)
	for k in actors:
		actors[k].set_mood("determined")
		actors[k].act = "float"
	_start_walk()


# ===================================================================================== THE FIRST IMAGE
func _start_focus() -> void:
	phase = "focus"
	msg.visible = false
	msg_sub.visible = false
	toolbox_panel.visible = false
	glow.visible = false
	clock_cap.text = tr("The first image")
	clock.text = "M100"
	clock.add_theme_color_override("font_color", Kit.C_GOLD)
	clock_note.text = tr(W.D.focus.note)
	houston.text = tr(W.D.focus.houston)
	for row in step_rows:
		row.text = ""
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	target = rng.randf_range(0.55, 0.9)
	dial = 0.0
	focus_box = Kit.panel_box(Kit.PAD)
	Kit.place(focus_box, 0.5, 0.5, 0.5, 0.5, -270, -230, 270, 330)
	add_child(focus_box)
	move_child(focus_box, flash.get_index())
	var v := Kit.vbox(Kit.GAP)
	focus_box.add_child(v)
	focus_img = TextureRect.new()
	focus_img.custom_minimum_size = Vector2(440, 440)
	focus_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	focus_img.texture = load(W.D.focus.after)
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FOCUS
	m.shader = sh
	m.set_shader_parameter("before_tex", load(W.D.focus.before))
	m.set_shader_parameter("after_tex", load(W.D.focus.after))
	focus_img.material = m
	v.add_child(focus_img)
	var row := Kit.hbox(Kit.GAP)
	v.add_child(row)
	row.add_child(Kit.lbl(tr("Correction"), Kit.T_BODY, Kit.C_DIM, Kit.FONT_B))
	dial_bar = ProgressBar.new()
	dial_bar.min_value = 0.0
	dial_bar.max_value = 1.0
	dial_bar.show_percentage = false
	dial_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dial_bar.custom_minimum_size.y = 22
	dial_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	dial_bar.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT):
			dial = clampf(e.position.x / dial_bar.size.x, 0.0, 1.0))
	row.add_child(dial_bar)
	sharp_lbl = Kit.lbl("", Kit.T_BODY, Kit.C_GOLD, Kit.FONT_B)
	row.add_child(sharp_lbl)
	v.add_child(Kit.lbl(tr("← → or the wheel turn the correction; stop when the stars are points."), Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))
	for k in actors:
		actors[k].act = "float"
		actors[k].set_mood("curious")


func _focus_update(delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		dial = minf(1.0, dial + delta * 0.35)
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		dial = maxf(0.0, dial - delta * 0.35)
	var err := absf(dial - target)
	var q := clampf(1.0 - err / 0.5, 0.0, 1.0)
	var m := focus_img.material as ShaderMaterial
	m.set_shader_parameter("sharp", smoothstep(0.35, 1.0, q))
	m.set_shader_parameter("blur", clampf(err * 3.0, 0.0, 1.0))
	dial_bar.value = dial
	sharp_lbl.text = "%d %%" % int(round(q * 100.0))
	if err < 0.03:
		lock_t += delta
		if lock_t > 0.5:
			_sharp()
	else:
		lock_t = 0.0


func _sharp() -> void:
	phase = "done"
	phase_t = 0.0
	dial = target
	var m := focus_img.material as ShaderMaterial
	m.set_shader_parameter("sharp", 1.0)
	m.set_shader_parameter("blur", 0.0)
	flash.color.a = 0.85
	Kit.UiSound.play("fanfare", 0.0)
	msg.text = tr(W.D.focus.win)
	msg_sub.text = tr(W.D.focus.win_sub)
	msg.visible = true
	msg_sub.visible = true
	msg.pivot_offset = Vector2(msg.size.x * 0.5, 30)
	msg.scale = Vector2(0.6, 0.6)
	msg.create_tween().tween_property(msg, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK)
	for k in actors:
		actors[k].act = "cheer"
		actors[k].set_mood("happy")


## The real thing: NASA's M100 before and after, the stars, and what comes next.
func _show_photo() -> void:
	photo_shown = true
	msg.visible = false
	msg_sub.visible = false
	if focus_box:
		focus_box.visible = false
	var shade := ColorRect.new()
	shade.color = Kit.C_SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var p := Kit.panel_box(Kit.PAD)
	Kit.place(p, 0.5, 0.5, 0.5, 0.5, -560, -320, 560, 320)
	add_child(p)
	var v := Kit.vbox(Kit.GAP)
	p.add_child(v)
	var top := Kit.hbox(Kit.PAD)
	v.add_child(top)
	for pair in [[W.D.focus.before, tr("Before: WFPC1, 1993")], [W.D.focus.after, tr("After: WFPC2, this mission")]]:
		var col := Kit.vbox(4)
		top.add_child(col)
		var img := TextureRect.new()
		img.texture = load(pair[0])
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.custom_minimum_size = Vector2(330, 330)
		col.add_child(img)
		col.add_child(Kit.lbl(pair[1], Kit.T_SMALL + 1, Kit.C_DIM, Kit.FONT_B))
	var side := Kit.vbox(Kit.GAP)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(side)
	side.add_child(Kit.caps(tr("Mission 2 · done")))
	var stars := W.stars()
	Progress.earn("sts61", stars)
	side.add_child(Kit.lbl("★".repeat(stars) + "☆".repeat(3 - stars), Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T))
	side.add_child(Kit.lbl(tr("Wrong parts: %d · Retries: %d · Perfect fits: %d of %d") % [W.wrong, W.retries, W.perfect, W.presses], Kit.T_SMALL + 1, Kit.C_DIM, Kit.FONT_R, true))
	side.add_child(Kit.rule())
	side.add_child(Kit.lbl(tr(W.D.focus.caption), Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B, true))
	side.add_child(Kit.lbl(W.D.focus.credit, Kit.T_SMALL, Kit.C_DIM))
	for F in W.D.facts:
		var fh := Kit.hbox(Kit.GAP)
		fh.add_child(Kit.chip("NASA", Kit.C_GOLD))
		var fl := Kit.lbl(tr(F.text), Kit.T_SMALL + 1, Kit.C_DIM, Kit.FONT_R, true)
		fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fh.add_child(fl)
		side.add_child(fh)
	var row := Kit.hbox(Kit.GAP)
	v.add_child(row)
	var go_on := Kit.btn(tr("Continue  ·  Enter"), _continue, Kit.T_BODY)
	Kit.accent_btn(go_on, Kit.C_GOLD)
	row.add_child(go_on)
	row.add_child(Kit.btn(tr("Play again  ·  R"), _again, Kit.T_BODY))
	go_on.grab_focus()


func _again() -> void:
	go("sts61", {"campaign": campaign, "then": then_scenes, "back": back})


func _continue() -> void:
	if not then_scenes.is_empty():
		go("story", {"scenes": then_scenes, "back": back})
	else:
		go(back)


# ===================================================================================== EVERY FRAME
func process(delta: float) -> void:
	_t += delta
	phase_t += delta
	flash.color.a = maxf(0.0, flash.color.a - delta * 1.5)
	# the camera glides to the work, with a breath of drift (and a little shake when time is short)
	var g := _cam_goal()
	var k := 1.0 - exp(-delta * 1.6)
	cam_pos = cam_pos.lerp(g[0], k)
	cam_look = cam_look.lerp(g[1], k * 1.2)
	var short := clampf(1.0 - W.left / 15.0, 0.0, 1.0) if phase == "walks" else 0.0
	var jit := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.04 * short
	world.cam.position = cam_pos + Vector3(sin(_t * 0.3), sin(_t * 0.23), 0) * 0.25 + jit
	world.cam.look_at(cam_look, Vector3.UP)
	glow.scale = Vector3.ONE * (1.0 + 0.12 * sin(_t * 5.0))
	# the solar wings stand on Hubble's sides: when the work is there, they fade so they never hide the crew
	var side_work := false
	if phase == "walks" and W.needed() != "" and W.needed() != "arrays":
		side_work = absf(_outward(S.spots.get(W.needed(), Vector3.ZERO)).x) > 0.6
	var wings: Node3D = S.wings
	if wings.has_meta("mats"):
		for m in wings.get_meta("mats"):
			(m as StandardMaterial3D).albedo_color.a = move_toward((m as StandardMaterial3D).albedo_color.a, 0.18 if side_work else 1.0, delta * 2.0)
	if held and is_instance_valid(held):
		held.rotate_y(delta * 0.3)
		if work_box.visible and W.picked == "arrays":
			(S.wings as Node3D).scale.y = maxf(0.05, work.progress)
		if work_box.visible:
			var spot: Vector3 = S.spots.get(W.picked, held_from)
			held.global_position = held_from.lerp(spot, smoothstep(0.0, 1.0, work.progress) * 0.85)
	match phase:
		"walks":
			W.update(delta)
			var left := W.real_minutes_left()
			clock.text = _hm(left).replace(" h ", ":").replace(" min", "")
			var col: Color = Kit.C_BAD if W.left <= 10.0 else (Kit.C_WARN if W.left <= 20.0 else Kit.C_GOLD)
			clock.add_theme_color_override("font_color", col if W.left > 10.0 or int(_t * 4.0) % 2 == 0 else Kit.C_TEXT)
			clock.pivot_offset = clock.size * 0.5
			clock.scale = Vector2.ONE * (1.0 + (0.08 * (0.5 + 0.5 * sin(_t * 10.0)) if W.left <= 10.0 else 0.0))
			var sec := int(ceil(W.left))
			if sec != _last_sec and sec <= 10 and sec > 0:
				tick.play()
			_last_sec = sec
			for key in W.D.urgent:
				if W.left <= float(key) and not _said.has(key) and W.picked == "":
					_said[key] = true
					houston.text = tr(W.D.urgent[key])
			_heart_t -= delta
			if _heart_t <= 0.0 and W.left < 25.0:
				heart.play()
				_heart_t = lerpf(1.0, 0.45, short)
			var tr_ring := ring as Instruments.TimingRing
			tr_ring.active = false
			if W.lost:
				work_box.visible = false
				toolbox_panel.visible = true
				_lose()
		"between":
			if phase_t > 2.4:
				msg.visible = false
				msg_sub.visible = false
				for key in actors:
					actors[key].act = "float"
				if W.done():
					_start_focus()
				else:
					_start_walk()
		"focus":
			_focus_update(delta)
		"done":
			if phase_t > 2.6 and not photo_shown:
				_show_photo()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and phase == "focus":
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			dial = minf(1.0, dial + 0.02)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dial = maxf(0.0, dial - 0.02)
		return
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = e.physical_keycode
	if photo_shown:
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			_continue()
		elif k == KEY_R:
			_again()
		else:
			return
	elif phase == "lost":
		if k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_R:
			_retry()
		else:
			return
	elif phase == "walks" and k >= KEY_1 and k <= KEY_9 and k - KEY_1 < keys.size():
		_pick(keys[k - KEY_1])
	elif phase == "walks" and k == KEY_SPACE and W.picked != "":
		work.key_space()
	elif k == KEY_ESCAPE:
		go(back)
	else:
		return
	get_viewport().set_input_as_handled()


# ===================================================================================== DRAWINGS
## A drawing of a part, from simple shapes.
class PartIcon extends Control:
	var part := ""

	func _draw() -> void:
		var c := size * 0.5
		var metal := Color(0.72, 0.74, 0.78)
		match part:
			"rsu":
				draw_rect(Rect2(c + Vector2(-30, -20), Vector2(60, 40)), metal)
				draw_arc(c, 13, 0, TAU, 28, Color(0.85, 0.7, 0.3), 4.0)
				draw_line(c + Vector2(-13, 0), c + Vector2(13, 0), Color(0.85, 0.7, 0.3), 2.0)
			"ecu", "sade":
				draw_rect(Rect2(c + Vector2(-30, -20), Vector2(60, 40)), metal if part == "ecu" else Color(0.8, 0.74, 0.55))
				for i in 4:
					draw_rect(Rect2(c + Vector2(-26 + i * 14, 22), Vector2(6, 8)), Color(0.4, 0.4, 0.45))
				draw_rect(Rect2(c + Vector2(-12, -8), Vector2(24, 16)), Color(0.2, 0.25, 0.3))
			"fuses":
				for i in 8:
					draw_rect(Rect2(c + Vector2(-38 + i * 10, -14), Vector2(7, 28)), Color(0.9, 0.4, 0.3) if i % 2 == 0 else Color(0.95, 0.85, 0.5))
			"arrays":
				draw_rect(Rect2(c + Vector2(-44, -22), Vector2(88, 44)), Color(0.15, 0.22, 0.5))
				for i in 5:
					draw_line(c + Vector2(-44 + i * 22, -22), c + Vector2(-44 + i * 22, 22), Color(0.85, 0.65, 0.25), 2.0)
			"wfpc2":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-34, -22), c + Vector2(34, -22), c + Vector2(24, 22), c + Vector2(-24, 22)]), Color(0.9, 0.9, 0.95))
				draw_circle(c + Vector2(0, -6), 7, Color(0.2, 0.25, 0.35))
			"magnetometers", "covers":
				draw_rect(Rect2(c + Vector2(-34, -6), Vector2(68, 12)), metal if part == "magnetometers" else Color(0.95, 0.95, 0.95))
				draw_circle(c + Vector2(-34, 0), 8, metal)
				draw_circle(c + Vector2(34, 0), 8, metal)
			"costar":
				draw_rect(Rect2(c + Vector2(-20, -26), Vector2(40, 52)), Color(0.85, 0.85, 0.8))
				for sy in [-1, 1]:
					draw_line(c + Vector2(20, sy * 10), c + Vector2(40, sy * 16), metal, 4.0)
					draw_circle(c + Vector2(40, sy * 16), 5, Color(0.5, 0.75, 1.0))
			"coprocessor":
				draw_rect(Rect2(c + Vector2(-26, -20), Vector2(52, 40)), Color(0.3, 0.6, 0.35))
				for i in 5:
					draw_line(c + Vector2(-26, -14 + i * 7), c + Vector2(-34, -14 + i * 7), metal, 2.0)
					draw_line(c + Vector2(26, -14 + i * 7), c + Vector2(34, -14 + i * 7), metal, 2.0)
			"ghrs":
				draw_rect(Rect2(c + Vector2(-32, -18), Vector2(64, 36)), Color(0.8, 0.6, 0.35))
				draw_rect(Rect2(c + Vector2(-10, -24), Vector2(20, 8)), Color(0.4, 0.3, 0.2))
			"cloth":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-28, -18), c + Vector2(26, -24), c + Vector2(30, 20), c + Vector2(-24, 24)]), Color(1.0, 0.6, 0.75))
				for p in [Vector2(-34, -26), Vector2(36, -2), Vector2(-6, 30)]:
					draw_line(c + p + Vector2(-5, 0), c + p + Vector2(5, 0), Color(1, 1, 0.8), 2.0)
					draw_line(c + p + Vector2(0, -5), c + p + Vector2(0, 5), Color(1, 1, 0.8), 2.0)
			_:
				draw_rect(Rect2(c + Vector2(-24, -24), Vector2(48, 48)), metal)


## The buttons a phone needs now (scripts/ui/touch_keys.gd): the parts are tapped; the work needs its keys.
func touch_keys() -> Array:
	if phase == "walks" and W.picked != "":
		return [["◀", KEY_A, "left"], ["▶", KEY_D, "left"], ["▼", KEY_S, "left"], [tr("WORK"), KEY_SPACE, "right"]]
	return []
