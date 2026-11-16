extends "res://scripts/screens/screen.gd"
## The lobby: how the crew plays (Solo, Same screen, Online), and who holds which station. Free stations are held by
## their bot, which is shown on the card. The room itself is scripts/net/room.gd.
## args: {"view": "solo" | "same" | "online"}; without it, the choice of how to play. {"players": n} opens the
## same-screen view for n players (kept for the walkthrough tests).

const Bots := preload("res://scripts/crew/bots.gd")

var _name_edit: LineEdit
var _code_edit: LineEdit
var _in_room := false


func enter(args: Dictionary) -> void:
	if args.has("players"):
		_show_same(int(args.players))
		return
	match args.get("view", ""):
		"solo": _show_solo()
		"same": _show_same(2)
		"online": _show_online()
		_: _show_home()


func exit() -> void:
	if GameState.room.changed.is_connected(_on_room_changed):
		GameState.room.changed.disconnect(_on_room_changed)
	if GameState.room_failed.is_connected(_on_failed):
		GameState.room_failed.disconnect(_on_failed)


func _frame(w: float, h: float, title: String, intro: String) -> VBoxContainer:
	clear()
	var p := Kit.panel_box(26)
	Kit.place(p, 0.5, 0.5, 0.5, 0.5, -w / 2, -h / 2, w / 2, h / 2)
	add_child(p)
	var v := Kit.vbox(10)
	p.add_child(v)
	v.add_child(Kit.lbl(title, 30, Kit.C_TEXT, Kit.FONT_T))
	if intro != "":
		v.add_child(Kit.lbl(intro, 15, Kit.C_DIM, Kit.FONT_R, true))
	return v


## The steps a station decides, as a line of titles.
func _steps_of(st: String) -> String:
	var t: Array = []
	for s in GameData.STEPS:
		if s.role == st:
			t.append(s.title)
	return " · ".join(PackedStringArray(t))


# ===================================================================================== HOME
func _show_home() -> void:
	var v := _frame(700, 620, tr("Your crew"), tr("A mission is a team effort. You have four stations, each with its cuy: Rumi the engineer, Killa the scientist, Inti the pilot and Wayra at ground control. Friends take the stations they like, and the cuyes take the rest, so you never fly alone."))
	var opts := [
		[tr("Solo"), tr("You take one station. Three cuyes take the others and work with you."), "solo", Kit.C_GOLD],
		[tr("Same screen"), tr("Two to four people on one computer, passing the screen. Free stations get their cuy."), "same", null],
		[tr("Online"), tr("Create a room, share its code, and up to four friends join from their own browsers."), "online", null]]
	for o in opts:
		var b := Kit.btn(o[0], func(): go("team", {"view": o[2]}), 22, 640)
		if o[3] != null:   # one main action: playing alone, the quickest way in
			Kit.accent_btn(b, o[3])
		v.add_child(b)
		v.add_child(Kit.lbl(o[1], 14, Kit.C_DIM, Kit.FONT_R, true))
	# the first mission, guided by the crew, is a way in too: it lives here with the other ways to play
	var guided := Kit.btn(tr("Guided first mission"), func(): preload("res://scripts/tutorial/coach.gd").start(main), 22, 640)
	v.add_child(guided)
	v.add_child(Kit.lbl(tr("New to space missions? The crew walks you through your first one, station by station."), 14, Kit.C_DIM, Kit.FONT_R, true))
	v.add_child(Kit.spacer(6))
	v.add_child(Kit.btn(tr("◀ Back"), func(): go("menu")))


# ===================================================================================== SOLO
func _show_solo() -> void:
	var v := _frame(1000, 600, tr("Pick your station"), tr("You run one station. The cuyes take the other three, and you can open any station and change what a cuy chose."))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	for st in GameData.ROLE_ORDER:
		grid.add_child(_station_card(st, func():
			GameState.start_solo(st)
			go("missions"), tr("Take this station")))
	v.add_child(Kit.btn(tr("◀ Back"), func(): go("team")))


## A card of a station: its name, goal, steps and who would hold it. pick runs when the button is pressed.
func _station_card(st: String, pick: Callable, button_text: String, holder_text := "") -> PanelContainer:
	var R: Dictionary = GameData.ROLES[st]
	var pc := Kit.tile(R.color)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cv := Kit.vbox(3)
	pc.add_child(cv)
	var top := Kit.hbox(10)
	top.add_child(_portrait(st, 52))
	top.add_child(Kit.lbl(R.name + "  ·  " + Bots.NAMES[st], 20, R.color, Kit.FONT_T))
	cv.add_child(top)
	cv.add_child(Kit.lbl(tr("Decides") + " · " + _steps_of(st), 13, Kit.C_TEXT, Kit.FONT_B, true))
	cv.add_child(Kit.lbl(tr("Goal") + " · " + R.goal, 13, Kit.C_DIM, Kit.FONT_R, true))
	if holder_text != "":
		cv.add_child(Kit.lbl(holder_text, 14, Kit.C_ACCENT, Kit.FONT_B, true))
	if button_text != "":
		cv.add_child(Kit.accent_btn(Kit.btn(button_text, pick, 15), R.color))
	return pc


# ===================================================================================== SAME SCREEN
func _show_same(n: int) -> void:
	var v := _frame(1000, 640, tr("Same screen"), tr("Type your names and choose who takes each station. Pass the screen when it is your station's turn. Stations nobody takes stay with their cuy."))
	var count := Kit.hbox(8)
	v.add_child(count)
	count.add_child(Kit.lbl(tr("How many players?"), 15, Kit.C_TEXT, Kit.FONT_B))
	for k in [2, 3, 4]:
		var b := Kit.btn(tr("%d players") % k, func(): go("team", {"players": k}), 15, 120)
		if k == n:
			Kit.accent_btn(b, Kit.C_ACCENT)
		count.add_child(b)
	var edits: Array = []
	for i in n:
		var e := LineEdit.new()
		e.text = tr("Player %d") % (i + 1)
		e.custom_minimum_size = Vector2(240, 0)
		var row := Kit.hbox(10)
		row.add_child(Kit.lbl(tr("Player %d") % (i + 1), 14, Kit.C_DIM, Kit.FONT_B))
		row.add_child(e)
		v.add_child(row)
		edits.append(e)
	v.add_child(HSeparator.new())
	var picks := {}
	for st in GameData.ROLE_ORDER:
		var R: Dictionary = GameData.ROLES[st]
		var row := Kit.hbox(10)
		row.add_child(_portrait(st, 34))
		var l := Kit.lbl(R.name, 17, R.color, Kit.FONT_B)
		l.custom_minimum_size.x = 150
		row.add_child(l)
		var ob := OptionButton.new()
		for i in n:
			ob.add_item(tr("Player %d") % (i + 1))
		ob.add_item(tr("%s, the cuy") % Bots.NAMES[st])
		ob.select(GameData.ROLE_ORDER.find(st) if GameData.ROLE_ORDER.find(st) < n else n)
		ob.custom_minimum_size.x = 260
		row.add_child(ob)
		var d := Kit.lbl(_steps_of(st), 13, Kit.C_DIM, Kit.FONT_R, true)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(d)
		picks[st] = ob
		v.add_child(row)
	v.add_child(Kit.spacer(6))
	var h := Kit.hbox(10)
	v.add_child(h)
	h.add_child(Kit.btn(tr("◀ Back"), func(): go("team")))
	h.add_child(Kit.accent_btn(Kit.btn(tr("Continue ▶"), func():
		var humans: Array = []
		for i in n:
			var nm: String = edits[i].text.strip_edges()
			humans.append({"name": nm if nm != "" else tr("Player %d") % (i + 1), "stations": []})
		for st in picks:
			var idx: int = picks[st].selected
			if idx < n:
				humans[idx].stations.append(st)
		humans = humans.filter(func(p): return not p.stations.is_empty())
		if humans.is_empty():
			toast(tr("Someone has to take at least one station."), Kit.C_WARN)
			return
		GameState.start_crew("same", humans)
		go("missions"), 18), Kit.C_ACCENT))


# ===================================================================================== ONLINE
func _show_online() -> void:
	var v := _frame(760, 520, tr("Online room"), tr("One of you creates a room and shares its code. The others type it and join. Everybody picks a station; the cuyes take the free ones."))
	if not GameState.TransportWeb.available():
		v.add_child(Kit.lbl(tr("Online rooms work in the web version of the game. This build can play solo or on one screen."), 16, Kit.C_WARN, Kit.FONT_B, true))
		v.add_child(Kit.btn(tr("◀ Back"), func(): go("team")))
		return
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 10)
	v.add_child(nr)
	nr.add_child(Kit.lbl(tr("Your name"), 15, Kit.C_TEXT, Kit.FONT_B))
	_name_edit = LineEdit.new()
	_name_edit.text = tr("Player")
	_name_edit.max_length = 20
	_name_edit.custom_minimum_size = Vector2(260, 0)
	nr.add_child(_name_edit)
	v.add_child(Kit.accent_btn(Kit.btn(tr("Create a room"), func(): _begin(true), 20, 400), Kit.C_ACCENT))
	v.add_child(Kit.lbl(tr("or join a friend's room"), 14, Kit.C_DIM))
	var jr := Kit.hbox(10)
	v.add_child(jr)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = tr("Room code")
	_code_edit.max_length = 6
	_code_edit.custom_minimum_size = Vector2(200, 0)
	jr.add_child(_code_edit)
	jr.add_child(Kit.accent_btn(Kit.btn(tr("Join"), func(): _begin(false), 18, 140), Kit.C_ACCENT))
	v.add_child(Kit.spacer(8))
	v.add_child(Kit.btn(tr("◀ Back"), func(): go("team")))


func _begin(create: bool) -> void:
	var nm := _name_edit.text.strip_edges()
	if nm == "":
		nm = tr("Player")
	var r = GameState.new_online_room()
	if r == null:
		return
	GameState.room_failed.connect(_on_failed)
	r.changed.connect(_on_room_changed)
	if create:
		r.create(nm)
	else:
		if _code_edit.text.strip_edges().length() < 4:
			toast(tr("Type the room code first."), Kit.C_WARN)
			return
		r.join(_code_edit.text, nm)
	_in_room = true
	_show_room()


func _on_failed(text: String) -> void:
	toast(text, Kit.C_BAD, 4.0)
	_in_room = false
	_show_online()


func _on_room_changed(_by_me: bool) -> void:
	if _in_room and GameState.room.state.phase == "lobby":
		_show_room()


## The room view: the code, the people, and the four stations with their holders.
func _show_room() -> void:
	var room = GameState.room
	var v := _frame(1000, 660, tr("Room") + " " + room.code, tr("Share this code with your friends. Each one takes a station; the free ones stay with their cuy."))
	var people: Array = []
	for pid in room.state.members:
		people.append(room.state.members[pid])
	v.add_child(Kit.lbl(tr("In the room") + " · " + (", ".join(PackedStringArray(people)) if not people.is_empty() else tr("connecting...")), 15, Kit.C_TEXT, Kit.FONT_B, true))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	for st in GameData.ROLE_ORDER:
		var h: Dictionary = room.holder(st)
		var who: String
		var label := ""
		var cb: Callable
		if h.kind == "bot":
			who = tr("%s, the cuy") % Bots.NAMES[st]
			label = tr("Take this station")
			cb = func(): room.take(st)
		elif room.mine(st):
			who = tr("You") + " · " + h.name
			label = tr("Give it to its cuy")
			cb = func(): room.release(st)
		else:
			who = h.name
		grid.add_child(_station_card(st, cb, label, who))
	v.add_child(Kit.spacer(4))
	var hb := Kit.hbox(10)
	v.add_child(hb)
	hb.add_child(Kit.btn(tr("◀ Leave"), func():
		GameState.start_solo()
		_in_room = false
		go("team")))
	if room.is_host():
		hb.add_child(Kit.accent_btn(Kit.btn(tr("Pick the mission ▶"), func(): go("missions"), 18), Kit.C_ACCENT))
	else:
		hb.add_child(Kit.lbl(tr("Waiting for the host to pick the mission..."), 15, Kit.C_WARN, Kit.FONT_B))


## The cuy of a station: its round portrait from the story, size px.
func _portrait(st: String, size: float) -> Control:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path: String = Bots.PORTRAITS.get(st, "")
	if path != "" and ResourceLoader.exists(path):
		t.texture = load(path)
	return t
