extends "res://tests/test_case.gd"
## The feel lab: every setting is a real number in the tuning table with sane limits, a change is felt at once by the
## fighter, values stay inside their limits and keep their type, and a saved set comes back exactly.

const FeelLab := preload("res://scripts/sim/feel_lab.gd")
const FeelPanel := preload("res://scripts/present/feel_panel.gd")
const Fighter := preload("res://scripts/sim/fighter.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")

const TEST_SAVE := "user://test-feel-lab.json"


func lab_on(key: String):
	var lab = FeelLab.new(Tuning.fresh())
	while lab.current()[0] != key:
		lab.select(1)
	return lab


func test_every_setting_is_a_real_tuning_number() -> void:
	for s in FeelLab.SETTINGS:
		check(Tuning.DEFAULTS.has(s[0]), "%s is in the tuning table" % s[0])
		var d = Tuning.DEFAULTS[s[0]]
		check(typeof(d) == typeof(s[2]), "%s: its step has the default's type" % s[0])
		if not d is bool:
			check(d >= s[3] and d <= s[4], "%s: the default %s sits inside %s..%s" % [s[0], d, s[3], s[4]])


func test_a_change_is_felt_at_once() -> void:
	var tune := Tuning.fresh()
	var f = Fighter.new(tune)
	var lab = FeelLab.new(tune)
	while lab.current()[0] != "walk_speed":
		lab.select(1)
	for i in 4:
		lab.nudge(1)
	eq(tune["walk_speed"], 5.0, "four steps up from 4.0")
	var x0: float = f.x
	f.step({"mx": 1.0})
	check(is_equal_approx(f.x - x0, 5.0), "the fighter walks at the new speed on the next tick")


func test_limits_and_types_hold() -> void:
	var lab = lab_on("punch_startup")
	for i in 50:
		lab.nudge(-1)
	eq(lab.tune["punch_startup"], 1, "start-up never goes under 1 tick")
	check(lab.tune["punch_startup"] is int, "tick settings stay whole numbers")
	lab = lab_on("air_steer")
	for i in 50:
		lab.nudge(1)
	eq(lab.tune["air_steer"], 1.0, "air steering tops out at 1")
	lab = lab_on("flat_line")
	lab.nudge(1)
	eq(lab.tune["flat_line"], true, "the flat line switches on")
	lab.nudge(-1)
	eq(lab.tune["flat_line"], false, "and off")


func test_picking_wraps_around() -> void:
	var lab = FeelLab.new(Tuning.fresh())
	lab.select(-1)
	eq(lab.index, FeelLab.SETTINGS.size() - 1, "back from the first goes to the last")
	lab.select(1)
	eq(lab.index, 0, "on from the last goes to the first")


func test_reset() -> void:
	var lab = lab_on("jump_height")
	lab.nudge(1)
	lab.select(1)
	lab.nudge(1)
	check(lab.changes().size() == 2, "two changes made")
	lab.reset_current()
	eq(lab.changes().size(), 1, "reset this undoes one")
	lab.reset_all()
	eq(lab.changes().size(), 0, "reset all undoes everything")


func test_save_and_load_round_trip() -> void:
	var lab = lab_on("kick_recovery")
	lab.nudge(1)
	lab = lab_on("camera_zoom")
	lab.nudge(1)
	lab.select(1)  # flat_line
	lab.nudge(1)
	var text := JSON.stringify(lab.changes())
	var back = FeelLab.new(Tuning.fresh())
	eq(back.load_changes(JSON.parse_string(text)), 2, "both saved changes load")  # one lab per change above
	eq(back.tune["flat_line"], true, "a switch comes back")
	check(is_equal_approx(back.tune["camera_zoom"], 1.05), "a decimal comes back")
	var other = FeelLab.new(Tuning.fresh())
	other.load_changes({"kick_recovery": 13.0})
	check(other.tune["kick_recovery"] is int and other.tune["kick_recovery"] == 13, "a tick count read as 13.0 comes back as 13")


func test_a_bad_save_cannot_break_the_feel() -> void:
	var lab = FeelLab.new(Tuning.fresh())
	var n: int = lab.load_changes({"walk_speed": 999.0, "jump_height": "high", "no_such_setting": 3, "flat_line": 1})
	eq(n, 1, "only the usable value applies")
	eq(lab.tune["walk_speed"], 12.0, "an out-of-range value is held to its limit")
	eq(lab.tune["jump_height"], Tuning.DEFAULTS["jump_height"], "a word where a number belongs is ignored")
	check(not lab.tune.has("no_such_setting"), "unknown names are ignored")
	eq(lab.tune["flat_line"], false, "a number where a switch belongs is ignored")


func test_panel_keys_and_saved_file() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var tune := Tuning.fresh()
	var panel = FeelPanel.new(tune, TEST_SAVE)
	check(not panel.visible, "hidden until F1")
	check(panel.handle(KEY_F1) and panel.visible, "F1 shows it")
	check(not panel.handle(KEY_A), "other keys are left for the game")
	panel.handle(KEY_F5)
	eq(tune["walk_speed"], 4.25, "F5 raises the picked setting in the live table")
	panel.handle(KEY_F8)
	check(FileAccess.file_exists(TEST_SAVE), "F8 writes the save file")
	var box: Rect2 = Rect2(panel.bg.position, panel.bg.size)
	check(box.end.x <= 1920.0 and box.end.y <= 1080.0, "the box fits on the screen (%s)" % box)
	# measured independently: every line of text needs at least one line height of the font
	var lines: int = panel.label.text.count("\n") + 1
	var need: float = lines * ThemeDB.fallback_font.get_height(FeelPanel.FONT_SIZE)
	check(panel.bg.size.y >= need, "the box (%.0f px) is tall enough for %d lines (%.0f px)" % [panel.bg.size.y, lines, need])
	panel.free()
	var tune2 := Tuning.fresh()
	var again = FeelPanel.new(tune2, TEST_SAVE)
	eq(tune2["walk_speed"], 4.25, "the next start loads it")
	check(again.note.begins_with("Loaded 1"), "and says so")
	again.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	check(not FileAccess.file_exists(TEST_SAVE), "the test leaves no file behind")
	Engine.time_scale = 1.0
