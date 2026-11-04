extends RefCounted
## Things thrown that fly along the street (DJ Volt's records, in the team's boss list; later a thrown weapon). Each
## flies straight at its own height band; it hits the first fighter of the other side it meets (once), and a fighter
## dodges it by being elsewhere: up or down the street's depth, over it in a jump, under it, or round in a roll. A
## perfect block sends it back the way it came, now on the blocker's side (the team: "perfect-block one and it flies
## back at him"). Plain logic like fight.gd.

const BODY_HALF_WIDTH := 24.0
const BODY_HEIGHT := 300.0
const DEPTH := 22.0  # how far up or down the street it still catches someone

## Each: {x, z, y0, y1 (its height band above the street), vx, damage, effect, team, kind, alive, x_from}
var flying: Array[Dictionary] = []


func throw(kind: String, x: float, z: float, y0: float, y1: float, vx: float, damage: float, team: int, effect := "") -> Dictionary:
	var p := {"x": x, "z": z, "y0": y0, "y1": y1, "vx": vx, "damage": damage, "effect": effect, "team": team, "kind": kind,
		"alive": true, "x_from": x}
	flying.append(p)
	return p


## Moves everything one tick and settles what it meets. Returns what happened: {target, result, kind, projectile}.
func step(fighters: Array, left: float, right: float) -> Array:
	var events := []
	for p in flying:
		if not p["alive"]:
			continue
		p["x"] += p["vx"]
		if p["x"] < left - 200.0 or p["x"] > right + 200.0:
			p["alive"] = false
			continue
		if p.has("range") and absf(p["x"] - p["x_from"]) > p["range"]:
			p["alive"] = false  # a thrown weapon at the end of its flight: it drops (level.gd lays it on the street)
			events.append({"target": null, "result": "landed", "kind": p["kind"], "projectile": p})
			continue
		for f0 in fighters:
			if f0.team == p["team"] or absf(f0.x - p["x"]) > BODY_HALF_WIDTH or absf(f0.z - p["z"]) > DEPTH:
				continue
			# a held hero: it hits whoever holds him (the team's house rule: nobody hits a held hero)
			var f = f0.held_by if f0.state == "held" and f0.held_by != null and not f0.held_by.defeated() else f0
			if p["y1"] <= f.y or p["y0"] >= f.y + BODY_HEIGHT:
				continue  # over him or under him (he jumped it)
			# the blow comes from where it flies from: a fighter-like stand-in for take_hit's "attacker"
			var from := {"x": p["x"] - signf(p["vx"]) * 10.0, "y": 0.0}
			var blow := {"damage": p["damage"], "effect": p["effect"], "low": p["y0"], "high": p["y1"], "move": p["kind"]}
			if p.get("catchable", false) and f.catches and f.weapon == "" and signf(p["vx"]) == -float(f.facing):
				f.take_weapon(p["kind"])  # caught out of the air, and his now (the Godfather)
				p["alive"] = false
				events.append({"target": f, "result": "caught", "kind": p["kind"], "projectile": p})
				break
			var result: String = f.take_hit(blow, from)
			if result == "":
				continue  # lying down: it flies over
			if result == "perfect" and p.get("catchable", false) and f.weapon == "":
				f.take_weapon(p["kind"])  # a thrown weapon caught: it's his now (the Wrench Mechanic's wrench)
				p["alive"] = false
				result = "caught"
			elif result == "perfect":
				p["vx"] = -p["vx"] * 1.2  # back the way it came, harder
				p["team"] = f.team
			elif result != "evaded":
				p["alive"] = false
			if result != "evaded":
				events.append({"target": f, "result": result, "kind": p["kind"], "projectile": p})
				break
	flying = flying.filter(func(p): return p["alive"])
	return events
