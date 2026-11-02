extends RefCounted
## A scripted run of inputs that shows every move once: for screenshots, clips, and the start of the bot.
## Each step: [ticks, input]; buttons fire on the step's first tick only.

## The route on the grey street (street_world.grey_street): smash the first crate with two kicks, walk on, climb the
## car, walk across its roof and flying-kick off the end, step down the street and jump the second crate, then a
## punch-punch combo and a walk back.
const STEPS := [
	[30, {}],
	[150, {"mx": 1.0}],
	[1, {"kick": true}], [30, {}],
	[1, {"kick": true}], [30, {}],
	[260, {"mx": 1.0}],
	[40, {"mx": 1.0}],
	[1, {"mx": 1.0, "jump": true}], [12, {"mx": 1.0}],
	[1, {"kick": true}], [40, {"mx": 1.0}],
	[16, {"mz": 1.0}],
	[21, {"mx": 1.0}],
	[1, {"mx": 1.0, "jump": true}], [55, {"mx": 1.0}],
	[1, {"punch": true}], [12, {}], [1, {"punch": true}], [24, {}],
	[20, {"mx": -1.0}],
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
