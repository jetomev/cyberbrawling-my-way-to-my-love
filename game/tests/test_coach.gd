extends "res://tests/test_case.gd"
## Coach Crusher, level 4's boss (the team's roster, the bosses): medicine-ball throw, jab, jab, then a tackle; his big
## gloves block every punch, so kicks only; step aside from the tackle and he slams into the ropes, open; dizzy him
## twice and he gives up.

const Level := preload("res://scripts/sim/level.gd")
const HeroBot := preload("res://scripts/sim/hero_bot.gd")


func gym():
	var l = Level.new(Level.load_data("res://levels/coach_gym.json"), {}, 1)
	for i in 400:
		if l.on == 1:
			break
		l.step({"mx": 1.0})
	return l


func coach(l) -> Dictionary:
	return l.enemies.filter(func(e): return e["kind"] == "coach")[0]


func test_his_gloves_block_every_punch_but_not_a_kick() -> void:
	var l = gym()
	var f = coach(l)["f"]
	f.x = l.hero.x + 100.0
	f.facing = -1
	f._enter("idle")
	var hp: float = f.health
	for mv in ["punch", "cross", "power_punch"]:
		f._enter("idle")
		eq(f.take_hit({"damage": 3.0, "effect": "", "low": 120.0, "high": 230.0, "move": mv}, l.hero), "blocked", "%s: into the gloves" % mv)
	eq(f.health, hp, "not a scratch")
	f._enter("idle")
	eq(f.take_hit({"damage": 2.0, "effect": "", "low": 0.0, "high": 110.0, "move": "kick"}, l.hero), "hit", "a kick gets him")
	check(f.health < hp, "and hurts")


func test_the_medicine_ball_flies_at_him() -> void:
	var l = gym()
	var e = coach(l)
	e["f"].x = l.hero.x + 500.0
	e["brain"].wait = 9999
	l._coach(e, {"ball": true})
	eq(l.projectiles.flying.size(), 1, "the ball's thrown")
	eq(l.projectiles.flying[0]["kind"], "ball", "a medicine ball")
	check(l.projectiles.flying[0]["vx"] < 0.0, "toward the hero")


func test_the_tackle_knocks_him_down() -> void:
	var l = gym()
	var e = coach(l)
	e["f"].x = l.hero.x + 400.0
	e["f"].z = l.hero.z
	e["brain"].wait = 9999
	l._coach(e, {"tackle": true})
	var hp: float = l.hero.health
	for i in 120:
		l.step({})
		if not e.has("tackle"):
			break
	check(l.hero.state in ["knockdown", "down", "get_up"], "he runs into him: knocked down (%s)" % l.hero.state)
	check(is_equal_approx(hp - l.hero.health, Level.TACKLE_DAMAGE), "for %.0f" % Level.TACKLE_DAMAGE)


func test_step_aside_and_he_slams_into_the_ropes_open() -> void:
	var l = gym()
	var e = coach(l)
	var f = e["f"]
	f.x = l.hero.x + 400.0
	f.z = 120.0
	l.hero.z = 20.0  # stepped out of his line
	e["brain"].wait = 9999
	l._coach(e, {"tackle": true})
	var ropes := false
	for i in 400:
		l.step({})
		ropes = ropes or l.events.any(func(ev): return ev.get("result", "") == "ropes")
		if ropes:
			break
	check(ropes, "he runs past into the ropes")
	eq(l.hero.health, l.hero.max_health, "the hero untouched")
	eq(f.state, "stagger", "and he stands dazed")
	var open := 0
	while f.state == "stagger" and open < 400:
		l.step({})
		open += 1
	check(open >= Level.ROPES_DAZE, "open long enough for K K K (%d frames)" % open)


func test_dizzy_him_twice_and_he_gives_up() -> void:
	var l = gym()
	var e = coach(l)
	var f = e["f"]
	e["brain"].wait = 9999
	f.dizzy_left = 30
	f._enter("dizzy")
	l.step({})
	check(not f.defeated(), "dizzy once: he fights on")
	f._enter("idle")
	l.step({})
	f.dizzy_left = 30
	f._enter("dizzy")
	l.step({})
	check(f.defeated(), "dizzy twice: he gives up")
	check(l.won, "and the level's won")


func test_the_bot_beats_coach_crusher() -> void:
	var results := []
	for s in [1, 2, 3]:
		var l = Level.new(Level.load_data("res://levels/coach_gym.json"), {}, s)
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


## The testers' send-back on 9ce3cd1 (the team's level 4: "he bounces off the ropes"): the ropes give and throw him back
## into the ring, then he stands dazed; the view bends the ropes where he hit.
func test_off_the_ropes_he_bounces_back_into_the_ring() -> void:
	var l = gym()
	var e = coach(l)
	var f = e["f"]
	f.x = l.hero.x + 400.0
	f.z = 120.0
	l.hero.z = 20.0
	e["brain"].wait = 9999
	l._coach(e, {"tackle": true})
	var at_ropes := -1.0
	var rebound := false
	for i in 400:
		l.step({})
		if at_ropes < 0.0 and l.events.any(func(ev): return ev.get("result", "") == "ropes"):
			at_ropes = f.x
			var middle: float = (l.bounds().x + l.bounds().y) * 0.5
			check(not l.rope_hit.is_empty() and float(l.rope_hit["side"]) == signf(at_ropes - middle),
				"the ropes on the side he ran into are marked hit (they bend)")
		if l.events.any(func(ev): return ev.get("result", "") == "rebound"):
			rebound = true
			break
	check(at_ropes > 0.0 and rebound, "into the ropes, and back off them")
	var mid: float = (l.bounds().x + l.bounds().y) * 0.5
	check(absf(f.x - mid) < absf(at_ropes - mid) - 60.0, "thrown back toward the middle of the ring (%.0f px off the ropes)" % absf(at_ropes - f.x))
	eq(f.state, "stagger", "then dazed, open")
