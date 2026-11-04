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
	"wait_min": 40,  # ticks between his attacks (a fair window for the hero)
	"wait_max": 90,
	"block_chance": 0.3,  # how often he raises his guard against a blow he sees coming
	"block_ticks": 22,
	"combos": [["punch"], ["punch", "punch"], ["kick"], ["punch", "punch", "punch"], ["kick", "kick", "kick"],
		["kick", "punch", "kick"]],
}

var me
var foe
var kind: Dictionary
var dice := RandomNumberGenerator.new()
var wait := 0  # ticks until he may start his next attack
var plan: Array = []  # the presses left in the combo he is throwing
var pressed_on := -1  # the blow (attack serial) during which he pressed the next one: one press per blow
var block_left := 0
var read_serial := -1  # the foe's blow he already decided about


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
	# line up on the street's depth, then close to the distance he wants
	var dz: float = foe.z - me.z
	if absf(dz) > 6.0:
		inp["mz"] = clampf(dz / 16.0, -1.0, 1.0)
	var want: float = kind["strike"] if wait == 0 else kind["keep"]
	if dist > want + 6.0:
		inp["mx"] = toward
	elif me.facing != int(toward):
		inp["mx"] = toward * 0.01  # a tiny step just to turn and face him
	if wait == 0 and dist <= kind["strike"] + 8.0 and absf(dz) <= me.tune["hit_depth"] and me.state in Fighter.GROUND_STATES:
		plan = (kind["combos"][dice.randi_range(0, kind["combos"].size() - 1)] as Array).duplicate()
		inp[plan.pop_front()] = true
		pressed_on = -1
		inp.erase("mx")
		wait = dice.randi_range(kind["wait_min"], kind["wait_max"])
	return inp
