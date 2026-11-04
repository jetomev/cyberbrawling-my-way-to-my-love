extends "res://tests/test_case.gd"
## Stage 1: one enemy type that fights back. Blows land once each and hurt (fight.gd); each finisher's effect plays
## out (stagger, push, knockdown, launch) and he gets back up; a block takes less, a perfect block none and stops the
## combo; a timed roll takes nothing; the last blow puts him down for good and he drops his weapon; the enemy's mind
## (brain.gd) walks up and hits back, the same way every time for the same seed.

const Fighter := preload("res://scripts/sim/fighter.gd")
const Fight := preload("res://scripts/sim/fight.gd")
const Brain := preload("res://scripts/sim/brain.gd")
const StreetWorld := preload("res://scripts/sim/street_world.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")


func pair(gap := 100.0):
	var hero = Fighter.new(Tuning.fresh(), 400.0, 80.0)
	var t := Tuning.fresh()
	t["health"] = 12.0
	var enemy = Fighter.new(t, 400.0 + gap, 80.0)
	enemy.team = 1
	enemy.facing = -1
	return [hero, enemy]


## Steps both, the hero on the given presses (one per tick, then nothing), settling blows; returns every event.
func play(hero, enemy, presses: Array, ticks: int, fight = null, world = null) -> Array:
	var f = fight if fight != null else Fight.new()
	var events := []
	for i in ticks:
		hero.step(presses[i] if i < presses.size() else {})
		enemy.step({})
		events.append_array(f.step([hero, enemy], world))
	return events


func test_a_blow_lands_once_and_hurts() -> void:
	var p = pair()
	var events := play(p[0], p[1], [{"punch": true}], 20)
	eq(events.size(), 1, "the jab lands once, not once per tick it's out")
	eq(events[0]["result"], "hit", "a clean hit")
	eq(p[1].health, 11.0, "it takes the jab's damage")
	check(p[1].x > 500.0, "and drives him back a little (%.1f)" % p[1].x)


func test_a_blow_out_of_reach_misses() -> void:
	var p = pair(300.0)
	eq(play(p[0], p[1], [{"punch": true}], 20).size(), 0, "a jab can't reach 300 px")
	var q = pair()
	q[1].z = 80.0 + 60.0
	eq(play(q[0], q[1], [{"punch": true}], 20).size(), 0, "nor someone further up the street")


func test_no_hitting_your_own_side() -> void:
	var p = pair()
	p[1].team = 0
	eq(play(p[0], p[1], [{"punch": true}], 20).size(), 0, "a blow only lands on the other team")


func test_each_finisher_has_its_effect() -> void:
	# P,P,P ends in the power punch: he reels back
	var p = pair(90.0)
	p[1].tune["health"] = 99.0
	p[1].health = 99.0
	var seen := {}
	var presses := []
	for i in 80:
		presses.append({"punch": i % 14 == 0})
	var f := Fight.new()
	for i in 80:
		p[0].step(presses[i])
		p[1].step({})
		f.step([p[0], p[1]])
		seen[p[1].state] = true
	check(seen.has("stagger"), "the power punch staggers him (saw %s)" % [seen.keys()])
	# K,K,K ends in the side kick: he goes down, lies there, gets up
	var q = pair(90.0)
	q[1].health = 99.0
	var states := []
	f = Fight.new()
	for i in 260:
		q[0].step({"kick": i % 14 == 0 and i < 50})
		q[1].step({})
		f.step([q[0], q[1]])
		if states.is_empty() or states[-1] != q[1].state:
			states.append(q[1].state)
	for s in ["knockdown", "down", "get_up", "idle"]:
		check(s in states, "the side kick: %s (saw %s)" % [s, states])
	check(states.find("knockdown") < states.find("down") and states.find("down") < states.find("get_up"),
		"in that order: falls, lies, gets up")


func test_the_push_kick_shoves_and_the_uppercut_launches() -> void:
	var p = pair(90.0)
	p[1].health = 99.0
	var r: String = p[1].take_hit({"damage": 1, "effect": "push"}, p[0])
	eq(r, "hit", "a push lands")
	var x0: float = p[1].x
	for i in 20:
		p[1].step({})
	check(p[1].x - x0 > 60.0, "the push kick shoves him well away (%.0f px)" % (p[1].x - x0))
	eq(p[1].state, "idle", "and he recovers")
	var q = pair(90.0)
	q[1].health = 99.0
	q[1].take_hit({"damage": 3, "effect": "launch"}, q[0])
	var top := 0.0
	for i in 60:
		q[1].step({})
		top = maxf(top, q[1].y)
	check(top > 60.0, "the uppercut throws him up (%.0f px)" % top)
	eq(q[1].state, "down", "and he lands on his back")
	check(not q[1].on_ground() or q[1].y == 0.0, "back on the street")


func test_no_hitting_a_man_when_hes_down() -> void:
	var p = pair()
	p[1].take_hit({"damage": 1, "effect": "knockdown"}, p[0])
	for i in 30:
		p[1].step({})
	eq(p[1].state, "down", "lying on the street")
	eq(p[1].take_hit({"damage": 1, "effect": ""}, p[0]), "", "a blow can't land on him")


func test_a_block_takes_less_and_a_perfect_block_none() -> void:
	var p = pair()
	p[1].step({"block": true})  # raised the tick before: perfect
	var events := []
	var f := Fight.new()
	p[0].step({"punch": true})
	for i in 20:
		p[1].step({"block": true})
		events.append_array(f.step([p[0], p[1]]))
		p[0].step({})
	eq(events.size(), 1, "the jab meets the guard")
	eq(events[0]["result"], "perfect", "early in the guard: a perfect block")
	eq(p[1].health, 12.0, "it takes nothing")
	var q = pair()
	for i in 20:
		q[1].step({"block": true})  # held long: a plain block
	f = Fight.new()
	events = []
	q[0].step({"punch": true})
	for i in 20:
		q[1].step({"block": true})
		events.append_array(f.step([q[0], q[1]]))
		q[0].step({})
	eq(events[0]["result"], "blocked", "late in the guard: a plain block")
	check(q[1].health < 12.0 and q[1].health > 11.0, "it takes a little (%.2f), less than the jab's 1" % q[1].health)
	eq(q[1].blocking(), "block", "and he's back in his guard, past its perfect window")


func test_a_guard_facing_away_stops_nothing() -> void:
	var p = pair()
	p[1].facing = 1  # his back to the hero
	for i in 3:
		p[1].step({"block": true})
	var events := play(p[0], p[1], [{"punch": true}], 20)
	eq(events[0]["result"], "hit", "blocking the wrong way doesn't help")


func test_a_perfect_block_stops_the_combo() -> void:
	var p = pair()
	var f := Fight.new()
	var events := []
	p[1].step({"block": true})
	for i in 40:
		p[0].step({"punch": i in [0, 6]})  # jab, and the cross lined up behind it
		p[1].step({"block": true})
		events.append_array(f.step([p[0], p[1]]))
	eq(events[0]["result"], "perfect", "the jab is perfectly blocked")
	check(not "cross" in events.map(func(e): return e["move"]), "the cross he'd lined up never comes")


func test_a_timed_roll_takes_nothing() -> void:
	var p = pair()
	var f := Fight.new()
	p[1].facing = 1
	p[1].step({"roll": true})
	for i in 12:
		p[1].step({})
	check(p[1].evading(), "round, over the shoulder")
	eq(p[1].take_hit({"damage": 3, "effect": "knockdown"}, p[0]), "evaded", "a blow passes over him")
	eq(p[1].health, 12.0, "untouched")


func test_the_last_blow_puts_him_down_for_good_and_he_drops_his_weapon() -> void:
	var p = pair()
	var w = StreetWorld.new()
	p[1].health = 1.0
	p[1].weapon = "pipe"
	var events := play(p[0], p[1], [{"punch": true}], 200, null, w)
	eq(events[0]["drop"], "pipe", "knocked down, he drops the pipe")
	eq(w.items.size(), 1, "it lies on the street")
	eq(p[1].weapon, "", "he no longer has it")
	eq(p[1].state, "ko", "the last blow puts him down for good")
	check(p[1].defeated(), "defeated")


func test_the_enemy_walks_up_and_hits_back() -> void:
	var p = pair(600.0)
	var b = Brain.new(p[1], p[0], 3)
	var f := Fight.new()
	var hit_at := -1
	for i in 600:
		p[0].step({})
		p[1].step(b.think())
		for e in f.step([p[0], p[1]]):
			if e["attacker"] == p[1] and hit_at < 0:
				hit_at = i
	check(hit_at > 0, "he came and hit the hero")
	check(hit_at < 300, "within five seconds (tick %d)" % hit_at)
	check(p[0].health < 20.0, "the hero is hurt (%.0f)" % p[0].health)


func test_the_enemy_throws_combos_and_waits_between_attacks() -> void:
	var p = pair(140.0)
	p[0].tune["health"] = 999.0
	p[0].health = 999.0
	var b = Brain.new(p[1], p[0], 5)
	var moves := []
	var starts := []
	for i in 1500:
		p[0].step({})
		var was: String = p[1].state
		p[1].step(b.think())
		if p[1].state != was and p[1].attack_phase() != "":
			moves.append(p[1].state)
			starts.append(i)
	check(moves.size() >= 8, "he keeps attacking (%d blows)" % moves.size())
	check("cross" in moves or "body_kick" in moves or "elbow" in moves, "and chains combos (%s)" % [moves])
	var gaps := 0
	for i in range(1, starts.size()):
		if starts[i] - starts[i - 1] >= 40:
			gaps += 1
	check(gaps >= 3, "with breathing room between attacks, not a nonstop flurry")


func test_the_enemy_sometimes_blocks() -> void:
	var p = pair(110.0)
	p[1].tune["health"] = 999.0
	p[1].health = 999.0
	var b = Brain.new(p[1], p[0], 7)
	var f := Fight.new()
	var results := {}
	for i in 1200:
		p[0].step({"punch": i % 40 == 0})
		p[1].step(b.think())
		for e in f.step([p[0], p[1]]):
			if e["attacker"] == p[0]:
				results[e["result"]] = results.get(e["result"], 0) + 1
	check(results.get("hit", 0) > 0, "some of the hero's jabs land (%s)" % [results])
	check(results.get("perfect", 0) + results.get("blocked", 0) > 0, "and he guards against some (%s)" % [results])


func test_a_fight_replays_the_same() -> void:
	var a := _fight(11)
	var b := _fight(11)
	eq(a, b, "the same seed, the same fight")
	check(a != _fight(12), "another seed, another fight")


func _fight(dice_seed: int) -> Array:
	var p = pair(500.0)
	var foe = Brain.new(p[1], p[0], dice_seed)
	var f := Fight.new()
	var trace := []
	for i in 600:
		p[0].step({"punch": i % 30 == 0, "mx": 1.0 if p[1].x - p[0].x > 120.0 else 0.0})
		p[1].step(foe.think())
		f.step([p[0], p[1]])
		if i % 25 == 0:
			trace.append([p[0].snapshot(), p[1].snapshot(), p[0].health, p[1].health])
	return trace


func test_bodies_dont_walk_through_each_other() -> void:
	var p = pair(200.0)
	for i in 120:
		p[0].step({"mx": 1.0})
		p[1].step({"mx": -1.0})
		Fight.separate([p[0], p[1]])
	check(p[1].x - p[0].x >= Fight.SPACE - 0.01, "walking into each other they stop a body apart (%.0f px)" % (p[1].x - p[0].x))
	check(p[0].x < p[1].x, "and neither passes the other")
	p[1].take_hit({"damage": 1, "effect": "knockdown"}, p[0])
	for i in 30:
		p[1].step({})
	for i in 60:
		p[0].step({"mx": 1.0})
		Fight.separate([p[0], p[1]])
	check(p[0].x > p[1].x, "but he can step over a man lying down")
