extends RefCounted
## Mission 2, STS-61: the five spacewalks' rules, with no screen (issue #46), so a test can play them.
## Each spacewalk asks for its real parts in order (data/missions/sts61.json, from NASA's STS-61 page); the player
## picks a part from the toolbox, then fits it with a press on the timing ring. Each spacewalk has its own clock (its
## real length shown, run fast: about a minute of play); a wrong part costs seconds; when the clock runs out that
## spacewalk is tried again (the team's choice for the story's missions). After the fifth, the first image.
##   var W = Spacewalks.new(); W.update(dt); W.pick("rsu"); W.press("perfect")

const DATA_PATH := "res://data/missions/sts61.json"
const WRONG_COST := 5.0       ## Seconds a wrong part costs.

var D: Dictionary = {}
var walk := 0                 ## The spacewalk being done (5 when all are done).
var step := 0                 ## The step in it.
var left := 0.0               ## Seconds of play left on this spacewalk's clock.
var picked := ""              ## The part in hand, waiting for its press ("" none).
var wrong := 0
var perfect := 0
var presses := 0
var retries := 0
var lost := false


func _init() -> void:
	D = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	left = float(D.seconds_per_walk)


func walks() -> Array:
	return D.spacewalks


func current_walk() -> Dictionary:
	return D.spacewalks[walk] if walk < D.spacewalks.size() else {}


func current() -> Dictionary:
	var W := current_walk()
	return W.steps[step] if not W.is_empty() and step < W.steps.size() else {}


func needed() -> String:
	return str(current().get("part", ""))


func done() -> bool:
	return walk >= D.spacewalks.size()


## The real minutes of this spacewalk still to go, as the clock shows them (the play seconds scaled to its length).
func real_minutes_left() -> float:
	var W := current_walk()
	if W.is_empty():
		return 0.0
	return float(W.minutes) * left / float(D.seconds_per_walk)


## How many times faster than real the clock runs.
func speed() -> float:
	var W := current_walk()
	return float(W.get("minutes", 1)) * 60.0 / float(D.seconds_per_walk)


## Picks a part: "ok" (in hand: press to fit it), "wrong", "cloth" (Killa's lens cloth: wrong, and a joke), or "".
func pick(id: String) -> String:
	if done() or lost or picked != "":
		return ""
	if id == needed():
		picked = id
		return "ok"
	wrong += 1
	left = maxf(0.0, left - WRONG_COST)
	if left <= 0.0:
		lost = true
	return "cloth" if id == "cloth" else "wrong"


## Fits the part in hand with a press graded "perfect", "good" or "late". Returns "next" (the next step),
## "walk" (this spacewalk is done), "all" (the fifth is done) or "".
func press(grade: String) -> String:
	if picked == "" or lost:
		return ""
	presses += 1
	if grade == "perfect":
		perfect += 1
	picked = ""
	step += 1
	if step < current_walk().steps.size():
		return "next"
	walk += 1
	step = 0
	left = float(D.seconds_per_walk)
	return "all" if done() else "walk"


func update(dt: float) -> void:
	if done() or lost:
		return
	left = maxf(0.0, left - dt)
	if left <= 0.0:
		lost = true


## Tries the spacewalk that ran out of time again, from its first step.
func retry() -> void:
	lost = false
	picked = ""
	step = 0
	retries += 1
	left = float(D.seconds_per_walk)


## Stars, 1 to 3: all done (1), no wrong part and no retry, most fits perfect.
func stars() -> int:
	var s := 1
	if wrong == 0 and retries == 0:
		s += 1
	if presses > 0 and perfect * 2 >= presses:
		s += 1
	return s


## The real total: 35 h 28 min [S-hubble-sm1].
func total_minutes() -> int:
	var t := 0
	for W in D.spacewalks:
		t += int(W.minutes)
	return t
