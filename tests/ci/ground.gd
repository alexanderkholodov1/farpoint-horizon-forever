extends SceneTree
## Ground control (issue #9): the Deep Space Network's numbers and both mini-games, played through their own steps.
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/ground.gd
## check: ok ground

const Dsn := preload("res://scripts/minigames/dsn.gd")
const Carrier := preload("res://scripts/minigames/carrier.gd")
const Triage := preload("res://scripts/minigames/triage.gd")
const Handoff := preload("res://scripts/minigames/handoff.gd")
const Telemetry := preload("res://scripts/minigames/telemetry.gd")

var fails := 0


func _ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL ", what)


func _initialize() -> void:
	# the log titles below are the English ones: read them in English whatever the computer's language is
	TranslationServer.set_locale("en")
	# GMST at 2000 January 1, 12h UT is 18.697374558 h = 280.46 degrees [S-usno-gast]
	_ok(absf(Dsn.gmst_deg(946728000.0) - 280.4606) < 0.01, "gmst at J2000: %f" % Dsn.gmst_deg(946728000.0))
	# a sidereal day later the sky is back where it was (23 h 56 m 4 s)
	_ok(absf(Dsn.gmst_deg(946728000.0 + 86164.0905) - 280.4606) < 0.01, "gmst after a sidereal day")
	# the vernal equinox direction has ra 0, dec 0; 90 degrees of ecliptic longitude has dec +23.44
	_ok(Dsn.equatorial(0.0).length() < 0.001, "equinox")
	_ok(absf(Dsn.equatorial(90.0).y - 23.44) < 0.01, "solstice")
	# at every hour of a day some complex sees a far craft (the 120 degree rule) [S-dsn-facts]
	var seen := 0
	for h in 24:
		var b: Dictionary = Dsn.best_station(1794700800.0 + h * 3600.0, 3.0e8, 1.0e8)
		if b.up:
			seen += 1
	_ok(seen == 24, "one complex always up: %d of 24 hours" % seen)
	# the three take turns over a day
	var names := {}
	for h in 24:
		names[Dsn.best_station(1794700800.0 + h * 3600.0, 3.0e8, 1.0e8).id] = true
	_ok(names.size() == 3, "all three complexes take turns")
	# the Moon is about 1.28 s away [S-jpl-lighttime]; going away lowers the tone
	_ok(absf(Dsn.light_s(3.844e8) - 1.282) < 0.01, "light time to the Moon")
	_ok(Dsn.doppler_hz(5000.0) < 0.0 and absf(Dsn.doppler_hz(5000.0) + 140096.0) < 10.0, "doppler at 5 km/s away")

	# Find the carrier: click the line at each filter, narrow down, hold
	var f0 := -123456.0
	var c = Carrier.new()
	c.setup({"name": "Madrid", "place": "Spain", "elev": 40.0}, func() -> float: return f0, 0.2, 4400.0)
	for i in 3:
		c.set_band(i)
		c.tune(f0 + 100.0)
		c.step(0.1)
	_ok(c.inside(), "tuned inside the narrowest filter")
	var got := {}
	c.done.connect(func(r): got.merge(r))
	for i in 20:
		c.step(0.1)
	_ok(got.get("by", "") == "player" and int(got.get("bonus", 0)) >= Carrier.BONUS_MIN, "carrier locked by the player: %s" % str(got))
	# far off, it never locks
	var c2 = Carrier.new()
	c2.setup({"name": "Goldstone", "place": "California", "elev": 20.0}, func() -> float: return f0, 0.2, 4400.0)
	c2.set_band(2)
	c2.tune(0.0)
	for i in 30:
		c2.step(0.1)
	_ok(not c2.locked, "no lock when tuned off the tone")
	c.free()
	c2.free()

	# The 1202: shed the radar's jobs, keep the landing's, call go
	var g = Triage.new()
	g.setup({"code": "1202"})
	var res := {}
	g.done.connect(func(r): res.merge(r))
	g.add_job("guide")
	g.click(0)
	_ok(g.tray.size() == 1 and g.slips == 1, "a landing job is kept")
	g.tray = ["guide"]
	g.ages = [0.0]
	for i in Triage.SHED_FOR_GO:
		g.add_job("radar")
		g.click(g.tray.size() - 1)
	_ok(g.shed == Triage.SHED_FOR_GO, "radar jobs shed")
	g.call_go()
	_ok(res.get("go", false) and res.get("by", "") == "player" and int(res.bonus) > 0, "go called by the player: %s" % str(res))
	# a full tray restarts and keeps only the landing's jobs
	var g2 = Triage.new()
	g2.setup({"code": "1202"})
	for k in ["radar", "guide", "radar", "radar", "throttle"]:
		g2.add_job(k)
	_ok(g2.restarts == 1 and g2.tray == ["guide", "throttle"], "restart keeps the landing: %s" % str(g2.tray))
	# left alone, ground still calls go in time
	var g3 = Triage.new()
	g3.setup({"code": "1202"})
	var r3 := {}
	g3.done.connect(func(r): r3.merge(r))
	for i in 220:
		g3.step(0.1)
	_ok(r3.get("go", false), "go called in time when nobody plays")
	for n in [g, g2, g3]:
		n.free()

	# Hand it over (#63): over one turn of the Earth a player who hands over each setting dish to a risen one makes
	# three clean handoffs, wherever the craft is: the Moon at several dates, and L2
	var Desk := load("res://scripts/minigames/desk.gd")
	var skies := [["lunar", 0.0], ["lunar", 5.0 * 86400.0], ["lunar", 11.0 * 86400.0], ["l2", 0.0], ["l2", 120.0 * 86400.0]]
	for sk in skies:
		var sky: Vector2 = Desk.sky_of(sk[0], sk[1])
		var h = Handoff.new()
		h.setup(sky, Desk.UNIX_DAY0 + sk[1], "the Moon")
		var hr := {}
		h.done.connect(func(r): hr.merge(r))
		var early := false
		for i in 1200:
			h.step(0.05)
			if hr.size() > 0:
				break
			if h.holder >= 0 and not h.is_setting(h.holder) and not early:
				for k in 3:
					if k != h.holder and h.is_up(k):
						early = true
						_ok(not h.hand_to(k), "an early handoff is refused (%s)" % str(sk))
						break
			if h.holder >= 0 and h.is_setting(h.holder):
				var best := -1
				for k in 3:
					if k != h.holder and h.is_up(k) and (best < 0 or h.elev[k] > h.elev[best]):
						best = k
				if best >= 0:
					h.hand_to(best)
		_ok(hr.get("by", "") == "player" and int(hr.clean) == Handoff.HANDOFFS and int(hr.bonus) > 0,
			"three clean handoffs at %s: %s" % [str(sk), str(hr)])
		_ok(float(hr.get("secs", 99)) <= Handoff.DAY_REAL_S * 1.5, "within about one turn of the Earth at %s" % str(sk))
		h.free()
	# a player who never hands over loses contact; picking it up again still counts, for less
	var h2 = Handoff.new()
	h2.setup(Desk.sky_of("lunar", 0.0), Desk.UNIX_DAY0, "the Moon")
	var lost := false
	for i in 1200:
		h2.step(0.05)
		if h2.holder < 0:
			lost = true
			break
	_ok(lost, "contact lost when nobody hands over")
	var up := -1
	for i in 1200:
		for k in 3:
			if h2.is_up(k):
				up = k
		if up >= 0:
			break
		h2.step(0.05)
	_ok(up >= 0 and h2.hand_to(up) and h2.late == 1, "a gap picked up again counts as late")
	h2.free()
	# left alone, Wayra takes it
	var h3 = Handoff.new()
	h3.setup(Desk.sky_of("lunar", 0.0), Desk.UNIX_DAY0, "the Moon")
	var r3h := {}
	h3.done.connect(func(r): r3h.merge(r))
	for i in 100:
		h3.step(1.0)
	_ok(r3h.get("by", "") == "bot", "Wayra hands it over when nobody plays")
	h3.free()

	# Read the squiggles (#63): every case is found from its log titles, and a fix after two slips pays less than the full bonus
	var chans: Dictionary = Telemetry.channels()
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(Telemetry.DATA)).cases
	_ok(not Telemetry.fallback().is_empty(), "a fallback case")
	for cs in cases:
		_ok(cs.fixes.size() == 3 and cs.channels.has(cs.bad) and cs.channels.size() == 4, "case %s is well formed" % cs.id)
		for ch in cs.channels:
			_ok(chans.has(ch), "channel %s of %s exists" % [ch, cs.id])
		for m in cs.match:
			var title: String = str(m).replace("%s", "G4 (severe)")
			_ok(Telemetry.case_for(title).get("id", "") == cs.id, "'%s' opens %s" % [title, cs.id])
		var tg = Telemetry.new()
		tg.setup(cs, chans, "x", 7)
		var tr_res := {}
		tg.done.connect(func(r): tr_res.merge(r))
		for i in 30:
			tg.step(0.1)
		var wrong: int = (tg.bad + 1) % 4
		_ok(not tg.pick_channel(wrong) and tg.stage == "find", "a normal channel is not the trouble (%s)" % cs.id)
		_ok(tg.pick_channel(tg.bad) and tg.stage == "fix", "the bad channel found (%s)" % cs.id)
		_ok(not tg.pick_fix(1), "a wrong fix does nothing (%s)" % cs.id)
		_ok(tg.pick_fix(0) and tr_res.get("by", "") == "player" and int(tr_res.bonus) > 0 and int(tr_res.bonus) < Telemetry.BONUS_MAX,
			"fixed with two slips (%s): %s" % [cs.id, str(tr_res)])
		tg.free()
	_ok(Telemetry.case_for("Liftoff").is_empty(), "good news opens nothing")

	print("ok ground" if fails == 0 else "ground: %d failed" % fails)
	quit(0 if fails == 0 else 1)
