extends SceneTree
## Mission 6, Artemis I (issue #50): its rules against NASA's numbers. Boosters off at 2 min 12 s, core stage at 8 min
## 03 s; the flyby burn from 2,128 to 5,102 mph about 81 miles up; re-entry at 24,581 mph, Mach 32 [S-artemis-timeline];
## 268,563 miles from Earth [S-artemis-nasa]; perfect play scores 100 and 3 stars; the far point's picture exists; the
## facts' sources are in docs/sources.md and every text has its Spanish.
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/artemis1.gd
## check: ^ok artemis1

var bad := 0


func fail(m: String) -> void:
	print("FAIL artemis1: ", m)
	bad += 1


func _initialize() -> void:
	var F = load("res://scripts/missions/artemis1/flight.gd").new()
	if int(F.L.srb_sep_s) != 132 or int(F.L.core_sep_s) != 483:
		fail("ascent times %s %s" % [F.L.srb_sep_s, F.L.core_sep_s])
	if int(F.F.before_mph) != 2128 or int(F.F.after_mph) != 5102 or int(F.F.miles_up) != 81:
		fail("flyby numbers")
	if int(F.R.speed_mph) != 24581 or int(F.R.mach) != 32 or int(F.D.far.miles) != 268563:
		fail("re-entry or far point")
	# Mach 32 at about 24,581 mph is a speed of sound near 768 mph: a sanity check on NASA's own pair
	if absf(float(F.R.speed_mph) / float(F.R.mach) - 768.0) > 15.0:
		fail("Mach and speed disagree")
	if F.call_quality(132.0, 132.0) < 0.99 or F.call_quality(140.0, 132.0) > 0.0:
		fail("call quality")
	if F.burn_quality(5102.0) < 0.99 or F.burn_quality(4800.0) > 0.0:
		fail("burn quality")
	if F.corridor_quality(-6.0) < 0.99 or F.in_corridor(-11.0) or F.in_corridor(-1.5):
		fail("corridor")
	if F.chute_quality(7.6, 7.6) < 0.99 or F.chute_quality(9.0, 7.6) > 0.0:
		fail("chutes")
	if absf(F.score(1, 1, 1) - 100.0) > 0.01 or F.stars_for(100.0) != 3 or F.stars_for(40.0) != 0:
		fail("score")
	if not FileAccess.file_exists(F.D.far.photo):
		fail("no picture " + F.D.far.photo)
	var md := FileAccess.get_file_as_string("res://docs/sources.md")
	for id in ["S-artemis-nasa", "S-artemis-timeline", "S-artemis-campos", "S-artemis-art672"]:
		if ("- **%s**" % id) not in md:
			fail("source not listed: " + id)
	var es := {}
	for path in ["res://i18n/artemis1.csv", "res://i18n/story.csv"]:
		var fh := FileAccess.open(path, FileAccess.READ)
		while fh and not fh.eof_reached():
			var row := fh.get_csv_line()
			if row.size() >= 2:
				es[row[0]] = row[1]
	var texts: Array = F.D.texts.values()
	for x in F.D.facts:
		texts.append(x.text)
		if ("- **%s**" % x.source) not in md:
			fail("source not listed: " + x.source)
	var story = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/artemis1.json"))
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
	print("ok artemis1: boosters 2:12, core 8:03, flyby 2,128 to 5,102 mph, Mach 32" if bad == 0 else "FAILED artemis1 %d" % bad)
	quit()
