extends "res://tests/test_case.gd"
## The glass lift (the team's levels page, level 5): a floor that rides about six seconds while its fight goes on; the
## doors open on the floor it was going to only once it has ridden its time AND its fight is beaten.

const Level := preload("res://scripts/sim/level.gd")
const HeroBot := preload("res://scripts/sim/hero_bot.gd")


func into_the_lift():
	var l = Level.new(Level.load_data("res://tests/levels/lift.json"), {}, 1)
	for i in 400:
		if l.on == 1:
			break
		l.step({"mx": 1.0})
	return l


func test_in_the_lift_the_fight_goes_on_while_it_rides() -> void:
	var l = into_the_lift()
	eq(l.where, "the glass lift", "into the lift")
	for i in 30:
		l.step({})
	eq(l.enemies.filter(func(e): return e["kind"] == "snick").size(), 2, "two Snicks in it with him")
	check(l.active_wave >= 0, "the fight's on")


func test_the_doors_wait_for_the_fight_to_be_won() -> void:
	var l = into_the_lift()
	for i in 500:
		l.step({"block": true})
	eq(l.on, 1, "ridden its time, Snicks still up: the doors stay shut")
	for e in l.enemies:
		e["f"].health = 0.0
		e["f"]._enter("ko")
	for i in 60:
		l.step({})
		if l.on != 1:
			break
	eq(l.where, "the main floor", "fight won: the doors open on the main floor")


func test_and_for_the_ride_to_end() -> void:
	var l = into_the_lift()
	for i in 20:
		l.step({})
	for e in l.enemies:
		e["f"].health = 0.0
		e["f"]._enter("ko")
	l.step({})
	eq(l.on, 1, "fight won at once: still riding")
	for i in 400:
		l.step({})
		if l.on != 1:
			break
	eq(l.on, 2, "and out when it's ridden its time")


func test_the_bot_rides_it_down_and_wins() -> void:
	var results := []
	for s in [1, 2, 3]:
		var l = Level.new(Level.load_data("res://tests/levels/lift.json"), {}, s)
		var bot = HeroBot.new(l.hero, s)
		for i in 12000:
			if l.won or l.lost:
				break
			bot.me = l.hero
			bot.goal = l.next_door()
			l.step(bot.think(l.standing()))
		results.append("won" if l.won else ("lost" if l.lost else "stuck in %s" % l.where))
	check(not results.any(func(r): return r.begins_with("stuck")), "never stuck: %s" % [results])
	check(results.count("won") >= 2, "and wins on most seeds: %s" % [results])
