extends RefCounted
## One fighter's body and moves, stepped one tick at a time. No nodes, no engine time: the same inputs always give
## the same result, so tests and the bot can drive it bare. The hero uses it now; enemies will too.
##
## Space: x runs along the street, z is the depth of the street (0 = far edge), y is height above the street.
## An input is a Dictionary: {mx: -1..1, mz: -1..1, jump: bool, punch: bool, kick: bool}; the buttons are
## "pressed this tick", not "held". A world (street_world.gd) is optional: without one the street is empty.

const Tuning := preload("res://scripts/sim/tuning.gd")

const GROUND_STATES := ["idle", "walk"]
const AIR_STATES := ["jump", "air_kick"]
const ATTACKS := ["punch", "kick", "air_kick"]

var tune: Dictionary
var world = null
var x := 0.0
var z := 0.0
var y := 0.0  # feet height; standing on a car, y is the car's top
var vx := 0.0
var vy := 0.0
var facing := 1  # 1 = right, -1 = left
var state := "idle"
var t := 0  # ticks spent in the current state
var buffered := ""  # a button pressed early, waiting for the fighter to be free
var buffer_left := 0
var attack_serial := 0  # counts attacks, so a world can tell one blow from the next
var air_kicked := false  # one flying kick per jump
var push_ticks := 0  # how long the stick has pushed into something climbable
var climb_from := Vector2.ZERO  # (x, y) where a climb started
var climb_to := Vector2.ZERO  # (x, y) where it ends, on top


func _init(tuning: Dictionary = {}, start_x := 200.0, start_z := 80.0, street = null) -> void:
	tune = tuning if not tuning.is_empty() else Tuning.fresh()
	x = start_x
	z = start_z
	world = street


func step(inp: Dictionary) -> void:
	var mx: float = clampf(inp.get("mx", 0.0), -1.0, 1.0)
	var mz: float = clampf(inp.get("mz", 0.0), -1.0, 1.0)
	for b in ["jump", "punch", "kick"]:
		if inp.get(b, false):
			buffered = b
			buffer_left = tune["buffer_ticks"]
	t += 1
	match state:
		"idle", "walk":
			_ground(mx, mz)
		"jump", "air_kick":
			if state == "jump" and buffered == "kick" and not air_kicked:
				_take_buffer()
				air_kicked = true
				attack_serial += 1
				_enter("air_kick")
			_air(mx)
		"land":
			if t >= tune["land_ticks"]:
				_enter("idle")
		"climb":
			_climb()
		"punch", "kick":
			if t >= attack_length(state):
				_enter("idle")
	# a fighter who just became free acts on a buffered button in the same tick
	if state in GROUND_STATES and buffered != "":
		_start(_take_buffer(), mx)
	if buffer_left > 0:
		buffer_left -= 1
		if buffer_left == 0:
			buffered = ""


func _take_buffer() -> String:
	var b := buffered
	buffered = ""
	buffer_left = 0
	return b


func _blocked(nx: float, nz: float) -> bool:
	return world != null and world.blocks(nx, nz, y)


func _ground(mx: float, mz: float) -> void:
	vx = mx * tune["walk_speed"]
	var nx := clampf(x + vx, tune["street_left"], tune["street_right"])
	if mx != 0.0:
		facing = 1 if mx > 0.0 else -1
	if _blocked(nx, z):
		_push(mx)
	else:
		x = nx
		push_ticks = 0
	if not tune["flat_line"]:
		var nz := clampf(z + mz * tune["depth_speed"], 0.0, tune["street_depth"])
		if not _blocked(x, nz):
			z = nz
	if state == "climb":
		return
	if world != null and world.floor_at(x, z, y) < y - 0.5:
		vy = 0.0  # walked off an edge: fall
		_enter("jump")
		return
	var moving: bool = mx != 0.0 or (mz != 0.0 and not tune["flat_line"])
	var next: String = "walk" if moving else "idle"
	if next != state:
		_enter(next)


## Pushing into something: after a moment, climb it if it's climbable and not too tall.
func _push(mx: float) -> void:
	if mx == 0.0:
		push_ticks = 0
		return
	var o: Dictionary = world.ahead(x, z, y, facing)
	if o.is_empty() or not o["climbable"] or o["top"] - y > tune["climb_max"]:
		push_ticks = 0
		return
	push_ticks += 1
	if push_ticks >= tune["climb_hold_ticks"]:
		push_ticks = 0
		var edge: float = o["x0"] if facing == 1 else o["x1"]
		climb_from = Vector2(x, y)
		climb_to = Vector2(edge + facing * 30.0, o["top"])
		_enter("climb")


func _climb() -> void:
	var k := clampf(float(t) / float(tune["climb_ticks"]), 0.0, 1.0)
	# up first, then over the edge
	y = lerpf(climb_from.y, climb_to.y, clampf(k * 1.6, 0.0, 1.0))
	x = lerpf(climb_from.x, climb_to.x, clampf(k * 1.6 - 0.6, 0.0, 1.0))
	if k >= 1.0:
		y = climb_to.y
		x = climb_to.x
		_enter("idle")


func _air(mx: float) -> void:
	# a jump keeps its momentum; only a pushed stick bends it (letting go mid-air must not brake)
	if mx != 0.0:
		vx = lerpf(vx, mx * tune["jump_speed"], tune["air_steer"] * 0.1)
	var nx := clampf(x + vx, tune["street_left"], tune["street_right"])
	if _blocked(nx, z):
		vx = 0.0  # bumped into the side of something
	else:
		x = nx
	var ground: float = 0.0 if world == null else world.floor_at(x, z, y)
	y += vy
	vy -= Tuning.gravity(tune)
	if y <= ground:
		y = ground
		vy = 0.0
		air_kicked = false
		_enter("land")


func _start(action: String, mx: float) -> void:
	if action == "jump":
		vy = Tuning.takeoff_speed(tune)
		vx = mx * tune["jump_speed"]
		_enter("jump")
	else:
		vx = 0.0
		attack_serial += 1
		_enter(action)


func _enter(s: String) -> void:
	state = s
	t = 0


func on_ground() -> bool:
	return not state in AIR_STATES


func attack_length(a: String) -> int:
	return tune[a + "_startup"] + tune[a + "_active"] + tune[a + "_recovery"]


## "startup", "active" or "recovery" while attacking; "" otherwise. A flying kick stays out until landing.
func attack_phase() -> String:
	if not state in ATTACKS:
		return ""
	if t < tune[state + "_startup"]:
		return "startup"
	if t < tune[state + "_startup"] + tune[state + "_active"]:
		return "active"
	return "recovery"


## The space a blow covers this tick, or {} when nothing can be hit: {x0, x1, z0, z1} on the street.
func hit_box() -> Dictionary:
	if attack_phase() != "active":
		return {}
	var reach: float = tune[state + "_reach"]
	var near := x + facing * 20.0
	var far := x + facing * reach
	return {"x0": minf(near, far), "x1": maxf(near, far), "z0": z - tune["hit_depth"], "z1": z + tune["hit_depth"]}


func snapshot() -> Array:
	return [snappedf(x, 0.001), snappedf(z, 0.001), snappedf(y, 0.001), facing, state, t]
