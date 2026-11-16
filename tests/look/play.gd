extends Node
## A play test: the game played as a player plays it, through real input only. Mouse clicks land on the screen where
## a button is (found by its visible text) and pass through the GUI like a person's; keys are pressed and held like a
## person's. No state is set by hand, no screen is skipped, no autopilot unless a step says so. Screenshots go to
## shots/play_*.png and the buttons on screen are printed at each step, so a reader can follow and judge it.
## Run (needs a window): tools/dev/godot.sh --path . res://tests/look/play.tscn -- <part>
var g
var step := 0


func _ready() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await wait(1.5)
	var part: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "start"
	await call(part)
	get_tree().quit()


# ===================================================================================== THE PLAYER'S HANDS
func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	step += 1
	get_viewport().get_texture().get_image().save_png("%s/play_%02d_%s.png" % [dir, step, name])
	print("shot play_%02d_%s  [screen %s]" % [step, name, g.screen_id])


## Every visible button's text, for the log.
func buttons() -> PackedStringArray:
	var out := PackedStringArray()
	for b in g.find_children("*", "BaseButton", true, false):
		if b.is_visible_in_tree() and b is Button and b.text != "":
			out.append(b.text.replace("\n", " "))
	return out


## Clicks the visible button whose text contains t (the nth one when several). Returns false when none is there.
func click(t: String, nth := 0) -> bool:
	var found: Array = []
	for b in g.find_children("*", "BaseButton", true, false):
		if b.is_visible_in_tree() and b is Button and t in b.text and not b.disabled:
			found.append(b)
	if found.size() <= nth:
		print("NO BUTTON '", t, "' on ", g.screen_id, ": ", buttons())
		return false
	await click_at(found[nth].get_global_rect().get_center())
	print("click '", t, "'")
	return true


## Clicks the visible control that shows the label text t (a card): the nearest container that takes the mouse.
func click_label(t: String) -> bool:
	for l in g.find_children("*", "Label", true, false):
		if l.is_visible_in_tree() and t in l.text:
			var c: Control = l
			while c and c.mouse_filter != Control.MOUSE_FILTER_STOP:
				c = c.get_parent() as Control
			await click_at((c if c else l).get_global_rect().get_center())
			print("click card '", t, "'")
			return true
	print("NO LABEL '", t, "' on ", g.screen_id)
	return false


func click_at(p: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	get_viewport().push_input(mv)
	await get_tree().process_frame
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = p
		e.global_position = p
		get_viewport().push_input(e)
		await get_tree().process_frame
	await wait(0.4)


## Presses a key (physical), holds it `hold` seconds, releases it.
func key(code: Key, hold := 0.08) -> void:
	_key(code, true)
	await wait(hold)
	_key(code, false)
	await get_tree().process_frame


func key_down(code: Key) -> void:
	_key(code, true)


func key_up(code: Key) -> void:
	_key(code, false)


func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)


# ===================================================================================== PARTS OF THE GAME
## From the menu to the design: what a new player sees first.
func start() -> void:
	await shot("menu")
	print("buttons: ", buttons())
	await click("Play")
	await wait(0.8)
	await shot("team")
	print("buttons: ", buttons())
	await click("Solo")
	await wait(0.8)
	await shot("solo_stations")
	print("buttons: ", buttons())
	await click("Take this station", 2)          # Engineer, Scientist, Pilot, Ground control
	await wait(0.8)
	await shot("missions")
	print("buttons: ", buttons())
	var labels := []
	for l in g.find_children("*", "Label", true, false):
		if l.is_visible_in_tree() and l.text.length() < 60:
			labels.append(l.text)
	print("labels: ", labels)
	await click_label("Ice at the Moon's South Pole")
	await wait(1.0)
	await shot("design_first")
	# step by step, as a player goes: the bots do their stations' parts on the way; the pilot picks an engine to stop at
	# the Moon and fine pointing on step 6
	for k in 7:
		if k == 5:
			await click_label("Chemical (hydrazine)")
			await click_label("Wheels and star tracker")
			await shot("design_propulsion")
		await click("Next ▶")
		await wait(0.7)
	await shot("review")
	print("review buttons: ", buttons())


## The whole mission after the review: approve, launch, fly the climb by hand, the trip, the landing by hand, the
## operation and the report.
func mission() -> void:
	await start()
	await click("Approve")
	await click("LAUNCH!")
	await _climb()
	await _trip()
	await _land()
	await _operation_and_report()


## The climb by hand: hold ← or → to keep the dial's needle on the green marker, Space when STAGE lights, . for ×10.
func _climb() -> void:
	while g.screen_id != "launch":
		await wait(0.2)
	await wait(1.0)
	await shot("launch_countdown")
	var sped := false
	var held := 0
	var t0 := Time.get_ticks_msec()
	while g.screen_id == "launch" and g.screen.phase in ["countdown", "climb"]:
		var s = g.screen
		if s.phase == "climb" and s.model.lifted and not sped and s.model.h > 300.0:
			await key(KEY_PERIOD)          # time ×10, as a player does once the rocket clears the tower
			sped = true
			await shot("launch_climbing")
		if s.phase == "climb":
			var want: int = 0
			var err: float = s.model.marker - s.model.pitch
			if err > 1.0:
				want = 1
			elif err < -1.0:
				want = -1
			if want != held:
				if held == 1: key_up(KEY_RIGHT)
				if held == -1: key_up(KEY_LEFT)
				if want == 1: key_down(KEY_RIGHT)
				if want == -1: key_down(KEY_LEFT)
				held = want
			if s.hud.action.lit:
				await key(KEY_SPACE)        # STAGE, when it glows
				await shot("launch_stage")
		await get_tree().process_frame
		if Time.get_ticks_msec() - t0 > 240000:
			print("CLIMB TOO LONG"); break
	key_up(KEY_LEFT); key_up(KEY_RIGHT)
	print("climb: ", GameState.flight.get("ascent", {}))
	await shot("launch_orbit")
	while g.screen_id == "launch":
		await wait(0.2)


## The trip: wait for the plan, speed time up, BURN at the countdown, CUT at the planned speed, CORRECT, BRAKE.
func _trip() -> void:
	while g.screen_id != "flight":
		await wait(0.2)
	var s = g.screen
	while s.plan.is_empty():
		await wait(0.2)
	await wait(1.0)
	await shot("trip_plan")
	for k in 3:
		await key(KEY_PERIOD)              # ×10, ×100, ×1k
	var t0 := Time.get_ticks_msec()
	while s.phase == "plan" and not s.hud.action.lit:
		await get_tree().process_frame
	await shot("trip_countdown")
	await key(KEY_SPACE)                   # BURN
	await wait(0.3)
	print("after BURN press: phase ", s.phase)
	await key(KEY_PERIOD)                  # ×10 with the engine on
	while s.phase == "burn":
		if s.m.dv_used >= s.dv_plan - 2.0:
			await key(KEY_SPACE)           # CUT, on the gauge's mark
			break
		await get_tree().process_frame
	await wait(0.5)
	print("burn: ", GameState.flight.get("tli", {}))
	await shot("trip_cut")
	for k in 4:
		await key(KEY_PERIOD)
	while s.correction_state != "offered" and s.correction_state != "done":
		await get_tree().process_frame
	await wait(0.5)
	await shot("trip_correction")
	if s.correction_state == "offered":
		await key(KEY_SPACE)               # CORRECT
	for k in 4:
		await key(KEY_PERIOD)
	while s.phase == "coast":
		await get_tree().process_frame
	await shot("trip_arrival")
	while not s.hud.action.lit:
		await get_tree().process_frame
	await key(KEY_SPACE)                   # BRAKE
	await key(KEY_PERIOD)
	while s.phase == "capture":
		await get_tree().process_frame
	print("capture: ", GameState.flight.get("capture", {}), "  correction: ", GameState.flight.get("correction", {}))
	await shot("trip_lunar_orbit")
	while g.screen_id == "flight":
		await wait(0.2)
	print("trip took ", (Time.get_ticks_msec() - t0) / 1000, " s real")


## The landing by hand: W and S on the throttle to fall slower near the ground, the arrows to push toward the ring.
func _land() -> void:
	while g.screen_id != "landing":
		await wait(0.2)
	var s = g.screen
	await wait(1.0)
	await shot("landing_start")
	var keys_held := {}
	while g.screen_id == "landing" and s.phase == "descent":
		var m = s.model
		var alt: float = m.altitude()
		var want_vs := -clampf(0.8 + alt * 0.08, 0.9, 18.0)
		var want := {}
		if m.vel.y < want_vs - 0.4:
			want[KEY_W] = true                  # falling too fast: more throttle
		elif m.vel.y > want_vs + 0.4:
			want[KEY_S] = true
		var to := -Vector2(m.pos.x, m.pos.z)
		var v := Vector2(m.vel.x, m.vel.z)
		var goal_v := to.limit_length(clampf(to.length() * 0.05, 0.0, 10.0))
		var dvx := goal_v.x - v.x
		var dvz := goal_v.y - v.y
		if dvx > 0.5: want[KEY_RIGHT] = true
		elif dvx < -0.5: want[KEY_LEFT] = true
		if dvz < -0.5: want[KEY_UP] = true      # forward is toward -z
		elif dvz > 0.5: want[KEY_DOWN] = true
		for k in [KEY_W, KEY_S, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			var on: bool = want.has(k)
			if on != keys_held.get(k, false):
				if on: key_down(k)
				else: key_up(k)
				keys_held[k] = on
		if alt < 30.0 and not keys_held.get("shot_low", false):
			keys_held["shot_low"] = true
			await shot("landing_low")
		await get_tree().process_frame
	for k in [KEY_W, KEY_S, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		key_up(k)
	await wait(1.0)
	print("landing: ", GameState.flight.get("landing", {}))
	await shot("landing_touchdown")


func _operation_and_report() -> void:
	while g.screen_id != "operation":
		await wait(0.2)
	await wait(3.0)
	await shot("operation")
	await click("×10")
	while g.screen_id != "report":
		await wait(0.2)
	await wait(2.0)
	await shot("report")
	for l in g.find_children("*", "TextureRect", true, false):
		if l.is_visible_in_tree() and l.texture and l.get_global_rect().size.x > 150:
			await click_at(l.get_global_rect().get_center())
			break
	await wait(0.8)
	await shot("report_photo")


## The trip screen alone (the flight to the Moon), reached with the Moon mission set up, then played by real input only.
func trip() -> void:
	var t0 := Time.get_ticks_msec()
	GameState.start_solo("pilot")
	GameState.start_mission("moon_south_pole")
	GameState.mission.from_dict({"bus": "medium", "instruments": ["cam_ms", "gamma"], "panels": "dep_m", "battery": "b1k", "comms": "ka", "adcs": "st", "propulsion": "chem", "launcher": "medium", "orbit": "lunar", "years": 1, "redundancy": true, "shielding": true})
	GameState.begin_flight(GameState.mission.compute())
	GameState.last_sim.launch_failed = false
	g.go("flight")
	var s = g.screen
	while s.plan.is_empty():
		await wait(0.2)
	await wait(1.5)
	await shot("trip_plan")
	print("plan shown after ", (Time.get_ticks_msec() - t0) / 1000.0, " s; warp ", s.hud.warp, " ", s.hud.warp_note.text)
	await click("Later ▶")
	await wait(0.6)
	await shot("trip_plan_moved")
	await click("Mission control's plan")
	await click("Ready ▶")
	while not s.hud.action.lit:
		await get_tree().process_frame
	print("countdown reached after ", (Time.get_ticks_msec() - t0) / 1000.0, " s")
	await wait(2.0)
	await shot("trip_countdown")
	await key(KEY_LEFT, 0.8)                 # look around the craft
	await shot("trip_countdown_turned")
	while s.burn_start - s.m.t > 3.0:
		await get_tree().process_frame
	await key(KEY_SPACE)                     # BURN
	await wait(0.2)
	print("after BURN: phase ", s.phase)
	await wait(2.0)
	await shot("trip_burning")
	await key(KEY_M)
	await wait(0.6)
	await shot("trip_burning_map")
	await key(KEY_M)
	await key(KEY_SPACE)                     # a cut far too early: refused while the path does not reach the Moon
	await wait(0.3)
	print("early cut: phase ", s.phase, " dv ", roundi(s.m.dv_used))
	while s.phase == "burn" and s.m.dv_used < s.dv_plan - 3.0:
		await get_tree().process_frame
	await key(KEY_SPACE)                     # CUT on the mark
	await wait(0.3)
	print("cut: ", GameState.flight.get("tli", {}))
	await shot("trip_cut")
	while s.correction_state != "offered" and s.correction_state != "done":
		await get_tree().process_frame
	print("correction offered after ", (Time.get_ticks_msec() - t0) / 1000.0, " s")
	await shot("trip_correction")
	await key(KEY_SPACE)                     # CORRECT
	await wait(1.5)
	await shot("trip_coast")
	await click("Skip")                      # the computer flies the coast
	while s.phase == "coast":
		await get_tree().process_frame
	print("arrival after ", (Time.get_ticks_msec() - t0) / 1000.0, " s")
	await wait(3.0)
	await shot("trip_arrival_countdown")
	while s.phase == "capture" and not s.braking:
		await get_tree().process_frame
	await wait(1.5)
	await shot("trip_braking")
	while s.phase == "capture":
		await get_tree().process_frame
	await wait(1.0)
	await shot("trip_lunar_orbit")
	print("capture: ", GameState.flight.get("capture", {}), "  correction: ", GameState.flight.get("correction", {}))
	while g.screen_id == "flight":
		await wait(0.2)
	print("trip took ", (Time.get_ticks_msec() - t0) / 1000.0, " s real; now on ", g.screen_id)
