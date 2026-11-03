extends "res://tests/test_case.gd"
## Walking and running, and the two stances (Javier, 2026-11-02 18:48: "the character needs to be able to walk, and
## run. ASDW are not key for walking. Let's do: A for punches, B for kicks, D for blocking, W for running, X to swtich
## stance (fight/walk)"). X switches between the fight stance and the walk stance; W held runs from either; a blow or
## a block from the walk stance raises the guard first, and the press isn't lost.

const Fighter := preload("res://scripts/sim/fighter.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")
const Poses := preload("res://scripts/present/poses.gd")
const Controls := preload("res://scripts/present/controls.gd")


func run_for(f, ticks: int, inp := {}) -> void:
	for i in ticks:
		f.step(inp)


func test_x_switches_between_the_fight_stance_and_the_walk_stance() -> void:
	var f = Fighter.new()
	eq([f.stance, f.state], ["fight", "idle"], "he starts in the fight stance, in his guard")
	f.step({"stance": true})
	eq([f.stance, f.state], ["walk", "to_walk"], "X: he eases into the walk stance")
	run_for(f, f.tune["stance_switch_ticks"] + 1)
	eq(f.state, "stand", "and stands easy")
	run_for(f, 3, {"mx": 1.0})
	eq(f.state, "stroll", "moving in the walk stance is an everyday walk")
	check(is_equal_approx(f.vx, f.tune["stroll_speed"]), "at an everyday walking speed")
	f.step({"stance": true})
	eq([f.stance, f.state], ["fight", "to_fight"], "X again: back to the fight stance")
	run_for(f, f.tune["stance_switch_ticks"] + 1)
	eq(f.state, "idle", "his guard up")


func test_w_runs_from_either_stance() -> void:
	for start_walk in [false, true]:
		var f = Fighter.new()
		if start_walk:
			f.step({"stance": true})
			run_for(f, f.tune["stance_switch_ticks"] + 1)
		var x0: float = f.x
		run_for(f, 10, {"mx": 1.0, "run": true})
		eq(f.state, "run", "W held while moving: he runs (from the %s stance)" % f.stance)
		check(is_equal_approx(f.vx, f.tune["run_speed"]), "at the running speed")
		check(f.x - x0 > 10.0 * f.tune["walk_speed"], "covering more street than walking")
		run_for(f, 2)
		eq(f.state, "idle" if not start_walk else "stand", "letting go, he's back in his own stance")


func test_a_blow_from_the_walk_stance_raises_the_guard_first() -> void:
	var f = Fighter.new()
	f.step({"stance": true})
	run_for(f, f.tune["stance_switch_ticks"] + 1)
	f.step({"punch": true})
	eq([f.stance, f.state], ["fight", "to_fight"], "a punch from the walk stance: the guard comes up first")
	var thrown := false
	for i in f.tune["stance_switch_ticks"] + 4:
		f.step({})
		thrown = thrown or f.state == "punch"
	check(thrown, "and then the punch comes out: the press waited, it wasn't lost")
	var g = Fighter.new()
	g.step({"stance": true})
	run_for(g, g.tune["stance_switch_ticks"] + 1)
	g.step({"block": true})
	eq(g.stance, "fight", "a block from the walk stance takes the fight stance too")


func test_the_keys_are_javiers() -> void:
	var k: Dictionary = Controls.KEYS
	# Javier's final set (2026-11-02 21:56, through the assistant team): "A punches, S kicks, D block, W for running, X
	# for stance, z for sweep, c for evation role (direction of the keys), space jump"
	for pair in [["punch", KEY_A], ["kick", KEY_S], ["block", KEY_D], ["run", KEY_W], ["stance", KEY_X], ["sweep", KEY_Z], ["roll", KEY_C], ["jump", KEY_SPACE]]:
		check(pair[1] in k[pair[0]], "%s is on %s" % [pair[0], OS.get_keycode_string(pair[1])])
	for move in ["move_left", "move_right", "move_up", "move_down"]:
		for key in [KEY_A, KEY_S, KEY_D, KEY_W]:
			check(not key in k[move], "%s doesn't move him" % OS.get_keycode_string(key))
	check(not KEY_X in k["kick"], "X isn't a kick any more")
	check(not KEY_B in k["kick"], "B isn't the kick any more (S is)")
	for action in k:
		if action != "roll":
			check(not KEY_C in k[action], "C is only the roll (not %s)" % action)
		if action != "kick":
			check(not KEY_S in k[action], "S is only the kick (not %s)" % action)
	for action in k:
		if action != "sweep":
			check(not KEY_Z in k[action], "Z is only the sweep (not %s)" % action)


func test_standing_easy_strolling_and_running_look_it() -> void:
	var t := Tuning.fresh()
	var s := Poses.bake(Poses.angles("stand", 0, t), true)
	for side in ["f", "b"]:
		check(absf(s["leg_%s_lower" % side]) <= 22.0, "standing easy: the %s leg nearly straight (%.0f)" % [side, absf(s["leg_%s_lower" % side])])
	var hand: Vector2 = Poses._end("hand_f", s)[0]
	check(hand.y > (Poses._end("belly", s)[0] as Vector2).y, "the hands hang down, not up in a guard")
	check(absf(rad_to_deg(Poses._end("head", s)[1]) + 90.0) <= 10.0, "the chin level")
	# the everyday walk: the legs pass each other and the arms swing against them
	var order := {}
	var arms_against := true
	for tt in range(Poses.WALK_EASE_IN, Poses.WALK_EASE_IN + Poses.STROLL_CYCLE):
		var p := Poses.angles("stroll", tt, t)
		var b := Poses.bake(p, true)
		order[signf((Poses._end("leg_f_lower", b)[0] as Vector2).x - (Poses._end("leg_b_lower", b)[0] as Vector2).x)] = true
		if absf(p["step_b"]) > 20.0:
			arms_against = arms_against and signf(p["arm_f_upper"] + 8.0) == -signf(p["step_b"])
	check(order.has(1.0) and order.has(-1.0), "walking, the legs pass each other")
	check(arms_against, "and the arms swing against the legs")
	# the run: twice a cycle both feet off the street, the knee driven up, the arms bent and pumping, a lean
	var flights := 0
	var knee_high := false
	for tt in range(Poses.WALK_EASE_IN, Poses.WALK_EASE_IN + Poses.RUN_CYCLE):
		var p := Poses.angles("run", tt, t)
		var b := Poses.bake(p, true)
		if p["lift_f"] > 0.0 and p["lift_b"] > 0.0:
			flights += 1
		for side in ["f", "b"]:
			knee_high = knee_high or (Poses._end("leg_%s_upper" % side, b)[0] as Vector2).y < (Poses._end("hip", b)[0] as Vector2).y + 30.0
	check(flights >= 2, "running, both feet leave the street (%d frames a cycle)" % flights)
	check(knee_high, "the knee is driven up toward hip height")
	var r := Poses.angles("run", 30, t)
	check(r["arm_f_lower"] <= -80.0 and r["torso"] >= 12.0, "arms bent and pumping, leaning into it")


func test_planted_feet_hold_their_place_walking_and_running() -> void:
	var t := Tuning.fresh()
	for gait in [["stroll", t["stroll_speed"], Poses.STROLL_CYCLE], ["run", t["run_speed"], Poses.RUN_CYCLE]]:
		var last := {}
		for tt in range(Poses.WALK_EASE_IN + 1, Poses.WALK_EASE_IN + 2 * gait[2]):
			var p := Poses.angles(gait[0], tt, t)
			var b := Poses.bake(p, true)
			for side in ["f", "b"]:
				var world: float = gait[1] * tt + (Poses._end("toe_" + side, b)[0] as Vector2).x
				if p["lift_" + side] == 0.0 and last.has(side):
					check(absf(world - last[side]) < 1.0, "%s@%d: the planted %s foot stays put (slid %.1f px)" % [gait[0], tt, side, world - last[side]])
				if p["lift_" + side] == 0.0:
					last[side] = world
				else:
					last.erase(side)


func test_w_alone_runs_the_way_he_faces() -> void:
	# Javier played build e7e1320 (2026-11-02, through the assistant team): "S and W don't work". W only ran while an
	# arrow was held too. Now W alone runs the way he faces, and an arrow still steers it.
	var g = Fighter.new()
	var x0: float = g.x
	run_for(g, 10, {"run": true})
	eq(g.state, "run", "W alone: he runs")
	check(g.x > x0 + 40.0, "forward, the way he faces (%.0f px)" % (g.x - x0))
	var x1: float = g.x
	run_for(g, 10, {"run": true, "mx": -1.0})
	check(g.x < x1 - 40.0 and g.facing == -1, "an arrow still steers the run (%.0f px)" % (g.x - x1))
	var x2: float = g.x
	run_for(g, 10, {"run": true})
	check(g.x < x2 - 40.0, "and W alone keeps running the new way (%.0f px)" % (g.x - x2))
	run_for(g, 10, {})
	check(g.state != "run", "letting go of W stops the run")


func test_z_sweeps() -> void:
	# Javier, 2026-11-02 19:28 (through the assistant team): "Z key" for the sweep, its own move, outside the combos
	var f = Fighter.new()
	f.step({"punch": true})
	run_for(f, 12)
	eq(f.chain, "P", "a jab starts a chain")
	f.step({"sweep": true})
	run_for(f, 2)
	eq(f.state, "sweep", "Z: the sweep")
	eq(f.chain, "", "it is no link of a chain (a P after it opens a new one)")
	run_for(f, 90)
	eq(f.state, "idle", "and he rises back to his guard")


func test_c_rolls_the_way_the_arrows_point() -> void:
	# Javier (21:56): "c for evation role (direction of the keys)". An evasion roll along the street the way the arrows
	# point (forward if none), facing the threat the whole time; it evades for most of the roll, then he is open again.
	var f = Fighter.new()
	var x0: float = f.x
	f.step({"roll": true, "mx": -1.0})
	eq(f.state, "roll", "C: the roll")
	check(f.evading(), "while rolling he can't be hit")
	run_for(f, f.tune["roll_ticks"] - 4)
	check(f.x < x0 - 100.0, "it goes the way the arrow points: back (%.0f px)" % (f.x - x0))
	eq(f.facing, 1, "still facing the threat")
	check(not f.evading(), "coming up out of it, he's open again")
	run_for(f, 10)
	eq(f.state, "idle", "back in his guard")
	var g = Fighter.new()
	var gx: float = g.x
	g.step({"roll": true})
	run_for(g, g.tune["roll_ticks"])
	check(g.x > gx + 100.0, "no arrow: a forward roll (%.0f px)" % (g.x - gx))
	var h = Fighter.new()
	var z0: float = h.z
	h.step({"roll": true, "mz": 1.0})
	run_for(h, h.tune["roll_ticks"])
	check(h.z > z0 + 20.0, "down the street with the down arrow (%.0f px)" % (h.z - z0))
