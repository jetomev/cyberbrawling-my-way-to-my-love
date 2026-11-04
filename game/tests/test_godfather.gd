extends "res://tests/test_case.gd"
## The Godfather of Glow, level 10's boss (the team's roster, the bosses): three rounds. Armour: only the Lovelight cuts
## his coat; thrown, he catches it. Speed: only a blow into his wind-up lands. Rage: he blocks the last combo used on
## him; two combos make him dizzy and the finisher landed then saves your love. Lose a life and only that round
## restarts.

const Level := preload("res://scripts/sim/level.gd")
const HeroBot := preload("res://scripts/sim/hero_bot.gd")


func top():
	var l = Level.new(Level.load_data("res://levels/tower_top.json"), {}, 1)
	l._go_to(1, 300.0)
	l.step({})
	return l


func boss(l) -> Dictionary:
	return l.enemies.filter(func(e): return e["kind"] == "godfather")[0]


func blow(move := "punch", counter := false) -> Dictionary:
	return {"damage": 3.0, "effect": "", "low": 100.0, "high": 230.0, "move": move, "counter": counter}


func end_round(l, e) -> void:
	e["f"].health = 0.0
	e["f"]._enter("ko")
	l.step({})


func test_round_one_only_the_lovelight_cuts_his_coat() -> void:
	var l = top()
	var f = boss(l)["f"]
	f._enter("idle")
	eq(f.take_hit(blow(), l.hero), "bounced", "a fist: off the coat")
	l.hero.take_weapon("pipe")
	eq(f.take_hit(blow("swing"), l.hero), "bounced", "a pipe: off the coat")
	l.hero.take_weapon("lovelight")
	eq(f.take_hit(blow("swing"), l.hero), "hit", "the Lovelight: it cuts")


func test_round_one_throw_the_lovelight_and_he_catches_it() -> void:
	var l = top()
	var f = boss(l)["f"]
	boss(l)["brain"].wait = 9999
	f.x = l.hero.x + 400.0
	f.facing = -1
	l.hero.take_weapon("lovelight")
	l.hero.facing = 1
	l.step({"throw": true})
	for i in 60:
		l.step({})
	eq(f.weapon, "lovelight", "he catches it, and it's his")


func test_a_round_won_he_comes_back_for_the_next() -> void:
	var l = top()
	var e = boss(l)
	end_round(l, e)
	check(not l.won, "round one won: not over")
	eq(e["round"], 2, "round two")
	eq(e["f"].health, e["f"].max_health, "fresh for it")
	check(not e["f"].armour, "the coat's off")


func test_round_two_only_a_blow_into_his_wind_up_lands() -> void:
	var l = top()
	var e = boss(l)
	end_round(l, e)
	var f = e["f"]
	f._enter("idle")
	eq(f.take_hit(blow(), l.hero), "dodged", "a plain jab: too fast for it")
	f._enter("idle")
	eq(f.take_hit(blow("punch", true), l.hero), "hit", "into his wind-up: it lands")


func test_round_three_he_blocks_the_last_combo_and_the_dizzy_finisher_saves_your_love() -> void:
	var l = top()
	var e = boss(l)
	end_round(l, e)
	end_round(l, e)
	eq(e["round"], 3, "round three, rage")
	var f = e["f"]
	e["last_combo"] = "KKK"
	l.hero.chain = ""
	l.hero._enter("side_kick")
	l._chrome(e, {})
	f._enter("idle")
	f.facing = -1 if f.x > l.hero.x else 1
	eq(f.take_hit(blow("side_kick"), l.hero), "parried", "the same combo again: blocked")
	f.health = 2.0
	f._enter("idle")
	f.take_hit(blow("roundhouse"), l.hero)
	check(not f.defeated() and f.health >= 1.0, "worn down in the rage round he won't fall (%.1f)" % f.health)
	f._enter("idle")
	var kd := blow("roundhouse")
	kd["effect"] = "knockdown"
	f.take_hit(kd, l.hero)
	eq(f.state, "stagger", "a knockdown blow only rocks him: on his feet, the dizzy count kept")
	f.health = 5.0
	f.dizzy_left = 100
	f._enter("dizzy")
	l.step({})
	l.events = [{"attacker": l.hero, "target": f, "result": "hit", "move": "power_punch"}]
	l._godfather()
	check(f.defeated(), "the finisher while he's dazed: it's over")
	l.step({})
	check(l.won, "your love is saved")


func test_lose_a_life_and_only_the_round_restarts() -> void:
	var l = top()
	var e = boss(l)
	end_round(l, e)
	e["f"].health = 4.0
	l.lives -= 1
	l.step({})
	eq(e["round"], 2, "still round two, not back to one")
	eq(e["f"].health, e["f"].max_health, "that round starts again, fresh")


func test_the_bot_saves_your_love() -> void:
	var results := []
	for s in [1, 2, 3]:
		var l = Level.new(Level.load_data("res://levels/tower_top.json"), {}, s)
		var bot = HeroBot.new(l.hero, s)
		for i in 25000:
			if l.won or l.lost:
				break
			bot.me = l.hero
			bot.goal = l.next_door()
			l.step(bot.think(l.standing()))
		results.append("won" if l.won else ("lost" if l.lost else "still fighting"))
	check(results.count("won") >= 2, "through all three rounds on most seeds: %s" % [results])
