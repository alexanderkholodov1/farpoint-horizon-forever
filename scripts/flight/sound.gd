extends RefCounted
## The flight's sounds, synthesized in code when first needed (no audio files): the engine's rumble, beeps, the
## alarm, the thump of staging, the touchdown thud, the arrival chime and the explosion. Quiet by default; every
## player goes to the Master bus, which the mute switch silences. The rumble is a loop of brown noise whose pitch and
## volume follow the throttle and wander a little, so it never repeats the same way.
##   const Sound := preload("res://scripts/flight/sound.gd")
##   var p := Sound.player(self, "beep")

const RATE := 22050
const QUIET_DB := -10.0

static var _streams := {}


## An AudioStreamPlayer for sound `id` ("rumble", "beep", "alarm", "clunk", "thud", "chime", "boom", "hiss"), added
## to parent. The rumble and the hiss loop.
static func player(parent: Node, id: String, volume_db := QUIET_DB) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream(id)
	p.volume_db = volume_db
	parent.add_child(p)
	return p


static func stream(id: String) -> AudioStreamWAV:
	if not _streams.has(id):
		_streams[id] = _make(id)
	return _streams[id]


## Mutes or unmutes every sound of the game (the Master bus).
static func set_muted(m: bool) -> void:
	AudioServer.set_bus_mute(0, m)


static func is_muted() -> bool:
	return AudioServer.is_bus_mute(0)


static func _make(id: String) -> AudioStreamWAV:
	var s: PackedFloat32Array
	var loop := false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	match id:
		"rumble":
			s = _brown(rng, 2.0, 0.985)
			loop = true
		"hiss":
			s = _brown(rng, 1.5, 0.6)
			loop = true
		"beep":
			s = _tone([880.0], 0.12, 0.004, 0.08)
		"alarm":
			s = PackedFloat32Array()
			for i in 4:
				s.append_array(_tone([620.0 if i % 2 == 0 else 830.0], 0.16, 0.005, 0.03))
		"chime":
			s = _tone([523.25, 783.99, 1046.5], 1.6, 0.01, 1.2)
		"clunk":
			s = _hit(rng, 0.35, 95.0, 0.6)
		"thud":
			s = _hit(rng, 0.9, 55.0, 0.8)
		"boom":
			s = _blast(rng, 2.8)
		_:
			s = _tone([440.0], 0.1, 0.005, 0.05)
	return _wav(s, loop)


## Brown noise (a random walk): a deep rumble. `keep` near 1 is deeper. Its end fades into its start so it loops clean.
static func _brown(rng: RandomNumberGenerator, seconds: float, keep: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	var peak := 0.001
	for i in n:
		y = y * keep + rng.randf_range(-1.0, 1.0) * (1.0 - keep) * 4.0
		out[i] = y
		peak = maxf(peak, absf(y))
	var fade := int(RATE * 0.25)
	for i in fade:
		var k := float(i) / fade
		out[n - fade + i] = out[n - fade + i] * (1.0 - k) + out[i] * k
	for i in n:
		out[i] = out[i] / peak * 0.8
	return out


## Sine tones mixed, with a short attack and an exponential decay.
static func _tone(freqs: Array, seconds: float, attack: float, decay: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / attack) * exp(-t / maxf(decay, 0.001))
		var v := 0.0
		for f in freqs:
			v += sin(TAU * float(f) * t)
		out[i] = v / freqs.size() * env * 0.7
	return out


## A hit: a low sine that sinks in pitch, plus a burst of noise, both decaying.
static func _hit(rng: RandomNumberGenerator, seconds: float, freq: float, noise: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * freq * (1.0 - 0.4 * t / seconds) / RATE
		y = y * 0.9 + rng.randf_range(-1.0, 1.0) * 0.1
		var env := exp(-t * 6.0 / seconds)
		out[i] = (sin(ph) * 0.7 + y * noise * 3.0) * env * 0.8
	return out


## An explosion any speaker can play: a bright crack (white noise, gone in a tenth of a second), the blast's body
## (noise smoothed only a little, so its energy sits in the middle frequencies a laptop speaker reproduces) and a
## falling thump at 80 Hz underneath. A low tone alone (40 Hz) is felt in a cinema but not heard on a laptop.
static func _blast(rng: RandomNumberGenerator, seconds: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var body := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		body = body * 0.55 + white * 0.45
		ph += TAU * 80.0 * (1.0 - 0.5 * t / seconds) / RATE
		var crack := white * exp(-t * 40.0)
		var roar := body * exp(-t * 2.2) * (1.0 - exp(-t * 60.0))
		var thump := sin(ph) * exp(-t * 3.0)
		out[i] = clampf(crack * 0.9 + roar * 0.85 + thump * 0.6, -1.0, 1.0)
	return out


static func _wav(s: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w
