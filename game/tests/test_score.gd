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


## Puts the hero down for good on his last life (as a level would).
func last_life_gone(l) -> void:
	l.lives = 1
	l.hero.health = 0.0
	l.hero._enter("ko")
	for i in Level.DOWN_TICKS + 2:
		l.step({})


func test_without_the_helper_the_last_life_loses_the_level() -> void:
	var l = street()
	last_life_gone(l)
	check(l.lost and not l.life_offer, "lost, no offer")


func test_the_helper_offers_a_life_and_takes_it_off_the_total() -> void:
	var l = street()
	l.helper = true
	l.bank = 1500
	l.score = 800
	last_life_gone(l)
	check(l.life_offer and not l.lost, "the last life gone: \"Another life for 2,000?\"")
	eq(l.life_price(), 2000, "the price")
	var t: int = l.tick
	l.step({})
	eq(l.tick, t, "(the level waits on the answer)")
	l.buy_life()
	eq(l.lives, 1, "a life")
	eq(l.hero.health, l.hero.max_health, "up again, full")
	eq(l.bank, 0, "the price off the earlier levels first...")
	eq(l.score, 300, "...then this level's (its score otherwise kept)")
	check(l.helper_used, "marked")


func test_the_helper_is_never_refused_short_and_costs_more_in_the_harder_mode() -> void:
	var l = street()
	l.helper = true
	l.harder = true
	l.score = 500
	last_life_gone(l)
	eq(l.life_price(), 3000, "3,000 in the harder mode")
	l.buy_life()
	check(l.lives == 1 and l.score == 0, "short of the price: still a life, the total down to zero")
	last_life_gone(l)
	l.decline_life()
	check(l.lost, "no thanks: the level's lost")
