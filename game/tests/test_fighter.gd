extends "res://tests/test_case.gd"
## The hero's body and moves in plain logic: walking, the shallow street, jumping, punch and kick timing, reach,
## the input buffer, and that the same inputs always play out the same way.

const Moves := preload("res://scripts/sim/moves.gd")
const Fighter := preload("res://scripts/sim/fighter.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")

const NONE := {}


func run(f, inp: Dictionary, ticks: int) -> void:
	for i in ticks:
		f.step(inp)


## Steps with no input until the fighter is back to idle; returns how many ticks that took.
func settle(f, limit := 200) -> int:
	var n := 0
	while f.state != "idle" and n < limit:
		f.step(NONE)
		n += 1
	return n


func test_standing_still_stays_put() -> void:
	var f = Fighter.new()
	run(f, NONE, 30)
	eq(f.state, "idle", "no input = idle")
	eq([f.x, f.z, f.y], [200.0, 80.0, 0.0], "did not drift")


func test_walking_moves_at_walk_speed_and_turns() -> void:
	var f = Fighter.new()
	run(f, {"mx": 1.0}, 10)
	eq(f.state, "walk", "walking")
	check(is_equal_approx(f.x, 200.0 + 10 * f.tune["walk_speed"]), "10 ticks right = 10 x walk speed (x=%s)" % f.x)
	eq(f.facing, 1, "faces right")
	run(f, {"mx": -1.0}, 1)
	eq(f.facing, -1, "turns at once when walking left")
	run(f, NONE, 1)
	eq(f.state, "idle", "letting go stops at once")


func test_shallow_street_depth_is_walkable_and_has_edges() -> void:
	var f = Fighter.new()
	run(f, {"mz": 1.0}, 5)
	check(is_equal_approx(f.z, 80.0 + 5 * f.tune["depth_speed"]), "down the street at depth speed (z=%s)" % f.z)
	eq(f.state, "walk", "moving in depth is walking")
	run(f, {"mz": 1.0}, 500)
	eq(f.z, f.tune["street_depth"], "stops at the near edge")
	run(f, {"mz": -1.0}, 500)
	eq(f.z, 0.0, "stops at the far edge")
	run(f, {"mx": -1.0}, 2000)
	eq(f.x, f.tune["street_left"], "stops at the street's left end")


func test_flat_line_has_no_depth() -> void:
	var t := Tuning.fresh()
	t["flat_line"] = true
	var f = Fighter.new(t)
	run(f, {"mz": 1.0}, 20)
	eq(f.z, 80.0, "depth input does nothing on the flat line")
	eq(f.state, "idle", "and is not walking")


func test_jump_reaches_its_height_and_lands_on_time() -> void:
	var f = Fighter.new()
	f.step({"jump": true})
	eq(f.state, "jump_squat", "the press starts a crouch")
	run(f, NONE, f.tune["jump_squat_ticks"])
	eq(f.state, "jump", "and after it he leaves the ground")
	var apex := 0.0
	var air := 1
	while f.state == "jump" and air < 200:
		f.step(NONE)
		apex = maxf(apex, f.y)
		air += 1
	var h: float = f.tune["jump_height"]
	check(absf(apex - h) <= h * 0.1, "apex %.1f within 10%% of %.0f" % [apex, h])
	check(absi(air - int(f.tune["jump_air_ticks"])) <= 2, "air time %d ticks, wanted about %d" % [air, f.tune["jump_air_ticks"]])
	eq(f.state, "land", "lands")
	eq(f.y, 0.0, "back on the ground")
	eq(settle(f), int(f.tune["land_ticks"]), "a short landing, then free")


func test_no_jump_in_the_air() -> void:
	var f = Fighter.new()
	f.step({"jump": true})
	run(f, NONE, 10)
	var vy_before: float = f.vy
	f.step({"jump": true})
	check(f.vy < vy_before, "a second press does not push up again")


func test_a_running_jump_carries_forward() -> void:
	var f = Fighter.new()
	run(f, {"mx": 1.0}, 5)
	var x0: float = f.x  # (jump_speed carries it)
	f.step({"mx": 1.0, "jump": true})
	while f.state in ["jump_squat", "jump"]:
		f.step(NONE)
	check(f.x - x0 > 100.0, "the jump carried the hero forward (%.0f px)" % (f.x - x0))


func attack_timeline(button: String) -> Array:
	var f = Fighter.new()
	f.step({button: true})
	var phases := [f.attack_phase()]
	while f.state == button:
		f.step(NONE)
		if f.state == button:
			phases.append(f.attack_phase())
	return phases


func test_punch_and_kick_timing() -> void:
	var t := Tuning.fresh()
	for a in ["punch", "kick"]:
		var phases := attack_timeline(a)
		eq(phases.size(), t[a + "_startup"] + t[a + "_active"] + t[a + "_recovery"], "%s lasts its full length" % a)
		eq(phases.count("startup"), t[a + "_startup"], "%s start-up ticks" % a)
		eq(phases.count("active"), t[a + "_active"], "%s active ticks" % a)
		eq(phases.find("active"), t[a + "_startup"], "%s hits right after start-up" % a)
	check(attack_timeline("kick").size() > attack_timeline("punch").size(), "a kick is slower than a punch")


func test_blows_land_in_front_with_their_reach() -> void:
	for dir in [1, -1]:
		var f = Fighter.new()
		f.facing = dir
		f.step({"kick": true})
		while f.attack_phase() != "active":
			check(f.hit_box().is_empty(), "nothing hits during start-up")
			f.step(NONE)
		var box: Dictionary = f.hit_box()
		check(not box.is_empty(), "the kick can hit while active")
		var far: float = box["x1"] if dir == 1 else box["x0"]
		check(is_equal_approx(absf(far - f.x), f.tune["kick_reach"]), "kick reaches %s px (facing %d)" % [f.tune["kick_reach"], dir])
		check((box["x0"] - f.x) * dir >= 0.0 or (box["x1"] - f.x) * dir >= 0.0, "in front, facing %d" % dir)
	var p = Fighter.new()
	p.step({"punch": true})
	while p.attack_phase() != "active":
		p.step(NONE)
	# (the opening kick is the low kick since 2026-11-02, shorter than the jab; the front kick still outreaches it)
	check(p.hit_box()["x1"] - p.x < Moves.data("front_kick", p.tune)["reach"], "a punch reaches less than a front kick")


func test_attacking_plants_the_feet() -> void:
	var f = Fighter.new()
	f.step({"punch": true})
	var x0: float = f.x
	run(f, {"mx": 1.0, "mz": 1.0}, 8)
	eq(f.state, "punch", "still punching")
	eq(f.x, x0, "no sliding during a punch")


func test_early_press_is_buffered_into_the_next_move() -> void:
	var f = Fighter.new()
	f.step({"punch": true})
	var length: int = f.attack_length("punch")
	run(f, NONE, length - 4)
	f.step({"punch": true})  # pressed 3 ticks before the first punch ends
	var waited := 0
	while f.t != 0 and waited < 10:
		f.step(NONE)
		waited += 1
	eq(f.state, "cross", "the second press came out, as the combo's second hit (moves.gd)")
	check(waited <= 3, "with no gap (%d ticks)" % waited)


func test_a_press_too_early_is_dropped() -> void:
	var f = Fighter.new()
	f.step({"kick": true})
	f.step({"punch": true})  # far too early: the kick has 20+ ticks left
	settle(f)
	run(f, NONE, 2)
	eq(f.state, "idle", "the stale press did not fire later")


func test_same_inputs_same_fight() -> void:
	var a = Fighter.new()
	var b = Fighter.new()
	var script := [{"mx": 1.0}, {"jump": true, "mx": 1.0}, {}, {"punch": true}, {"mz": -1.0}, {"kick": true}]
	for i in 240:
		var inp: Dictionary = script[(i / 7) % script.size()]
		a.step(inp)
		b.step(inp)
	eq(a.snapshot(), b.snapshot(), "two runs of the same inputs end identical")


func test_hit_in_the_air_he_comes_down() -> void:
	var w = preload("res://scripts/sim/street_world.gd").new()
	for effect in ["knockdown", "", "push"]:
		var f = preload("res://scripts/sim/fighter.gd").new(preload("res://scripts/sim/tuning.gd").fresh(), 400.0, 80.0, w)
		f.step({"jump": true})
		for i in 14:
			f.step({})
		check(f.y > 60.0, "up in the air (%.0f)" % f.y)
		f.take_hit({"damage": 1.0, "effect": effect, "low": 0.0, "high": 300.0, "move": "container"}, {"x": 300.0, "y": 0.0})
		for i in 60:
			f.step({})
		eq(f.y, 0.0, "hit up there (%s): he comes down, he doesn't hang in the air" % (effect if effect != "" else "a plain hit"))
