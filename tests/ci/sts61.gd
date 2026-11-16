extends SceneTree
## Mission 2, STS-61 (issue #46): the five spacewalks' rules played through, and their numbers against NASA's. The
## spacewalks' real lengths add up to 35 h 28 min [S-hubble-sm1]; each asks for its real parts in order; a wrong part
## or Killa's cloth costs seconds; a spacewalk whose clock runs out is tried again from its start; the data's facts
## name sources listed in docs/sources.md; every text has its Spanish in i18n/sts61.csv or i18n/story.csv.
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/sts61.gd
## check: ^ok sts61

var bad := 0


func fail(m: String) -> void:
	print("FAIL sts61: ", m)
	bad += 1


func _initialize() -> void:
	var SW = load("res://scripts/missions/sts61/spacewalks.gd")
	var A = SW.new()
	if A.total_minutes() != 35 * 60 + 28:
		fail("total %d min, NASA says 35 h 28 min" % A.total_minutes())
	var lengths: Array = A.walks().map(func(w): return int(w.minutes))
	if lengths != [474, 395, 408, 410, 441]:
		fail("lengths %s" % [lengths])
	# a clean run
	while not A.done():
		A.update(1.0)
		if A.pick(A.needed()) != "ok":
			fail("could not pick " + A.needed())
			break
		A.press("perfect")
	if A.stars() != 3:
		fail("clean run stars %d" % A.stars())
	# wrong parts, the cloth, and a spacewalk that runs out
	var B = SW.new()
	var l0: float = B.left
	if B.pick("cloth") != "cloth" or B.left >= l0:
		fail("the cloth costs nothing")
	if B.pick("costar") != "wrong":
		fail("COSTAR is not spacewalk one's first part")
	B.update(100.0)
	if not B.lost or B.pick("rsu") != "":
		fail("the clock ran out but the spacewalk goes on")
	B.retry()
	if B.lost or B.step != 0 or B.left != float(B.D.seconds_per_walk):
		fail("retry does not restart the spacewalk")
	while not B.done():
		B.pick(B.needed())
		B.press("late")
	if B.stars() != 1:
		fail("slow run stars %d" % B.stars())
	# sources and Spanish
	var md := FileAccess.get_file_as_string("res://docs/sources.md")
	var D: Dictionary = A.D
	for F in D.facts + [D.focus]:
		if ("- **%s**" % F.source) not in md:
			fail("source not listed: " + F.source)
	for f in [D.focus.before, D.focus.after]:
		if not FileAccess.file_exists(f):
			fail("no image " + f)
	var es := {}
	for path in ["res://i18n/sts61.csv", "res://i18n/story.csv"]:
		var fh := FileAccess.open(path, FileAccess.READ)
		while not fh.eof_reached():
			var row := fh.get_csv_line()
			if row.size() >= 2:
				es[row[0]] = row[1]
	var texts: Array = [D.wrong, D.cloth, D.lost, D.lost_sub, D.walk_done, D.focus.houston, D.focus.note, D.focus.win, D.focus.win_sub, D.focus.caption] + D.urgent.values()
	for P in D.parts:
		texts += [P.name, P.line]
	for Wk in D.spacewalks:
		for St in Wk.steps:
			texts.append(St.houston)
	for F in D.facts:
		texts.append(F.text)
	for t in texts:
		if not es.has(t):
			fail("no Spanish for: " + t)
	print("ok sts61 %d spacewalks, %d min, stars clean %d, slow %d" % [A.walks().size(), A.total_minutes(), A.stars(), B.stars()] if bad == 0 else "FAILED sts61 %d" % bad)
	quit()
