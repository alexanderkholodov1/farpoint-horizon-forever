extends RefCounted
## Mission 1, Apollo 13: the adapter game's rules, with no screen (issue #45), so a test can play it.
## The CO2 climbs at the gauge's pace; each step of Mission Control asks for one part of the table; a wrong part costs
## a little air; the tape step needs its presses (graded by the timing ring); the last part turns the reading around.
## At the top of the scale the air runs out: lost, and the game is tried again (the team's choice). Data:
## data/missions/apollo13.json (the gauge's numbers are our simplification, said there and on screen).
##   var A = Adapter.new(); A.update(dt); A.pick("cardboard"); A.press(grade)

const DATA_PATH := "res://data/missions/apollo13.json"

var D: Dictionary = {}
var co2 := 0.0                ## 0 clean air, 1 the top of the scale.
var step := 0                 ## The step being done (steps.size() when the adapter is finished).
var presses := 0              ## Presses done in the tape step.
var wrong := 0                ## Wrong parts picked.
var perfect := 0              ## Presses graded perfect.
var peak := 0.0               ## The highest CO2 reached.
var lost := false             ## The air ran out (the gauge reached the top).
var done := false             ## The adapter works: the CO2 falls.
var t := 0.0


func _init() -> void:
	D = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	co2 = D.gauge.start
	peak = co2


func steps() -> Array:
	return D.steps


func current() -> Dictionary:
	return D.steps[step] if step < D.steps.size() else {}


## The part this step needs ("" once finished).
func needed() -> String:
	return str(current().get("part", ""))


## How many presses the current step needs (0: none).
func presses_needed() -> int:
	return int(current().get("presses", 0))


## Picks a part from the table. Returns "ok" (the step's part; a step with presses waits for them), "next" (the step is
## done), "wrong", or "" once finished.
func pick(id: String) -> String:
	if step >= D.steps.size() or lost:
		return ""
	if id != needed():
		wrong += 1
		co2 = minf(1.0, co2 + float(D.gauge.wrong_pick))
		peak = maxf(peak, co2)
		if co2 >= 1.0:
			lost = true
		return "wrong"
	if presses_needed() > 0:
		return "ok"
	return _advance()


## A press in a step that needs them (the tape); grade "perfect", "good" or "late". Every press counts: a late one
## only earns less.
func press(grade: String) -> String:
	if presses_needed() == 0 or lost:
		return ""
	presses += 1
	if grade == "perfect":
		perfect += 1
	if presses >= presses_needed():
		presses = 0
		return _advance()
	return "ok"


func _advance() -> String:
	step += 1
	if step >= D.steps.size():
		done = true
	return "next"


func update(dt: float) -> void:
	t += dt
	if done:
		co2 = maxf(float(D.gauge.clean), co2 - float(D.gauge.fall_per_s) * dt)
		return
	if lost:
		return
	co2 = minf(1.0, co2 + float(D.gauge.rise_per_s) * dt)
	peak = maxf(peak, co2)
	if co2 >= 1.0:
		lost = true


## Stars, 1 to 3: finished (always 1), no wrong part and a clean peak, perfect taping.
func stars() -> int:
	var s := 1
	if wrong == 0 and peak < 0.9:
		s += 1
	if perfect >= 2:
		s += 1
	return s


## Seconds of air left before the top of the scale at the gauge's pace (0 past it).
func seconds_left() -> float:
	return maxf(0.0, (1.0 - co2) / float(D.gauge.rise_per_s))


## How bad the air is for the eyes: 0 below the warning, 1 at the top of the scale.
func danger() -> float:
	var w := float(D.gauge.warning)
	return clampf((co2 - w) / (1.0 - w), 0.0, 1.0)


func warning() -> bool:
	return co2 >= float(D.gauge.warning) and not (done and co2 < float(D.gauge.warning))
