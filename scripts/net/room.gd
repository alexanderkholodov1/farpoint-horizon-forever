extends RefCounted
## The room: the state a crew shares (who holds which station, the design, the sign-offs, the bots' lines, the launch)
## and the one way to change it. Screens never edit the shared state: they call `submit(op)` and read `state`.
##
## Two implementations extend this class: RoomLocal (same screen or solo, no network) and RoomOnline (Firebase
## Realtime Database through the page's JavaScript). Both run the same rules in `apply_op`.
##
## Authority: the HOST (the room's creator, or the only machine in a local room) is the only one that runs `apply_op`,
## the bots and the rules, and the only one that publishes `state`. Everyone else sends an op and mirrors the state it
## receives. So two people editing at once never fight over the rules: the host orders their ops.
##
## State (a plain dictionary, so it travels as JSON):
##   rev        number of changes so far
##   mode       "solo" | "same" | "online"
##   code       the room code ("" in local rooms)
##   phase      "lobby" | "design"  (guests follow the host into the design)
##   members    pid -> name of the players in the room
##   stations   station id -> {"kind": "bot"} or {"kind": "human", "pid", "name"}
##   mission    Mission.to_dict() of the shared design
##   approvals  station id -> true once it signed off
##   bot_lines  step id -> {"station", "line": {"t", "a"}}, what the bot of that step said (see crew/bots.gd)
##   touched    step id -> true once a person edited that step (the bot then leaves it alone)
##   launch     {"seed", "n"}: n grows at every launch, the seed makes every client fly the same random events
## Ops (dictionaries with "k"): take, release, set_stations, join, members, patch, enter, sign, clear, phase, launch.

const GD := preload("res://scripts/core/game_data.gd")
const Bots := preload("res://scripts/crew/bots.gd")

## Emitted after every change of the state; by_me is true when this machine's own op caused it.
signal changed(by_me: bool)
## Emitted when the room cannot do what was asked (no such room, no network): a text for the player.
signal failed(text: String)

var code := ""
var me := ""                     ## This machine's member id.
var my_name := ""
var mode := "solo"
var state := {}
## () -> Dictionary: the design this machine edits (Mission.to_dict()). The host reads it before applying any op, so a
## design edited directly (without going through `patch`) is never lost. Set by GameState.
var local_mission := Callable()
var _last_enter := ""


func _init() -> void:
	me = "p%d%d" % [Time.get_ticks_usec() % 100000, randi() % 1000]
	state = blank_state("solo", "")


static func blank_state(mode_: String, code_: String) -> Dictionary:
	var stations := {}
	for st in GD.ROLE_ORDER:
		stations[st] = {"kind": "bot"}
	return {"rev": 0, "mode": mode_, "code": code_, "phase": "lobby", "members": {}, "stations": stations, "mission": {},
		"approvals": {}, "bot_lines": {}, "touched": {}, "launch": {"seed": 0, "n": 0}}


# ===================================================================================== INTERFACE
func is_host() -> bool:
	return true


func is_online() -> bool:
	return false


## Called every frame by GameState (the online room reads its messages here).
func poll(force := false) -> void:
	pass


## Leaves the room.
func leave() -> void:
	pass


## Sends an op: the host applies it, a guest passes it to the host. See `apply_op` for the ops.
func submit(op: Dictionary) -> void:
	if apply_op(op):
		publish()
	changed.emit(true)


## Writes the state where the guests read it (online host only).
func publish() -> void:
	pass


## The holder of a station: {"kind": "bot"} or {"kind": "human", "pid", "name"}.
func holder(st: String) -> Dictionary:
	return state.stations.get(st, {"kind": "bot"})


func is_bot(st: String) -> bool:
	return holder(st).kind == "bot"


## The name shown for the station's holder: the player, or the bot.
func holder_name(st: String) -> String:
	var h := holder(st)
	return h.name if h.kind == "human" else Bots.NAMES.get(st, "Bot")


func mine(st: String) -> bool:
	var h := holder(st)
	return h.kind == "human" and h.pid == me


## How many people hold at least one station.
func human_count() -> int:
	var pids := {}
	for st in state.stations:
		if state.stations[st].kind == "human":
			pids[state.stations[st].pid] = true
	return pids.size()


## Can this machine change the decisions of a station? Anyone can on one screen; online, only the holder, and anyone
## for a station a bot holds (a solo player can always change what a bot chose).
func can_edit(st: String) -> bool:
	return true


# ----------------------------------------------------- shortcuts for the screens
func take(st: String, force := false) -> void:
	submit({"k": "take", "st": st, "pid": me, "name": my_name, "force": force})


func release(st: String) -> void:
	submit({"k": "release", "st": st, "pid": me})


func sign(st: String, value := true) -> void:
	submit({"k": "sign", "st": st, "v": value})


## The design was edited on a step: tells the room (it keeps the fields that differ from the shared design).
func design_edited(step_id: String) -> void:
	var cur: Dictionary = local_mission.call() if local_mission.is_valid() else {}
	var patch := {}
	for k in cur:
		if state.mission.get(k) != cur[k]:
			patch[k] = cur[k]
	submit({"k": "patch", "f": patch, "step": step_id})


## A step is shown: the bot that holds it makes its choice (once per state of the design).
func enter_step(step_id: String) -> void:
	var cur: Dictionary = local_mission.call() if local_mission.is_valid() else state.mission
	var key := step_id + str(cur.hash()) + str(state.approvals.hash())
	if key == _last_enter:
		return
	_last_enter = key
	submit({"k": "enter", "step": step_id})
	_last_enter = step_id + str((local_mission.call() if local_mission.is_valid() else state.mission).hash()) + str(state.approvals.hash())


func start_design(mission_dict: Dictionary) -> void:
	_last_enter = ""
	submit({"k": "phase", "p": "design", "m": mission_dict})


func request_launch(seed_value: int) -> void:
	submit({"k": "launch", "seed": seed_value})


# ===================================================================================== RULES (host)
## Applies an op to the state. Returns true when the state changed (and then `rev` grew). Only the host calls this.
func apply_op(op: Dictionary) -> bool:
	var before := JSON.stringify(state)
	_pull_local_mission(op)
	match op.get("k", ""):
		"take":
			var st: String = op.st
			var h := holder(st)
			if state.stations.has(st) and (h.kind == "bot" or h.pid == op.pid or op.get("force", false)):
				state.stations[st] = {"kind": "human", "pid": op.pid, "name": String(op.name).substr(0, 24)}
		"release":
			if state.stations.has(op.st) and (holder(op.st).get("pid", "") == op.pid or op.get("force", false)):
				state.stations[op.st] = {"kind": "bot"}
		"set_stations":
			for st in op.s:
				if state.stations.has(st):
					state.stations[st] = op.s[st]
		"join":
			state.members[op.pid] = String(op.name).substr(0, 24)
		"members":
			state.members = op.m
			for st in state.stations:
				var h := holder(st)
				if h.kind == "human" and not op.m.has(h.pid):
					state.stations[st] = {"kind": "bot"}
		"patch":
			var changed_fields := false
			for k in op.f:
				if state.mission.get(k) != op.f[k]:
					state.mission[k] = op.f[k]
					changed_fields = true
			if op.get("step", "") != "":
				state.touched[op.step] = true
			if changed_fields:
				state.approvals = {}
		"enter":
			_bots_enter(op.step)
		"sign":
			if op.v:
				state.approvals[op.st] = true
			else:
				state.approvals.erase(op.st)
		"clear":
			state.approvals = {}
		"phase":
			state.phase = op.p
			if op.has("m"):
				state.mission = op.m
				state.touched = {}
				state.bot_lines = {}
				state.approvals = {}
		"launch":
			state.launch = {"seed": int(op.seed), "n": int(state.launch.n) + 1}
	var after := JSON.stringify(state)
	if after == before:
		return false
	state.rev = int(state.rev) + 1
	return true


## The host's own edits made outside an op are part of the shared design before the op runs.
func _pull_local_mission(op: Dictionary) -> void:
	if not is_host() or not local_mission.is_valid() or op.get("k", "") == "phase":
		return
	var cur: Dictionary = local_mission.call()
	for k in cur:
		if state.mission.get(k) != cur[k]:
			state.mission[k] = cur[k]
			state.approvals = {}


func _bots_enter(step_id: String) -> void:
	if state.mission.is_empty():
		return
	var st := ""
	for s in GD.STEPS:
		if s.id == step_id:
			st = s.role
	if st == "" or step_id == "revision":
		_bots_review()
		return
	if not is_bot(st) or state.touched.get(step_id, false):
		return
	var m = _mission()
	var res: Dictionary = Bots.act(step_id, m, state.touched)
	if res.line.is_empty():
		return   # a step the bots do not know
	for k in res.patch:
		state.mission[k] = res.patch[k]
	state.bot_lines[step_id] = {"station": st, "line": res.line}
	if not res.patch.is_empty():
		state.approvals = {}


## At the review every bot signs unless something is red.
func _bots_review() -> void:
	var r: Dictionary = _mission().compute()
	for st in state.stations:
		if not is_bot(st):
			continue
		var res: Dictionary = Bots.review(st, r)
		if res.sign:
			state.approvals[st] = true
		else:
			state.approvals.erase(st)
		state.bot_lines["revision_" + st] = {"station": st, "line": res.line}


func _mission():
	var m = load("res://scripts/core/mission.gd").new()
	m.from_dict(state.mission)
	return m
