extends RefCounted
## Things the game finds by folder instead of by a shared list, so a piece of work adds its own files and never edits
## a file that every piece edits (issue #26): the screens in scripts/screens/, the translations in i18n/.
## It reads folders through ResourceLoader.list_directory, which also sees the files of an exported game (the web
## build), where scripts and imported files are stored under other names.
##   const Found := preload("res://scripts/core/found.gd")

## File names in `dir` ending in `ext` (".gd", ".translation"), sorted, without the folder.
static func files(dir: String, ext: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in ResourceLoader.list_directory(dir):
		var name := f.trim_suffix(".remap").trim_suffix(".import")
		if name.ends_with(ext) and not out.has(name):
			out.append(name)
	out.sort()
	return out


## Every screen and overlay by id: each script in scripts/screens/ is one, and its id is its file name
## ("launch.gd" is "launch"). screen.gd is the base they all extend, not a screen.
static func screens() -> Dictionary:
	var out := {}
	for f in files("res://scripts/screens", ".gd"):
		if f == "screen.gd":
			continue
		out[f.get_basename()] = load("res://scripts/screens/" + f)
	return out


static var _translations_loaded := false

## Adds every translation in i18n/ to the game: one CSV per piece of work (i18n/<piece>.csv, with the columns
## keys,es), which Godot imports as i18n/<piece>.<language>.translation. The ones project.godot already lists are
## skipped. Called once at startup, before the catalogs are translated (GameData).
static func load_translations() -> void:
	if _translations_loaded:
		return
	_translations_loaded = true
	var listed: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	for f in files("res://i18n", ".translation"):
		var path := "res://i18n/" + f
		if listed.has(path):
			continue
		var t = load(path)
		if t is Translation:
			TranslationServer.add_translation(t)
		else:
			push_error("Found: %s is not a translation" % path)
