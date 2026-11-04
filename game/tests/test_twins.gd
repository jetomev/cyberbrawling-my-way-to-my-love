extends "res://tests/test_case.gd"
## Twin Loans, level 3's boss (the team's roster, the bosses): two brothers; while one attacks the other guards and
## waits; halfway through a combo they swap places ("Interest"); at half their health both rush together
## ("Compound"); knocked down a flight, a brother takes about ten seconds to climb back; both down wins the level,
## and the tall one leaves the stick.

const Level := preload("res://scripts/sim/level.gd")
const StreetWorld := preload("res://scripts/sim/street_world.gd")
const HeroBot := preload("res://scripts/sim/hero_bot.gd")


func shop():
	var l = Level.new(Level.load_data("res://tests/levels/twins.json"), {}, 1)
	for i in 400:
		if l.on == 1:
			break
		l.step({"mx": 1.0})
	return l


func twin(l, kind: String) -> Dictionary:
	return l.enemies.filter(func(e): return e["kind"] == kind)[0]


func test_two_brothers_where_the_layout_puts_them() -> void:
	var l = shop()
	eq(l.on, 1, "into the pawn shop")
	var short = twin(l, "twin_short")["f"]
	var tall = twin(l, "twin_tall")["f"]
	check(twin(l, "twin_short")["boss"] and twin(l, "twin_tall")["boss"], "both are the boss")
	eq(short.y, 0.0, "the short one on the shop floor")
	check(absf(tall.y - 400.0) < 1.0, "the tall one at the top of the stairs (%.0f)" % tall.y)


func test_one_guards_while_the_other_attacks() -> void:
	var l = shop()
	var a = twin(l, "twin_short")
	var b = twin(l, "twin_tall")
	b["f"].x = l.hero.x + 260.0  # both down on the floor with him
	b["f"].y = 0.0
	b["f"].z = 80.0
	a["f"].x = l.hero.x + 120.0
	a["brain"].plan = ["punch", "punch"]
	a["f"].step({"punch": true})
	l.step({})
	check(not b["brain"].allowed, "his brother's swinging: he waits his turn")
	check(b["f"].state == "block" or b["brain"].block_left > 0, "with his guard up (%s)" % b["f"].state)


func test_interest_they_swap_places_halfway_through_a_combo() -> void:
	var l = shop()
	var a = twin(l, "twin_short")
	var b = twin(l, "twin_tall")
	b["f"].x = l.hero.x + 300.0
	b["f"].y = 0.0
	b["f"].z = 80.0
	a["f"].x = l.hero.x + 120.0
	a["f"].z = 80.0
	a["brain"].wait = 0
	var swapped := -1
	for i in 300:
		l.step({})
		if l.events.any(func(ev): return ev.get("result", "") == "swap"):
			swapped = i
			break
	check(swapped >= 0, "a combo starts, and halfway they swap places")
	check(absf(b["f"].x - l.hero.x) < absf(a["f"].x - l.hero.x), "the guarding brother is now the near one (%.0f vs %.0f)" % [b["f"].x, a["f"].x])


func test_compound_at_half_their_health_both_rush_together() -> void:
	var l = shop()
	var a = twin(l, "twin_short")
	var b = twin(l, "twin_tall")
	l.step({})
	check(not l.compound, "not at first")
	a["f"].health = 12.0
	b["f"].health = 12.0
	l.step({})
	check(l.compound, "at half their health together: Compound")
	check(a["brain"].allowed and b["brain"].allowed, "both may attack at once")


func test_knocked_down_the_stairs_he_takes_about_ten_seconds_to_climb_back() -> void:
	var l = shop()
	var b = twin(l, "twin_tall")
	var f = b["f"]
	var st: Dictionary = l.world.objects.filter(func(o): return o["kind"] == "stairs")[0]
	l.hero.x = 1460.0  # the hero up on the landing, where the tall one was
	l.hero.z = 15.0
	l.hero.y = 400.0
	f.x = 1300.0
	f.y = StreetWorld.step_height(st, 1300.0)
	twin(l, "twin_short")["f"].health = 0.0  # just the one brother here
	twin(l, "twin_short")["f"]._enter("ko")
	l.events = [{"attacker": l.hero, "target": f, "result": "hit", "move": "push_kick"}]
	l._stairs()
	eq(f.state, "tumble", "the push kick shoves him down the stairs")
	var back := -1
	for i in 1500:
		l.step({"block": true})
		if i > 60 and f.y >= 300.0:
			back = i
			break
	check(back > 0, "he does climb back")
	check(back >= 480 and back <= 900, "about ten seconds before he's back near the top (%.1f s)" % (back / 60.0))


func test_both_down_wins_and_the_tall_one_leaves_the_stick() -> void:
	var l = shop()
	twin(l, "twin_short")["f"].health = 0.0
	twin(l, "twin_short")["f"]._enter("ko")
	l.step({})
	check(not l.won, "one brother down is not enough")
	twin(l, "twin_tall")["f"].health = 0.0
	twin(l, "twin_tall")["f"]._enter("ko")
	l.step({})
	check(l.won, "both down: the level is won")
	check(l.world.items.any(func(it): return it["kind"] == "stick"), "and the stick is the prize")


func test_the_bot_beats_twin_loans() -> void:
	var results := []
	for s in [1, 2, 3]:
		var l = Level.new(Level.load_data("res://tests/levels/twins.json"), {}, s)
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


## The team's third ruling: the brothers open with their swap, once, whatever the hero does: here a hero who walks
## straight at the short one and punches from the first frame. Hits still hurt them, but nothing rocks the opener
## till they've swapped; after that they flinch as before.
func test_they_open_with_their_swap_even_against_a_rush() -> void:
	var l = Level.new(Level.load_data("res://levels/level3.json"), {}, 1)
	l._go_to(3, 150.0)
	var short: Dictionary = twin(l, "twin_short")
	var opened := -1
	var swapped := -1
	for i in 600:
		var dx: float = short["f"].x - l.hero.x
		l.step({"mx": signf(dx) if absf(dx) > 100.0 else 0.0, "punch": i % 12 == 0})
		for ev in l.events:
			if ev.get("result", "") == "opening" and opened < 0:
				opened = i
			if ev.get("result", "") == "swap" and swapped < 0:
				swapped = i
	check(opened >= 0 and opened < 180, "they open within three seconds of him walking in (at %d)" % opened)
	check(swapped > opened and swapped - opened < 30, "and swap on the opening combo's second blow (%d frames on)" % (swapped - opened))
	check(short["f"].health < short["f"].max_health, "his punches really landed on the short one meanwhile")
	check(not l.enemies.any(func(e): return e["f"].unflinching and not e["f"].defeated() and not l.compound and e["brain"].plan.is_empty()),
		"after the opening, nobody stays unflinching")


## The tall brother hurries down the stairs only to open with his brother; once they're both at him at once (Compound)
## there's no opening to come, and he walks at his own pace (an escape down the stairs stays an escape).
func test_no_hurry_down_the_stairs_once_its_both_at_once() -> void:
	var l = Level.new(Level.load_data("res://levels/level3.json"), {}, 1)
	l._go_to(3, 150.0)
	l.step({})
	var tall: Dictionary = twin(l, "twin_tall")
	check(not tall["f"].flight().is_empty(), "(he starts up on the stairs: the setup)")
	l.step({})
	check(tall["f"].tune["walk_speed"] > tall["walk"] * 1.5, "before the opening: he hurries down")
	l.compound = true
	l.step({})
	check(is_equal_approx(tall["f"].tune["walk_speed"], tall["walk"]), "both at once: his own pace (%.1f, his %.1f)" % [tall["f"].tune["walk_speed"], tall["walk"]])
