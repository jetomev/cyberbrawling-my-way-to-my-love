extends RefCounted
## Who hits whom (Stage 1: an enemy that fights back). Each tick, every blow that's out (a fighter's hit_box()) lands
## on each fighter of the other team its box covers, once per blow: along the street, up and down its depth, and in
## height (a jab flies over a man lying down, a sweep under a jump). The one hit reacts (fighter.take_hit()). Plain
## logic like fighter.gd, so tests and the bot drive it bare.
##
## D-19: a plain block takes less pain; a perfect block takes none and stops the attacker's combo. A fighter knocked
## down drops what he carries, onto the street (street_world.gd's items).

const Moves := preload("res://scripts/sim/moves.gd")

const BODY_HALF_WIDTH := 24.0  # as street_world.gd
const BODY_HEIGHT := 300.0  # feet to the top of the head, standing

const SPACE := 64.0  # two standing fighters' centres never come closer than this along the street (no walking through)

var _hit := {}  # attacker id -> [attack serial, ids already hit by that blow]


## Settles this tick's blows. Returns what happened, one entry per blow that landed:
## {attacker, target, result ("hit", "blocked", "perfect", "evaded"), move, drop (what fell, or ""), counter (caught
## winding up), broke (the part the blow broke, or ""), worn (the weapon that broke on it, or "")}.
func step(fighters: Array, world = null) -> Array:
	var events := []
	for a in fighters:
		var box: Dictionary = a.hit_box()
		if box.is_empty():
			continue
		var blow: Dictionary = a.move()
		blow["finisher"] = Moves.is_finisher(a.state)
		blow["move"] = a.state
		blow["weapon_speed"] = Moves.Weapons.TABLE[a.weapon]["speed"] if a.weapon != "" and Moves.Weapons.is_swing(a.state) else 0
		if a.soft:
			blow["damage"] = 0.0  # practice: it lands, it doesn't hurt
		var id: int = a.get_instance_id()
		var seen: Array = _hit.get(id, [-1, []])
		if seen[0] != a.attack_serial:
			seen = [a.attack_serial, []]
		for d in fighters:
			if d == a or d.team == a.team or d.get_instance_id() in seen[1]:
				continue
			if box["x1"] <= d.x - BODY_HALF_WIDTH or box["x0"] >= d.x + BODY_HALF_WIDTH:
				continue
			if d.z < box["z0"] or d.z > box["z1"]:
				continue
			if a.y + blow["low"] >= d.y + BODY_HEIGHT or a.y + blow["high"] <= d.y:
				continue
			var winding_up: bool = d.attack_phase() == "startup"  # caught as he starts a blow: a counter
			# a low kick into the Doorman's bash knocks his shield aside, and he spins round, open (the team's roster)
			if winding_up and d.weapon == "shield" and blow["move"] == "kick":
				_disarm(d, world, a.x)
				d.facing = -d.facing
			var result: String = d.take_hit(blow, a)
			if result == "":
				continue
			seen[1].append(d.get_instance_id())
			if result == "umbrella":
				events.append({"attacker": a, "target": d, "result": "umbrella", "move": a.state, "drop": "", "counter": false,
					"broke": "", "worn": ""})
				continue
			var drop := ""
			# D-19: the right hit (a counter, caught winding up) or a perfect block interrupts him and can disarm him;
			# knocked down he drops it too
			if result == "hit" and (winding_up or d.state in ["knockdown", "launch"]) and d.weapon != "":
				drop = _disarm(d, world, a.x)
			if result == "perfect":
				a.chain = ""  # a perfect block stops his combo: the presses he'd lined up are gone
				a.queue.clear()
				if a.weapon != "" and not a.grip:
					drop = _disarm(a, world, d.x)
			if result == "hit":
				a.finishers_taken = 0  # landing a blow of his own breaks a run of combos on him
			var worn := ""
			if result == "hit":
				worn = a.wear(blow.get("wear", 0))  # a weapon wears only on a hit; kicks never wear it (the team's combos)
			events.append({"attacker": a, "target": d, "result": result, "move": a.state, "drop": drop, "counter": winding_up and result == "hit",
				"broke": d.just_broke, "worn": worn})
		_hit[id] = seen
	return events


## Knocks his weapon out of his hand: it flies a step away from whoever knocked it loose (from_x) and lands on the
## street, out from under his feet (the disarm trial, 2026-11-03: dropped at his feet, he picked it straight back up).
const FLY := 80.0


static func _disarm(f, world, from_x: float) -> String:
	var what: String = f.drop_weapon()
	if f.weapon_snaps:
		return what  # it bends and breaks as it lands: nothing to pick up
	if world != null:
		var away := 1.0 if f.x >= from_x else -1.0
		world.drop(what, clampf(f.x + away * FLY, f.tune["street_left"], f.tune["street_right"]), f.z)
	return what


## Bodies don't pass through each other: two fighters on their feet at about the same depth are pushed apart along
## the street, each half the overlap (one lying down, or in the air above the other, is passed over).
static func separate(fighters: Array) -> void:
	for i in fighters.size():
		for j in range(i + 1, fighters.size()):
			var a = fighters[i]
			var b = fighters[j]
			if not a.hittable() or not b.hittable() or absf(a.z - b.z) > BODY_HALF_WIDTH or absf(a.y - b.y) > 100.0:
				continue
			var gap: float = b.x - a.x
			if absf(gap) >= SPACE:
				continue
			var side := 1.0 if gap > 0.0 or (gap == 0.0 and a.facing > 0) else -1.0
			var push := (SPACE - absf(gap)) * 0.5
			for pair in [[a, -side], [b, side]]:
				var f = pair[0]
				var nx: float = clampf(f.x + pair[1] * push, f.tune["street_left"], f.tune["street_right"])
				if f.world == null or not f.world.blocks(nx, f.z, f.y):
					f.x = nx
