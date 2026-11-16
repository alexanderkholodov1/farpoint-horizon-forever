extends CanvasLayer
## A story scene (v0.3.0, issue #66): the cuyes talk, one line at a time, in a card at the bottom of the screen with
## the speaker's portrait, name and station; a line may carry a NASA fact (with its source id) and may light a control
## on screen, the way the guided first mission does. It plays over any screen without stopping it, or pauses the game
## while it plays (pause = true). Click the card or press Enter to go on (the first press completes a line still being
## written); Esc skips the scene. Scenes are data: data/story/<chapter>.json, {"scenes": {id: [line, ...]}}, a line
## being {"who": cast id, "text", "mood" (optional), "fact" (optional), "source" (optional, a docs/sources.md id),
## "light" (optional, the visible text of a control to light), "shot" and "fx" (optional, for the cinematic stage,
## scripts/screens/story.gd)}. A line with "title" (and "sub") and no "who" is a title card: the date and place, big
## in the middle of the screen. The portrait is live: the speaker's 3D model in a small studio of its own, with the
## mood's face, its mouth moving while the line is written (scripts/story/cuy_actor.gd); each cuy babbles in its own
## voice as the letters appear.
##   const Dialogue := preload("res://scripts/story/dialogue.gd")
##   Dialogue.play(main, "apollo13", "problem", func(): ...)

signal finished(skipped: bool)
signal line_started(index: int, line: Dictionary)

## Each cuy's babble: the pitch of their syllables (Hz) and how often they squeak (letters per syllable).
const VOICE := {"rumi": [300.0, 4], "killa": [640.0, 2], "inti": [470.0, 3], "wayra": [380.0, 4]}

const Kit := preload("res://scripts/ui/kit.gd")
const Cast := preload("res://scripts/story/cast.gd")
const CHARS_PER_S := 55.0             ## How fast a line is written out.

var lines: Array = []
var at := -1
var pause := false
var card: PanelContainer
var portrait: TextureRect
var initial: Label
var frame: PanelContainer
var name_lbl: Label
var text_lbl: Label
var fact_box: Control
var fact_lbl: Label
var ring: Panel
var lit: Control
var _t := 0.0
var live := true             ## The portrait is the speaker's 3D model (false: the rendered image).
var show_portrait := true    ## The cinematic stage hides it: the camera is already on the speaker's face.
var studio: SubViewport
var studio_cam: Camera3D
var actors := {}             ## Cast id -> CuyActor in the portrait's studio.
var speaker := ""
var title_box: Control
var title_lbl: Label
var sub_lbl: Label
var voice: AudioStreamPlayer
var _voices := {}
var _said := 0
var _title_t := 0.0
var _title_len := 3.2
var waiting := -1.0          ## Seconds left of a beat with no words (the stage plays: a launch, a splashdown).


## Plays scene `scene` of chapter `chapter` over the game; on_done(skipped) is called at the end. Returns the player.
static func play(main: Node, chapter: String, scene: String, on_done := Callable(), pause_game := false) -> Node:
	var d = load("res://scripts/story/dialogue.gd").new()
	d.lines = load_scene(chapter, scene)
	d.pause = pause_game
	if on_done.is_valid():
		d.finished.connect(on_done)
	main.add_child(d)
	return d


## The lines of a scene, from data/story/<chapter>.json ([] when it is not there).
static func load_scene(chapter: String, scene: String) -> Array:
	var path := "res://data/story/%s.json" % chapter
	if not FileAccess.file_exists(path):
		return []
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data.get("scenes", {}).get(scene, [])


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	if pause:
		get_tree().paused = true
	_build()
	next()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	card = Kit.panel_box(Kit.PAD)
	Kit.place(card, 0.5, 1, 0.5, 1, -460, -Kit.MARGIN - 60, 460, -Kit.MARGIN)
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN       # as tall as its line, from the bottom up
	card.material = null      # solid, not frosted: what is behind it (a screen's own hints) must not read through
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			advance())
	root.add_child(card)
	var h := Kit.hbox(Kit.PAD)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(h)
	# the portrait in a round frame of the speaker's colour
	frame = PanelContainer.new()
	frame.custom_minimum_size = Vector2(132, 132)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	h.add_child(frame)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(portrait)
	initial = Kit.lbl("", Kit.T_CLOCK, Color(0.03, 0.06, 0.13), Kit.FONT_T)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(initial)
	var v := Kit.vbox(Kit.GAP)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	name_lbl = Kit.lbl("", Kit.T_BODY, Kit.C_TEXT, Kit.spaced(Kit.FONT_B, 2))
	v.add_child(name_lbl)
	text_lbl = Kit.lbl("", Kit.T_ACTION, Kit.C_TEXT, Kit.FONT_B, true)
	text_lbl.custom_minimum_size.x = 600
	v.add_child(text_lbl)
	# a NASA fact under the line, with where it comes from
	var fh := Kit.hbox(Kit.GAP)
	fh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fact_box = fh
	v.add_child(fh)
	fh.add_child(Kit.chip("NASA", Kit.C_GOLD))
	fact_lbl = Kit.lbl("", Kit.T_SMALL + 1, Kit.C_DIM, Kit.FONT_R, true)
	fact_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fh.add_child(fact_lbl)
	var foot := Kit.lbl(tr("Click or Enter to go on  ·  Esc skips"), Kit.T_CAPS, Kit.C_DIM, Kit.FONT_R)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(foot)
	# the title card: a date and a place, big in the middle
	# on a soft dark card, so a busy set behind it (a lit screen, a drawn orbit) never crosses the words
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Kit.flat(Color(0.02, 0.03, 0.06, 0.78), Color(0, 0, 0, 0), 16, 0, 32, 14))
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	card.offset_top = 150          # high, over the heads of a wide shot
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.visible = false
	root.add_child(card)
	var tv := Kit.vbox(Kit.GAP)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(tv)
	title_box = card
	title_lbl = Kit.lbl("", Kit.T_CLOCK + 14, Kit.C_ON_DARK, Kit.FONT_T)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_constant_override("outline_size", 6)
	title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	tv.add_child(title_lbl)
	sub_lbl = Kit.lbl("", Kit.T_ACTION, Kit.C_GOLD, Kit.spaced(Kit.FONT_B, 3))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_constant_override("outline_size", 4)
	sub_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	tv.add_child(sub_lbl)
	voice = AudioStreamPlayer.new()
	voice.volume_db = -21.0
	add_child(voice)
	if live:
		_build_studio()
	ring = Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := Kit.flat(Color(Kit.C_GOLD, 0.08), Kit.C_GOLD, 10, 3, 0, 0)
	sb.shadow_color = Color(Kit.C_GOLD, 0.45)
	sb.shadow_size = 10
	ring.add_theme_stylebox_override("panel", sb)
	ring.visible = false
	root.add_child(ring)


## Shows the next line, or ends the scene.
func next() -> void:
	at += 1
	if at >= lines.size():
		_end(false)
		return
	var L: Dictionary = lines[at]
	line_started.emit(at, L)
	if L.has("title") and not L.has("who"):
		_show_title(L)
		return
	title_box.visible = false
	if not L.has("who"):
		# a beat with no words: the stage plays for a while
		card.visible = false
		speaker = ""
		waiting = float(L.get("wait", 2.0))
		return
	card.visible = true
	var who := str(L.get("who", ""))
	var narrator := who == "narrator"
	frame.visible = show_portrait and not narrator
	speaker = who
	_said = 0
	var col: Color = Kit.C_GOLD if narrator else Cast.colour(who)
	name_lbl.visible = not narrator
	name_lbl.text = (Cast.display_name(who) + "  ·  " + Cast.station(who)).to_upper()
	name_lbl.add_theme_color_override("font_color", Kit.ink(col))
	text_lbl.add_theme_color_override("font_color", (Color(1.0, 0.86, 0.62) if Kit.mode != "light" else Kit.ink(Kit.C_GOLD)) if narrator else Kit.C_TEXT)   # a pale gold on the dark card, a deep one on the light card (#97)
	var tex: Texture2D = _live_portrait(who, str(L.get("mood", ""))) if live and not narrator else null
	if tex == null:
		tex = Cast.portrait(who)
	portrait.texture = tex
	initial.text = "" if tex else Cast.display_name(who).left(1)
	# opaque: the round frame clips the portrait by its own alpha
	frame.add_theme_stylebox_override("panel", Kit.flat(col.darkened(0.55) if tex else col, col, 66, 3, 0, 0))
	card.add_theme_stylebox_override("panel", Kit.flat(Kit.C_BG, Color(col, 0.55), 14, 2, Kit.PAD, Kit.PAD))
	text_lbl.text = tr(str(L.get("text", "")))
	text_lbl.visible_ratio = 0.0
	_t = 0.0
	var fact := str(L.get("fact", ""))
	fact_box.visible = false              # the fact follows once the line is written
	fact_lbl.text = tr(fact)
	lit = _find(tr(str(L.get("light", "")))) if L.has("light") else null
	ring.visible = lit != null
	Kit.UiSound.play("notify", 0.0)
	# the card answers each new line with a small lift
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.97, 0.97)
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


## Click or Enter: finish writing the line, or go to the next one.
func advance() -> void:
	if waiting >= 0.0:
		waiting = -1.0
		next()
	elif title_box.visible:
		next()
	elif text_lbl.visible_ratio < 1.0:
		text_lbl.visible_ratio = 1.0
	else:
		next()


func _process(delta: float) -> void:
	if text_lbl and text_lbl.visible_ratio < 1.0:
		_t += delta
		var n := maxi(text_lbl.text.length(), 1)
		text_lbl.visible_ratio = minf(1.0, _t * CHARS_PER_S / n)
		_babble()
	if actors.has(speaker):
		actors[speaker].talking = writing()
		studio_cam.look_at(actors[speaker].face_point(), Vector3.UP)
	if title_box.visible:
		_title_t += delta
		title_box.modulate.a = clampf(_title_t * 2.0, 0.0, 1.0)
		if _title_t > _title_len:
			next()
	if waiting >= 0.0:
		waiting -= delta
		if waiting < 0.0:
			next()
	if text_lbl and text_lbl.visible_ratio >= 1.0 and fact_lbl.text != "" and not fact_box.visible:
		fact_box.visible = true
	if lit and is_instance_valid(lit) and lit.is_visible_in_tree():
		var r := lit.get_global_rect().grow(6)
		ring.position = r.position
		ring.size = r.size
		ring.modulate.a = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 160.0)
	else:
		ring.visible = false


func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.physical_keycode == KEY_ENTER or e.physical_keycode == KEY_KP_ENTER:
		advance()
	elif e.physical_keycode == KEY_ESCAPE:
		_end(true)
	else:
		return
	get_viewport().set_input_as_handled()


func _end(skipped: bool) -> void:
	if pause:
		get_tree().paused = false
	finished.emit(skipped)
	queue_free()


## True while the line is still being written (the speaker's mouth moves).
func writing() -> bool:
	return card.visible and text_lbl.visible_ratio < 1.0 and speaker != "narrator"


func _show_title(L: Dictionary) -> void:
	card.visible = false
	ring.visible = false
	lit = null
	speaker = ""
	title_lbl.text = tr(str(L.title))
	sub_lbl.text = tr(str(L.get("sub", ""))).to_upper()
	sub_lbl.visible = sub_lbl.text != ""
	title_box.visible = true
	title_box.modulate.a = 0.0
	_title_t = 0.0
	_title_len = float(L.get("wait", 3.2))
	Kit.UiSound.play("whoosh", 0.0)


## A syllable of the speaker's babble every few letters written.
func _babble() -> void:
	if Kit.UiSound.is_muted() or not VOICE.has(speaker):
		return
	var shown := int(text_lbl.visible_ratio * text_lbl.text.length())
	var every: int = VOICE[speaker][1]
	if shown - _said < every:
		return
	_said = shown
	var ch := text_lbl.text.substr(maxi(shown - 1, 0), 1)
	if ch == " " or ch == "." or ch == ",":
		return
	if not _voices.has(speaker):
		var f: float = VOICE[speaker][0]
		var list := []
		for k in 4:
			var ff: float = f * [1.0, 1.12, 0.92, 1.25][k]
			list.append(Kit.UiSound._wav(Kit.UiSound._tone([ff, ff * 2.0], 0.07, 0.004, 0.035)))
		_voices[speaker] = list
	voice.stream = _voices[speaker][randi() % 4]
	voice.pitch_scale = randf_range(0.94, 1.06)
	voice.play()


## The portrait's studio: a small world of its own with a key light, where the speaker's model stands.
func _build_studio() -> void:
	studio = SubViewport.new()
	studio.size = Vector2i(256, 256)
	studio.transparent_bg = true
	studio.own_world_3d = true
	studio.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(studio)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.environment.ambient_light_energy = 0.7
	studio.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -30, 0)
	key.light_energy = 1.3
	studio.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 160, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.6, 0.78, 1.0)
	studio.add_child(rim)
	studio_cam = Camera3D.new()
	studio_cam.fov = 30.0
	studio.add_child(studio_cam)


## The speaker in the studio, with the line's mood; the studio's picture is the portrait.
func _live_portrait(who: String, m: String) -> Texture2D:
	if studio == null or not Cast.has(who):
		return null
	if not actors.has(who):
		var a = load("res://scripts/story/cuy_actor.gd").new()
		a.id = who
		studio.add_child(a)
		if a.head == null:
			a.queue_free()
			return null
		actors[who] = a
	for k in actors:
		actors[k].visible = k == who
	var actor = actors[who]
	actor.set_mood(m)
	var f: Vector3 = actor.face_point()
	studio_cam.position = f + Vector3(0.0, 0.02, 0.62)
	studio_cam.look_at(f, Vector3.UP)
	return studio.get_texture()


## The visible button whose text is `txt` (what a line lights).
func _find(txt: String) -> Control:
	if txt == "":
		return null
	for n in get_tree().root.find_children("*", "Button", true, false):
		var b := n as Button
		if b.is_visible_in_tree() and b.text.strip_edges() == txt:
			return b
	return null
