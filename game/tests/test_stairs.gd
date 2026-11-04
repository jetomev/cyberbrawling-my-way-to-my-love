extends "res://tests/test_case.gd"
## The stairs (the team's level 3 page, "the game's stairs question, answered"): one flight inside a screen, walked up
## and down with the arrows like the street, one fighter deep, a wall from the side; a push kick or any knockdown on
## the slope tumbles someone to the foot, bowling over anyone below; never more than two enemies on it at once; the
## enemies and the bot find their way round to its foot; the landing at the top leads on to the floor above.

const Level := preload("res://scripts/sim/level.gd")
const StreetWorld := preload("res://scripts/sim/street_world.gd")
const HeroBot := preload("res://scripts/sim/hero_bot.gd")

const FOOT := 1000.0
const TOP := 400.0


func shop():
	return Level.new(Level.load_data("res://tests/levels/stairs.json"), {}, 1)


func flight(l) -> Dictionary:
	return l.world.objects.filter(func(o): return o["kind"] == "stairs")[0]


## The hero set down on the flight at x (on its step).
func on_flight(l, x: float) -> void:
	l.hero.x = x
	l.hero.z = 15.0
	l.hero.y = StreetWorld.step_height(flight(l), x)


func bring(l, kind: String, x: float, z := 15.0) -> Dictionary:
	l._spawn(kind, x, z)
	var e: Dictionary = l.enemies[-1]
	e["brain"].wait = 9999
	e["brain"].dormant_until_within = 1.0  # standing still unless a test wants him to move
	return e


func test_up_the_flight_with_the_arrows() -> void:
	var l = shop()
	var st := flight(l)
	l.hero.x = FOOT - 40.0
	l.hero.z = 15.0
	var heights := []
	for i in 400:
		l.step({"mx": 1.0, "mz": 1.0 if i % 2 == 0 else -1.0})  # up the flight, pressing up and down the street too
		if l.on == 0 and l.hero.x > FOOT and l.hero.x < 1800.0:
			heights.append([l.hero.x, l.hero.y, l.hero.z])
		if l.on == 1:
			break
	check(heights.size() > 30, "he walked up the flight (%d steps on it)" % heights.size())
	var off := heights.filter(func(h): return absf(h[1] - StreetWorld.step_height(st, h[0])) > 1.0)
	eq(off.size(), 0, "feet on the step under him all the way up")
	check(heights.all(func(h): return h[2] >= -2.0 and h[2] <= 32.0), "one fighter deep: the up and down arrows don't take him off it")
	eq(l.on, 1, "the landing's end leads on to the flat above")


func test_the_side_of_the_flight_is_a_wall() -> void:
	var l = shop()
	l.hero.x = 1500.0
	l.hero.z = 80.0
	for i in 80:
		l.step({"mz": -1.0})
	check(l.hero.z > 30.0, "walking at the flight's side from the street: blocked (z %.0f)" % l.hero.z)
	eq(l.hero.y, 0.0, "and he's still on the street")


func test_down_the_flight_from_the_landing() -> void:
	var l = shop()
	l._go_to(1, 120.0)
	l.arrived_x = -1.0e9
	l.hero.z = 0.0
	l.step({})
	eq(l.on, 0, "the doorway upstairs leads back onto the landing")
	check(absf(l.hero.y - TOP) < 1.0, "up at the top (%.0f)" % l.hero.y)
	for i in 300:
		l.step({"mx": -1.0})
	check(l.hero.x < FOOT, "walked down and off the foot (%.0f)" % l.hero.x)
	eq(l.hero.y, 0.0, "back on the street")


func test_a_push_kick_on_the_slope_tumbles_him_to_the_foot() -> void:
	var l = shop()
	on_flight(l, 1600.0)
	var e = bring(l, "thug", 1450.0)
	var f = e["f"]
	check(f.y > 100.0, "an enemy set on the flight stands on its step (%.0f)" % f.y)
	var hp: float = f.health
	f.take_hit({"damage": 2.0, "effect": "push", "low": 60.0, "high": 160.0, "move": "push_kick"}, l.hero)
	var after_kick: float = f.health
	l.events = [{"attacker": l.hero, "target": f, "result": "hit", "move": "push_kick"}]
	l._stairs()
	eq(f.state, "tumble", "the push kick sends him tumbling")
	for i in 120:
		l.step({})
		if f.state != "tumble":
			break
	check(f.x < FOOT, "to the foot of the stairs (%.0f)" % f.x)
	eq(f.y, 0.0, "on the street")
	eq(f.state, "down", "lying there")
	check(is_equal_approx(after_kick - f.health, Level.TUMBLE_DAMAGE), "a bit more damage (%.1f)" % (after_kick - f.health))
	var lying := 0
	while f.state in ["down", "get_up"] and lying < 400:
		l.step({})
		lying += 1
	check(lying >= 110, "and a long get-up, about 2 s (%d frames)" % lying)
	check(hp > f.health, "hurt in all")


func test_a_plain_hit_or_the_landing_is_no_tumble() -> void:
	var l = shop()
	on_flight(l, 1600.0)
	var f = bring(l, "thug", 1450.0)["f"]
	l.events = [{"attacker": l.hero, "target": f, "result": "hit", "move": "punch"}]
	l._stairs()
	check(f.state != "tumble", "a jab on the stairs: no tumble")
	var g = bring(l, "thug", 1880.0)["f"]
	check(absf(g.y - TOP) < 1.0, "one on the landing")
	l.events = [{"attacker": l.hero, "target": g, "result": "hit", "move": "push_kick"}]
	l._stairs()
	check(g.state != "tumble", "a push kick on the top landing: no tumble")
	var h = bring(l, "thug", 600.0, 80.0)["f"]
	l.events = [{"attacker": l.hero, "target": h, "result": "hit", "move": "push_kick"}]
	l._stairs()
	check(h.state != "tumble", "nor on the street")


func test_whoever_he_rolls_into_goes_down_too() -> void:
	var l = shop()
	on_flight(l, 1750.0)
	var upper = bring(l, "thug", 1600.0)["f"]
	var lower = bring(l, "thug", 1300.0)["f"]
	upper._enter("knockdown")
	l.events = [{"attacker": l.hero, "target": upper, "result": "hit", "move": "side_kick"}]
	l._stairs()
	eq(upper.state, "tumble", "a knockdown on the slope: tumbling")
	var bowled := false
	for i in 120:
		l.step({})
		bowled = bowled or lower.state == "tumble"
	check(bowled, "he bowls over the one below him, like skittles")
	check(upper.x < FOOT and lower.x < FOOT, "both end up at the foot (%.0f, %.0f)" % [upper.x, lower.x])


func test_a_tumbling_enemy_doesnt_bowl_the_hero_over() -> void:
	var l = shop()
	on_flight(l, 1300.0)  # the hero below
	var above = bring(l, "thug", 1600.0)["f"]
	above._enter("knockdown")
	l.events = [{"attacker": l.hero, "target": above, "result": "hit", "move": "push_kick"}]
	l._stairs()
	for i in 80:
		l.step({})
	check(l.hero.state != "tumble" and l.hero.y > 50.0, "he rolls past the hero (only a knockdown on him rolls the hero down)")


func test_the_same_rule_for_the_hero() -> void:
	var l = shop()
	on_flight(l, 1500.0)
	l.hero._enter("knockdown")
	l.events = [{"attacker": null, "target": l.hero, "result": "hit", "move": "smash"}]
	l._stairs()
	eq(l.hero.state, "tumble", "a heavy's knockdown on the stairs rolls the hero down too")
	for i in 120:
		l.step({})
	check(l.hero.x < FOOT and l.hero.y == 0.0, "to the foot")


func test_no_more_than_two_enemies_on_the_slope() -> void:
	var l = shop()
	on_flight(l, 1500.0)
	for k in 4:
		var e = bring(l, "thug", 700.0 - k * 60.0, 80.0)
		e["brain"].dormant_until_within = 0.0
		e["brain"].wait = 9999  # walking up to him, never swinging
	var most := 0
	var reached := false
	for i in 900:
		l.step({"block": true})
		var n: int = l.enemies.filter(func(e): return e["f"].y >= 1.0 and StreetWorld.on_slope(flight(l), e["f"].x)).size()
		most = maxi(most, n)
		reached = reached or n >= 1
	check(reached, "they come round to the foot and up the flight at him")
	check(most <= 2, "never more than two on it at once (%d)" % most)
	# failing direction: the rule really holds them back, there were more than two who wanted to come up
	var waiting: int = l.enemies.filter(func(e): return e["f"].y < 1.0).size()
	check(waiting >= 2, "the others wait at the foot (%d)" % waiting)


func test_the_bot_goes_up_the_flight_to_the_floor_above() -> void:
	var l = shop()
	var bot = HeroBot.new(l.hero, 1)
	for i in 3000:
		if l.on == 1:
			break
		bot.goal = l.next_door()
		l.step(bot.think(l.standing()))
	eq(l.on, 1, "the bot finds the foot, walks up and through to the flat above (at %.0f, %.0f, %.0f)" % [l.hero.x, l.hero.y, l.hero.z])


func test_the_bruiser_never_sets_foot_on_the_stairs() -> void:
	var l = shop()
	on_flight(l, 1500.0)
	var e = bring(l, "bruiser", 700.0, 80.0)
	e["brain"].dormant_until_within = 0.0
	e["brain"].wait = 9999
	var on_it := false
	for i in 600:
		l.step({"block": true})
		on_it = on_it or (e["f"].y >= 1.0 and StreetWorld.on_slope(flight(l), e["f"].x))
	check(not on_it, "he comes round to the foot but never up the flight (the team's roster v3)")
	check(absf(e["f"].x - FOOT) < 150.0, "he waits at the foot (%.0f)" % e["f"].x)
