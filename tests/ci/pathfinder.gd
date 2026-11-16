extends SceneTree
## Mission 3, Mars Pathfinder (issue #47): the descent flown by its rules against NASA's numbers. Rockets at 98 m and
## the cut at 21.5 m land near the real 18 m/s and bounce about 12 m up, at least 15 more times [S-mpf-nssdc]; no
## rockets, or no cut, burst the airbags (lost); the data's facts and photos name sources listed in docs/sources.md;
## every text has its Spanish in i18n/pathfinder.csv or i18n/story.csv.
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/pathfinder.gd
## check: ^ok pathfinder

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
	if hs.size() < 16 or absf(hs[0] - 12.0) > 3.0:
		fail("bounces %s" % [hs])
	if good.t < 15.0 or good.t > 40.0:
		fail("the descent from 1.6 km took %.0f s" % good.t)
	if not fly(0.0, 21.5).burst:
		fail("no rockets and the airbags survive")
	if not fly(98.0, 0.0).burst:
		fail("never cut and the airbags survive")
	if not fly(60.0, 21.5).burst:
		fail("rockets at 60 m and the airbags survive")
	var md := FileAccess.get_file_as_string("res://docs/sources.md")
	for F in good.D.facts + good.D.photos:
		if ("- **%s**" % F.source) not in md:
			fail("source not listed: " + F.source)
	for P in good.D.photos:
		if not FileAccess.file_exists(P.file):
			fail("no photo " + P.file)
	var es := {}
	for path in ["res://i18n/pathfinder.csv", "res://i18n/story.csv"]:
		var fh := FileAccess.open(path, FileAccess.READ)
		while not fh.eof_reached():
			var row := fh.get_csv_line()
			if row.size() >= 2:
				es[row[0]] = row[1]
	var texts: Array = good.D.texts.values()
	for F in good.D.facts + good.D.photos:
		texts.append(F.text if F.has("text") else F.caption)
	for t in texts:
		if not es.has(t):
			fail("no Spanish for: " + t)
	print("ok pathfinder impact %.1f m/s in %.0f s, first bounce %.1f m, %d bounces" % [good.impact, good.t, hs[0], hs.size()] if bad == 0 else "FAILED pathfinder %d" % bad)
	quit()
