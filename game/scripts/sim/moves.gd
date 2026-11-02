extends RefCounted
## Every attack and the combos that chain them (D-18, Javier 2026-11-01: "make combos to make fights fun… FUN!").
## Three presses in quick succession chain into a finisher; missing the window (combo_window_ticks in the tuning)
## starts over. The opening press is always the same move (it can't know what comes next), so P opens with the jab
## and K with the front kick, whichever chain follows.
##
## Per move: start-up / active / recovery ticks, reach from the body's centre (px), the height band a blow covers
## above the feet (a jab flies over a low crate), damage, what a finisher does to whoever it hits, and the limb that
## lands it (the drawing's tip must reach where the logic says the blow lands).

## The jab, front kick and flying kick take their timing and reach from the tuning table (the feel lab edits them).
const TUNED := ["punch", "kick", "air_kick"]

const TABLE := {
	# opener P: the jab
	"punch": {"low": 120.0, "high": 230.0, "damage": 1, "effect": "", "limb": "arm_f_lower"},
	"cross": {"startup": 5, "active": 3, "recovery": 9, "reach": 125.0, "low": 120.0, "high": 230.0, "damage": 1,
		"effect": "", "limb": "arm_b_lower"},
	"hook": {"startup": 7, "active": 4, "recovery": 14, "reach": 112.0, "low": 130.0, "high": 230.0, "damage": 2,
		"effect": "stagger", "limb": "arm_f_lower"},
	"push_kick": {"startup": 8, "active": 4, "recovery": 14, "reach": 124.0, "low": 60.0, "high": 180.0, "damage": 1,
		"effect": "push", "limb": "leg_f_lower"},
	"knee": {"startup": 5, "active": 3, "recovery": 10, "reach": 64.0, "low": 60.0, "high": 160.0, "damage": 2,
		"effect": "", "limb": "leg_f_upper"},
	"uppercut": {"startup": 7, "active": 4, "recovery": 16, "reach": 72.0, "low": 140.0, "high": 260.0, "damage": 3,
		"effect": "launch", "limb": "arm_b_lower"},
	# opener K: the front kick
	"kick": {"low": 60.0, "high": 180.0, "damage": 2, "effect": "", "limb": "leg_f_lower"},
	"body_kick": {"startup": 7, "active": 4, "recovery": 12, "reach": 120.0, "low": 60.0, "high": 190.0, "damage": 2,
		"effect": "", "limb": "leg_b_lower"},
	"spin_kick": {"startup": 10, "active": 5, "recovery": 18, "reach": 110.0, "low": 120.0, "high": 260.0, "damage": 3,
		"effect": "knockdown", "limb": "leg_f_lower"},
	"elbow": {"startup": 4, "active": 3, "recovery": 10, "reach": 80.0, "low": 140.0, "high": 230.0, "damage": 2,
		"effect": "", "limb": "arm_f_upper"},
	"roundhouse": {"startup": 9, "active": 5, "recovery": 16, "reach": 120.0, "low": 100.0, "high": 230.0, "damage": 3,
		"effect": "stagger", "limb": "leg_b_lower"},
	# in the air: one per jump
	"air_kick": {"low": 30.0, "high": 170.0, "damage": 3, "effect": "", "limb": "leg_f_lower"},
	"hammer_fist": {"startup": 4, "active": 8, "recovery": 0, "reach": 70.0, "low": 20.0, "high": 160.0, "damage": 2,
		"effect": "", "limb": "arm_f_lower"},
}

## What each sequence of presses becomes. A sequence not listed starts a new chain with its last press.
const COMBOS := {
	"P": "punch", "PP": "cross", "PPP": "hook", "PPK": "push_kick", "PK": "knee", "PKP": "uppercut",
	"K": "kick", "KK": "body_kick", "KKK": "spin_kick", "KP": "elbow", "KPK": "roundhouse",
}
const AIR := {"P": "hammer_fist", "K": "air_kick"}
const FINISHER_LENGTH := 3


static func is_move(name: String) -> bool:
	return TABLE.has(name)


static func is_air(name: String) -> bool:
	return name in AIR.values()


## The full data for a move, with the tuned moves' timing and reach read from the tuning table.
static func data(name: String, tune: Dictionary) -> Dictionary:
	var d: Dictionary = TABLE[name].duplicate()
	if name in TUNED:
		for k in ["startup", "active", "recovery", "reach"]:
			if tune.has(name + "_" + k):
				d[k] = tune[name + "_" + k]
		if not d.has("recovery"):
			d["recovery"] = 0  # the flying kick stays out until landing
	return d


static func length(name: String, tune: Dictionary) -> int:
	var d := data(name, tune)
	return d["startup"] + d["active"] + d["recovery"]


## The next link of a chain: given the chain so far ("" for none) and the press ("P" or "K"), the new chain and the
## move it plays. A finisher ends the chain.
static func next(chain: String, press: String) -> Array:
	var seq := chain + press
	if not COMBOS.has(seq):
		seq = press
	var move: String = COMBOS[seq]
	return ["" if seq.length() >= FINISHER_LENGTH else seq, move]
