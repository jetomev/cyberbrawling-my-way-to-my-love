extends RefCounted
## A scripted run of inputs that shows every move once: for screenshots, clips, and the start of the bot.
## Each step: [ticks, input]; buttons fire on the step's first tick only.

const STEPS := [
	[40, {}],
	[70, {"mx": 1.0}],
	[1, {"punch": true}], [24, {}],
	[1, {"kick": true}], [34, {}],
	[40, {"mx": 1.0, "mz": 1.0}],
	[1, {"mx": 1.0, "jump": true}], [56, {"mx": 1.0}],
	[1, {"punch": true}], [12, {}], [1, {"punch": true}], [24, {}],
	[50, {"mx": -1.0, "mz": -1.0}],
	[1, {"kick": true}], [40, {}],
]


static func length() -> int:
	var n := 0
	for s in STEPS:
		n += s[0]
	return n


## The input for tick i (0-based), or {} after the end.
static func input_at(i: int) -> Dictionary:
	var start := 0
	for s in STEPS:
		if i < start + s[0]:
			var inp: Dictionary = s[1].duplicate()
			if i != start:
				for b in ["jump", "punch", "kick"]:
					inp.erase(b)
			return inp
		start += s[0]
	return {}
