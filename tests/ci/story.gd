extends SceneTree
## Story test (issue #66): every scene of data/story/ plays through over the running game, one line at a time, with
## Enter (the first press completes a line still being written, the second goes on) and ends by itself; Esc skips a
## scene; every speaker is in the cast and has a portrait; every NASA fact names a source of docs/sources.md; every
## line and fact has its Spanish version in i18n/story.csv.
## Run: tools/dev/godot.sh --headless --path . -s res://tests/ci/story.gd
## check: ^ok story

var bad := 0


func fail(msg: String) -> void:
	print("FAIL story: ", msg)
	bad += 1


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var Cast = load("res://scripts/story/cast.gd")
	var Dialogue = load("res://scripts/story/dialogue.gd")
	var sources := FileAccess.get_file_as_string("res://docs/sources.md")
	var es := {}
	var f := FileAccess.open("res://i18n/story.csv", FileAccess.READ)
	f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 2 and row[0] != "":
			es[row[0]] = row[1]
	var played := 0
	var lines_total := 0
	for file in DirAccess.get_files_at("res://data/story"):
		if not file.ends_with(".json"):
			continue
		var chapter := file.get_basename()
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/" + file))
		for scene in data.scenes:
			var lines: Array = Dialogue.load_scene(chapter, scene)
			if lines.is_empty():
				fail("%s/%s has no lines" % [chapter, scene])
			for L in lines:
				if not L.has("who") or L.who == "narrator":
					pass
				elif not Cast.has(str(L.get("who", ""))):
					fail("%s/%s: %s is not in the cast" % [chapter, scene, L.get("who", "?")])
				elif Cast.portrait(L.who) == null:
					fail("no portrait for " + L.who)
				for k in ["text", "fact", "title", "sub"]:
					if L.has(k) and not es.has(L[k]):
						fail("no Spanish for: " + L[k])
				if L.has("fact") and ("- **%s**" % L.get("source", "?")) not in sources:
					fail("fact without a listed source: " + L.fact)
			# play it through with Enter
			var done := [false, true]
			var d = Dialogue.play(main, chapter, scene, func(skipped): done[0] = true; done[1] = skipped)
			await process_frame
			var presses := 0
			while not done[0] and presses < 200:
				var e := InputEventKey.new()
				e.pressed = true
				e.physical_keycode = KEY_ENTER
				d._input(e)
				presses += 1
				await process_frame
			if not done[0] or done[1] or presses < lines.size() or presses > lines.size() * 2:
				fail("%s/%s did not play through (%d presses for %d lines)" % [chapter, scene, presses, lines.size()])
			played += 1
			lines_total += lines.size()
	# Esc skips, and a paused scene gives the game back
	var skipped := [false]
	var d2 = Dialogue.play(main, "apollo13", "problem", func(s): skipped[0] = s, true)
	await process_frame
	if not paused:
		fail("a pausing scene did not pause the game")
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.physical_keycode = KEY_ESCAPE
	d2._input(esc)
	await process_frame
	if not skipped[0] or paused:
		fail("Esc did not skip the scene and unpause")
	if played == 0:
		fail("no scenes found")
	print("ok story %d scenes, %d lines" % [played, lines_total] if bad == 0 else "FAILED story %d" % bad)
	quit()
