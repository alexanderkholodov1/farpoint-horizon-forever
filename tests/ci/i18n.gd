extends SceneTree
## Translation check: plays through every screen in English and in Spanish and lists every text a player can read that
## is the same in both languages, which means it has no Spanish translation (names and numbers aside).
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/i18n.gd
## It also reports the data texts of GameData and the texts of the mission checks and events found by 300 random designs.
## check: 0 texts without a Spanish version

const GD := preload("res://scripts/core/game_data.gd")
## Texts that must appear in the Spanish run and in the English run (proof that each language was really played).
const PROBES := {"en": "Choose your mission's goal", "es": "Elige el objetivo de tu misión"}
## Loaded when it runs: a script started with -s is compiled before the autoloads exist, and these use them.
var MainScene: PackedScene
var Mission: GDScript
var GS: Node

## Texts that are the same in every language on purpose.
const SAME := ["Farpoint HORIZON", "Farpoint", "HORIZON", "NASA SPACE APPS CHALLENGE 2026", "SK-Horizons", "● Ecuador", "CubeSat", "CubeSat 3U", "CubeSat 6U",
	"CubeSat 12U", "SmallSat (~200 kg)", "Ranking", "Normal", "CML 1 · Idea", "L2", "GEO", "LEO", "SSO", "English", "Español", "Ka band high gain",
	"UHF radio", "Magnetómetro", "CML 4", "SAR", "Solo", "Bot · Rivet", "Bot · Quark", "Bot · Skip", "Bot · Echo", "Bot", "%s (bot) · %s"]

var main_node: Node


func _initialize() -> void:
	MainScene = load("res://scenes/main.tscn")
	Mission = load("res://scripts/core/mission.gd")
	GS = root.get_node("GameState")
	var seen := {}                     # language -> {text: true}
	for lang in ["en", "es"]:
		GD.language = ""               # force the catalogs to be built again
		TranslationServer.set_locale(lang)
		GD.language = lang
		GD._build()
		seen[lang] = await _play()
		_mission_texts(seen[lang])
		_catalog_texts(seen[lang])
	var missing: Array = []
	for t in seen["en"]:
		if seen["es"].has(t) and _has_words(t) and not SAME.has(t) and not SAME.has(t.substr(2)):
			missing.append(t)
	# every tr("...") written in the code, so a new screen is checked without being added to _play() (#26)
	TranslationServer.set_locale("es")
	for t in _code_texts():
		if TranslationServer.translate(t) == t and _has_words(t) and not SAME.has(t) and not missing.has(t):
			missing.append(t)
	TranslationServer.set_locale("en")
	missing.sort()
	for lang in PROBES:
		print("probe ", lang, ": ", seen[lang].has(PROBES[lang]))
	print("texts seen: en ", seen["en"].size(), ", es ", seen["es"].size())
	for t in missing:
		print("UNTRANSLATED: ", t.replace("\n", "\\n"))
	print("i18n check: ", missing.size(), " texts without a Spanish version")
	quit(1 if missing.size() > 0 else 0)


## The literal texts of every tr("...") in scripts/, escapes read as GDScript reads them.
func _code_texts() -> Array:
	var out: Array = []
	var rx := RegEx.new()
	rx.compile(r'\btr\("((?:[^"\\]|\\.)*)"\)')
	var dirs: Array = ["res://scripts"]
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		for f in DirAccess.get_directories_at(d):
			dirs.append(d + "/" + f)
		for f in DirAccess.get_files_at(d):
			if not f.ends_with(".gd"):
				continue
			for m in rx.search_all(FileAccess.get_file_as_string(d + "/" + f)):
				var t := m.get_string(1).c_unescape()
				if not out.has(t):
					out.append(t)
	return out


func _has_words(t: String) -> bool:
	var rx := RegEx.new()
	rx.compile("[A-Za-zÁÉÍÓÚáéíóúñ]{3,}")
	return rx.search(t) != null


## Plays the screens in the current language and returns the texts that were on screen.
func _play() -> Dictionary:
	var texts := {}
	main_node = MainScene.instantiate()
	root.add_child(main_node)
	await process_frame
	await process_frame
	GS.start_solo()
	await _visit("menu", {}, texts)
	await _visit("team", {}, texts)
	await _visit("team", {"players": 3}, texts)
	await _visit("team", {"view": "solo"}, texts)
	await _visit("team", {"view": "online"}, texts)
	for sc in GD.SCENARIOS:
		GS.start_mission(sc)
		if sc == "volcanes":
			await _visit("missions", {}, texts)
		for i in GD.STEPS.size():
			await _visit("design", {"step": i}, texts)
	GS.team_mode = true
	GS.start_mission("luna")
	await _visit("design", {"step": 7}, texts)
	GS.team_mode = false
	GS.start_mission("volcanes")
	GS.mission.from_dict({"bus": "small", "instruments": ["ir_adv", "gas_adv"], "panels": "dep_m", "battery": "b1k", "comms": "xband", "adcs": "rw", "propulsion": "cold", "launcher": "ride", "orbit": "sso", "years": 2})
	var r: Dictionary = GS.mission.compute()
	GS.begin_flight(r)
	await _visit("launch", {}, texts)
	# the Moon's south pole: the burn toward the Moon and the landing (issue #8)
	var keep: Dictionary = GS.mission.to_dict()
	GS.start_mission("moon_south_pole")
	GS.begin_flight(GS.mission.compute())
	await _visit("flight", {}, texts)
	await _visit("landing", {}, texts)
	GS.start_mission("volcanes")
	GS.mission.from_dict(keep)
	GS.begin_flight(GS.mission.compute())
	await _visit("operation", {}, texts)
	main_node.screen.month_f = 9999.0
	main_node.screen.process(0.1)
	_collect(main_node.root_ui, texts)
	GS.last_sim.launch_failed = false
	await _visit("report", {}, texts)
	main_node.overlay("howto")
	await process_frame
	_collect(main_node.root_ui, texts)
	GS.ranking = [{"team": "T", "score": 500, "grade": "B", "scenario": "x", "difficulty": "y", "date": ""}]
	main_node.overlay("ranking")
	await process_frame
	_collect(main_node.root_ui, texts)
	main_node.queue_free()
	await process_frame
	return texts


func _visit(id: String, args: Dictionary, texts: Dictionary) -> void:
	main_node.go(id, args)
	await process_frame
	await process_frame
	_collect(main_node.root_ui, texts)


## Adds the text of every label, button, rich text and edit under node.
func _collect(node: Node, texts: Dictionary) -> void:
	for c in node.find_children("*", "Control", true, false):
		var t := ""
		if c is Label or c is Button or c is RichTextLabel:
			t = c.text
		elif c is LineEdit:
			t = c.placeholder_text
		if t != "":
			# the text as shown: the translation of the key (what Godot does itself)
			texts[c.atr(t)] = true
	for c in node.find_children("*", "Label3D", true, false):
		texts[c.atr(c.text)] = true


func _mission_texts(texts: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 300:
		var m = Mission.new()
		m.scenario = GD.SCENARIOS.keys()[rng.randi() % 5]
		m.difficulty = GD.DIFFICULTY.keys()[rng.randi() % 3]
		m.orbit = GD.ORBITS.keys()[rng.randi() % 5]
		m.bus = GD.BUSES.keys()[rng.randi() % 6]
		m.instruments = []
		for k in rng.randi() % 4:
			var id = GD.INSTRUMENTS.keys()[rng.randi() % GD.INSTRUMENTS.size()]
			if not m.instruments.has(id):
				m.instruments.append(id)
		m.panels = GD.PANELS.keys()[rng.randi() % 5]
		m.battery = GD.BATTERIES.keys()[rng.randi() % 5]
		m.comms = GD.COMMS.keys()[rng.randi() % 4]
		m.adcs = GD.ADCS.keys()[rng.randi() % 3]
		m.propulsion = GD.PROPULSION.keys()[rng.randi() % 4]
		m.launcher = GD.LAUNCHERS.keys()[rng.randi() % 4]
		m.years = [1, 2, 3, 5, 10][rng.randi() % 5]
		m.redundancy = rng.randf() < 0.5
		m.shielding = rng.randf() < 0.5
		var r: Dictionary = m.compute()
		for c in r.checks:
			texts[_shape(c.title)] = true
			texts[_shape(c.detail)] = true
		var s: Dictionary = m.simulate(i)
		for e in s.events:
			texts[_shape(e.title)] = true
			texts[_shape(e.text)] = true
		texts[s.score.label] = true
		for t in m.real_missions():
			texts[t] = true


## Digits make every message different; the numbers are cut out so the same sentence counts once.
func _shape(t: String) -> String:
	var rx := RegEx.new()
	rx.compile("[0-9][0-9.,]*")
	return rx.sub(t, "N", true)


func _catalog_texts(texts: Dictionary) -> void:
	for cat in [GD.SCENARIOS, GD.BUSES, GD.INSTRUMENTS, GD.PANELS, GD.BATTERIES, GD.COMMS, GD.ADCS, GD.PROPULSION, GD.ORBITS,
			GD.LAUNCHERS, GD.ROLES, GD.DIFFICULTY]:
		for id in cat:
			for f in ["name", "type", "desc", "real", "goal", "why", "short"]:
				if cat[id].has(f):
					texts[cat[id][f]] = true
	for s in GD.STEPS:
		texts[s.title] = true
	for k in GD.CML_NAMES:
		texts[GD.CML_NAMES[k]] = true
	for k in GD.SIZE_NAMES:
		texts[GD.SIZE_NAMES[k]] = true
