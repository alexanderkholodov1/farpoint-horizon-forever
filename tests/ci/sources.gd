extends SceneTree
## Citations check (issue #32): every source ID the code or the data cites ([S-lola], "S-horizons", [S10]) must be
## listed in docs/sources.md, so pieces built in parallel never leave a citation the judges cannot follow.
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/sources.gd
## check: ^ok sources

const ROOTS := ["res://scripts", "res://data", "res://tests", "res://tools"]
const KINDS := [".gd", ".json", ".py", ".sh"]


func _initialize() -> void:
	var listed := {}
	var rx_listed := RegEx.new()
	rx_listed.compile(r'(?m)^- \*\*(S[-0-9a-z]+)\*\*')
	for m in rx_listed.search_all(FileAccess.get_file_as_string("res://docs/sources.md")):
		listed[m.get_string(1)] = true
	var rx := RegEx.new()
	rx.compile(r'\[(S-[a-z0-9-]+|S[0-9]+)\]|"(S-[a-z0-9-]+|S[0-9]+)"')
	var missing := {}
	var cited := 0
	for root in ROOTS:
		for f in _files(root):
			for m in rx.search_all(FileAccess.get_file_as_string(f)):
				var id := m.get_string(1) if m.get_string(1) != "" else m.get_string(2)
				cited += 1
				if not listed.has(id):
					missing[id] = f
	for id in missing:
		print("NOT IN docs/sources.md: ", id, " (cited in ", missing[id], ")")
	print("sources: ", listed.size(), " listed, ", cited, " citations, ", missing.size(), " missing")
	if missing.is_empty():
		print("ok sources")
	quit(0 if missing.is_empty() else 1)


func _files(dir: String) -> Array:
	var out: Array = []
	var dirs: Array = [dir]
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(d):
			if not sub.begins_with("."):
				dirs.append(d + "/" + sub)
		for f in DirAccess.get_files_at(d):
			for k in KINDS:
				if f.ends_with(k):
					out.append(d + "/" + f)
	return out
