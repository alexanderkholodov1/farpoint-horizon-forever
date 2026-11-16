extends SceneTree
## Mission 5, DART (issue #49): its rules against NASA's numbers. DART at about 6.58 km/s; a picture 2 s before the
## impact through DRACO's 0.5 arcsec pixel is about 3 cm per pixel, as the real last images [S-dart-nssdc]; the two
## asteroids split into two dots on DRACO's view hours before; a player who pulses toward the target hits Dimorphos,
## one who does nothing may not; Dimorphos's orbit 11 h 55 min before, 11 h 23 min after, 32 minutes shorter
## [S-dart-nasa-period]; the facts' sources are in docs/sources.md and every text has its Spanish.
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/dart.gd
## check: ^ok dart

var bad := 0


func fail(m: String) -> void:
	print("FAIL dart: ", m)
	bad += 1


func _initialize() -> void:
	var A = load("res://scripts/missions/dart/approach.gd").new()
	if absf(float(A.P.speed_kms) - 6.58) > 0.001:
		fail("speed %s" % A.P.speed_kms)
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
	if int(M.before_min) != 715 or int(M.after_min) != 683 or int(M.before_min) - int(M.after_min) != 32:
		fail("periods %s and %s" % [M.before_min, M.after_min])
	var d0: Array = A.dips(false)
	var d1: Array = A.dips(true)
	if absf((d0[1] - d0[0]) * 60.0 - 715.0) > 0.1 or absf((d1[1] - d1[0]) * 60.0 - 683.0) > 0.1:
		fail("dips %s / %s" % [d0, d1])
	if A.curve(d0[0], false) > A.curve(d0[0] + 3.0, false) - 0.04:
		fail("no dip in the light at %.2f h" % d0[0])
	if A.period_quality(715.0, false) < 0.99 or A.period_quality(683.0, false) > 0.0:
		fail("period quality")
	if absf(A.score(1, 1, 1, 1) - 100.0) > 0.01 or A.stars_for(100.0) != 3:
		fail("score")
	# sources and Spanish
	var md := FileAccess.get_file_as_string("res://docs/sources.md")
	for id in ["S-dart-nasa", "S-dart-nssdc", "S-dart-nasa-period"]:
		if ("- **%s**" % id) not in md:
			fail("source not listed: " + id)
	var es := {}
	for path in ["res://i18n/dart.csv", "res://i18n/story.csv"]:
		var fh := FileAccess.open(path, FileAccess.READ)
		while fh and not fh.eof_reached():
			var row := fh.get_csv_line()
			if row.size() >= 2:
				es[row[0]] = row[1]
	var texts: Array = A.D.texts.values()
	for F in A.D.facts:
		texts.append(F.text)
	var story = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/dart.json"))
	if story:
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
	print("ok dart: split %.0f s before, last picture %.1f cm/px, careful miss %.0f m, pulses %d" % [split_s, cm, A.miss(0.0).length(), A.used] if bad == 0 else "FAILED dart %d" % bad)
	quit()
