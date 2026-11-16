extends RefCounted
## The campaign's collectibles (issue #50): each mission finished earns its patch, with its best stars; finishing
## Artemis I, the last, earns the final trophy, "Campos's seat". The patches are our own design (no NASA insignia,
## AGENTS.md). Kept in user://campaign.cfg, so they stay between games.
##   Progress.earn("dart", 3); Progress.stars("dart"); Progress.all_done()

const PATH := "user://campaign.cfg"
## [screen id, mission, year, the patch's colour]
const MISSIONS := [
	["apollo13", "Apollo 13", "1970", Color(0.85, 0.35, 0.25)],
	["sts61", "STS-61 · Hubble", "1993", Color(0.3, 0.55, 0.9)],
	["pathfinder", "Mars Pathfinder", "1997", Color(0.85, 0.5, 0.25)],
	["lcross", "LCROSS", "2009", Color(0.6, 0.65, 0.75)],
	["dart", "DART", "2022", Color(0.55, 0.45, 0.8)],
	["artemis1", "Artemis I", "2022", Color(0.95, 0.65, 0.2)],
]


static func _cfg() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(PATH)
	return c


## A mission finished with this many stars: its patch is earned (the best stars are kept). True if new.
static func earn(id: String, stars: int) -> bool:
	var c := _cfg()
	var had := int(c.get_value("stars", id, -1))
	if stars > had:
		c.set_value("stars", id, stars)
		c.save(PATH)
	return had < 0


## The best stars of a mission, or -1 when it has not been finished.
static func stars(id: String) -> int:
	return int(_cfg().get_value("stars", id, -1))


static func count() -> int:
	var n := 0
	for m in MISSIONS:
		if stars(m[0]) >= 0:
			n += 1
	return n


## All six patches: the trophy.
static func all_done() -> bool:
	return count() == MISSIONS.size()
