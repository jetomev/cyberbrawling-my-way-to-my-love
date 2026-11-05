extends "res://tests/test_case.gd"
## The hard versions (Pippin's roster, level 9: "darker and harder: a shorter glint, a bit more health, and one extra
## trick each"), switched on by "hard": true on an enemy in a layout.

const Level := preload("res://scripts/sim/level.gd")
const Moves := preload("res://scripts/sim/moves.gd")


func street():
	return Level.new(Level.load_data("res://tests/levels/open_street.json"), {}, 1)


## An enemy brought in as a layout would ({kind, hard?}), standing still.
func bring(l, kind: String, hard: bool, x := 500.0) -> Dictionary:
	l._arrive({"kind": kind, "dx": x - l.hero.x, "z": l.hero.z, "hard": hard}, l.hero.x, -1)
	var e: Dictionary = l.enemies[-1]
	e["brain"].wait = 9999
	e["brain"].dormant_until_within = 1.0
	return e


func test_a_bit_more_health_and_a_shorter_glint() -> void:
	var l = street()
	var plain: Dictionary = bring(l, "bruiser", false)
	var hard: Dictionary = bring(l, "bruiser", true, 700.0)
	eq(hard["f"].max_health, plain["f"].max_health * Level.HARD_HEALTH, "a bit more health")
	eq(hard["f"].health, hard["f"].max_health, "(full)")
	var a: int = Moves.data("punch", plain["f"].tune)["startup"]
	var b: int = Moves.data("punch", hard["f"].tune)["startup"]
	eq(b, a - Level.HARD_GLINT, "a shorter glint on his blows (%d frames, not %d)" % [b, a])


func test_the_hard_whistler_calls_three() -> void:
	for hard in [false, true]:
		var l = street()
		bring(l, "lookout", hard)
		for i in 10:
			l.step({})
		var called: int = l.enemies.filter(func(e): return e.get("whistled", false)).size()
		eq(called, 3 if hard else 2, "the %s Whistler's first whistle brings %d" % ["hard" if hard else "plain", called])


func test_the_hard_mechanic_has_a_second_wrench() -> void:
	var l = street()
	var e: Dictionary = bring(l, "wrench_mechanic", true, 800.0)
	var f = e["f"]
	var thrown := 0
	for n in 2:
		f._enter("throw")
		f.t = int(Moves.data("throw", f.tune)["startup"])
		f.hurling = true
		var before: int = l.projectiles.flying.size()
		l._release(f)
		thrown += l.projectiles.flying.size() - before
		if n == 0:
			eq(f.weapon, "wrench", "after his first throw: a second wrench in hand")
	eq(thrown, 2, "two wrenches thrown")
	eq(f.weapon, "", "after the second: empty-handed (only the one spare)")


func test_the_hard_mauler_throws_you_sooner() -> void:
	for hard in [false, true]:
		var l = street()
		var e: Dictionary = bring(l, "grabber", hard, l.hero.x + 60.0)
		l.hug = {"by": e, "at": l.tick}
		l.hero._enter("held")
		var thrown_at := -1
		for i in 120:
			l.step({})
			if l.hero.state != "held" and thrown_at < 0:
				thrown_at = i
		var want: int = Level.HARD_HUG_TICKS if hard else Level.HUG_TICKS
		check(thrown_at >= want - 3 and thrown_at <= want + 3, "%s Mauler: thrown after %d frames (about %d)" % ["hard" if hard else "plain", thrown_at, want])


## Counts how many times the enemy's state enters the move within frames, from a standing start (pushed into it once).
func finishers(l, e: Dictionary, move: String, frames := 120) -> int:
	var f = e["f"]
	f._enter(move)
	f.attack_serial += 1
	var n := 1
	var serial: int = f.attack_serial
	for i in frames:
		l.step({})
		if f.state == move and f.attack_serial != serial:  # (a new blow of it: the second starts as the first ends)
			n += 1
		serial = f.attack_serial
	return n


func test_the_hard_glow_punk_shoves_twice_and_the_hard_enforcer_lunges_twice() -> void:
	for c in [["glow_punk", "push_kick"], ["enforcer", "smash"]]:
		for hard in [false, true]:
			var l = street()
			var e: Dictionary = bring(l, c[0], hard, l.hero.x + 300.0)
			eq(finishers(l, e, c[1]), 2 if hard else 1, "%s %s: its last blow %s" % ["hard" if hard else "plain", c[0], "twice" if hard else "once"])


func test_the_hard_doormans_shield_bounces_you_back() -> void:
	for hard in [false, true]:
		var l = street()
		var e: Dictionary = bring(l, "doorman", hard, l.hero.x + 100.0)
		e["f"].facing = -1
		var bounced := false
		for i in 30:
			l.step({"punch": i == 0})
			bounced = bounced or l.events.any(func(ev): return ev.get("result", "") == "shield_bounce")
		check(bounced == hard, "%s Doorman: a jab off his shield %s" % ["hard" if hard else "plain", "bounces you back" if hard else "just bounces off"])


func test_the_hard_snick_throws_her_knife_when_she_cant_reach_you() -> void:
	for hard in [false, true]:
		var l = street()
		var e: Dictionary = bring(l, "snick", hard, l.hero.x + 600.0)
		e["brain"].dormant_until_within = 0.0
		e["brain"].wait = 0
		var thrown := false
		for i in 200:
			l.hero.x = e["f"].x - 600.0  # (he keeps away)
			l.step({})
			thrown = thrown or l.projectiles.flying.any(func(p): return p["kind"] == "knife")
		check(thrown == hard, "%s Snick, kept out of reach: %s" % ["hard" if hard else "plain", "the knife flies" if hard else "no throw"])


func test_the_hard_dancer_feints_her_skate_in() -> void:
	var l = street()
	var e: Dictionary = bring(l, "neon_dancer", true, l.hero.x + 500.0)
	e["brain"].dormant_until_within = 0.0
	e["brain"].wait = 0
	var feints := 0
	for i in 400:
		l.step({})
		feints += l.events.filter(func(ev): return ev.get("result", "") == "feint").size()
	check(feints >= 1, "she pulls up short before skating in (%d feints)" % feints)


func test_the_hard_bruisers_slam_sends_a_ring_you_jump() -> void:
	for jump in [false, true]:
		var l = street()
		var e: Dictionary = bring(l, "bruiser", true, l.hero.x + 250.0)  # (out of his fist's reach: only the ring)
		var f = e["f"]
		f.facing = -1
		f._enter("power_punch")
		f.attack_serial += 1
		var hit := false
		var rang := false
		for i in 60:
			var r: Array = l.rings
			var near: bool = not r.is_empty() and absf(absf(l.hero.x - r[0]["x"]) - (l.tick - r[0]["at"]) * Level.RING_SPEED) < 110.0
			l.step({"jump": jump and near and l.hero.y < 1.0})
			rang = rang or l.events.any(func(ev): return ev.get("result", "") == "shock_ring")
			hit = hit or l.events.any(func(ev): return ev.get("kind", "") == "shock_ring" and ev.get("result", "") == "hit")
		check(rang, "his slam sends a shock ring along the floor")
		check(hit != jump, "%s: %s" % ["jumped" if jump else "standing", "it passes under him" if jump else "it catches him"])
