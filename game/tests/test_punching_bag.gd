extends "res://tests/test_case.gd"
## Level 4's weights room (the team's agreed page, screen 2): the punching bag, hit, swings away from the blow, into whoever stands
## behind it, a knockdown; it never breaks.

const Level := preload("res://scripts/sim/level.gd")


## Level 4's weights room, its goons set aside, the hero facing the bag from its left, a Mechanic where asked.
func room(foe_x: float):
	var l = Level.new(Level.load_data("res://levels/level4.json"), {}, 1)
	l.floors[0]["wave"] = l.floors[0]["waves"].size()
	var bag: Dictionary = l.world.objects.filter(func(o): return o["kind"] == "bag")[0]
	l.hero.x = bag["x0"] - 60.0
	l.hero.z = 40.0
	l.hero.facing = 1
	l._spawn("wrench_mechanic", foe_x, 40.0)
	var e: Dictionary = l.enemies[-1]
	e["brain"].wait = 9999
	e["brain"].dormant_until_within = 1.0
	return [l, bag, e["f"]]


## Punches until the bag swings (or 40 frames go by); returns whether it swung.
func punch_bag(l) -> bool:
	for i in 40:
		l.step({"punch": i % 12 == 0})
		if l.events.any(func(ev): return ev.get("result", "") == "bag_swing"):
			return true
	return false


func test_the_bag_hangs_on_screen_two() -> void:
	var l = Level.new(Level.load_data("res://levels/level4.json"), {}, 1)
	var bags: Array = l.world.objects.filter(func(o): return o["kind"] == "bag")
	eq(bags.size(), 1, "one punching bag in the weights room")
	check(bags[0]["x0"] >= 1920.0 and bags[0]["x1"] <= 3840.0, "on screen 2 (%.0f)" % bags[0]["x0"])


func test_hit_it_and_it_swings_into_whoever_is_behind() -> void:
	var r: Array = room(0.0)
	var l = r[0]
	var bag: Dictionary = r[1]
	var foe = r[2]
	foe.x = bag["x1"] + 50.0
	foe.facing = -1
	check(punch_bag(l), "a punch swings the bag")
	eq(float(bag["swing_dir"]), 1.0, "away from him")
	check(not foe.state in ["knockdown", "launch", "down"], "not yet: it has to swing out to him first")
	for i in Level.BAG_HIT_AT + 1:
		l.step({})
	check(foe.state in ["knockdown", "launch", "down"], "into the Mechanic behind it: knocked down (%s)" % foe.state)
	check(not bag["broken"], "the bag never breaks")


func test_nobody_behind_nobody_hit_and_the_hitter_is_safe() -> void:
	var r: Array = room(0.0)
	var l = r[0]
	var bag: Dictionary = r[1]
	var foe = r[2]
	foe.x = bag["x1"] + 400.0  # well past its reach
	var hp: float = l.hero.health
	check(punch_bag(l), "it swings")
	for i in Level.BAG_HIT_AT + 1:
		l.step({})
	check(not foe.state in ["knockdown", "launch", "down"], "too far behind it: untouched (%s)" % foe.state)
	eq(l.hero.health, hp, "it swings away from the one who hit it")
	for i in 60:  # many more blows: still hanging
		l.step({"punch": i % 12 == 0})
	check(not bag["broken"], "still hanging after a string of blows")


func test_the_gym_sign_hangs_in_the_weights_room() -> void:
	var d: Dictionary = Level.load_data("res://levels/level4.json")
	var signs: Array = d["floors"][0].get("signs", [])
	eq(signs.size(), 1, "one sign on the ground floor (Pippin's, art-in 2026-11-05-level4-gym-sign)")
	check(float(signs[0][0]) >= 1920.0 and float(signs[0][0]) <= 3840.0, "on screen 2, the weights room")
	eq(signs[0][2], "GYM: NO PAIN NO GAIN", "its words")
	check(not (signs[0][3] as String).contains("GAIN"), "and it flickers to drop the GAIN")
