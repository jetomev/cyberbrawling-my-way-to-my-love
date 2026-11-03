extends RefCounted
## One fighter's body and moves, stepped one tick at a time. No nodes, no engine time: the same inputs always give
## the same result, so tests and the bot can drive it bare. The hero uses it now; enemies will too.
##
## Space: x runs along the street, z is the depth of the street (0 = far edge), y is height above the street.
## An input is a Dictionary: {mx: -1..1, mz: -1..1, jump, punch, kick, block, run, stance: bool}; jump, punch, kick
## and stance are "pressed this tick"; block and run are "held" (D-19: hold to guard; its first moments are a perfect
## block). Two stances (Javier, 2026-11-02 18:48: "W for running, X to swtich stance (fight/walk)"): the fight stance
## (guard "idle", the shuffle "walk") and the walk stance (relaxed "stand", the everyday walk "stroll"); X switches
## between them through a short "to_walk" / "to_fight"; running ("run" held: alone, the way he faces; with an arrow, that way) works from either and
## comes back to it. A blow, a block or a press from the walk stance raises the guard first ("to_fight"): the press
## waits through it. A world (street_world.gd) is optional: without one the street is empty.
## Attacks and combos live in moves.gd: the state is the move's name ("punch", "cross", "spin_kick", …).

const Tuning := preload("res://scripts/sim/tuning.gd")
const Moves := preload("res://scripts/sim/moves.gd")

const GROUND_STATES := ["idle", "walk", "stand", "stroll", "run"]
const SWITCH_STATES := ["to_walk", "to_fight"]
const DOUBLE_TAP_TICKS := 3
const MAX_QUEUE := 2  # P then K pressed during one long blow play P then K
const AIR_STATES := ["jump", "air_kick", "hammer_fist"]

var tune: Dictionary
var world = null
var x := 0.0
var z := 0.0
var y := 0.0  # feet height; standing on a car, y is the car's top
var vx := 0.0
var vy := 0.0
var facing := 1  # 1 = right, -1 = left
var state := "idle"
var stance := "fight"  # "fight" (the guard) or "walk" (relaxed)
var squat_mx := 0.0  # the stick when the jump was pressed: a running jump still carries forward from its crouch
var t := 0  # ticks spent in the current state
var queue: Array[String] = []  # buttons pressed early, in order, waiting for the fighter to be free
var buffer_left := 0  # once free, how long the waiting presses stay good
var clock := 0  # ticks since this fighter was made
var last_press := -100  # the tick of the last attack button that counted
var chain := ""  # the combo so far ("P", "PK", …); "" = none
var chain_left := 0  # ticks left to continue the chain once free
var attack_serial := 0  # counts attacks, so a world can tell one blow from the next
var air_kicked := false  # one air attack (flying kick or hammer fist) per jump
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
	clock += 1
	for b in ["jump", "punch", "kick"]:
		if inp.get(b, false):
			# during a blow, a press is kept until the blow ends, so a rhythm of presses chains a combo; a press
			# hard on the heels of the last one (a bounced or doubled tap) is dropped, so it can't fire twice
			if b != "jump":
				if clock - last_press < DOUBLE_TAP_TICKS:
					continue
				last_press = clock
			if queue.size() < MAX_QUEUE:
				queue.append(b)
			buffer_left = tune["buffer_ticks"]
	t += 1
	if inp.get("stance", false) and state in GROUND_STATES and queue.is_empty():
		vx = 0.0
		stance = "walk" if stance == "fight" else "fight"
		_enter("to_walk" if stance == "walk" else "to_fight")
		return
	match state:
		"idle", "walk", "stand", "stroll", "run":
			_ground(mx, mz, inp.get("run", false))
		"to_walk", "to_fight":
			if t >= tune["stance_switch_ticks"]:
				_enter(_rest())
		"jump", "air_kick", "hammer_fist":
			if state == "jump" and not queue.is_empty() and queue[0] in ["punch", "kick"] and not air_kicked:
				var move: String = Moves.AIR["P" if _take_buffer() == "punch" else "K"]
				air_kicked = true
				attack_serial += 1
				_enter(move)
			_air(mx)
		"block":
			if mx != 0.0:
				facing = 1 if mx > 0.0 else -1  # turn to face a threat without dropping the guard
			if not inp.get("block", false):
				_enter("idle")
		"land":
			if t >= tune["land_ticks"]:
				_enter(_rest())
		"jump_squat":
			# the crouch before take-off, feet planted; then the legs drive him up (the stick steers the jump)
			if t >= tune["jump_squat_ticks"]:
				vy = Tuning.takeoff_speed(tune)
				vx = (mx if mx != 0.0 else squat_mx) * tune["jump_speed"]
				_enter("jump")
		"climb":
			_climb()
		_:
			if _ground_attack() and t >= attack_length(state):
				chain_left = tune["combo_window_ticks"]
				_enter("idle")
	# a blow or a block from the walk stance raises the guard first; the press waits through it
	if stance == "walk" and state in GROUND_STATES and (inp.get("block", false) or (not queue.is_empty() and queue[0] != "jump")):
		vx = 0.0
		stance = "fight"
		_enter("to_fight")
	# a fighter who just became free acts on a buffered button in the same tick
	if (state in GROUND_STATES or state == "block") and not queue.is_empty():
		_start(_take_buffer(), mx)  # a press from the guard comes straight out of it
	if state in GROUND_STATES and inp.get("block", false):
		chain = ""
		vx = 0.0
		_enter("block")
	if not _ground_attack() and not state in SWITCH_STATES:
		if chain_left > 0:
			chain_left -= 1
		if chain_left == 0:
			chain = ""
		if buffer_left > 0:
			buffer_left -= 1
			if buffer_left == 0:
				queue.clear()


func _ground_attack() -> bool:
	return Moves.is_move(state) and not Moves.is_air(state)


func _take_buffer() -> String:
	return queue.pop_front()


func _blocked(nx: float, nz: float) -> bool:
	return world != null and world.blocks(nx, nz, y)


## Where a free fighter rests: the guard in the fight stance, standing relaxed in the walk stance.
func _rest() -> String:
	return "idle" if stance == "fight" else "stand"


func _ground(mx: float, mz: float, run := false) -> void:
	if run and mx == 0.0:
		mx = float(facing)  # W alone runs the way he faces; an arrow steers it (Javier, 2026-11-02: "W don't work")
	var moving: bool = mx != 0.0 or (mz != 0.0 and not tune["flat_line"])
	var speed := "walk_speed"
	if run and moving:
		speed = "run_speed"
	elif stance == "walk":
		speed = "stroll_speed"
	vx = mx * tune[speed]
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
	var next := _rest()
	if moving:
		next = "run" if run else ("walk" if stance == "fight" else "stroll")
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
		_enter(_rest())


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
		chain = ""
		vx = 0.0
		if tune["jump_squat_ticks"] > 0:
			squat_mx = mx
			_enter("jump_squat")  # a crouch first: recorded jumps load the legs before they leave the ground
		else:
			vy = Tuning.takeoff_speed(tune)
			vx = mx * tune["jump_speed"]
			_enter("jump")
	else:
		vx = 0.0
		attack_serial += 1
		var link: Array = Moves.next(chain, "P" if action == "punch" else "K")
		chain = link[0]
		chain_left = 0
		_enter(link[1])


func _enter(s: String) -> void:
	state = s
	t = 0


## "perfect" in a block's first perfect_block_ticks, "block" after that, "" when not blocking.
func blocking() -> String:
	if state != "block":
		return ""
	return "perfect" if t < tune["perfect_block_ticks"] else "block"


func on_ground() -> bool:
	return not state in AIR_STATES


func attack_length(a: String) -> int:
	return Moves.length(a, tune)


## "startup", "active" or "recovery" while attacking; "" otherwise. Air attacks stay out until landing.
func attack_phase() -> String:
	if not Moves.is_move(state):
		return ""
	var d := Moves.data(state, tune)
	if t < d["startup"]:
		return "startup"
	if t < d["startup"] + d["active"]:
		return "active"
	return "recovery"


## The move being thrown, with its damage and effect (moves.gd), or {}.
func move() -> Dictionary:
	return Moves.data(state, tune) if Moves.is_move(state) else {}


## The space a blow covers this tick, or {} when nothing can be hit: {x0, x1, z0, z1} on the street.
func hit_box() -> Dictionary:
	if attack_phase() != "active":
		return {}
	var reach: float = move()["reach"]
	var near := x + facing * 20.0
	var far := x + facing * reach
	return {"x0": minf(near, far), "x1": maxf(near, far), "z0": z - tune["hit_depth"], "z1": z + tune["hit_depth"]}


func snapshot() -> Array:
	return [snappedf(x, 0.001), snappedf(z, 0.001), snappedf(y, 0.001), facing, state, t]
