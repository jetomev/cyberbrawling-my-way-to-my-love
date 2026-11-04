extends "res://tests/test_case.gd"
## Madame Chrome, level 5's boss (the team's roster, the bosses): three cards thrown, then she's open a moment; a low
## cane sweep (jump it) and a cane jab; any combo the hero uses twice in a row she parries; three kicks into her
## cane's wind-up snap it, and then she's done; the pipe is her prize.

const Level := preload("res://scripts/sim/level.gd")
const HeroBot := preload("res://scripts/sim/hero_bot.gd")


func casino():
	var l = Level.new(Level.load_data("res://levels/chrome_casino.json"), {}, 1)
	l._go_to(2, 300.0)  # (past the doors and the lift: her floor)
	return l


func chrome(l) -> Dictionary:
	return l.enemies.filter(func(e): return e["kind"] == "chrome")[0]


func test_she_carries_her_cane() -> void:
	var l = casino()
	eq(chrome(l)["f"].weapon, "cane", "the chrome cane")


func test_three_cards_then_she_is_open_then_the_sweep_and_the_jab() -> void:
	var l = casino()
	var e = chrome(l)
	e["f"].x = l.hero.x + 400.0
	l._chrome(e, {"cards": true})
	var then: int = e["then"]
	var cards := 0
	var was_open := false
	var next_plan := []
	while l.tick < then + 1:
		l.step({"block": true})
		for p in l.projectiles.flying:
			if p["kind"] == "card" and not p.has("seen"):
				p["seen"] = true
				cards += 1
		was_open = was_open or (l.tick > then - Level.CHROME_OPEN and e["f"].parries.is_empty() and e["brain"].block_left == 0)
		if not e.has("then") and next_plan.is_empty():
			next_plan = e["brain"].plan.duplicate()
	eq(cards, 3, "three cards thrown")
	check(was_open, "after them she's open: no guard, no parry")
	eq(next_plan, ["sweep", "punch"], "then the low cane sweep and the cane jab")


func test_a_combo_used_twice_in_a_row_she_parries() -> void:
	var l = casino()
	var e = chrome(l)
	var f = e["f"]
	e["last_combo"] = "PPP"  # he's just finished P P P on her
	e["brain"].wait = 9999
	f.facing = -1 if f.x > l.hero.x else 1
	l.hero.chain = ""  # and finishes P P P again (his chain reads empty on a finisher)
	l.hero._enter("power_punch")
	l._chrome(e, {})
	f._enter("idle")
	eq(f.take_hit({"damage": 2.0, "effect": "", "low": 120.0, "high": 230.0, "move": "power_punch"}, l.hero), "parried", "the same combo again: its finisher parried")
	# the same opening with a different finish isn't a repeat: P P K after P P P
	l.hero._enter("push_kick")
	l._chrome(e, {})
	f._enter("idle")
	eq(f.take_hit({"damage": 2.0, "effect": "", "low": 60.0, "high": 160.0, "move": "push_kick"}, l.hero), "hit", "P P K after P P P: a different combo, it lands")
	# a finished combo is read from its finisher
	l.events = [{"attacker": l.hero, "target": f, "result": "hit", "move": "side_kick", "counter": false}]
	l._chrome_after()
	eq(e["last_combo"], "KKK", "K K K finished on her: she knows it")
	e["last_combo"] = "PPP"
	# failing direction: a different combo she can't read
	l.hero.chain = "KK"
	l.hero._enter("body_kick")
	l._chrome(e, {})
	f._enter("idle")
	eq(f.take_hit({"damage": 1.0, "effect": "", "low": 60.0, "high": 160.0, "move": "body_kick"}, l.hero), "hit", "mixed up: it lands")


func test_three_kicks_into_the_canes_wind_up_snap_it_and_she_is_done() -> void:
	var l = casino()
	var e = chrome(l)
	var f = e["f"]
	for k in 2:
		l.events = [{"attacker": l.hero, "target": f, "result": "hit", "move": "kick", "counter": true}]
		l._chrome_after()
	eq(f.weapon, "cane", "two kicks: the cane holds")
	check(not f.defeated(), "and she fights on")
	l.events = [{"attacker": l.hero, "target": f, "result": "punch", "move": "punch", "counter": true}]
	l._chrome_after()
	eq(f.weapon, "cane", "a punch into the wind-up doesn't count (a kick beats a weapon)")
	l.events = [{"attacker": l.hero, "target": f, "result": "hit", "move": "body_kick", "counter": true}]
	l._chrome_after()
	eq(f.weapon, "", "the third kick: the cane SNAPS")
	check(f.defeated(), "and she's done")
	eq(l.world.items.filter(func(it): return it["kind"] == "cane").size(), 0, "nothing left of the cane to pick up")
	l.step({})
	check(l.won, "the level's won")


func test_the_bot_beats_madame_chrome() -> void:
	var results := []
	for s in [1, 2, 3]:
		var l = Level.new(Level.load_data("res://levels/chrome_casino.json"), {}, s)
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
