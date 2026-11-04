extends RefCounted
## A bot that plays the hero (L-8: a bot that plays the whole game catches breakage early). It walks to the nearest
## enemy still standing, lines up on the street, throws the hero's combos and raises its guard now and then. Seeded,
## so a run replays the same. Not clever: steady, so a fight it loses or can't finish is a finding.

const Brain := preload("res://scripts/sim/brain.gd")

var me
var dice := RandomNumberGenerator.new()
var tick := 0
var combo: Array = []  # the presses of the combo under way
var block_left := 0
var read_serial := -1
var last_combo: Array = []  # the combo it threw last (against someone who reads combos, never the same twice running)
var goal := -1.0  # a doorway or ladder to take when the street is clear (the level tells it: level.next_door())
var goal_hit := false  # the goal is a switch to hit, not a way through (level.goal_is_switch)
var jump_cue := false  # something low is about to sweep through him: jump (level.crane_jump_cue())
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
	if jump_cue and me.state in ["idle", "walk", "block", "run"]:
		inp["jump"] = true  # the crane's container, low across the floor
		return inp
	if foe == null:
		if goal >= 0.0 and goal_hit and absf(me.x - goal) < 60.0:
			if me.facing != (1 if goal >= me.x else -1):
				inp["mx"] = signf(goal - me.x) * 0.01
			elif tick % 20 == 0:
				inp["punch"] = true  # a switch: hit it
			return inp
		if goal >= 0.0 and absf(me.x - goal) < 30.0:
			inp["mz"] = -1.0  # at the doorway or ladder: into it, up
			return inp
		inp["mx"] = 1.0 if goal < 0.0 or goal > me.x else -1.0  # nobody to fight: walk on (to the next wave, the way up)
		_get_past(inp)
		return inp
	if Brain.to_the_stairs(me, foe, inp):
		return inp
	# an armoured coat only the Lovelight cuts (the Godfather's first round): without it in hand, go and get it
	if foe.armour and me.weapon != "lovelight" and me.world != null:
		for it in me.world.items:
			if it["kind"] == "lovelight":
				if me.weapon != "":
					pass  # (walking over it with another weapon in hand won't take it: he keeps fighting with what he has)
				else:
					inp["mx"] = signf(it["x"] - me.x) if absf(it["x"] - me.x) > 6.0 else 0.0
					inp["mz"] = clampf((it["z"] - me.z) / 16.0, -1.0, 1.0)
					return inp
	# a floor slam about to land (Mr. Static's): jump it, timed so he's up while the floor's live
	if foe.slam_in >= 0 and foe.slam_in <= 6 and me.state in ["idle", "walk", "block"]:
		inp["jump"] = true
		return inp
	# a charge coming along his line of the street (Coach Crusher's tackle): step out of it
	if foe.charging and absf(foe.x - me.x) < 600.0 and absf(foe.z - me.z) <= me.tune["hit_depth"] + 20.0 \
			and me.state in ["idle", "walk", "block"]:
		var away := 1.0 if me.z >= foe.z else -1.0  # away from his line, and stick to it
		if (away > 0.0 and me.z > me.tune["street_depth"] - 40.0) or (away < 0.0 and me.z < 40.0):
			away = -away  # no room that way: the other
		inp["mz"] = away
		return inp
	var dx: float = foe.x - me.x
	var toward := 1.0 if dx >= 0.0 else -1.0
	# too fast for anything but a blow into his wind-up (the Godfather's second round): guard up, and jab the moment he
	# starts one
	if foe.only_counters:
		if me.facing != int(toward):
			inp["mx"] = toward * 0.01
		if foe.attack_phase() == "startup" and absf(dx) < 150.0 and me.state in ["idle", "walk", "block"]:
			inp["punch"] = true
		elif absf(dx) > 150.0:
			inp["mx"] = toward
		elif me.state in ["idle", "walk", "block"]:
			inp["block"] = true
		return inp
	if block_left > 0:
		block_left -= 1
		inp["block"] = true
		if me.facing != int(toward):
			inp["mx"] = toward
		return inp
	if foe.attack_phase() == "startup" and absf(dx) < 200.0 and foe.attack_serial != read_serial:
		read_serial = foe.attack_serial
		if dice.randf() < (0.9 if foe.reads_combos else 0.55):
			block_left = 20
			inp["block"] = true
			return inp
	var dz: float = foe.z - me.z
	if absf(dz) > 6.0:
		inp["mz"] = clampf(dz / 16.0, -1.0, 1.0)
	# pinned at the locked street's edge he can't step closer: he swings from where he is (the cross reaches 150; the
	# roster yard, 2026-11-04: a Mechanic standing 119 px past the lock beat him three lives running)
	var pinned: bool = (toward < 0.0 and me.x <= me.tune["street_left"] + 1.0) or (toward > 0.0 and me.x >= me.tune["street_right"] - 1.0)
	if absf(dx) > (140.0 if pinned else 115.0):
		inp["mx"] = toward
	elif me.facing != int(toward):
		inp["mx"] = toward * 0.01
	elif not foe.hittable():
		pass  # he's down: wait for him to get up
	elif combo.is_empty() and me.state in ["idle", "walk"] and absf(dz) <= me.tune["hit_depth"]:
		combo = (COMBOS[dice.randi_range(0, COMBOS.size() - 1)] as Array).duplicate()
		while foe.reads_combos and combo == last_combo:  # he'd read it: mix it up
			combo = (COMBOS[dice.randi_range(0, COMBOS.size() - 1)] as Array).duplicate()
		last_combo = combo.duplicate()
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
