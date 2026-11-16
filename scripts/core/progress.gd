extends RefCounted
## Which missions the player has finished, kept between sessions (user://settings.cfg, [progress]). Every mission is
## open from the start (the team's call for v0.3.0, so a jury reaches the Moon at once); "In order" (settings) opens
## them one after another instead, each when the one before it is done. Missions flagged "soon" in data/scenarios.json are never open.
##   const Progress := preload("res://scripts/core/progress.gd")

const PATH := "user://settings.cfg"
## The order missions open in, from the simplest to the hardest; the sandbox last.
const ORDER := ["volcanes", "clima", "luna", "moon_south_pole", "telescopio", "libre"]


static func _cfg() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(PATH)
	return c


static func is_done(id: String) -> bool:
	return bool(_cfg().get_value("progress", id, false))


## Records a finished mission (the report screen calls it).
static func done(id: String) -> void:
	var c := _cfg()
	c.set_value("progress", id, true)
	c.save(PATH)


static func all_open() -> bool:
	return bool(_cfg().get_value("progress", "_all_open", true))


static func set_all_open(on: bool) -> void:
	var c := _cfg()
	c.set_value("progress", "_all_open", on)
	c.save(PATH)


## "" when the mission can be played; else why not: "soon" (not built yet) or the id of the mission to finish first.
static func locked_by(id: String, scenario: Dictionary) -> String:
	if scenario.get("soon", false):
		return "soon"
	if all_open():
		return ""
	var i := ORDER.find(id)
	if i <= 0:
		return ""
	return "" if is_done(ORDER[i - 1]) else ORDER[i - 1]
