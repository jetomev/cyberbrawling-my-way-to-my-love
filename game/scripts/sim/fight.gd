extends RefCounted
## Who hits whom (Stage 1: an enemy that fights back). Each tick, every blow that's out (a fighter's hit_box()) lands
## on each fighter of the other team its box covers, once per blow: along the street, up and down its depth, and in
## height (a jab flies over a man lying down, a sweep under a jump). The one hit reacts (fighter.take_hit()). Plain
## logic like fighter.gd, so tests and the bot drive it bare.
##
## D-19: a plain block takes less pain; a perfect block takes none and stops the attacker's combo. A fighter knocked
## down drops what he carries, onto the street (street_world.gd's items).

const BODY_HALF_WIDTH := 24.0  # as street_world.gd
const BODY_HEIGHT := 300.0  # feet to the top of the head, standing

const SPACE := 64.0  # two standing fighters' centres never come closer than this along the street (no walking through)

var _hit := {}  # attacker id -> [attack serial, ids already hit by that blow]


## Settles this tick's blows. Returns what happened, one entry per blow that landed:
## {attacker, target, result ("hit", "blocked", "perfect", "evaded"), move, drop (what fell, or "")}.
func step(fighters: Array, world = null) -> Array:
	var events := []
	for a in fighters:
		var box: Dictionary = a.hit_box()
		if box.is_empty():
			continue
		var blow: Dictionary = a.move()
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
			var result: String = d.take_hit(blow, a)
			if result == "":
				continue
			seen[1].append(d.get_instance_id())
			var drop := ""
			if result == "hit" and d.state in ["knockdown", "launch"] and d.weapon != "":
				drop = d.weapon
				d.weapon = ""
				if world != null:
					world.drop(drop, d.x, d.z)
			if result == "perfect":
				a.chain = ""  # a perfect block stops his combo: the presses he'd lined up are gone
				a.queue.clear()
			events.append({"attacker": a, "target": d, "result": result, "move": a.state, "drop": drop})
		_hit[id] = seen
	return events


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
