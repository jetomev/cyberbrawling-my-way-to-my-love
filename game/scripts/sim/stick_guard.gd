extends RefCounted
## Thumbsticks, read safely (L-6, F-1). Javier's Logitech G13 thumbstick reports full left and full up while resting:
## at connect Godot delivers 0 then -1 in the same instant, and a plain stick reading walks the hero left forever.
## So a stick axis counts only once it has been seen near the middle AFTER its connect burst (a real stick passes
## the middle as soon as a hand moves it), each pad and axis on its own. A drifting stick that rests a little off
## centre is caught by the dead zone, and the rest of the travel is stretched back to the full 0..1 range.

const DEAD_ZONE := 0.25  # how far a stick must move before it counts
const CENTRE := 0.25  # within this of the middle = "seen centred"
const BURST_MS := 300  # events this soon after an axis is first heard are its connect burst, not a hand

var _value := {}  # "device:axis" -> last raw value
var _first_ms := {}  # "device:axis" -> when its first event came
var _trusted := {}  # "device:axis" -> true once seen centred after its burst


func feed(device: int, axis: int, value: float, now_ms: int) -> void:
	var key := "%d:%d" % [device, axis]
	if not _first_ms.has(key):
		_first_ms[key] = now_ms
	_value[key] = value
	if absf(value) < CENTRE and now_ms - int(_first_ms[key]) > BURST_MS:
		_trusted[key] = true


## A pad was unplugged or plugged in: start over on it, burst and all.
func forget(device: int) -> void:
	for d in [_value, _first_ms, _trusted]:
		for key in d.keys():
			if key.begins_with("%d:" % device):
				d.erase(key)


func trusted(device: int, axis: int) -> bool:
	return _trusted.has("%d:%d" % [device, axis])


## The left stick of every trusted pad, after the dead zone: (x, y), each -1..1.
func stick() -> Vector2:
	var out := Vector2.ZERO
	var devices := {}
	for key in _value:
		devices[int(key.get_slice(":", 0))] = true
	for d in devices:
		var v := Vector2(_axis(d, JOY_AXIS_LEFT_X), _axis(d, JOY_AXIS_LEFT_Y))
		var length := v.length()
		if length < DEAD_ZONE:
			continue
		# stretch what's past the dead zone back to 0..1, so a light push still walks slowly
		v = v / length * minf((length - DEAD_ZONE) / (1.0 - DEAD_ZONE), 1.0)
		out += v
	return out.clamp(Vector2(-1, -1), Vector2(1, 1))


func _axis(device: int, axis: int) -> float:
	var key := "%d:%d" % [device, axis]
	return _value[key] if _trusted.has(key) else 0.0
