extends RefCounted
## A bot that plays the hero (L-8: a bot that plays the whole game catches breakage early). It walks to the nearest
## enemy still standing, lines up on the street, throws the hero's combos and raises its guard now and then. Seeded,
## so a run replays the same. Not clever: steady, so a fight it loses or can't finish is a finding.

const Brain := preload("res://scripts/sim/brain.gd")
const Fighter := preload("res://scripts/sim/fighter.gd")

var me
var dice := RandomNumberGenerator.new()
var tick := 0
var combo: Array = []  # the presses of the combo under way
var block_left := 0
var read_serial := -1
var eat_x := -1.0e9  # where the food errand is heading
var stall_x := 0.0  # where it last made headway along the street (unsticking: hero_bot think)
var stall_at := 0
var last_combo: Array = []  # the combo it threw last (against someone who reads combos, never the same twice running)
var goal := -1.0  # a doorway or ladder to take when the street is clear (the level tells it: level.next_door())
var goal_hit := false  # the goal is a switch to hit, not a way through (level.goal_is_switch)
var jump_cue := false  # something low is about to sweep through him: jump (level.crane_jump_cue())
var climb := {}  # where to climb to follow the fight up or down a ladder: {x, z, mz} (level.climb_cue())
var dodge_x := 0.0  # a shadow on him, something falling: step this way along the street (level.shadow_cue())
const COMBOS := [["punch", "punch", "punch"], ["kick", "kick", "kick"], ["punch", "kick", "punch"], ["punch", "punch", "kick"], ["sweep"]]


func _init(hero, dice_seed := 1) -> void:
	me = hero
	dice.seed = dice_seed


func think(enemies: Array) -> Dictionary:
	var inp: Dictionary = _think(enemies)
	# at a ladder's foot "up" climbs it, at its top "down" does: a step in depth to line up on someone there isn't a
	# climb, so it's dropped unless he means to climb (the level's climb cue)
	if me.world != null and climb.is_empty() and absf(inp.get("mz", 0.0)) > 0.5:
		var lad: Dictionary = me.world.ladder_near(me.x, me.z, me.y)
		if not lad.is_empty() and ((lad["at"] == "foot" and inp["mz"] < 0.0) or (lad["at"] == "top" and inp["mz"] > 0.0)):
			inp.erase("mz")
	return inp


func _think(enemies: Array) -> Dictionary:
	tick += 1
	var inp := {}
	var foe = null
	for e in enemies:
		if me.world != null and e.flight().is_empty() and me.flight().is_empty() \
				and absf(me.world.floor_at(e.x, e.z, e.y + 1.0) - me.world.floor_at(me.x, me.z, me.y + 1.0)) > 180.0:
			continue  # (standing up on a stack, or below it: out of reach; the level's climb cue takes him there)
		if not e.defeated() and (foe == null or absf(e.x - me.x) < absf(foe.x - me.x)):
			foe = e
	if jump_cue and me.state in ["idle", "walk", "block", "run"]:
		inp["jump"] = true  # the crane's container, low across the floor; up on a stack (level 6), across the gap ahead
		if me.y > 1.0:
			inp["mx"] = float(me.facing)
		return inp
	if not climb.is_empty() and me.state in ["idle", "walk", "block", "run"]:
		var z_first: bool = climb.get("z_first", false)  # (in line with its foot first, past a stack's side; but at another
		if z_first and absf(me.z - climb["z"]) > 10.0:  # ladder's top, along first: a step in depth there takes him down it)
			inp["mz"] = clampf((climb["z"] - me.z) / 16.0, -1.0, 1.0)
		elif absf(me.x - climb["x"]) > 10.0:
			inp["mx"] = clampf((climb["x"] - me.x) / 20.0, -1.0, 1.0)
		elif absf(me.z - climb["z"]) > 10.0:
			inp["mz"] = clampf((climb["z"] - me.z) / 16.0, -1.0, 1.0)
		else:
			inp["mz"] = climb["mz"]
		return inp
	if dodge_x != 0.0 and me.state in ["idle", "walk", "block", "run"]:
		inp["mx"] = dodge_x  # out of the shadow before it lands (level 4's wrenches from the balcony)
		return inp
	if foe == null and me.health < me.max_health * 0.6 and _go_eat(inp):
		return inp
	# badly hurt mid-fight, nobody right on him: break off for the food (the props hold it in level 3)
	if foe != null and me.health < me.max_health * 0.35 and absf(foe.x - me.x) > 160.0 and _go_eat(inp):
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
			if absf(me.x - goal) > 4.0:
				inp["mx"] = signf(goal - me.x) * 0.5  # (and the last steps along: from the right, a stair's side is too high)
			return inp
		inp["mx"] = 1.0 if goal < 0.0 or goal > me.x else -1.0  # nobody to fight: walk on (to the next wave, the way up)
		_get_past(inp)
		# no headway for a second and a half (hung on a prop's corner): out toward the front of the street, then on
		if absf(me.x - stall_x) > 3.0:
			stall_x = me.x
			stall_at = tick
		elif tick - stall_at > 90:
			inp["mz"] = 1.0 if me.z < me.tune["street_depth"] - 20.0 else -1.0
			inp.erase("jump")
			if tick - stall_at > 150:
				stall_at = tick
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
	if me.world != null and me.state in ["idle", "walk"] and absf(dx) > 60.0:  # a gap between them (the fire escape): jump it
		var gap: Dictionary = me.world.ahead(me.x, me.z, me.y, int(toward), 30.0)
		if not gap.is_empty() and gap["kind"] == "gap":
			inp["jump"] = true
			inp["mx"] = toward
			return inp
	if absf(dx) > 115.0 and Brain.around(me, toward, inp):
		inp["mx"] = toward
		return inp
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
	# the Doorman's lesson: block his shield, and low-kick as his bash winds up (it knocks the shield aside)
	var between: Dictionary = me.world.ahead(me.x, me.z, me.y, int(toward), 30.0) if me.world != null else {}
	if foe.weapon == "shield" and foe.facing == -int(toward) and absf(dx) < 160.0 and between.is_empty():
		if foe.attack_phase() == "startup" and me.state in ["idle", "walk", "block"]:
			inp["kick"] = true
		elif me.state in ["idle", "walk", "block"]:
			inp["block"] = true
			if me.facing != int(toward):
				inp["mx"] = toward * 0.01
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
		while "punch" in foe.shrugs and combo[0] == "punch":  # (he shrugs off punches, the Bruiser: kicks)
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


## Hurt, with the street clear: food or a first-aid kit lying near, or a prop holding some (the team's level 3: "the
## props carry the food"), to walk over or smash. Fills inp and returns true while he's on his way.
func _go_eat(inp: Dictionary) -> bool:
	if me.world == null:
		return false
	if not me.state in ["idle", "walk"]:
		if me.state in ["jump_squat", "jump", "land", "kick"] and eat_x > -1.0e8:
			inp["mx"] = signf(eat_x - me.x) if absf(eat_x - me.x) > 6.0 else 0.0  # (mid-way there: keep heading for it)
			return true
		return false
	var best := {}
	var best_d := 1400.0
	for it in me.world.items:
		if Fighter.HEALS.has(it["kind"]) and absf(it.get("y", 0.0) - me.y) < 20.0 and absf(it["x"] - me.x) < best_d:
			best = {"x": it["x"], "z": it["z"], "smash": false}
			best_d = absf(it["x"] - me.x)
	for o in me.world.objects:
		var cx: float = (o["x0"] + o["x1"]) * 0.5
		var vending: bool = o["kind"] == "vending" and not o["broken"] and int(o.get("kicks", 0)) == 0  # (level 5: its first
		# kick gives a snack; only the first: the second gives a note, the third tips it over onto whoever's in front)
		if (vending or (o["breakable"] and not o["broken"] and Fighter.HEALS.has(o.get("holds", "")))) and absf(cx - me.x) < best_d:
			var zc: float = (o["z0"] + o["z1"]) * 0.5
			var near_side: float = o["x0"] - 50.0 if me.x < cx else o["x1"] + 50.0
			var far_side: float = o["x1"] + 50.0 if me.x < cx else o["x0"] - 50.0
			var side: float = near_side if not me.world.blocks(near_side, zc, 0.0) else far_side  # (a free spot beside it)
			if me.world.blocks(side, zc, 0.0):
				continue  # boxed in on both sides: not for the bot
			best = {"x": cx, "z": zc, "smash": true, "side": side}
			best_d = absf(cx - me.x)
	if best.is_empty():
		eat_x = -1.0e9
		return false
	var tx: float = best["side"] if best["smash"] else best["x"]
	eat_x = tx
	var tz: float = clampf(best["z"], 0.0, me.tune["street_depth"])
	if best["smash"] and absf(me.x - tx) < 12.0 and absf(me.z - tz) <= 8.0:
		var face := 1 if best["x"] > me.x else -1
		if me.facing != face:
			inp["mx"] = face * 0.01
		elif tick % 20 == 0:
			inp["kick"] = true  # smash it open
		return true
	inp["mx"] = signf(tx - me.x) if absf(tx - me.x) > 6.0 else 0.0
	inp["mz"] = clampf((tz - me.z) / 16.0, -1.0, 1.0) if absf(tz - me.z) > 6.0 else 0.0
	if inp["mx"] != 0.0:  # something in the way of the food: jump it (a gap, a low prop) or step round it
		var o: Dictionary = me.world.ahead(me.x, me.z, me.y, int(inp["mx"]), 30.0)
		if not o.is_empty() and o["kind"] == "gap":
			if tick % 30 == 0:
				inp["jump"] = true
		elif not o.is_empty():
			Brain.around(me, inp["mx"], inp)  # round a prop (not over it: a jump lands him the other side of his aim)
	return true
