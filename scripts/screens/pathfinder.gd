extends "res://scripts/screens/screen.gd"
## Mission 3, Mars Pathfinder (July 4, 1997): "Land by bouncing" (issue #47).
## (1) The descent, in real time from the radar's first echo at 1.6 km: the lander swings on its 20 m bridle under
## the parachute; the player steadies it (mouse or A/D), fires the three rockets (Space, best at 98 m) and cuts the
## bridle (C, best at 21.5 m); near each mark time slows (said on screen). Too fast at the ground, or still on the
## bridle: the airbags burst, a lose screen, tried again. (2) The bounces, shown 4 times faster: about 12 m up first,
## then at least 15 more; the player steers the ball away from the big rocks; Inti counts every bounce. (3) The
## airbags pull in, the petals open, and Sojourner rolls down the rear ramp, tilted 20 degrees, kept between its rails
## by the player (off the edge: lost). Climax: the first wheel on Mars, its tracks, then NASA's own pictures.
## Rules of the descent: scripts/missions/pathfinder/landing.gd; data: data/missions/pathfinder.json.

const TouchKeys := preload("res://scripts/ui/touch_keys.gd")
const Progress := preload("res://scripts/story/campaign_progress.gd")
const Landing := preload("res://scripts/missions/pathfinder/landing.gd")
const Sets := preload("res://scripts/story/sets.gd")
const CuyActor := preload("res://scripts/story/cuy_actor.gd")
const Sound := preload("res://scripts/flight/sound.gd")
const BALL_R := 2.6
const TIME_FAST := 4.0

var L: Landing
var T: Dictionary
var campaign := false
var then_scenes: Array = []
var back := "menu"
var S := {}
var saved := {}
var actors := {}
var phase := "brief"           ## brief, descent, bounce, deflate, ramp, wheel, done, lost
var phase_t := 0.0
var _t := 0.0
var cam_pos := Vector3.ZERO
var cam_look := Vector3.ZERO
# interface
var big: Label
var big_sub: Label
var note: Label
var alt_lbl: Label
var speed_lbl: Label
var ladder: Control
var houston: Label
var hint: Label
var bubble: Label
var flash: ColorRect
var lose_layer: Control
var photo_shown := false
var brief: Control
var steps_box: VBoxContainer
var step_rows: Array = []
var shout_panel: PanelContainer   ## The card behind the big moment ("Impact: 19 m/s"), above the action.
var hint_panel: PanelContainer    ## The dark card behind the line of what to do, so it reads on bright ground.
var now_lbl: Label             ## The big call to act ("SPACE: ROCKETS NOW!").
var vside := 0.0               ## The ball's sideways speed (steering and rock hits).
# descent
var shell_off := Vector3.ZERO
var shell_v := Vector3.ZERO
var _said := {}
var steer := 0.0
# bounces
var heights: Array = []
var ball := Vector3.ZERO
var vy := 0.0
var vx := 0.0
var bounce := 0
var rocks_hit := 0
var hit_cool := 0.0
var rest_t := -1.0
# ramp
var ramp_s := 0.0
var ramp_off := 0.0
var ramp_drift := 0.0
var tracks: Array = []
var thump: AudioStreamPlayer
var roar: AudioStreamPlayer


func enter(args: Dictionary) -> void:
	campaign = args.get("campaign", false)
	then_scenes = args.get("then", [])
	back = args.get("back", "menu")
	L = Landing.new()
	T = L.D.texts
	saved = Sets.save_world(world)
	world.cam_free = false
	world.cam.fov = 50.0
	S = Sets.build("mars", world)
	thump = Sound.player(self, "thud", -4.0)
	roar = Sound.player(self, "rumble", -6.0)
	for id in ["inti", "killa", "rumi"]:
		var a = CuyActor.new()
		a.id = id
		a.visible = false
		world.stage.add_child(a)
		actors[id] = a
	_build_ui()
	_place_craft()
	var g := _cam_goal()
	cam_pos = g[0]
	cam_look = g[1]
	houston.text = tr("Radar has the ground: 1.6 km. Steady the lander, then the rockets, then the cut.")
	_show_brief()
	_phone_layout()
	TouchKeys.attach(self)


func exit() -> void:
	Engine.time_scale = 1.0
	Sets.restore_world(world, saved)


# ===================================================================================== THE INTERFACE
func _build_ui() -> void:
	var head := Kit.vbox(2)
	Kit.place(head, 0, 0, 0, 0, Kit.MARGIN, Kit.MARGIN, 520, 100)
	add_child(head)
	var over := Kit.caps(tr("Mission 3 · Mars Pathfinder · July 4, 1997"))
	over.add_theme_color_override("font_color", Color(Kit.C_ON_DARK, 0.8))
	head.add_child(over)
	head.add_child(Kit.lbl(tr("Land by bouncing"), Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T))
	# height and speed, big, top middle
	var cp := Kit.panel_box(Kit.PAD)
	Kit.place(cp, 0.5, 0, 0.5, 0, -170, Kit.MARGIN, 170, Kit.MARGIN + 130)
	add_child(cp)
	var cv := Kit.vbox(0)
	cp.add_child(cv)
	var cap := Kit.caps(tr("Height above Mars"))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(cap)
	alt_lbl = Kit.lbl("", Kit.T_CLOCK + 16, Kit.C_GOLD, Kit.font_num())
	alt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(alt_lbl)
	speed_lbl = Kit.lbl("", Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B)
	speed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(speed_lbl)
	note = Kit.lbl(tr(T.time_note), Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(note)
	# Wayra on the radio
	var hp := Kit.panel_box(Kit.PAD)
	Kit.place(hp, 1, 0, 1, 0, -Kit.MARGIN - 430, Kit.MARGIN, -Kit.MARGIN, Kit.MARGIN + 60)
	add_child(hp)
	var hv := Kit.vbox(Kit.GAP)
	hp.add_child(hv)
	var hh := Kit.hbox(Kit.GAP)
	hv.add_child(hh)
	hh.add_child(Kit.chip("Wayra", Kit.C_ACCENT))
	hh.add_child(Kit.lbl(tr("Mission control, on the radio"), Kit.T_SMALL, Kit.C_DIM))
	houston = Kit.lbl("", Kit.T_ACTION - 2, Kit.C_TEXT, Kit.FONT_B, true)
	houston.custom_minimum_size.x = 380
	hv.add_child(houston)
	# the ladder: the height against the two marks
	ladder = Ladder.new()
	ladder.L = L
	Kit.place(ladder, 0, 0.5, 0, 0.5, Kit.MARGIN, -220, Kit.MARGIN + 170, 260)
	add_child(ladder)
	# the three steps of the descent, ticked as they are done
	var steps_panel := Kit.panel_box(10)
	steps_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Kit.place(steps_panel, 0, 0.5, 0, 0.5, Kit.MARGIN, 272, Kit.MARGIN + 10, 282)
	add_child(steps_panel)
	steps_box = Kit.vbox(4)
	steps_panel.add_child(steps_box)
	for t in [tr("1  Keep it steady (A/D)"), tr("2  Rockets at 98 m (SPACE)"), tr("3  Cut at 21.5 m (C)")]:
		var l := Kit.lbl(t, Kit.T_ACTION - 4, Kit.C_DIM, Kit.FONT_B)
		steps_box.add_child(l)
		step_rows.append(l)
	now_lbl = Kit.lbl("", Kit.T_SHOUT, Kit.C_GOLD, Kit.FONT_T)
	now_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Kit.place(now_lbl, 0, 0.5, 1, 0.5, 0, 60, 0, 140)
	now_lbl.add_theme_constant_override("outline_size", 6)
	now_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_child(now_lbl)
	# what to do now, at the bottom
	hint = Kit.lbl("", Kit.T_ACTION, Kit.C_ON_DARK, Kit.FONT_B, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_panel = Kit.panel_box(12)
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Kit.place(hint_panel, 0.5, 1, 0.5, 1, -330, -130, 330, -Kit.MARGIN)
	hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_panel.add_child(hint)
	add_child(hint_panel)
	shout_panel = Kit.panel_box(12)
	shout_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Kit.place(shout_panel, 0.5, 0, 0.5, 0, -10, Kit.MARGIN + 176, 10, Kit.MARGIN + 186)
	shout_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(shout_panel)
	var shout_box := Kit.vbox(2)
	shout_panel.add_child(shout_box)
	big = Kit.lbl("", Kit.T_SHOUT, Kit.C_GOLD, Kit.FONT_T)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shout_box.add_child(big)
	big_sub = Kit.lbl("", Kit.T_ACTION, Kit.C_TEXT, Kit.FONT_B)
	big_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shout_box.add_child(big_sub)
	# Inti's count, in a speech bubble
	bubble = Kit.lbl("", Kit.T_CLOCK, Kit.C_TEXT, Kit.FONT_T)
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Kit.place(bubble, 0.5, 0.5, 0.5, 0.5, -300, -105, 300, -45)
	bubble.add_theme_constant_override("outline_size", 5)
	bubble.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	add_child(bubble)
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 1, 1, 0)
	add_child(flash)


## How to land, in three steps, before anything moves.
func _show_brief() -> void:
	brief = Control.new()
	brief.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(brief)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brief.add_child(shade)
	var p := Kit.panel_box(Kit.PAD)
	Kit.place(p, 0.5, 0.5, 0.5, 0.5, -420, -230, 420, 230)
	brief.add_child(p)
	var v := Kit.vbox(Kit.GAP)
	p.add_child(v)
	v.add_child(Kit.caps(tr("How to land")))
	v.add_child(Kit.lbl(tr("Land by bouncing"), Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T))
	for row in [["1", tr("Keep the lander steady on its rope"), tr("A / D or the mouse, against the swing")],
			["2", tr("Fire the rockets at 98 m"), tr("SPACE, when the height reaches the gold line")],
			["3", tr("Cut the rope at 21.5 m"), tr("C, when the height reaches the blue line")]]:
		var h := Kit.hbox(Kit.PAD)
		v.add_child(h)
		h.add_child(Kit.lbl(row[0], Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T))
		var t := Kit.vbox(0)
		h.add_child(t)
		t.add_child(Kit.lbl(row[1], Kit.T_ACTION - 2, Kit.C_TEXT, Kit.FONT_B))
		t.add_child(Kit.lbl(row[2], Kit.T_BODY, Kit.C_DIM))
	v.add_child(Kit.lbl(tr("Too fast at the ground and the airbags burst. Then: steer the bounces, and drive Sojourner down its ramp."), Kit.T_SMALL + 1, Kit.C_DIM, Kit.FONT_R, true))
	var go_btn := Kit.btn(tr("Start the descent  ·  Enter"), _start_descent, Kit.T_BODY)
	Kit.accent_btn(go_btn, Kit.C_GOLD)
	v.add_child(go_btn)
	go_btn.grab_focus()


func _start_descent() -> void:
	if phase != "brief":
		return
	if brief and is_instance_valid(brief):
		brief.queue_free()
	phase = "descent"
	phase_t = 0.0


func _shout(a: String, b := "", col := Kit.C_GOLD) -> void:
	big.text = a
	big_sub.text = b
	big.add_theme_color_override("font_color", col)
	big.pivot_offset = Vector2(big.size.x * 0.5, 30)
	big.scale = Vector2(0.6, 0.6)
	big.create_tween().tween_property(big, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)


# ===================================================================================== THE DESCENT
## The craft: the lander swings below the backshell on the bridle; after the cut the backshell flies off.
func _place_craft() -> void:
	var craft: Node3D = S.craft
	var lander: Node3D = S.lander
	var shell: Node3D = S.shell
	var bridle: MeshInstance3D = S.bridle
	var lx := sin(L.swing) * 20.0
	var ly := 20.0 - cos(L.swing) * 20.0
	craft.position = Vector3(0, L.alt + BALL_R, 0)
	lander.position = Vector3(lx, ly, 0)
	lander.rotation.z = L.swing
	if not L.released:
		shell.position = Vector3(0, 20.0, 0)
		var a := lander.position + Vector3(0, 0.6, 0)
		var b := shell.position
		bridle.visible = true
		bridle.position = (a + b) * 0.5
		bridle.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized())) * Basis.from_scale(Vector3(1, (b - a).length(), 1))
	else:
		bridle.visible = false
		shell.position = Vector3(0, 20.0, 0) + shell_off


func _descent(delta: float) -> void:
	# the player's push against the swing
	steer = 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		steer = -1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		steer = 1.0
	steer = clampf(steer + _mouse_push * 0.02, -1.0, 1.0)
	_mouse_push = lerpf(_mouse_push, 0.0, delta * 6.0)
	var was_bags := L.airbags
	L.update(delta, steer)
	if L.airbags and not was_bags:
		var bag: Node3D = S.airbags
		bag.visible = true
		bag.scale = Vector3.ONE * 0.05
		bag.create_tween().tween_property(bag, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
		Kit.UiSound.play("whoosh", 0.0)
		houston.text = tr("Airbags inflated! A 5.2 meter ball around the lander.")
	if L.released:
		shell_v += Vector3(1.5, 6.0, 0) * delta
		shell_off += shell_v * delta
	# the rockets burn
	var burning := L.fired and L.burn < float(L.D.descent.rocket_time) and not L.released
	for f in (S.rockets as Node3D).get_children():
		f.emitting = burning or (L.fired and L.burn < float(L.D.descent.rocket_time) and L.released and false)
	if burning and not roar.playing:
		roar.play()
	elif not burning and roar.playing:
		roar.stop()
	_place_craft()
	# slow motion near the two marks, said on screen
	var De: Dictionary = L.D.descent
	var band := float(De.slow_band)
	var near := (not L.fired and L.alt > float(De.rocket_alt) - 4.0 and L.alt < float(De.rocket_alt) + band) or (L.fired and not L.released and L.alt > float(De.cut_alt) - 4.0 and L.alt < float(De.cut_alt) + band)
	Engine.time_scale = float(De.slow_scale) if near else 1.0
	note.text = tr(T.slow) if near else tr("Real time")
	alt_lbl.text = "%d m" % int(round(L.alt))
	speed_lbl.text = tr("falling at %d m/s") % int(round(L.vz))
	hint.text = tr(T.steady)
	# the checklist and, near each mark, the big call to act
	var cols := [Kit.C_GOLD if not L.fired else Kit.C_OK, Kit.C_GOLD if not L.fired else Kit.C_OK, Kit.C_DIM if not L.fired else (Kit.C_GOLD if not L.released else Kit.C_OK)]
	for i in 3:
		(step_rows[i] as Label).add_theme_color_override("font_color", cols[i])
	(step_rows[0] as Label).add_theme_color_override("font_color", Kit.C_BAD if absf(L.swing) > 0.17 else Kit.C_OK)
	var call := ""
	if not L.fired and L.alt < float(De.rocket_alt) + 40.0:
		call = tr("SPACE: ROCKETS NOW!") if L.alt <= float(De.rocket_alt) + 8.0 else tr("Get ready: rockets at 98 m")
	elif L.fired and not L.released and L.alt < float(De.cut_alt) + 25.0:
		call = tr("C: CUT THE ROPE NOW!") if L.alt <= float(De.cut_alt) + 4.0 else tr("Get ready: cut at 21.5 m")
	now_lbl.text = call
	now_lbl.modulate.a = 0.6 + 0.4 * sin(_t * 12.0) if call.ends_with("!") else 1.0
	if L.alt < 400.0 and not _said.has("400") and not L.fired:
		_said["400"] = true
		houston.text = tr("Rockets at 98 meters. Watch the ladder.")
	if L.fired and not _said.has("cut") and not L.released:
		_said["cut"] = true
		houston.text = tr("Rockets burning! Cut the bridle at 21 meters!")
	if L.landed:
		Engine.time_scale = 1.0
		roar.stop()
		thump.play()
		if L.burst:
			_lose(tr(T.tangled if L.tangled else T.burst), tr(T.tangled_sub if L.tangled else T.burst_sub))
		else:
			_start_bounces()


var _mouse_push := 0.0


# ===================================================================================== THE BOUNCES
func _start_bounces() -> void:
	phase = "bounce"
	phase_t = 0.0
	heights = L.bounce_heights()
	bounce = 0
	var lander: Node3D = S.lander
	ball = lander.global_position
	ball.y = BALL_R
	vy = sqrt(2.0 * float(L.D.descent.g) * heights[0])
	vx = L.roll_speed() * 0.5
	(S.bridle as Node3D).visible = false
	flash.color.a = 0.5
	shake = 0.8
	_shout(tr("Impact: %d m/s") % int(round(L.impact)), tr("The real one: 18 m/s. Now it bounces."))
	note.text = tr("Shown 4 times faster")
	hint.text = tr(T.steer)
	houston.text = tr("Touchdown! It bounces like a giant beach ball. Inti, count!")
	bubble.text = ""


var shake := 0.0


func _bounces(delta: float) -> void:
	var dt := delta * TIME_FAST
	var g := float(L.D.descent.g)
	# steering, and the ball's run
	var side := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		side = -1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		side = 1.0
	side = clampf(side + _mouse_push * 0.02, -1.0, 1.0)
	_mouse_push = lerpf(_mouse_push, 0.0, delta * 6.0)
	vside = lerpf(vside, side * 4.0, clampf(dt * 1.5, 0.0, 1.0))
	ball.z += vside * dt
	ball.x += vx * dt
	vy -= g * dt
	ball.y += vy * dt
	hit_cool -= delta
	# the big rocks are solid: the ball touches one, is pushed out of it and bounces off, losing speed
	for r in S.rocks:
		var c := Vector3(r.pos.x, float(r.r) * 0.3, r.pos.z)
		var rr: float = BALL_R + float(r.r) * 0.85
		var d3 := ball - c
		if d3.length() < rr:
			var nrm := d3.normalized() if d3.length() > 0.01 else Vector3.UP
			ball = c + nrm * rr
			var v := Vector3(vx, vy, vside)
			if v.dot(nrm) < 0.0:
				v -= 1.6 * v.dot(nrm) * nrm
			vx = maxf(v.x * 0.8, 0.8)
			vy = maxf(v.y, 0.0) * 0.8
			vside = v.z
			if hit_cool <= 0.0:
				rocks_hit += 1
				hit_cool = 0.8
				thump.play()
				bubble.text = tr("Ow! A rock!")
				shake = 0.6
	if ball.y <= BALL_R and vy < 0.0 and rest_t >= 0.0:
		ball.y = BALL_R
		vy = 0.0
	elif ball.y <= BALL_R and vy < 0.0:
		ball.y = BALL_R
		bounce += 1
		thump.play()
		shake = clampf(heights[mini(bounce - 1, heights.size() - 1)] / 12.0, 0.15, 0.8)
		if bounce < heights.size():
			vy = sqrt(2.0 * g * heights[bounce])
			vx = lerpf(vx, L.roll_speed() * 0.5 * (1.0 - bounce / float(heights.size())), 0.5) + 0.5
			bubble.text = tr(T.bounce) % bounce
			bubble.pivot_offset = bubble.size * 0.5
			bubble.scale = Vector2(1.4, 1.4)
			bubble.create_tween().tween_property(bubble, "scale", Vector2.ONE, 0.3)
		else:
			vy = 0.0
			if rest_t < 0.0:
				rest_t = 0.0
	if rest_t >= 0.0:
		rest_t += delta
		vx = maxf(0.0, vx - 3.0 * dt)
		ball.y = BALL_R
		if vx <= 0.0 and rest_t > 1.0:
			_rest()
	var lander: Node3D = S.lander
	var craft: Node3D = S.craft
	craft.position = Vector3.ZERO
	lander.position = ball
	lander.rotation.z -= vx * dt / BALL_R
	alt_lbl.text = "%d" % bounce
	speed_lbl.text = tr("bounces · %d m from the first") % int(ball.x)


func _rest() -> void:
	phase = "deflate"
	phase_t = 0.0
	bubble.text = ""
	_shout(tr(T.rest), tr("Inti counted %d bounces.") % bounce)
	houston.text = tr(T.deflate)
	hint.text = ""
	var base: Node3D = S.base
	base.global_position = Vector3(ball.x, 0.0, ball.z)
	base.visible = true
	for p in S.petals:
		(p as Node3D).rotation.x = -1.2
	(S.craft as Node3D).visible = false
	# the crew climb out, dizzy
	var marks: Dictionary = S.marks
	for k in actors:
		var a = actors[k]
		a.visible = true
		a.scale = Vector3.ONE * float(S.get("actor_scale", 1.0))
		a.global_position = base.global_position + marks[k].pos
		a.rotation.y = marks[k].yaw
		a.set_mood("tired" if k == "inti" else "happy")
		a.act = "idle"


func _deflate(delta: float) -> void:
	var k := clampf(phase_t / 2.5, 0.0, 1.0)
	for p in S.petals:
		(p as Node3D).rotation.x = lerpf(-1.2, 0.0, smoothstep(0.0, 1.0, k))
	if phase_t > 3.5:
		phase = "ramp"
		phase_t = 0.0
		ramp_s = 0.0
		ramp_off = 0.0
		hint.text = tr(T.drive)
		houston.text = tr("Sol 2. Rear ramp down. Sojourner, roll!")
		big.text = ""
		big_sub.text = ""
		alt_lbl.text = "20°"
		speed_lbl.text = tr("the rear ramp's tilt")
		note.text = ""


# ===================================================================================== THE RAMP
func _ramp(delta: float) -> void:
	var go_on := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	ramp_drift += (randf_range(-1, 1) * 0.6 - ramp_drift * 0.5) * delta
	var side := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		side = -1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		side = 1.0
	if go_on:
		ramp_s = minf(1.0, ramp_s + delta * float(L.D.ramp.speed) * 0.35)
		ramp_off += (ramp_drift * 0.12 + side * 0.12 + _mouse_push * 0.0015) * delta
	_mouse_push = lerpf(_mouse_push, 0.0, delta * 6.0)
	var rover: Node3D = S.rover
	var ramp: Node3D = S.ramp
	# along the ramp, tilted 20 degrees down to the ground
	# the rover's wheels ride on the rails' top: down the ramp, then on the ground (never below it)
	var start := ramp.position + Vector3(0, 0.03, 0)
	var dir := Vector3(0, -sin(deg_to_rad(20.0)), cos(deg_to_rad(20.0)))
	rover.position = start + dir * (Sets.RAMP_LEN * ramp_s) + Vector3(ramp_off, 0.0, 0)
	rover.position.y = maxf(rover.position.y, 0.0)
	rover.rotation.x = deg_to_rad(20.0) * (1.0 - smoothstep(0.9, 1.0, ramp_s))
	(ladder as Ladder).ramp = ramp_off
	if absf(ramp_off) > 0.17:
		Engine.time_scale = 1.0
		rover.rotation.z = signf(ramp_off) * -0.8
		_lose(tr(T.off), tr(T.off_sub))
		return
	if ramp_s >= 1.0:
		_wheel()


func _wheel() -> void:
	phase = "wheel"
	phase_t = 0.0
	Engine.time_scale = 0.4
	get_tree().create_timer(0.9, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
	flash.color.a = 0.6
	Kit.UiSound.play("fanfare", 0.0)
	_shout(tr(T.wheel), tr(T.wheel_sub))
	hint.text = ""
	houston.text = tr("JPL here: we have a rover on Mars!")
	# the first tracks, behind the rover
	var rover: Node3D = S.rover
	var base: Node3D = S.base
	for i in 6:
		for sx in [-0.28, 0.28]:
			var tr_m := Sets.box(base, Vector3(0.07, 0.005, 0.12), rover.position + Vector3(sx, -rover.position.y + 0.004, 0.15 + i * 0.16), Sets.mat(Color(0.32, 0.2, 0.13), 1.0))
			tracks.append(tr_m)
	for k in actors:
		actors[k].act = "cheer"
		actors[k].set_mood("happy")


# ===================================================================================== THE END
func _lose(a: String, b: String) -> void:
	phase = "lost"
	phase_t = 0.0
	Engine.time_scale = 1.0
	Kit.UiSound.play("error", 0.0)
	hint.text = ""
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
	var l1 := Kit.lbl(a, Kit.T_SHOUT, Kit.C_BAD, Kit.FONT_T)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l1)
	var l2 := Kit.lbl(b, Kit.T_ACTION, Kit.C_ON_DARK, Kit.FONT_B, true)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l2.custom_minimum_size.x = 900
	v.add_child(l2)
	var row := Kit.hbox(Kit.GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var again := Kit.btn(tr("Try again  ·  Enter"), _again, Kit.T_BODY)
	Kit.accent_btn(again, Kit.C_GOLD)
	row.add_child(again)
	v.create_tween().tween_property(v, "modulate:a", 1.0, 0.6).set_delay(0.5)
	again.grab_focus()


func _again() -> void:
	go("pathfinder", {"campaign": campaign, "then": then_scenes, "back": back})


func _continue() -> void:
	if not then_scenes.is_empty():
		go("story", {"scenes": then_scenes, "back": back})
	else:
		go(back)


## The real thing: NASA's pictures of Sojourner on its petal and of its first tracks.
func _show_photo() -> void:
	photo_shown = true
	big.text = ""
	big_sub.text = ""
	var shade := ColorRect.new()
	shade.color = Kit.C_SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var p := Kit.panel_box(Kit.PAD)
	Kit.place(p, 0.5, 0.5, 0.5, 0.5, -620, -330, 620, 330)
	add_child(p)
	var v := Kit.vbox(Kit.GAP)
	p.add_child(v)
	var top := Kit.hbox(Kit.PAD)
	v.add_child(top)
	var pics := Kit.vbox(Kit.GAP)
	top.add_child(pics)
	for i in L.D.photos.size():
		var P: Dictionary = L.D.photos[i]
		var img := TextureRect.new()
		img.texture = load(P.file)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.custom_minimum_size = Vector2(640, 268 if i == 0 else 200)
		pics.add_child(img)
		pics.add_child(Kit.lbl(tr(P.caption) + "  ·  " + P.credit, Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))
	var side := Kit.vbox(Kit.GAP)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(side)
	side.add_child(Kit.caps(tr("Mission 3 · done")))
	var stars := L.stars(rocks_hit)
	Progress.earn("pathfinder", stars)
	side.add_child(Kit.lbl("★".repeat(stars) + "☆".repeat(3 - stars), Kit.T_CLOCK, Kit.C_GOLD, Kit.FONT_T))
	side.add_child(Kit.lbl(tr("Impact: %d m/s (the real one: 18) · Bounces: %d · Rocks hit: %d") % [int(round(L.impact)), bounce, rocks_hit], Kit.T_SMALL + 1, Kit.C_DIM, Kit.FONT_R, true))
	side.add_child(Kit.rule())
	for F in L.D.facts:
		var fh := Kit.hbox(Kit.GAP)
		fh.add_child(Kit.chip("NASA", Kit.C_GOLD))
		var fl := Kit.lbl(tr(F.text), Kit.T_SMALL + 1, Kit.C_DIM, Kit.FONT_R, true)
		fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fh.add_child(fl)
		side.add_child(fh)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(sp)
	var row := Kit.hbox(Kit.GAP)
	side.add_child(row)
	var go_on := Kit.btn(tr("Continue  ·  Enter"), _continue, Kit.T_BODY)
	Kit.accent_btn(go_on, Kit.C_GOLD)
	row.add_child(go_on)
	row.add_child(Kit.btn(tr("Play again  ·  R"), _again, Kit.T_BODY))
	go_on.grab_focus()


# ===================================================================================== EVERY FRAME
func _cam_goal() -> Array:
	match phase:
		"brief", "descent", "lost":
			var lander: Node3D = S.lander
			var at := lander.global_position
			if L.landed:
				at = lander.global_position
			var up := clampf(L.alt * 0.05, 4.0, 14.0)
			return [at + Vector3(16, up * 0.4 + 2.0, 30), at + Vector3(0, up * 0.6, 0)]
		"bounce":
			return [ball + Vector3(-14, 6, 20), ball + Vector3(6, 0, 0)]
		"deflate":
			var base: Node3D = S.base
			return [base.global_position + Vector3(4.5, 3.0, 7.5), base.global_position + Vector3(0, 0.4, 0.5)]
		_:
			var base2: Node3D = S.base
			var rover: Node3D = S.rover
			var r := rover.global_position
			# a little to the left, so Rumi, the engineer, watches his rover roll off beside it
			return [base2.global_position + Vector3(0.9, 1.3, 4.9), r + Vector3(-0.7, 0.4, -0.2)]


func process(delta: float) -> void:
	_t += delta
	phase_t += delta
	flash.color.a = maxf(0.0, flash.color.a - delta * 1.5)
	match phase:
		"descent":
			_descent(delta)
		"bounce":
			_bounces(delta)
		"deflate":
			_deflate(delta)
		"ramp":
			_ramp(delta)
		"wheel":
			if phase_t > 3.0 and not photo_shown:
				phase = "done"
				_show_photo()
	ladder.visible = phase == "descent" or phase == "ramp" or phase == "brief"
	steps_box.get_parent().visible = (phase == "descent" or phase == "brief") and not Kit.compact
	hint_panel.visible = hint.text != ""
	shout_panel.visible = big.text != ""
	big_sub.visible = big_sub.text != ""
	if phase != "descent":
		now_lbl.text = ""
	(ladder as Ladder).mode = phase
	var g := _cam_goal()
	var k := 1.0 - exp(-delta * (6.0 if phase == "descent" or phase == "bounce" else 2.0))
	cam_pos = cam_pos.lerp(g[0], k)
	cam_look = cam_look.lerp(g[1], k)
	shake = maxf(0.0, shake - delta)
	var jit := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.4
	world.cam.position = cam_pos + jit
	world.cam.look_at(cam_look, Vector3.UP)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_mouse_push += e.relative.x
		if phase == "ramp":
			ramp_off += e.relative.x * 0.0006
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
			_again()
		else:
			return
	elif phase == "brief" and (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE):
		_start_descent()
	elif phase == "descent" and k == KEY_SPACE:
		if L.fire():
			Kit.UiSound.play("snap")
			shake = 0.5
			houston.text = tr("Rockets fired at %d m!") % int(round(L.alt))
	elif phase == "descent" and k == KEY_C:
		if L.cut():
			Kit.UiSound.play("snap")
			houston.text = tr("Bridle cut at %d m! Falling free...") % int(round(L.alt))
	elif k == KEY_ESCAPE:
		go(back)
	else:
		return
	get_viewport().set_input_as_handled()


# ===================================================================================== DRAWINGS
## The ladder: the height against the rockets' mark (98 m) and the cut's (21.5 m), and the swing; on the ramp, how
## close to the rails Sojourner is.
class Ladder extends Control:
	var L
	var mode := "descent"
	var ramp := 0.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, 0.75))
		if mode == "ramp":
			var c := size.x * 0.5
			draw_string(Kit.FONT_B, Vector2(10, 22), TranslationServer.translate("Between the rails"), HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, Kit.T_SMALL, Kit.C_DIM)
			draw_rect(Rect2(c - 60, 60, 6, size.y - 90), Color(0.75, 0.75, 0.8))
			draw_rect(Rect2(c + 54, 60, 6, size.y - 90), Color(0.75, 0.75, 0.8))
			var x := c + ramp / 0.17 * 54.0
			draw_rect(Rect2(x - 22, size.y * 0.5 - 14, 44, 28), Kit.C_BAD if absf(ramp) > 0.12 else Kit.C_OK)
			return
		var top := 1600.0
		var y0 := 40.0
		var h := size.y - 80.0
		# a log-like scale so the low marks have room
		var ypos := func(m: float) -> float: return y0 + h * (1.0 - sqrt(clampf(m, 0.0, top) / top))
		draw_line(Vector2(60, y0), Vector2(60, y0 + h), Color(0.6, 0.65, 0.75), 2.0)
		for mark in [[float(L.D.descent.rocket_alt), TranslationServer.translate("Rockets"), Kit.C_GOLD], [float(L.D.descent.cut_alt), TranslationServer.translate("Cut"), Kit.C_ACCENT]]:
			var y: float = ypos.call(mark[0])
			draw_line(Vector2(40, y), Vector2(size.x - 10, y), mark[2], 2.0)
			draw_string(Kit.FONT_B, Vector2(70, y - 4), "%s  %s m" % [mark[1], str(mark[0])], HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, mark[2])
		var yy: float = ypos.call(L.alt)
		draw_colored_polygon(PackedVector2Array([Vector2(48, yy), Vector2(30, yy - 9), Vector2(30, yy + 9)]), Kit.C_TEXT)
		draw_string(Kit.FONT_B, Vector2(10, 22), TranslationServer.translate("Height"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_DIM)
		# the swing
		var sc := Vector2(size.x - 50, size.y - 22)
		draw_string(Kit.FONT_B, Vector2(size.x - 100, size.y - 54), TranslationServer.translate("Swing"), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.T_SMALL, Kit.C_DIM)
		var a: float = L.swing
		draw_line(sc - Vector2(0, 26), sc - Vector2(0, 26) + Vector2(sin(a), cos(a)) * 26.0, Kit.C_BAD if absf(a) > 0.17 else Kit.C_OK, 4.0)


## The buttons a phone needs now (scripts/ui/touch_keys.gd): only what this moment of the landing asks for.
func touch_keys() -> Array:
	match phase:
		"descent":
			var k := [["◀", KEY_A, "left"], ["▶", KEY_D, "left"]]
			if not L.fired:
				k.append([tr("ROCKETS"), KEY_SPACE, "right"])
			elif not L.released:
				k.append([tr("CUT"), KEY_C, "right"])
			return k
		"bounce":
			return [["◀", KEY_A, "left"], ["▶", KEY_D, "left"]]
		"ramp":
			return [["◀", KEY_A, "left"], ["▶", KEY_D, "left"], [tr("ROLL ▲"), KEY_W, "right"]]
	return []


## A phone in landscape (Kit.compact): the height ladder shorter and clear of the title and the buttons, the steps
## list gone (the call to act says the step), the line of what to do in the middle above the touch buttons.
func _phone_layout() -> void:
	if not Kit.compact:
		return
	Kit.place(ladder, 0, 0.5, 0, 0.5, Kit.MARGIN, -150, Kit.MARGIN + 150, 120)
	steps_box.get_parent().visible = false
	var radio_card: Control = houston.get_parent().get_parent()
	Kit.place(radio_card, 1, 0, 1, 0, -Kit.MARGIN - 330, Kit.MARGIN, -Kit.MARGIN, Kit.MARGIN + 50)
	houston.custom_minimum_size.x = 300
	houston.add_theme_font_size_override("font_size", Kit.T_BODY)
	Kit.place(hint_panel, 0.5, 1, 0.5, 1, -250, -150, 250, -96)
	hint.add_theme_font_size_override("font_size", Kit.T_BODY)
	Kit.place(now_lbl, 0, 1, 1, 1, 0, -215, 0, -160)
