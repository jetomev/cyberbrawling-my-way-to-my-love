extends CanvasLayer
## The feel lab on screen (L-1): F1 shows or hides it; the other F-keys change the feel while you play.
## Changes are saved with F8 to user://feel-lab.json and loaded again at the next start.

const FeelLab := preload("res://scripts/sim/feel_lab.gd")

const SAVE_PATH := "user://feel-lab.json"
const FONT_SIZE := 22
const HELP := "F1 hide    F2 / F3 pick a setting    F4 / F5 less / more\nF6 reset this    F7 reset all    F8 save    F9 slow motion"

var lab
var save_path := SAVE_PATH
var label: Label
var bg: ColorRect
var note := ""


func _init(tune: Dictionary, path := SAVE_PATH) -> void:
	save_path = path
	layer = 10
	lab = FeelLab.new(tune)
	bg = ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05, 0.82)
	bg.position = Vector2(1100, 90)
	bg.size = Vector2(710, 620)
	add_child(bg)
	label = Label.new()
	label.position = Vector2(1120, 104)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color(0.86, 0.88, 0.94))
	add_child(label)
	visible = false
	var n := load_saved()
	if n > 0:
		note = "Loaded %d saved change(s) from the last session." % n
	refresh()


func load_saved() -> int:
	if not FileAccess.file_exists(save_path):
		return 0
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	return lab.load_changes(data) if data is Dictionary else 0


func save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		note = "Could not save (%s)." % error_string(FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(lab.changes(), "  ", true))
	note = "Saved %d change(s) to %s in the game's user folder." % [lab.changes().size(), save_path.get_file()]
	print("feel lab saved to %s: %s" % [ProjectSettings.globalize_path(save_path), JSON.stringify(lab.changes())])


func refresh() -> void:
	label.text = "THE FEEL LAB\n\n%s\n\n%s%s" % ["\n".join(lab.lines()), HELP, "\n\n" + note if note != "" else ""]
	bg.size = text_size() + Vector2(40, 28)  # the box always fits its text


## The text's size measured with the font itself: a Label outside the scene tree reports too small a size.
func text_size() -> Vector2:
	var font := ThemeDB.fallback_font
	var width := 0.0
	var lines := label.text.split("\n")
	for line in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	# a Label puts its theme's line_spacing between lines, blank lines included
	var gap := float(ThemeDB.get_default_theme().get_constant("line_spacing", "Label"))
	return Vector2(width, lines.size() * (font.get_height(FONT_SIZE) + gap))


## Returns true when the key was the feel lab's.
func handle(key: Key) -> bool:
	match key:
		KEY_F1: visible = not visible
		KEY_F2: lab.select(-1)
		KEY_F3: lab.select(1)
		KEY_F4: lab.nudge(-1)
		KEY_F5: lab.nudge(1)
		KEY_F6: lab.reset_current()
		KEY_F7: lab.reset_all()
		KEY_F8: save()
		KEY_F9:
			Engine.time_scale = 1.0 if Engine.time_scale < 1.0 else 0.25
			note = "Slow motion %s." % ("on (1/4 speed)" if Engine.time_scale < 1.0 else "off")
		_: return false
	if key != KEY_F1:
		visible = true  # any lab key shows what it changed
	refresh()
	return true
