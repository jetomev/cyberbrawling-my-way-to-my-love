extends RefCounted
## The things on the street a fighter cannot walk through (DESIGN: obstacles are smashed or jumped, never walked
## through): crates, cars, barriers. Each sits on a footprint (x and depth) and has a height. A fighter below an
## object's top is blocked by it; above it, the top is a floor to land and stand on. Breakable objects lose strength
## to blows and break. Plain logic, like fighter.gd; fighters ask it questions, and step_hits() settles the smashing.

const BODY_HALF_WIDTH := 24.0  # how far a fighter's body reaches left and right of their x
const BODY_HALF_DEPTH := 6.0

## Each object: {id, kind, x0, x1, z0, z1, top, climbable, breakable, strength, broken}
var objects: Array[Dictionary] = []
var _hit_log := {}  # attack serial -> ids it already hit, so one blow hits an object once


func add(kind: String, x0: float, x1: float, z0: float, z1: float, top: float, climbable := true, strength := 0) -> Dictionary:
	var o := {"id": objects.size(), "kind": kind, "x0": x0, "x1": x1, "z0": z0, "z1": z1, "top": top,
		"climbable": climbable, "breakable": strength > 0, "strength": strength, "broken": false}
	objects.append(o)
	return o


## The street as it stands in the grey box: something to smash, something to climb, something to go around.
static func grey_street():
	var w = new()
	w.add("crate", 1080.0, 1160.0, 40.0, 120.0, 96.0, true, 4)
	w.add("car", 1900.0, 2160.0, 30.0, 130.0, 130.0, true)
	w.add("crate", 2620.0, 2700.0, 90.0, 160.0, 96.0, true, 4)
	w.add("barrier", 3150.0, 3190.0, 0.0, 90.0, 220.0, false)
	return w


func _covers(o: Dictionary, x: float, z: float) -> bool:
	return x > o["x0"] - BODY_HALF_WIDTH and x < o["x1"] + BODY_HALF_WIDTH \
		and z > o["z0"] - BODY_HALF_DEPTH and z < o["z1"] + BODY_HALF_DEPTH


## True when a body at (x, z) with its feet at height y would be inside something.
func blocks(x: float, z: float, y: float) -> bool:
	for o in objects:
		if not o["broken"] and y < o["top"] - 0.5 and _covers(o, x, z):
			return true
	return false


## The highest surface under (x, z) that is not above the feet: an object's top, or the street (0).
func floor_at(x: float, z: float, y: float) -> float:
	var best := 0.0
	for o in objects:
		if not o["broken"] and o["top"] <= y + 0.5 and o["top"] > best and _covers(o, x, z):
			best = o["top"]
	return best


## The object a body at (x, z, y) would walk into one step ahead, or {}.
func ahead(x: float, z: float, y: float, dir: int, step := 6.0) -> Dictionary:
	for o in objects:
		if not o["broken"] and y < o["top"] - 0.5 and _covers(o, x + dir * step, z):
			return o
	return {}


## Applies every active blow to the breakable objects it covers; returns the ids broken this tick.
func step_hits(fighters: Array) -> Array:
	var broke := []
	for f in fighters:
		var box: Dictionary = f.hit_box()
		if box.is_empty():
			continue
		var blow: Dictionary = f.move()  # damage and height band, from moves.gd
		var seen: Array = _hit_log.get(f.attack_serial, [])
		for o in objects:
			if o["broken"] or not o["breakable"] or o["id"] in seen:
				continue
			var x_ok: bool = box["x1"] > o["x0"] and box["x0"] < o["x1"]
			var z_ok: bool = box["z1"] > o["z0"] and box["z0"] < o["z1"]
			var low: float = f.y + blow["low"]
			var y_ok: bool = low < o["top"] and f.y + blow["high"] > 0.0
			if x_ok and z_ok and y_ok:
				seen.append(o["id"])
				o["strength"] -= blow["damage"]
				if o["strength"] <= 0:
					o["broken"] = true
					broke.append(o["id"])
		_hit_log[f.attack_serial] = seen
	return broke


## Draw order on screen: nearer the viewer draws on top; standing on an object puts you above it.
func draw_order(f) -> int:
	var z := int(f.z)
	for o in objects:
		if not o["broken"] and f.y >= o["top"] - 0.5 and f.y > 0.0 and _covers(o, f.x, f.z):
			z = maxi(z, int(o["z1"]) + 1)
	return z
