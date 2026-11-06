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


func test_on_the_docks_a_goon_knocked_off_a_stack_lands_hurt_and_waits_at_the_path() -> void:
	var l = Level.new(Level.load_data("res://levels/level6.json"), {}, 1)
	l.floors[0]["wave"] = l.floors[0]["waves"].size()
	l.hero.x = 6600.0
	l.hero.y = 200.0
	l.hero.z = 30.0
	l._arrive({"kind": "wrench_mechanic", "dx": 120.0, "z": 30.0, "y": 200.0}, l.hero.x, -1)
	var e: Dictionary = l.enemies[-1]
	var f = e["f"]
	f.x = 6998.0  # right at the second gap's lip
	f.facing = -1
	f.take_hit({"damage": 1.0, "effect": "knockdown", "low": 0.0, "high": 300.0, "move": "push_kick"}, {"x": 6900.0, "y": 200.0})
	var fell := false
	for i in 400:
		l.step({})
		fell = fell or l.events.any(func(ev): return ev.get("result", "") == "fell")
	check(fell and f.y < 1.0, "knocked off the stack: down on the quay")
	check(f.health <= f.max_health * Level.FALLEN_HEALTH + 0.01, "hurt (%.0f of %.0f)" % [f.health, f.max_health])
	check(absf(f.x - 7640.0) < 40.0, "gone to the foot of the path down and waiting there (x %.0f)" % f.x)
	check(e.get("waits_below", false), "not coming at him while he's up there")


func test_on_the_docks_the_whistler_hops_from_lamp_to_lamp() -> void:
	var l = Level.new(Level.load_data("res://levels/level6.json"), {}, 1)
	l.floors[0]["wave"] = l.floors[0]["waves"].size()
	l.hero.x = 5130.0
	l.hero.y = 400.0
	l.hero.z = 20.0
	l._arrive({"kind": "lookout", "dx": 130.0, "z": 20.0, "y": 400.0, "whistles": 0}, l.hero.x, -1)
	var f = l.enemies[-1]["f"]
	var hopped := false
	for i in 120:
		l.step({"mx": 0.3})
		hopped = hopped or l.events.any(func(ev): return ev.get("result", "") == "hop")
	check(hopped, "cornered at his lamp's lip, he hops the short gap")
	check(f.x > 5380.0 and absf(f.y - 400.0) < 1.0, "onto the next lamp's stack (x %.0f, %.0f up)" % [f.x, f.y])


func test_on_the_docks_climbing_down_a_ladder_onto_a_stack_sets_him_on_the_stack() -> void:
	var l = Level.new(Level.load_data("res://levels/level6.json"), {}, 1)
	l.floors[0]["wave"] = l.floors[0]["waves"].size()  # (nobody about)
	var h = l.hero
	h.x = 4980.0  # at the top of screen 3's ladder, up on floor 3
	h.y = 400.0
	h.z = 15.0
	var hp: float = h.health
	var fell := false
	for i in 120:
		l.step({"mz": 1.0} if i < 5 else {})
		fell = fell or l.events.any(func(ev): return ev.get("result", "") == "hero_fell")
	eq(h.y, 200.0, "down the ladder onto floor 2's stack (y %.0f, z %.0f)" % [h.y, h.z])
	check(not fell and h.health == hp, "and nothing fell (health %.0f of %.0f)" % [h.health, hp])
