extends "res://tests/test_case.gd"
## Combos (D-18): three quick presses chain into a finisher; a slow press starts over; mashing still chains;
## finishers carry their effect; jump + punch is the hammer fist; one air attack per jump.

const Fighter := preload("res://scripts/sim/fighter.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")
const Moves := preload("res://scripts/sim/moves.gd")

const BUTTON := {"P": "punch", "K": "kick"}


## Plays a sequence of presses, each one pressed `wait` ticks after the previous blow turns active (so it lands
## during that blow), and returns the moves that came out, in order.
func play(seq: String, wait := 2, f = null) -> Array:
	if f == null:
		f = Fighter.new()
	var out := []
	for i in seq.length():
		f.step({BUTTON[seq[i]]: true})
		var n := 0
		while f.t != 0 and n < 80:  # until the new move starts
			f.step({})
			n += 1
		out.append(f.state)
		n = 0
		while f.attack_phase() != "active" and n < 80:
			f.step({})
			n += 1
		for k in wait:
			f.step({})
	return out


func test_every_combo_names_a_real_move() -> void:
	for seq in Moves.COMBOS:
		check(Moves.is_move(Moves.COMBOS[seq]), "%s plays a real move" % seq)
		if seq.length() > 1:
			check(Moves.COMBOS.has(seq.substr(0, seq.length() - 1)), "%s grows from a real chain" % seq)
	var t := Tuning.fresh()
	for m in Moves.TABLE:
		var d := Moves.data(m, t)
		for k in ["startup", "active", "recovery", "reach", "low", "high", "damage", "effect", "limb"]:
			check(d.has(k), "%s has %s" % [m, k])


func test_the_chains() -> void:
	eq(play("PPP"), ["punch", "cross", "hook"], "jab, cross, hook")
	eq(play("KKK"), ["kick", "body_kick", "spin_kick"], "front kick, body kick, spinning kick")
	eq(play("PKP"), ["punch", "knee", "uppercut"], "jab, knee, uppercut")
	eq(play("KPK"), ["kick", "elbow", "roundhouse"], "front kick, elbow, roundhouse")
	eq(play("PPK"), ["punch", "cross", "push_kick"], "jab, cross, push kick")


func test_finishers_carry_their_effect() -> void:
	var t := Tuning.fresh()
	eq(Moves.data("hook", t)["effect"], "stagger", "the hook staggers")
	eq(Moves.data("spin_kick", t)["effect"], "knockdown", "the spinning kick knocks down")
	eq(Moves.data("uppercut", t)["effect"], "launch", "the uppercut launches")
	eq(Moves.data("push_kick", t)["effect"], "push", "the push kick makes space")
	check(Moves.data("hook", t)["damage"] > Moves.data("punch", t)["damage"], "a finisher hits harder than a jab")


func test_a_finisher_ends_the_chain() -> void:
	eq(play("PPPP"), ["punch", "cross", "hook", "punch"], "after the hook, a new chain")
	eq(play("PKK"), ["punch", "knee", "kick"], "a press that fits no chain starts a new one")


func test_a_slow_press_starts_over() -> void:
	var f = Fighter.new()
	play("P", 0, f)
	while f.state != "idle":
		f.step({})
	for i in f.tune["combo_window_ticks"] + 1:
		f.step({})
	f.step({"punch": true})
	eq(f.state, "punch", "too late: a jab again, not the cross")
	var g = Fighter.new()
	play("P", 0, g)
	while g.state != "idle":
		g.step({})
	for i in g.tune["combo_window_ticks"] - 2:
		g.step({})
	g.step({"punch": true})
	eq(g.state, "cross", "in time: the cross")


func test_the_window_is_a_feel_lab_knob() -> void:
	var t := Tuning.fresh()
	t["combo_window_ticks"] = 4
	var f = Fighter.new(t)
	play("P", 0, f)
	while f.state != "idle":
		f.step({})
	for i in 10:
		f.step({})
	f.step({"punch": true})
	eq(f.state, "punch", "a 4-tick window is missed by a 10-tick wait")


func test_mashing_still_chains() -> void:
	var f = Fighter.new()
	var seen := []
	for i in 120:
		f.step({"punch": i % 3 == 0})
		if f.t == 0 and Moves.is_move(f.state):
			seen.append(f.state)
	check(seen.slice(0, 3) == ["punch", "cross", "hook"], "mashing P plays jab, cross, hook (%s)" % str(seen.slice(0, 3)))
	var doubles := 0
	for i in range(1, seen.size()):
		doubles += int(seen[i] == seen[i - 1] and seen[i] != "punch")
	eq(doubles, 0, "no move fires twice in a row from one press")


func test_a_double_tap_fires_once() -> void:
	var f = Fighter.new()
	f.step({"punch": true})
	f.step({"punch": true})  # a double tap, during the jab's start-up
	while f.state == "punch":
		f.step({})
	for i in 3:
		f.step({})
	eq(f.state, "idle", "the double tap did not fire a cross")


func test_hammer_fist_and_one_air_attack_per_jump() -> void:
	var f = Fighter.new()
	f.step({"jump": true})
	for i in 6:
		f.step({})
	f.step({"punch": true})
	eq(f.state, "hammer_fist", "jump + punch = hammer fist")
	for i in 3:
		f.step({})
	f.step({"kick": true})
	eq(f.state, "hammer_fist", "no flying kick after a hammer fist in the same jump")
	while f.state == "hammer_fist":
		f.step({})
	eq(f.state, "land", "it lasts until landing")


func test_jumping_breaks_the_chain() -> void:
	var f = Fighter.new()
	play("P", 0, f)
	while f.state != "idle":
		f.step({})
	f.step({"jump": true})
	while f.state != "idle":
		f.step({})
	f.step({"punch": true})
	eq(f.state, "punch", "after a jump the chain starts over")


func test_presses_during_one_blow_keep_their_order() -> void:
	# found by the demo: a P then a K pressed during one long kick came out as K, K (the second press overwrote the
	# first); they wait in order now
	var f = Fighter.new()
	f.step({"kick": true})
	for i in 8:
		f.step({})
	f.step({"punch": true})
	for i in 5:
		f.step({})
	f.step({"kick": true})
	var seen := ["kick"]
	for i in 120:
		f.step({})
		if f.t == 0 and Moves.is_move(f.state):
			seen.append(f.state)
	eq(seen, ["kick", "elbow", "roundhouse"], "K, then P and K pressed during the kick = kick, elbow, roundhouse")
