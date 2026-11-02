extends Node2D
## The grey-box street with the hero on it (Stage 1). Steps the hero's logic 60 times a second and draws it.
## Options after "--": --demo plays the scripted demo (scripts/sim/demo.gd) and quits when it ends (--lab shows the
## feel lab during it);
## --flat uses the flat line instead of the shallow street (D-13). F1 opens the feel lab (feel_panel.gd).

const Version := preload("res://scripts/sim/version.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")
const Fighter := preload("res://scripts/sim/fighter.gd")
const Demo := preload("res://scripts/sim/demo.gd")
const Controls := preload("res://scripts/present/controls.gd")
const HeroView := preload("res://scripts/present/hero_view.gd")
const Street := preload("res://scripts/present/street.gd")
const FeelPanel := preload("res://scripts/present/feel_panel.gd")

var tune := Tuning.fresh()
var hero
var hero_view
var tick := 0
var demo := false
var feel


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	demo = "--demo" in args
	tune["flat_line"] = "--flat" in args
	Controls.ensure()
	if not demo or "--lab" in args:
		# a saved feel must not change what the demo shows, so the demo's lab starts from the defaults
		feel = FeelPanel.new(tune, "user://demo-feel-lab.json" if demo else FeelPanel.SAVE_PATH)
		feel.name = "FeelLab"
		feel.visible = demo
		add_child(feel)
		if "--flat" in args:
			tune["flat_line"] = true  # asked for on the command line: beats a saved setting
	hero = Fighter.new(tune, 400.0, 80.0)
	hero_view = HeroView.new()
	hero_view.name = "Hero"
	add_child(hero_view)
	$Street.setup(tune["street_right"], tune["street_depth"])
	$Camera.limit_left = int(tune["street_left"])
	$Camera.limit_right = int(tune["street_right"])
	$Hud/Title.text = "%s   ·   %s%s" % [Version.TITLE, Version.STAGE, "   ·   demo" if demo else ""]
	hero_view.sync(hero, Street.GROUND_Y)


func _physics_process(_delta: float) -> void:
	var inp: Dictionary = Demo.input_at(tick) if demo else Controls.read()
	hero.step(inp)
	tick += 1
	hero_view.sync(hero, Street.GROUND_Y)
	$Camera.position.x = lerpf($Camera.position.x, hero.x + hero.facing * 160.0, 0.08)
	$Camera.zoom = Vector2.ONE * tune["camera_zoom"]
	if demo and tick > Demo.length():
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if feel != null and event is InputEventKey and event.pressed and not event.echo:
		if feel.handle(event.keycode):
			get_viewport().set_input_as_handled()
