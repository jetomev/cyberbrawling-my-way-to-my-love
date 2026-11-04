extends "res://tests/test_case.gd"
## Weapons in the hand (Stage 1): each weapon feels different, walking over one picks it up, holding one the punch
## button swings it (swing, backswing, overhead smash), it wears out after its hits, a broken arm can't swing it, and
## an enemy carrying one swings it too.

const Fighter := preload("res://scripts/sim/fighter.gd")
const Fight := preload("res://scripts/sim/fight.gd")
const Weapons := preload("res://scripts/sim/weapons.gd")
const Moves := preload("res://scripts/sim/moves.gd")
const StreetWorld := preload("res://scripts/sim/street_world.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")


func armed(kind := "pipe"):
	var f = Fighter.new(Tuning.fresh(), 400.0, 80.0)
	f.take_weapon(kind)
	return f


func test_each_weapon_feels_different() -> void:
	for kind in Weapons.TABLE:
		var w: Dictionary = Weapons.TABLE[kind]
		for k in ["damage", "reach", "speed", "hits", "smash"]:
			check(w.has(k), "%s has its %s" % [kind, k])
	var knife := Weapons.swing_data("swing", "knife")
	for kind in Weapons.TABLE:
		if kind != "knife":
			var d := Weapons.swing_data("swing", kind)
			check(knife["startup"] < d["startup"], "the knife comes out faster than the %s" % kind)
			check(knife["reach"] < d["reach"] or kind == "wrench" or kind == "knife", "and is shorter than the %s" % kind)
	var sword := Weapons.swing_data("swing", "sword")
	for kind in Weapons.TABLE:
		check(sword["reach"] >= Weapons.swing_data("swing", kind)["reach"], "the sword reaches furthest (vs %s)" % kind)
	eq(Weapons.swing_data("smash", "bat")["effect"], "push", "the bat's smash sends him flying back")
	check(Weapons.swing_data("swing", "pipe")["damage"] > Weapons.swing_data("swing", "knife")["damage"], "the pipe hits heavier than the knife")


func test_walking_over_a_weapon_picks_it_up() -> void:
	var w = StreetWorld.new()
	w.drop("bat", 500.0, 80.0)
	var f = Fighter.new(Tuning.fresh(), 400.0, 80.0, w)
	for i in 40:
		f.step({"mx": 1.0})
	eq(f.weapon, "bat", "walking over the bat, he picks it up")
	eq(w.items.size(), 0, "it's gone from the street")
	w.drop("knife", f.x + 30.0, 80.0)
	for i in 20:
		f.step({"mx": 1.0})
	eq(f.weapon, "bat", "his hand is full: the knife stays where it lies")
	eq(w.items.size(), 1, "on the street")


func test_holding_one_the_punch_button_swings_it() -> void:
	var f = armed("pipe")
	var seen := []
	for i in 120:
		f.step({"punch": i % 16 == 0 and i < 48})
		if seen.is_empty() or seen[-1] != f.state:
			seen.append(f.state)
	for m in ["swing", "backswing", "smash"]:
		check(m in seen, "three presses: %s (saw %s)" % [m, seen])
	check(not "punch" in seen, "no fists while holding the pipe")
	var g = armed("pipe")
	g.step({"punch": true})
	for i in 10:
		g.step({})
	eq(g.move()["reach"], Weapons.TABLE["pipe"]["reach"], "the swing reaches as far as the pipe does")


func test_the_smash_is_a_finisher() -> void:
	check(Moves.is_finisher("smash"), "the overhead smash ends a chain (two in a row: dizzy)")
	check(not Moves.is_finisher("swing"), "the swing doesn't")


func test_a_weapon_wears_out() -> void:
	var f = armed("stick")
	var target = Fighter.new(Tuning.fresh(), 520.0, 80.0)
	target.team = 1
	target.health = 999.0
	var fight := Fight.new()
	var worn := ""
	for i in 1200:
		f.step({"punch": i % 30 == 0})
		target.step({})
		if target.state in ["down", "knockdown"]:
			target.health = 999.0
		for e in fight.step([f, target]):
			if e["worn"] != "":
				worn = e["worn"]
		target.x = 520.0
		target.state = "idle" if target.state in ["down", "get_up", "knockdown"] else target.state
		if f.weapon == "":
			break
	eq(worn, "stick", "after its hits the stick breaks, and the fight says so")
	eq(f.weapon, "", "his hand is empty")


func test_a_broken_arm_cant_swing_it() -> void:
	var f = armed("pipe")
	f.pain["arm_f"] = 99.0
	f.step({"punch": true})
	eq(f.state, "punch", "with his lead arm broken, the press throws a jab, not the pipe")


func test_knocked_down_he_drops_it_and_is_back_to_fists() -> void:
	var w = StreetWorld.new()
	var f = Fighter.new(Tuning.fresh(), 400.0, 80.0, w)
	f.take_weapon("sword")
	var hero = Fighter.new(Tuning.fresh(), 300.0, 80.0, w)
	f.team = 1
	f.health = 1.0
	var fight := Fight.new()
	hero.step({"punch": true})
	for i in 30:
		hero.step({})
		f.step({})
		fight.step([hero, f], w)
	eq(f.weapon, "", "knocked out, the sword drops")
	eq(w.items[0]["kind"], "sword", "onto the street")
	w.items.clear()  # (lying on it, he'd pick it straight back up)
	f.health = 20.0
	f._enter("idle")
	f.step({"punch": true})
	eq(f.state, "punch", "and his punch is a fist again")


func test_an_enemy_swings_his_pipe() -> void:
	var f = armed("pipe")
	f.team = 1
	f.step({"punch": true})
	eq(f.state, "swing", "a thug with a pipe swings it")
