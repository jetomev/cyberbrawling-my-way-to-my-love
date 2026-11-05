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
var cat := false  # level 1's stray cat, fed: it comes along
var levels: Array = []  # the level files, in order
var path := SAVE
const MODES := ["normal", "harder", "rush"]  # the normal game, the harder mode, the boss rush (the team's agreed list)
var mode := "normal"
var helper := false  # the helper's switch (off at the start)
var total := 0  # the run's score so far, the levels won
var marked := false  # a life bought with the helper this run: its best score carries a mark
## Kept apart from the save, for good (a finished game forgets its save, not these): the three letters a first no-hit
## level puts up in neon, and the best score of each mode ({score, mark}).
var name := ""
var best := {}
var records_path := ""


func _init(save_path := SAVE, list_path := LIST) -> void:
	path = save_path
	records_path = save_path.get_basename() + "-records.json"  # (beside its save: a test's never touches the real one)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(list_path))
	levels = parsed.get("levels", []) if parsed is Dictionary else []
	load_save()


## A saved game to continue?
func has_save() -> bool:
	return hero != ""


func load_save() -> void:
	if FileAccess.file_exists(records_path):
		var rec = JSON.parse_string(FileAccess.get_file_as_string(records_path))
		if rec is Dictionary:
			name = str(rec.get("name", ""))
			best = rec.get("best", {}) if rec.get("best", {}) is Dictionary else {}
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and parsed.get("hero", "") in HEROES:
		hero = parsed["hero"]
		level = clampi(int(parsed.get("level", 0)), 0, maxi(0, levels.size() - 1))
		cat = parsed.get("cat", false)
		mode = parsed.get("mode", "normal") if parsed.get("mode", "normal") in MODES else "normal"
		helper = parsed.get("helper", false)
		total = int(parsed.get("total", 0))
		marked = parsed.get("marked", false)


## Saved at the start of every level (D-15).
func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"hero": hero, "level": level, "cat": cat, "mode": mode, "helper": helper,
			"total": total, "marked": marked}))


## A new game: the chosen hero, from level 1, saved at once (the mode and the helper's switch as chosen).
func new_game(chosen: String, chosen_mode := "normal", with_helper := false) -> void:
	hero = chosen if chosen in HEROES else HEROES[0]
	level = 0
	cat = false
	mode = chosen_mode if chosen_mode in MODES else "normal"
	helper = with_helper
	total = 0
	marked = false
	save()


## A level (or a boss rush fight) won: its score onto the run's total, the helper's mark if a life was bought; the
## mode's best score raised if the run's total beats it.
func add_score(points: int, used_helper: bool) -> void:
	total += points
	marked = marked or used_helper
	var b: Dictionary = best.get(mode, {})
	if total > int(b.get("score", 0)):
		best[mode] = {"score": total, "mark": marked}
		save_records()
	save()


## The three letters for the neon sign (the first no-hit level), kept for good.
func set_name(letters: String) -> void:
	name = letters.to_upper().left(3)
	save_records()


func save_records() -> void:
	var f := FileAccess.open(records_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"name": name, "best": best}))


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
