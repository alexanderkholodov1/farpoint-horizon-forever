extends SceneTree
## Mission 6, Artemis I (issue #50): its rules and one independent cross-check of NASA's numbers. NASA's re-entry speed
## and Mach number [S-artemis-timeline] agree with a speed of sound near 768 mph; each call, burn, corridor and parachute
## rule scores about 1 when played right and 0 when played wrong; perfect play scores 100 and 3 stars. The numbers themselves,
## the picture, the sources and the Spanish are data (data.gd).
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/artemis1.gd
## check: ok artemis1

var bad := 0


func fail(m: String) -> void:
	print("FAIL artemis1: ", m)
	bad += 1


func _initialize() -> void:
	var F = load("res://scripts/missions/artemis1/flight.gd").new()
	# Mach 32 at about 24,581 mph is a speed of sound near 768 mph: a sanity check on NASA's own pair
	if absf(float(F.R.speed_mph) / float(F.R.mach) - 768.0) > 15.0:
		fail("Mach and speed disagree")
	if F.call_quality(132.0, 132.0) < 0.99 or F.call_quality(140.0, 132.0) > 0.0:
		fail("call quality")
	if F.burn_quality(float(F.F.after_mph)) < 0.99 or F.burn_quality(float(F.F.after_mph) - 302.0) > 0.0:
		fail("burn quality")
	if F.corridor_quality(-6.0) < 0.99 or F.in_corridor(-11.0) or F.in_corridor(-1.5):
		fail("corridor")
	if F.chute_quality(float(F.R.drogue_km), float(F.R.drogue_km)) < 0.99 or F.chute_quality(float(F.R.drogue_km) + 1.4, float(F.R.drogue_km)) > 0.0:
		fail("chutes")
	if absf(F.score(1, 1, 1) - 100.0) > 0.01 or F.stars_for(100.0) != 3 or F.stars_for(40.0) != 0:
		fail("score")
	print("ok artemis1: Mach and speed agree, call, burn, corridor and chute rules score as designed" if bad == 0 else "FAILED artemis1 %d" % bad)
	quit(1 if bad > 0 else 0)
