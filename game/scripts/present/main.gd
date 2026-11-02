extends Node2D
## The grey-box street with the hero on it (Stage 1). Steps the hero's logic 60 times a second and draws it.
## Options after "--": --demo plays the scripted demo (scripts/sim/demo.gd) and quits when it ends (--lab shows the
## feel lab during it);
## --flat uses the flat line instead of the shallow street (D-13); --marks <file> (with --demo) writes, for every drawn
## frame, where the hips, hands and feet are on screen, for the reviewers' close-ups (scripts/build.sh, D-22).
## F1 opens the feel lab (feel_panel.gd).

const Version := preload("res://scripts/sim/version.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")
const Fighter := preload("res://scripts/sim/fighter.gd")
const Demo := preload("res://scripts/sim/demo.gd")
const Controls := preload("res://scripts/present/controls.gd")
const HeroView := preload("res://scripts/present/hero_view.gd")
const Street := preload("res://scripts/present/street.gd")
const FeelPanel := preload("res://scripts/present/feel_panel.gd")
const StreetWorld := preload("res://scripts/sim/street_world.gd")
const ObstaclesView := preload("res://scripts/present/obstacles_view.gd")

var tune := Tuning.fresh()
var world
var obstacles_view
var hero
var hero_view
var tick := 0
var demo := false
var feel
var marks: FileAccess
var frame := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	demo = "--demo" in args
	tune["flat_line"] = "--flat" in args
	Controls.ensure()
	_ready_pads()
	if not demo or "--lab" in args:
		# a saved feel must not change what the demo shows, so the demo's lab starts from the defaults
		feel = FeelPanel.new(tune, "user://demo-feel-lab.json" if demo else FeelPanel.SAVE_PATH)
		feel.name = "FeelLab"
		feel.visible = demo
		add_child(feel)
		if "--flat" in args:
			tune["flat_line"] = true  # asked for on the command line: beats a saved setting
	world = StreetWorld.grey_street()
	obstacles_view = ObstaclesView.new()
	obstacles_view.name = "Obstacles"
	add_child(obstacles_view)
	obstacles_view.setup(world, Street.GROUND_Y)
	hero = Fighter.new(tune, 400.0, 80.0, world)
	hero_view = HeroView.new()
	hero_view.name = "Hero"
	add_child(hero_view)
	$Street.setup(tune["street_right"], tune["street_depth"])
	$Camera.limit_left = int(tune["street_left"])
	$Camera.limit_right = int(tune["street_right"])
	$Hud/Title.text = "%s   ·   %s%s" % [Version.TITLE, Version.STAGE, "   ·   demo" if demo else ""]
	hero_view.sync(hero, Street.GROUND_Y)
	var at := args.find("--marks")
	if demo and at >= 0 and at + 1 < args.size():
		marks = FileAccess.open(args[at + 1], FileAccess.WRITE)
		marks.store_line("# frame tick then x y in the 1920x1080 game for: hip hand_f hand_b foot_f foot_b head(top)")
		RenderingServer.frame_pre_draw.connect(_mark)


func _physics_process(_delta: float) -> void:
	var inp: Dictionary = Demo.input_at(tick) if demo else Controls.read()
	hero.step(inp)
	tick += 1
	var crate_was: Array = world.objects.map(func(o): return o["strength"])
	world.step_hits([hero])
	if world.objects.map(func(o): return o["strength"]) != crate_was:
		obstacles_view.refresh()
	hero_view.sync(hero, Street.GROUND_Y)
	hero_view.z_index = world.draw_order(hero)
	$Camera.position.x = lerpf($Camera.position.x, hero.x + hero.facing * 160.0, 0.08)
	$Camera.zoom = Vector2.ONE * tune["camera_zoom"]
	if demo and tick > Demo.length():
		get_tree().quit()


## One line per drawn frame (the movie's frame number), in the 1920x1080 game's pixels (the movie can be smaller: the
## build scales them), written after the camera has moved, just before drawing.
func _mark() -> void:
	var to_screen: Transform2D = hero_view.get_global_transform_with_canvas()
	var line := "%d %d" % [frame, tick]
	for p in hero_view.points().values():
		var s: Vector2 = to_screen * p
		line += " %d %d" % [roundi(s.x), roundi(s.y)]
	marks.store_line(line)
	marks.flush()
	frame += 1


func _ready_pads() -> void:
	Input.joy_connection_changed.connect(func(device: int, _connected: bool): Controls.guard.forget(device))


func _input(event: InputEvent) -> void:
	Controls.feed(event)


func _unhandled_input(event: InputEvent) -> void:
	if feel != null and event is InputEventKey and event.pressed and not event.echo:
		if feel.handle(event.keycode):
			get_viewport().set_input_as_handled()
