extends Node
## Every screen at the window size the harness is run with, measured instead of judged by eye: each panel on screen
## (a PanelContainer not inside another one) must not cover another panel nor leave the screen. Prints every overlap
## and saves shots/ov_<tag>_<screen>.png. A phone's browser bar leaves less height than the screen has, so run it at
## the heights a phone really shows (FIT_CSS_H), e.g.:
##   FIT_CSS_H=340 tools/godot.sh --path . --resolution 1240x500 res://tests/overlapshot.tscn -- phone340
## check-free: development harness, not part of tools/check.sh.
var g
var tag := "dev"
var total := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(200.0).timeout.connect(func(): print("overlapshot: timed out"); get_tree().quit())
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		tag = a[0]
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await _wait(1.5)
	print(tag, " visible ", get_viewport().get_visible_rect().size)
	await _check("menu")
	g.go("missions")
	await _wait(0.8)
	await _check("missions")
	GameState.start_solo()
	GameState.start_mission("volcanes")
	GameState.mission.from_dict({"bus": "small", "instruments": ["ir_adv", "gas_adv", "cam_ms"], "panels": "dep_m", "battery": "b1k", "comms": "xband", "adcs": "rw", "propulsion": "cold", "launcher": "medium", "orbit": "sso", "years": 3})
	for st in [0, 1, 2, 3, 5, 7]:
		g.go("design", {"step": st})
		await _wait(0.7)
		await _check("design%d" % st)
	g.go("builder", {"back_step": 7})
	await _wait(1.2)
	await _check("builder")
	GameState.begin_flight(GameState.mission.compute(), 7)
	GameState.last_sim.launch_failed = false
	g.go("launch")
	await _wait(3.0)
	await _check("launch")
	await _wait(5.0)
	await _check("launch_climb")
	g.go("operation")
	await _wait(0.6)
	g.screen._set_speed(2)
	var t := 0.0
	while not is_instance_valid(g.screen.alert) and t < 30.0:
		await _wait(0.25)
		t += 0.25
	await _check("storm")
	if is_instance_valid(g.screen.alert):
		g.screen._answer("keep")
	g.screen._set_speed(0)
	await _wait(1.0)
	await _check("operation")
	g.go("report")
	await _wait(1.0)
	g.screen._end_intro()
	await _wait(0.8)
	await _check("report")
	GameState.start_mission("moon_south_pole")
	GameState.begin_flight(GameState.mission.compute(), 7)
	g.go("flight")
	await _wait(6.0)
	await _check("trip")
	g.go("landing")
	await _wait(3.0)
	await _check("landing")
	g.go("menu")
	await _wait(0.8)
	g.overlay("howto")
	await _wait(0.6)
	await _check("howto")
	g.go("menu", {"settings": true})
	await _wait(0.8)
	await _check("settings")
	g.overlay("credits")
	await _wait(0.8)
	await _check("credits")
	g.go("design", {"step": 0})
	await _wait(0.8)
	g.overlay("pause")
	await _wait(0.5)
	await _check("pause")
	get_tree().paused = false
	print("overlapshot %s: %d overlap(s)" % [tag, total])
	get_tree().quit()


## The top-level panels on screen: visible PanelContainers with no PanelContainer above them. An overlay card (with
## its shade) is checked against the screen's edges only, since it is meant to cover the screen.
func _panels() -> Array:
	var out: Array = []
	for n in g.find_children("*", "PanelContainer", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or c.size.x < 4.0 or c.size.y < 4.0:
			continue
		var p := c.get_parent()
		var nested := false
		while p and p != g:
			if p is PanelContainer:
				nested = true
				break
			p = p.get_parent()
		if not nested:
			out.append(c)
	return out


func _check(name: String) -> void:
	await _wait(0.5)
	await RenderingServer.frame_post_draw
	var view := get_viewport().get_visible_rect()
	var ps := _panels()
	var found := 0
	for i in ps.size():
		var a: Rect2 = ps[i].get_global_rect()
		if not view.grow(1.0).encloses(a) and not _in_scroll(ps[i]):
			found += 1
			print("  %s: OFF SCREEN %s %s (screen %s)" % [name, _who(ps[i]), a, view.size])
		if _is_card(ps[i]):
			continue   # a card over a shade covers the screen on purpose: only its edges are checked
		for j in range(i + 1, ps.size()):
			if _is_card(ps[j]) or _in_scroll(ps[i]) or _in_scroll(ps[j]):
				continue
			var b: Rect2 = ps[j].get_global_rect()
			var x := a.intersection(b)
			if x.size.x > 3.0 and x.size.y > 3.0:
				found += 1
				print("  %s: OVERLAP %s and %s by %dx%d" % [name, _who(ps[i]), _who(ps[j]), x.size.x, x.size.y])
	total += found
	print("%s: %d panels, %d problem(s)" % [name, ps.size(), found])
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/ov_%s_%s.png" % [dir, tag, name])


## A card shown over a full-screen shade (pause, How to play, the space weather alert, a photo).
func _is_card(c: Control) -> bool:
	var p := c.get_parent()
	return p is ColorRect and (p as ColorRect).anchor_right == 1.0 and (p as ColorRect).anchor_bottom == 1.0


## Inside a scroll list: it may run past the screen's edge, the list scrolls.
func _in_scroll(c: Control) -> bool:
	var p := c.get_parent()
	while p and p != g:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


## A short name for a panel: the first text found inside it.
func _who(c: Control) -> String:
	for l in c.find_children("*", "Label", true, false):
		var s: String = (l as Label).text.strip_edges()
		if s != "":
			return "[" + s.substr(0, 24) + "]"
	for b in c.find_children("*", "Button", true, false):
		var s2: String = (b as Button).text.strip_edges()
		if s2 != "":
			return "[" + s2.substr(0, 24) + "]"
	return "[" + c.name + "]"


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
