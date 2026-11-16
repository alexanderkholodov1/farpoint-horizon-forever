extends RefCounted
## The interface's sounds (issue #12), synthesized here when first needed: no audio files, nothing from outside.
## The flight has its own sounds (scripts/flight/sound.gd, issue #8); both play on the Master bus, so the one mute
## silences everything. Quiet by default, a little different every time (pitch and level vary per play), and no sound
## on hover, as docs/design/criteria.md asks.
##   UiSound.play("click")
## Sounds: click (a button), select (an option chosen), snap (a part locks onto the rocket), error (something blocks),
## notify (a message), success (a mission well done), whoosh (a screen fading to the next).

const RATE := 22050
const SETTINGS_PATH := "user://settings.cfg"
const LEVEL := {"click": -20.0, "select": -17.0, "snap": -9.0, "error": -15.0, "notify": -19.0, "success": -12.0, "whoosh": -24.0}

static var _streams := {}
static var _pool: Array = []
static var _next := 0
static var _loaded := false


## Plays sound `id` once, with a slight random pitch so repeated presses do not sound mechanical.
static func play(id: String, pitch_jitter := 0.05) -> void:
	var p := _player()
	if p == null:
		return
	p.stream = _stream(id)
	p.volume_db = LEVEL.get(id, -18.0) + randf_range(-1.0, 1.0)
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## Mutes or unmutes every sound of the game (the Master bus, shared with the flight) and remembers it.
static func set_muted(m: bool) -> void:
	AudioServer.set_bus_mute(0, m)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("ui", "muted", m)
	cfg.save(SETTINGS_PATH)


static func is_muted() -> bool:
	return AudioServer.is_bus_mute(0)


## Applies the remembered mute once (called by Kit.build_theme at start).
static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		AudioServer.set_bus_mute(0, bool(cfg.get_value("ui", "muted", false)))


## A small pool of players under the scene tree's root, so a sound outlives the screen that asked for it.
static func _player() -> AudioStreamPlayer:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	if _pool.is_empty() or not is_instance_valid(_pool[0]):
		_pool.clear()
		var holder := Node.new()
		holder.name = "UiSound"
		tree.root.add_child.call_deferred(holder)
		for i in 6:
			var p := AudioStreamPlayer.new()
			holder.add_child(p)
			_pool.append(p)
		return null if not holder.is_inside_tree() else _pool[0]
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	if not p.is_inside_tree():
		return null
	return p


static func _stream(id: String) -> AudioStreamWAV:
	if not _streams.has(id):
		_streams[id] = _wav(_make(id))
	return _streams[id]


static func _make(id: String) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	match id:
		"click":
			# a short, bright tick with a little body under it
			return _mix(_tone([2100.0, 3150.0], 0.035, 0.001, 0.012), _tone([420.0], 0.04, 0.001, 0.02), 0.5)
		"select":
			return _cat(_tone([660.0, 990.0], 0.07, 0.003, 0.05), _tone([990.0, 1485.0], 0.11, 0.003, 0.08))
		"snap":
			# metal on metal: a damped low knock and a ringing overtone
			return _mix(_knock(rng, 0.25, 140.0), _tone([1240.0, 1873.0], 0.35, 0.001, 0.12), 0.35)
		"error":
			return _cat(_tone([220.0, 233.0], 0.11, 0.004, 0.06), _tone([196.0, 208.0], 0.16, 0.004, 0.1))
		"notify":
			return _tone([880.0, 1320.0], 0.18, 0.004, 0.12)
		"success":
			# a rising major chord, the notes entering one after another
			var a := _tone([523.25], 1.4, 0.01, 1.0)
			var b := _cat(_silence(0.09), _tone([659.25], 1.3, 0.01, 0.95))
			var c := _cat(_silence(0.18), _tone([783.99, 1046.5], 1.2, 0.01, 0.9))
			return _mix(_mix(a, b, 1.0), c, 1.0)
		"whoosh":
			return _swell(rng, 0.38)
		"fanfare":
			# the mission done: a swell, a quick rising arpeggio (C E G C) and a long open chord with a high fifth on top
			var run := _silence(0.0)
			var notes := [523.25, 659.25, 783.99, 1046.5]
			for i in notes.size():
				run = _mix(run, _cat(_silence(0.11 * i), _tone([notes[i], notes[i] * 2.0], 0.5, 0.005, 0.32)), 0.8)
			var chord := _cat(_silence(0.46), _tone([261.63, 392.0, 523.25, 659.25, 783.99, 1567.98], 2.6, 0.02, 1.7))
			return _mix(_mix(_swell(rng, 0.5), run, 1.0), chord, 0.9)
		"tick":
			return _tone([1800.0], 0.02, 0.001, 0.01)
		_:
			return _tone([440.0], 0.08, 0.004, 0.05)


# ===================================================================================== SYNTHESIS
## Sine partials with an attack and an exponential decay (seconds).
static func _tone(freqs: Array, seconds: float, attack: float, decay: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / maxf(attack, 0.0001)) * exp(-t / maxf(decay, 0.0001))
		var v := 0.0
		for k in freqs.size():
			v += sin(TAU * freqs[k] * t) / (1.0 + k * 0.6)
		out[i] = v * env / freqs.size()
	return out


## A knock: a falling-pitch sine burst plus a short filtered noise click.
static func _knock(rng: RandomNumberGenerator, seconds: float, f0: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := f0 * (1.0 + 1.5 * exp(-t * 40.0))
		ph += TAU * f / RATE
		y = y * 0.6 + rng.randf_range(-1.0, 1.0) * 0.4
		out[i] = (sin(ph) * exp(-t * 18.0) + y * exp(-t * 90.0) * 0.8) * 0.9
	return out


## Air rising and falling: low-passed noise under a smooth swell.
static func _swell(rng: RandomNumberGenerator, seconds: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / n
		var k := 0.12 + 0.5 * sin(PI * t)      # the filter opens in the middle
		y = y + (rng.randf_range(-1.0, 1.0) - y) * k
		out[i] = y * sin(PI * t) * 0.8
	return out


static func _silence(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(RATE * seconds))
	return out


static func _cat(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate()
	out.append_array(b)
	return out


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array, gain_b: float) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = (a[i] if i < a.size() else 0.0) + (b[i] if i < b.size() else 0.0) * gain_b
	return out


## 16-bit mono WAV, normalized to 0.9 of full scale.
static func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.001
	for v in s:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i] / peak * 0.9, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
