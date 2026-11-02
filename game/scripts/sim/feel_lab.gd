extends RefCounted
## The feel lab's logic (L-1): which numbers can be changed while playing, by how much, within what limits, and how
## a set of changes is saved and loaded. It edits the very table the fighter reads, so a change is felt at once.

const Tuning := preload("res://scripts/sim/tuning.gd")

## [key, label, step, min, max]
const SETTINGS := [
	["walk_speed", "Walk speed (px/tick)", 0.25, 1.0, 12.0],
	["depth_speed", "Up/down the street (px/tick)", 0.2, 0.5, 8.0],
	["jump_height", "Jump height (px)", 10.0, 40.0, 400.0],
	["jump_air_ticks", "Jump air time (ticks)", 2, 12, 90],
	["jump_speed", "Running jump speed (px/tick)", 0.25, 0.0, 14.0],
	["air_steer", "Steering in the air (0-1)", 0.1, 0.0, 1.0],
	["land_ticks", "Landing pause (ticks)", 1, 0, 20],
	["punch_startup", "Punch start-up (ticks)", 1, 1, 20],
	["punch_active", "Punch active (ticks)", 1, 1, 12],
	["punch_recovery", "Punch recovery (ticks)", 1, 0, 30],
	["kick_startup", "Kick start-up (ticks)", 1, 1, 30],
	["kick_active", "Kick active (ticks)", 1, 1, 12],
	["kick_recovery", "Kick recovery (ticks)", 1, 0, 40],
	["buffer_ticks", "Early-press window (ticks)", 1, 0, 20],
	["combo_window_ticks", "Combo window (ticks, 60 = 1 s)", 2, 4, 90],
	["camera_zoom", "Camera zoom", 0.05, 0.6, 2.0],
	["flat_line", "Flat line instead of street", true, false, true],
]

var tune: Dictionary
var index := 0


func _init(table: Dictionary) -> void:
	tune = table


func current() -> Array:
	return SETTINGS[index]


func select(step: int) -> void:
	index = posmod(index + step, SETTINGS.size())


func nudge(direction: int) -> void:
	var s: Array = current()
	var key: String = s[0]
	if tune[key] is bool:
		tune[key] = not tune[key]
		return
	var v = tune[key] + s[2] * direction
	v = clamp(v, s[3], s[4])
	tune[key] = int(v) if s[2] is int else snappedf(v, 0.001)


func reset_current() -> void:
	tune[current()[0]] = Tuning.DEFAULTS[current()[0]]


func reset_all() -> void:
	for s in SETTINGS:
		tune[s[0]] = Tuning.DEFAULTS[s[0]]


## Only the settings that differ from the defaults, so a saved file reads as "what Javier changed".
func changes() -> Dictionary:
	var out := {}
	for s in SETTINGS:
		if tune[s[0]] != Tuning.DEFAULTS[s[0]]:
			out[s[0]] = tune[s[0]]
	return out


## Applies a saved set. Unknown keys are ignored and values are held to their limits; returns how many applied.
func load_changes(saved: Dictionary) -> int:
	var n := 0
	for s in SETTINGS:
		if not saved.has(s[0]):
			continue
		var v = saved[s[0]]
		if Tuning.DEFAULTS[s[0]] is bool:
			if v is bool:
				tune[s[0]] = v
				n += 1
		elif v is float or v is int:
			v = clamp(v, s[3], s[4])
			tune[s[0]] = int(v) if s[2] is int else float(v)
			n += 1
	return n


func lines() -> PackedStringArray:
	var out := PackedStringArray()
	for i in SETTINGS.size():
		var s: Array = SETTINGS[i]
		var v = tune[s[0]]
		var mark := "▶ " if i == index else "   "
		var changed := "" if v == Tuning.DEFAULTS[s[0]] else "   (default %s)" % str(Tuning.DEFAULTS[s[0]])
		out.append("%s%s: %s%s" % [mark, s[1], ("on" if v else "off") if v is bool else str(v), changed])
	return out
