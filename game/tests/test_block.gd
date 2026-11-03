extends "res://tests/test_case.gd"
## Blocking (D-19): hold to guard, its first ticks are a perfect block, no walking while guarding but turning is
## fine, a press comes straight out of the guard, no blocking in the air, and a held block waits for a blow to end.

const Fighter := preload("res://scripts/sim/fighter.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")


func test_hold_to_block_let_go_to_drop_it() -> void:
	var f = Fighter.new()
	f.step({"block": true})
	eq(f.state, "block", "holding block guards at once")
	for i in 20:
		f.step({"block": true, "mx": 1.0})
	eq(f.x, 200.0, "no walking while guarding")
	eq(f.facing, 1, "but it turns to face the stick")
	f.step({"block": true, "mx": -1.0})
	eq(f.facing, -1, "both ways")
	f.step({})
	eq(f.state, "idle", "letting go drops the guard")


func test_the_perfect_block_window() -> void:
	var f = Fighter.new()
	f.step({"block": true})
	var perfect := 0
	for i in 40:
		if f.blocking() == "perfect":
			perfect += 1
		f.step({"block": true})
	eq(perfect, int(f.tune["perfect_block_ticks"]), "perfect for exactly its window")
	eq(f.blocking(), "block", "then a plain block")
	f.step({})
	eq(f.blocking(), "", "not blocking once let go")


func test_the_window_is_a_feel_lab_knob() -> void:
	var t := Tuning.fresh()
	t["perfect_block_ticks"] = 2
	var f = Fighter.new(t)
	f.step({"block": true})
	f.step({"block": true})
	f.step({"block": true})
	eq(f.blocking(), "block", "a 2-tick window is over by the third tick")


func test_attack_straight_out_of_the_guard() -> void:
	var f = Fighter.new()
	for i in 10:
		f.step({"block": true})
	f.step({"block": true, "punch": true})
	eq(f.state, "punch", "a punch comes straight out of the guard")


func test_no_block_in_the_air_and_a_held_block_waits_for_the_blow() -> void:
	var f = Fighter.new()
	f.step({"jump": true})
	for i in f.tune["jump_squat_ticks"] + 1:
		f.step({"block": true})
	eq(f.state, "jump", "no guarding in the air (nor in the crouch before it)")
	var g = Fighter.new()
	g.step({"kick": true})
	g.step({"block": true})
	eq(g.state, "kick", "the kick finishes first")
	while g.state == "kick":
		g.step({"block": true})
	eq(g.state, "block", "then the guard goes up")


func test_blocking_ends_the_chain() -> void:
	var f = Fighter.new()
	f.step({"punch": true})
	while f.state == "punch":
		f.step({})
	f.step({"block": true})
	f.step({})
	f.step({"punch": true})
	eq(f.state, "punch", "after a block, a fresh jab, not the cross")
