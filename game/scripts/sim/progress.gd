extends RefCounted
## Where the player is in the game, and the save (D-15: the game saves at the start of every level; three lives per
## level, losing them restarts that level). The story's order: choose your hero (a man or a woman; DESIGN, The story),
## then the levels in order (levels/levels.json lists them), each started fresh-bodied (pain heals between levels).
## A save is a small JSON file: {hero, level}; nothing else is kept between sessions. Plain logic: the title screen
## and main.gd ask it what comes next.

const LIST := "res://levels/levels.json"
const SAVE := "user://save.json"
const HEROES := ["man", "woman"]

var hero := ""  # "man" or "woman", once chosen
var level := 0  # index into the level list
var levels: Array = []  # the level files, in order
var path := SAVE


func _init(save_path := SAVE, list_path := LIST) -> void:
	path = save_path
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(list_path))
	levels = parsed.get("levels", []) if parsed is Dictionary else []
	load_save()


## A saved game to continue?
func has_save() -> bool:
	return hero != ""


func load_save() -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and parsed.get("hero", "") in HEROES:
		hero = parsed["hero"]
		level = clampi(int(parsed.get("level", 0)), 0, maxi(0, levels.size() - 1))


## Saved at the start of every level (D-15).
func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"hero": hero, "level": level}))


## A new game: the chosen hero, from level 1, saved at once.
func new_game(chosen: String) -> void:
	hero = chosen if chosen in HEROES else HEROES[0]
	level = 0
	save()


## The level file to play now.
func level_file() -> String:
	return "res://levels/%s.json" % levels[level] if level < levels.size() else ""


## A level won: on to the next (saved at its start); true when that was the last one (the game is done).
func level_won() -> bool:
	level += 1
	if level >= levels.size():
		level = levels.size() - 1
		return true
	save()
	return false


func forget() -> void:
	hero = ""
	level = 0
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path) if path.begins_with("user://") else path)
