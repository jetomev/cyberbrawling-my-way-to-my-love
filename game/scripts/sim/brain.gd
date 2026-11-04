extends RefCounted
## An enemy's mind (Stage 1: one enemy type that fights back). Each tick it looks at itself and its foe and gives its
## fighter the same kind of input the keyboard gives the hero, so an enemy moves and hits by exactly the hero's rules.
## It walks up, lines up on the street's depth, waits a breath, steps in and throws a combo (its own presses chain by
## the same table, moves.gd), and sometimes raises its guard when the hero winds up. A seeded dice, so a fight replays
## the same every time (tests, the bot).

const Fighter := preload("res://scripts/sim/fighter.gd")

## How this enemy type fights; another type is another table.
const THUG := {
	"keep": 170.0,  # waiting distance, out of the hero's jab
	"strike": 112.0,  # how close he steps in to throw
	"wait_min": 55,  # ticks between his attacks (a fair window for the hero)
	"wait_max": 110,
	"block_chance": 0.3,  # how often he raises his guard against a blow he sees coming
	"block_ticks": 22,
	"combos": [["punch"], ["punch", "punch"], ["kick"], ["punch", "punch", "punch"], ["kick", "kick", "kick"],
		["kick", "punch", "kick"]],
}

## The level 1 boss: bigger, tougher (level.gd gives him his health), quicker to come again, blocks more, and his
## combos run longer and heavier. The team's enemy table replaces these with each boss's own.
const BOSS := {
	"keep": 160.0,
	"strike": 118.0,
	"wait_min": 22,
	"wait_max": 55,
	"block_chance": 0.45,
	"block_ticks": 26,
	"combos": [["punch", "punch", "punch"], ["kick", "kick", "kick"], ["punch", "kick", "punch"], ["kick", "punch", "kick"],
		["punch", "punch", "kick"]],
}
const HANG_BACK := 130.0  # how much further off an enemy waits while it isn't his turn to attack

## The team's enemy table (art-in 2026-11-03). The Glow Punk, the warm-up: "Slap Happy", slap, slap, a two-handed
## shove (jab, cross, push kick by the hero's own table); no counter; quick to come again, never blocks.
const GLOW_PUNK := {
	"keep": 170.0, "strike": 110.0, "wait_min": 50, "wait_max": 100, "block_chance": 0.0, "block_ticks": 0,
	"combos": [["punch", "punch", "kick"], ["punch", "punch"], ["punch"]],
}
## The Bruiser, the big lad: "Wrecking Ball", heavy blows (jab, cross, power punch for now; the hooks and the body slam
## come with his own poses); shrugs off a jab (level.gd); slow to come again, blocks sometimes.
const BRUISER := {
	"keep": 170.0, "strike": 115.0, "wait_min": 70, "wait_max": 130, "block_chance": 0.25, "block_ticks": 24,
	"combos": [["punch", "punch", "punch"], ["punch", "punch"], ["kick", "kick", "kick"]],
}
## DJ Volt, level 1's boss (the team's boss list): from range he throws his records ("Scratch": low, middle, high,
## level.gd flies them); close in, the mic stand. His "Bass Drop" (a guard held too long while his speakers stand
## pushes you back) is level.gd's, since it needs the speakers.
const DJ_VOLT := {
	"keep": 170.0, "strike": 120.0, "wait_min": 45, "wait_max": 90, "block_chance": 0.3, "block_ticks": 22,
	"combos": [["punch", "punch", "punch"], ["punch", "punch"], ["kick", "punch", "kick"]],
	"records_from": 280.0,  # further off than this, he throws instead
	"records_every": 110,
}
## Snick, the knife girl (the team's roster): "Paper Cuts", three quick slashes (her knife's swing, backswing,
## smash), and from further off a dash in, knife first; "Backstep", she hops back out of the slow end kicks (the side
## kick, the roundhouse). Beaten by a perfect block on her dash, or a low kick into a slash's wind-up (both knock the
## knife away).
const SNICK := {
	"keep": 180.0, "strike": 125.0, "wait_min": 35, "wait_max": 75, "block_chance": 0.0, "block_ticks": 0,
	"combos": [["punch", "punch", "punch"], ["punch", "punch"], ["punch"]],
	"dash_from": 260.0, "dash_to": 520.0,  # between these, she dashes in
	"backstep": ["side_kick", "roundhouse"],
}
## Big Mama Noodle, level 2's boss (the team's roster): "Order Up", ladle, ladle, then a wok smash that knocks a guard
## open (her wok's swing, backswing, smash); from across the kitchen she charges (level.gd: onto the wet patch, she
## slips). The hot soup and the floor are level.gd's.
const BIG_MAMA := {
	"keep": 170.0, "strike": 120.0, "wait_min": 45, "wait_max": 90, "block_chance": 0.2, "block_ticks": 20,
	"combos": [["punch", "punch", "punch"]],
	"dash_from": 300.0, "dash_to": 1900.0,  # her charge
}
## Every enemy type's way of fighting, by name (level.gd's KINDS points here).
const TYPES := {"THUG": THUG, "BOSS": BOSS, "GLOW_PUNK": GLOW_PUNK, "BRUISER": BRUISER, "DJ_VOLT": DJ_VOLT,
	"SNICK": SNICK, "BIG_MAMA": BIG_MAMA}

var me
var foe
var kind: Dictionary
var dice := RandomNumberGenerator.new()
var wait := 0  # ticks until he may start his next attack
var plan: Array = []  # the presses left in the combo he is throwing
var pressed_on := -1  # the blow (attack serial) during which he pressed the next one: one press per blow
var block_left := 0
var read_serial := -1  # the foe's blow he already decided about
var allowed := true  # a level lets only a couple of enemies attack at once; the others hang back, waiting their turn
var dormant_until_within := 0.0  # hidden (the lamppost in level 1): still until the hero comes this close, then out


func _init(fighter, target, dice_seed := 1, how: Dictionary = THUG) -> void:
	me = fighter
	foe = target
	kind = how
	dice.seed = dice_seed
	wait = dice.randi_range(kind["wait_min"], kind["wait_max"])


## This tick's input for his fighter.
func think() -> Dictionary:
	var inp := {}
	if foe == null or foe.defeated() or me.state in Fighter.HURT_STATES:
		plan.clear()
		block_left = 0
		return inp
	if dormant_until_within > 0.0:
		if absf(foe.x - me.x) > dormant_until_within:
			return inp  # still hiding
		dormant_until_within = 0.0
		wait = 0  # he jumps out swinging
	var dx: float = foe.x - me.x
	var toward := 1.0 if dx >= 0.0 else -1.0
	var dist := absf(dx)
	# the guard: held a moment once raised; decided once per blow he sees winding up near him
	if block_left > 0:
		block_left -= 1
		inp["block"] = true
		if me.facing != int(toward):
			inp["mx"] = toward  # turn to face the blow without dropping the guard
		return inp
	# a backstep out of the slow kicks she reads coming (Snick)
	if kind.has("backstep") and foe.state in kind["backstep"] and foe.attack_phase() == "startup" and dist < 240.0 \
			and foe.attack_serial != read_serial and me.state in Fighter.GROUND_STATES:
		read_serial = foe.attack_serial
		inp["roll"] = true
		inp["mx"] = -toward
		return inp
	if foe.attack_phase() == "startup" and dist < 220.0 and foe.attack_serial != read_serial and plan.is_empty():
		read_serial = foe.attack_serial
		if dice.randf() < kind["block_chance"]:
			block_left = kind["block_ticks"]
			inp["block"] = true
			return inp
	# a combo under way: the next press as the last blow recovers, so it chains
	if not plan.is_empty():
		if me.attack_phase() == "recovery" and me.attack_serial != pressed_on:
			pressed_on = me.attack_serial
			inp[plan.pop_front()] = true
		return inp
	if wait > 0:
		wait -= 1
	# a dasher (Snick): from mid range she runs straight in, then slashes
	if kind.has("dash_from") and wait == 0 and dist > kind["dash_from"] and dist < kind["dash_to"] and me.state in Fighter.GROUND_STATES:
		inp["run"] = true
		inp["mx"] = toward
		return inp
	# a thrower, far off: a volley of records (level.gd flies them), then a breath
	if kind.has("records_from") and dist > kind["records_from"] and wait == 0 and me.state in Fighter.GROUND_STATES:
		wait = kind["records_every"]
		if me.facing != int(toward):
			inp["mx"] = toward * 0.01
		inp["throw"] = true
		return inp
	# line up on the street's depth, then close to the distance he wants
	var dz: float = foe.z - me.z
	if absf(dz) > 6.0:
		inp["mz"] = clampf(dz / 16.0, -1.0, 1.0)
	var want: float = kind["strike"] if wait == 0 and allowed else kind["keep"] + (0.0 if allowed else HANG_BACK)
	if dist > want + 6.0:
		inp["mx"] = toward
	elif me.facing != int(toward):
		inp["mx"] = toward * 0.01  # a tiny step just to turn and face him
	if wait == 0 and allowed and dist <= kind["strike"] + 8.0 and absf(dz) <= me.tune["hit_depth"] and me.state in Fighter.GROUND_STATES:
		plan = (kind["combos"][dice.randi_range(0, kind["combos"].size() - 1)] as Array).duplicate()
		inp[plan.pop_front()] = true
		pressed_on = -1
		inp.erase("mx")
		wait = dice.randi_range(kind["wait_min"], kind["wait_max"])
	return inp
