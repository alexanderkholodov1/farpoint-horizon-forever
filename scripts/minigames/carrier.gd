extends VBoxContainer
## Ground control's mini-game "Find the carrier" (issue #9): the craft's radio tone is a faint line in a waterfall of
## noise, shifted from its X-band frequency by the craft's own motion (Doppler). The player clicks the line to tune
## to it, then narrows the filter: a narrower filter lets in less noise, so the line stands out, until the receiver
## locks. As the Deep Space Network found Voyager 2's faint carrier in 2023 when no data could be read [S-jpl-voyager2],
## and SOHO's in 1998 [S-soho-recovery]. Built only from scripts/ui/kit.gd.
##   var g := Carrier.new(); g.setup(station, f_hz_callable, light_s); g.done.connect(...)

signal done(result: Dictionary)

const Kit := preload("res://scripts/ui/kit.gd")
const BANDS := [100000.0, 10000.0, 1000.0]   ## Filter widths, Hz: each one tenth of the one before.
const COLS := 128
const ROWS := 64
const ROW_S := 0.05                          ## Seconds between rows of the waterfall.
const LOCK_S := 1.5                          ## Seconds tuned inside the narrowest filter to lock.
const BONUS_MAX := 120
const BONUS_MIN := 60
const SLOW_S := 60.0                         ## After this, the bonus is the minimum.
const GIVE_UP_S := 90.0                      ## Wayra (the ground control cuy) locks it after this, so the panel never waits forever.

var station := {}
var f_of := Callable()       ## Returns the craft's tone, Hz from the X-band frequency (the desk fixes it when the pass begins).
var tuner := 0.0             ## Hz: where the receiver listens.
var band := 0                ## Index into BANDS.
var t := 0.0
var row_t := 0.0
var held := 0.0
var locked := false
var img: Image
var tex: ImageTexture
var view: TextureRect
var status: Label
var bands_row: HBoxContainer
var rng := RandomNumberGenerator.new()


func setup(st: Dictionary, f_callable: Callable, light_s: float, speed_mps: float) -> void:
	station = st
	f_of = f_callable
	add_theme_constant_override("separation", Kit.GAP)
	custom_minimum_size = Vector2(380, 0)
	add_child(Kit.caps(tr("Ground control · Deep Space Network")))
	add_child(Kit.lbl(tr("Find the carrier"), Kit.T_VALUE, Kit.C_TEXT, Kit.FONT_B))
	var away := tr("away from Earth") if speed_mps >= 0.0 else tr("toward Earth")
	add_child(Kit.lbl(tr("%s (%s) sees your craft %d° up, %.2f light-seconds away. It moves %.1f km/s %s, so its tone is shifted %+.0f kHz (Doppler).") % [
		station.name, tr(station.place), roundi(station.elev), light_s, absf(speed_mps) / 1000.0, away, f_of.call() / 1000.0], Kit.T_SMALL, Kit.C_DIM, Kit.FONT_R, true))
	img = Image.create(COLS, ROWS, false, Image.FORMAT_RGB8)
	img.fill(Kit.C_BG)
	tex = ImageTexture.create_from_image(img)
	view = TextureRect.new()
	view.texture = tex
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.custom_minimum_size = Vector2(380, 84)
	view.mouse_default_cursor_shape = Control.CURSOR_CROSS
	view.gui_input.connect(_on_view_input)
	var mid := ColorRect.new()
	mid.color = Color(Kit.C_GOLD, 0.7)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	mid.anchor_bottom = 1.0
	mid.offset_left = -0.5
	mid.offset_right = 0.5
	view.add_child(mid)
	add_child(view)
	var acts := Kit.hbox(Kit.GAP)
	add_child(acts)
	bands_row = Kit.segmented()
	bands_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acts.add_child(bands_row)
	_bands()
	acts.add_child(Kit.btn(tr("Wayra, take it"), func(): _finish("bot"), Kit.T_SMALL))
	status = Kit.lbl(tr("Click the faint line to tune to it, then narrow the filter."), Kit.T_BODY, Kit.C_ACCENT, Kit.FONT_R, true)
	add_child(status)
	rng.randomize()


func _bands() -> void:
	for c in bands_row.get_children():
		c.queue_free()
	bands_row.add_child(Kit.lbl(tr("Filter"), Kit.T_SMALL, Kit.C_DIM))
	for i in BANDS.size():
		var w: float = BANDS[i]
		var txt := "%d kHz" % roundi(w / 1000.0)
		bands_row.add_child(Kit.choice(txt, i == band, func(): set_band(i), 66))


## The width of the waterfall now, Hz (eight filters wide, centred on the tuner).
func span() -> float:
	return BANDS[band] * 8.0 if band > 0 else 800000.0


func set_band(i: int) -> void:
	band = clampi(i, 0, BANDS.size() - 1)
	held = 0.0
	_bands()


func tune(f_hz: float) -> void:
	tuner = clampf(f_hz, -400000.0, 400000.0)


func _on_view_input(e: InputEvent) -> void:
	if locked:
		return
	var press: bool = e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT
	var drag: bool = e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if press or drag:
		var x: float = e.position.x / maxf(view.size.x, 1.0)
		tune(tuner + (x - 0.5) * span())


## True when the tone is inside the filter.
func inside() -> bool:
	return absf(float(f_of.call()) - tuner) < BANDS[band] * 0.5


func _process(delta: float) -> void:
	if station.is_empty() or locked:
		return
	step(delta)


## One step of the game, delta in real seconds (tests call it too).
func step(delta: float) -> void:
	t += delta
	row_t += delta
	while row_t >= ROW_S:
		row_t -= ROW_S
		_row()
	var f: float = f_of.call()
	if t >= GIVE_UP_S:
		_finish("bot")
		return
	if inside() and band == BANDS.size() - 1:
		held += delta
		status.text = tr("Holding the tone... %d%%") % roundi(100.0 * held / LOCK_S)
		if held >= LOCK_S:
			_finish("player")
	else:
		held = 0.0
		if inside() and band < BANDS.size() - 1:
			status.text = tr("On it. Narrow the filter: less noise gets in, the line stands out.")
		elif absf(f - tuner) < span() * 0.5:
			status.text = tr("The line is in view. Click right on it.")
		else:
			status.text = tr("Not in view. Widen the filter and look for the faint line.")


## A new row of the waterfall at the top: noise in every column, and the tone where it falls, stronger the narrower
## the filter (the noise in a filter grows with its width; the tone does not).
func _row() -> void:
	img.blit_rect(img, Rect2i(0, 0, COLS, ROWS - 1), Vector2i(0, 1))
	var f: float = f_of.call()
	var w := span() / COLS
	var col := (f - tuner) / w + COLS * 0.5
	var strength: float = [0.32, 0.55, 0.9][band]
	for c in COLS:
		var v := pow(rng.randf(), 2.2) * 0.55
		if absf(c + 0.5 - col) < 1.0:
			v += strength * rng.randf_range(0.7, 1.0)
		v = clampf(v, 0.0, 1.0)
		img.set_pixel(c, 0, Kit.C_BG.lerp(Kit.C_ACCENT, minf(v * 1.6, 1.0)).lerp(Color.WHITE, maxf(v - 0.6, 0.0) * 2.0))
	tex.update(img)


func _finish(by: String) -> void:
	if locked:
		return
	locked = true
	var bonus := 0
	if by == "player":
		bonus = roundi(lerpf(BONUS_MAX, BONUS_MIN, clampf((t - 15.0) / (SLOW_S - 15.0), 0.0, 1.0)))
		status.text = tr("CARRIER LOCK. %s hears your craft. +%d") % [station.name, bonus]
		status.add_theme_color_override("font_color", Kit.ink(Kit.C_OK))
	var words := tr("%s has your craft's carrier. Telemetry is coming in.") % station.name
	done.emit({"go": true, "by": by, "bonus": bonus, "words": words, "secs": roundi(t)})
