extends RefCounted
## The online room's link to Firebase Realtime Database: the page's JavaScript (web/room_bridge.js, object FPRoom)
## talks to the database and keeps a queue of messages; Godot sends calls with JavaScriptBridge.eval and reads the queue
## with poll(). Strings are passed as JSON literals so no text can break the call. Only exists in the web build.
## Messages from the queue: {"t": "created"|"taken"|"joined"|"nosuch"|"error"}, {"t": "state", "s": json},
## {"t": "op", "o": json}, {"t": "members", "m": {pid: name}}.


static func available() -> bool:
	return OS.has_feature("web") and bool(JavaScriptBridge.eval("typeof window.FPRoom !== 'undefined' && window.FPRoom.ready()", true))


func ready() -> bool:
	return available()


func _call(fn: String, args: Array) -> Variant:
	var parts: Array = []
	for a in args:
		parts.append(JSON.stringify(a))
	return JavaScriptBridge.eval("FPRoom.%s(%s)" % [fn, ",".join(PackedStringArray(parts))], true)


func create(code: String, pid: String, name: String, state_json: String) -> void:
	_call("create", [code, pid, name, state_json])


func join(code: String, pid: String, name: String) -> void:
	_call("join", [code, pid, name])


func send_op(code: String, pid: String, op_json: String) -> void:
	_call("send_op", [code, pid, op_json])


func publish(code: String, state_json: String) -> void:
	_call("publish", [code, state_json])


func leave(code: String, pid: String) -> void:
	_call("leave", [code, pid])


func poll() -> Array:
	var raw := str(_call("pull", []))
	var arr = JSON.parse_string(raw)
	var out: Array = []
	if arr is Array:
		for s in arr:
			var m = JSON.parse_string(str(s))
			if m is Dictionary:
				out.append(m)
	return out
