extends RefCounted
## A scripted run of inputs that shows every move once: for screenshots, clips, and the start of the bot.
## Each step: [ticks, input]; buttons fire on the step's first tick only.

## The route on the grey street (street_world.grey_street): smash the first crate with two kicks, walk on, climb the
## car, walk across its roof and flying-kick off the end, step down the street and jump the second crate, then the
## combos (moves.gd): jab-cross-power punch, jab-cross-push kick, low kick-body kick-side kick, jab-knee-uppercut, low kick-elbow-roundhouse, and a
## hammer fist from a jump, a block, the sweep (Z), a roll forward and a roll back (C); then the walk stance: switching to it, an everyday walk, a run, and back.
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
	[1, {"punch": true}], [9, {}], [1, {"punch": true}], [9, {}], [1, {"punch": true}], [45, {}],
	[1, {"punch": true}], [9, {}], [1, {"punch": true}], [9, {}], [1, {"kick": true}], [55, {}],
	[1, {"kick": true}], [12, {}], [1, {"kick": true}], [12, {}], [1, {"kick": true}], [55, {}],
	[1, {"punch": true}], [9, {}], [1, {"kick": true}], [9, {}], [1, {"punch": true}], [50, {}],
	[1, {"kick": true}], [12, {}], [1, {"punch": true}], [9, {}], [1, {"kick": true}], [50, {}],
	[1, {"jump": true}], [6, {}], [1, {"punch": true}], [50, {}],
	[40, {"block": true}], [1, {"block": true, "punch": true}], [40, {}],
	[1, {"sweep": true}], [75, {}],
	# (forward first, into the open street: a roll back from here ran into the crate behind him and tumbled on the spot)
	[1, {"roll": true}], [45, {}], [1, {"roll": true, "mx": -1.0}], [45, {}],
	# then X to the walk stance, an everyday walk, a run of a full second (W held: enough strides for the testers to
	# judge steady running), and X back to the fight stance
	[1, {"stance": true}], [16, {}], [66, {"mx": 1.0}], [60, {"mx": 1.0, "run": true}], [12, {}],
	[1, {"stance": true}], [20, {}],
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
				for b in ["jump", "punch", "kick", "stance"]:
					inp.erase(b)
			return inp
		start += s[0]
	return {}
