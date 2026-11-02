extends RefCounted
## One fighter's body and moves, stepped one tick at a time. No nodes, no engine time: the same inputs always give
## the same result, so tests and the bot can drive it bare. The hero uses it now; enemies will too.
##
## Space: x runs along the street, z is the depth of the street (0 = far edge), y is height above the ground.
## An input is a Dictionary: {mx: -1..1, mz: -1..1, jump: bool, punch: bool, kick: bool}; the buttons are
## "pressed this tick", not "held".

const Tuning := preload("res://scripts/sim/tuning.gd")

const GROUND_STATES := ["idle", "walk"]
const ATTACKS := ["punch", "kick"]

var tune: Dictionary
var x := 0.0
var z := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var facing := 1  # 1 = right, -1 = left
var state := "idle"
var t := 0  # ticks spent in the current state
var buffered := ""  # a button pressed early, waiting for the fighter to be free
var buffer_left := 0


func _init(tuning: Dictionary = {}, start_x := 200.0, start_z := 80.0) -> void:
	tune = tuning if not tuning.is_empty() else Tuning.fresh()
	x = start_x
	z = start_z


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
		"jump":
			_air(mx)
		"land":
			if t >= tune["land_ticks"]:
				_enter("idle")
		"punch", "kick":
			if t >= attack_length(state):
				_enter("idle")
	# a fighter who just became free acts on a buffered button in the same tick
	if state in GROUND_STATES and buffered != "":
		_start(buffered, mx)
	if buffer_left > 0:
		buffer_left -= 1
		if buffer_left == 0:
			buffered = ""


func _ground(mx: float, mz: float) -> void:
	var speed: float = tune["walk_speed"]
	vx = mx * speed
	x = clampf(x + vx, tune["street_left"], tune["street_right"])
	if not tune["flat_line"]:
		z = clampf(z + mz * tune["depth_speed"], 0.0, tune["street_depth"])
	if mx != 0.0:
		facing = 1 if mx > 0.0 else -1
	var moving: bool = mx != 0.0 or (mz != 0.0 and not tune["flat_line"])
	var next: String = "walk" if moving else "idle"
	if next != state:
		_enter(next)


func _air(mx: float) -> void:
	var speed: float = tune["walk_speed"]
	# a jump keeps its momentum; only a pushed stick bends it (letting go mid-air must not brake)
	if mx != 0.0:
		vx = lerpf(vx, mx * speed, tune["air_steer"] * 0.1)
	x = clampf(x + vx, tune["street_left"], tune["street_right"])
	y += vy
	vy -= Tuning.gravity(tune)
	if y <= 0.0:
		y = 0.0
		vy = 0.0
		_enter("land")


func _start(action: String, mx: float) -> void:
	buffered = ""
	buffer_left = 0
	if action == "jump":
		vy = Tuning.takeoff_speed(tune)
		vx = mx * tune["walk_speed"]
		_enter("jump")
	else:
		vx = 0.0
		_enter(action)


func _enter(s: String) -> void:
	state = s
	t = 0


func on_ground() -> bool:
	return state != "jump"


func attack_length(a: String) -> int:
	return tune[a + "_startup"] + tune[a + "_active"] + tune[a + "_recovery"]


## "startup", "active" or "recovery" while attacking; "" otherwise.
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
