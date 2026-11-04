extends RefCounted
## Every attack and the combos that chain them (D-18, Javier 2026-11-01: "make combos to make fights fun… FUN!").
## Three presses in quick succession chain into a finisher; missing the window (combo_window_ticks in the tuning)
## starts over. The opening press is always the same move (it can't know what comes next), so P opens with the jab
## and K with the low kick, whichever chain follows. The three-punch chain ends in the power punch and the three-kick
## chain goes low, middle, then a side kick to the face (Javier, 2026-11-02 18:19, through the assistant team: "Power
## Button is part of the 3 punch combination, it is the last punch. The side kick (to the face) is part of the 3 kick
## combo, the low kick could be the first kick of the 3 kick combo (down, middle, side up)."). The hook, the front
## kick and the spinning kick keep their poses and data but no press reaches them for now (enemies may use them).
##
## Per move: start-up / active / recovery ticks, reach from the body's centre (px), the height band a blow covers
## above the feet (a jab flies over a low crate), damage, what a finisher does to whoever it hits, and the limb that
## lands it (the drawing's tip must reach where the logic says the blow lands).

## The jab, the opening kick (now the low kick) and the flying kick take their timing and reach from the tuning table
## (the feel lab edits them).
const TUNED := ["punch", "kick", "air_kick"]

const TABLE := {
	# opener P: the jab
	"punch": {"low": 120.0, "high": 230.0, "damage": 1, "effect": "", "limb": "hand_f"},
	"cross": {"startup": 5, "active": 3, "recovery": 9, "reach": 150.0, "low": 120.0, "high": 230.0, "damage": 1,
		"effect": "", "limb": "hand_b"},
	"hook": {"startup": 7, "active": 4, "recovery": 14, "reach": 112.0, "low": 130.0, "high": 230.0, "damage": 2,
		"effect": "stagger", "limb": "hand_f"},
	# P, P, P: the power punch, from a bow stance, the rear fist straight to the chest
	"power_punch": {"startup": 10, "active": 4, "recovery": 18, "reach": 160.0, "low": 110.0, "high": 210.0, "damage": 3,
		"effect": "stagger", "limb": "hand_b"},
	"push_kick": {"startup": 8, "active": 4, "recovery": 14, "reach": 140.0, "low": 60.0, "high": 180.0, "damage": 1,
		"effect": "push", "limb": "foot_f"},
	"knee": {"startup": 5, "active": 3, "recovery": 10, "reach": 64.0, "low": 60.0, "high": 160.0, "damage": 2,
		"effect": "", "limb": "leg_f_upper"},
	"uppercut": {"startup": 7, "active": 4, "recovery": 16, "reach": 72.0, "low": 140.0, "high": 280.0, "damage": 3,
		"effect": "launch", "limb": "hand_b"},
	# opener K: the low kick, the front foot to the knee or shin
	"kick": {"low": 0.0, "high": 110.0, "damage": 2, "effect": "", "limb": "foot_f"},
	# the front snap kick, kept (no press reaches it now)
	"front_kick": {"startup": 7, "active": 4, "recovery": 12, "reach": 138.0, "low": 60.0, "high": 180.0, "damage": 2,
		"effect": "", "limb": "foot_f"},
	"body_kick": {"startup": 7, "active": 4, "recovery": 12, "reach": 138.0, "low": 60.0, "high": 190.0, "damage": 2,
		"effect": "", "limb": "foot_b"},
	"spin_kick": {"startup": 10, "active": 5, "recovery": 18, "reach": 90.0, "low": 120.0, "high": 260.0, "damage": 3,
		"effect": "knockdown", "limb": "foot_f"},
	# K, K, K: the side kick to the face, heel first, the whole body on the standing foot (slower: about 0.7 s in all,
	# out in 167 ms as recorded, CMU 135_11: 150-190)
	"side_kick": {"startup": 10, "active": 4, "recovery": 28, "reach": 130.0, "low": 170.0, "high": 280.0, "damage": 3,
		"effect": "knockdown", "limb": "foot_f"},
	"elbow": {"startup": 4, "active": 3, "recovery": 10, "reach": 80.0, "low": 140.0, "high": 230.0, "damage": 2,
		"effect": "", "limb": "arm_f_upper"},
	"roundhouse": {"startup": 9, "active": 5, "recovery": 16, "reach": 128.0, "low": 100.0, "high": 230.0, "damage": 3,
		"effect": "stagger", "limb": "foot_b"},
	# Z: the back sweep (Javier, 2026-11-02 19:28: "Z key"), its own move outside the combos; the posture sheet's: sink
	# low, spin on the front foot with the back leg straight along the street, hands near the floor; the biggest
	# wind-up of the low moves. No recorded sweep exists in the libraries we use: drawn from the sheet.
	# (reach: he turns round his planted front foot, which carries the long sweeping leg well out in front: 195, was
	# 120 before the turn kept that foot planted; the testers, 02:29 on 0922751)
	"sweep": {"startup": 12, "active": 6, "recovery": 20, "reach": 195.0, "low": 0.0, "high": 50.0, "damage": 2,
		"effect": "knockdown", "limb": "leg_b_lower"},  # a back sweep catches the ankles with the heel and calf
	# in the air: one per jump
	"air_kick": {"low": 30.0, "high": 170.0, "damage": 3, "effect": "", "limb": "foot_f"},
	"hammer_fist": {"startup": 4, "active": 8, "recovery": 0, "reach": 70.0, "low": 20.0, "high": 160.0, "damage": 2,
		"effect": "", "limb": "hand_f"},
}

## What each sequence of presses becomes. A sequence not listed starts a new chain with its last press.
const COMBOS := {
	"P": "punch", "PP": "cross", "PPP": "power_punch", "PPK": "push_kick", "PK": "knee", "PKP": "uppercut",
	"K": "kick", "KK": "body_kick", "KKK": "side_kick", "KP": "elbow", "KPK": "roundhouse",
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


## True for the blow that ends a three-press chain (the power punch, the side kick, …): two of them landing in a row
## on one enemy make him dizzy (D-19).
static func is_finisher(name: String) -> bool:
	for seq in COMBOS:
		if (seq as String).length() >= FINISHER_LENGTH and COMBOS[seq] == name:
			return true
	return false


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
