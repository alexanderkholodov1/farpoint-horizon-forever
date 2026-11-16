extends RefCounted
## The pilot asks ground control about a failure in flight. Ground control's station (issue #9) answers with its
## mini-game by setting GameState.ground_answer; until then, and whenever a bot holds that station, the ground-control
## bot reads the alarm and answers after a short think.
##   const Ground := preload("res://scripts/flight/ground.gd")
##   Ground.ask(self, {"code": "1202", ...}, func(answer): ...)

const BOT_THINK := 2.8      ## Seconds the bot takes to answer, about as long as Houston took for the 1202.


## failure: {"code", "title", "desc", "phase", ...}. done is called once with {"go": bool, "by": "player"|"bot",
## "bonus": int, "words": String}. host is the screen (when it is freed first, the answer is dropped).
static func ask(host: Node, failure: Dictionary, done: Callable) -> void:
	var gs: Node = host.get_tree().root.get_node("GameState")
	gs.flight_moment("alarm", failure)
	var answer := func(a: Dictionary) -> void:
		if not is_instance_valid(host):
			return
		gs.flight_moment("alarm_cleared", a)
		done.call(a)
	var ga: Callable = gs.ground_answer
	if ga.is_valid():
		ga.call(failure, answer)
		return
	var timer := host.get_tree().create_timer(BOT_THINK)
	timer.timeout.connect(func():
		answer.call({"go": true, "by": "bot", "bonus": 0, "words": TranslationServer.translate("Ground here. We're go on that alarm, keep flying.")}))
