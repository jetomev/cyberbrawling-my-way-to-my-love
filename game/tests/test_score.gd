extends "res://tests/test_case.gd"
## The score: the team's points (sim/score.gd; Merry and Pippin's agreed list, 2026-11-05), kept in parts, counted on
## every level, shown only with Javier's yes.

const Level := preload("res://scripts/sim/level.gd")
const Score := preload("res://scripts/sim/score.gd")


func street():
	return Level.new(Level.load_data("res://tests/levels/open_street.json"), {}, 1)


func bring(l) -> Variant:
	l._arrive({"kind": "thug", "dx": 100.0, "z": l.hero.z}, l.hero.x, -1)
	return l.enemies[-1]["f"]


func test_a_goon_down_and_a_finisher_score() -> void:
	var l = street()
	var f = bring(l)
	l.events = [{"attacker": l.hero, "target": f, "result": "hit", "move": "power_punch"}]
	l._score_blows()
	eq(l.score, Score.FINISHER, "a combo's last blow landing")
	f.health = 0.0
	f._enter("ko")
	l.step({})
	eq(l.score, Score.FINISHER + Score.ENEMY, "and the goon down")
	eq(l.score_parts, {"finishers": Score.FINISHER, "goons": Score.ENEMY}, "kept in parts")


func test_a_finisher_on_someone_dizzy_scores_more() -> void:
	var l = street()
	var f = bring(l)
	l.was_dizzy = {f: true}
	l.events = [{"attacker": l.hero, "target": f, "result": "hit", "move": "side_kick"}]
	l._score_blows()
	eq(l.score, Score.DIZZY_FINISHER, "the dizzy finisher")


func test_a_perfect_block_scores_only_when_it_breaks_a_combo_and_three_times_at_most() -> void:
	var l = street()
	var f = bring(l)
	l.events = [{"attacker": f, "target": l.hero, "result": "perfect", "move": "punch", "broke_combo": false}]
	l._score_blows()
	eq(l.score, 0, "a perfect block that broke nothing: nothing")
	for i in 5:
		l.events = [{"attacker": f, "target": l.hero, "result": "perfect", "move": "punch", "broke_combo": true}]
		l._score_blows()
	eq(l.score, Score.PERFECT_BLOCK * Score.PERFECT_BLOCKS_MAX, "breaking his combo: 100, three times at most")
	l.events = [{"attacker": f, "target": l.hero, "result": "perfect", "move": "punch", "broke_combo": true, "projectile": {"kind": "wrench"}}]
	var before: int = l.score
	l._score_blows()
	eq(l.score, before, "(a thrown wrench blocked: nothing)")


func test_a_pick_up_and_the_level_end() -> void:
	var l = street()
	l.world.drop("matchbook", l.hero.x, l.hero.z)
	l.step({})
	eq(l.score, Score.for_collectible("matchbook"), "the matchbook picked up")
	var before: int = l.score
	l.won = true
	l.close_score()
	var health: int = mini(int(l.hero.health) * Score.HEALTH_LEFT, Score.HEALTH_MAX)
	eq(l.score, before + health + Score.NO_HIT, "won: health left (up to 1,500), and no health lost")
	l.close_score()
	eq(l.score, before + health + Score.NO_HIT, "(once only)")


func test_any_health_lost_and_no_no_hit_bonus() -> void:
	var l = street()
	l.step({})
	l.hero.health -= 2.0  # (a crate, the container, a live floor: anything)
	l.step({})
	check(l.health_lost >= 2.0, "health lost to anything is counted (%.0f)" % l.health_lost)
	l.won = true
	l.close_score()
	eq(l.score_parts.get("no_hit", 0), 0, "won: no no-hit bonus")


func test_the_harder_mode_counts_half_again() -> void:
	var l = street()
	l.harder = true
	l.world.drop("matchbook", l.hero.x, l.hero.z)
	l.step({})
	eq(l.score, int(Score.for_collectible("matchbook") * Score.HARDER), "×1.5")
