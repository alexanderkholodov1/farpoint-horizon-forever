extends RefCounted
## The photos a mission sends home: real NASA images of its target, listed with their source and credit in
## data/nasa/manifest.json (built by tools/content/data/, every file with its source ID in docs/sources.md). The caption and
## the credit come from the manifest's own words. A photo that an extra objective unlocks (data/objectives.json,
## `photo`) comes home only when that objective was met; the others come home with any mission that worked.
##   const Photos := preload("res://scripts/flight/photos.gd")
##   for p in Photos.of(mission.scenario): p.path, p.caption, p.credit, p.objective ("" or the objective's id)

const MANIFEST := "res://data/nasa/manifest.json"
## Scenario id -> the photo set's name in the manifest, where they differ.
const SETS := {"volcanes": "volcano_watch"}
## Photos whose manifest entry describes only its processing: their caption and credit.
const CAPTIONS := {
	"south_pole_wide_lroc_wac.jpg": ["The Moon's south pole seen from above, a mosaic of the Lunar Reconnaissance Orbiter's wide-angle camera", "NASA/GSFC/Arizona State University"],
}

static var _cache: Array = []


## The photos of a scenario: [{path, caption, credit, source_id, objective}], in the manifest's order.
static func of(scenario_id: String) -> Array:
	var set_name: String = SETS.get(scenario_id, scenario_id)
	var unlock := {}
	var objectives: Dictionary = GameData._entries("objectives")
	for id in objectives:
		if objectives[id].has("photo"):
			unlock[str(objectives[id].photo)] = id
	var out: Array = []
	for e in _manifest():
		var f := str(e.get("file", ""))
		if str(e.get("mission", "")) != set_name or not (f.ends_with(".jpg") or f.ends_with(".png")):
			continue
		var path := "res://" + str(e.file)
		var words := _words(e)
		out.append({"path": path, "caption": words[0], "credit": words[1], "source_id": str(e.get("source_id", "")),
			"objective": unlock.get(path, "")})
	return out


## True when the photo came home on this flight: an objective's photo when it was met, any other when the mission
## worked at least a month.
static func earned(p: Dictionary, flight: Dictionary, sim: Dictionary) -> bool:
	if p.objective != "":
		return flight.get("photos", []).has(p.path)
	return int(sim.get("months", 0)) > 0 and not bool(sim.get("launch_failed", false))


static func _manifest() -> Array:
	if _cache.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if d is Array:
			_cache = d
	return _cache


## [caption, credit] from the manifest entry's description: its parts are separated by "; ", one names what the
## picture shows, one starts with "credit".
static func _words(e: Dictionary) -> Array:
	var file := str(e.file).get_file()
	if CAPTIONS.has(file):
		return CAPTIONS[file]
	var caption := ""
	var credit := "NASA"
	for part in str(e.get("processing", "")).split("; "):
		var p := part.strip_edges()
		var low := p.to_lower()
		if low.begins_with("credit"):
			credit = p.trim_prefix("credit:").trim_prefix("credit as printed").trim_prefix("credit").strip_edges().trim_prefix(":").strip_edges()
		elif caption == "" and not (low.begins_with("cropped") or low.begins_with("no crop") or low.begins_with("resized") \
				or low.begins_with("tiles") or low.begins_with("page") or low.begins_with("library record") or low.begins_with("same page")):
			caption = p
	caption = caption.split(", page:")[0].strip_edges()
	return [caption if caption != "" else file.get_basename().replace("_", " "), credit]
