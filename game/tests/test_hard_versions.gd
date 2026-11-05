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
