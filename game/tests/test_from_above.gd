extends "res://tests/test_case.gd"
## Level 4's balcony Mechanics throwing down at the ring hall (the team's agreed page, screen 3): wrenches fall at the
## hero below, shadow first, one in the air at a time, never while he climbs the ladder, never anywhere else.

const Level := preload("res://scripts/sim/level.gd")


## Level 4's ground floor with its goons set aside, the hero standing at x.
func hall(x: float):
	var l = Level.new(Level.load_data("res://levels/level4.json"), {}, 1)
	l.floors[0]["wave"] = l.floors[0]["waves"].size()
	l.hero.x = x
	l.hero.z = 80.0
	return l


func test_wrenches_fall_on_him_under_the_balcony_one_at_a_time() -> void:
	var l = hall(4300.0)
	var hp: float = l.hero.health
	var most := 0
	var hits := 0
	var shadow_first := true
	for i in 600:
		var before: int = l.from_above.size()
		l.step({})
		most = maxi(most, l.from_above.size())
		for ev in l.events:
			if ev.get("kind", "") == "wrench_from_above" and ev.get("result", "") == "hit":
				hits += 1
				shadow_first = shadow_first and before == 1  # (the one that hit had been falling, shadow showing)
	check(hits >= 3, "standing still under them, wrenches keep landing on him (%d in 10 s)" % hits)
	check(l.hero.health < hp, "and they hurt (%.0f of %.0f)" % [l.hero.health, hp])
	eq(most, 1, "one wrench in the air at a time")
	check(shadow_first, "every one showed its shadow before it landed")


func test_step_out_of_the_shadow_and_it_misses() -> void:
	var l = hall(4300.0)
	for i in 400:
		if not l.from_above.is_empty() and absf(l.from_above[0]["x"] - l.hero.x) < 70.0:
			var d: Dictionary = l.from_above[0]  # its shadow showing: walk out of it, along the street (staying under them)
			l.step({"mx": 1.0 if d["x"] <= l.hero.x and l.hero.x < 5600.0 or l.hero.x < 4000.0 else -1.0})
		else:
			l.step({})
	var hp: float = l.hero.health
	eq(hp, l.hero.max_health, "stepping out of each shadow: nothing lands")


func test_never_off_their_stretch_never_on_the_ladder_never_upstairs() -> void:
	var l = hall(3000.0)  # screen 2, the weights room
	for i in 300:
		l.step({})
	check(l.from_above.is_empty() and l.hero.health == l.hero.max_health, "off screen 3: nothing thrown")
	l = hall(4300.0)
	for i in 70:
		l.step({})
	check(not l.from_above.is_empty(), "(under the balcony one is falling)")
	l.hero._enter("climb")
	l.step({})
	check(l.from_above.is_empty(), "he grabs the ladder: they stop that moment")
	l._go_to(1, 300.0)
	for i in 300:
		l.step({})
	check(l.from_above.is_empty(), "up on the balcony: no throwing down")
