extends SceneTree
## Mission 3, Mars Pathfinder (issue #47): the descent flown by its rules against NASA's numbers. Rockets at 98 m and
## the cut at 21.5 m land near the real 18 m/s and bounce about 12 m up, at least 15 more times [S-mpf-nssdc]; no
## rockets, or no cut, burst the airbags (lost). Sources, photos and Spanish are data.gd's.
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/pathfinder.gd
## check: ok pathfinder

var bad := 0


func fail(m: String) -> void:
	print("FAIL pathfinder: ", m)
	bad += 1


func fly(fire_at: float, cut_at: float) -> RefCounted:
	var L = load("res://scripts/missions/pathfinder/landing.gd").new()
	while not L.landed and L.t < 120.0:
		if fire_at > 0.0 and not L.fired and L.alt <= fire_at:
			L.fire()
		if cut_at > 0.0 and not L.released and L.alt <= cut_at and (L.fired or fire_at <= 0.0):
			L.cut()
		L.update(0.01, -L.swing * 2.0)
	return L


func _initialize() -> void:
	var good = fly(98.0, 21.5)
	if good.burst or absf(good.impact - 18.0) > 3.0:
		fail("the real sequence lands at %.1f m/s (burst %s)" % [good.impact, good.burst])
	if not good.airbags:
		fail("the airbags never inflated")
	var hs: Array = good.bounce_heights()
	# NASA: about 12 m up first, then at least 15 more bounces [S-mpf-nssdc]: 16 heights is the least that says so, and
	# the real count is a lower bound, so the range is not widened
	if hs.size() < 1 + 15 or absf(hs[0] - 12.0) > 3.0:
		fail("bounces %s" % [hs])
	if good.t < 15.0 or good.t > 40.0:
		fail("the descent from 1.6 km took %.0f s" % good.t)
	if not fly(0.0, 21.5).burst:
		fail("no rockets and the airbags survive")
	if not fly(98.0, 0.0).burst:
		fail("never cut and the airbags survive")
	if not fly(60.0, 21.5).burst:
		fail("rockets at 60 m and the airbags survive")
	print("ok pathfinder impact %.1f m/s in %.0f s, first bounce %.1f m, %d bounces" % [good.impact, good.t, hs[0], hs.size()] if bad == 0 else "FAILED pathfinder %d" % bad)
	quit(1 if bad > 0 else 0)
