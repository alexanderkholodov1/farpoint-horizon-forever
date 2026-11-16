extends SceneTree
## Prueba de robustez: diseños aleatorios en todos los escenarios.
## A script started with -s is compiled before the autoloads exist, so it reaches the catalogs through the script
## (GameData keeps them in static variables).
const GD := preload("res://scripts/core/game_data.gd")

func _initialize():
	var M = load("res://scripts/core/mission.gd")
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	var n = 0
	var grades = {}
	for i in 600:
		var m = M.new()
		m.scenario = GD.SCENARIOS.keys()[rng.randi() % 5]
		m.difficulty = GD.DIFFICULTY.keys()[rng.randi() % 3]
		m.orbit = GD.ORBITS.keys()[rng.randi() % 5]
		m.bus = GD.BUSES.keys()[rng.randi() % 6]
		m.instruments = []
		for k in rng.randi() % 4:
			var id = GD.INSTRUMENTS.keys()[rng.randi() % GD.INSTRUMENTS.size()]
			if not m.instruments.has(id): m.instruments.append(id)
		m.panels = GD.PANELS.keys()[rng.randi() % 5]
		m.battery = GD.BATTERIES.keys()[rng.randi() % 5]
		m.comms = GD.COMMS.keys()[rng.randi() % 4]
		m.adcs = GD.ADCS.keys()[rng.randi() % 3]
		m.propulsion = GD.PROPULSION.keys()[rng.randi() % 4]
		m.launcher = GD.LAUNCHERS.keys()[rng.randi() % 4]
		m.years = [1,2,3,4,5,7,10][rng.randi() % 7]
		m.redundancy = rng.randf() < 0.5
		m.shielding = rng.randf() < 0.5
		var r = m.compute()
		var s = m.simulate(i)
		n += 1
		if not r.fatal:
			grades[s.score.grade] = grades.get(s.score.grade, 0) + 1
	print("ok ", n, " launchable grades ", grades)
	quit()
