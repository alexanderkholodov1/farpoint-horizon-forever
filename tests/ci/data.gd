extends SceneTree
## The game's data against itself (issue #2), for every mission module (data/missions/*.json), every story chapter
## (data/story/*.json) and the chapter list: each source ID it cites is listed in docs/sources.md; each player-facing text
## has a Spanish text that is not empty and differs from the English one (unless it is in SAME, on purpose); each file it
## names exists; and every id it uses from another catalog (an orbit in a launcher or a scenario, a part in a step, an
## instrument tag in a scenario's needs, a scenario in an objective, a mission in the chapter list) exists there.
## This one file replaces the "sources listed" and "Spanish exists" blocks each mission test used to repeat.
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/data.gd
## check: ok data

## Keys whose strings are not player-facing text: identifiers, file paths, stage directions, names of people, clock
## strings. (Any string with no word of three letters, or starting with res://, is skipped as well.)
const NOT_TEXT := ["act", "after", "all", "before", "cast", "centaur_ut", "credit", "crew", "do", "doc", "file", "fx",
	"id", "inti", "intro", "killa", "map", "mission", "mood", "order", "other", "outro", "part", "photo", "play",
	"rumi", "set", "shepherd_ut", "shot", "source", "wayra", "who"]
## Paths (the keys joined with dots, list positions left out) of strings that are notes for developers, not texts.
const NOT_TEXT_PATHS := ["gauge.note"]
## Texts that read the same in English and in Spanish on purpose. Each needs its reason.
const SAME := {
	"COSTAR": "the name of Hubble's corrective optics, an acronym used as is in both languages",
}

var bad := 0
var texts_checked := 0
var sources_checked := 0
var refs_checked := 0
var listed := {}


func fail(m: String) -> void:
	print("FAIL data: ", m)
	bad += 1


func _initialize() -> void:
	preload("res://scripts/core/found.gd").load_translations()
	TranslationServer.set_locale("es")
	var rx := RegEx.new()
	rx.compile(r'(?m)^- \*\*(S[-0-9a-z]+)\*\*')
	for m in rx.search_all(FileAccess.get_file_as_string("res://docs/sources.md")):
		listed[m.get_string(1)] = true
	if listed.is_empty():
		fail("no source found in docs/sources.md")
	var files := 0
	for dir in ["res://data/missions", "res://data/story"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".json"):
				var data = _load(dir + "/" + f)
				if data != null:
					_walk(data, "", "", dir + "/" + f)
					files += 1
	if files < 12:
		fail("expected at least 12 mission and story files, found %d" % files)
	_references()
	print("ok data: %d files, %d texts with a Spanish version, %d source citations, %d references" % [files, texts_checked, sources_checked, refs_checked] if bad == 0 else "FAILED data %d" % bad)
	quit(0 if bad == 0 else 1)


## The JSON file as data; a missing or broken file is a failure, never a silent skip.
func _load(path: String):
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		fail("%s is missing or is not valid JSON" % path)
	return data


func _has_words(t: String) -> bool:
	var rx := RegEx.new()
	rx.compile("[A-Za-zÁÉÍÓÚáéíóúñ]{3,}")
	return rx.search(t) != null


func _walk(node, key: String, path: String, file: String) -> void:
	if node is Dictionary:
		for k in node:
			_walk(node[k], str(k), path + ("." if path != "" else "") + str(k), file)
	elif node is Array:
		for v in node:
			_walk(v, key, path, file)
	elif node is String:
		if key == "source":
			_source(node, file)
		elif node.begins_with("res://"):
			refs_checked += 1
			if not FileAccess.file_exists(node):
				fail("%s names a file that does not exist: %s" % [file, node])
		elif not NOT_TEXT.has(key) and not NOT_TEXT_PATHS.any(func(p): return path.ends_with(p)) and _has_words(node):
			_text(node, file)


func _source(id: String, file: String) -> void:
	sources_checked += 1
	if not listed.has(id):
		fail("%s cites %s, which docs/sources.md does not list" % [file, id])


func _text(t: String, file: String) -> void:
	texts_checked += 1
	var es := TranslationServer.translate(t)
	if es == "" or (es == t and not SAME.has(t)):
		fail("%s: no Spanish for: %s" % [file, t.left(70)])
	elif es != t and SAME.has(t):
		fail("SAME lists a text that has a Spanish version now, remove it: " + t)


## Ids that one file uses from another file's catalog.
func _references() -> void:
	var orbits: Dictionary = _entries("orbits")
	var scenarios: Dictionary = _entries("scenarios")
	var tags := {}
	for id in _entries("instruments"):
		for tag in _entries("instruments")[id].tags:
			tags[tag] = true
	for id in _entries("launchers"):
		for o in _entries("launchers")[id].cap:
			_need(orbits.has(o), "launcher %s: capacity for orbit %s, which is not in orbits.json" % [id, o])
	for id in scenarios:
		var s: Dictionary = scenarios[id]
		for o in s.orbit_mult:
			_need(orbits.has(o), "scenario %s: orbit_mult for %s, which is not in orbits.json" % [id, o])
		for o in orbits:
			_need(s.orbit_mult.has(o), "scenario %s has no orbit_mult for orbit %s" % [id, o])
		for tag in s.relevance:
			_need(tags.has(tag), "scenario %s: relevance for tag %s, which no instrument has" % [id, tag])
		for need in s.needs:
			for tag in need.any:
				_need(tags.has(tag), "scenario %s: needs tag %s, which no instrument has" % [id, tag])
	var objectives: Dictionary = _entries("objectives")
	for id in objectives:
		var sc := str(objectives[id].get("scenario", ""))
		_need(sc == "any_orbit" or scenarios.has(sc), "objective %s: scenario %s does not exist" % [id, sc])
	var chapters: Array = _load("res://data/chapters.json").chapters
	_need(not chapters.is_empty(), "the chapter list is empty")
	for c in chapters:
		for p in ["res://data/missions/%s.json", "res://data/story/%s.json"]:
			_need(FileAccess.file_exists(p % c.id), "chapter %s: %s is missing" % [c.id, p % c.id])
	# a step asks for a part its mission defines
	for f in DirAccess.get_files_at("res://data/missions"):
		var d = _load("res://data/missions/" + f)
		if d is Dictionary and d.has("parts"):
			var ids := {}
			for p in d.parts:
				ids[p.id] = true
			var used: Array = []
			_collect_parts(d, used)
			_need(not used.is_empty(), "%s has parts and no step that asks for one" % f)
			for u in used:
				_need(ids.has(u), "%s: a step asks for the part %s, which it does not define" % [f, u])


func _collect_parts(node, out: Array) -> void:
	if node is Dictionary:
		for k in node:
			if k == "steps":
				for s in node[k]:
					out.append(s.part)
			else:
				_collect_parts(node[k], out)
	elif node is Array:
		for v in node:
			_collect_parts(v, out)


func _entries(file: String) -> Dictionary:
	return _load("res://data/%s.json" % file).entries


func _need(cond: bool, what: String) -> void:
	refs_checked += 1
	if not cond:
		fail(what)
