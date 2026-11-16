extends "res://scripts/screens/screen.gd"
## Report, as a celebration (issue #11): the grade and score of the last flight (GameState.last_sim, last_report),
## the photos the mission sent home (real NASA images, scripts/flight/photos.gd; an extra objective's photo only when it
## was met, the others locked with what to do to bring them home), the extra objectives met and their bonus (it adds
## to the score; missing one never takes anything away), what happened and why, the real missions like it, and the
## ways on: redesign, fly again, a new mission, save to the ranking. Behind it, the craft where it is: the lander on
## the ground after a landing (scripts/flight/surface.gd), the orbit otherwise, the Earth after a lost launch.

const Photos := preload("res://scripts/flight/photos.gd")
const Objectives := preload("res://scripts/flight/objectives.gd")
const Surface := preload("res://scripts/flight/surface.gd")
const FlightData := preload("res://scripts/flight/flight_data.gd")
const Horizon := preload("res://scripts/ui/horizon.gd")

var surface                    ## scripts/flight/surface.gd behind a landed mission's report
var bonus := 0
var panel: PanelContainer      ## the report itself, shown once the celebration is over
var intro: Control             ## the celebration over the scene: the title, the grade, the points rolling up
var intro_t := 0.0
var counted := 0.0
var total_pts := 0
var pts_lbl: Label
var photo_layer: Control       ## a photo shown large (Esc closes it before anything else)
var first_btn: Button          ## the report's main action, focused once the celebration is over
## Where each problem of the design is fixed (scripts/core/mission.gd checks' "at"), as the design's stage names.
const FIX_AT := {"instruments": "Craft", "bus": "Craft", "panels": "Power", "battery": "Power", "comms": "Systems",
	"adcs": "Systems", "propulsion": "Systems", "launcher": "Rocket", "orbit": "Mission"}


func enter(_args: Dictionary) -> void:
	var last_sim: Dictionary = GameState.last_sim
	var flight: Dictionary = GameState.flight
	var landing: Dictionary = flight.get("landing", {})
	if not last_sim.launch_failed:
		preload("res://scripts/core/progress.gd").done(mission.scenario)   # a mission flown opens the next one
	if last_sim.launch_failed:
		world.stage_earth()
	elif bool(landing.get("landed", false)) and FlightData.has_landing(mission.scenario):
		Surface.note_landing(mission, landing)
		surface = Surface.new()
		surface.build(world, mission, landing)
		surface.cam_dist = 11.0
	elif world.stage == null or world.orbit_ship == null:
		world.stage_orbit()
	# a mission with no landing settles its extra goals here, once its months of work are known
	if not flight.has("extras") and not mission.extras.is_empty() and not last_sim.launch_failed:
		GameState.settle_extras()
		last_sim = GameState.last_sim
	bonus = int(flight.get("bonus", 0))
	var s: Dictionary = last_sim.score
	if not flight.get("ranked", false):   # each flight enters the ranking once (issue #52), whatever happens after
		flight["ranked"] = true
		GameState.add_ranking(_crew_name(), int(s.total) + bonus, str(s.grade))
	var r: Dictionary = GameState.last_report
	var S: Dictionary = GameData.SCENARIOS[mission.scenario]
	var p := Kit.panel_box(Kit.PAD)
	if Kit.compact:
		Kit.place(p, 0, 0, 1, 1, Kit.MARGIN, Kit.MARGIN, -Kit.MARGIN, -Kit.MARGIN)
	else:
		Kit.place(p, 0.5, 0, 0.5, 1, -660, Kit.MARGIN, 660, -Kit.MARGIN)
	add_child(p)
	panel = p
	p.modulate.a = 0.0
	var outer := Kit.vbox(Kit.GAP)
	p.add_child(outer)
	_header(outer, s, r, S, last_sim)
	var cols := Kit.hbox(26)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(cols)
	_score_column(cols, s, r, S, last_sim)
	_photo_column(cols, flight, last_sim)
	_story_column(cols, last_sim)
	outer.add_child(Kit.rule())
	_actions(outer, s)
	_celebrate(s, last_sim)


func exit() -> void:
	if surface:
		surface.restore()


func process(delta: float) -> void:
	if surface:
		surface.camera(delta)
	if intro and is_instance_valid(intro):
		intro_t += delta
		# the points roll up, a tick every few, then hold
		var target: float = float(total_pts)
		var before := int(counted)
		counted = minf(target, counted + maxf(target, 1.0) * delta / 1.3) if intro_t > 0.9 else 0.0
		if int(counted) / 25 != before / 25:
			Kit.UiSound.play("tick", 0.0)
		pts_lbl.text = tr("%d points") % int(counted)
		if intro_t > 4.6:
			_end_intro()


## Any key or click ends the celebration early. Then (issue #58): Enter redesigns, R flies again, N picks a new mission,
## Esc or Backspace go to the menu; Esc first closes a photo shown large.
func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if intro and is_instance_valid(intro):
		if intro_t > 0.6:
			_end_intro()
		get_viewport().set_input_as_handled()
		return
	var k: int = e.physical_keycode
	if photo_layer and is_instance_valid(photo_layer):
		if k in [KEY_ESCAPE, KEY_BACKSPACE, KEY_ENTER, KEY_KP_ENTER]:
			photo_layer.queue_free()
			get_viewport().set_input_as_handled()
		return
	match k:
		KEY_ENTER, KEY_KP_ENTER:
			_back_to_design()
		KEY_R:
			_fly_again()
		KEY_N:
			go("missions")
		KEY_ESCAPE, KEY_BACKSPACE:
			go("menu")
		_:
			return
	get_viewport().set_input_as_handled()


# ===================================================================================== THE CELEBRATION
## The moment the mission ends, before the details: the scene behind, a big title, the grade landing, the points
## rolling up, a burst of the brand's colours and a fanfare. A lost mission gets a calm version, never a failure screen.
func _celebrate(s: Dictionary, last_sim: Dictionary) -> void:
	var lost: bool = last_sim.launch_failed or last_sim.status == "lost"
	total_pts = s.total + bonus
	intro = Control.new()
	intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro.mouse_filter = Control.MOUSE_FILTER_STOP   # the click that ends it must not reach the report under it
	intro.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and intro_t > 0.6:
			_end_intro())
	add_child(intro)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.04, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro.add_child(shade)
	var gcol0: Color = {"S": Color(1.0, 0.85, 0.3), "A": Kit.C_OK, "B": Kit.C_ACCENT, "C": Kit.C_WARN, "D": Kit.C_BAD}[s.grade]
	# a warm sunrise glow and a glow of the grade's colour, both swelling in from the centre
	for spec in [[Kit.C_GOLD, 0.5, Vector2(0.5, 0.62)], [gcol0, 0.6, Vector2(0.5, 0.45)]]:
		var gt := GradientTexture2D.new()
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 256
		gt.height = 256
		var gr := Gradient.new()
		gr.set_color(0, Color(spec[0], spec[1]))
		gr.set_color(1, Color(spec[0], 0.0))
		gt.gradient = gr
		var glow := TextureRect.new()
		glow.texture = gt
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_SCALE
		glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		glow.anchor_left = spec[2].x - 0.42
		glow.anchor_right = spec[2].x + 0.42
		glow.anchor_top = spec[2].y - 0.5
		glow.anchor_bottom = spec[2].y + 0.5
		glow.offset_left = 0
		glow.offset_right = 0
		glow.offset_top = 0
		glow.offset_bottom = 0
		glow.modulate.a = 0.0
		intro.add_child(glow)
		glow.create_tween().tween_property(glow, "modulate:a", 1.0, 1.2).set_delay(0.5)
	# the brand's horizon arc sweeps across, lit from the left like a sunrise
	var arc := Horizon.new()
	arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arc.thickness = 4.0
	arc.progress = 0.0
	arc.anchor_left = 0.1
	arc.anchor_right = 0.9
	arc.anchor_top = 0.2
	arc.anchor_bottom = 0.27
	intro.add_child(arc)
	arc.create_tween().tween_property(arc, "progress", 1.0, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var v := Kit.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro.add_child(v)
	var title_txt: String = tr("MISSION OVER") if lost else (tr("MISSION COMPLETE!") if s.grade in ["S", "A"] else tr("MISSION DONE!"))
	var t := Kit.legible(Kit.lbl(title_txt, Kit.T_SHOUT + 8, Color(1.0, 0.78, 0.42), Kit.FONT_T))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := Kit.legible(Kit.lbl(GameData.SCENARIOS[mission.scenario].name + "  ·  " + str(s.label), Kit.T_VALUE, Kit.C_ON_DARK, Kit.FONT_B), 1.3)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var gcol: Color = {"S": Color(1.0, 0.85, 0.3), "A": Kit.C_OK, "B": Kit.C_ACCENT, "C": Kit.C_WARN, "D": Kit.C_BAD}[s.grade]
	var g := Kit.legible(Kit.lbl(s.grade, 150, Kit.ink(gcol), Kit.FONT_T), 0.7)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(g)
	pts_lbl = Kit.legible(Kit.lbl(tr("%d points") % 0, Kit.T_CLOCK, Color(0.62, 0.82, 1.0), Kit.font_num()))
	pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pts_lbl)
	var skip := Kit.legible(Kit.lbl(tr("Click or press any key for your report"), Kit.T_BODY, Kit.C_ON_DARK, Kit.FONT_R), 1.3)
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip.modulate.a = 0.0
	v.add_child(skip)
	# the entrances: the title drops in, the grade lands with a bounce, the hint comes last
	t.modulate.a = 0.0
	g.modulate.a = 0.0
	var tw := intro.create_tween()
	tw.tween_property(t, "modulate:a", 1.0, 0.35)
	tw.tween_interval(0.25)
	tw.tween_callback(func():
		g.pivot_offset = g.size * 0.5
		g.scale = Vector2(2.6, 2.6)
		var gt := g.create_tween().set_parallel(true)
		gt.tween_property(g, "modulate:a", 1.0, 0.25)
		gt.tween_property(g, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Kit.UiSound.play("fanfare" if not lost else "notify", 0.0)
		if not lost:
			_burst(gcol))
	tw.tween_interval(2.0)
	tw.tween_property(skip, "modulate:a", 0.8, 0.4)


## A burst of small bright bits from the centre in the brand's blue and amber and the grade's colour.
func _burst(col: Color) -> void:
	for c in [Kit.C_GOLD, Kit.C_ACCENT, col, Color(1.0, 0.86, 0.62), Color(0.35, 0.55, 1.0)]:
		var p := CPUParticles2D.new()
		p.position = get_viewport_rect().size * Vector2(0.5, 0.42)
		p.amount = 70
		p.one_shot = true
		p.explosiveness = 0.92
		p.lifetime = 2.4
		p.direction = Vector2(0, -1)
		p.spread = 180.0
		p.initial_velocity_min = 220.0
		p.initial_velocity_max = 620.0
		p.gravity = Vector2(0, 420)
		p.damping_min = 40.0
		p.damping_max = 90.0
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
		p.scale_amount_min = 3.0
		p.scale_amount_max = 7.0
		p.color = c
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 1))
		fade.set_color(1, Color(1, 1, 1, 0))
		p.color_ramp = fade
		intro.add_child(p)
		p.emitting = true


func _end_intro() -> void:
	if intro == null or not is_instance_valid(intro):
		return
	var it := intro
	intro = null
	var tw := create_tween().set_parallel(true)
	tw.tween_property(it, "modulate:a", 0.0, 0.35)
	tw.tween_property(panel, "modulate:a", 1.0, 0.45)
	tw.chain().tween_callback(it.queue_free)
	if first_btn and is_instance_valid(first_btn):
		first_btn.grab_focus()   # Tab and the arrows move between the ways on


# ===================================================================================== HEADER
func _header(outer: VBoxContainer, s: Dictionary, r: Dictionary, S: Dictionary, last_sim: Dictionary) -> void:
	var head := Kit.hbox(22)
	outer.add_child(head)
	var gcol: Color = {"S": Color(1.0, 0.85, 0.3), "A": Kit.C_OK, "B": Kit.C_ACCENT, "C": Kit.C_WARN, "D": Kit.C_BAD}[s.grade]
	var gl := Kit.lbl(s.grade, 88, Kit.ink(gcol), Kit.FONT_T)
	gl.custom_minimum_size.x = 92
	head.add_child(gl)
	var hv := Kit.vbox(4)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	hv.add_child(Kit.caps(tr("Mission report") + " · " + S.name))
	hv.add_child(Kit.lbl(s.label, 34, Kit.C_TEXT, Kit.FONT_T))
	var pts := tr("%d / 1000 points") % s.total
	if bonus > 0:
		pts += "  " + tr("+ %d bonus") % bonus
	hv.add_child(Kit.lbl(pts + "   ·   " + tr("Final cost %s of %s") % [Kit.money(s.final_cost), Kit.money(r.budget)] + "   ·   " \
		+ tr("%d of %d months in operation") % [last_sim.months, mission.years * 12], Kit.T_BODY, Kit.C_DIM))
	var good: bool = s.grade in ["S", "A", "B"] and not last_sim.launch_failed and last_sim.status != "lost"
	if good:
		# the brand's horizon arc draws itself under the header: the moment of the mission done
		var arc := Horizon.new()
		arc.custom_minimum_size = Vector2(0, 10)
		arc.thickness = 2.5
		arc.progress = 0.0
		outer.add_child(arc)
		arc.create_tween().tween_property(arc, "progress", 1.0, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		outer.add_child(Kit.rule())


# ===================================================================================== SCORE
func _score_column(cols: HBoxContainer, s: Dictionary, r: Dictionary, S: Dictionary, last_sim: Dictionary) -> void:
	var c1 := Kit.vbox(8)
	c1.custom_minimum_size.x = 250 if Kit.compact else 340
	cols.add_child(c1)
	c1.add_child(Kit.caps(tr("Score")))
	_score_row(c1, tr("Goals met"), s.objectives, 400, "")
	var sci_note: String = tr("%d of %d science points.") % [int(last_sim.science), int(S.science_target)]
	if last_sim.science < S.science_target:
		for c in r.checks:
			if c.level == "warn" and str(c.get("at", "")) in ["panels", "battery", "comms", "adcs", "instruments"]:
				sci_note += " " + tr("Less than the goal mostly because: %s.") % c.title
				break
	_score_row(c1, tr("Science gathered"), s.science, 300, sci_note)
	_score_row(c1, tr("Efficient use of resources"), s.efficiency, 200, "")
	if not GameState.team_mode:
		return   # alone, the crew's roles are all yours: the four bars above say it all
	_score_row(c1, tr("Teamwork"), s.team, 100, tr("Each role's goals met."))
	c1.add_child(Kit.spacer(4))
	c1.add_child(Kit.caps(tr("Goals by role")))
	for role in GameData.ROLE_ORDER:
		var R: Dictionary = GameData.ROLES[role]
		var ok: bool = r.goals[role]
		var who := GameState.player_for_role(role) + " · "
		c1.add_child(Kit.lbl(("✓ " if ok else "○ ") + who + R.name, Kit.T_BODY, Kit.ink(Kit.C_OK if ok else Kit.C_WARN), Kit.FONT_B, true))
		c1.add_child(Kit.lbl(R.why, Kit.T_SMALL - 1, Kit.C_DIM, Kit.FONT_R, true))


func _score_row(parent: VBoxContainer, nm: String, val: int, mx: int, sub: String) -> void:
	var h := Kit.hbox(6)
	parent.add_child(h)
	var n := Kit.lbl(nm, Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	h.add_child(Kit.lbl("%d / %d" % [val, mx], Kit.T_BODY, Kit.C_TEXT, Kit.font_num()))
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 10)
	pb.max_value = mx
	pb.value = val
	var f: float = float(val) / mx
	pb.add_theme_stylebox_override("fill", Kit.flat(Kit.C_OK if f >= 0.75 else (Kit.C_WARN if f >= 0.4 else Kit.C_BAD), Color(0, 0, 0, 0), 4, 0, 0, 0))
	parent.add_child(pb)
	if sub != "":
		parent.add_child(Kit.lbl(sub, Kit.T_SMALL - 1, Kit.C_DIM, Kit.FONT_R, true))


# ===================================================================================== PHOTOS AND BONUSES
func _photo_column(cols: HBoxContainer, flight: Dictionary, last_sim: Dictionary) -> void:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size.x = 300 if Kit.compact else 420
	cols.add_child(sc)
	var c := Kit.vbox(Kit.GAP)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(c)
	var photos: Array = Photos.of(mission.scenario)
	var got := 0
	for ph in photos:
		if Photos.earned(ph, flight, last_sim):
			got += 1
	c.add_child(Kit.caps(tr("Photos your mission sent home")))
	if photos.is_empty():
		c.add_child(Kit.lbl(tr("This mission's pictures are not in the game yet."), Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))
	else:
		c.add_child(Kit.lbl(tr("Real pictures of your target taken by NASA satellites: the kind your craft sends home. %d of %d came home this time. Click one to see it large.") % [got, photos.size()], Kit.T_SMALL, Kit.C_TEXT, Kit.FONT_R, true))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		c.add_child(grid)
		for ph in photos:
			grid.add_child(_photo_tile(ph, Photos.earned(ph, flight, last_sim)))


## A photo's tile: the picture (click to see it large) or, when it did not come home, what would bring it.
func _photo_tile(ph: Dictionary, earned: bool) -> Control:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(140, 92) if Kit.compact else Vector2(200, 132)
	tile.add_theme_stylebox_override("panel", Kit.flat(Kit.C_CARD, Kit.C_LINE, 8, 1, 0, 0))
	if earned:
		var tr_ := TextureRect.new()
		tr_.texture = load(ph.path)
		tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr_.clip_contents = true
		tr_.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(tr_)
		tile.mouse_filter = Control.MOUSE_FILTER_STOP
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.tooltip_text = tr(str(ph.caption))
		tile.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_show_photo(ph))
	else:
		var v := Kit.vbox(4)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		tile.add_child(v)
		var all: Dictionary = Objectives.all()
		var what: String = tr("Meet “%s” to bring this one home.") % str(all[ph.objective].name) if ph.objective != "" and all.has(ph.objective) \
			else tr("It comes home when the mission works.")
		if ph.objective != "" and all.has(ph.objective) and all[ph.objective].has("how"):
			what += "
" + tr("How: %s") % tr(str(all[ph.objective].how))   # #98
		var l := Kit.lbl("🔒  " + what, Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.x = 180
		v.add_child(l)
	return tile


## A photo large, with what it shows and whose it is.
func _show_photo(ph: Dictionary) -> void:
	Kit.UiSound.play("select")
	var box := Kit.overlay(self, tr("A photo your mission sent home"), 980.0, 760.0)
	photo_layer = box.get_parent().get_parent()   # the overlay's shade, which holds the panel
	var tex := TextureRect.new()
	tex.texture = load(ph.path)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tex)
	box.add_child(Kit.lbl(tr(str(ph.caption)), Kit.T_LEAD, Kit.C_TEXT, Kit.FONT_R, true))
	box.add_child(Kit.lbl(tr("Credit: %s") % ph.credit, Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))


# ===================================================================================== THE STORY
func _story_column(cols: HBoxContainer, last_sim: Dictionary) -> void:
	var c2sc := ScrollContainer.new()
	c2sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c2sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(c2sc)
	var c2 := Kit.vbox(6)
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c2sc.add_child(c2)
	c2.add_child(Kit.caps(tr("What went well")))
	var shown := 0
	for e in last_sim.events:
		if e.kind == "good" and shown < 6:
			shown += 1
			var star: bool = str(e.title).begins_with(tr("Extra objective · %s") % "")
			c2.add_child(Kit.lbl(("★ " if star else "✓ ") + str(e.title), Kit.T_BODY, Kit.ink(Kit.C_GOLD if star else Kit.C_OK), Kit.FONT_B, true))
	if bonus > 0:
		c2.add_child(Kit.lbl(tr("Bonus: +%d points on top of your score.") % bonus, Kit.T_BODY, Kit.ink(Kit.C_GOLD), Kit.FONT_B, true))
	c2.add_child(Kit.spacer(4))
	c2.add_child(Kit.caps(tr("To do even better next time")))
	var any_bad := false
	var r: Dictionary = GameState.last_report
	for c in r.checks:
		if c.level == "warn":
			any_bad = true
			c2.add_child(Kit.lbl("→ " + c.title, Kit.T_BODY, Kit.ink(Kit.C_WARN), Kit.FONT_B, true))
			var where: String = FIX_AT.get(str(c.get("at", "")), "")
			c2.add_child(Kit.lbl(c.detail + ("  " + tr("Change it in the %s step.") % tr(where) if where != "" else ""), Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))
	for e in last_sim.events:
		if e.kind == "bad" and e.month > 1:
			any_bad = true
			c2.add_child(Kit.lbl(tr("• Month %d · %s") % [e.month, e.title], Kit.T_BODY, Kit.ink(Kit.C_WARN), Kit.FONT_B, true))
			c2.add_child(Kit.lbl(e.text, Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))
	if not any_bad:
		c2.add_child(Kit.lbl(tr("✓ The design was balanced, with margin in power, data, mass and fuel. That's how a mission gets designed!"), Kit.T_BODY, Kit.ink(Kit.C_OK), Kit.FONT_B, true))
	c2.add_child(Kit.spacer(4))
	c2.add_child(Kit.caps(tr("Similar real missions")))
	for t in mission.real_missions():
		c2.add_child(Kit.lbl("• " + t, Kit.T_SMALL + 1, Kit.C_DIM, Kit.FONT_R, true))



# ===================================================================================== WAYS ON
func _actions(outer: VBoxContainer, s: Dictionary) -> void:
	var bh := Kit.hbox(10)
	outer.add_child(bh)
	var redo := Kit.accent_btn(Kit.btn(tr("Redesign mission") + "  ·  Enter", func(): _back_to_design(), Kit.T_BODY), Kit.C_ACCENT)
	first_btn = redo
	redo.custom_minimum_size.y = Kit.BTN_H
	bh.add_child(redo)
	for b in [Kit.btn(tr("↻ Fly again (new luck)") + "  ·  R", func(): _fly_again(), Kit.T_BODY), Kit.btn(tr("New mission") + "  ·  N", func(): go("missions"), Kit.T_BODY)]:
		b.custom_minimum_size.y = Kit.BTN_H
		bh.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(sp)
	var rank := Kit.btn(tr("Ranking"), func(): main.overlay("ranking"), Kit.T_BODY)
	rank.custom_minimum_size.y = Kit.BTN_H
	bh.add_child(rank)
	var menu := Kit.btn(tr("Menu") + "  ·  Esc", func(): go("menu"), Kit.T_BODY)
	menu.custom_minimum_size.y = Kit.BTN_H
	bh.add_child(menu)


func _back_to_design() -> void:
	GameState.approvals = {}
	world.clear_stage()
	world.stage_design()
	go("design", {"step": GameData.STEPS.size() - 1})


## The same design flies again, with new luck: every role approves and it launches.
func _fly_again() -> void:
	GameState.approve_all()
	main.launch()


## Who flew it, for the ranking: the players' names, or the station the player held with its cuy crewmates.
func _crew_name() -> String:
	var names: Array = []
	for P in GameState.players:
		names.append(str(P.get("name", "")))
	names = names.filter(func(n): return n.strip_edges() != "")
	return " · ".join(names) if not names.is_empty() else tr("You and the cuyes")
