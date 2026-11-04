extends Node2D
## The grey-box street with the hero on it (Stage 1). Steps the hero's logic 60 times a second and draws it.
## Options after "--": --demo plays the scripted demo (scripts/sim/demo.gd) and quits when it ends (--lab shows the
## feel lab during it);
## --fight has a bot (hero_bot.gd) play the hero against the thugs for FIGHT_TICKS and quits (the build's fight clip);
## --trial <name> plays one of the testers' controlled trials (present/trials.gd) and quits; --level <file> plays another layout (levels/*.json format); --bot has the bot play level 1 through and quits when it ends (prints how it went);
## --flat uses the flat line instead of the shallow street (D-13); --marks <file> (with --demo) writes, for every drawn
## frame, where the hips, hands and feet are on screen, for the reviewers' close-ups (scripts/build.sh, D-22).
## F1 opens the feel lab (feel_panel.gd).
## Played, it's level 1 (levels/level1.json, level.gd): waves of thugs along the street, the street locked at each
## until it's beaten, food and first aid lying about, the stairs, the boss upstairs; three lives, then the level starts
## again (D-15). With --fight a thug walks up and fights the bot on the free grey street.

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
const Level := preload("res://scripts/sim/level.gd")
const Trials := preload("res://scripts/present/trials.gd")
const Progress := preload("res://scripts/sim/progress.gd")
const Sound := preload("res://scripts/present/sound.gd")
const HERO_TINT := {"man": Color.WHITE, "woman": Color(1.08, 0.93, 1.03)}  # grey boxes: told apart by a warmer tint
## The story's opening, until the team's text lands (docs/ART-BRIEF.md: the story text is theirs)
const STORY := "The mob has taken the one you love.\nThey're holding them at the top of their tower.\n\nStreet by street, you're going to get them back."
const STORY_TICKS := 420
const LEVEL_FILE := "res://levels/level1.json"
const END_TICKS := 240  # how long "cleared" or "out of lives" shows before the level starts again
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
var level = null  # played: level 1
var shown_world = null  # the street the obstacles view is drawing
var level_views := {}  # enemy fighter id -> its view
var ended_for := 0
var items_seen := -1
var flips_seen := -1
var trial = null  # --trial <name>: one of the testers' controlled trials (present/trials.gd)
var dummy
var dummy_view
var trial_label: Label
var layer_was := {}
var progress = null  # played from the title: the game's order and its save (sim/progress.gd)
var title_label: Label
var title_options := []
var title_choice := 0
var title_mx := 0.0
var screen := ""  # "title", "story", "the_end" or "" (playing)
var screen_ticks := 0
var sound


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
	var ti := args.find("--trial")
	var trial_name: String = args[ti + 1] if ti >= 0 and ti + 1 < args.size() else ""
	var playing: bool = not demo and not "--fight" in args and trial_name == ""  # (--bot: the bot plays level 1)
	if playing:
		# (--bot plays seed 2, a run the bot wins, so the build's level clip shows the whole level, boss included)
		var file := LEVEL_FILE
		var li := args.find("--level")  # --level <file>: play another layout (the team's, a test one)
		if li >= 0 and li + 1 < args.size():
			file = args[li + 1]
		if not "--bot" in args and li < 0:
			progress = Progress.new()  # the full game: the title, a hero, the levels in order, the save
			if progress.has_save():
				file = progress.level_file()
		level = Level.new(Level.load_data(file), tune, 2 if "--bot" in args else 1)
		world = level.world
	elif trial_name != "":
		world = StreetWorld.new()  # a bare street: only the trial's two fighters
	else:
		world = StreetWorld.grey_street()
	obstacles_view = ObstaclesView.new()
	obstacles_view.name = "Obstacles"
	add_child(obstacles_view)
	obstacles_view.setup(world, Street.GROUND_Y)
	shown_world = world
	hero = level.hero if level != null else Fighter.new(tune, 600.0 if trial_name != "" else 400.0, 80.0, world)
	hero_view = HeroView.new()
	hero_view.name = "Hero"
	add_child(hero_view)
	$Street.setup(level.floors[0]["length"] if level != null else tune["street_right"], tune["street_depth"])
	$Camera.limit_left = int(tune["street_left"])
	$Camera.limit_right = int(tune["street_right"])
	$Hud/Title.text = "%s   ·   %s%s" % [Version.TITLE, Version.STAGE, "   ·   demo" if demo else ""]
	hero_view.sync(hero, Street.GROUND_Y)
	_make_bars()
	sound = Sound.new()
	sound.name = "Sound"
	add_child(sound)
	if progress != null:
		_show_title()
	if trial_name != "":
		_start_trial(trial_name)
	if "--fight" in args or "--bot" in args:
		bot = HeroBot.new(hero, 2 if "--bot" in args else 1)
	if bot != null and level == null:
		_spawn_enemy(hero.x + 600.0)
	var at := args.find("--marks")
	if demo and at >= 0 and at + 1 < args.size():
		marks = FileAccess.open(args[at + 1], FileAccess.WRITE)
		marks.store_line("# frame tick then x y in the 1920x1080 game for: hip hand_f hand_b foot_f foot_b head(top) street(0,0) shoulders")
		RenderingServer.frame_pre_draw.connect(_mark)


func _physics_process(_delta: float) -> void:
	if screen != "":
		_play_screen()
		return
	if trial != null:
		_play_trial()
		return
	if level != null:
		_play_level()
		return
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
	var fight_events: Array = fight.step(everyone, world)
	sound.fight_tick(everyone, fight_events)
	for ev in fight_events:
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
	$Street.follow($Camera.get_screen_center_position().x)
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


## Level 1, played: the level steps everyone; this draws what it holds and says how it stands.
func _play_level() -> void:
	if level.won or level.lost:
		ended_for += 1
		$Hud/Title.text = "LEVEL 1 CLEARED!" if level.won else "Out of lives: level 1 starts again"
		if ended_for >= END_TICKS:
			ended_for = 0
			if bot != null:
				print("LEVEL %s at tick %d, lives %d" % ["WON" if level.won else "LOST", level.tick, level.lives])
				get_tree().quit()
				return
			if level.won and progress != null:
				if progress.level_won():
					_show_screen("the_end")  # the last level won: the game is done
				else:
					_start_level(progress.level_file(), progress.hero)  # on to the next, fresh-bodied, saved at its start
				return
			level.restart()
	else:
		if bot != null:
			bot.me = level.hero
		level.step(bot.think(level.standing()) if bot != null else Controls.read())
		sound.fight_tick(level.everyone(), level.events)
	tick += 1
	hero = level.hero
	world = level.world
	if world != shown_world:  # restarted, or up the stairs: a new street to draw
		shown_world = world
		obstacles_view.setup(world, Street.GROUND_Y)
		$Street.setup(level.bounds().y, tune["street_depth"])
		items_seen = -1
	if world.items.size() != items_seen or not level.events.is_empty() or level.flipped.size() != flips_seen:
		items_seen = world.items.size()
		flips_seen = level.flipped.size()
		obstacles_view.set_marks(_marks())
		obstacles_view.refresh()
	# a view for every enemy on the street; gone ones go
	var live := {}
	for e in level.enemies:
		if e["gone"]:
			continue
		var id: int = e["f"].get_instance_id()
		live[id] = true
		if not level_views.has(id):
			var v = HeroView.new(ENEMY_TINT.lerp(Color(1.6, 0.6, 0.9), 0.5) if e["f"].max_health > Level.KINDS["thug"]["health"] else ENEMY_TINT)
			add_child(v)
			level_views[id] = v
		level_views[id].sync(e["f"], Street.GROUND_Y)
		level_views[id].z_index = world.draw_order(e["f"])
	for id in level_views.keys():
		if not live.has(id):
			level_views[id].queue_free()
			level_views.erase(id)
	hero_view.sync(hero, Street.GROUND_Y)
	hero_view.z_index = world.draw_order(hero)
	var b: Vector2 = level.bounds()
	$Camera.limit_left = int(b.x)
	$Camera.limit_right = int(maxf(b.y, b.x + 1920.0))
	$Camera.position.x = lerpf($Camera.position.x, hero.x + hero.facing * 160.0, 0.08)
	$Camera.zoom = Vector2.ONE * tune["camera_zoom"]
	$Street.follow($Camera.get_screen_center_position().x)
	if not (level.won or level.lost):
		var where: String = "fight!" if level.active_wave >= 0 else ("the boss" if level.boss_spawned and level.standing().any(func(f): return f.max_health > Level.KINDS["thug"]["health"]) else "go →")
		$Hud/Title.text = "Level 1   ·   %s   ·   lives %s" % [where, "♥ ".repeat(level.lives).strip_edges()]
	bars["hero"][1].size.x = 416.0 * hero.health / hero.max_health
	var foes: Array = level.standing()
	bars["enemy"][0].visible = not foes.is_empty()
	if not foes.is_empty():
		foes.sort_custom(func(a, c): return absf(a.x - hero.x) < absf(c.x - hero.x))
		bars["enemy"][1].size.x = 416.0 * foes[0].health / foes[0].max_health


func _start_trial(trial_name: String) -> void:
	dummy = Fighter.new(Tuning.fresh(), 700.0, 80.0, world)
	dummy.team = 1
	dummy.facing = -1
	dummy_view = HeroView.new(ENEMY_TINT)
	dummy_view.name = "Dummy"
	add_child(dummy_view)
	trial = Trials.new(trial_name, hero, dummy)
	trial_label = Label.new()
	trial_label.position = Vector2(32, 130)
	trial_label.add_theme_font_size_override("font_size", 30)
	trial_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	$Hud.add_child(trial_label)
	$Camera.position.x = 960.0


## One of the testers' trials: the script's presses, the blows settled, the numbers on screen; it quits at the end,
## printing what happened and when.
func _play_trial() -> void:
	var inp: Array = trial.inputs()
	hero.step(inp[0])
	dummy.step(inp[1])
	Fight.separate([hero, dummy])
	var events: Array = fight.step([hero, dummy], world)
	trial.saw(events)
	sound.fight_tick([hero, dummy], events)
	if not events.is_empty():
		obstacles_view.refresh()
	hero_view.sync(hero, Street.GROUND_Y)
	dummy_view.sync(dummy, Street.GROUND_Y)
	if trial.name == "scenery":
		$Camera.position.x += 6.0  # a steady pan, so each layer's speed can be read
		$Camera.position_smoothing_enabled = false
	else:
		$Camera.position.x = lerpf($Camera.position.x, (hero.x + dummy.x) * 0.5, 0.1)
	var cam: float = $Camera.get_screen_center_position().x
	$Street.follow(cam)
	var speeds := {}
	for spec in Street.LAYERS:
		var x: float = $Street.layers[spec[0]].position.x
		if layer_was.has(spec[0]) and layer_was.has("cam"):
			speeds[spec[0]] = (cam - layer_was["cam"]) - (x - layer_was[spec[0]])  # seen on screen, px a frame
		layer_was[spec[0]] = x
	speeds["street"] = cam - layer_was.get("cam", cam)
	layer_was["cam"] = cam
	trial_label.text = trial.overlay(speeds)
	bars["hero"][1].size.x = 416.0 * hero.health / hero.max_health
	bars["enemy"][1].size.x = 416.0 * dummy.health / dummy.max_health
	if trial.tick >= trial.length:
		for line in trial.history:
			print(line)
		print("TRIAL DONE %s" % trial.name)
		get_tree().quit()


## The title (choose a hero, or continue a save), the story's opening, the end: arrows choose, A (punch) goes on.
func _show_title() -> void:
	title_options = []
	if progress.has_save():
		title_options.append("continue")
	title_options.append_array(["man", "woman"])
	title_choice = 0
	_show_screen("title")


func _show_screen(which: String) -> void:
	screen = which
	screen_ticks = 0
	if title_label == null:
		title_label = Label.new()
		title_label.position = Vector2(0, 300)
		title_label.size = Vector2(1920, 500)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 44)
		title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		$Hud.add_child(title_label)
	title_label.visible = true
	_draw_screen()


func _draw_screen() -> void:
	match screen:
		"title":
			var names := {"continue": "CONTINUE (level %d)" % (progress.level + 1), "man": "THE MAN", "woman": "THE WOMAN"}
			var row := []
			for i in title_options.size():
				var n: String = names[title_options[i]]
				row.append("▶ %s ◀" % n if i == title_choice else n.to_lower())
			title_label.text = "CYBERBRAWLING MY WAY TO MY LOVE!\n\nChoose your hero\n\n%s\n\n←  →  to choose   ·   A  to start" % "     ".join(row)
		"story":
			title_label.text = STORY + "\n\n(A to go on)"
		"the_end":
			title_label.text = "YOU GOT THEM BACK.\n\nThe end, for now: the game grows a level at a time.\n\n(A for the title)"


func _play_screen() -> void:
	screen_ticks += 1
	$Street.follow($Camera.get_screen_center_position().x)
	for b in bars.values():
		b[0].visible = false  # no health bars over the title, the story or the end
	var inp: Dictionary = Controls.read()
	var mx: float = signf(inp.get("mx", 0.0))
	var go: bool = inp.get("punch", false) and screen_ticks > 20  # a short breath, so one press doesn't skip two screens
	match screen:
		"title":
			if mx != 0.0 and mx != title_mx:
				title_choice = wrapi(title_choice + int(mx), 0, title_options.size())
				_draw_screen()
			if go:
				var pick: String = title_options[title_choice]
				if pick == "continue":
					screen = ""
					title_label.visible = false
					_start_level(progress.level_file(), progress.hero)
				else:
					progress.new_game(pick)
					_show_screen("story")
		"story":
			if go or screen_ticks >= STORY_TICKS:
				screen = ""
				title_label.visible = false
				_start_level(progress.level_file(), progress.hero)
		"the_end":
			if go:
				progress.forget()
				_show_title()
	title_mx = mx


## A level from its file, fresh: the hero as chosen, at full health with no pain (it heals between levels).
func _start_level(file: String, who: String) -> void:
	level = Level.new(Level.load_data(file), tune, 1)
	world = level.world
	hero = level.hero
	shown_world = world
	obstacles_view.setup(world, Street.GROUND_Y)
	$Street.setup(level.floors[0]["length"], tune["street_depth"])
	for v in level_views.values():
		v.queue_free()
	level_views = {}
	hero_view.queue_free()
	hero_view = HeroView.new(HERO_TINT.get(who, Color.WHITE))
	hero_view.name = "Hero"
	add_child(hero_view)
	hero_view.sync(hero, Street.GROUND_Y)
	items_seen = -1
	flips_seen = -1
	ended_for = 0
	bars["hero"][0].visible = true


## The stairs' doorways and the switches on the floor he's on, for the obstacles view.
func _marks() -> Array:
	var out := []
	for l in level.plan.get("links", []):
		if int(l["from"]) == level.on and not l.get("auto", false):
			out.append({"kind": "doorway", "x": l["x"], "on": false})
	var sw: Array = level.plan.get("switches", [])
	for i in sw.size():
		if int(sw[i]["floor"]) == level.on:
			out.append({"kind": "switch", "x": sw[i]["x"], "on": level.flipped.has(i)})
	return out


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


## A pad plugged in or out: its sticks start fresh (stick_guard.gd). A method of this node, unhooked as the game closes:
## a hook left on Input (a lambda, before 2026-11-03) made Godot abort as it quit, on every run since 11-01.
func _ready_pads() -> void:
	Input.joy_connection_changed.connect(_on_pad_change)


func _on_pad_change(device: int, _connected: bool) -> void:
	Controls.guard.forget(device)


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_pad_change):
		Input.joy_connection_changed.disconnect(_on_pad_change)


func _input(event: InputEvent) -> void:
	Controls.feed(event)


func _unhandled_input(event: InputEvent) -> void:
	if feel != null and event is InputEventKey and event.pressed and not event.echo:
		if feel.handle(event.keycode):
			get_viewport().set_input_as_handled()
