extends "res://tests/test_case.gd"
## Throwing the weapon in hand (TODO: "throw the held weapon at a far enemy; it lands and can be picked up again"; the
## key itself waits on Javier's pick): it leaves the hand at the throw's release, flies, hurts whoever it meets a little
## more than a swing and falls a step past him, or drops where its flight ends; it can be picked up again; the knife
## flies furthest; some catch it (the Godfather, level 10); in the crane's cab there's no room to throw.

const Level := preload("res://scripts/sim/level.gd")
const Weapons := preload("res://scripts/sim/weapons.gd")


func street():
	return Level.new(Level.load_data("res://tests/levels/open_street.json"), {}, 1)


func throw_at(l, what: String, foe_dx: float) -> Dictionary:
	l.hero.take_weapon(what)
	l.hero.facing = 1
	var e := {}
	if foe_dx > 0.0:
		l._spawn("thug", l.hero.x + foe_dx, l.hero.z)
		e = l.enemies[-1]
		e["brain"].wait = 9999
		e["brain"].dormant_until_within = 1.0
	l.step({"throw": true})
	var hit := false
	var landed := false
	for i in 120:
		l.step({})
		for ev in l.events:
			hit = hit or (ev.get("projectile") != null and ev["result"] == "hit")
			landed = landed or ev["result"] == "landed"
		if l.projectiles.flying.is_empty() and i > 10:
			break
	return {"hit": hit, "landed": landed, "foe": e}


func test_a_thrown_weapon_hits_a_far_enemy_and_falls_past_him() -> void:
	var l = street()
	var r := throw_at(l, "pipe", 450.0)
	eq(l.hero.weapon, "", "it left his hand")
	check(r["hit"], "it flies and hits the enemy 450 px off")
	check(r["foe"]["f"].health < r["foe"]["f"].max_health, "and hurts him")
	var on_street: Array = l.world.items.filter(func(it): return it["kind"] == "pipe")
	eq(on_street.size(), 1, "the pipe lies on the street")
	check(on_street[0]["x"] > r["foe"]["f"].x, "a step past him")


func test_a_miss_drops_where_its_flight_ends_and_he_can_pick_it_up() -> void:
	var l = street()
	var from: float = l.hero.x
	var r := throw_at(l, "pipe", 0.0)
	check(r["landed"], "nobody there: it drops at the end of its flight")
	var it: Dictionary = l.world.items.filter(func(x): return x["kind"] == "pipe")[0]
	check(absf(it["x"] - from - Weapons.THROW_RANGE_DEFAULT) < 80.0, "about %d px off (%.0f)" % [int(Weapons.THROW_RANGE_DEFAULT), it["x"] - from])
	for i in 400:
		l.step({"mx": 1.0})
		if l.hero.weapon != "":
			break
	eq(l.hero.weapon, "pipe", "he walks over it: his again")


func test_the_knife_flies_furthest() -> void:
	var l = street()
	var from: float = l.hero.x
	throw_at(l, "knife", 0.0)
	var it: Dictionary = l.world.items.filter(func(x): return x["kind"] == "knife")[0]
	check(it["x"] - from > Weapons.THROW_RANGE_DEFAULT + 150.0, "the knife spins further (%.0f px)" % (it["x"] - from))


func test_one_who_catches_takes_it_out_of_the_air() -> void:
	var l = street()
	l.hero.take_weapon("bat")
	l.hero.facing = 1
	l._spawn("thug", l.hero.x + 400.0, l.hero.z)
	var g = l.enemies[-1]
	g["brain"].wait = 9999
	g["brain"].dormant_until_within = 1.0
	g["f"].catches = true
	g["f"].facing = -1
	l.step({"throw": true})
	for i in 60:
		l.step({})
	eq(g["f"].weapon, "bat", "caught, and his now")
	eq(g["f"].health, g["f"].max_health, "no harm to him")


func test_no_throw_without_a_weapon_or_in_the_cab() -> void:
	var l = street()
	l.step({"throw": true})
	check(l.hero.state != "throw", "empty-handed: nothing to throw")
	var l2 = street()
	l2.hero.take_weapon("pipe")
	l2.hero.no_swing = true
	l2.hero.step({"throw": true})
	check(l2.hero.state != "throw", "no room in the cab")
	eq(l2.hero.weapon, "pipe", "he keeps it")


func test_the_throwing_arm_itself_hits_nobody() -> void:
	var l = street()
	l.hero.take_weapon("pipe")
	l.hero.facing = 1
	l._spawn("thug", l.hero.x + 80.0, l.hero.z)  # right up close
	var e = l.enemies[-1]
	e["brain"].wait = 9999
	e["brain"].dormant_until_within = 1.0
	l.step({"throw": true})
	var arm_hit := false
	for i in 12:
		l.step({})
		arm_hit = arm_hit or l.events.any(func(ev): return ev.get("attacker") == l.hero)
	check(not arm_hit, "the arm's swing lands on nobody (only the weapon, flying)")
