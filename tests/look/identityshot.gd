extends Node
## A look at the screens that carry the game's identity (development only; needs a window): the menu, the crew, the
## mission select, the design and its review, the launch. Saves to shots/id_*.png. LOOK_MODE=light shoots the light
## appearance. Run: tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/identityshot.tscn
var g

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/id_%s.png" % [dir, name])
	print("shot ", name)

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _ready() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	var look_mode := OS.get_environment("LOOK_MODE")
	if look_mode != "":
		var K := preload("res://scripts/ui/kit.gd")
		K.load_mode()
		K._apply(look_mode)
		g.root_ui.theme = K.build_theme()
		g.go("menu")
	await wait(1.2)
	await shot("1_menu")
	g.go("menu", {"settings": true})
	await wait(0.8)
	await shot("1_settings")
	g.go("team")
	await wait(0.6)
	await shot("2_team")
	g.go("team", {"view": "solo"})
	await wait(0.6)
	await shot("3_solo")
	GameState.start_solo()
	g.go("missions")
	await wait(0.8)
	await shot("4_missions")
	GameState.start_mission("volcanes")
	g.go("design", {"step": 0})
	GameState.mission.from_dict({"bus": "small", "instruments": ["ir_adv", "gas_adv", "cam_ms"], "panels": "dep_m", "battery": "b1k", "comms": "xband", "adcs": "rw", "propulsion": "cold", "launcher": "ride", "orbit": "sso", "years": 3})
	g.world.rebuild_ship()
	g.go("design", {"step": 0})
	for qi in 11:
		g.screen._show(qi)
		await wait(0.9)
		await shot("5_design_%d" % qi)
	preload("res://scripts/craft/rocket_design.gd").current = null
	g.go("builder", {"back_step": 6})
	await wait(1.2)
	await shot("8_builder_1")
	g.screen._pick("e1", "engine_merlin_x9")
	g.screen._pick("t1", "tank_37_long")
	await wait(0.8)
	await shot("8_builder_3")
	g.screen._pick("e2", "engine_merlin_vac")
	g.screen._pick("t2", "tank_37_short")
	g.screen._pick("bo", "none")
	g.screen._pick("fa", "fairing_52")
	await wait(1.0)
	await shot("8_builder_done")
	g.go("design", {"step": 6})
	await wait(0.5)
	g.launch()
	await wait(4.6)
	await shot("6_launch")
	g.go("flight")
	await wait(6.0)
	await shot("7_flight")
	get_tree().quit()
