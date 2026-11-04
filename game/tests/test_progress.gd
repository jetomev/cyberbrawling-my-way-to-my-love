extends "res://tests/test_case.gd"
## The game's order and the save (D-15): choose a hero, the levels in order, saved at each level's start; a save
## continues where it left off; the last level won ends the game.

const Progress := preload("res://scripts/sim/progress.gd")
const SAVE := "user://test-save.json"


func fresh():
	var p = Progress.new(SAVE)
	p.forget()
	return Progress.new(SAVE)


func test_a_new_game_saves_the_hero_and_level_one() -> void:
	var p = fresh()
	check(not p.has_save(), "no save to begin with")
	p.new_game("woman")
	eq(p.hero, "woman", "the chosen hero")
	eq(p.level_file(), "res://levels/level1.json", "level 1 first")
	var again = Progress.new(SAVE)
	check(again.has_save(), "saved at once")
	eq(again.hero, "woman", "the save remembers the hero")
	eq(again.level, 0, "and the level")
	again.forget()


func test_levels_go_in_order_and_the_last_ends_the_game() -> void:
	var p = fresh()
	p.new_game("man")
	p.levels = ["level1", "level2", "level3"]
	check(not p.level_won(), "level 1 won: on to level 2")
	eq(p.level_file(), "res://levels/level2.json", "level 2")
	eq(int(JSON.parse_string(FileAccess.get_file_as_string(SAVE))["level"]), 1, "saved at level 2's start")
	check(not p.level_won(), "then level 3")
	check(p.level_won(), "the last one won: the game is done")
	p.forget()


func test_every_listed_level_exists() -> void:
	var p = fresh()
	check(p.levels.size() >= 1, "the list has levels")
	for name in p.levels:
		check(FileAccess.file_exists("res://levels/%s.json" % name), "levels/%s.json is there" % name)
