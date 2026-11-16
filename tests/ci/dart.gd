extends SceneTree
## Mission 5, DART (issue #49): its rules against NASA's numbers. A picture 2 s before the
## impact through DRACO's 0.5 arcsec pixel is about 3 cm per pixel, as the real last images [S-dart-nssdc]; the two
## asteroids split into two dots on DRACO's view hours before; a player who pulses toward the target hits Dimorphos,
## one who does nothing may not; Dimorphos's orbit 11 h 55 min before, 11 h 23 min after, 32 minutes shorter
## [S-dart-nasa-period]: the dips in the light are that many minutes apart, and the period answer is judged against it.
## Sources, Spanish and references are data.gd's.
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/dart.gd
## check: ok dart

var bad := 0


func fail(m: String) -> void:
	print("FAIL dart: ", m)
	bad += 1


func _initialize() -> void:
	var A = load("res://scripts/missions/dart/approach.gd").new()
	var cm: float = A.photo_cm(-2.0)
	if absf(cm - 3.2) > 0.3:
		fail("a picture 2 s before impact is %.2f cm per pixel" % cm)
	# when the pair splits on DRACO's view
	var t := float(A.P.start_s)
	while t < 0.0 and not A.resolved(t):
		t += 10.0
	if t < -14000.0 or t > -1800.0:
		fail("the two asteroids split %.0f s before impact" % -t)
	var split_s := -t
	# a careful player: a pulse against the miss every 20 s of mission time, checked every second
	t = float(A.P.start_s)
	var next := t
	while t < 0.0:
		A.update(1.0, t)
		if t >= next and A.miss(t).length() > 8.0:
			A.pulse(-A.miss(t), t)
			next = t + 2.0
		t += 1.0
	if not A.hits(0.0) or A.miss(0.0).length() > 30.0:
		fail("the careful player misses by %.0f m (pulses %d)" % [A.miss(0.0).length(), A.used])
	var B = load("res://scripts/missions/dart/approach.gd").new()
	t = float(B.P.start_s)
	while t < 0.0:
		B.update(1.0, t)
		t += 1.0
	if B.hits(0.0):
		fail("doing nothing still hits (miss %.0f m)" % B.miss(0.0).length())
	# the orbit before and after
	var M: Dictionary = A.M
	if float(M.before_min) <= float(M.after_min):
		fail("the impact must shorten the orbit: %s then %s min" % [M.before_min, M.after_min])
	var d0: Array = A.dips(false)
	var d1: Array = A.dips(true)
	if absf((d0[1] - d0[0]) * 60.0 - float(M.before_min)) > 0.1 or absf((d1[1] - d1[0]) * 60.0 - float(M.after_min)) > 0.1:
		fail("dips %s / %s" % [d0, d1])
	if A.curve(d0[0], false) > A.curve(d0[0] + 3.0, false) - 0.04:
		fail("no dip in the light at %.2f h" % d0[0])
	if A.period_quality(float(M.before_min), false) < 0.99 or A.period_quality(float(M.after_min), false) > 0.0:
		fail("period quality")
	if absf(A.score(1, 1, 1, 1) - 100.0) > 0.01 or A.stars_for(100.0) != 3:
		fail("score")
	print("ok dart: split %.0f s before, last picture %.1f cm/px, careful miss %.0f m, pulses %d" % [split_s, cm, A.miss(0.0).length(), A.used] if bad == 0 else "FAILED dart %d" % bad)
	quit(1 if bad > 0 else 0)
