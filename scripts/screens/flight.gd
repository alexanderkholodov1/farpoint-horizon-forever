extends "res://scripts/screens/screen.gd"
## From Earth orbit to an orbit around the Moon (issue #8). The physics is scripts/flight/transfer.gd: the Earth's and
## the Moon's pull, the Moon where JPL Horizons puts it [S-horizons].
## What the player does, as a real crew and its mission control do:
##   1. Plan: mission control finds where on the parking orbit to fire the burn so the craft meets the Moon three or
##      four days later, where the Moon will be then (phasing). The plan is drawn on the map with where the Moon will
##      be. The plan panel moves the burn earlier or later, or makes it bigger (a faster trip), to see how it changes.
##   2. Time runs by itself, as fast as it can, to each moment that needs the crew, and slows for it: a ten-second
##      countdown, then BURN (Space). CUT (Space) when the speed is added. A mid-course correction (Space), BRAKE at
##      the Moon (Space). Then the landing (screen "landing").
## Two ways to see it (M switches): next to the craft, with the Earth and the Moon at their true sizes in the sky, and
## the map at true scale with the paths. The arrows (or the panel's arrow buttons) turn the camera, the wheel zooms.
## Generous: if the pilot does not act, the flight computer does after a few seconds; a cut too early is refused
## while the path does not reach the Moon; Skip lets the computer fly the current step. Never a failure screen.

const Space := preload("res://scripts/world/space_builder.gd")
const Ship := preload("res://scripts/world/ship_builder.gd")
const FlightHud := preload("res://scripts/flight/flight_hud.gd")
const FlightData := preload("res://scripts/flight/flight_data.gd")
const Sound := preload("res://scripts/flight/sound.gd")
const Transfer := preload("res://scripts/flight/transfer.gd")

const EARTH_U := 10.0               ## The Earth's radius in the map's units.
const FAR := 20000.0                ## Metres: bodies farther than this from the craft are drawn nearer and smaller in the
                                    ## same proportion, so their size in the sky stays true (the craft's view is in metres).
const COAST_S := 5.0                ## Real seconds the days-long coast to the Moon takes (after the correction).
const SEGMENT_S := 2.5              ## Real seconds time takes to run to the next moment, whatever the wait.
const ORBIT_UTC := 13.0 * 3600.0    ## The craft reaches orbit at 13:00 UTC on 15 November 2026 (a game choice).
const DV_DEFAULT := 3150.0          ## m/s: a trip of about three and a half days, close to Apollo 11's 76 h [S-apollo11].
const DV_MIN := 3100.0
const DV_MAX := 3300.0
const CORRECT_AFTER := 6.0 * 3600.0 ## The mid-course correction, six hours after the burn.
const COUNTDOWN := 3.0              ## Seconds of countdown before a burn, in real time: the player watches, the flight
                                    ## computer fires at zero (issue #79; the player decides the plan and gives the GO).
const GRACE := 3.0                  ## Seconds past the planned burn after which mission control plans the next departure.
const CUT_GUARD_MS := 1500          ## A cut is refused this soon after lighting the engine (one press, not two).
const BURN_WARP := 50.0             ## Time while an engine burns: a six-minute burn in about seven seconds.
const SUN_LON_DEG := 233.0          ## The Sun's ecliptic longitude on 15 November 2026 (about; our simplification).
const UNIX_DAY0 := 1794700800       ## 15 November 2026 00:00 UTC, the first row of the Moon's ephemeris.
const BRAKE_DV_MAX := 2500.0         ## m/s: a brake that has burned this much and still is not held has failed (a real one is about 900).
const STEPS_TEXT := ["Plan", "Burn", "Coast", "Brake", "Moon orbit"]   ## The trip's steps, shown across the top.
const STEP_OF := {"plan": 0, "burn": 1, "coast": 2, "missed": 2, "capture": 3, "lunar": 4}
const EARTH_SPIN_MAX := 0.15        ## Turns a second of the drawn Earth above which it is held still (a blur, not a motion).
const LUNAR_ORBIT_HIGH := 160000.0  ## The capture burn ends when the orbit's high point is below this height (m).
const STARS := 7000                ## Our own stars, scattered by a formula (not a catalogue): 45 % crowd into a Milky Way band.

var m                                ## scripts/flight/transfer.gd
var hud
var r_park := 6.55e6
var t_launch := 0.0
var u := 6.371e5                     ## metres per map unit
var dv_plan := DV_DEFAULT
var shift_deg := 0.0
var job := {}
var plan := {}
var shown := {}
var burn_start := 0.0
var burn_t0 := 0.0
var burn_ms := 0
var phase := "plan"                  ## plan, burn, coast, capture, lunar, missed
var phase_t := 0.0
var throttle := 1.0
var pred := {}
var pred_age := 99.0
var correction := {}
var correction_state := ""           ## "", offered, done
var offered_ms := 0
var capture_at := 0.0
var braking := false
var leaving := false
var auto_fly := false                  ## This try is flown by the flight computer (after Skip on a missed Moon).
var missed_ms := 0
var steps_row: HBoxContainer
var cam_idle := 0.0
var earth_spin := 0.0                ## The angle the Earth is drawn at (radians).
var earth_held := false
var los := false                    ## The braking burn happens behind the Moon, out of contact with the Earth.
var brake_dv := 900.0              ## The speed the brake has to take off (m/s), for its gauge.
var now_lbl: Label
var minimap: MiniMap
var steps_shown := ""
var plan_ok := false                   ## The pilot said the plan is good (or let it be for a while): time runs to the burn.
var plan_shown_ms := 0
var cur_stop := ""                   ## The moment time is running to now ("count", "correct", "arrive").
var held_for := ""                   ## The moment the pilot's own choice of speed holds until.
var skip_step := ""                  ## The step the flight computer flies for the pilot (Skip).
var view := "map"                    ## craft or map
var view_auto := true
var map_view := "trip"               ## earth, trip, moon
var yaw := 0.0
var pitch := 0.0
var zoom := 1.0
var cam_center := Vector3.ZERO
var cam_dist := 60.0
var told := {}
var sfx := {}
var rumble: AudioStreamPlayer
var old_far := 2000.0
var last_count := -1

# the map
var mv: Node3D
var earth: Node3D
var moon: Node3D
var ghost: MeshInstance3D
var ghost_lbl: Label3D
var craft: MeshInstance3D
var craft_lbl: Label3D
var mark: MeshInstance3D
var mark_lbl: Label3D
var plan_line: MeshInstance3D
var pred_line: MeshInstance3D
var trail_line: MeshInstance3D
var trail := PackedVector3Array()
var trail_t := 0.0
var moon_lbl: Label3D
var moon_dot: MeshInstance3D
var moon_track: MeshInstance3D
var earth_lbl: Label3D
# next to the craft
var cv: Node3D
var ship: Node3D
var flame: CPUParticles3D
var cv_earth: Node3D
var cv_moon: Node3D
var stars: MultiMeshInstance3D
var plan_panel: PanelContainer


func enter(args: Dictionary) -> void:
	auto_fly = bool(args.get("auto", false))
	m = Transfer.new()
	m.setup()
	u = m.r_e / EARTH_U
	var climb: Dictionary = GameState.flight.get("ascent", {})
	r_park = m.r_e + float(climb.get("height_km", 166.0)) * 1000.0
	t_launch = ORBIT_UTC - float(climb.get("time_s", 480.0))
	m.place_circular(r_park, 0.0, ORBIT_UTC)
	world.cam_free = false
	world.clear_stage()
	old_far = world.cam.far
	world.cam.far = 60000.0
	world.cam.near = 0.05
	world.world_env.environment.ambient_light_energy = 0.2
	var lon := deg_to_rad(SUN_LON_DEG)
	world.sun.basis = Basis.looking_at(-Vector3(cos(lon), 0.0, -sin(lon)), Vector3.UP)
	world.sun.light_energy = 1.3
	_build_map()
	_build_craft_view()
	stars = _starfield()
	world.stage.add_child(stars)
	_build_hud()
	for id in ["beep", "clunk", "chime", "alarm"]:
		sfx[id] = Sound.player(self, id)
	rumble = Sound.player(self, "rumble", -40.0)
	_replan()
	_camera(1.0, true)


func exit() -> void:
	world.cam.far = old_far


# ===================================================================================== THE TWO VIEWS
func _build_map() -> void:
	mv = Node3D.new()
	world.stage.add_child(mv)
	earth = Space.make_earth(EARTH_U, false)
	mv.add_child(earth)
	earth_lbl = _label(tr("Earth"), Vector3(0, EARTH_U * 1.25, 0), Color(0.7, 0.85, 1.0))
	mv.add_child(earth_lbl)
	moon = Space.make_moon(m.r_m / u)
	mv.add_child(moon)
	moon_dot = _dot(Color(0.78, 0.78, 0.8))
	mv.add_child(moon_dot)
	moon_lbl = _label(tr("Moon"), Vector3.ZERO, Color(0.9, 0.9, 0.92))
	mv.add_child(moon_lbl)
	# the Moon's real track over the month, from the ephemeris, dashed
	var track := PackedVector3Array()
	var k := 0
	var tt := 0.0
	while tt < 29.0 * Transfer.DAY:
		if k % 2 == 0:
			track.append(_v3(m.moon(tt)))
			track.append(_v3(m.moon(tt + 3.0 * 3600.0)))
		tt += 3.0 * 3600.0
		k += 1
	moon_track = _line_node(Color(0.75, 0.78, 0.85, 0.45))
	_set_line(moon_track, track, false)
	mv.add_child(moon_track)
	var ring := PackedVector3Array()
	for i in 181:
		var a := TAU * i / 180.0
		ring.append(_v3([r_park * cos(a), r_park * sin(a)]))
	var rl := _line_node(Color(0.45, 0.8, 1.0, 0.85))
	_set_line(rl, ring)
	mv.add_child(rl)
	plan_line = _line_node(Color(0.4, 1.0, 0.6, 0.95))
	mv.add_child(plan_line)
	pred_line = _line_node(Color(0.45, 0.85, 1.0))
	mv.add_child(pred_line)
	trail_line = _line_node(Color(1.0, 0.72, 0.3, 0.9))
	mv.add_child(trail_line)
	ghost = _dot(Color(0.85, 0.87, 0.92, 0.35))
	mv.add_child(ghost)
	ghost_lbl = _label("", Vector3.ZERO, Color(0.85, 0.87, 0.92))
	mv.add_child(ghost_lbl)
	mark = _dot(Kit.C_OK)
	mv.add_child(mark)
	mark_lbl = _label(tr("Burn here"), Vector3.ZERO, Kit.C_OK)
	mv.add_child(mark_lbl)
	craft = _dot(Color.WHITE)
	mv.add_child(craft)
	craft_lbl = _label(tr("Your craft"), Vector3.ZERO, Color.WHITE)
	mv.add_child(craft_lbl)


## The craft at the centre, true size; the Earth and the Moon where they are, at their true size in the sky.
func _build_craft_view() -> void:
	cv = Node3D.new()
	world.stage.add_child(cv)
	ship = Ship.build(mission)
	var r: float = ship.get_meta("radius", 1.0)
	ship.scale = Vector3.ONE * (4.0 / maxf(r, 0.01))     # about 4 m across
	cv.add_child(ship)
	flame = Space.make_vacuum_flame(1.6)
	cv.add_child(flame)
	cv_earth = Space.make_earth(1.0, false)
	cv.add_child(cv_earth)
	cv_moon = Space.make_moon(1.0)
	cv.add_child(cv_moon)


## Stars at every direction, far beyond everything, moving with the camera (a backdrop of our own: random positions
## with a spread of brightness, not a star catalogue).
func _starfield() -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = mat
	mm.mesh = q
	mm.instance_count = STARS
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in STARS:
		var d := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var in_band := i < int(STARS * 0.45)
		if in_band:   # pressed toward a great circle tilted across the sky
			var pole := Vector3(0.35, 0.86, 0.36).normalized()
			d = (d - pole * d.dot(pole) * 0.86).normalized()
		var bright := pow(rng.randf(), 5.0 if in_band else 3.0)
		var s := lerpf(14.0, 70.0, bright)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), d * 40000.0))
		var tint := Color(0.8, 0.88, 1.0).lerp(Color(1.0, 0.93, 0.82), rng.randf())
		mm.set_instance_color(i, Color(tint.r, tint.g, tint.b, lerpf(0.25, 1.0, bright)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _build_hud() -> void:
	hud = FlightHud.new()
	add_child(hud)
	hud.build(tr("TO THE MOON"), tr("BURN"), tr("Space: act · ← → ↑ ↓ camera · M map · , . time"), true, false)
	hud.add_time_warp(100000.0)
	hud.add_readout("next", tr("Next"))
	hud.add_readout("utc", tr("Date (UTC)"))
	hud.add_readout("trip", tr("Trip"))
	hud.add_readout("pass", tr("Pass over the Moon"))
	hud.add_readout("speed", tr("Speed"))
	hud.add_gauge("burn", tr("Speed added"), 1.02, 1.08, Kit.C_OK)
	hud.show_gauge("burn", false)
	hud.lever.value = 1.0
	hud.action.lit = false
	hud.throttle_changed.connect(func(v): throttle = v)
	hud.action_pressed.connect(_on_action)
	hud.autopilot_toggled.connect(_on_autopilot)
	hud.skip_pressed.connect(_skip)
	hud.add_restart()
	hud.restart_pressed.connect(func(): _restart(false))
	hud.warp_picked.connect(_on_warp_picked)
	hud.set_autopilot(GameState.pilot_bot or auto_fly)
	_build_steps()
	_build_now()
	_build_minimap()
	_build_plan_panel()
	hud.hint(tr("You are in orbit around the Earth. Mission control is working out when to leave so that you meet the Moon where it will be in three or four days."))


func _on_autopilot(on: bool) -> void:
	if on:
		hud.hint(tr("Autopilot on: the flight computer flies every step."))


## On a phone nothing covers anything (issue #93): the plan starts under Skip, and the line of what to do now wraps in
## the gap between the readouts and the panels on the right.
func _fit_compact() -> void:
	var view: Vector2 = hud.get_viewport_rect().size
	var top_right: Rect2 = hud._top_right.get_parent().get_global_rect()
	plan_panel.offset_top = top_right.end.y + 6.0
	plan_panel.offset_bottom = plan_panel.offset_top
	var l: float = hud.readouts_panel.get_global_rect().end.x + 8.0
	var r: float = (plan_panel.get_global_rect().position.x if plan_panel.visible else top_right.position.x) - 8.0
	var p: Control = now_lbl.get_parent()
	p.anchor_left = 0.0
	p.anchor_right = 0.0
	p.grow_horizontal = Control.GROW_DIRECTION_END
	p.offset_left = l
	p.offset_right = r
	now_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	now_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	now_lbl.custom_minimum_size.x = maxf(80.0, r - l - 30.0)
	# the big message starts under that line, never behind it
	var top: float = p.get_global_rect().end.y + 6.0 if p.visible else 60.0
	for pair in [[hud.big, 0.0, 56.0], [hud.sub, 58.0, 140.0]]:
		var lb: Control = pair[0]
		lb.anchor_top = 0.0
		lb.anchor_bottom = 0.0
		lb.offset_top = top + pair[1]
		lb.offset_bottom = top + pair[2]


## The trip's steps across the top, the one being flown lit: the player always knows where they are and what comes.
func _build_steps() -> void:
	steps_row = Kit.hbox(6)
	steps_row.alignment = BoxContainer.ALIGNMENT_CENTER
	steps_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Kit.compact:
		Kit.place(steps_row, 0.5, 0, 0.5, 0, -230, Kit.MARGIN, 230, Kit.MARGIN + 28)
	else:
		Kit.place(steps_row, 0.5, 0, 0.5, 0, -330, 26, 330, 56)
	hud.add_child(steps_row)
	_show_steps()


func _show_steps() -> void:
	steps_shown = phase
	for c in steps_row.get_children():
		c.queue_free()
	var at: int = STEP_OF.get(phase, 0)
	for i in STEPS_TEXT.size():
		var col: Color = Kit.C_GOLD if i == at else (Kit.C_OK if i < at else Color(Kit.C_ON_DARK, 0.55))
		var word: String = tr(STEPS_TEXT[i]) if (i == at or not Kit.compact) else ""   # on a phone only the step being flown is named
		steps_row.add_child(Kit.chip((("✓" if i < at else "%d" % (i + 1)) + ("  " + word if word != "" else "")), col))


## What to do right now, in one line under the steps: the player is never left guessing.
func _build_now() -> void:
	var p := Kit.panel_box(8)
	p.add_theme_stylebox_override("panel", Kit.flat(Kit.C_BG, Kit.C_GOLD, 10, 1, 14, 6))
	Kit.place(p, 0.5, 0, 0.5, 0, 0, 46 if Kit.compact else 64, 0, 46 if Kit.compact else 64)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(p)
	now_lbl = Kit.lbl("", Kit.T_LEAD, Kit.C_GOLD, Kit.FONT_B)
	p.add_child(now_lbl)


func _now_text() -> String:
	match phase:
		"plan":
			if plan.is_empty():
				return tr("Wait: mission control is planning your departure")
			if not plan_ok:
				return tr("Adjust the departure if you like, then give the GO (SPACE)")
			return tr("Time runs to the burn: the flight computer fires the engine at the planned second")
		"burn":
			return tr("The engine burns: watch your path stretch out toward the Moon")
		"coast":
			if correction_state == "offered":
				return tr("Mission control has a correction: give the GO (SPACE)")
			return tr("Nothing to do: you coast toward the Moon and time runs by itself")
		"capture":
			return tr("Out of contact behind the Moon: the computer brakes on its own") if los else tr("The flight computer brakes you into orbit around the Moon")
		"lunar":
			return tr("You circle the Moon. Look at your orbit, then press SPACE to go down and land")
		"missed":
			return tr("Press SPACE to try the departure again")
	return ""


## A small map, always in view: the Earth, the Moon on its orbit, your craft and the path it will follow.
func _build_minimap() -> void:
	var p := Kit.panel_box(12)
	if Kit.compact:
		Kit.place(p, 0, 1, 0, 1, Kit.MARGIN, -Kit.MARGIN - 206, Kit.MARGIN + 206, -Kit.MARGIN)
	else:
		Kit.place(p, 0, 1, 0, 1, Kit.MARGIN, -300, Kit.MARGIN + 272, -Kit.MARGIN)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(p)
	hud.left_panel = p   # on a phone it shrinks under the readouts and the hint starts after it
	var v := Kit.vbox(4)
	p.add_child(v)
	v.add_child(Kit.caps(tr("Map · M for the big one")))
	minimap = MiniMap.new()
	minimap.screen = self
	minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(minimap)


## The plan's own controls: move the burn earlier or later, make it bigger or smaller, or take mission control's plan.
func _build_plan_panel() -> void:
	plan_panel = Kit.panel_box(Kit.PAD)
	if Kit.compact:
		Kit.place(plan_panel, 1, 0, 1, 0, -300, 58, -Kit.MARGIN, 58)
		hud.right_panel = plan_panel
	else:
		Kit.place(plan_panel, 1, 0, 1, 0, -380, 90, -Kit.MARGIN, 90)
	hud.add_child(plan_panel)
	var v := Kit.vbox(Kit.GAP)
	plan_panel.add_child(v)
	v.add_child(Kit.caps(tr("Your departure")))
	var try_it := Kit.lbl(tr("Try it: move the burn or change its size and watch where your path meets the Moon."), Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true)
	try_it.visible = not Kit.compact
	v.add_child(try_it)
	var row1 := Kit.segmented()
	v.add_child(row1)
	var bw := 128 if Kit.compact else 160
	row1.add_child(Kit.choice(tr("◀ Earlier"), false, func(): _shift(-1.0), bw))
	row1.add_child(Kit.choice(tr("Later ▶"), false, func(): _shift(1.0), bw))
	var row2 := Kit.segmented()
	v.add_child(row2)
	row2.add_child(Kit.choice(tr("Slower trip"), false, func(): _resize(-25.0), bw))
	row2.add_child(Kit.choice(tr("Faster trip"), false, func(): _resize(25.0), bw))
	v.add_child(Kit.choice(tr("Mission control's plan"), false, func(): _shift(0.0, true), 2 * bw + 4))
	var go_btn := Kit.accent_btn(Kit.btn(tr("GO for the burn ▶"), func(): _go_ahead(), Kit.T_BODY, 2 * bw + 4), Kit.C_GOLD)
	go_btn.custom_minimum_size.y = Kit.BTN_H
	go_btn.focus_mode = Control.FOCUS_NONE
	v.add_child(go_btn)


# ===================================================================================== EACH FRAME
## The Earth turns once a sidereal day [S-nssdc-planets]. Drawn at its true angle while that can be followed by eye;
## when time runs so fast that it would turn more than EARTH_SPIN_MAX times a second (day and night and the clouds
## flashing by: issue #55), it is held at its last angle and the time note says so; it eases back to the true angle
## when time slows down.
func _spin_earth(delta: float) -> void:
	var day_s: float = FlightData.fact("earth", "sidereal_rotation_h", 23.9345) * 3600.0
	var true_angle: float = fmod(TAU * m.t / day_s, TAU)
	var fast: bool = hud.warp / day_s > EARTH_SPIN_MAX
	if not fast:
		earth_spin = lerp_angle(earth_spin, true_angle, clampf(delta * 4.0, 0.0, 1.0)) if earth_held else true_angle
		if earth_held and absf(angle_difference(earth_spin, true_angle)) < 0.01:
			earth_held = false
	else:
		earth_held = true
	hud.extra_note = tr("the Earth's turning held still (it would be a blur)") if fast else ""


func process(delta: float) -> void:
	phase_t += delta
	_spin_earth(delta)
	hud.ring.active = false
	# each phase sets how fast time may run first, and only then takes its step (delta * hud.warp): a step taken at the
	# speed of the wait just ended would jump past the moment the phase slowed down for
	match phase:
		"plan":
			_plan_phase(delta)
		"burn":
			_burn_phase(delta)
		"coast":
			_coast_phase(delta)
		"capture":
			_capture_phase(delta)
		"lunar":
			_lunar_phase(delta)
		"missed":
			_missed_phase(delta)
	plan_panel.visible = phase == "plan" and not plan.is_empty() and not plan_ok
	if Kit.compact:   # on a phone the plan and the controls share the right side: only one at a time
		hud.controls_panel.visible = not plan_panel.visible
		_fit_compact()
	# seen from beside the craft, fast time is the Earth flashing from day to night every few seconds: the map shows it
	if view_auto and view == "craft" and hud.warp > 300.0:
		view = "map"
	_draw_map()
	_draw_craft_view()
	_camera(delta)
	_readouts()
	var loud: bool = (phase == "burn" or braking) and throttle > 0.02
	if loud and not rumble.playing:
		rumble.play()
	rumble.volume_db = lerpf(rumble.volume_db, lerpf(-30.0, -12.0, throttle) if loud else -60.0, clampf(delta * 5.0, 0.0, 1.0))
	if rumble.volume_db < -55.0 and rumble.playing:
		rumble.stop()


func _computer() -> bool:
	return hud.autopilot or skip_step == phase


## Time by itself: each wait runs at one steady speed that takes SEGMENT_S real seconds to reach the next moment
## (`next_t`, mission time), unless the pilot picked a speed for this wait. Returns the mission seconds to advance this
## frame, never past next_t.
func _time_to(next_t: float, delta: float, stop_name: String, seg := SEGMENT_S) -> float:
	var left: float = next_t - m.t
	if stop_name != cur_stop:
		cur_stop = stop_name
		held_for = ""
		hud.set_warp(clampf(left / seg, 1.0, hud.warp_cap))
		hud.auto_note = tr("Auto") if hud.warp > 1.0 else ""
	elif held_for != stop_name and hud.warp < 1.5 and left > 5.0:
		hud.set_warp(clampf(left / seg, 1.0, hud.warp_cap))
		hud.auto_note = tr("Auto")
	var dt: float = delta * hud.warp
	if left > 0.0 and dt > left:
		dt = left
	return dt


func _on_warp_picked(_w: float) -> void:
	held_for = cur_stop
	hud.auto_note = ""


# ===================================================================================== 1. PLAN, AND THE COUNTDOWN
func _replan() -> void:
	var a_now := atan2(m.y, m.x)
	job = m.plan_start(r_park, a_now, m.t, dv_plan, 3.0, m.burn_time(dv_plan) * 0.5 + COUNTDOWN + 240.0)
	plan = {}
	shown = {}
	shift_deg = 0.0
	hud.message(tr("PLANNING"), tr("Mission control is computing your departure..."), Kit.C_ACCENT, 0.0)


func _plan_phase(delta: float) -> void:
	# time may only run fast once the plan is taken: sped up while mission control planned, or while the player
	# looked at the plan, the craft flew past the moment to leave and burned in the wrong place (it missed the Moon)
	if plan_ok and not plan.is_empty():
		hud.cap_warp(100000.0)
	else:
		hud.cap_warp(1.0, tr("your plan first"))
	var dt: float = delta * hud.warp
	if not job.is_empty():
		if m.plan_work(job, 8.0):
			plan = job.result
			job = {}
			hud.message("", "", Color.WHITE, 0.01)
			if plan.is_empty():
				hud.hint(tr("No departure on this lap meets the Moon with this burn; try another size."))
			else:
				_show_plan()
				plan_shown_ms = Time.get_ticks_msec()
				hud.message(tr("YOUR PLAN"), tr("Burn at the green mark, on the far side of the Earth from where the Moon will be."), Kit.C_OK, 4.0)
				hud.hint(tr("Mission control planned your departure: your path (green) swings out and meets the Moon where it will be in three or four days. Move the burn or change its size on the right if you like, then give the GO: time runs to the burn and the flight computer fires the engine."))
				hud.action.label = "GO"
				hud.action.lit = true
		m.advance(dt)
		return
	if plan.is_empty():
		m.advance(dt)
		return
	if not plan_ok:
		m.advance(dt)
		if Time.get_ticks_msec() - plan_shown_ms > 20000:
			_go_ahead()
		return
	var count_at := burn_start - COUNTDOWN
	if m.t > burn_start + GRACE + 2.0 and not hud.action.lit:
		_replan()   # the moment to leave has gone by: mission control plans the next one, it never burns late
		return
	if m.t < count_at:
		m.advance(_time_to(count_at, get_process_delta_time(), "count"))
		hud.action.lit = false
		return
	# the countdown, three real seconds: the flight computer fires the engine at zero, at the planned second
	hud.cap_warp(1.0, tr("countdown"))
	hud.auto_note = ""
	m.advance(minf(delta * hud.warp, maxf(burn_start - m.t, 0.0)))
	var left: float = burn_start - m.t
	hud.action.lit = false
	if view_auto:
		view = "craft"
	var n := ceili(left)
	if n != last_count and n >= 0:
		last_count = n
		sfx.beep.play()
		hud.message(tr("IGNITION IN %d") % n if n > 0 else tr("IGNITION"), tr("The flight computer fires the engine at the planned second."), Kit.C_ACCENT, 0.0)
	if left <= 0.0:
		_start_burn()


func _go_ahead() -> void:
	if plan_ok:
		return
	plan_ok = true
	hud.action.lit = false
	hud.message(tr("GO FOR THE BURN"), tr("Time runs to the planned second; the flight computer fires the engine."), Kit.C_ACCENT, 2.5)
	hud.hint(tr("Like a real departure, the burn is planned to the second and flown by the computer: you chose when and how much, it holds the engine to the plan. Watch your path stretch out on the map."))


func _show_plan() -> void:
	var a: float = plan.angle + deg_to_rad(shift_deg)
	var dep: Array = m.departure(r_park, atan2(m.y, m.x), a, m.t, dv_plan, m.burn_time(dv_plan) * 0.5 + COUNTDOWN + 60.0)
	if shift_deg == 0.0:
		shown = plan.pass
		dep[1] = plan.time
	else:
		shown = m.predict(dep[0], dep[1])
	burn_start = float(dep[1]) - m.burn_time(dv_plan) * 0.5
	mark.position = _v3([r_park * cos(a), r_park * sin(a)])
	_draw_path(plan_line, shown)


func _shift(deg: float, reset := false) -> void:
	if plan.is_empty():
		return
	shift_deg = 0.0 if reset else shift_deg + deg
	_show_plan()
	if not reset and not told.has("shift"):
		told["shift"] = true
		hud.hint(tr("One degree moves your pass over the Moon by thousands of kilometres: real missions plan the departure carefully, and correct on the way."))


func _resize(d: float) -> void:
	var nd := clampf(dv_plan + d, DV_MIN, DV_MAX)
	if nd != dv_plan:
		dv_plan = nd
		_replan()
		if not told.has("dv"):
			told["dv"] = true
			hud.hint(tr("A bigger burn is a faster trip, but you arrive faster too, and need a bigger burn to stop at the Moon."))


func _on_action() -> void:
	match phase:
		"plan":
			if plan.is_empty():
				return
			if not plan_ok:
				_go_ahead()
				return
			hud.message(tr("ON ITS WAY"), tr("The flight computer fires the engine in %s.") % _span(burn_start - m.t), Kit.C_ACCENT, 1.5)
		"coast":
			if correction_state == "offered":
				_correct(false)
		"lunar":
			_to_landing()
		"missed":
			_restart(false)


# ===================================================================================== 2. THE BURN
func _start_burn() -> void:
	phase = "burn"
	phase_t = 0.0
	burn_t0 = m.t
	burn_ms = Time.get_ticks_msec()
	m.dv_used = 0.0
	throttle = 1.0
	hud.lever.value = 1.0
	hud.cap_warp(100.0, tr("engine on"))
	hud.set_warp(BURN_WARP)
	hud.auto_note = ""
	hud.action.lit = false
	hud.show_gauge("burn", true)
	if view_auto:
		view = "craft"
	sfx.beep.play()
	hud.message(tr("IGNITION"), tr("The engine burns until it has added %d m/s, then the computer cuts it.") % roundi(dv_plan), Kit.C_ACCENT, 3.0)
	hud.hint(tr("About six minutes of burning, sped up. The map shows your orbit stretching into a long ellipse that reaches the Moon's distance."))
	GameState.flight_moment("tli_start", {"dv_plan": roundi(dv_plan)})


## The farthest the craft's orbit around the Earth goes (two bodies), metres; INF once it would leave the Earth.
func _farthest() -> float:
	var r := sqrt(m.x * m.x + m.y * m.y)
	var energy: float = (m.vx * m.vx + m.vy * m.vy) / 2.0 - m.mu_e / r
	if energy >= 0.0:
		return INF
	var a: float = -m.mu_e / (2.0 * energy)
	var h: float = m.x * m.vy - m.y * m.vx
	var e := sqrt(maxf(1.0 + 2.0 * energy * h * h / (m.mu_e * m.mu_e), 0.0))
	return a * (1.0 + e)


func _burn_phase(delta: float) -> void:
	var dt: float = delta * hud.warp
	# the flight computer holds the engine to the plan and eases off near the end, as a guidance system does
	throttle = clampf((dv_plan - m.dv_used) / 40.0, 0.15, 1.0)
	hud.lever.value = throttle
	var step := minf(dt, maxf((dv_plan - m.dv_used) / m.accel(throttle), 0.0))
	m.advance(step, throttle, 1.0)
	_refresh_pred(0.25)
	hud.gauge("burn", m.dv_used / dv_plan / 1.1, "%d / %d m/s" % [roundi(m.dv_used), roundi(dv_plan)])
	if view_auto and phase_t > 2.0:
		view = "map"   # after the ignition, the map: the orbit stretching toward the Moon is the point of the burn
		map_view = "earth"
	if m.dv_used >= dv_plan - 0.05:
		_cut(true)


func _cut(by_computer: bool) -> void:
	var error: float = (float(m.dv_used) - dv_plan) / dv_plan
	GameState.flight["tli"] = {"dv": roundi(m.dv_used), "target": roundi(dv_plan), "error": snappedf(error, 0.0001),
		"by": "computer" if by_computer else "pilot", "shift_deg": shift_deg, "burn_s": roundi(m.t - burn_t0), "t_cut": m.t}
	m.use_engine("craft")   # the departure stage is left behind; from here the craft's own engine burns
	GameState.flight_moment("tli", GameState.flight.tli)
	phase = "coast"
	phase_t = 0.0
	if skip_step == "burn":
		skip_step = "coast"
	throttle = 0.0
	hud.lever.value = 0.0
	hud.action.lit = false
	hud.show_gauge("burn", false)
	hud.cap_warp(100000.0)
	sfx.clunk.play()
	pred_age = 99.0
	_refresh_pred(0.0)
	sfx.chime.play()
	hud.message(tr("ON YOUR WAY TO THE MOON"), tr("Engine off at %d m/s. Now about three days of coasting.") % roundi(m.dv_used), Kit.C_OK, 3.5)
	hud.hint(tr("Engine off. You coast for days: the Earth's pull slows you as you climb. Time runs by itself; mission control watches your path and will trim it on the way if needed."))


# ===================================================================================== 3. THE COAST
func _coast_phase(_delta: float) -> void:
	var t_cut: float = GameState.flight.tli.get("t_cut", m.t)
	if view_auto:
		view = "map"   # the coast is days of the path bending toward the Moon: only the map shows it (issue #79)
	if correction_state == "":
		var at := t_cut + CORRECT_AFTER
		m.advance(_time_to(at, get_process_delta_time(), "correct"))
		_refresh_pred(0.4)
		if m.t >= at - 0.5:
			hud.set_warp(1.0)
			correction = m.plan_correction(150.0)
			if correction.is_empty() or absf(float(correction.dv)) < 0.5:
				correction_state = "done"
				GameState.flight["correction"] = {"dv": 0.0}
				hud.message(tr("ON COURSE"), tr("No correction needed: you will pass %d km over the Moon.") % roundi(m.pass_height(pred) / 1000.0), Kit.C_OK, 3.0)
			else:
				correction_state = "offered"
				offered_ms = Time.get_ticks_msec()
				hud.action.label = "GO"
				hud.action.lit = true
				sfx.beep.play()
				hud.message(tr("MID-COURSE CORRECTION"), tr("Mission control: a %.1f m/s burn brings your pass to %d km over the Moon. GO? (SPACE)") % [absf(float(correction.dv)), roundi(m.pass_height(correction.pass) / 1000.0)], Kit.C_ACCENT, 0.0)
				hud.hint(tr("Real crews made small corrections on the way: a tiny error at the start grows over 380,000 km."))
		return
	if correction_state == "offered":
		hud.set_warp(1.0)
		if _computer() or Time.get_ticks_msec() - offered_ms > 8000.0:
			_correct(true)   # no answer: the procedure goes ahead, as planned
		return
	hud.cap_warp(100000.0)
	if not pred.is_empty() and (float(pred.closest) > Transfer.SOI or pred.impact):
		_missed(tr("Your path hits the Moon.") if pred.impact else tr("Your path does not reach the Moon."))
		return
	var cap_s: float = m.burn_time(m.capture_dv(pred)) if not pred.is_empty() else 100.0
	capture_at = float(pred.get("t_closest", m.t + 1e9)) - cap_s * 0.5
	# the long coast gets a few seconds of its own: quick, but long enough to watch the Moon come to meet you
	m.advance(_time_to(capture_at - COUNTDOWN, get_process_delta_time(), "arrive", COAST_S))
	_refresh_pred(0.5)
	if not told.has("soi") and m.about_moon().r < Transfer.SOI:
		told["soi"] = true
		hud.message(tr("THE MOON'S PULL"), tr("You enter the Moon's sphere of influence: its pull now beats the Earth's and bends your path."), Kit.C_ACCENT, 3.0)
	if m.t >= capture_at - COUNTDOWN - 0.5:
		phase = "capture"
		phase_t = 0.0
		last_count = -1
		hud.hint(tr("You arrive too fast for the Moon to hold you: left alone you would swing past it and away. Braking at the closest point, against your motion, bends that fly-by into a circle around the Moon. The small map shows both: your path, and the orbit you are braking into."))
		capture_at = m.t + COUNTDOWN   # fixed from here: the countdown is three real seconds and always ends in the burn
		if skip_step == "coast":
			skip_step = "capture"


func _correct(by_computer: bool) -> void:
	m.kick(float(correction.dv))
	correction_state = "done"
	var dv := absf(float(correction.dv))
	# the correction comes out of the lander's tanks: 1000 m/s would be all of them (a game value)
	GameState.flight["correction"] = {"dv": snappedf(dv, 0.1), "by": "computer" if by_computer else "pilot"}
	GameState.flight.tli["lander_fuel_used"] = snappedf(clampf(dv / 1000.0, 0.0, 0.4), 0.001)
	hud.action.lit = false
	hud.action.label = "BRAKE"
	hud.message(tr("CORRECTED"), tr("%.1f m/s burned. You will pass %d km over the Moon.") % [dv, roundi(m.pass_height(correction.pass) / 1000.0)], Kit.C_OK, 3.0)
	sfx.clunk.play()
	pred_age = 99.0
	_refresh_pred(0.0)


# ===================================================================================== 4. CAPTURE
func _capture_phase(delta: float) -> void:
	if view_auto and not braking:   # the arrival on the map, close on the Moon: the path that the brake will bend
		view = "map"
		map_view = "moon"
	if not braking:
		hud.cap_warp(1.0, tr("countdown"))
		hud.auto_note = ""
		m.advance(delta * hud.warp)
		_refresh_pred(0.25)
		var left: float = capture_at - m.t
		hud.action.lit = false
		var n := ceili(left)
		if n != last_count and n >= 0:
			last_count = n
			sfx.beep.play()
			hud.message(tr("BRAKE IN %d") % n if n > 0 else tr("BRAKING"), tr("You fall past the Moon at %.1f km/s. The flight computer burns against your motion so the Moon can hold you.") % (m.about_moon().v / 1000.0), Kit.C_ACCENT, 0.0)
		if left <= 0.0:
			_brake()
		_refresh_pred(0.4)
		return
	throttle = 1.0
	hud.lever.value = throttle
	m.advance(delta * hud.warp, throttle, -1.0, true)
	if view_auto:   # on the map, close on the Moon: the path is seen bending from a fly-by into a loop
		view = "map"
		map_view = "moon"
	hud.gauge("burn", m.dv_used / maxf(brake_dv, 1.0) / 1.1, tr("%d of about %d m/s lost") % [roundi(m.dv_used), roundi(brake_dv)])
	var o: Dictionary = m.moon_orbit()
	# a brake that cannot work (far from the Moon, or the tanks' worth burned and still not held) is never left running
	if m.about_moon().r > Transfer.SOI or m.dv_used > BRAKE_DV_MAX:
		braking = false
		throttle = 0.0
		hud.lever.value = 0.0
		_missed(tr("The Moon could not hold you."))
		return
	var here: float = m.about_moon().r - m.r_m
	# the Moon holds the craft once the orbit's high point comes down to where the craft is: then it is nearly round;
	# and the engine never brakes on into an orbit that would meet the ground
	# the computer cuts once the orbit's high point has come down, and never brakes into one that meets the ground
	if o.high < maxf(LUNAR_ORBIT_HIGH, here + 40000.0) or (o.high < INF and o.low < 30000.0):
		_end_capture(true)
	_refresh_pred(0.4)


func _brake() -> void:
	braking = true
	los = _behind_moon()
	burn_ms = Time.get_ticks_msec()
	m.dv_used = 0.0
	throttle = 1.0
	hud.lever.value = 1.0
	hud.cap_warp(100.0, tr("engine on"))
	hud.set_warp(BURN_WARP * 0.5)
	brake_dv = m.capture_dv(pred) if not pred.is_empty() else 900.0
	hud.show_gauge("burn", true)
	hud.name_gauge("burn", tr("Speed lost"))
	hud.action.lit = false
	if los:
		# Apollo's crews braked into lunar orbit on the far side, out of contact with the ground [S-afj-loi]
		hud.message(tr("LOSS OF SIGNAL"), tr("The Moon is between you and the Earth: no radio. The computer brakes on its own, as Apollo's crews did on the far side."), Kit.C_WARN, 3.5)
	else:
		hud.message(tr("BRAKING"), tr("Burning against your motion. The engine stops by itself once the Moon holds you."), Kit.C_ACCENT, 3.0)
	sfx.beep.play()


## True when the Moon hides the craft from the Earth: the craft beyond the Moon, closer to the Earth-Moon line than the
## Moon's radius (the radio needs a straight line; our simplification: the Earth as a point at its centre).
func _behind_moon() -> bool:
	var mo: Array = m.moon(m.t)
	var mx: float = mo[0]
	var my: float = mo[1]
	var d := sqrt(mx * mx + my * my)
	var ux: float = mx / d
	var uy: float = my / d
	var rx: float = m.x - mx
	var ry: float = m.y - my
	var along: float = rx * ux + ry * uy
	var across: float = absf(rx * uy - ry * ux)
	return along > 0.0 and across < m.r_m


func _end_capture(by_computer: bool) -> void:
	if Time.get_ticks_msec() - burn_ms < CUT_GUARD_MS:
		return
	var o: Dictionary = m.moon_orbit()
	if o.high == INF:
		return
	braking = false
	throttle = 0.0
	hud.lever.value = 0.0
	phase = "lunar"
	phase_t = 0.0
	hud.action.lit = false
	hud.action.label = "LAND"
	hud.show_gauge("burn", false)
	sfx.chime.play()
	GameState.flight["capture"] = {"dv": roundi(m.dv_used), "low_km": roundi(o.low / 1000.0), "high_km": roundi(o.high / 1000.0),
		"by": "computer" if by_computer else "pilot", "met_s": roundi(m.t - t_launch)}
	GameState.flight_moment("lunar_orbit", GameState.flight.capture)
	hud.cap_warp(1000.0)
	hud.set_warp(100.0)
	if view_auto:   # the map, close on the Moon: the player sees the orbit they are in before the landing
		view = "map"
		map_view = "moon"
		zoom = 1.0
	var aos: String = (tr("Signal again: the Earth hears you.") + " ") if los else ""
	hud.message(tr("IN ORBIT AROUND THE MOON"), aos + tr("%d × %d km over its surface.") % [roundi(o.low / 1000.0), roundi(o.high / 1000.0)], Kit.C_OK, 0.0)
	hud.hint(tr("The Moon holds you now: you go round it without burning any fuel, a lap about every two hours. The small map shows your orbit. When you are ready, press SPACE to go down to Shackleton's rim."))


func _lunar_phase(delta: float) -> void:
	m.advance(delta * hud.warp)
	_refresh_pred(0.5)
	hud.action.label = "LAND"
	hud.action.lit = true
	# the pilot looks at the orbit as long as they like (SPACE goes down); left alone, the game goes on by itself
	if phase_t > 14.0 or (_computer() and phase_t > 8.0):
		_to_landing()


func _to_landing() -> void:
	if leaving:
		return
	leaving = true
	GameState.flight["arrival_met_s"] = roundi(m.t - t_launch)
	main.go_faded("landing", 1.0, 1.0)


## A path that will not end around the Moon. Never a dead end: the game says so and offers the departure again.
func _missed(why: String) -> void:
	phase = "missed"
	phase_t = 0.0
	missed_ms = Time.get_ticks_msec()
	throttle = 0.0
	hud.cap_warp(1.0, tr("waiting for you"))
	hud.auto_note = ""
	hud.action.label = "RETRY"
	hud.action.lit = true
	sfx.alarm.play()
	hud.message(tr("YOU MISSED THE MOON"), why + " " + tr("Press SPACE to go back to your orbit around the Earth and try the departure again."), Kit.C_WARN, 0.0)
	hud.hint(tr("Real missions cannot go back, so they plan the departure with great care. Here you can: try again, or press Skip and the flight computer flies it."))
	GameState.flight_moment("missed_moon", {})


func _missed_phase(delta: float) -> void:
	m.advance(delta)
	_refresh_pred(1.0)
	if hud.autopilot or Time.get_ticks_msec() - missed_ms > 30000:
		_restart(hud.autopilot)


## Back to the parking orbit to fly the trip again; `auto`: the flight computer flies it this time.
func _restart(auto: bool) -> void:
	if leaving:
		return
	leaving = true
	main.go("flight", {"auto": auto})


## Skip: the flight computer flies the current step for the pilot (and the time runs to it as fast as it can).
func _skip() -> void:
	if phase == "missed":
		_restart(true)
		return
	if phase == "plan" and not plan.is_empty():
		_shift(0.0, true)   # the computer flies mission control's plan, not a departure that misses
		_go_ahead()
	skip_step = phase
	hud.set_autopilot(true)   # Skip is the whole way: the flight computer flies on from here, and the switch shows it
	held_for = ""
	cur_stop = ""
	if phase == "lunar":
		_to_landing()
	elif phase == "coast" and correction_state == "offered":
		_correct(true)
	hud.message(tr("FLIGHT COMPUTER"), tr("It flies this step for you."), Kit.C_ACCENT, 1.5)


# ===================================================================================== DRAWING
func _v3(p: Array) -> Vector3:
	return Vector3(p[0], 0.0, -p[1]) / u


func _refresh_pred(every: float) -> void:
	pred_age += get_process_delta_time()
	if pred_age < every:
		return
	pred_age = 0.0
	var lunar: bool = phase == "lunar" or (phase == "capture" and m.moon_orbit().high < INF)
	pred = m.predict(m.state(), m.t, 2.2 * 3600.0 if lunar else 7.0 * Transfer.DAY)
	_draw_path(pred_line, pred)


## A predicted path, each point where it will be at its time; near the Moon, as the Moon sees it (a closed loop).
func _draw_path(line: MeshInstance3D, p: Dictionary) -> void:
	var moon_frame: bool = phase in ["capture", "lunar"] or m.about_moon().r < Transfer.SOI
	var pts: PackedVector2Array = p.get("points", PackedVector2Array())
	var ts: PackedFloat64Array = p.get("times", PackedFloat64Array())
	var mn: Array = m.moon(m.t)
	var out := PackedVector3Array()
	var stp := maxi(1, pts.size() / 600)
	for i in range(0, pts.size(), stp):
		var q := [pts[i].x, pts[i].y]
		var mt: Array = m.moon(ts[i])
		if moon_frame and Vector2(q[0] - mt[0], q[1] - mt[1]).length() < Transfer.SOI:
			q = [q[0] - mt[0] + mn[0], q[1] - mt[1] + mn[1]]
		out.append(_v3(q))
	_set_line(line, out)


func _draw_map() -> void:
	mv.visible = view == "map"
	if not mv.visible:
		return
	var cam: Vector3 = world.cam.global_position
	var mp: Vector3 = _v3(m.moon(m.t))
	moon.position = mp
	moon.rotation.y = atan2(mp.x, mp.z) + PI
	earth.rotation.y = earth_spin
	moon_lbl.position = mp + Vector3(0, (m.r_m / u) * 1.6 + cam.distance_to(mp) * 0.03, 0)
	moon_dot.position = mp
	moon_dot.scale = Vector3.ONE * cam.distance_to(mp) * 0.007
	moon_dot.visible = moon_dot.scale.x > m.r_m / u
	var cp: Vector3 = _v3([m.x, m.y])
	craft.position = cp
	var s := cam.distance_to(cp) * 0.009
	craft.scale = Vector3.ONE * s
	(craft.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.62, 0.22) if (phase == "burn" or braking) and throttle > 0.02 else Color.WHITE
	craft_lbl.position = cp + Vector3(0, s * 3.5, 0)
	mark.scale = Vector3.ONE * cam.distance_to(mark.position) * 0.008
	mark_lbl.position = mark.position + Vector3(0, mark.scale.x * 3.5, 0)
	var showing_plan: bool = phase == "plan" and not plan.is_empty()
	var near_earth: bool = map_view == "trip" and cp.length() < EARTH_U * 3.0
	mark.visible = showing_plan and not near_earth
	craft.visible = not near_earth
	mark_lbl.visible = showing_plan and map_view == "earth"
	craft_lbl.visible = map_view != "trip" or m.about_moon().r < Transfer.SOI or (phase == "coast" and m.x * m.x + m.y * m.y > 4.0e15)
	earth_lbl.visible = map_view == "trip"
	plan_line.visible = phase in ["plan", "burn"] and not plan.is_empty()
	pred_line.visible = phase != "plan"
	var p: Dictionary = shown if phase == "plan" else pred
	ghost.visible = not p.is_empty() and phase in ["plan", "burn", "coast"] and m.about_moon().r > Transfer.SOI
	ghost_lbl.visible = ghost.visible
	moon_track.visible = map_view != "moon"
	if ghost.visible:
		var gp := _v3(p.moon_at)
		ghost.position = gp
		ghost.scale = Vector3.ONE * maxf(m.r_m / u, cam.distance_to(gp) * 0.008)
		ghost_lbl.position = gp - Vector3(0, ghost.scale.x * 2.5, 0)
		ghost_lbl.text = tr("The Moon when you pass it")
	trail_t += get_process_delta_time()
	trail_line.visible = phase in ["burn", "coast"]
	if phase in ["burn", "coast"] and trail_t > 0.05 and m.about_moon().r > Transfer.SOI:
		trail_t = 0.0
		if trail.is_empty() or trail[trail.size() - 1].distance_to(cp) > s * 0.4:
			trail.append(cp)
			if trail.size() > 2000:
				trail.remove_at(0)
			_set_line(trail_line, trail)


## Next to the craft: the craft at the centre, its nose along its motion (against it when braking), the flame, and
## the Earth and the Moon where they are, at their true sizes in the sky.
func _draw_craft_view() -> void:
	cv.visible = view == "craft"
	if not cv.visible:
		return
	var vel := Vector3(m.vx, 0.0, -m.vy)
	if phase in ["capture", "lunar"]:
		var mv_: Array = m.moon_vel(m.t)
		vel = Vector3(m.vx - mv_[0], 0.0, -(m.vy - mv_[1]))
	var fwd := vel.normalized() if vel.length() > 1.0 else Vector3.FORWARD
	if braking:
		fwd = -fwd
	ship.basis = Basis.looking_at(fwd, Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
	var burning: bool = (phase == "burn" or braking) and throttle > 0.02
	flame.emitting = burning
	var back := -fwd
	var fy := -back
	var fx := fy.cross(Vector3.UP).normalized() if absf(fy.y) < 0.99 else Vector3.RIGHT
	flame.basis = Basis(fx, fy, fx.cross(fy))
	flame.position = back * 2.8
	_place_body(cv_earth, [0.0, 0.0], m.r_e)
	_place_body(cv_moon, m.moon(m.t), m.r_m)
	cv_earth.rotation.y = earth_spin


## Puts a body (centre c, radius r, metres) where it is seen from the craft, at its true angular size; far bodies are
## drawn nearer and smaller in the same proportion (the same view, without depth trouble).
func _place_body(body: Node3D, c: Array, r: float) -> void:
	var d := Vector3(float(c[0]) - m.x, 0.0, -(float(c[1]) - m.y))
	var dist := d.length()
	var k := minf(1.0, FAR / maxf(dist, 1.0))
	body.position = d * k
	body.scale = Vector3.ONE * r * k


func _dot(col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 1.0
	sp.height = 2.0
	sp.radial_segments = 16
	sp.rings = 8
	mi.mesh = sp
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.no_depth_test = true
	mat.render_priority = 2
	if col.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _label(text: String, pos: Vector3, col: Color) -> Label3D:
	var l := Space.make_label(text, col)
	l.position = pos
	return l


func _line_node(col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.no_depth_test = true
	mat.render_priority = 1
	if col.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _set_line(mi: MeshInstance3D, pts: PackedVector3Array, strip := true) -> void:
	var im := mi.mesh as ImmediateMesh
	im.clear_surfaces()
	if pts.size() < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP if strip else Mesh.PRIMITIVE_LINES)
	for q in pts:
		im.surface_add_vertex(q)
	im.surface_end()


# ===================================================================================== READOUTS AND CAMERA
func _readouts() -> void:
	if steps_shown != phase:
		_show_steps()
	now_lbl.text = "▶  " + _now_text()
	minimap.queue_redraw()
	hud.clock.text = FlightHud.met_text(m.t - t_launch)
	var dtd := Time.get_datetime_dict_from_unix_time(UNIX_DAY0 + int(m.t))
	hud.value("utc", "%d-%02d-%02d %02d:%02d" % [dtd.year, dtd.month, dtd.day, dtd.hour, dtd.minute])
	var next := ""
	match phase:
		"plan":
			next = tr("planning...") if plan.is_empty() else tr("burn in %s") % _span(burn_start - m.t)
		"burn":
			next = tr("cut at %d m/s") % roundi(dv_plan)
		"coast":
			next = tr("correction in %s") % _span(float(GameState.flight.tli.get("t_cut", m.t)) + CORRECT_AFTER - m.t) if correction_state != "done" \
				else tr("brake in %s") % _span(capture_at - m.t)
		"capture":
			next = tr("brake now") if braking or m.t >= capture_at else tr("brake in %s") % _span(capture_at - m.t)
		"lunar":
			next = tr("landing")
		"missed":
			next = tr("try again")
	hud.value("next", next, Kit.C_ACCENT)
	var p: Dictionary = shown if phase == "plan" else pred
	if phase == "lunar":
		var o: Dictionary = m.moon_orbit()
		hud.value("trip", tr("arrived"))
		hud.value("pass", "%d × %d km" % [roundi(o.low / 1000.0), roundi(o.high / 1000.0)], Kit.C_OK)
	elif not p.is_empty():
		var reaches: bool = float(p.closest) < Transfer.SOI
		hud.value("trip", _span(float(p.t_closest) - (burn_start if phase == "plan" else m.t)) if reaches else "—")
		var hgt: float = m.pass_height(p)
		var col := Kit.C_OK if hgt > 30000.0 and hgt < 400000.0 else (Kit.C_BAD if p.impact or hgt < 0.0 else Kit.C_WARN)
		if phase == "burn":
			hud.value("pass", tr("the path is still growing"), Kit.C_DIM)   # mid-burn the path cannot reach yet: not a fault
		else:
			hud.value("pass", tr("hits the Moon") if p.impact or hgt < 0.0 else (tr("misses it") if float(p.closest) > Transfer.SOI else "%s km" % FlightHud._thousands(hgt / 1000.0)), col)
	if phase in ["capture", "lunar"] or m.about_moon().r < Transfer.SOI:
		hud.value("speed", tr("%.2f km/s past the Moon") % (m.about_moon().v / 1000.0))
	else:
		hud.value("speed", "%.2f km/s" % (sqrt(m.vx * m.vx + m.vy * m.vy) / 1000.0))


func _span(s: float) -> String:
	s = maxf(s, 0.0)
	if s < 120.0:
		return tr("%d s") % roundi(s)
	if s < 3.0 * 3600.0:
		return tr("%d min") % roundi(s / 60.0)
	if s < 2.0 * Transfer.DAY:
		return tr("%d h") % roundi(s / 3600.0)
	var hours := roundi(s / 3600.0)
	return tr("%d d %d h") % [hours / 24, hours % 24]


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_M:
		view = "map" if view == "craft" else "craft"
		view_auto = false
		zoom = 1.0
		hud.message(tr("VIEW"), tr("The map, at true scale") if view == "map" else tr("Next to your craft"), Color.WHITE, 1.0)
	elif e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_V and view == "map":
		var order := ["earth", "trip", "moon"]
		map_view = order[(order.find(map_view) + 1) % order.size()]
		zoom = 1.0
	elif e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		zoom = clampf(zoom * (0.85 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.18), 0.15, 6.0)


func _camera(delta: float, snap := false) -> void:
	# the arrows (keys or the panel's buttons) turn the camera around what it looks at
	var st: Vector2 = hud.steer()
	yaw += st.x * delta * 1.4
	pitch = clampf(pitch + st.y * delta * 1.0, -1.2, 1.1)
	# left alone for a while, the camera comes back behind the craft by itself
	cam_idle = 0.0 if st.length() > 0.01 else cam_idle + delta
	if cam_idle > 5.0 and not snap:
		yaw = lerp_angle(yaw, 0.0, clampf(delta * 1.5, 0.0, 1.0))
		pitch = lerpf(pitch, 0.0, clampf(delta * 1.5, 0.0, 1.0))
	var k := 1.0 if snap else clampf(delta * 2.0, 0.0, 1.0)
	if view == "craft":
		var dist := 34.0 * zoom
		# a chase camera: "up" is away from the body below (the Moon once near it, else the Earth), the camera trails
		# the craft a little above it and looks ahead over the curve of the horizon
		var near_moon: bool = m.about_moon().r < Transfer.SOI
		var up: Vector3 = -(cv_moon.position if near_moon else cv_earth.position).normalized()
		var vel := Vector3(m.vx, 0.0, -m.vy)
		if near_moon:
			var mvv: Array = m.moon_vel(m.t)
			vel = Vector3(m.vx - mvv[0], 0.0, -(m.vy - mvv[1]))
		var ahead := (vel - up * vel.dot(up)).normalized()
		if ahead.length() < 0.5:
			ahead = up.cross(Vector3.UP).normalized()
		var side := ahead.cross(up).normalized()
		var behind := (-ahead).rotated(up, yaw)
		var dir := (behind * cos(pitch + 0.22) + up * sin(pitch + 0.22)).normalized()
		world.cam.near = 0.1
		world.cam.position = dir * dist + side * 0.0
		# it looks past the craft, along the line from the camera through it, so the craft stays in view however far
		# the arrows turn the camera (looking along the path alone left the craft behind the camera at half a turn)
		world.cam.look_at(ahead.rotated(up, yaw) * dist * 0.6, up)
		stars.position = world.cam.global_position
		return
	world.cam.near = 0.05
	var mp: Vector3 = _v3(m.moon(m.t))
	if view_auto:
		match phase:
			"plan":
				map_view = "trip"
			"coast":
				map_view = "moon" if m.about_moon().r < Transfer.SOI * 0.6 else "trip"
			_:
				map_view = "moon" if phase in ["capture", "lunar"] else "earth"
	var want_c := Vector3.ZERO
	var want_d := 45.0
	match map_view:
		"earth":
			want_d = 46.0 + (clampf(m.dv_used / dv_plan, 0.0, 1.0) * 120.0 if phase == "burn" else 0.0)
		"trip":
			var pts: Array = [Vector3.ZERO, mp]
			var p: Dictionary = shown if phase == "plan" else pred
			if not p.is_empty() and phase != "lunar":
				pts.append(_v3(p.moon_at))
			var lo := Vector3(INF, 0, INF)
			var hi := Vector3(-INF, 0, -INF)
			for q in pts:
				lo = Vector3(minf(lo.x, q.x), 0, minf(lo.z, q.z))
				hi = Vector3(maxf(hi.x, q.x), 0, maxf(hi.z, q.z))
			want_c = (lo + hi) * 0.5
			want_d = maxf(hi.x - lo.x, (hi.z - lo.z) * 1.6) * 0.95 + 60.0
		"moon":
			want_c = mp
			want_d = clampf(m.about_moon().r / u * 2.6, 34.0, 220.0)
	want_d *= zoom
	if map_view == "trip":
		# the map sits in the free space between the panels and below the message line at the top
		want_d *= 1.25   # room for the panels on both sides: the far end of the trip never hides under the controls
		want_c += Vector3(want_d * 0.05, 0.0, want_d * 0.06)
	cam_center = cam_center.lerp(want_c, k)
	cam_dist = lerpf(cam_dist, want_d, k)
	# the trip seen nearly from above, as on the small map: the Earth, the path and the Moon read at once (issue #79)
	var el: float = clampf(pitch + 0.9, -1.5, 1.5)
	var dir2 := Vector3(sin(yaw) * cos(el), sin(el), cos(yaw) * cos(el)).normalized()
	world.cam.position = cam_center + dir2 * cam_dist
	world.cam.look_at(cam_center, Vector3.UP)
	stars.position = world.cam.global_position


## The small map of the trip (bottom left): drawn flat, seen from above the Earth's pole, at true scale. The Earth in
## the middle, the Moon's orbit as a ring, the Moon, where the Moon will be when the craft arrives, the craft's path
## ahead and the craft itself.
class MiniMap:
	extends Control
	const K := preload("res://scripts/ui/kit.gd")
	var screen
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(170, 150) if Kit.compact else Vector2(240, 220)

	func _process(delta: float) -> void:
		_t += delta

	func _draw() -> void:
		if screen == null or screen.m == null:
			return
		var m = screen.m
		var c := size * 0.5
		var f := K.FONT_B
		var about: Dictionary = m.about_moon()
		if about.r < 6.61e7 * 0.6 or screen.phase in ["capture", "lunar"]:
			_draw_moon(m, c, f, about)
			return
		var s: float = (minf(size.x, size.y) * 0.5 - 14.0) / 4.1e8   # pixels per metre: the Moon's orbit fits
		draw_arc(c, 3.84e8 * s, 0.0, TAU, 64, Color(K.C_ON_DARK, 0.18), 1.0, true)
		var p: Dictionary = screen.shown if screen.phase == "plan" else screen.pred
		if not p.is_empty() and p.points.size() > 1:
			var line := PackedVector2Array()
			var step := maxi(1, p.points.size() / 120)
			for i in range(0, p.points.size(), step):
				line.append(c + Vector2(p.points[i].x, -p.points[i].y) * s)
			draw_polyline(line, K.C_ACCENT, 1.5, true)
			var ma: Array = p.moon_at
			draw_arc(c + Vector2(ma[0], -ma[1]) * s, 6.0, 0.0, TAU, 20, Color(K.C_ON_DARK, 0.6), 1.0, true)
		draw_circle(c, 4.0, K.C_ACCENT)
		draw_string_outline(f, c + Vector2(7, 14), TranslationServer.translate("Earth"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0.0, 0.01, 0.04, 0.9))
		draw_string(f, c + Vector2(7, 14), TranslationServer.translate("Earth"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(K.C_ON_DARK, 0.85))
		var mo: Array = m.moon(m.t)
		var mp := c + Vector2(mo[0], -mo[1]) * s
		draw_circle(mp, 3.5, Color(0.82, 0.82, 0.86))
		draw_string_outline(f, mp + Vector2(7, 4), TranslationServer.translate("Moon"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0.0, 0.01, 0.04, 0.9))
		draw_string(f, mp + Vector2(7, 4), TranslationServer.translate("Moon"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(K.C_ON_DARK, 0.85))
		var cp := c + Vector2(m.x, -m.y) * s
		draw_circle(cp, 4.0 + 1.5 * sin(_t * 5.0), K.C_GOLD)
		draw_arc(cp, 9.0, 0.0, TAU, 20, Color(K.C_GOLD, 0.5), 1.0, true)
		draw_string(f, cp + Vector2(10, -6), TranslationServer.translate("You"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, K.C_GOLD)

	## Near the Moon the map closes in on it: the Moon to scale, the ring of the orbit the craft is braking into, the
	## craft's path as the Moon sees it (a fly-by that swings past, or a closed orbit once held) and the craft.
	func _draw_moon(m, c: Vector2, f: Font, about: Dictionary) -> void:
		var reach: float = maxf(about.r * 1.25, m.r_m * 3.2)
		var s: float = (minf(size.x, size.y) * 0.5 - 12.0) / reach
		draw_circle(c, maxf(m.r_m * s, 5.0), Color(0.62, 0.62, 0.66))
		draw_arc(c, maxf(m.r_m * s, 5.0), 0.0, TAU, 40, Color(0.9, 0.9, 0.94), 1.5, true)
		var ring: float = (m.r_m + 110000.0) * s
		for k in 24:   # the orbit to stay in, dashed
			if k % 2 == 0:
				draw_arc(c, ring, TAU * k / 24.0, TAU * (k + 1) / 24.0, 4, Color(K.C_GOLD, 0.8), 1.5, true)
		var p: Dictionary = screen.pred
		if not p.is_empty() and p.points.size() > 1:
			var line := PackedVector2Array()
			var step := maxi(1, p.points.size() / 100)
			for i in range(0, p.points.size(), step):
				var mo: Array = m.moon(p.times[i])
				var rel := Vector2(p.points[i].x - mo[0], -(p.points[i].y - mo[1]))
				if rel.length() < reach * 1.05:
					line.append(c + rel * s)
			if line.size() > 1:
				draw_polyline(line, K.C_ACCENT, 1.5, true)
		var now: Array = m.moon(m.t)
		var cp := c + Vector2(m.x - now[0], -(m.y - now[1])) * s
		draw_circle(cp, 4.0 + 1.5 * sin(_t * 5.0), K.C_GOLD)
		draw_arc(cp, 9.0, 0.0, TAU, 20, Color(K.C_GOLD, 0.5), 1.0, true)
		draw_string(f, cp + Vector2(10, -6), TranslationServer.translate("You"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, K.C_GOLD)
		draw_string(f, c + Vector2(-16, 4), TranslationServer.translate("Moon"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.08, 0.08, 0.1))
		draw_string(f, Vector2(0, size.y - 4), TranslationServer.translate("- - the orbit to stay in"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(K.C_GOLD, 0.9))
