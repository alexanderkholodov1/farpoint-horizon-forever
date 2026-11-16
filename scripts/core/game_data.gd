extends Node
## The game's catalogs (autoload `GameData`), read from the JSON files in `data/` when the game starts. The content and
## the balance live in those files, never here; the schema of each file is in docs/guides/architecture.md.
## Units: mass in kg, power in W, energy in Wh, money in millions of USD (M$), data in GB per day, link rate in Mbps,
## delta-v in m/s. Every entry carries `source` (IDs of docs/sources.md) and, where the number is our own rounding,
## `simplified` saying so.
##
## The catalogs are static, so `GameData.SCENARIOS` also works in scripts that run before the autoload exists (the
## tests, started with `-s`).
##
## Texts in the files are English. When the language is Spanish (or any other with a translation table), the text
## fields are translated here with tr() when the catalogs are built, so the screens read plain strings. Changing the
## language (set_language) builds the catalogs again; screens drawn before the change have to be drawn again.

signal language_changed

const DATA_DIR := "res://data/"
const SETTINGS_PATH := "user://settings.cfg"
const LANGUAGES := {"en": "English", "es": "Español"}   ## Language code -> its own name, for the language switch.

## Fields that hold a whole number (a JSON number always loads as a float).
const INT_FIELDS := ["size", "slots", "max_size", "min_years", "level", "radiation", "pointing", "cml"]
## Fields whose text is translated.
const TEXT_FIELDS := ["name", "type", "desc", "real", "goal", "why", "title", "label", "short"]

static var language := "en"

static var SIZE_NAMES: Dictionary
static var SCENARIOS: Dictionary
static var BUSES: Dictionary
static var INSTRUMENTS: Dictionary
static var PANELS: Dictionary
static var BATTERIES: Dictionary
static var COMMS: Dictionary
static var ADCS: Dictionary
static var PROPULSION: Dictionary
static var ORBITS: Dictionary
static var LAUNCHERS: Dictionary
static var ROLES: Dictionary
static var ROLE_ORDER: Array
static var STEPS: Array
static var DIFFICULTY: Dictionary
static var CML_NAMES: Dictionary


func _init() -> void:
	preload("res://scripts/core/found.gd").load_translations()   # every i18n/<piece>.csv, found by folder (#26)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		language = str(cfg.get_value("game", "language", "en"))
	if not LANGUAGES.has(language):
		language = "en"
	TranslationServer.set_locale(language)
	_build()


## Changes the language, remembers it for the next session and builds the catalogs again.
func set_language(code: String) -> void:
	if not LANGUAGES.has(code) or code == language:
		return
	language = code
	TranslationServer.set_locale(code)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("game", "language", code)
	cfg.save(SETTINGS_PATH)
	_build()
	language_changed.emit()


static func _build() -> void:
	var labels: Dictionary = _read("labels")
	SIZE_NAMES = _int_keys(_texts(labels.get("size_names", {})))
	CML_NAMES = _int_keys(_texts(labels.get("cml_names", {})))
	SCENARIOS = _entries("scenarios")
	BUSES = _entries("buses")
	INSTRUMENTS = _entries("instruments")
	PANELS = _entries("panels")
	BATTERIES = _entries("batteries")
	COMMS = _entries("comms")
	ADCS = _entries("adcs")
	PROPULSION = _entries("propulsion")
	ORBITS = _entries("orbits")
	LAUNCHERS = _entries("launchers")
	DIFFICULTY = _entries("difficulty")
	var roles: Dictionary = _read("roles")
	ROLES = _entries("roles")
	ROLE_ORDER = roles.get("order", ROLES.keys())
	var steps: Dictionary = _read("steps")
	STEPS = _prepare(steps.get("entries", []))


## The JSON file data/<name>.json as a Dictionary (empty, with an error in the log, if it can't be read).
static func _read(file: String) -> Dictionary:
	var path := DATA_DIR + file + ".json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("GameData: cannot open " + path)
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		push_error("GameData: " + path + " is not a JSON object")
		return {}
	return data


static func _entries(file: String) -> Dictionary:
	return _prepare(_read(file).get("entries", {}))


## Turns what JSON cannot say into what the game uses: whole numbers, colors, vectors, translated text.
static func _prepare(node):
	if node is Dictionary:
		var out := {}
		for k in node:
			var v = node[k]
			if k == "color" and v is Array:
				out[k] = Color(v[0], v[1], v[2])
			elif k == "dims" and v is Array:
				out[k] = Vector3(v[0], v[1], v[2])
			elif INT_FIELDS.has(k) and v is float:
				out[k] = int(v)
			elif TEXT_FIELDS.has(k) and v is String:
				out[k] = TranslationServer.translate(v)
			else:
				out[k] = _prepare(v)
		return out
	if node is Array:
		var arr := []
		for v in node:
			arr.append(_prepare(v))
		return arr
	return node


static func _texts(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = TranslationServer.translate(d[k]) if d[k] is String else d[k]
	return out


static func _int_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[int(k)] = d[k]
	return out
