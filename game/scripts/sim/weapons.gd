extends RefCounted
## The melee weapons (DESIGN, Fighting: bats, pipes, wrenches, sticks, knives, swords; no guns), taken from enemies,
## carried in the hand. Each feels different (DESIGN: the knife fast and short, the sword a wide sweep, the bat big
## knockback, the pipe and wrench heavy) and wears out after a number of hits (D-14). The combos are the team's
## (art-in 2026-11-03, weapon combos): the same key presses armed or not, the weapon taking the fist's place. P P P is
## swing, backswing, overhead smash; P P K swing, backswing, push kick; P K P swing, knee, rising swing (launches);
## K P K low kick, handle jab, roundhouse; K K K as without one; jump + P a jumping chop. A weapon wears only on a hit,
## and kicks never wear it. A broken arm can't swing one (DESIGN, Pain): the fist combos instead.
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

## The fist move each press becomes with a weapon in hand (the rest stay as they are).
const ARMED := {"punch": "swing", "cross": "backswing", "power_punch": "smash", "uppercut": "rising_swing",
	"elbow": "handle_jab", "hammer_fist": "chop"}
## The weapon blows, before a weapon's own numbers: the swing across, the backswing, the overhead smash, the rising
## swing, the handle jab, the jumping chop.
const SWINGS := {
	"swing": {"startup": 7, "active": 4, "recovery": 12, "low": 120.0, "high": 260.0, "damage": 1, "effect": "",
		"limb": "hand_f", "wear": 1},
	"backswing": {"startup": 6, "active": 4, "recovery": 12, "low": 120.0, "high": 260.0, "damage": 1, "effect": "",
		"limb": "hand_f", "wear": 1},
	"smash": {"startup": 12, "active": 5, "recovery": 20, "low": 140.0, "high": 300.0, "damage": 2, "effect": "",
		"limb": "hand_f", "wear": 2},
	# P K P armed: from low, up through him, launching him
	"rising_swing": {"startup": 8, "active": 4, "recovery": 16, "low": 120.0, "high": 300.0, "damage": 2, "effect": "launch",
		"limb": "hand_f", "wear": 1},
	# K P K armed: the butt of the weapon, short, in place of the elbow; it doesn't wear the weapon
	"handle_jab": {"startup": 4, "active": 3, "recovery": 10, "low": 140.0, "high": 230.0, "damage": 1, "effect": "",
		"limb": "hand_f", "wear": 0, "reach": 85.0},
	# jump + P armed: a chop down, in place of the hammer fist
	"chop": {"startup": 4, "active": 8, "recovery": 0, "low": 20.0, "high": 170.0, "damage": 2, "effect": "",
		"limb": "hand_f", "wear": 1},
}
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
	d["reach"] = minf(w["reach"], d["reach"]) if d.has("reach") else w["reach"]  # the handle jab is short whatever it is
	d["startup"] = maxi(2, d["startup"] + w["speed"])
	if move != "chop":
		d["recovery"] = maxi(4, d["recovery"] + w["speed"] * 2)
	if move == "smash":
		d["effect"] = w["smash"]
	return d


## The loose weapon a fighter standing at (x, z) can pick up from the street's items, or {}.
static func within_reach(items: Array, x: float, z: float) -> Dictionary:
	for it in items:
		if is_weapon(it["kind"]) and absf(it["x"] - x) <= PICK_UP_REACH and absf(it["z"] - z) <= PICK_UP_REACH:
			return it
	return {}
