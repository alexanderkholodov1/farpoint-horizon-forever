extends RefCounted
## The UI kit every screen builds with: theme, colors, fonts, and helpers for labels, buttons, cards, panels, boxes,
## toasts, overlays and number formatting. It is the project's one UI standard (issue #31): a screen takes its sizes
## from the type scale and spacing below, its colours from C_*, and its pieces from the components here (section
## labels, hairlines, joined choices, stat cards, hint boxes), never loose numbers or colours, so every screen looks
## the same and nobody needs a screenshot to match another. Everything is static and stateless:
##   const Kit := preload("res://scripts/ui/kit.gd")   (screens already have it from scripts/screens/screen.gd)
##   add_child(Kit.lbl("Hola", 16, Kit.C_ACCENT, Kit.FONT_B))

const FONT_R := preload("res://assets/fonts/Inter-Regular.otf")
const FONT_B := preload("res://assets/fonts/Inter-SemiBold.otf")
const FONT_T := preload("res://assets/fonts/InterDisplay-Bold.otf")

## Two appearances the player chooses on the menu, remembered between sessions (user://settings.cfg, [ui] mode):
## - "dark" (the default): deep navy frosted glass over the scene, light text, bright status colours.
## - "light": the lead's "clean room" (direction A, issue #12): light frosted glass, dark text, dark status colours.
## The palette is the brand's horizon arc and nothing else: horizon blue (C_ACCENT), sunrise amber (C_GOLD), and
## navy-tinted neutrals. Status stays inside it: fine is ice blue, attention is pale sunrise, and one red only for what
## blocks the mission. No green, pink or violet anywhere in the UI.
## Both keep the same language: frosted panels over the 3D scene, hairlines, large tabular numerals, the deep blue and
## the gold of thermal blankets, contrast at least WCAG AA. The brand's horizon arc is scripts/ui/horizon.gd.
## Screens read these as Kit.C_*; set_mode() changes them and main.gd rebuilds the theme and the screen.
const MODES := ["dark", "light"]
const SETTINGS_PATH := "user://settings.cfg"
static var mode := "dark"
static var C_BG := Color(0.045, 0.07, 0.12, 1.0)      ## Panel fill (the frost shader mixes it over the blurred scene).
static var C_CARD := Color(1, 1, 1, 0.045)            ## Cards and tiles inside a panel.
static var C_CARD_SEL := Color(0.16, 0.36, 0.7, 0.32) ## A selected card.
static var C_CARD_HOVER := Color(1, 1, 1, 0.09)
static var C_BTN := Color(1, 1, 1, 0.06)
static var C_BTN_HOVER := Color(1, 1, 1, 0.13)
static var C_BTN_PRESS := Color(0.2, 0.42, 0.8, 0.45)
static var C_EDGE := Color(0.6, 0.75, 1.0, 0.22)      ## A panel's hairline edge.
static var C_ACCENT := Color(0.47, 0.72, 1.0)         ## Blue: selection, headings, links, the default bar fill.
static var C_GOLD := Color(1.0, 0.66, 0.26)           ## Sunrise amber, the arc's warm point: the one main action of a screen.
static var C_OK := Color(0.62, 0.9, 1.0)             ## Fine: the ice blue of the horizon's limb (no green: the palette is the arc's).
static var C_WARN := Color(1.0, 0.82, 0.5)            ## Attention: pale sunrise.
static var C_BAD := Color(1.0, 0.45, 0.4)             ## Blocks the mission: the only red, used for nothing else.
static var C_DIM := Color(0.66, 0.72, 0.82)
static var C_TEXT := Color(0.94, 0.96, 1.0)
static var C_LINE := Color(0.6, 0.75, 1.0, 0.16)      ## Hairlines: borders, dividers, empty bars.
static var C_SHADE := Color(0.0, 0.01, 0.03, 0.55)    ## Behind an overlay.
const C_ON_DARK := Color(0.96, 0.97, 1.0)             ## Text drawn straight on the 3D scene (space, sky).
const FROST := preload("res://assets/shaders/ui_frost.gdshader")

## The type scale, in pixels. Every text in the game uses one of these.
static var T_CAPS := 11       ## Section labels, in spaced capitals (caps()).
static var T_SMALL := 13      ## Notes under a value, key hints, captions.
static var T_BODY := 15       ## Labels, buttons, list text.
static var T_LEAD := 17       ## Hints and lead paragraphs.
static var T_VALUE := 19      ## A readout's value (with font_num()).
static var T_ACTION := 21     ## The one main action's button.
static var T_STAT := 26       ## The big number of a stat card.
static var T_CLOCK := 40      ## Clocks and the one key number of a screen.
static var T_SHOUT := 60      ## A big message straight on the scene.
static var T_CINEMA := 92     ## A title card of the credits film, alone on the screen.
## Spacing, in pixels.
static var MARGIN := 24       ## From the window's edge to a panel.
static var PAD := 22          ## Inside a panel.
static var GAP := 10          ## Between rows inside a panel.
static var BTN_H := 44        ## A button's height (a main action: 56).
const UiSound := preload("res://scripts/ui/ui_sound.gd")
## A short screen (a phone in landscape): the interface is drawn bigger there (main.gd _fit_screen), so the layout has
## about 1050 x 490 to work with instead of 1600 x 900. Compact keeps small text readable (captions and notes a little
## bigger), shrinks the big numbers and the spacing, and screens lay themselves out for the room left (issue #89).
static var compact := false


static func set_compact(on: bool) -> void:
	compact = on
	T_CAPS = 13 if on else 11
	T_SMALL = 14 if on else 13
	T_BODY = 15
	T_LEAD = 16 if on else 17
	T_VALUE = 17 if on else 19
	T_ACTION = 18 if on else 21
	T_STAT = 22 if on else 26
	T_CLOCK = 28 if on else 40
	T_SHOUT = 38 if on else 60
	T_CINEMA = 56 if on else 92
	MARGIN = 10 if on else 24
	PAD = 12 if on else 22
	GAP = 6 if on else 10
	BTN_H = 40 if on else 44

static var _frost: ShaderMaterial
static var _num_font: FontVariation
static var _mode_loaded := false


## Loads the remembered appearance (once) and applies it.
static func load_mode() -> void:
	if _mode_loaded:
		return
	_mode_loaded = true
	var cfg := ConfigFile.new()
	var m := "dark"
	if cfg.load(SETTINGS_PATH) == OK:
		m = str(cfg.get_value("ui", "mode", "dark"))
	_apply(m if MODES.has(m) else "dark")


## Switches the appearance and remembers it. The caller rebuilds the theme (build_theme) and redraws the screen.
static func set_mode(m: String) -> void:
	if not MODES.has(m):
		return
	_apply(m)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("ui", "mode", m)
	cfg.save(SETTINGS_PATH)


static func _apply(m: String) -> void:
	mode = m
	if m == "light":
		C_BG = Color(0.97, 0.975, 0.985, 1.0)
		C_CARD = Color(1, 1, 1, 0.62)
		C_CARD_SEL = Color(0.88, 0.93, 1.0, 0.97)
		C_CARD_HOVER = Color(1, 1, 1, 0.95)
		C_BTN = Color(1, 1, 1, 0.72)
		C_BTN_HOVER = Color(1, 1, 1, 0.98)
		C_BTN_PRESS = Color(0.85, 0.9, 0.98, 1.0)
		C_EDGE = Color(1, 1, 1, 0.95)
		C_ACCENT = Color(0.08, 0.3, 0.68)
		C_GOLD = Color(0.9, 0.56, 0.14)
		C_OK = Color(0.04, 0.42, 0.6)
		C_WARN = Color(0.68, 0.42, 0.0)
		C_BAD = Color(0.76, 0.14, 0.14)
		C_DIM = Color(0.32, 0.38, 0.48)
		C_TEXT = Color(0.05, 0.09, 0.18)
		C_LINE = Color(0.08, 0.2, 0.4, 0.16)
		C_SHADE = Color(0.02, 0.05, 0.12, 0.35)
	else:
		C_BG = Color(0.045, 0.07, 0.12, 1.0)
		C_CARD = Color(1, 1, 1, 0.045)
		C_CARD_SEL = Color(0.16, 0.36, 0.7, 0.32)
		C_CARD_HOVER = Color(1, 1, 1, 0.09)
		C_BTN = Color(1, 1, 1, 0.06)
		C_BTN_HOVER = Color(1, 1, 1, 0.13)
		C_BTN_PRESS = Color(0.2, 0.42, 0.8, 0.45)
		C_EDGE = Color(0.6, 0.75, 1.0, 0.22)
		C_ACCENT = Color(0.47, 0.72, 1.0)
		C_GOLD = Color(1.0, 0.66, 0.26)
		C_OK = Color(0.62, 0.9, 1.0)
		C_WARN = Color(1.0, 0.82, 0.5)
		C_BAD = Color(1.0, 0.45, 0.4)
		C_DIM = Color(0.66, 0.72, 0.82)
		C_TEXT = Color(0.94, 0.96, 1.0)
		C_LINE = Color(0.6, 0.75, 1.0, 0.16)
		C_SHADE = Color(0.0, 0.01, 0.03, 0.55)
	var f := frost()
	# the panel colour covers most of the blur, so a panel over a bright sky, white smoke or dark space reads the same
	f.set_shader_parameter("tint", 0.88 if m == "light" else 0.9)
	f.set_shader_parameter("lift", 0.55 if m == "light" else 0.0)
	f.set_shader_parameter("lift_to", Color(1, 1, 1) if m == "light" else Color(0, 0, 0))


## The frosted-glass material of the panels (one shared instance).
static func frost() -> ShaderMaterial:
	if _frost == null:
		_frost = ShaderMaterial.new()
		_frost.shader = FROST
	return _frost


## Inter Display with tabular figures, so numbers that change keep their width: gauges, clocks, telemetry.
static func font_num() -> FontVariation:
	if _num_font == null:
		_num_font = FontVariation.new()
		_num_font.base_font = FONT_T
		var ts := TextServerManager.get_primary_interface()
		_num_font.opentype_features = {ts.name_to_tag("tnum"): 1}
	return _num_font


# ===================================================================================== THEME
static func flat(bg: Color, border := Color(0, 0, 0, 0), radius := 8, bw := 0, mx := 12.0, my := 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	s.anti_aliasing = true
	return s


## The theme of the whole UI in the current appearance; main.gd sets it on the UI root, so every screen inherits it.
static func build_theme() -> Theme:
	load_mode()
	UiSound.load_settings()
	UiSound.play("click", 0.0)   # makes the sound players early (the first call only prepares them)
	var t := Theme.new()
	t.default_font = FONT_R
	t.default_font_size = 16
	# a panel that is not given the frost material still reads as frosted glass: a little translucent
	var panel := flat(Color(C_BG.r, C_BG.g, C_BG.b, 0.9), C_EDGE, 14, 1, 16, 14)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("normal", "Button", flat(C_BTN, C_LINE, 7, 1, 16, 8))
	t.set_stylebox("hover", "Button", flat(C_BTN_HOVER, Color(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, 0.55), 7, 1, 16, 8))
	t.set_stylebox("pressed", "Button", flat(C_BTN_PRESS, C_ACCENT, 7, 1, 16, 8))
	t.set_stylebox("disabled", "Button", flat(Color(C_BTN.r, C_BTN.g, C_BTN.b, C_BTN.a * 0.5), Color(C_LINE.r, C_LINE.g, C_LINE.b, 0.08), 7, 1, 16, 8))
	t.set_stylebox("focus", "Button", flat(Color(0, 0, 0, 0), C_ACCENT, 7, 2, 16, 8))
	t.set_font("font", "Button", FONT_B)
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", C_ACCENT if mode == "light" else Color.WHITE)
	t.set_color("font_pressed_color", "Button", C_ACCENT if mode == "light" else Color.WHITE)
	t.set_color("font_focus_color", "Button", C_TEXT)
	t.set_color("font_disabled_color", "Button", Color(C_DIM.r, C_DIM.g, C_DIM.b, 0.6))
	t.set_color("font_color", "Label", C_TEXT)
	t.set_stylebox("normal", "LineEdit", flat(Color(C_BTN.r, C_BTN.g, C_BTN.b, minf(1.0, C_BTN.a * 1.4)), C_LINE, 6, 1, 10, 8))
	t.set_stylebox("focus", "LineEdit", flat(Color(0, 0, 0, 0), C_ACCENT, 6, 2, 10, 8))
	t.set_color("font_color", "LineEdit", C_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", C_DIM)
	t.set_color("caret_color", "LineEdit", C_ACCENT)
	t.set_stylebox("background", "ProgressBar", flat(Color(C_LINE.r, C_LINE.g, C_LINE.b, 0.14), Color(0, 0, 0, 0), 3, 0, 0, 0))
	t.set_stylebox("fill", "ProgressBar", flat(C_ACCENT, Color(0, 0, 0, 0), 3, 0, 0, 0))
	t.set_color("font_color", "ProgressBar", C_TEXT)
	t.set_stylebox("panel", "TooltipPanel", flat(Color(C_BG.r, C_BG.g, C_BG.b, 0.97), C_EDGE, 6, 1, 10, 6))
	t.set_color("font_color", "TooltipLabel", C_TEXT)
	t.set_color("font_color", "CheckBox", C_TEXT)
	t.set_color("font_hover_color", "CheckBox", C_ACCENT)
	t.set_color("font_pressed_color", "CheckBox", C_TEXT)
	t.set_stylebox("grabber", "VScrollBar", flat(Color(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, 0.35), Color(0, 0, 0, 0), 4, 0, 4, 4))
	t.set_stylebox("grabber_highlight", "VScrollBar", flat(Color(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, 0.6), Color(0, 0, 0, 0), 4, 0, 4, 4))
	t.set_stylebox("scroll", "VScrollBar", flat(Color(C_LINE.r, C_LINE.g, C_LINE.b, 0.06), Color(0, 0, 0, 0), 4, 0, 4, 4))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_font("normal_font", "RichTextLabel", FONT_R)
	t.set_font("bold_font", "RichTextLabel", FONT_B)
	t.set_color("default_color", "RichTextLabel", C_TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", 16)
	t.set_font_size("bold_font_size", "RichTextLabel", 16)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	return t


# ===================================================================================== WIDGETS
## Sets anchors (al, at, ar, ab: 0..1 of the parent) and offsets in pixels; returns the control.
## On a short screen (a phone in landscape, under its browser bar) a panel anchored to the bottom may reach up into
## one above it. This scales it down, from its bottom corner, just enough that its top stays below top_limit (in the
## screen's units), never below min_s. Returns the scale used. Measured every frame by the screens that need it, so it
## follows the panel's own content and the screen's size.
static func fit_under(lower: Control, top_limit: float, right_corner: bool, min_s := 0.55) -> float:
	var bottom: float = lower.get_viewport_rect().size.y - MARGIN
	var s := clampf((bottom - top_limit) / maxf(lower.size.y, 1.0), min_s, 1.0)
	lower.pivot_offset = Vector2(lower.size.x if right_corner else 0.0, lower.size.y)
	lower.scale = Vector2(s, s)
	return s


## The middle column of a phone's three-column screen (design, builder): the hint and the action bar span exactly the
## gap between the left panel and the right one, the bar on the bottom edge and the hint just above it, so neither
## covers a panel whatever the panels' content or the screen's size.
static func fit_middle(left: Control, right: Control, hint: Control, bar: Control) -> void:
	var view: Vector2 = bar.get_viewport_rect().size
	var l: float = left.get_global_rect().end.x + 8.0
	var r: float = right.get_global_rect().position.x - 8.0 if right.visible else view.x - MARGIN
	for c in [hint, bar]:
		c.offset_left = l
		c.offset_right = r - view.x
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_top = -MARGIN
	bar.offset_bottom = -MARGIN
	hint.offset_top = -MARGIN - bar.size.y - 6.0
	hint.offset_bottom = hint.offset_top


static func place(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, orr: float, ob: float) -> Control:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob
	return c


## A colour made readable as text on the panels of the current appearance: on light panels a saturated light colour
## (a role's, a scenario's) is darkened until it holds AA contrast; on dark panels a saturated dark one is lightened.
## Neutrals pass unchanged.
static func ink(c: Color) -> Color:
	if c.s < 0.3:
		return c
	var out := c
	if mode == "light":
		for i in 12:
			if out.get_luminance() <= 0.33:
				break
			out = out.darkened(0.12)
	else:
		for i in 12:
			if out.get_luminance() >= 0.5:
				break
			out = out.lightened(0.12)
	out.a = c.a
	return out


## Text drawn straight on the 3D scene (no panel behind it) made readable over anything, bright clouds and white
## pads included: a dark outline and a soft shadow, both in proportion to its size. Returns the label.
static func legible(l: Label, k := 1.0) -> Label:
	var fs: int = l.get_theme_font_size("font_size")
	if l.has_theme_font_size_override("font_size"):
		fs = l.get_theme_font_size("font_size")
	l.add_theme_constant_override("outline_size", maxi(4, int(fs * 0.16 * k)))
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.04, 0.85))
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(2, int(fs * 0.05)))
	l.add_theme_constant_override("shadow_outline_size", maxi(6, int(fs * 0.3 * k)))
	return l


static func lbl(text: String, size := 16, color := C_TEXT, font: Font = FONT_R, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ink(color))
	l.add_theme_font_override("font", font)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func btn(text: String, cb: Callable, size := 16, min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func(): UiSound.play("click"))
	b.pressed.connect(cb)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if min_w > 0.0:
		b.custom_minimum_size.x = min_w
	return b


## Colors a button (the main action, the selected option): filled with the colour, its text white or dark, whichever
## reads better on it; returns it.
static func accent_btn(b: Button, col: Color) -> Button:
	b.add_theme_stylebox_override("normal", flat(col, col.darkened(0.18), 7, 1, 18, 10))
	b.add_theme_stylebox_override("hover", flat(col.lightened(0.1), col.darkened(0.3), 7, 1, 18, 10))
	b.add_theme_stylebox_override("pressed", flat(col.darkened(0.12), col.darkened(0.4), 7, 1, 18, 10))
	var fg := Color(0.03, 0.06, 0.13) if col.get_luminance() > 0.45 else Color.WHITE
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fg)
	return b


## A frosted-glass panel over the 3D scene: the scene behind it blurred and washed light, a hairline edge.
static func panel_box(pad := 16.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_theme_stylebox_override("panel", flat(C_BG, C_EDGE, 14, 1, pad, pad))
	p.material = frost()
	return p


## A card-like panel with a tinted border (a station's color, a status): the one place screens get that look from.
static func tile(border: Color, pad_x := 12.0, pad_y := 10.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(C_CARD, Color(border.r, border.g, border.b, 0.55), 8, 1, pad_x, pad_y))
	return p


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer(h := 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


## A selectable option. on_hover(title, text) is called when the mouse enters it (text is info_body, else body).
static func card(title: String, body: String, selected: bool, on_click: Callable, info_body := "", badge := "", badge_col := C_DIM, dimmed := false, on_hover := Callable()) -> PanelContainer:
	var pc := PanelContainer.new()
	var base_bg := C_CARD_SEL if selected else C_CARD
	var border := C_ACCENT if selected else C_LINE
	var sb := flat(base_bg, border, 8, 2 if selected else 1, 12, 9)
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var v := vbox(3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(v)
	var h := hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var t := lbl(("● " if selected else "○ ") + title, 16, C_ACCENT if selected else C_TEXT, FONT_B, true)
	h.add_child(t)
	if badge != "":
		var b := lbl(badge, 12, badge_col, FONT_B)
		h.add_child(b)
	if body != "":
		v.add_child(lbl(body, 13, C_DIM, FONT_R, true))
	if dimmed:
		pc.modulate = Color(1, 1, 1, 0.55)
	pc.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			UiSound.play("select")
			on_click.call())
	pc.mouse_entered.connect(func():
		sb.bg_color = C_CARD_HOVER if not selected else base_bg.lightened(0.04)
		if on_hover.is_valid():
			on_hover.call(title, info_body if info_body != "" else body))
	pc.mouse_exited.connect(func(): sb.bg_color = base_bg)
	return pc


## A short message at the top center that fades out; it lives in `parent` (a screen), so it goes with it.
static func toast(parent: Control, text: String, col := C_ACCENT, time := 2.5, top := 122.0) -> void:
	UiSound.play("error" if col == C_BAD else "notify")
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(Color(C_BG.r, C_BG.g, C_BG.b, 0.97), col, 10, 2, 18, 12))
	p.add_child(lbl(text, 16, col, FONT_B))
	place(p, 0.5, 0, 0.5, 0, -300, top, 300, top + 54.0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(time)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


## A dimmed full-screen layer with a centered panel, a title and a close button; returns the panel's box to fill.
## The close button calls on_close, or removes the layer when none is given.
static func overlay(parent: Control, title: String, w := 900.0, h := 640.0, on_close := Callable()) -> VBoxContainer:
	var shade := ColorRect.new()
	shade.color = C_SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(shade)
	var p := panel_box(14 if compact else 24)
	var room: Vector2 = parent.get_viewport_rect().size - Vector2(2.0 * MARGIN, 2.0 * MARGIN)
	w = minf(w, room.x)
	h = minf(h, room.y)   # never taller or wider than the screen it is on (a phone in landscape)
	place(p, 0.5, 0.5, 0.5, 0.5, -w / 2.0, -h / 2.0, w / 2.0, h / 2.0)
	shade.add_child(p)
	var v := vbox(10)
	p.add_child(v)
	var hh := hbox(8)
	v.add_child(hh)
	var t := lbl(title, 22 if compact else 28, C_TEXT, FONT_T)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(t)
	var close: Callable = on_close if on_close.is_valid() else shade.queue_free
	hh.add_child(btn(TranslationServer.translate("Close ×"), close, 14))
	return v


# ===================================================================================== NUMBERS
static func pct(x: float) -> String:
	return "%d %%" % int(round(x * 100.0))


static func money(x: float) -> String:
	if x >= 100.0:
		return "%.0f M$" % x
	if x >= 1.0:
		return "%.1f M$" % x
	return "%.2f M$" % x


static func kg(x: float) -> String:
	if x >= 1000.0:
		return "%.2f t" % (x / 1000.0)
	if x >= 10.0:
		return "%.0f kg" % x
	return "%.1f kg" % x


static func watts(x: float) -> String:
	if x >= 1000.0:
		return "%.1f kW" % (x / 1000.0)
	return "%.0f W" % x


static func gb(x: float) -> String:
	if x >= 10.0:
		return "%.0f GB" % x
	if x >= 0.1:
		return "%.1f GB" % x
	if x <= 0.0:
		return "0 GB"
	if x >= 0.001:
		return "%d MB" % roundi(x * 1000.0)   # small amounts in MB: "0.004 GB" reads as nothing at all
	return "<1 MB"


## Minutes as "45 min", "1.5 h" or "24 h".
static func mins(m: float) -> String:
	if m >= 1440.0:
		return "24 h"
	if m >= 60.0:
		return "%.1f h" % (m / 60.0)
	if m <= 0.0:
		return "0 min"
	return "%d min" % int(m)


# ===================================================================================== SHARED COMPONENTS (#31)
## A small spaced section label in capitals ("DIFFICULTY", "TIME").
static func caps(text: String) -> Label:
	var f := FontVariation.new()
	f.base_font = FONT_B
	f.spacing_glyph = 2
	return lbl(text.to_upper(), T_CAPS, C_DIM, f)


## A hairline across a panel.
static func rule() -> Control:
	var r := ColorRect.new()
	r.color = C_LINE
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A row of joined choices (a segmented control): add buttons made with choice().
static func segmented() -> HBoxContainer:
	return hbox(4)


## One choice of a segmented control; `on` marks the chosen one in the accent colour.
static func choice(text: String, on: bool, cb: Callable, min_w := 0.0) -> Button:
	var b := btn(text, cb, T_BODY, min_w)
	b.custom_minimum_size.y = BTN_H - 4
	b.focus_mode = Control.FOCUS_NONE
	if on:
		accent_btn(b, C_ACCENT)
	return b


## A stat card: a title, a big number in the status colour, a note under it (the builder's "Carries to SSO").
static func stat(title: String, value: String, note: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(C_CARD, col.darkened(0.3), 8, 2))
	var v := vbox(2)
	p.add_child(v)
	v.add_child(lbl(title, T_SMALL, C_DIM, FONT_B))
	v.add_child(lbl(value, T_STAT, ink(col), FONT_T))
	if note != "":
		v.add_child(lbl(note, T_SMALL - 1, C_DIM, FONT_R, true))
	return p


## A label and its value on one row of a readout grid (a GridContainer of two columns); returns the value label.
static func readout(grid: GridContainer, label: String) -> Label:
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 6)
	grid.add_child(lbl(label, T_BODY, C_DIM, FONT_R))
	var v := lbl("", T_VALUE, C_TEXT, font_num())
	grid.add_child(v)
	return v


## A frosted box for a plain-words hint, with its label (set the label's text; hide the box when empty).
static func hint_box() -> Array:
	var p := panel_box(10 if compact else 18)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := lbl("", T_LEAD, C_TEXT, FONT_R, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return [p, l]


## A small pill for one fact ("220 M$", "3 yr"): a few of these replace a sentence.
static func chip(text: String, col := C_ACCENT) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", flat(Color(col.r, col.g, col.b, 0.12), Color(col.r, col.g, col.b, 0.45), 12, 1, 11, 4))
	p.add_child(lbl(text, T_SMALL, col, FONT_B))
	return p


## A picture that fills its box whatever its shape (cropped, never stretched), `h` pixels tall. `region` (in the
## texture's pixels) shows only that part of it, for a view cut from a global map.
static func cover(tex: Texture2D, h: float, region := Rect2()) -> TextureRect:
	var t := TextureRect.new()
	if region.size.x > 0.0:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = region
		tex = a
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.custom_minimum_size = Vector2(0, h)
	t.clip_contents = true
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## A line of a menu drawn straight on the scene: no box, the words alone; under the pointer a warm bar lights at its
## left and the line brightens. For lists where the scene behind should stay in view (the main menu).
static func menu_item(text: String, cb: Callable, size := T_ACTION) -> Button:
	var b := btn(text, cb, size)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var clear := Color(0, 0, 0, 0)
	for st in ["normal", "hover", "pressed", "focus"]:   # the keyboard's focus looks as the pointer's hover
		var sb := StyleBoxFlat.new()
		sb.bg_color = clear if st == "normal" else Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.2 if st == "pressed" else 0.1)
		sb.border_color = clear if st == "normal" else C_GOLD
		sb.border_width_left = 3
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 7
		sb.content_margin_bottom = 7
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color(C_ON_DARK, 0.82))
	b.add_theme_color_override("font_hover_color", C_ON_DARK)
	b.add_theme_color_override("font_pressed_color", C_ON_DARK)
	b.add_theme_font_override("font", FONT_B)
	return b


## A font with its letters spaced by `px` (labels in capitals).
static func spaced(font: Font, px: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = font
	f.spacing_glyph = px
	return f
