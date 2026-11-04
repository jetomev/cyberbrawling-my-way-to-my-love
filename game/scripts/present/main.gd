extends Node2D
## The grey-box street with the hero on it (Stage 1). Steps the hero's logic 60 times a second and draws it.
## Options after "--": --demo plays the scripted demo (scripts/sim/demo.gd) and quits when it ends (--lab shows the
## feel lab during it);
## --fight has a bot (hero_bot.gd) play the hero against the thugs for FIGHT_TICKS and quits (the build's fight clip);
## --flat uses the flat line instead of the shallow street (D-13); --marks <file> (with --demo) writes, for every drawn
## frame, where the hips, hands and feet are on screen, for the reviewers' close-ups (scripts/build.sh, D-22).
## F1 opens the feel lab (feel_panel.gd).
## Outside the demo a thug walks up and fights back (Stage 1; brain.gd, fight.gd): put him down and another comes;
## put down yourself, you get up again (lives and saves come with the levels, D-15).

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
const Fight := preload("res://scripts/sim/fight.gd")
const Brain := preload("res://scripts/sim/brain.gd")
const HeroBot := preload("res://scripts/sim/hero_bot.gd")
const FIGHT_TICKS := 1500  # --fight: how long the recorded bot fight runs (25 s)

const ENEMY_TINT := Color(1.35, 0.78, 0.72)  # the thug, reddish, so he never reads as the hero
const ENEMY_HEALTH := 12.0
const RESPAWN_TICKS := 180

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
var fight := Fight.new()
var enemies := []  # each {f: fighter, brain, view, down_for: ticks since put down for good}
var spawned := 0
var hero_down_for := 0
var bars := {}  # "hero"/"enemy" -> [back, fill] ColorRects
var bot = null  # --fight: a bot plays the hero against the thugs (for the build's fight clip)


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
	_make_bars()
	if "--fight" in args:
		bot = HeroBot.new(hero, 1)
	if not demo:
		_spawn_enemy(hero.x + 600.0)
	var at := args.find("--marks")
	if demo and at >= 0 and at + 1 < args.size():
		marks = FileAccess.open(args[at + 1], FileAccess.WRITE)
		marks.store_line("# frame tick then x y in the 1920x1080 game for: hip hand_f hand_b foot_f foot_b head(top) street(0,0) shoulders")
		RenderingServer.frame_pre_draw.connect(_mark)


func _physics_process(_delta: float) -> void:
	var inp: Dictionary = Demo.input_at(tick) if demo else (bot.think(enemies.map(func(e): return e["f"])) if bot != null else Controls.read())
	hero.step(inp)
	for e in enemies:
		e["f"].step(e["brain"].think())
	tick += 1
	var everyone := [hero] + enemies.map(func(e): return e["f"])
	var crate_was: Array = world.objects.map(func(o): return o["strength"])
	world.step_hits(everyone)
	if world.objects.map(func(o): return o["strength"]) != crate_was:
		obstacles_view.refresh()
	Fight.separate(everyone)
	for ev in fight.step(everyone, world):
		if ev["drop"] != "":
			obstacles_view.refresh_items()
	_after_the_fight()
	hero_view.sync(hero, Street.GROUND_Y)
	hero_view.z_index = world.draw_order(hero)
	for e in enemies:
		e["view"].sync(e["f"], Street.GROUND_Y)
		e["view"].z_index = world.draw_order(e["f"])
	_show_bars()
	$Camera.position.x = lerpf($Camera.position.x, hero.x + hero.facing * 160.0, 0.08)
	$Camera.zoom = Vector2.ONE * tune["camera_zoom"]
	if demo and tick > Demo.length():
		get_tree().quit()
	if bot != null and tick > FIGHT_TICKS:
		get_tree().quit()


## One line per drawn frame (the movie's frame number), in the 1920x1080 game's pixels (the movie can be smaller: the
## build scales them), written after the camera has moved, just before drawing.
func _mark() -> void:
	var to_screen: Transform2D = hero_view.get_global_transform_with_canvas()
	var line := "%d %d" % [frame, tick]
	for p in hero_view.points().values():
		var s: Vector2 = to_screen * p
		line += " %d %d" % [roundi(s.x), roundi(s.y)]
	# and where a fixed spot of the street (the world's origin) is on screen: the camera follows the hero, so this is
	# how the build holds the street still in its pictures and shows his travel (the testers, 2026-11-02 22:33)
	var street: Vector2 = get_viewport().get_canvas_transform() * Vector2.ZERO
	line += " %d %d" % [roundi(street.x), roundi(street.y)]
	# and the shoulders, for the roll's shoulder close-up (the testers, 00:57 on 66ce4c6)
	var shoulder: Vector2 = to_screen * hero_view.shoulder_point()
	line += " %d %d" % [roundi(shoulder.x), roundi(shoulder.y)]
	marks.store_line(line)
	marks.flush()
	frame += 1


func _spawn_enemy(at_x: float) -> void:
	var t := Tuning.fresh()
	t["health"] = ENEMY_HEALTH
	t["flat_line"] = tune["flat_line"]
	var f = Fighter.new(t, clampf(at_x, tune["street_left"] + 100.0, tune["street_right"] - 100.0), 80.0, world)
	f.team = 1
	f.facing = -1 if f.x > hero.x else 1
	f.take_weapon("pipe")
	spawned += 1
	var view = HeroView.new(ENEMY_TINT)
	view.name = "Thug%d" % spawned
	add_child(view)
	view.sync(f, Street.GROUND_Y)
	enemies.append({"f": f, "brain": Brain.new(f, hero, spawned), "view": view, "down_for": 0})


## Put down for good, a thug lies a while, then goes; another walks in. The hero gets back up (lives come later).
func _after_the_fight() -> void:
	for e in enemies.duplicate():
		if e["f"].defeated():
			e["down_for"] += 1
			if e["down_for"] >= RESPAWN_TICKS:
				e["view"].queue_free()
				enemies.erase(e)
				_spawn_enemy(hero.x + 700.0 * (1 if hero.x < tune["street_right"] - 900.0 else -1))
	if hero.defeated():
		hero_down_for += 1
		if hero_down_for >= RESPAWN_TICKS:
			hero_down_for = 0
			hero.health = hero.max_health
			hero._enter("get_up")


func _make_bars() -> void:
	for who in ["hero", "enemy"]:
		var back := ColorRect.new()
		back.color = Color(0.1, 0.1, 0.12, 0.85)
		back.size = Vector2(420, 22)
		back.position = Vector2(32, 84) if who == "hero" else Vector2(1920 - 32 - 420, 84)
		var fill := ColorRect.new()
		fill.color = Color(0.35, 0.85, 0.9) if who == "hero" else Color(0.95, 0.45, 0.4)
		fill.size = Vector2(416, 18)
		fill.position = Vector2(2, 2)
		back.add_child(fill)
		$Hud.add_child(back)
		bars[who] = [back, fill]


func _show_bars() -> void:
	bars["hero"][1].size.x = 416.0 * hero.health / hero.max_health
	var foe = null
	for e in enemies:
		if foe == null or absf(e["f"].x - hero.x) < absf(foe.x - hero.x):
			foe = e["f"]
	bars["enemy"][0].visible = foe != null
	if foe != null:
		bars["enemy"][1].size.x = 416.0 * foe.health / foe.max_health


func _ready_pads() -> void:
	Input.joy_connection_changed.connect(func(device: int, _connected: bool): Controls.guard.forget(device))


func _input(event: InputEvent) -> void:
	Controls.feed(event)


func _unhandled_input(event: InputEvent) -> void:
	if feel != null and event is InputEventKey and event.pressed and not event.echo:
		if feel.handle(event.keycode):
			get_viewport().set_input_as_handled()
