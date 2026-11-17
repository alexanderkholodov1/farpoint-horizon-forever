extends SceneTree
## Mission 2, STS-61 (issue #46): the five spacewalks' rules played through, and their numbers against NASA's. The
## spacewalks' real lengths add up to 35 h 28 min [S-hubble-sm1]; each asks for its real parts in order; a wrong part
## or Killa's cloth costs seconds; a spacewalk whose clock runs out is tried again from its start. Sources, images
## and Spanish are data.gd's.
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/sts61.gd
## check: ok sts61

var bad := 0


func fail(m: String) -> void:
	print("FAIL sts61: ", m)
	bad += 1


func _initialize() -> void:
	var SW = load("res://scripts/missions/sts61/spacewalks.gd")
	var A = SW.new()
	if A.total_minutes() != 35 * 60 + 28:
		fail("total %d min, NASA says 35 h 28 min" % A.total_minutes())
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
	print("ok sts61 %d spacewalks, %d min, stars clean %d, slow %d" % [A.walks().size(), A.total_minutes(), A.stars(), B.stars()] if bad == 0 else "FAILED sts61 %d" % bad)
	quit(1 if bad > 0 else 0)
