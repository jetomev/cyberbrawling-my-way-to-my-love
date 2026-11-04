extends "res://tests/test_case.gd"
## The testers' controlled trials (present/trials.gd) do what they show: each one's thing happens on its cue. And the
## combo window's edge, exactly: the setting is the last frame a press still continues the chain.

const Fighter := preload("res://scripts/sim/fighter.gd")
const Fight := preload("res://scripts/sim/fight.gd")
const Trials := preload("res://scripts/present/trials.gd")
const StreetWorld := preload("res://scripts/sim/street_world.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")


## Plays a trial bare (no drawing): returns the trial, after every frame of it.
func run(trial: String):
	var w = StreetWorld.new()
	var hero = Fighter.new(Tuning.fresh(), 600.0, 80.0, w)
	var dummy = Fighter.new(Tuning.fresh(), 700.0, 80.0, w)
	dummy.team = 1
	dummy.facing = -1
	var tr = Trials.new(trial, hero, dummy)
	var fight := Fight.new()
	var moves := []
	for i in tr.length:
		var inp: Array = tr.inputs()
		hero.step(inp[0])
		dummy.step(inp[1])
		Fight.separate([hero, dummy])
		tr.saw(fight.step([hero, dummy], w))
		tr.overlay()
		if hero.attack_phase() == "startup" and hero.t == 0:
			moves.append(hero.state)
	tr.data["moves"] = moves
	return tr


func test_the_combo_window_edge_is_the_setting() -> void:
	var window: int = Tuning.fresh()["combo_window_ticks"]
	for wait in [window - 1, window, window + 1]:
		var f = Fighter.new()
		f.step({"punch": true})
		var n: int = f.attack_length("punch")
		for i in n - 1:
			f.step({})
		eq(f.state, "punch", "the jab's last frame")
		f.step({})
		eq(f.state, "idle", "the jab has ended")
		for i in wait - 1:
			f.step({})
		f.step({"punch": true})
		eq(f.state, "cross" if wait <= window else "punch", "a press %d frames after the jab ends: %s" % [wait, "the cross" if wait <= window else "a new jab"])


func test_trial_combo_edge() -> void:
	var tr = run("combo_edge")
	eq(tr.data["moves"], ["punch", "cross", "punch", "cross", "punch", "punch"], "23 and 24 frames go on to the cross; 25 starts again")


func test_trial_injuries() -> void:
	var tr = run("injuries")
	check(tr.dummy.broken("leg_f"), "six low kicks break his lead leg (%.0f points)" % tr.dummy.pain["leg_f"])
	check(tr.history.any(func(l): return l.contains("leg_f BROKEN")), "and the trial says so on screen")
	var speed: float = absf(tr.dummy.x - tr.data["walk_from"]) / float(tr.length - 331)
	check(absf(speed - tr.dummy.tune["walk_speed"] * tr.dummy.tune["limp"]) < 0.2, "then he limps at 60%% (%.2f px a frame)" % speed)


func test_trial_weapon_wear() -> void:
	var tr = run("weapon_wear")
	eq(tr.hero.weapon, "", "the stick is gone")
	check(tr.history.any(func(l): return l.contains("stick BREAKS")), "it broke from wear, on screen: %s" % [tr.history.slice(-3)])


func test_trial_disarm() -> void:
	var tr = run("disarm")
	var h: Array = tr.history
	check(h.any(func(l): return l.contains("PERFECT BLOCK") and l.contains("pipe leaves his hand")), "the perfect block knocks the pipe loose: %s" % [h])
	check(h.any(func(l): return l.contains("in HIS hand now")), "and the hero walks over it and picks it up: %s" % [h])
	eq(tr.hero.weapon, "pipe", "the hero ends holding it")


func test_trial_counter() -> void:
	var tr = run("counter")
	check(tr.history.any(func(l): return l.contains("COUNTER") and l.contains("pipe leaves his hand")), "the jab into his kick's wind-up knocks the pipe loose: %s" % [tr.history])


func test_trial_broken_arm() -> void:
	var tr = run("broken_arm")
	check(tr.history.any(func(l): return l.contains("HIT: punch, damage 0.5") and l.contains("whole: 1")), "the jab lands at half: %s" % [tr.history])
	check(tr.history.any(func(l): return l.contains("a JAB, not a swing")), "with the pipe, A still throws a jab: %s" % [tr.history])


func test_trial_weapons() -> void:
	var tr = run("weapons")
	for kind in tr.WEAPON_ROUND:
		check(tr.history.any(func(l): return l.contains("the %s BREAKS" % kind)), "the %s wears out and breaks" % kind)


func test_trial_dizzy() -> void:
	var tr = run("dizzy")
	check(tr.history.any(func(l): return l.contains("power_punch")), "the power punch lands: %s" % [tr.history])
	var w = StreetWorld.new()
	var hero = Fighter.new(Tuning.fresh(), 600.0, 80.0, w)
	var dummy = Fighter.new(Tuning.fresh(), 700.0, 80.0, w)
	dummy.team = 1
	dummy.facing = -1
	var t2 = Trials.new("dizzy", hero, dummy)
	var fight := Fight.new()
	var dazed := false
	for i in t2.length:
		var inp: Array = t2.inputs()
		hero.step(inp[0])
		dummy.step(inp[1])
		Fight.separate([hero, dummy])
		fight.step([hero, dummy], w)
		dazed = dazed or dummy.state == "dizzy"
	check(dazed, "two combos in a row leave him dazed")
	check(tr.history.any(func(l): return l.contains("finishing chain")), "the third combo lands while he's dazed: %s" % [tr.history.slice(-4)])


func test_trial_records() -> void:
	var tr = run("records")
	var h: Array = tr.history
	check(h.any(func(l): return l.contains("stepped out of its line")), "the first is dodged by stepping up the street: %s" % [h])
	check(h.any(func(l): return l.contains("he jumped it")), "the low one is jumped: %s" % [h])
	check(h.any(func(l): return l.contains("PERFECT")), "the last is perfect-blocked: %s" % [h])
	check(h.any(func(l): return l.contains("his own record hits him")), "and it hits the DJ: %s" % [h])


func test_trial_bass_drop() -> void:
	var tr = run("bass_drop")
	eq(tr.data.get("waves", 0), 1, "one wave: while the speakers stood; none once they were smashed")
