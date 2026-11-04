extends "res://tests/test_case.gd"
## The fight's sounds are asked for at the right moments (present/sound.gd); with no sound files yet they're silent,
## and the game runs either way.

const Sound := preload("res://scripts/present/sound.gd")
const Fighter := preload("res://scripts/sim/fighter.gd")
const Fight := preload("res://scripts/sim/fight.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")


func test_the_fights_moments_ask_for_their_sounds() -> void:
	var s = Sound.new()
	var hero = Fighter.new(Tuning.fresh(), 400.0, 80.0)
	var foe = Fighter.new(Tuning.fresh(), 500.0, 80.0)
	foe.team = 1
	foe.facing = -1
	foe.health = 99.0
	foe.pain["leg_f"] = 8.5
	var fight := Fight.new()
	hero.step({"punch": true})
	s.fight_tick([hero, foe], [])
	check("punch_whoosh" in s.played, "a jab thrown: its whoosh (%s)" % [s.played])
	var events := []
	for i in 10:
		hero.step({})
		foe.step({})
		events.append_array(fight.step([hero, foe]))
	s.fight_tick([hero, foe], events)
	check("hit_light" in s.played, "the jab lands: a light hit (%s)" % [s.played])
	s.played.clear()
	for i in 40:
		hero.step({})  # past the combo window, so the kick is the low kick, not the jab's knee
	foe.x = hero.x + 100.0  # (the jab drove him back)
	foe._enter("idle")
	for i in 40:
		hero.step({"kick": i == 0})
		foe.step({})
		s.fight_tick([hero, foe], fight.step([hero, foe]))
	check("kick_whoosh" in s.played, "a low kick: its whoosh")
	check("crack" in s.played, "it breaks the bruised leg: the crack (%s)" % [s.played])
	s.free()


func test_silent_without_files() -> void:
	var s = Sound.new()
	s.play("hit_heavy")
	check(s.takes.is_empty() or s.takes.has("hit_heavy"), "a sound not there yet is simply silent")
	s.free()
