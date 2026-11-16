extends SceneTree
## Mission 4, LCROSS (issue #48): its rules against NASA's numbers. The impact speed of about 2.5 km/s is NASA's
## 9,000 km/h [S-lcross-nssdc]; a 1 m/s burn at separation moves the impact about 35 km; the dark floor of Cabeus
## lies where its shadow is on NASA's mosaic, about half of it dark; aiming into the dark floor wins, outside it
## loses; a player who keeps the plume in the crosshair saves the readings needed. Sources, Spanish and references
## are data.gd's.
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/lcross.gd
## check: ok lcross

var bad := 0


func fail(m: String) -> void:
	print("FAIL lcross: ", m)
	bad += 1


func _initialize() -> void:
	var I = load("res://scripts/missions/lcross/impact.gd").new()
	var P: Dictionary = I.P
	if absf(float(P.speed_kms) * 3600.0 - 9000.0) > 100.0:
		fail("speed %s km/s is not NASA's 9,000 km/h" % P.speed_kms)
	if absf(I.shepherd_alt(0.0) - 641.5) > 1.0:
		fail("shepherd at %.1f km when the Centaur hits" % I.shepherd_alt(0.0))
	# one burn of 1 m/s moves the impact about 34.9 km
	var p0: Vector2 = I.point
	for k in 4:
		I.nudge(Vector2.RIGHT)
	if absf(I.point.x - p0.x - 34.88) > 0.1:
		fail("1 m/s moved %.2f km" % (I.point.x - p0.x))
	# half the crater or more is in shadow; the dark floor wins, the sunlit side and outside lose
	var dark := 0
	var tot := 0
	var best := Vector2.ZERO
	for y in range(-50, 51, 5):
		for x in range(-50, 51, 5):
			var p: Vector2 = I.cabeus + Vector2(x, y)
			if p.distance_to(I.cabeus) < I.cabeus_r:
				tot += 1
				if I.brightness(p) <= float(I.A.dark_max):
					dark += 1
					if best == Vector2.ZERO:
						best = p
	if dark < tot * 0.4:
		fail("only %d of %d points of Cabeus are dark" % [dark, tot])
	I.point = I.cabeus + Vector2(-30, 0)
	if I.verdict() != "in":
		fail("the west floor is %s (brightness %.2f)" % [I.verdict(), I.brightness(I.point)])
	I.point = I.cabeus + Vector2(35, 0)
	if I.verdict() != "sunlit":
		fail("the east floor is %s (brightness %.2f)" % [I.verdict(), I.brightness(I.point)])
	I.point = I.cabeus + Vector2(0, 80)
	if I.verdict() != "missed":
		fail("80 km off is %s" % I.verdict())
	# the plume: in the sunlight for most of the four minutes; a player on target saves enough readings
	var J = load("res://scripts/missions/lcross/impact.gd").new()
	var t := 0.0
	var lit_s := 0.0
	while t < float(P.gap_s):
		if J.lit(t) >= 0.12:
			lit_s += 0.5
		if J.flash(t) > 0.5:
			J.read(t, 0.5)
		t += 0.5
	if lit_s < 150.0:
		fail("the plume is lit only %.0f s" % lit_s)
	if J.pulses.size() < 18 or J.stars() < 3:
		fail("%d flashes; a perfect player saves %d readings, %d stars" % [J.pulses.size(), J.readings, J.stars()])
	var K = load("res://scripts/missions/lcross/impact.gd").new()
	t = 0.0
	while t < float(P.gap_s):
		K.read(t, 5.0)
		t += 0.5
	if K.readings != 0:
		fail("off target and still %d readings" % K.readings)
	# pressing all the time, on target, is worse than reading in the flashes: each miss pauses the instruments
	var M = load("res://scripts/missions/lcross/impact.gd").new()
	t = 0.0
	while t < float(P.gap_s):
		M.read(t, 0.5)
		t += 0.25
	if M.readings >= J.readings:
		fail("spamming saves %d readings, as many as reading in the flashes (%d)" % [M.readings, J.readings])
	# the five stages: the flash caught at its peak, the data sent home
	var Q = load("res://scripts/missions/lcross/impact.gd").new()
	if absf(Q.flash_quality(float(Q.D.stages.flash_peak_s)) - 1.0) > 0.01 or Q.flash_quality(3.0) > 0.0:
		fail("flash quality at the peak %.2f, late %.2f" % [Q.flash_quality(float(Q.D.stages.flash_peak_s)), Q.flash_quality(3.0)])
	Q.readings = int(Q.D.stages.ice_full)
	if absf(Q.data(Q.D.stages.instruments.size(), 1.0, 1.0) - 100.0) > 0.01 or Q.stars_for(Q.data(Q.D.stages.instruments.size(), 1.0, 1.0)) != 3:
		fail("a perfect run sends %.1f%% of the data" % Q.data(Q.D.stages.instruments.size(), 1.0, 1.0))
	if Q.data(0, 0.0, 0.0) >= float(Q.D.stages.need):
		fail("only the ice, and still enough data (%.1f%%)" % Q.data(0, 0.0, 0.0))
	print("ok lcross: Cabeus %d of %d dark, plume lit %.0f s, %d readings" % [dark, tot, lit_s, J.readings] if bad == 0 else "FAILED lcross %d" % bad)
	quit(1 if bad > 0 else 0)
