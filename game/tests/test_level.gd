extends "res://tests/test_case.gd"
## The level (Stage 1: a grey level 1 with the boss upstairs): the street locks at each wave until it's beaten, the
## stairs take him up to the boss, the boss down wins the level, three lives and then the level restarts (D-15); and
## a bot plays it through on several seeds (L-8).

const Level := preload("res://scripts/sim/level.gd")
const HeroBot := preload("res://scripts/sim/hero_bot.gd")


func level(seed_value := 1):
	return Level.new(Level.load_data("res://levels/level1.json"), {}, seed_value)


## Puts every standing enemy down for good, as if beaten.
func beat_them(l) -> void:
	for f in l.standing():
		f.health = 0.0
		f._enter("ko")


func walk_to(l, x: float, ticks := 4000) -> void:
	var start: String = l.where
	for i in ticks:
		if l.hero.x >= x or l.won or l.lost or l.where != start:
			return
		l.step({"mx": 1.0})


func test_level_one_loads() -> void:
	var l = level()
	check(l.data["waves"].size() >= 3, "level 1 has its waves (%d)" % l.data["waves"].size())
	eq(l.lives, 3, "three lives (D-15)")
	eq(l.where, "street", "it starts on the street")
	eq(l.enemies.size(), 0, "nobody there until he walks up")


func test_the_street_locks_at_a_wave_until_its_beaten() -> void:
	var l = level()
	var at: float = l.data["waves"][0]["at"]
	walk_to(l, at)
	eq(l.active_wave, 0, "walking up to the first wave starts it")
	check(l.standing().size() >= 2, "its thugs are there (%d)" % l.standing().size())
	var lock: float = at + Level.LOCK_MARGIN
	eq(l.bounds().y, lock, "the street locks %d px past the wave" % int(Level.LOCK_MARGIN))
	beat_them(l)  # (so they don't fight back while he tries to walk on)
	for e in l.enemies:
		e["f"].health = 12.0
		e["f"]._enter("idle")
		e["brain"].wait = 100000
	for i in 600:
		l.step({"mx": 1.0})
	check(l.hero.x <= lock + 0.5, "while they stand he can't walk on past the lock (%.0f, lock %.0f)" % [l.hero.x, lock])
	beat_them(l)
	l.step({})
	eq(l.active_wave, -1, "beaten, the street opens")
	walk_to(l, lock + 200.0, 600)
	check(l.hero.x > lock, "and he walks on")


func test_up_the_stairs_to_the_boss_and_the_level_is_won() -> void:
	var l = level()
	for w in l.data["waves"].size():
		walk_to(l, l.data["waves"][w]["at"])
		l.step({})
		beat_them(l)
		l.step({})
	walk_to(l, l.data["stairs"] + 10.0)
	l.step({})
	eq(l.where, "upstairs", "past the last wave, the stairs take him up")
	eq(l.standing().size(), 1, "the boss waits there")
	eq(l.standing()[0].max_health, float(l.data["boss"]["health"]), "with his own health")
	check(not l.won, "not won yet")
	beat_them(l)
	l.step({})
	check(l.won, "the boss down for good: the level is won")


func test_three_lives_then_the_level_restarts() -> void:
	var l = level()
	for life in 3:
		l.hero.health = 0.0
		l.hero._enter("ko")
		for i in Level.DOWN_TICKS + 2:
			l.step({})
	check(l.lost, "the third life gone: the level is lost")
	l.restart()
	eq(l.lives, 3, "it restarts from the level's start with three lives")
	eq(l.hero.health, l.hero.max_health, "fresh")
	eq(l.where, "street", "on the street")


func test_a_life_lost_he_gets_up_where_he_was() -> void:
	var l = level()
	walk_to(l, 900.0)
	var x: float = l.hero.x
	l.hero.health = 0.0
	l.hero._enter("ko")
	for i in Level.DOWN_TICKS + 2:
		l.step({})
	eq(l.lives, 2, "one life gone")
	check(not l.lost, "the level goes on")
	eq(l.hero.health, l.hero.max_health, "up again, healed")
	check(absf(l.hero.x - x) < 1.0, "where he fell")


func test_the_bot_plays_level_one_through() -> void:
	# L-8: a bot plays every level on several seeds; a level it can't finish is a finding
	var results := []
	for s in [1, 2, 3]:
		var l = level(s)
		var bot = HeroBot.new(l.hero, s)
		for i in 30000:
			if l.won or l.lost:
				break
			if l.where == "upstairs" and bot.me != l.hero:
				bot.me = l.hero
			l.step(bot.think(l.standing()))
		results.append("won" if l.won else "%s at %.0f, wave %d, %s" % ["lost" if l.lost else "stuck", l.hero.x, l.wave, l.where])
	check(not results.any(func(r): return r.begins_with("stuck")), "the bot is never stuck: %s" % [results])
	check(results.count("won") >= 2, "and wins on most seeds: %s" % [results])


func test_only_two_attack_at_once() -> void:
	var l = level()
	walk_to(l, l.data["waves"][0]["at"])
	beat_them(l)
	l.step({})
	var w: Dictionary = l.data["waves"][1]
	walk_to(l, w["at"])
	for i in 30:
		l.step({})
	var turns: Array = l.enemies.filter(func(e): return not e["gone"]).map(func(e): return e["brain"].allowed)
	check(turns.size() >= 3, "a wave of three (%d)" % turns.size())
	eq(turns.count(true), Level.ATTACKERS, "only two may attack; the third waits his turn")


func test_food_and_first_aid_heal_the_hero() -> void:
	var l = level()
	check(l.data["items"].any(func(i): return i[0] == "food"), "level 1 has food on the street")
	var food: Array = ["food", 420.0, 80.0]
	l.world.drop("food", food[1], food[2])
	l.hero.health = 5.0
	for i in 60:
		l.step({"mx": 1.0})
	check(l.hero.health > 5.0, "walking over the food, hurt, he eats it (%.0f)" % l.hero.health)
	check(not l.world.items.any(func(i): return i["x"] == food[1]), "and it's gone")
