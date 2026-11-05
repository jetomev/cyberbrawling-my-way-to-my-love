extends RefCounted
## The things on the street a fighter cannot walk through (DESIGN: obstacles are smashed or jumped, never walked
## through): crates, cars, barriers. Each sits on a footprint (x and depth) and has a height. A fighter below an
## object's top is blocked by it; above it, the top is a floor to land and stand on. Breakable objects lose strength
## to blows and break. Plain logic, like fighter.gd; fighters ask it questions, and step_hits() settles the smashing.

const BODY_HALF_WIDTH := 24.0  # how far a fighter's body reaches left and right of their x
const BODY_HALF_DEPTH := 6.0
## The stairs (the team's level 3 page, "the game's stairs question, answered"): one straight flight at the back of the
## street, rising left to right from its foot (x0) to a landing at its top (the last LANDING px, at "top" height),
## one fighter deep (z0..z1). Walked up and down like the street; from the side it's a wall.
const STEP_UP := 24.0  # how far up a stride can step onto the slope (more than this and it's the side of the flight)
const LANDING := 120.0

## Each object: {id, kind, x0, x1, z0, z1, top, climbable, breakable, strength, broken}
var objects: Array[Dictionary] = []
var _hit_log := {}  # attack serial -> ids it already hit, so one blow hits an object once
## Things lying on the street that can be picked up: {kind, x, z} (a knocked-down enemy drops his weapon here)
var items: Array[Dictionary] = []


func add(kind: String, x0: float, x1: float, z0: float, z1: float, top: float, climbable := true, strength := 0) -> Dictionary:
	var o := {"id": objects.size(), "kind": kind, "x0": x0, "x1": x1, "z0": z0, "z1": z1, "top": top,
		"climbable": climbable, "breakable": strength > 0, "strength": strength, "broken": false,
		"solid": not kind in ["ladder", "stairs", "chandelier"]}  # (a chandelier hangs high: you walk under it)
	objects.append(o)
	return o


func drop(kind: String, x: float, z: float, y := 0.0) -> Dictionary:
	var it := {"kind": kind, "x": x, "z": z, "y": y}  # y: lying up on something (an awning roof), not the street
	items.append(it)
	return it


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


## True when a body at (x, z) with its feet at height y would be inside something (the side of a flight of stairs
## too: the slope is more than a stride above his feet there).
func blocks(x: float, z: float, y: float) -> bool:
	for o in objects:
		if o["solid"] and not o["broken"] and y < o["top"] - 0.5 and _covers(o, x, z):
			return true
		if o["kind"] == "stairs" and _on_flight(o, x, z) and step_height(o, x) > y + STEP_UP:
			return true
	return false


## The highest surface under (x, z) that is not above the feet: an object's top, a step of the stairs within a
## stride, or the street (0).
func floor_at(x: float, z: float, y: float) -> float:
	var best := 0.0
	for o in objects:
		if o["solid"] and not o["broken"] and o["top"] <= y + 0.5 and o["top"] > best and _covers(o, x, z):
			best = o["top"]
		elif o["kind"] == "stairs" and _on_flight(o, x, z) and step_height(o, x) <= y + STEP_UP:
			best = maxf(best, step_height(o, x))
	return best


## The object a body at (x, z, y) would walk into one step ahead, or {}.
func ahead(x: float, z: float, y: float, dir: int, step := 6.0) -> Dictionary:
	for o in objects:
		if o["solid"] and not o["broken"] and y < o["top"] - 0.5 and _covers(o, x + dir * step, z):
			return o
		if o["kind"] == "stairs" and _on_flight(o, x + dir * step, z) and step_height(o, x + dir * step) > y + STEP_UP:
			return o
	return {}


## The stairs: the height of the step at x (the street at the foot, "top" on the landing).
static func step_height(o: Dictionary, x: float) -> float:
	return o["top"] * clampf((x - o["x0"]) / maxf(1.0, o["x1"] - LANDING - o["x0"]), 0.0, 1.0)


## The step under (x, z) if it's on a flight's footprint (else 0): where something placed there stands.
static func step_height_at(w, x: float, z: float) -> float:
	for o in w.objects:
		if o["kind"] == "stairs" and x >= o["x0"] and x <= o["x1"] and z >= o["z0"] - 2.0 and z <= o["z1"] + 2.0:
			return step_height(o, x)
	return 0.0


## Over the flight's footprint (one fighter deep: only the depth the steps take, not a body's width either side).
func _on_flight(o: Dictionary, x: float, z: float) -> bool:
	return x >= o["x0"] and x <= o["x1"] and z >= o["z0"] - 2.0 and z <= o["z1"] + 2.0


## The flight a body at (x, z, y) stands on (its feet on a step, within a stride), or {}.
func stairs_under(x: float, z: float, y: float) -> Dictionary:
	for o in objects:
		if o["kind"] == "stairs" and _on_flight(o, x, z) and absf(step_height(o, x) - y) <= STEP_UP:
			return o
	return {}


## On the slope itself, below the top landing: where a push kick or knockdown sends him tumbling.
static func on_slope(o: Dictionary, x: float) -> bool:
	return x > o["x0"] and x < o["x1"] - LANDING


## A ladder (leaning on something tall at the back of the street: a stall's awning) the body at (x, z, y) stands at:
## {ladder, at: "foot" or "top"}, or {}. A ladder doesn't block anyone; it's climbed (fighter.gd).
func ladder_near(x: float, z: float, y: float) -> Dictionary:
	for o in objects:
		if o["kind"] != "ladder" or absf(x - (o["x0"] + o["x1"]) * 0.5) > 40.0:
			continue
		if y < 1.0 and z <= o["z1"] + 50.0:
			return {"ladder": o, "at": "foot"}
		if absf(y - o["top"]) < 2.0:
			return {"ladder": o, "at": "top"}
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
				o["hits"] = o.get("hits", 0) + 1  # (who hit it last and how: level 5's vending machine counts kicks)
				o["hit_team"] = f.team  # (the side and the move, not the fighter: no reference kept)
				o["hit_move"] = f.state
				o["hit_kick"] = f.from_kick
				o["hit_x"] = f.x  # (where the blow came from: level 4's punching bag swings away from it)
				o["hit_y"] = f.y  # (and how high: level 5's chandelier falls only to a blow from the balcony)
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
		elif o["kind"] == "stairs" and f.y > 0.0 and _on_flight(o, f.x, f.z):
			z = maxi(z, int(o["z1"]) + 1)  # on the steps: drawn on them, not behind their front
	return z
