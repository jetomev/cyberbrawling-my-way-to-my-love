extends "res://tests/test_case.gd"
## Mr. Static, level 7's boss (the team's roster, the bosses): baton, baton, baton jab, then he slams the floor and it
## goes live a second (jump it); perfect-block him and the HERO gets the shock (only he does this); P P K him in by the
## water tank and he shorts out, dizzy at once; his prize, rubber gloves, lets the hero block shocks from then on.

const Level := preload("res://scripts/sim/level.gd")
const HeroBot := preload("res://scripts/sim/hero_bot.gd")


func plant():
	var l = Level.new(Level.load_data("res://levels/static_plant.json"), {}, 1)
	for i in 400:
		if l.on == 1:
			break
		l.step({"mx": 1.0})
	return l


func static_of(l) -> Dictionary:
	return l.enemies.filter(func(e): return e["kind"] == "static")[0]


func test_he_carries_his_baton() -> void:
	eq(static_of(plant())["f"].weapon, "baton", "the crackling baton")


func test_any_block_shocks_the_hero_unless_he_wears_rubber_gloves() -> void:
	var l = plant()
	var e = static_of(l)
	var hp: float = l.hero.health
	l.events = [{"attacker": e["f"], "target": l.hero, "result": "perfect", "move": "swing"}]
	l._static_after()
	check(l.hero.health < hp, "a perfect block on his baton: the HERO is shocked (%.1f → %.1f)" % [hp, l.hero.health])
	eq(l.hero.state, "hurt", "and reels")
	var l2 = plant()
	l2.hero.rubber = true
	l2.events = [{"attacker": static_of(l2)["f"], "target": l2.hero, "result": "perfect", "move": "swing"}]
	l2._static_after()
	eq(l2.hero.health, l2.hero.max_health, "rubber gloves on: no shock")
	var l3 = plant()
	l3.events = [{"attacker": static_of(l3)["f"], "target": l3.hero, "result": "blocked", "move": "swing"}]
	l3._static_after()
	check(l3.hero.health < l3.hero.max_health, "a plain block too: shocked (the agreed level 7 page, any block)")
	var l4 = plant()
	l4.events = [{"attacker": static_of(l4)["f"], "target": l4.hero, "result": "hit", "move": "swing"}]
	l4._static_after()
	eq(l4.hero.health, l4.hero.max_health, "failing direction: a blow that simply lands is no block shock")


func slammed(jump_at: int):
	var l = plant()
	var e = static_of(l)
	e["brain"].wait = 9999
	e["f"].x = l.hero.x + 600.0
	l._static(e, {"slam": true})
	var hp: float = l.hero.health
	var up_while_live := false
	for i in Level.SLAM_WINDUP + Level.LIVE_TICKS + 30:
		l.step({"jump": e["f"].slam_in == jump_at})
		if l.tick < l.live_until and l.hero.y > 0.0:
			up_while_live = true
	return [hp - l.hero.health, up_while_live]


func test_the_slam_winds_up_then_the_floor_goes_live() -> void:
	var r = slammed(-99)
	check(r[0] > 0.0, "standing on it when it's live: shocked (%.1f)" % r[0])


func test_jump_as_it_comes_down_and_it_misses_him() -> void:
	var r = slammed(6)
	check(r[1], "he's in the air while it's live")
	eq(r[0], 0.0, "jumped it: no shock")
	var early_jump = slammed(Level.SLAM_WINDUP - 1)
	check(early_jump[0] > 0.0, "jump too early and he lands on it: shocked (%.1f)" % early_jump[0])


func test_p_p_k_into_the_water_tank_and_he_shorts_out() -> void:
	var l = plant()
	var e = static_of(l)
	var f = e["f"]
	f.x = 1500.0  # by the tank
	f._enter("idle")
	var hp: float = f.health
	l.events = [{"attacker": l.hero, "target": f, "result": "hit", "move": "push_kick"}]
	l._static_after()
	eq(f.state, "dizzy", "he shorts out: dizzy at once")
	check(f.health < hp, "and it hurts")
	var l2 = plant()
	var g = static_of(l2)["f"]
	g.x = 900.0  # far from the tank
	g._enter("idle")
	l2.events = [{"attacker": l2.hero, "target": g, "result": "hit", "move": "push_kick"}]
	l2._static_after()
	check(g.state != "dizzy", "away from the tank: a push kick is a push kick")


func test_his_prize_rubber_gloves_put_on_by_walking_over_them() -> void:
	var l = plant()
	l.world.drop("rubber_gloves", l.hero.x + 30.0, l.hero.z)
	for i in 20:
		l.step({"mx": 1.0})
	check(l.hero.rubber, "he's wearing them")


func test_the_bot_beats_mr_static() -> void:
	var results := []
	for s in [1, 2, 3]:
		var l = Level.new(Level.load_data("res://levels/static_plant.json"), {}, s)
		var bot = HeroBot.new(l.hero, s)
		for i in 15000:
			if l.won or l.lost:
				break
			bot.me = l.hero
			bot.goal = l.next_door()
			l.step(bot.think(l.standing()))
		results.append("won" if l.won else ("lost" if l.lost else "stuck"))
	check(not results.has("stuck"), "never stuck: %s" % [results])
	check(results.count("won") >= 2, "and wins on most seeds: %s" % [results])
