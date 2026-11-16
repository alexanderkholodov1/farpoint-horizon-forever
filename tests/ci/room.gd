extends SceneTree
## Room test: the stations with their bots on one screen, and the online room's protocol (create, join, take a station,
## edit, sign off, launch) between a host and a guest over the in-memory transport. No browser needed; the real
## Firebase round trip is tested in a browser (see docs/guides/architecture.md, Room). Run:
##   tools/dev/godot.sh --headless --path . -s res://tests/ci/room.gd
## check: ok room
const GD := preload("res://scripts/core/game_data.gd")

var fails := 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL ", what)


func _initialize() -> void:
	var RoomLocal = load("res://scripts/net/room_local.gd")
	var RoomOnline = load("res://scripts/net/room_online.gd")
	var Mem = load("res://scripts/net/transport_memory.gd")
	var Mission = load("res://scripts/core/mission.gd")
	var Bots = load("res://scripts/crew/bots.gd")

	# ---- one screen, one player with three bots
	var m = Mission.new()
	m.scenario = "luna"
	m.bus = "cube6"
	m.panels = "body"
	m.battery = "b20"
	m.comms = "uhf"
	m.adcs = "mag"
	m.propulsion = "none"
	m.launcher = "ride"
	m.orbit = "sso"
	var r = RoomLocal.new()
	r.local_mission = func(): return m.to_dict()
	r.changed.connect(func(_by): m.from_dict(r.state.mission))
	r.submit({"k": "set_stations", "s": {"pilot": {"kind": "human", "pid": r.me, "name": "Ana"}}})
	r.start_design(m.to_dict())
	check(r.holder_name("pilot") == "Ana" and r.holder_name("engineer") == "Rumi", "holders")
	m.orbit = "lunar"   # the pilot is the person: the orbit is theirs to choose
	r.design_edited("orbita")
	for st in GD.STEPS:
		r.enter_step(st.id)
	var c: Dictionary = m.compute()
	check(not c.fatal, "bots' design has nothing red")
	check(r.state.bot_lines.has("plataforma") and r.state.bot_lines.has("lanzador"), "bots said a line")
	check(not r.state.bot_lines.has("orbita"), "the person's own station gets no bot line")
	check(r.state.approvals.has("engineer") and r.state.approvals.has("ground") and not r.state.approvals.has("pilot"), "bots signed, the person did not")
	check(r.holder("engineer").kind == "bot", "engineer is a bot")
	for k in r.state.bot_lines:
		var t: String = Bots.say(r.state.bot_lines[k].line)
		check(t != "" and not "%" in t, "line readable: " + k)
	# a person's edit on a bot's step stays, and voids the sign-offs
	m.bus = "large"
	r.design_edited("plataforma")
	check(r.state.mission.bus == "large" and r.state.approvals.is_empty() and r.state.touched.has("plataforma"), "edit on a bot step")
	r.enter_step("plataforma")
	check(r.state.mission.bus == "large", "bot leaves a touched step alone")
	m.bus = "medium"   # large is over the budget: red, so nobody signs
	r.design_edited("plataforma")
	r.enter_step("revision")
	check(r.state.approvals.has("engineer"), "bots sign again at the review")

	# ---- online: host and guest over the memory transport
	var h = RoomOnline.new()
	h.transport = Mem.new()
	var hm := {}
	h.local_mission = func(): return hm
	h.create("Host")
	h.poll(true)
	check(h.code.length() == 5 and Mem.rooms.has(h.code), "room created with a code")
	var g = RoomOnline.new()
	g.transport = Mem.new()
	var seen: Array = []
	g.changed.connect(func(by): seen.append(by))
	g.join("NOPE1", "Guest")
	g.poll(true)
	check(g.code == "", "joining a missing room fails")
	g.join(h.code.to_lower(), "Guest")
	g.poll(true)
	h.poll(true)
	check(h.state.members.size() == 2, "host sees both members")
	g.poll(true)
	check(g.state.members.size() == 2 and g.state.code == h.code, "guest mirrors the state")
	g.take("scientist")
	h.poll(true)
	g.poll(true)
	check(g.mine("scientist") and h.holder("scientist").pid == g.me, "guest took the scientist")
	h.take("scientist")   # already held by the guest: refused
	check(h.holder("scientist").pid == g.me, "a held station is not taken from its holder")
	check(not g.can_edit("engineer") == false and g.can_edit("scientist") and not h.can_edit("scientist"), "edit rights")
	h.take("engineer")
	hm = {"scenario": "volcanes", "difficulty": "normal", "orbit": "sso", "bus": "small", "instruments": ["ir_adv"], "panels": "dep_m", "battery": "b1k", "comms": "xband", "adcs": "rw", "propulsion": "cold", "launcher": "ride", "years": 2, "redundancy": false, "shielding": false}
	h.start_design(hm)
	g.poll(true)
	check(g.state.phase == "design" and g.state.mission.bus == "small", "guest follows the host into the design")
	g.submit({"k": "patch", "f": {"instruments": ["ir_adv", "cam_ms"]}, "step": "instrumentos"})
	h.poll(true)
	g.poll(true)
	check(h.state.mission.instruments.size() == 2 and g.state.mission.instruments.size() == 2 and g.state.touched.has("instrumentos"), "guest's edit reaches the host and comes back")
	g.sign("scientist")
	h.poll(true)
	g.poll(true)
	check(g.state.approvals.has("scientist"), "sign-off travels")
	g.request_launch(1234)
	h.poll(true)
	g.poll(true)
	check(h.state.launch.n == 1 and g.state.launch.seed == 1234, "launch reaches both with one seed")
	g.leave()
	h.poll(true)
	check(h.state.members.size() == 1 and h.holder("scientist").kind == "bot", "a leaving guest hands the station to its bot")
	print("ok room" if fails == 0 else "FAILED room %d" % fails)
	quit(0 if fails == 0 else 1)
