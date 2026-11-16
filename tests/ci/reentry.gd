extends SceneTree
## Coming home (issue #67): the re-entry's rules, played through their own steps.
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/reentry.gd
## check: ^ok reentry

const Reentry := preload("res://scripts/flight/reentry.gd")
var fails := 0


func _ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL ", what)


func _initialize() -> void:
	# the real values [S-afj13-return] [S-apollo13-return]
	var r = Reentry.new("apollo13", 1)
	_ok(absf(r.speed_mph() - 24689.3) < 1.0, "entry speed 36,211 ft/s is 24,689 mph: %f" % r.speed_mph())
	_ok(float(r.D.drogue_ft) == 24000.0 and float(r.D.main_ft) == 10000.0, "parachute heights")
	# a good pilot: steers back to the corridor's middle, calls each chute on its mark -> three stars
	var mid := (float(r.D.corridor_deg[0]) + float(r.D.corridor_deg[1])) * 0.5
	var saw_blackout := false
	for i in 4000:
		if r.phase == "plasma":
			var push := 0
			if r.angle < mid - 0.3:
				push = 1
			elif r.angle > mid + 0.3:
				push = -1
			r.step(0.02, push)
			saw_blackout = saw_blackout or r.blackout()
		elif r.phase == "chutes":
			if r.drogue_err < 0.0 and r.height_ft <= float(r.D.drogue_ft):
				r.call_chute()
			elif r.drogue_err >= 0.0 and r.main_err < 0.0 and r.height_ft <= float(r.D.main_ft):
				r.call_chute()
			r.step(0.02)
		else:
			break
	_ok(r.phase == "splash", "splashed down")
	_ok(saw_blackout, "the radio blackout happened")
	_ok(r.corridor_quality() > 0.9 and r.stars() == 3, "a good pilot gets three stars: corridor %f, stars %d" % [r.corridor_quality(), r.stars()])
	# nobody at the controls: it still comes home (never a fail screen), with fewer stars
	var r2 = Reentry.new("apollo13", 2)
	for i in 4000:
		if r2.phase == "splash":
			break
		r2.step(0.02)
	_ok(r2.phase == "splash" and r2.stars() >= 1 and r2.drogue_err >= 0.0 and r2.main_err >= 0.0, "hands off still splashes down, chutes open late: stars %d" % r2.stars())
	_ok(r2.stars() < 3, "hands off is not three stars")
	# Artemis I's way home on the same mechanic (#100): NASA's 24,581 mph [S-artemis-timeline], its own blackout
	var r3 = Reentry.new("artemis1", 3)
	_ok(absf(r3.speed_mph() - 24581.0) < 1.0, "Orion enters at 24,581 mph: %f" % r3.speed_mph())
	var black3 := false
	for i in 4000:
		if r3.phase == "splash":
			break
		r3.step(0.02)
		black3 = black3 or r3.blackout()
	_ok(r3.phase == "splash" and black3, "Orion splashes down, through its blackout")
	for k in ["blackout_note", "down_in", "sources_line", "simplified", "craft", "date"]:
		_ok(r.D.has(k) and r3.D.has(k), "both crafts bring their own " + k)
	print("ok reentry" if fails == 0 else "reentry: %d failed" % fails)
	quit(0 if fails == 0 else 1)
