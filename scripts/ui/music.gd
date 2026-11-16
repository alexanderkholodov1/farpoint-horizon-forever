extends Node
## The game's music (issue #12): "Horizon", our own piece composed by tools/content/audio/compose_music.py, in two layers of
## the same length that always play together:
##   - the piece itself (pads, bells, a slow bass): the calm of the menus, the design and the coast through space;
##   - the drive (a pulse, a thump on each beat, a run of the chord's notes): it comes in under the piece when the
##     flight asks for the player, the climb, an engine burning or about to, the braking at the Moon, the landing.
## So the music follows the moment, not only the screen: it reads which screen is showing and, in a flight, what the
## craft is doing, and moves each layer to its level in a second or two. It plays on the Master bus, so Sound off
## silences it with everything else, and it pauses while the game's window is not in front.
##   const Music := preload("res://scripts/ui/music.gd")

const TRACK := preload("res://assets/audio/music_horizon.ogg")
const DRIVE := preload("res://assets/audio/music_horizon_drive.ogg")
const OFF := -60.0
## The piece's level on each screen (dB); DEFAULT_DB elsewhere.
const LEVEL := {"credits_film": -9.0, "launch": -30.0, "flight": -20.0, "landing": -30.0, "report": -13.0,
	"apollo13": -22.0, "sts61": -20.0, "pathfinder": -22.0, "lcross": -21.0, "dart": -21.0, "artemis1": -24.0, "reentry": -22.0}
const DEFAULT_DB := -17.0
## The drive's level when the moment is tense, on each screen (dB): under the engines, never over the call-outs.
const DRIVE_LEVEL := {"launch": -19.0, "flight": -17.0, "landing": -20.0,
	# the story's action games (#97): the drive under each one, a little below its own alarms and engines
	"apollo13": -18.0, "sts61": -20.0, "pathfinder": -19.0, "lcross": -19.0, "dart": -19.0, "artemis1": -21.0, "reentry": -18.0}
const STORY_GAMES := ["apollo13", "sts61", "pathfinder", "lcross", "dart", "artemis1", "reentry"]

var main
var player: AudioStreamPlayer
var drive: AudioStreamPlayer


## Starts the music once, for the whole game.
static func ensure(m) -> void:
	var root: Window = m.get_tree().root
	if root.has_node("Music"):
		return
	var n = load("res://scripts/ui/music.gd").new()
	n.name = "Music"
	n.main = m
	root.add_child.call_deferred(n)


func _ready() -> void:
	player = _layer(TRACK)
	drive = _layer(DRIVE)
	player.play()
	drive.play()


func _layer(track: AudioStreamOggVorbis) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s: AudioStreamOggVorbis = track.duplicate()
	s.loop = true
	p.stream = s
	p.volume_db = OFF
	add_child(p)
	return p


## True when the flight asks for the player right now: the drive comes in.
func _tense(id: String) -> bool:
	if main == null or not is_instance_valid(main) or main.screen == null or not is_instance_valid(main.screen):
		return false
	var sc = main.screen
	if id in STORY_GAMES:
		return true   # each is a game against the clock or the air from its first second
	match id:
		"launch":
			return str(sc.get("phase")) == "climb"
		"landing":
			return true
		"flight":
			var ph := str(sc.get("phase"))
			return ph == "burn" or ph == "capture" or (ph == "plan" and sc.hud != null and sc.hud.action.lit)
	return false


func _process(delta: float) -> void:
	if player == null:
		return
	var id: String = main.screen_id if main and is_instance_valid(main) else ""
	# fades of about two seconds, in decibels
	player.volume_db = move_toward(player.volume_db, LEVEL.get(id, DEFAULT_DB), delta * 12.0)
	drive.volume_db = move_toward(drive.volume_db, DRIVE_LEVEL.get(id, OFF) if _tense(id) else OFF, delta * 18.0)
	# the two layers are one piece: if they ever drift apart, the drive steps back onto the beat
	if player.playing and drive.playing and absf(player.get_playback_position() - drive.get_playback_position()) > 0.04:
		drive.seek(player.get_playback_position())


func _notification(what: int) -> void:
	if player == null:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		player.stream_paused = true
		drive.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		player.stream_paused = false
		drive.stream_paused = false
