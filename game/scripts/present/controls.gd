extends RefCounted
## Keyboard and gamepad controls, set up in code so they're easy to read and test.
## Keyboard: arrows or WASD move, J or Z punch, K or X kick, Space or L jump.
## Gamepad: left stick or d-pad moves, X/Square punch, B/Circle kick, A/Cross jump.
## The full dead-zone and drifting-stick work is its own TODO item; this is the basic map.

const DEAD_ZONE := 0.25

const KEYS := {
	"move_left": [KEY_LEFT, KEY_A], "move_right": [KEY_RIGHT, KEY_D],
	"move_up": [KEY_UP, KEY_W], "move_down": [KEY_DOWN, KEY_S],
	"punch": [KEY_J, KEY_Z], "kick": [KEY_K, KEY_X], "jump": [KEY_SPACE, KEY_L],
}
const PAD_BUTTONS := {
	"move_left": [JOY_BUTTON_DPAD_LEFT], "move_right": [JOY_BUTTON_DPAD_RIGHT],
	"move_up": [JOY_BUTTON_DPAD_UP], "move_down": [JOY_BUTTON_DPAD_DOWN],
	"punch": [JOY_BUTTON_X], "kick": [JOY_BUTTON_B], "jump": [JOY_BUTTON_A],
}
const PAD_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
}


static func ensure() -> void:
	for action in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, DEAD_ZONE)
		for k in KEYS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
		for b in PAD_BUTTONS.get(action, []):
			var e := InputEventJoypadButton.new()
			e.button_index = b
			InputMap.action_add_event(action, e)
		if PAD_AXES.has(action):
			var e := InputEventJoypadMotion.new()
			e.axis = PAD_AXES[action][0]
			e.axis_value = PAD_AXES[action][1]
			InputMap.action_add_event(action, e)


## This tick's input for the fighter, in the shape fighter.gd reads.
static func read() -> Dictionary:
	return {
		"mx": Input.get_axis("move_left", "move_right"),
		"mz": Input.get_axis("move_up", "move_down"),
		"jump": Input.is_action_just_pressed("jump"),
		"punch": Input.is_action_just_pressed("punch"),
		"kick": Input.is_action_just_pressed("kick"),
	}
