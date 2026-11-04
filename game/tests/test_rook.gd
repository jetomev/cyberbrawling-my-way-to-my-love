extends "res://tests/test_case.gd"
## Velvet Rook, level 8's boss (the team's roster, the bosses): the Enforcer's three cuts, faster, then "Checkmate": his
## Enforcers come in through the doors, one for each door switch still standing; he parries the plain combos (P P P,
## K K K), only the mixed ones get through; a perfect block doesn't knock his sword loose, but three on his last cut
## break it, and he's only fists, slow and old; a sword is the prize.

const Level := preload("res://scripts/sim/level.gd")
const Brain := preload("res://scripts/sim/brain.gd")
const HeroBot := preload("res://scripts/sim/hero_bot.gd")


func penthouse():
	var l = Level.new(Level.load_data("res://levels/rook_penthouse.json"), {}, 1)
	for i in 400:
		if l.on == 1:
			break
		l.step({"mx": 1.0})
	return l


func rook(l) -> Dictionary:
	return l.enemies.filter(func(e): return e["kind"] == "rook")[0]


func test_he_parries_the_plain_combos_not_the_mixed() -> void:
	var l = penthouse()
	var f = rook(l)["f"]
	f.facing = -1 if f.x > l.hero.x else 1
	for mv in ["power_punch", "side_kick"]:
		f._enter("idle")
		eq(f.take_hit({"damage": 3.0, "effect": "", "low": 120.0, "high": 230.0, "move": mv}, l.hero), "parried", "%s (a plain combo's end): parried" % mv)
	for mv in ["push_kick", "uppercut", "roundhouse"]:
		f._enter("idle")
		eq(f.take_hit({"damage": 2.0, "effect": "", "low": 60.0, "high": 230.0, "move": mv}, l.hero), "hit", "%s (a mixed combo's end): gets through" % mv)


func test_checkmate_one_enforcer_per_standing_door_switch() -> void:
	var l = penthouse()
	var e = rook(l)
	l._rook(e, {"checkmate": true})
	eq(l.enemies.filter(func(x): return x["kind"] == "enforcer").size(), 2, "both switches standing: two Enforcers")
	var l2 = penthouse()
	for o in l2.world.objects:
		if o["kind"] == "door_switch":
			o["broken"] = true
			break
	l2._rook(rook(l2), {"checkmate": true})
	eq(l2.enemies.filter(func(x): return x["kind"] == "enforcer").size(), 1, "one smashed: one Enforcer")
	var l3 = penthouse()
	for o in l3.world.objects:
		if o["kind"] == "door_switch":
			o["broken"] = true
	l3._rook(rook(l3), {"checkmate": true})
	eq(l3.enemies.filter(func(x): return x["kind"] == "enforcer").size(), 0, "all smashed: nobody comes")
	l._rook(e, {"checkmate": true})
	eq(l.enemies.filter(func(x): return x["kind"] == "enforcer").size(), 2, "and not again straight away")


func test_three_perfect_blocks_on_his_last_cut_break_his_sword() -> void:
	var l = penthouse()
	var e = rook(l)
	var f = e["f"]
	l.events = [{"attacker": f, "target": l.hero, "result": "perfect", "move": "swing"}]
	l._rook_after()
	eq(e.get("sword_blocks", 0), 0, "a perfect block on his first cut doesn't count")
	for k in 2:
		l.events = [{"attacker": f, "target": l.hero, "result": "perfect", "move": "smash"}]
		l._rook_after()
	eq(f.weapon, "sword", "two on his last cut: the sword holds")
	l.events = [{"attacker": f, "target": l.hero, "result": "perfect", "move": "smash"}]
	l._rook_after()
	eq(f.weapon, "", "the third: his sword BREAKS")
	eq(e["brain"].kind, Brain.ROOK_OLD, "only fists now, slow and old")
	eq(l.world.items.filter(func(it): return it["kind"] == "sword").size(), 0, "nothing left of it to pick up")


func test_a_perfect_block_does_not_knock_his_sword_loose() -> void:
	var w = preload("res://scripts/sim/street_world.gd").new()
	var Fighter := preload("res://scripts/sim/fighter.gd")
	var Fight := preload("res://scripts/sim/fight.gd")
	var hero = Fighter.new(preload("res://scripts/sim/tuning.gd").fresh(), 400.0, 80.0, w)
	var r = Fighter.new(preload("res://scripts/sim/tuning.gd").fresh(), 500.0, 80.0, w)
	r.team = 1
	r.facing = -1
	r.take_weapon("sword")
	r.grip = true
	var fight := Fight.new()
	r.step({"punch": true})
	var perfect := false
	for i in 40:
		hero.step({"block": i >= 4})
		r.step({})
		for ev in fight.step([hero, r], w):
			perfect = perfect or ev["result"] == "perfect"
	check(perfect, "the hero's guard went up just in time: perfect")
	eq(r.weapon, "sword", "but his grip holds: the sword stays in his hand")


func test_the_bot_beats_velvet_rook() -> void:
	var results := []
	for s in [1, 2, 3]:
		var l = Level.new(Level.load_data("res://levels/rook_penthouse.json"), {}, s)
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
