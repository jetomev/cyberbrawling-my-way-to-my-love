extends RefCounted
## The melee weapons (DESIGN, Fighting: bats, pipes, wrenches, sticks, knives, swords; no guns), taken from enemies,
## carried in the hand. Each feels different (DESIGN: the knife fast and short, the sword a wide sweep, the bat big
## knockback, the pipe and wrench heavy) and wears out after a number of hits (D-14). Holding one, the punch button
## swings it: three presses chain swing, backswing, overhead smash (DESIGN, "Still to come, with weapons"; the smash
## wears the weapon faster). A broken arm can't swing one (DESIGN, Pain).
##
## Per weapon: what it adds to a swing's damage, its reach (px from the body's centre), how much faster (-) or slower
## (+) it comes out and recovers, in ticks, how many hits it lasts, and what the overhead smash does.

const TABLE := {
	"knife": {"damage": 1.0, "reach": 120.0, "speed": -3, "hits": 14, "smash": "stagger"},
	"stick": {"damage": 1.0, "reach": 160.0, "speed": -1, "hits": 8, "smash": "stagger"},
	"pipe": {"damage": 2.0, "reach": 165.0, "speed": 2, "hits": 12, "smash": "knockdown"},
	"wrench": {"damage": 2.0, "reach": 145.0, "speed": 2, "hits": 16, "smash": "knockdown"},
	"bat": {"damage": 2.0, "reach": 175.0, "speed": 1, "hits": 10, "smash": "push"},
	"sword": {"damage": 3.0, "reach": 200.0, "speed": 0, "hits": 20, "smash": "knockdown"},
}

## The three weapon blows, before a weapon's own numbers: the swing across, the backswing, the overhead smash.
const SWINGS := {
	"swing": {"startup": 7, "active": 4, "recovery": 12, "low": 120.0, "high": 260.0, "damage": 1, "effect": "",
		"limb": "hand_f", "wear": 1},
	"backswing": {"startup": 6, "active": 4, "recovery": 12, "low": 120.0, "high": 260.0, "damage": 1, "effect": "",
		"limb": "hand_f", "wear": 1},
	"smash": {"startup": 12, "active": 5, "recovery": 20, "low": 140.0, "high": 300.0, "damage": 2, "effect": "",
		"limb": "hand_f", "wear": 2},
}
const CHAIN := {"W": "swing", "WW": "backswing", "WWW": "smash"}
const PICK_UP_REACH := 40.0  # standing this close (along the street and its depth) to a loose weapon picks it up


static func is_weapon(kind: String) -> bool:
	return TABLE.has(kind)


static func is_swing(move: String) -> bool:
	return SWINGS.has(move)


## A weapon blow's full data with the weapon held: the base swing plus the weapon's damage, reach and speed; the smash
## takes the weapon's own effect.
static func swing_data(move: String, weapon: String) -> Dictionary:
	var d: Dictionary = SWINGS[move].duplicate()
	var w: Dictionary = TABLE[weapon]
	d["damage"] = d["damage"] + w["damage"]
	d["reach"] = w["reach"]
	d["startup"] = maxi(2, d["startup"] + w["speed"])
	d["recovery"] = maxi(4, d["recovery"] + w["speed"] * 2)
	if move == "smash":
		d["effect"] = w["smash"]
	return d


## The next link of a weapon chain, like moves.gd's next(): [chain so far, the move it plays].
static func next(chain: String, press: String) -> Array:
	var seq := chain + press
	if not CHAIN.has(seq):
		seq = press
	return ["" if seq.length() >= 3 else seq, CHAIN[seq]]


## The loose weapon a fighter standing at (x, z) can pick up from the street's items, or {}.
static func within_reach(items: Array, x: float, z: float) -> Dictionary:
	for it in items:
		if is_weapon(it["kind"]) and absf(it["x"] - x) <= PICK_UP_REACH and absf(it["z"] - z) <= PICK_UP_REACH:
			return it
	return {}
