extends RefCounted
## A pretend network in memory, with the same interface as TransportWeb: two rooms in one process talk through it.
## Used by tests/ci/room.gd to prove the online room's protocol without a browser; never used in the game.

static var rooms := {}   ## code -> {"state": String, "host": pid, "members": {pid: name}, "clients": {pid: TransportMemory}}

var inbox: Array = []
var pid := ""


func ready() -> bool:
	return true


func create(code: String, pid_: String, name: String, state_json: String) -> void:
	pid = pid_
	if rooms.has(code):
		inbox.append({"t": "taken"})
		return
	rooms[code] = {"state": state_json, "host": pid, "members": {pid: name}, "clients": {pid: self}}
	inbox.append({"t": "created"})
	inbox.append({"t": "members", "m": {pid: name}})


func join(code: String, pid_: String, name: String) -> void:
	pid = pid_
	if not rooms.has(code):
		inbox.append({"t": "nosuch"})
		return
	var r: Dictionary = rooms[code]
	r.members[pid] = name
	r.clients[pid] = self
	inbox.append({"t": "state", "s": r.state})
	inbox.append({"t": "joined"})
	r.clients[r.host].inbox.append({"t": "members", "m": r.members.duplicate()})


func send_op(code: String, _pid: String, op_json: String) -> void:
	if rooms.has(code):
		rooms[code].clients[rooms[code].host].inbox.append({"t": "op", "o": op_json})


func publish(code: String, state_json: String) -> void:
	if not rooms.has(code):
		return
	rooms[code].state = state_json
	for p in rooms[code].clients:
		if p != rooms[code].host:
			rooms[code].clients[p].inbox.append({"t": "state", "s": state_json})


func leave(code: String, _pid: String) -> void:
	if not rooms.has(code):
		return
	var r: Dictionary = rooms[code]
	r.members.erase(pid)
	r.clients.erase(pid)
	if r.host == pid:
		rooms.erase(code)
	elif r.clients.has(r.host):
		r.clients[r.host].inbox.append({"t": "members", "m": r.members.duplicate()})


func poll() -> Array:
	var out := inbox
	inbox = []
	return out
