extends SceneTree
## Mission 1, Apollo 13 (issue #45): the adapter game's rules played through. A clean run finishes with three stars
## and turns the CO2 around; a part out of order costs air and a star; at the top of the scale the air runs out (lost,
## tried again) and no part is taken any more; the data's facts name sources listed in docs/sources.md, and every text
## has its Spanish version in i18n/apollo13.csv.
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/apollo13.gd
## check: ^ok apollo13

var bad := 0


func fail(m: String) -> void:
	print("FAIL apollo13: ", m)
	bad += 1


func _initialize() -> void:
	var Adapter = load("res://scripts/missions/apollo13/adapter.gd")
	# a clean run
	var A = Adapter.new()
	var order: Array = A.steps().map(func(s): return s.part)
	if order != ["cardboard", "bag", "tape", "hose"]:
		fail("steps: %s" % [order])
	for id in order:
		A.update(1.0)
		var r: String = A.pick(id)
		if A.presses_needed() > 0 and r == "ok":
			for i in A.presses_needed():
				A.press("perfect")
		elif r != "next":
			fail("pick %s gave %s" % [id, r])
	if not A.done or A.stars() != 3:
		fail("clean run: done=%s stars=%d" % [A.done, A.stars()])
	var before: float = A.co2
	A.update(2.0)
	if A.co2 >= before:
		fail("the CO2 did not turn around")
	# mistakes and a long wait: never a fail
	var B = Adapter.new()
	var c0: float = B.co2
	if B.pick("tape") != "wrong" or B.co2 <= c0:
		fail("a part out of order costs no air")
	if B.pick("food") != "wrong":
		fail("the food packet is not a part of the adapter")
	var secs: float = B.seconds_left()
	if secs < 90.0 or secs > 130.0:
		fail("about two minutes of air: %.0f s" % secs)
	for i in 400:
		B.update(0.5)
	if B.co2 > 1.0 or not B.lost or B.pick("cardboard") != "":
		fail("top of the scale: co2=%.2f lost=%s" % [B.co2, B.lost])
	# a slow but successful run: one wrong part, late tape
	var C = Adapter.new()
	C.pick("hose")
	for id in order:
		C.update(5.0)
		if C.pick(id) == "ok":
			for i in C.presses_needed():
				C.press("late")
	if not C.done or C.stars() != 1:
		fail("slow run: done=%s stars=%d" % [C.done, C.stars()])
	# sources and Spanish
	var md := FileAccess.get_file_as_string("res://docs/sources.md")
	var D: Dictionary = A.D
	for F in D.facts + [D.photo]:
		if ("- **%s**" % F.source) not in md:
			fail("source not listed: " + F.source)
	if not FileAccess.file_exists(D.photo.file):
		fail("no photo")
	var es := {}
	var f := FileAccess.open("res://i18n/apollo13.csv", FileAccess.READ)
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 2:
			es[row[0]] = row[1]
	var texts: Array = [D.wrong, D.lost, D.lost_sub, D.win, D.win_sub, D.photo.caption] + D.urgent.values()
	for P in D.parts:
		texts += [P.name, P.line]
	for St in D.steps:
		texts += [St.houston, St.done]
	for F in D.facts:
		texts.append(F.text)
	for t in texts:
		if not es.has(t):
			fail("no Spanish for: " + t)
	print("ok apollo13 %d steps, stars clean %d, slow %d" % [order.size(), A.stars(), C.stars()] if bad == 0 else "FAILED apollo13 %d" % bad)
	quit()
