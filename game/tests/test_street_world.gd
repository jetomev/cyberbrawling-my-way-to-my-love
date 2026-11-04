extends "res://tests/test_case.gd"
## Obstacles: never walked through, jumped over, landed on, climbed onto and stepped off; crates smashed by kicks,
## each blow counting once; and the flying kick.

const Fighter := preload("res://scripts/sim/fighter.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")
const StreetWorld := preload("res://scripts/sim/street_world.gd")

const NONE := {}


func one_crate():
	var w = StreetWorld.new()
	w.add("crate", 600.0, 680.0, 40.0, 120.0, 96.0, true, 4)
	return w


func hero(w, start_x := 400.0, start_z := 80.0):
	return Fighter.new(Tuning.fresh(), start_x, start_z, w)


func run(f, inp: Dictionary, ticks: int) -> void:
	for i in ticks:
		f.step(inp)


func inside(w, f) -> bool:
	for o in w.objects:
		if not o["broken"] and f.y < o["top"] - 0.5 and f.x > o["x0"] and f.x < o["x1"] and f.z > o["z0"] and f.z < o["z1"]:
			return true
	return false


func test_never_walk_through() -> void:
	var w = one_crate()
	var f = hero(w)
	f.tune["climb_hold_ticks"] = 9999  # just walking into it
	var through := false
	for i in 200:
		f.step({"mx": 1.0})
		through = through or inside(w, f)
	check(not through, "never inside the crate")
	check(f.x < 600.0 and f.x > 560.0, "stopped at its face (x=%.0f)" % f.x)
	run(f, {"mz": 1.0}, 40)
	run(f, {"mx": 1.0}, 200)
	check(f.x > 700.0, "walked around it by going down the street (x=%.0f)" % f.x)


func test_jump_over_it() -> void:
	var w = one_crate()
	var f = hero(w, 520.0)  # takes off about a body's length before the crate
	f.step({"mx": 1.0, "jump": true})
	var through := false
	for i in 80:
		f.step({"mx": 1.0})
		through = through or inside(w, f)
	check(not through, "never inside it in the air")
	check(f.x > 700.0, "a running jump clears it (x=%.0f)" % f.x)
	eq(f.y, 0.0, "back on the street")


func test_land_on_top_then_step_off() -> void:
	var w = one_crate()
	var f = hero(w, 560.0)
	f.step({"mx": 1.0, "jump": true})
	var landed_on_top := false
	for i in 60:
		f.step({"mx": 0.6} if f.x < 640.0 else NONE)
		if f.state == "land" and is_equal_approx(f.y, 96.0):
			landed_on_top = true
	check(landed_on_top, "landed on the crate's top")
	run(f, NONE, 10)
	eq([f.state, f.y], ["idle", 96.0], "standing on it")
	run(f, {"mx": 1.0}, 40)
	check(f.x > 700.0, "walked off the far edge")
	run(f, NONE, 40)
	eq(f.y, 0.0, "fell back down to the street")


func test_climb_on_and_off() -> void:
	var w = one_crate()
	var f = hero(w)
	var climbed := false
	for i in 200:
		f.step({"mx": 1.0})
		climbed = climbed or f.state == "climb"
		if f.state == "idle" or (f.state == "walk" and f.y > 0.0):
			break
	check(climbed, "pushing into the crate climbs it")
	eq(f.y, 96.0, "on top after the climb")
	check(f.x > 600.0 and f.x < 680.0, "standing over it (x=%.0f)" % f.x)
	var f2 = hero(w)
	f2.tune["climb_max"] = 80.0
	run(f2, {"mx": 1.0}, 200)
	eq(f2.y, 0.0, "a crate taller than the climb limit can't be climbed")
	check(f2.state != "climb", "and no climb starts")


func test_a_wall_is_not_climbable() -> void:
	var w = StreetWorld.new()
	w.add("barrier", 600.0, 640.0, 0.0, 160.0, 120.0, false)
	var f = hero(w)
	run(f, {"mx": 1.0}, 200)
	check(f.x < 600.0 and f.y == 0.0, "stays at the barrier")


func test_kicks_smash_a_crate_once_per_blow() -> void:
	var w = one_crate()
	var f = hero(w, 520.0)
	f.facing = 1
	var broke := []
	f.step({"kick": true})
	for i in 30:
		f.step(NONE)
		broke.append_array(w.step_hits([f]))
	eq(w.objects[0]["strength"], 2, "one kick = 2 of its 4 strength, however many ticks it's out")
	f.step({"kick": true})
	for i in 30:
		f.step(NONE)
		broke.append_array(w.step_hits([f]))
	eq(broke, [0], "the second kick breaks it")
	check(not w.blocks(650.0, 80.0, 0.0), "a broken crate no longer blocks")


func test_a_punch_flies_over_a_low_crate() -> void:
	var w = one_crate()
	var f = hero(w, 540.0)
	for p in 3:
		f.step({"punch": true})
		for i in 20:
			f.step(NONE)
			w.step_hits([f])
	eq(w.objects[0]["strength"], 4, "punches pass over a 96 px crate")


func test_a_car_does_not_break() -> void:
	var w = StreetWorld.new()
	w.add("car", 600.0, 860.0, 30.0, 130.0, 130.0, true)
	var f = hero(w, 520.0)
	for k in 5:
		f.step({"kick": true})
		for i in 30:
			f.step(NONE)
			w.step_hits([f])
	check(not w.objects[0]["broken"], "kicking a car doesn't break it")


func test_flying_kick() -> void:
	var f = hero(null)
	f.step({"jump": true})
	run(f, NONE, 8)
	f.step({"kick": true})
	eq(f.state, "air_kick", "kick in the air = flying kick")
	run(f, NONE, f.tune["air_kick_startup"])
	eq(f.attack_phase(), "active", "out after its start-up")
	var box: Dictionary = f.hit_box()
	check(is_equal_approx(box["x1"] - f.x, f.tune["air_kick_reach"]), "reaches %s px" % f.tune["air_kick_reach"])
	var serial: int = f.attack_serial
	f.step({"kick": true})
	eq(f.attack_serial, serial, "one flying kick per jump")
	while f.state == "air_kick":
		f.step(NONE)
	eq(f.state, "land", "it lasts until landing")
	run(f, NONE, 10)
	f.step({"jump": true})
	run(f, NONE, 5)
	f.step({"kick": true})
	eq(f.state, "air_kick", "the next jump can flying-kick again")


func test_flying_kick_smashes_harder() -> void:
	var w = one_crate()
	var f = hero(w, 520.0)
	f.step({"jump": true})
	run(f, NONE, 29)  # on the way down: at the top of the jump the foot sails over a low crate
	f.step({"kick": true})
	while f.state == "air_kick":
		f.step(NONE)
		w.step_hits([f])
	eq(w.objects[0]["strength"], 1, "a flying kick does 3")


func test_standing_on_top_draws_in_front() -> void:
	var w = one_crate()
	var f = hero(w, 650.0, 50.0)
	f.y = 96.0
	check(w.draw_order(f) > 120, "on top of the crate draws over it (%d)" % w.draw_order(f))
	f.y = 0.0
	f.x = 400.0
	eq(w.draw_order(f), 50, "on the street, draw order is depth")


func test_the_grey_street_has_one_of_each() -> void:
	var w = StreetWorld.grey_street()
	var kinds := {}
	for o in w.objects:
		kinds[o["kind"]] = true
	check(kinds.has("crate") and kinds.has("car") and kinds.has("barrier"), "crate, car and barrier")
	var gaps := true
	for o in w.objects:
		gaps = gaps and (o["z0"] > 0.0 or o["z1"] < Tuning.DEFAULTS["street_depth"])
	check(gaps, "nothing blocks the whole width of the street")


## Ladders (the team's level 2): a ladder leans on something tall at the back; up at its foot climbs it, down at the
## top climbs off; it doesn't block anyone, and enemies don't climb.
const Fighter2 := preload("res://scripts/sim/fighter.gd")


func awning_and_ladder():
	var w = preload("res://scripts/sim/street_world.gd").new()
	w.add("awning", 400.0, 700.0, 0.0, 60.0, 380.0, false, 0)
	w.add("ladder", 500.0, 540.0, 60.0, 80.0, 380.0, false, 0)
	return w


func test_up_the_ladder_onto_the_awning_and_down_again() -> void:
	var w = awning_and_ladder()
	var f = Fighter2.new(preload("res://scripts/sim/tuning.gd").fresh(), 520.0, 100.0, w)
	f.step({"mz": -1.0})
	eq(f.state, "climb", "up at its foot: he climbs")
	for i in 80:
		f.step({})
	check(absf(f.y - 380.0) < 0.5, "on the awning roof (y %.0f)" % f.y)
	for i in 30:
		f.step({})
	check(absf(f.y - 380.0) < 0.5, "and he stays up there, standing on it")
	f.step({"mz": 1.0})
	eq(f.state, "climb", "down at the top: he climbs down")
	for i in 80:
		f.step({})
	eq(f.y, 0.0, "back on the street")


func test_a_ladder_doesnt_block_and_enemies_dont_climb() -> void:
	var w = awning_and_ladder()
	var f = Fighter2.new(preload("res://scripts/sim/tuning.gd").fresh(), 450.0, 100.0, w)
	for i in 30:
		f.step({"mx": 1.0})
	check(f.x > 560.0, "he walks past the ladder's foot (%.0f)" % f.x)
	var e = Fighter2.new(preload("res://scripts/sim/tuning.gd").fresh(), 520.0, 100.0, w)
	e.can_climb = false
	e.step({"mz": -1.0})
	check(e.state != "climb", "an enemy doesn't climb")
