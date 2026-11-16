extends "res://scripts/net/room.gd"
## The room on the network. `transport` is a TransportWeb in the browser (Firebase Realtime Database), or a
## TransportMemory in tests. The creator is the host (see room.gd): it applies every op and publishes the state at
## rooms/<code>/state; a guest writes its ops to rooms/<code>/ops and mirrors the state.
##
## Limits, said plainly: nothing here is secret or signed. Anyone who knows a code can read and write that room
## (database.rules.json checks sizes and shapes, not who writes), so a guest could publish a state and pretend to be the
## host. The code is the only key. A room stops when its host leaves (its tab closes): the guests keep their last state.

var transport
var host := false
var _t := 0
var _tries := 0

const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


func _init() -> void:
	super()
	mode = "online"
	state.mode = mode


func is_host() -> bool:
	return host


func is_online() -> bool:
	return true


func can_edit(st: String) -> bool:
	return is_bot(st) or mine(st)


## Creates a room with a fresh code and becomes its host.
func create(player_name: String) -> void:
	my_name = player_name
	host = true
	_tries = 0
	_try_create()


func _try_create() -> void:
	_tries += 1
	code = ""
	for i in 5:
		code += CODE_CHARS[randi() % CODE_CHARS.length()]
	state = blank_state("online", code)
	transport.create(code, me, my_name, JSON.stringify(state))


## Joins the room with that code as a guest.
func join(room_code: String, player_name: String) -> void:
	my_name = player_name
	host = false
	code = room_code.strip_edges().to_upper()
	transport.join(code, me, my_name)


func leave() -> void:
	if transport and code != "":
		transport.leave(code, me)
	code = ""


func submit(op: Dictionary) -> void:
	if host:
		if apply_op(op):
			publish()
		changed.emit(true)
	else:
		transport.send_op(code, me, JSON.stringify(op))


func publish() -> void:
	if host and code != "":
		transport.publish(code, JSON.stringify(state))


func poll(force := false) -> void:
	if transport == null:
		return
	var now := Time.get_ticks_msec()
	if not force and now - _t < 100:
		return
	_t = now
	for msg in transport.poll():
		_on_message(msg)


func _on_message(msg: Dictionary) -> void:
	match msg.get("t", ""):
		"taken":
			if _tries < 5:
				_try_create()
			else:
				failed.emit(tr("Could not create a room. Try again."))
		"nosuch":
			code = ""
			failed.emit(tr("No room with that code."))
		"error":
			failed.emit(tr("The room is not reachable right now: ") + str(msg.get("text", "")))
		"created", "joined":
			changed.emit(false)
		"members":
			if host:
				submit_members(msg.m)
		"op":
			if host:
				var op = JSON.parse_string(msg.o)
				if op is Dictionary:
					if apply_op(op):
						publish()
					changed.emit(false)
		"state":
			if not host:
				var s = JSON.parse_string(msg.s)
				if s is Dictionary:
					state = s
					changed.emit(false)


func submit_members(m: Dictionary) -> void:
	if apply_op({"k": "members", "m": m}):
		publish()
	changed.emit(false)
