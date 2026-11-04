extends "res://tests/test_case.gd"
## The rest of the team's roster (art-in 2026-11-03, enemy roster v2), each with its own trick: the Wrench Mechanic
## ducks the high kicks, hurls his wrench (block it just right and it's yours) and fetches a spare from his toolbox;
## the Doorman's riot shield stops everything from the front, but a low kick into his bash knocks it aside; the Neon
## Dancer on skates is too quick for slow weapons until she's launched off them; the Enforcer parries the jab and
## strikes straight back; the lookout never fights, he whistles in two more goons; the Grabber grabs right through the
## guard, and it takes three quick punches (or a roll) to wriggle free before he throws you down.

const Level := preload("res://scripts/sim/level.gd")
const Brain := preload("res://scripts/sim/brain.gd")
const Fighter := preload("res://scripts/sim/fighter.gd")
const Fight := preload("res://scripts/sim/fight.gd")
const StreetWorld := preload("res://scripts/sim/street_world.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")

const ROSTER := ["wrench_mechanic", "doorman", "neon_dancer", "enforcer", "lookout", "grabber"]


func street():
	return Level.new(Level.load_data("res://tests/levels/open_street.json"), {}, 1)


## Brings one of them in, dx from the hero, and hands back his entry.
func bring(l, kind: String, dx := 300.0) -> Dictionary:
	l._spawn(kind, l.hero.x + dx, l.hero.z)
	return l.enemies[-1]


func blow(move: String, damage := 2.0, low := 120.0, high := 230.0) -> Dictionary:
	return {"damage": damage, "effect": "", "low": low, "high": high, "move": move}


func test_the_whole_roster_comes_in_armed_as_drawn() -> void:
	var l = street()
	for k in ROSTER:
		check(Level.KINDS.has(k), "%s is a kind" % k)
		check(Brain.TYPES.has(Level.KINDS[k]["brain"]), "with a way of fighting (%s)" % Level.KINDS[k]["brain"])
		bring(l, k)
	var weapons := {}
	for e in l.enemies:
		weapons[e["kind"]] = e["f"].weapon
	eq(weapons["wrench_mechanic"], "wrench", "the mechanic carries his wrench")
	eq(weapons["doorman"], "shield", "the Doorman his riot shield")
	eq(weapons["enforcer"], "sword", "the Enforcer his sword")
	eq(weapons["neon_dancer"], "", "the Dancer fights with her feet")


func test_the_mechanic_ducks_the_high_kicks_not_the_low_one() -> void:
	var l = street()
	var m = bring(l, "wrench_mechanic", 100.0)["f"]
	var hp: float = m.health
	eq(m.take_hit(blow("side_kick", 3.0, 150.0, 260.0), l.hero), "dodged", "a side kick to the face: he ducks it")
	eq(m.take_hit(blow("roundhouse", 3.0), l.hero), "dodged", "the roundhouse too")
	eq(m.health, hp, "and nothing landed")
	eq(m.take_hit(blow("kick", 2.0, 0.0, 110.0), l.hero), "hit", "the low kick gets him")
	check(m.health < hp, "and hurts")


## Throws his wrench at the hero from a step off and steps the level until it lands; block_at: how far off the
## wrench is when the hero raises his guard (0: never).
func hurl_at_hero(block_at: float) -> Array:
	var l = street()
	var m = bring(l, "wrench_mechanic", 300.0)
	m["brain"].wait = 9999
	m["brain"].dormant_until_within = 1.0  # keep him still: only the thrown wrench matters here
	l._hurl(m["f"])
	var seen := []
	for i in 80:
		var p = l.projectiles.flying[0] if not l.projectiles.flying.is_empty() else null
		var near: bool = p != null and absf(p["x"] - l.hero.x) < block_at
		l.step({"block": near})
		for ev in l.events:
			if ev.get("projectile") != null:
				seen.append(ev["result"])
	return [l, m["f"], seen]


func test_the_mechanic_hurls_his_wrench_and_a_perfect_block_catches_it() -> void:
	var r := hurl_at_hero(30.0)
	var l = r[0]
	eq(r[1].weapon, "", "the wrench left his hand")
	eq(r[2], ["caught"], "blocked just as it lands: caught")
	eq(l.hero.weapon, "wrench", "and it's the hero's now")
	eq(l.world.items.filter(func(it): return it["kind"] == "wrench").size(), 0, "nothing left lying on the street")


func test_an_unblocked_wrench_hits_and_falls_to_the_street() -> void:
	var r := hurl_at_hero(0.0)
	var l = r[0]
	eq(r[2], ["hit"], "no guard: it hits him")
	check(l.hero.health < l.hero.max_health, "and hurts (%.1f)" % l.hero.health)
	eq(l.hero.weapon, "", "nothing caught")
	eq(l.world.items.filter(func(it): return it["kind"] == "wrench").size(), 1, "the wrench lies on the street, for anyone")


func test_the_mechanic_fetches_a_spare_from_his_toolbox() -> void:
	var l = street()
	l.world.add("toolbox", 1200.0, 1260.0, 60.0, 100.0, 40.0, false, 0)
	var m = bring(l, "wrench_mechanic", 600.0)
	m["f"].drop_weapon()
	var got := false
	for i in 600:
		l.step({})
		if m["f"].weapon == "wrench":
			got = true
			break
	check(got, "empty-handed, he walks to his toolbox and comes back with a spare (at %.0f)" % m["f"].x)
	# failing direction: with no toolbox on the street he stays empty-handed
	var l2 = street()
	var m2 = bring(l2, "wrench_mechanic", 600.0)
	m2["f"].drop_weapon()
	for i in 600:
		l2.step({})
	eq(m2["f"].weapon, "", "no toolbox, no spare")


func test_the_doormans_shield_stops_everything_from_the_front() -> void:
	var l = street()
	var d = bring(l, "doorman", 100.0)["f"]
	d.facing = -1
	var hp: float = d.health
	for mv in ["punch", "cross", "kick", "side_kick"]:
		eq(d.take_hit(blow(mv, 3.0), l.hero), "shielded", "%s from the front: off the shield" % mv)
	eq(d.health, hp, "not a scratch")
	d.facing = 1  # turned away from the hero
	eq(d.take_hit(blow("punch", 2.0), l.hero), "hit", "from behind it lands")


func test_a_low_kick_into_his_bash_knocks_the_shield_aside() -> void:
	var w = StreetWorld.new()
	var hero = Fighter.new(Tuning.fresh(), 400.0, 80.0, w)
	hero.facing = 1
	var door = Fighter.new(Tuning.fresh(), 480.0, 80.0, w)
	door.team = 1
	door.facing = -1
	door.take_weapon("shield")
	var fight := Fight.new()
	hero.step({"kick": true})
	var landed := ""
	for i in 40:
		hero.step({})
		if hero.attack_phase() == "active" and landed == "":
			door._enter("punch")  # his bash just starting as the kick arrives
			for ev in fight.step([hero, door], w):
				landed = ev["result"]
		door.step({})
	eq(door.weapon, "", "the shield is knocked out of his hands")
	eq(landed, "hit", "and the kick lands on him")
	eq(w.items.filter(func(it): return it["kind"] == "shield").size(), 1, "the shield lies on the street")


func test_the_dancer_is_too_quick_for_slow_weapons_until_shes_off_her_skates() -> void:
	var l = street()
	var n = bring(l, "neon_dancer", 100.0)
	var f = n["f"]
	check(f.tune["walk_speed"] > Tuning.DEFAULTS["walk_speed"], "on skates she's quicker than anyone")
	var slow := blow("swing", 3.0)
	slow["weapon_speed"] = 1
	eq(f.take_hit(slow, l.hero), "dodged", "a slow weapon's swing: she's gone")
	var quick := blow("swing", 2.0)
	quick["weapon_speed"] = 0
	eq(f.take_hit(quick, l.hero), "hit", "a quick one (a knife) catches her")
	f._enter("launch")
	l.step({})
	check(not f.too_quick, "launched: off her skates (%s)" % f.state)
	check(f.tune["walk_speed"] < Tuning.DEFAULTS["walk_speed"], "and slower than anyone on foot")
	f._enter("idle")
	eq(f.take_hit(slow, l.hero), "hit", "now the slow weapon lands")


func test_the_enforcer_parries_the_jab_and_strikes_straight_back() -> void:
	var l = street()
	var e = bring(l, "enforcer", 100.0)
	var f = e["f"]
	f.facing = -1
	f._enter("idle")
	var hp: float = f.health
	eq(f.take_hit(blow("punch", 1.0), l.hero), "parried", "the jab: caught on his blade")
	eq(f.health, hp, "no harm done")
	eq(f.take_hit(blow("kick", 2.0, 0.0, 110.0), l.hero), "hit", "a kick gets through")
	f._enter("idle")
	e["brain"].wait = 200
	l.events = [{"attacker": l.hero, "target": f, "result": "parried", "move": "punch"}]
	l._roster_tricks()
	eq(e["brain"].wait, 0, "after a parry he doesn't wait his turn: straight back at you")


func test_the_lookout_never_fights_and_whistles_in_two_more() -> void:
	var l = street()
	var look = bring(l, "lookout", 500.0)
	var start: float = look["f"].x
	var swung := false
	var whistles := 0
	for i in Level.WHISTLE_EVERY + 10:
		l.step({})
		swung = swung or look["f"].attack_phase() != ""
		whistles += l.events.filter(func(ev): return ev.get("result", "") == "whistle").size()
	check(not swung, "he never throws a blow")
	check(look["f"].x > start, "he backs off from the hero (%.0f, from %.0f)" % [look["f"].x, start])
	eq(whistles, 2, "two whistles in that time")
	eq(l.enemies.filter(func(e): return e["kind"] == "glow_punk").size(), 4, "two goons each time")
	# failing direction: the hero far off, no whistle
	var l2 = street()
	bring(l2, "lookout", Level.WHISTLE_RANGE + 400.0)
	for i in 60:
		l2.step({})
	eq(l2.enemies.size(), 1, "out of earshot: nobody comes")


func test_the_whistle_keeps_to_five_at_once() -> void:
	var l = street()
	bring(l, "lookout", 500.0)
	for k in 3:
		bring(l, "thug", -300.0 - k * 50.0)["brain"].wait = 9999
	l.step({})
	eq(l.standing().size(), Level.MAX_ON_SCREEN, "one goon whistled in, then the street is full")


## The Grabber steps in on a hero holding his guard; returns the level once the hero is held (or after 600 ticks).
func grabbed():
	var l = street()
	bring(l, "grabber", 250.0)["brain"].wait = 0
	for i in 600:
		l.step({"block": true})
		if l.hero.state == "held":
			break
	return l


func test_the_grabber_grabs_right_through_the_guard() -> void:
	var l = grabbed()
	eq(l.hero.state, "held", "his guard was up: the grab gets him anyway")
	check(not l.hug.is_empty(), "the bear hug is on")


func test_three_quick_punches_wriggle_free_and_leave_him_off_balance() -> void:
	var l = grabbed()
	var g = l.hug["by"]["f"]
	for i in 6:
		l.step({"punch": i % 2 == 0})
	check(l.hero.state != "held", "three punches: free (%s)" % l.hero.state)
	eq(g.state, "stagger", "and the Grabber is off balance")
	eq(l.hero.health, l.hero.max_health, "free before the throw: no harm done")


func test_a_roll_wriggles_free_too() -> void:
	var l = grabbed()
	l.step({"roll": true})
	check(l.hero.state != "held", "a roll: free (%s)" % l.hero.state)


func test_held_too_long_hes_thrown_down() -> void:
	var l = grabbed()
	var hp: float = l.hero.health
	for i in Level.HUG_TICKS + 5:
		l.step({})
	check(l.hero.state in ["knockdown", "down", "get_up"], "not wriggling: thrown down (%s)" % l.hero.state)
	check(is_equal_approx(hp - l.hero.health, Level.HURL_DAMAGE), "for %.0f (took %.1f)" % [Level.HURL_DAMAGE, hp - l.hero.health])
	check(l.hug.is_empty(), "and the hug is over")


func test_the_bot_gets_through_the_roster_yard() -> void:
	const HeroBot := preload("res://scripts/sim/hero_bot.gd")
	var results := []
	for s in [1, 2, 3]:
		var l = Level.new(Level.load_data("res://levels/roster_yard.json"), {}, s)
		var bot = HeroBot.new(l.hero, s)
		for i in 20000:
			if l.won or l.lost:
				break
			bot.me = l.hero
			l.step(bot.think(l.standing()))
		results.append("won" if l.won else "%s at %.0f, wave %d" % ["lost" if l.lost else "stuck", l.hero.x, l.wave])
	check(not results.any(func(r): return r.begins_with("stuck")), "never stuck against any of the six: %s" % [results])
	check(results.count("won") >= 2, "and through on most seeds: %s" % [results])


func test_the_mechanic_pops_up_out_of_a_duck_with_a_headbutt() -> void:
	var l = street()
	var m = bring(l, "wrench_mechanic", 90.0)
	var f = m["f"]
	f.facing = -1
	m["brain"].wait = 9999
	l.events = [{"attacker": l.hero, "target": f, "result": "dodged", "move": "side_kick"}]
	l._roster_tricks()
	var butted := false
	for i in 40:
		l.step({})
		butted = butted or l.events.any(func(ev): return ev.get("attacker") == f and ev.get("move", "") == "headbutt" and ev["result"] == "hit")
	check(butted, "he ducks the high kick and comes up with a headbutt that lands")
	# failing direction: a plain hit on him is no cue for it
	var l2 = street()
	var m2 = bring(l2, "wrench_mechanic", 90.0)
	m2["brain"].wait = 9999
	l2.events = [{"attacker": l2.hero, "target": m2["f"], "result": "hit", "move": "kick"}]
	l2._roster_tricks()
	eq(m2["brain"].plan, [], "a plain kick that lands: no headbutt lined up")


func test_a_layout_can_say_who_the_lookout_calls_and_how_often() -> void:
	var l = street()
	l._arrive({"kind": "lookout", "dx": 500.0, "z": 40.0, "calls": "wrench_mechanic", "whistles": 2}, l.hero.x, 0)
	for i in Level.WHISTLE_EVERY * 3 + 10:
		l.step({"block": true})
	var called: Array = l.enemies.filter(func(e): return e["kind"] != "lookout").map(func(e): return e["kind"])
	eq(called.size(), 4, "two whistles, two each, and that's his lot: %s" % [called])
	check(called.all(func(k): return k == "wrench_mechanic"), "Mechanics, as the layout says")


func test_no_wrench_and_no_toolbox_he_fights_on_swing_swing_headbutt() -> void:
	var l = street()
	var m = bring(l, "wrench_mechanic", 110.0)
	m["f"].drop_weapon()
	m["brain"].wait = 0
	var moves := []
	for i in 300:
		l.step({"block": true})
		if m["f"].attack_phase() == "startup" and m["f"].t == 0:
			moves.append(m["f"].state)
	check(moves.has("headbutt"), "fists: swing, swing, then the headbutt (%s)" % [moves.slice(0, 6)])
	check(not moves.has("hurl"), "nothing to hurl")
