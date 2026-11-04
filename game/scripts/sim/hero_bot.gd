extends RefCounted
## A bot that plays the hero (L-8: a bot that plays the whole game catches breakage early). It walks to the nearest
## enemy still standing, lines up on the street, throws the hero's combos and raises its guard now and then. Seeded,
## so a run replays the same. Not clever: steady, so a fight it loses or can't finish is a finding.

var me
var dice := RandomNumberGenerator.new()
var tick := 0
var combo: Array = []  # the presses of the combo under way
var block_left := 0
var read_serial := -1
var goal := -1.0  # a doorway or ladder to take when the street is clear (the level tells it: level.next_door())
const COMBOS := [["punch", "punch", "punch"], ["kick", "kick", "kick"], ["punch", "kick", "punch"], ["punch", "punch", "kick"], ["sweep"]]


func _init(hero, dice_seed := 1) -> void:
	me = hero
	dice.seed = dice_seed


func think(enemies: Array) -> Dictionary:
	tick += 1
	var inp := {}
	var foe = null
	for e in enemies:
		if not e.defeated() and (foe == null or absf(e.x - me.x) < absf(foe.x - me.x)):
			foe = e
	if foe == null:
		if goal >= 0.0 and absf(me.x - goal) < 30.0:
			inp["mz"] = -1.0  # at the doorway or ladder: into it, up
			return inp
		inp["mx"] = 1.0 if goal < 0.0 or goal > me.x else -1.0  # nobody to fight: walk on (to the next wave, the way up)
		_get_past(inp)
		return inp
	var dx: float = foe.x - me.x
	var toward := 1.0 if dx >= 0.0 else -1.0
	if block_left > 0:
		block_left -= 1
		inp["block"] = true
		if me.facing != int(toward):
			inp["mx"] = toward
		return inp
	if foe.attack_phase() == "startup" and absf(dx) < 200.0 and foe.attack_serial != read_serial:
		read_serial = foe.attack_serial
		if dice.randf() < 0.55:
			block_left = 20
			inp["block"] = true
			return inp
	var dz: float = foe.z - me.z
	if absf(dz) > 6.0:
		inp["mz"] = clampf(dz / 16.0, -1.0, 1.0)
	if absf(dx) > 115.0:
		inp["mx"] = toward
	elif me.facing != int(toward):
		inp["mx"] = toward * 0.01
	elif not foe.hittable():
		pass  # he's down: wait for him to get up
	elif combo.is_empty() and me.state in ["idle", "walk"] and absf(dz) <= me.tune["hit_depth"]:
		combo = (COMBOS[dice.randi_range(0, COMBOS.size() - 1)] as Array).duplicate()
	if not combo.is_empty() and tick % 9 == 0:
		inp[combo.pop_front()] = true
	return inp


## Something in the way (a barrier, a crate, a car): smash it if it breaks, jump it if he can clear it, or step round it
## along the street's depth. Never walk through (DESIGN).
func _get_past(inp: Dictionary) -> void:
	if me.world == null or not me.state in ["idle", "walk"]:
		return
	var o: Dictionary = me.world.ahead(me.x, me.z, me.y, 1, 30.0)
	if o.is_empty():
		return
	if o["breakable"]:
		inp.erase("mx")
		if tick % 20 == 0:
			inp["kick"] = true
	elif o["top"] - me.y <= me.tune["jump_height"] - 5.0:
		if tick % 30 == 0:
			inp["jump"] = true
	else:
		inp["mz"] = 1.0 if o["z1"] < me.tune["street_depth"] - 10.0 else -1.0  # round it
