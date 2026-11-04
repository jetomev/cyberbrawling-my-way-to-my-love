extends "res://tests/test_case.gd"
## Thrown things (sim/projectiles.gd): a record flies along the street at its height and hits who it meets; stepping
## up or down the street, jumping a low one or a roll dodges it; a perfect block sends it back at the thrower.

const Fighter := preload("res://scripts/sim/fighter.gd")
const Projectiles := preload("res://scripts/sim/projectiles.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")


func hero_at(x := 400.0, z := 80.0):
	var f = Fighter.new(Tuning.fresh(), x, z)
	f.facing = 1
	return f


## Throws a record from x 900 toward the hero at the given height band; steps until it's gone. Returns the events.
func fly(hero, y0: float, y1: float, steps := 120, inputs := {}) -> Array:
	var p := Projectiles.new()
	p.throw("record", 900.0, 80.0, y0, y1, -9.0, 2.0, 1)
	var events := []
	for i in steps:
		hero.step(inputs.get(i, inputs.get("all", {})))
		events.append_array(p.step([hero], 0.0, 2000.0))
	return events


func test_a_record_hits_who_it_meets() -> void:
	var h = hero_at()
	var events := fly(h, 140.0, 200.0)
	eq(events.size(), 1, "it hits once")
	eq(events[0]["result"], "hit", "a clean hit")
	check(h.health < h.max_health, "and it hurts")


func test_stepping_up_the_street_dodges_it() -> void:
	var h = hero_at(400.0, 30.0)  # up the street from its line
	eq(fly(h, 140.0, 200.0).size(), 0, "it flies past a man further up the street")


func test_a_low_one_is_jumped() -> void:
	var h = hero_at()
	var inputs := {30: {"jump": true}}
	eq(fly(h, 0.0, 50.0, 120, inputs).size(), 0, "jumping, he's over a low record")


func test_a_roll_dodges_it() -> void:
	var h = hero_at()
	# rolling toward it, timed so it arrives while he is round over the shoulder (frames 6-24 of the roll)
	var events := fly(h, 140.0, 200.0, 120, {33: {"roll": true}})
	check(events.is_empty() or events[0]["result"] != "hit", "rolling round, it passes over him (%s)" % [events.map(func(e): return e["result"])])


func test_a_perfect_block_sends_it_back() -> void:
	var h = hero_at()
	var thrower = Fighter.new(Tuning.fresh(), 1000.0, 80.0)
	thrower.team = 1
	thrower.facing = -1
	var p := Projectiles.new()
	p.throw("record", 900.0, 80.0, 140.0, 200.0, -9.0, 2.0, 1)
	var results := []
	for i in 200:
		h.step({"block": i >= 50 and i < 70})  # up a moment before it arrives: perfect
		thrower.step({})
		for e in p.step([h, thrower], 0.0, 2000.0):
			results.append([e["target"] == h, e["result"]])
	check(results.size() >= 1 and results[0] == [true, "perfect"], "a perfect block on it (%s)" % [results])
	check(results.size() >= 2 and results[1] == [false, "hit"], "and it flies back and hits the thrower (%s)" % [results])
	check(thrower.health < thrower.max_health, "who's hurt by his own record")
