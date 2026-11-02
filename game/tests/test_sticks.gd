extends "res://tests/test_case.gd"
## Thumbsticks (L-6, F-1): a stick stuck at full left from the moment it connects (Javier's G13) moves nothing; a
## real stick moved by a hand works; the dead zone swallows drift; unplugging a pad starts it over.

const StickGuard := preload("res://scripts/sim/stick_guard.gd")
const Controls := preload("res://scripts/present/controls.gd")


## The G13 at connect, as Godot delivers it: 0 then -1 in the same instant, on both axes.
func g13_burst(feed: Callable, device := 0, at_ms := 1000) -> void:
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		feed.call(device, axis, 0.0, at_ms)
		feed.call(device, axis, -1.0, at_ms)


func motion(device: int, axis: int, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = device
	e.axis = axis
	e.axis_value = value
	return e


func test_the_g13_does_not_walk_the_hero_left() -> void:
	# end to end, through Godot's own input and the game's controls: the exact way F-1 happened
	Controls.ensure()
	var c = Controls.new()
	if c.has_method("reset"):
		c.call("reset")
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		for v in [0.0, -1.0]:
			var e := motion(0, axis, v)
			Input.parse_input_event(e)
			if c.has_method("feed"):
				c.call("feed", e, 1000)
	Input.flush_buffered_events()
	for t in [1100, 1500, 3000]:
		var inp: Dictionary = Controls.read()
		eq(inp["mx"], 0.0, "a G13 stuck at full left does not walk the hero (%d ms)" % t)
		eq(inp["mz"], 0.0, "nor up the street")
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		Input.parse_input_event(motion(0, axis, 0.0))
	Input.flush_buffered_events()
	if c.has_method("reset"):
		c.call("reset")


func test_stuck_stick_is_ignored() -> void:
	var g = StickGuard.new()
	g13_burst(g.feed)
	eq(g.stick(), Vector2.ZERO, "stuck at full left and up: nothing")
	g.feed(0, JOY_AXIS_LEFT_X, -1.0, 5000)  # still stuck, much later
	eq(g.stick(), Vector2.ZERO, "still nothing seconds later")
	check(not g.trusted(0, JOY_AXIS_LEFT_X), "not trusted until seen centred")


func test_a_real_stick_works() -> void:
	var g = StickGuard.new()
	g.feed(1, JOY_AXIS_LEFT_X, 0.0, 1000)  # connect burst at rest
	g.feed(1, JOY_AXIS_LEFT_X, 0.0, 1400)  # resting, after the burst
	check(g.trusted(1, JOY_AXIS_LEFT_X), "seen centred after its burst = trusted")
	g.feed(1, JOY_AXIS_LEFT_X, -1.0, 1600)  # a hand pushes it left
	eq(g.stick().x, -1.0, "full left walks left")
	g.feed(1, JOY_AXIS_LEFT_X, 0.6, 1700)
	check(g.stick().x > 0.4 and g.stick().x < 0.6, "a medium push is a medium walk (%.2f)" % g.stick().x)


func test_a_stuck_stick_that_gets_moved_starts_working() -> void:
	var g = StickGuard.new()
	g13_burst(g.feed)
	g.feed(0, JOY_AXIS_LEFT_X, -0.1, 2000)  # the hand moves it through the middle
	g.feed(0, JOY_AXIS_LEFT_X, 1.0, 2100)
	eq(g.stick().x, 1.0, "once it passes the middle, it counts")
	eq(g.stick().y, 0.0, "the other axis, still stuck, does not")


func test_drift_is_swallowed() -> void:
	var g = StickGuard.new()
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		g.feed(0, axis, 0.0, 0)
		g.feed(0, axis, 0.0, 400)
	g.feed(0, JOY_AXIS_LEFT_X, -0.18, 500)  # a worn stick resting a little left
	g.feed(0, JOY_AXIS_LEFT_Y, 0.12, 500)
	eq(g.stick(), Vector2.ZERO, "drift inside the dead zone moves nothing")


func test_unplugging_starts_over() -> void:
	var g = StickGuard.new()
	g.feed(0, JOY_AXIS_LEFT_X, 0.0, 0)
	g.feed(0, JOY_AXIS_LEFT_X, 0.0, 400)
	check(g.trusted(0, JOY_AXIS_LEFT_X), "trusted")
	g.forget(0)
	check(not g.trusted(0, JOY_AXIS_LEFT_X), "after unplugging, not trusted")
	g13_burst(g.feed, 0, 9000)
	eq(g.stick(), Vector2.ZERO, "plugged back in stuck: nothing again")


func test_sticks_are_not_in_the_action_map() -> void:
	Controls.ensure()
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		for e in InputMap.action_get_events(action):
			check(not e is InputEventJoypadMotion, "%s takes no raw stick (it would bypass the guard)" % action)
