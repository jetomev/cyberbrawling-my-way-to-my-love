extends Node2D
## The grey-box street with the hero on it (Stage 1). Steps the hero's logic 60 times a second and draws it.
## Options after "--": --demo plays the scripted demo (scripts/sim/demo.gd) and quits when it ends;
## --flat uses the flat line instead of the shallow street (D-13).

const Version := preload("res://scripts/sim/version.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")
const Fighter := preload("res://scripts/sim/fighter.gd")
const Demo := preload("res://scripts/sim/demo.gd")
const Controls := preload("res://scripts/present/controls.gd")
const HeroView := preload("res://scripts/present/hero_view.gd")
const Street := preload("res://scripts/present/street.gd")

var tune := Tuning.fresh()
var hero
var hero_view
var tick := 0
var demo := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	demo = "--demo" in args
	tune["flat_line"] = "--flat" in args
	Controls.ensure()
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
	if demo and tick > Demo.length():
		get_tree().quit()
