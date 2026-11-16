extends SceneTree
## Space weather (issue #90) on 400 random designs: every mission that reaches its orbit meets at least one storm
## alert; answering "keep" at a storm leaves every month before it exactly as it was (the operation simulates again from
## there); safe mode is never riskier than working through it; and how often each answer ends in damage.
## check: ok space weather
const GD := preload("res://scripts/core/game_data.gd")

func _initialize():
	var M = load("res://scripts/core/mission.gd")
	var rng = RandomNumberGenerator.new()
	rng.seed = 91
	var fails := 0
	var flown := 0
	var storms := 0
	var kinds := {}
	var dmg := {"safe": 0, "keep": 0}
	var asked := 0
	for i in 400:
		var m = M.new()
		m.scenario = GD.SCENARIOS.keys()[rng.randi() % GD.SCENARIOS.size()]
		m.difficulty = GD.DIFFICULTY.keys()[rng.randi() % 3]
		m.orbit = GD.ORBITS.keys()[rng.randi() % GD.ORBITS.size()]
		m.bus = GD.BUSES.keys()[rng.randi() % GD.BUSES.size()]
		m.instruments = []
		for k in 1 + rng.randi() % 3:
			var id = GD.INSTRUMENTS.keys()[rng.randi() % GD.INSTRUMENTS.size()]
			if not m.instruments.has(id): m.instruments.append(id)
		m.panels = GD.PANELS.keys()[rng.randi() % GD.PANELS.size()]
		m.battery = GD.BATTERIES.keys()[rng.randi() % GD.BATTERIES.size()]
		m.comms = GD.COMMS.keys()[rng.randi() % GD.COMMS.size()]
		m.adcs = GD.ADCS.keys()[rng.randi() % GD.ADCS.size()]
		m.propulsion = GD.PROPULSION.keys()[rng.randi() % GD.PROPULSION.size()]
		m.launcher = GD.LAUNCHERS.keys()[rng.randi() % GD.LAUNCHERS.size()]
		m.years = [1, 2, 3, 5, 7][rng.randi() % 5]
		m.redundancy = rng.randf() < 0.5
		m.shielding = rng.randf() < 0.5
		var s: Dictionary = m.simulate(1000 + i)
		if s.launch_failed or s.status == "lost" and s.storms.is_empty() and s.months <= 1:
			continue
		var reached_first: bool = s.months >= m.years * 4 and s.status == "ok"
		if reached_first:
			flown += 1
			if s.storms.is_empty():
				fails += 1
				print("FAIL no storm: ", m.orbit, " ", m.years, " years, seed ", 1000 + i)
		storms += s.storms.size()
		for st in s.storms:
			kinds[st.name] = kinds.get(st.name, 0) + 1
			if st.p_safe > st.p_keep:
				fails += 1
				print("FAIL safe riskier: ", st)
		if s.storms.is_empty():
			continue
		# keep at the first storm: the months before it come out the same
		var st0: Dictionary = s.storms[0]
		var k: Dictionary = m.simulate(1000 + i, {st0.month: "keep"})
		asked += 1
		var before_a: Array = s.events.filter(func(e): return e.month < st0.month)
		var before_b: Array = k.events.filter(func(e): return e.month < st0.month)
		if str(before_a) != str(before_b) or s.timeline.slice(0, st0.month - 1) != k.timeline.slice(0, st0.month - 1):
			fails += 1
			print("FAIL the months before the storm changed, seed ", 1000 + i)
		for pair in [[s, "safe"], [k, "keep"]]:
			for e in pair[0].events:
				if e.month == st0.month and e.kind == "bad" and String(e.title).begins_with("The storm") and not String(e.title).contains("upper air"):
					dmg[pair[1]] += 1
	print("missions flown past their first third: ", flown, ", storms: ", storms, ", kinds: ", kinds)
	print("first storm answered both ways: ", asked, ", damaged in safe mode: ", dmg.safe, ", working through: ", dmg.keep)
	# #99: a storm is never drawn twice in one month, and answering every one of them (as the operation does, in
	# order) never brings an earlier month back; the count per mission stays near 1 + 0.03 a month
	var Op := load("res://scripts/screens/operation.gd")
	var most := 0
	for i in 60:
		var mm = M.new()
		mm.scenario = "volcanes"
		mm.orbit = "geo"
		mm.years = 15
		mm.difficulty = "dificil"
		var ch := {}
		var sim: Dictionary = mm.simulate(500 + i, ch)
		var asked_months := []
		for guard in 40:
			var next := {}
			for stx in sim.storms:
				if not ch.has(stx.month):
					next = stx
					break
			if next.is_empty():
				break
			if asked_months.has(next.month):
				fails += 1
				print("FAIL month ", next.month, " asked twice, seed ", 500 + i)
				break
			asked_months.append(next.month)
			ch[next.month] = "keep" if asked_months.size() % 2 == 0 else "safe"
			sim = mm.simulate(500 + i, ch)
		most = maxi(most, asked_months.size())
	print("most storms in one 15-year mission: ", most, " (the player is asked ", Op.MAX_ASKS, ")")
	if Op.MAX_ASKS != 1:
		fails += 1
	if dmg.safe > dmg.keep:
		fails += 1
		print("FAIL safe mode damaged more often")
	if fails == 0:
		print("ok space weather")
	else:
		print("space weather: ", fails, " failure(s)")
	quit()
