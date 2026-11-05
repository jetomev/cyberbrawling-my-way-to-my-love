extends "res://tests/test_case.gd"
## The score (placeholder points, sim/score.gd): counted, not shown, until the team says what counts.

const Level := preload("res://scripts/sim/level.gd")
const Score := preload("res://scripts/sim/score.gd")


func street():
	return Level.new(Level.load_data("res://tests/levels/open_street.json"), {}, 1)


func test_a_goon_down_and_a_finisher_score() -> void:
	var l = street()
	l._arrive({"kind": "thug", "dx": 100.0, "z": l.hero.z}, l.hero.x, -1)
	var f = l.enemies[-1]["f"]
	l.events = [{"attacker": l.hero, "target": f, "result": "hit", "move": "power_punch"}]
	l._score_blows()
	eq(l.score, Score.FINISHER, "a combo's last blow landing")
	f.health = 0.0
	f._enter("ko")
	l.step({})
	eq(l.score, Score.FINISHER + Score.ENEMY, "and the goon down")


func test_a_pick_up_and_the_level_end() -> void:
	var l = street()
	l.world.drop("matchbook", l.hero.x, l.hero.z)
	l.step({})
	eq(l.score, Score.for_collectible("matchbook"), "the matchbook picked up")
	var before: int = l.score
	l.won = true
	l.close_score()
	eq(l.score, before + int(l.hero.health) * Score.HEALTH_LEFT + Score.NO_HIT, "won: health left, and never hit")
	l.close_score()
	eq(l.score, before + int(l.hero.health) * Score.HEALTH_LEFT + Score.NO_HIT, "(once only)")


func test_hit_once_and_no_no_hit_bonus() -> void:
	var l = street()
	l.events = [{"attacker": null, "target": l.hero, "result": "hit", "move": "punch"}]
	l._score_blows()
	eq(l.hits_taken, 1, "a blow on him counted")
	l.won = true
	l.close_score()
	eq(l.score, int(l.hero.health) * Score.HEALTH_LEFT, "won: health left, no no-hit bonus")
