extends SceneTree
## Crew test: the bots play every scenario from the defaults, step by step as the game does, and the result has to
## launch (nothing red) with every line readable. Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/crew.gd
## check: ^ok crew
const GD := preload("res://scripts/core/game_data.gd")


func _initialize() -> void:
	var Mission = load("res://scripts/core/mission.gd")
	var Bots = load("res://scripts/crew/bots.gd")
	var bad := 0
	for sc in GD.SCENARIOS:
		var m = Mission.new()
		m.scenario = sc
		m.bus = "cube6"
		m.panels = "body"
		m.battery = "b20"
		m.comms = "uhf"
		m.adcs = "mag"
		m.propulsion = "none"
		m.launcher = "ride"
		m.orbit = "sso"
		for step in GD.STEPS:
			if step.id == "revision":
				continue
			var res: Dictionary = Bots.act(step.id, m, {})
			m.from_dict(res.patch)
			var line: String = Bots.say(res.line)
			if "%" in line or line == "":
				print("BAD LINE ", step.id, ": ", line)
				bad += 1
		var r: Dictionary = m.compute()
		print("%-10s fatal=%s reserve=%.2f mass=%.0f/%.0f goals=%s bus=%s inst=%s orbit=%s launcher=%s" % [sc, r.fatal, r.reserve, r.mass_total, r.mass_limit, r.goals, m.bus, m.instruments, m.orbit, m.launcher])
		if r.fatal:
			bad += 1
			for c in r.checks:
				if c.level == "fatal":
					print("   RED: ", c.title)
		print("   ", Bots.say(Bots.act("lanzador", m, {}).line))
	print("ok crew" if bad == 0 else "FAILED crew %d" % bad)
	quit(0 if bad == 0 else 1)
