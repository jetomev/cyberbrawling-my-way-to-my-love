extends RefCounted
## Keyboard and gamepad controls, set up in code so they're easy to read and test.
## Sticks are NOT in the action map: they go through stick_guard.gd (feed()), which ignores a stick stuck off centre
## from the moment it connects (Javier's G13, F-1) and applies the dead zone.
## Keyboard (Javier, 2026-11-02 18:48: "ASDW are not key for walking. Let's do: A for punches, B for kicks, D for
## blocking, W for running, X to swtich stance (fight/walk)"): A punch, B kick, D block (hold), W run (hold), X switch
## stance; the arrows move (what moves the hero is his call still: MOVE_KEYS is the one place to change it); Space
## jump; the old J punch, K kick, L/Shift block still work. Z is the sweep (Javier, 2026-11-02 19:28, through the
## assistant team, on where the sweep goes: "Z key"), its own move, built with the punches and kicks from recorded
## motion; until then Z does nothing (no gamepad button for it yet).
## Gamepad: left stick or d-pad moves, X/Square punch, B/Circle kick, A/Cross jump, Y/Triangle or RB block (hold),
## LB run (hold), the left stick's click switches stance.

const StickGuard := preload("res://scripts/sim/stick_guard.gd")
const DEAD_ZONE := 0.25

static var guard = StickGuard.new()

const MOVE_KEYS := {
	"move_left": [KEY_LEFT], "move_right": [KEY_RIGHT], "move_up": [KEY_UP], "move_down": [KEY_DOWN],
}
const KEYS := {
	"move_left": MOVE_KEYS["move_left"], "move_right": MOVE_KEYS["move_right"],
	"move_up": MOVE_KEYS["move_up"], "move_down": MOVE_KEYS["move_down"],
	"punch": [KEY_A, KEY_J], "kick": [KEY_B, KEY_K], "jump": [KEY_SPACE], "block": [KEY_D, KEY_L, KEY_SHIFT],
	"run": [KEY_W], "stance": [KEY_X], "sweep": [KEY_Z],
}
const PAD_BUTTONS := {
	"move_left": [JOY_BUTTON_DPAD_LEFT], "move_right": [JOY_BUTTON_DPAD_RIGHT],
	"move_up": [JOY_BUTTON_DPAD_UP], "move_down": [JOY_BUTTON_DPAD_DOWN],
	"punch": [JOY_BUTTON_X], "kick": [JOY_BUTTON_B], "jump": [JOY_BUTTON_A],
	"block": [JOY_BUTTON_Y, JOY_BUTTON_RIGHT_SHOULDER],
	"run": [JOY_BUTTON_LEFT_SHOULDER], "stance": [JOY_BUTTON_LEFT_STICK],
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


## Forgets every stick (tests, and a fresh start).
static func reset() -> void:
	guard = StickGuard.new()


## Hands every stick movement to the guard; call it from the game's _input.
static func feed(event: InputEvent, now_ms := -1) -> void:
	if event is InputEventJoypadMotion:
		guard.feed(event.device, event.axis, event.axis_value, Time.get_ticks_msec() if now_ms < 0 else now_ms)


## This tick's input for the fighter, in the shape fighter.gd reads: keys and d-pad, plus the guarded stick.
static func read() -> Dictionary:
	var s: Vector2 = guard.stick()
	return {
		"mx": clampf(Input.get_axis("move_left", "move_right") + s.x, -1.0, 1.0),
		"mz": clampf(Input.get_axis("move_up", "move_down") + s.y, -1.0, 1.0),
		"jump": Input.is_action_just_pressed("jump"),
		"punch": Input.is_action_just_pressed("punch"),
		"kick": Input.is_action_just_pressed("kick"),
		"block": Input.is_action_pressed("block"),
		"run": Input.is_action_pressed("run"),
		"stance": Input.is_action_just_pressed("stance"),
	}
