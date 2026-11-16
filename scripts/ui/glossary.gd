extends RefCounted
## Words a newcomer may not know (issue #69), from data/glossary.json: what each means in plain words.
##   const Glossary := preload("res://scripts/ui/glossary.gd")
##   var notes := Glossary.notes("Fast radio (X band)")   # "Radio bands: the higher the frequency ..."

const PATH := "res://data/glossary.json"
static var _all: Array = []


## Every entry, in the file's order: {term, aka (as shown on screen), meaning (translated)}.
static func all() -> Array:
	if _all.is_empty():
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		for k in d.get("entries", {}):
			var e: Dictionary = d.entries[k]
			_all.append({"term": e.term, "aka": e.aka, "meaning": e.meaning})
	return _all


## The meanings of the words that appear in `text` (each once), one per line, "Word: meaning".
static func notes(text: String, most := 99) -> String:
	var out := PackedStringArray()
	for e in all():
		if out.size() >= most:
			break
		for a in e.aka:
			if text.containsn(str(a)) or text.containsn(TranslationServer.translate(str(a))):
				out.append(TranslationServer.translate(str(e.term)) + ": " + TranslationServer.translate(str(e.meaning)))
				break
	return "\n".join(out)
