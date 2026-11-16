extends RefCounted
## The cast of the story (v0.3.0, issue #66): the four cuy astronauts as slots, each with a name, a station, the
## station's colour (data/roles.json) and a portrait (assets/story/portraits/<id>.png, rendered from the crew's 3D
## models by assets/source/crew_portraits.py). A scene names its speakers by these ids; a new portrait drops in by
## replacing its image, with no code change. Names are the team's proposal (docs/design/story-v0.3.0.md).
##   const Cast := preload("res://scripts/story/cast.gd")

const SLOTS := {
	"rumi": {"name": "Rumi", "role": "engineer", "station": "Engineer"},
	"killa": {"name": "Killa", "role": "scientist", "station": "Scientist"},
	"inti": {"name": "Inti", "role": "pilot", "station": "Pilot"},
	"wayra": {"name": "Wayra", "role": "ground", "station": "Ground control"},
}
const PORTRAITS := "res://assets/story/portraits/%s.png"
const FALLBACK := Color(0.6, 0.65, 0.75)


static func has(id: String) -> bool:
	return SLOTS.has(id)


static func display_name(id: String) -> String:
	return SLOTS[id].name if SLOTS.has(id) else id


static func station(id: String) -> String:
	return TranslationServer.translate(SLOTS[id].station) if SLOTS.has(id) else ""


## The station's colour, from data/roles.json (the same colours the crew's stations use everywhere).
static func colour(id: String) -> Color:
	if not SLOTS.has(id):
		return FALLBACK
	var R: Dictionary = GameData.ROLES.get(SLOTS[id].role, {})
	return R.get("color", FALLBACK)


## The portrait, or null when it is not there yet (the card then shows the initial on the station's colour).
static func portrait(id: String) -> Texture2D:
	var p := PORTRAITS % id
	return load(p) if ResourceLoader.exists(p) else null
