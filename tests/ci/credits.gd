extends SceneTree
## Credits check (issue #14): the game's credits (data/credits.json, made by tools/content/credits.py) list every source of
## docs/sources.md, and nothing that is not there, so the credits never drift from the bibliography. When it fails,
## run: python tools/content/credits.py
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/credits.gd
## check: ^ok credits


func _initialize() -> void:
	var listed := {}
	var rx := RegEx.new()
	rx.compile(r'(?m)^- \*\*(S[-0-9a-z]+)\*\*')
	var md := FileAccess.get_file_as_string("res://docs/sources.md")
	# the section "Still to add" holds no sources
	for m in rx.search_all(md):
		listed[m.get_string(1)] = true
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/credits.json"))
	var shown := {}
	if data is Dictionary:
		for sec in data.get("sections", []):
			for e in sec.get("entries", []):
				shown[e.id] = true
	var missing: Array = listed.keys().filter(func(k): return not shown.has(k))
	var extra: Array = shown.keys().filter(func(k): return not listed.has(k))
	if not data is Dictionary or data.get("ai", []).is_empty() or data.get("built_with", []).is_empty():
		print("credits: data/credits.json is missing or has no AI or built-with lines; run python tools/content/credits.py")
	elif missing.is_empty() and extra.is_empty():
		print("ok credits %d sources" % shown.size())
	else:
		print("credits out of date (run python tools/content/credits.py). Missing: %s Extra: %s" % [missing, extra])
	quit()
