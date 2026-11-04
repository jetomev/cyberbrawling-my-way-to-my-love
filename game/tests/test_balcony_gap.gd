extends "res://tests/test_case.gd"
## Level 4's balcony knock-off (the team's level 4 page, Javier's yes 2026-11-04): a gap in the low railing on screen 4.
## A goon standing in it, push-kicked or knocked down, tips over the bar and drops to the ring hall below: out of the
## fight, counted as beaten, nothing dropped. The hero never goes over: for him the gap is a wall.

const Level := preload("res://scripts/sim/level.gd")


## Level 4 on its balcony at the gap, the balcony's own goons set aside, one Wrench Mechanic standing where asked.
func balcony(z: float, x := 2900.0) -> Array:
	var l = Level.new(Level.load_data("res://levels/level4.json"), {}, 1)
	l._go_to(1, 2700.0, 0.0, 120.0)
	l.floors[1]["wave"] = l.floors[1]["waves"].size()
	l._spawn("wrench_mechanic", x, z)
	var e: Dictionary = l.enemies[-1]
	e["brain"].wait = 9999
	e["brain"].dormant_until_within = 1.0
	return [l, e]


func test_the_gap_is_on_screen_four_at_the_front() -> void:
	var l = Level.new(Level.load_data("res://levels/level4.json"), {}, 1)
	l._go_to(1, 300.0)
	var g: Array = l.railing_gap()
	eq(g.size(), 2, "the balcony has its railing gap")
	check(float(g[0]) >= 1920.0 and float(g[1]) <= 3840.0, "on screen 4 (the balcony's second screen): %s" % str(g))
	l._go_to(2, 300.0)
	check(l.railing_gap().is_empty(), "round the ring: no gap")
	eq(l.plan["hints"].get("gap", ""), "Push kick them through the gap.", "the hint, word for word")


func test_a_push_kick_in_the_gap_sends_him_over_out_of_the_fight() -> void:
	var le := balcony(160.0)
	var l = le[0]
	var e: Dictionary = le[1]
	var d = e["f"]
	check(l.at_gap(d), "he stands in the gap, at the front edge")
	var items: int = l.world.items.size()
	l.events = [{"attacker": l.hero, "target": d, "result": "hit", "move": "push_kick"}]
	l._through_the_gap()
	check(e.has("over_rail"), "the push kick: over the bar he goes")
	var low := 0.0
	var below := false
	for i in Level.GAP_TICKS + 5:
		l.step({})
		low = minf(low, d.y)
		below = below or l.events.any(func(ev): return ev.get("result", "") == "down_below")
	check(below and e["gone"] and d.defeated(), "down to the ring hall: out of the fight, counted as beaten")
	check(d.z > l.tune["street_depth"], "out past the railing (z %.0f)" % d.z)
	check(low < -200.0, "and down below the balcony (%.0f px)" % low)
	eq(l.world.items.size(), items, "nothing dropped: it all went over with him")


func test_any_knockdown_in_the_gap_counts_too() -> void:
	var le := balcony(160.0)
	var l = le[0]
	var d = le[1]["f"]
	d._enter("knockdown")
	l.events = [{"attacker": l.hero, "target": d, "result": "hit", "move": "side_kick"}]
	l._through_the_gap()
	check(le[1].has("over_rail"), "a knockdown at the gap: over he goes")


func test_not_in_the_gap_not_over() -> void:
	var le := balcony(160.0)
	var l = le[0]
	var d = le[1]["f"]
	l.events = [{"attacker": l.hero, "target": d, "result": "hit", "move": "punch"}]
	l._through_the_gap()
	check(not le[1].has("over_rail"), "a jab that doesn't knock him down: he stays")
	for at in [[60.0, 2900.0], [160.0, 3300.0]]:  # at the back of the balcony; along it, past the gap
		le = balcony(at[0], at[1])
		l = le[0]
		d = le[1]["f"]
		check(not l.at_gap(d), "not at the gap (z %.0f, x %.0f)" % at)
		l.events = [{"attacker": l.hero, "target": d, "result": "hit", "move": "push_kick"}]
		l._through_the_gap()
		check(not le[1].has("over_rail"), "the push kick there: the railing holds him (z %.0f, x %.0f)" % at)


func test_the_hero_never_goes_over() -> void:
	var le := balcony(60.0, 3500.0)
	var l = le[0]
	l.hero.x = 2880.0
	for i in 80:
		l.step({"mz": 1.0})
	check(l.hero.z <= l.tune["street_depth"] + 0.01, "walked into the gap: the edge holds him (z %.0f)" % l.hero.z)
	check(l.hero.y > -1.0 and not l.hero.defeated(), "still on the balcony, on his feet")
	check(l.at_gap(l.hero), "(he really stands in the gap)")
	l.hero._enter("knockdown")  # knocked down there himself: no rule sends the hero over
	l.events = [{"attacker": l.hero, "target": l.hero, "result": "hit", "move": "push_kick"}]
	l._through_the_gap()
	for i in 60:
		l.step({})
	check(l.hero.y > -1.0 and l.hero.z <= l.tune["street_depth"] + 0.01, "knocked down in the gap: still on the balcony")


func test_the_hint_comes_when_a_goon_stands_in_the_gap() -> void:
	var le := balcony(160.0)
	var l = le[0]
	l.hero.x = 2700.0
	l.step({})
	eq(l.hint_text, "Push kick them through the gap.", "a goon in the gap, the hero near: the hint")


func test_knocked_out_in_the_gap_he_goes_over_too() -> void:
	var le := balcony(160.0)
	var l = le[0]
	var d = le[1]["f"]
	d.health = 0.0
	d._enter("ko")
	l.events = [{"attacker": l.hero, "target": d, "result": "hit", "move": "smash"}]
	l._through_the_gap()
	check(le[1].has("over_rail"), "knocked out cold in the gap: over he goes, nothing left behind")
