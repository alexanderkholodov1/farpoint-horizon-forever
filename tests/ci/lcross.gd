extends SceneTree
## Mission 4, LCROSS (issue #48): its rules against NASA's numbers. The two impacts 256.6 s apart (11:31:19.5 and
## 11:35:36.1 UT) at about 2.5 km/s [S-lcross-nssdc]; a 1 m/s burn at separation moves the impact about 35 km; Cabeus
## lands on NASA's mosaic where its shadow is, half of it dark; aiming into the dark floor wins, outside it loses; a
## player who keeps the plume in the crosshair saves the readings needed; the facts' sources are listed in
## docs/sources.md and every text has its Spanish in i18n/lcross.csv.
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/lcross.gd
## check: ^ok lcross

var bad := 0


func fail(m: String) -> void:
	print("FAIL lcross: ", m)
	bad += 1


func _initialize() -> void:
	var I = load("res://scripts/missions/lcross/impact.gd").new()
	var P: Dictionary = I.P
	if absf(float(P.gap_s) - 256.6) > 0.05:
		fail("gap %s" % P.gap_s)
	if I.ut(0.0) != "11:31:19.5 UT" or I.ut(float(P.gap_s)) != "11:35:36.1 UT":
		fail("times %s %s" % [I.ut(0.0), I.ut(float(P.gap_s))])
	if absf(float(P.speed_kms) * 3600.0 - 9000.0) > 100.0:
		fail("speed %s km/s is not NASA's 9,000 km/h" % P.speed_kms)
	if absf(I.shepherd_alt(0.0) - 641.5) > 1.0:
		fail("shepherd at %.1f km when the Centaur hits" % I.shepherd_alt(0.0))
	# Cabeus on the map: about 357, 343 px, 75 px across its radius
	var c: Vector2 = I.km_to_px(I.cabeus)
	if c.distance_to(Vector2(357.6, 342.6)) > 1.5 or absf(I.cabeus_r / I.km_px - 75.4) > 1.0:
		fail("Cabeus at %s px, radius %.1f px" % [c, I.cabeus_r / I.km_px])
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
	# the five stages: six real instruments, the flash caught at its peak, the data sent home
	var Q = load("res://scripts/missions/lcross/impact.gd").new()
	if Q.D.stages.instruments.size() != 6 or int(Q.D.stages.crater_m) != 20:
		fail("instruments %d, crater %s m" % [Q.D.stages.instruments.size(), Q.D.stages.crater_m])
	if absf(Q.flash_quality(float(Q.D.stages.flash_peak_s)) - 1.0) > 0.01 or Q.flash_quality(3.0) > 0.0:
		fail("flash quality at the peak %.2f, late %.2f" % [Q.flash_quality(float(Q.D.stages.flash_peak_s)), Q.flash_quality(3.0)])
	Q.readings = int(Q.D.stages.ice_full)
	if absf(Q.data(6, 1.0, 1.0) - 100.0) > 0.01 or Q.stars_for(Q.data(6, 1.0, 1.0)) != 3:
		fail("a perfect run sends %.1f%% of the data" % Q.data(6, 1.0, 1.0))
	if Q.data(0, 0.0, 0.0) >= float(Q.D.stages.need):
		fail("only the ice, and still enough data (%.1f%%)" % Q.data(0, 0.0, 0.0))
	# sources and Spanish
	var md := FileAccess.get_file_as_string("res://docs/sources.md")
	for id in ["S-lcross-nasa", "S-lcross-nssdc", "S-cabeus-gazetteer", "S-lroc-wac", "S-nssdc-planets"]:
		if ("- **%s**" % id) not in md:
			fail("source not listed: " + id)
	for F in I.D.facts:
		if ("- **%s**" % F.source) not in md:
			fail("source not listed: " + F.source)
	var es := {}
	for path in ["res://i18n/lcross.csv", "res://i18n/story.csv"]:
		var fh := FileAccess.open(path, FileAccess.READ)
		while fh and not fh.eof_reached():
			var row := fh.get_csv_line()
			if row.size() >= 2:
				es[row[0]] = row[1]
	var texts: Array = I.D.texts.values()
	for F in I.D.facts:
		texts.append(F.text)
	var story = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/lcross.json"))
	for sc in story.scenes:
		for L in story.scenes[sc]:
			for k in ["text", "title", "sub", "fact"]:
				if L.has(k):
					texts.append(L[k])
			if L.has("source") and ("- **%s**" % L.source) not in md:
				fail("source not listed: " + L.source)
	for s in texts:
		if not es.has(s):
			fail("no Spanish for: " + s)
	print("ok lcross: Cabeus %d of %d dark, plume lit %.0f s, %d readings" % [dark, tot, lit_s, J.readings] if bad == 0 else "FAILED lcross %d" % bad)
	quit()
