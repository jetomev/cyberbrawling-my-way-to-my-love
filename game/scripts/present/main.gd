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
const BossRush := preload("res://scripts/sim/boss_rush.gd")
## The score on screen (a number top right, a tally at each level's end): the team's proposal, waiting on Javier's yes.
## Counted all along; switched on here.
const SHOW_SCORE := false
const Trials := preload("res://scripts/present/trials.gd")
const Scenes := preload("res://scripts/present/scenes.gd")
const Proofs := preload("res://scripts/present/proofs.gd")
const EDGE_INK := Color(0.08, 0.08, 0.10)  # the neon-ink outline
const Progress := preload("res://scripts/sim/progress.gd")
const Sound := preload("res://scripts/present/sound.gd")
const HERO_TINT := {"man": Color.WHITE, "woman": Color(1.08, 0.93, 1.03)}  # grey boxes: told apart by a warmer tint
## The story's words (the assistant team's, story/story.json): a line at a time, A goes on, or on its own after a while
const STORY_FILE := "res://story/story.json"
const PAGE_TICKS := 420
const LAST_LEVEL := 10
const LEVEL_FILE := "res://levels/level1.json"
const END_TICKS := 240  # how long "cleared" or "out of lives" shows before the level starts again
const FIGHT_TICKS := 1500  # --fight: how long the recorded bot fight runs (25 s)

const ENEMY_TINT := Color(1.35, 0.78, 0.72)  # the thug, reddish, so he never reads as the hero
## Each enemy type its own colour in the grey boxes (the team's art replaces them): the Glow Punk's light-up pink,
## the Bruiser a dark red, the boss magenta
const KIND_TINT := {"glow_punk": Color(1.45, 0.85, 1.25), "bruiser": Color(1.1, 0.55, 0.5), "boss": Color(1.6, 0.6, 1.4),
	"dj_volt": Color(0.75, 1.1, 1.6),  # DJ Volt: his LED jacket's cold blue
	"snick": Color(0.95, 1.3, 0.75), "bruiser_pipe": Color(1.1, 0.55, 0.5),  # Snick's glowing knife green-yellow
	"big_mama": Color(1.5, 1.4, 1.25),  # Big Mama Noodle: an enormous white apron
	"twin_tall": Color(1.3, 1.15, 0.75), "twin_short": Color(1.15, 1.0, 0.6),  # Twin Loans: matching checked suits
	"coach": Color(0.7, 0.95, 1.35),  # Coach Crusher: an old blue tracksuit
	"chrome": Color(1.35, 1.38, 1.5),  # Madame Chrome: a silver dress
	"static": Color(0.85, 1.1, 1.45),  # Mr. Static: a rubber suit, crackling blue
	"rook": Color(0.85, 0.36, 0.56),  # Velvet Rook: deep wine-red velvet, a touch of purple, never bright red (character page v2)
	"crane_operator": Color(1.45, 1.35, 0.4),  # the Crane Operator: a neon safety vest
	"godfather": Color(1.5, 1.45, 1.4),  # the Godfather of Glow: a white armoured coat
	# the rest of the roster, from the team's looks: the mechanic's blue overalls, the Doorman's black suit, the
	# Dancer's bright tracksuit, the Enforcer's long dark coat, the lookout's neon raincoat, the Grabber's green glow
	"wrench_mechanic": Color(0.7, 0.85, 1.25), "doorman": Color(0.45, 0.45, 0.5), "neon_dancer": Color(1.6, 1.2, 0.5),
	"enforcer": Color(0.6, 0.5, 0.6), "lookout": Color(1.4, 1.5, 0.55), "grabber": Color(0.8, 1.35, 0.8)}
## Some are bigger or smaller than the hero (Twin Loans: one tall brother, one short)
const KIND_SIZE := {"twin_tall": 1.1, "twin_short": 0.85, "coach": 1.15, "godfather": 1.2}
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
var shown_wet := true
var trial = null  # --trial <name>: one of the testers' controlled trials (present/trials.gd)
var scene = null  # --scene <name> with --level: a scripted run on a real level for the testers (present/scenes.gd)
var shield_was := 0  # the umbrella last frame (to see it break)
var breaks := []  # weapons worn out this moment: the two halves falling ({x, y, kind, t, dir})
var umbrella_broke := Vector3(0, 0, 99)  # where it broke (x, height) and frames since
var dummy
var dummy_view
var trial_label: Label
var layer_was := {}
var progress = null  # played from the title: the game's order and its save (sim/progress.gd)
var title_label: Label
var title_options := []
var title_choice := 0
var title_mx := 0.0
var screen := ""  # "title", "pages" (the story) or "" (playing)
var story := {}
var pages: Array = []  # the story lines still to show
var then := ""  # after the pages: "level" (play the current level) or "title"
var screen_ticks := 0
var name_mz := 0.0
var chosen_hero := "man"  # picked on the title, before the mode
var mode_options := ["normal", "harder", "rush", "helper"]
var mode_choice := 0
var helper_on := false  # the helper's switch, on the start screen until Javier names a pause key
var offer_choice := 0  # "Another life?": 0 yes, 1 no
var name_letters := [0, 0, 0]  # the neon letters being typed (A=0)
var name_at := 0
var after_name := []  # [lines, next]: the story pages that follow the letters
var neon_next := false  # the letters go up on the next level's first screen
var rush_carry := {}  # the boss rush: what the run carries from fight to fight
var score_label: Label
var sound
var sign_view: Node2D  # a level's signs on the wall behind the street (level 4's flickering gym sign), every frame
var flying_view: Node2D  # thrown things (DJ Volt's records) and his bass wave, redrawn every frame
var friend_view = null  # the sparring friend on level 1's first screen
var hint_label: Label  # his lesson's hint


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
		var si := args.find("--seed")  # --seed <n>: which run the bot plays (2 by default: one it wins on level 1)
		var run_seed: int = int(args[si + 1]) if si >= 0 and si + 1 < args.size() else (2 if "--bot" in args else 1)
		level = Level.new(Level.load_data(file), tune, run_seed)
		world = level.world
		var sc := args.find("--scene")
		if sc >= 0 and sc + 1 < args.size():
			scene = (Proofs if args[sc + 1].begins_with("proof_") else Scenes).new(args[sc + 1])
			scene.setup(level)
			$Camera.position.x = level.hero.x  # the camera starts on him, not panning in
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
	sign_view = Node2D.new()
	sign_view.name = "Signs"
	sign_view.z_index = 1  # (on the wall: over the backdrop, under everything on the street)
	sign_view.draw.connect(_draw_signs)
	add_child(sign_view)
	flying_view = Node2D.new()
	flying_view.name = "Flying"
	flying_view.z_index = 600
	flying_view.draw.connect(_draw_flying)
	add_child(flying_view)
	if progress != null:
		_show_title()
	if trial_name != "":
		_start_trial(trial_name)
	if "--fight" in args or "--bot" in args:
		var bs := args.find("--seed")
		bot = HeroBot.new(hero, int(args[bs + 1]) if bs >= 0 and bs + 1 < args.size() else (2 if "--bot" in args else 1))
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
	_note_breaks(fight_events)
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
	if SHOW_SCORE and bot == null and scene == null:  # the running total, top right beside the health bar (the proposal)
		if score_label == null:
			score_label = Label.new()
			score_label.position = Vector2(1500, 18)
			score_label.add_theme_font_size_override("font_size", 30)
			$Hud.add_child(score_label)
		score_label.text = _fmt(level.bank + level.score)
	if level.life_offer and bot == null and scene == null:  # the helper: "Another life for 2,000?"
		offer_choice = 0
		_show_screen("offer")
		return
	if (level.won or level.lost) and scene != null:
		scene.inputs(level)  # a scripted scene sees its ending (its last events, the win) and ends; no restart
		_play_scene()
		return
	if level.won or level.lost:
		ended_for += 1
		if ended_for == 1:
			var lines: Array = story.get("out_of_lives", ["Out of lives: the level starts again."])
			# its number in the game's order, or (a level played on its own: the bot's clips) its own name's first part
			var which: String = ("LEVEL %d" % (progress.level + 1)) if progress != null \
				else str(level.plan.get("name", "Level")).split(" · ")[0].split(" (")[0].to_upper()
			$Hud/Title.text = ("%s CLEARED!" % which) if level.won else lines[randi() % lines.size()]
		if ended_for >= END_TICKS:
			ended_for = 0
			if bot != null:
				print("LEVEL %s at tick %d, lives %d" % ["WON" if level.won else "LOST", level.tick, level.lives])
				get_tree().quit()
				return
			if progress != null and progress.mode == "rush":
				_after_rush_fight()
				return
			if level.won and progress != null:
				progress.total = level.bank  # (the helper's price may have come off the earlier levels)
				progress.add_score(level.score, level.helper_used)
				progress.cat = progress.cat or level.cat_fed  # the cat comes along (saved with the next level's start)
				var won_no: int = progress.level + 1
				var after: Array = story.get("after", {}).get(str(won_no), [])
				var clean: bool = level.hits_taken == 0
				var lines: Array
				var next: String
				if progress.level_won():  # the last level there is
					next = "title"
					if won_no >= LAST_LEVEL:
						var lit: Array = ["%s, IN NEON OVER THE CITY." % progress.name] if clean and progress.name != "" else []
						lines = after + lit + story.get("ending", [])  # (a clean level 10 lights the letters in the ending)
					else:
						lines = after + ["The rest of the route is still being built. Come back soon."]
				else:  # on to the next, fresh-bodied, saved at its start
					next = "level"
					lines = after + story.get("before", {}).get(str(won_no + 1), [])
				if SHOW_SCORE:
					lines = [_tally_text()] + lines
				if clean and progress.name == "" and won_no < LAST_LEVEL:  # the first level without a hit: the letters
					after_name = [lines, next]
					name_letters = [0, 0, 0]
					name_at = 0
					_show_screen("name")
				else:
					_show_pages(lines, next)
				return
			level.restart()
	else:
		if bot != null:
			bot.me = level.hero
			bot.goal = level.next_door()
			bot.goal_hit = level.goal_is_switch
			bot.jump_cue = level.crane_jump_cue()
			bot.dodge_x = level.shadow_cue()
			bot.climb = level.climb_cue()
		level.step(scene.inputs(level) if scene != null else (bot.think(level.standing()) if bot != null else Controls.read()))
		sound.fight_tick(level.everyone(), level.events)
		_note_breaks(level.events)
		if scene != null:
			_play_scene()
	tick += 1
	hero = level.hero
	world = level.world
	if world != shown_world:  # restarted, or up the stairs: a new street to draw
		shown_world = world
		obstacles_view.setup(world, Street.GROUND_Y)
		$Street.setup(level.bounds().y, tune["street_depth"])
		items_seen = -1
	if world.items.size() != items_seen or not level.events.is_empty() or level.flipped.size() != flips_seen or level.wet != shown_wet:
		shown_wet = level.wet
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
			var tint: Color = KIND_TINT.get(e["kind"], ENEMY_TINT)
			if e.get("hard", false):
				tint = tint.darkened(0.35)  # the hard version: darker (the roster's level 9)
			var v = HeroView.new(tint)
			v.kind = e["kind"]
			v.scale = Vector2.ONE * KIND_SIZE.get(e["kind"], 1.0)  # (drawn from the feet: they stay on the street)
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
	flying_view.queue_redraw()
	sign_view.queue_redraw()
	_show_friend()
	var b: Vector2 = level.bounds()
	$Camera.limit_left = int(b.x)
	$Camera.limit_right = int(maxf(b.y, b.x + 1920.0))
	$Camera.position.x = lerpf($Camera.position.x, hero.x + hero.facing * 160.0, 0.08)
	$Camera.zoom = Vector2.ONE * tune["camera_zoom"]
	# up a container stack (level 6), the camera rises with him so his head stays on screen; on the street it rests
	$Camera.position.y = lerpf($Camera.position.y, 540.0 - maxf(0.0, hero.y - 120.0), 0.08)
	if scene != null and scene.zoom != 1.0:  # a scripted scene in close (the cat is small)
		$Camera.zoom = Vector2.ONE * scene.zoom
		$Camera.position.x = lerpf($Camera.position.x, hero.x - hero.facing * 60.0, 0.2)
		$Camera.position.y = Street.GROUND_Y + hero.z - 1080.0 / scene.zoom * 0.5 + 60.0
	$Street.follow($Camera.get_screen_center_position().x)
	if not (level.won or level.lost):
		var where: String = "fight!" if level.active_wave >= 0 else ("the boss" if level.enemies.any(func(e): return e["boss"] and not e["f"].defeated()) else "go →")
		$Hud/Title.text = "%s   ·   %s   ·   lives %s" % [level.plan.get("name", "Level"), where, "♥ ".repeat(level.lives).strip_edges()]
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
	obstacles_view.setup(world, Street.GROUND_Y)  # (a trial may set things on the street: the bass_drop speakers)
	trial_label = Label.new()
	trial_label.position = Vector2(32, 130)
	trial_label.add_theme_font_size_override("font_size", 30)
	trial_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	$Hud.add_child(trial_label)
	$Camera.position.x = 960.0


## Notes every weapon that wore out this tick, so it's drawn snapping in two at the hand.
func _note_breaks(events: Array) -> void:
	for e in events:
		if e.get("worn", "") != "" and e.get("attacker") != null:
			var a = e["attacker"]
			breaks.append({"x": a.x + a.facing * 70.0, "y": Street.GROUND_Y + a.z - a.y - 190.0, "kind": e["worn"], "t": 0,
				"dir": a.facing})


## A scripted run on a real level (--scene): its notes on screen; a next level when it asks (the cat carried along, as
## a won level carries it); it quits at the end, printing what happened and when.
func _play_scene() -> void:
	if scene.next_level != "":
		var file: String = scene.next_level
		scene.next_level = ""
		_start_level(file, "man")
		level.cat_fed = true
		level.cat = Vector2(level.hero.x - 90.0, 80.0)  # as a won level brings it (progress.cat)
		scene.setup(level)
		$Camera.position.x = level.hero.x
	if trial_label == null:
		trial_label = Label.new()
		trial_label.position = Vector2(32, 130)
		trial_label.add_theme_font_size_override("font_size", 30)
		trial_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
		$Hud.add_child(trial_label)
	trial_label.text = scene.overlay(level)
	if scene.tick >= scene.length:
		for line in scene.history:
			print(line)
		print("TRIAL DONE %s" % scene.name)
		get_tree().quit()


## One of the testers' trials: the script's presses, the blows settled, the numbers on screen; it quits at the end,
## printing what happened and when.
func _play_trial() -> void:
	var inp: Array = trial.inputs()
	hero.step(inp[0])
	dummy.step(inp[1])
	Fight.separate([hero, dummy])
	var events: Array = fight.step([hero, dummy], world)
	_note_breaks(events)
	trial.saw(events)
	sound.fight_tick([hero, dummy], events)
	if not events.is_empty():
		obstacles_view.refresh()
	hero_view.sync(hero, Street.GROUND_Y)
	dummy_view.sync(dummy, Street.GROUND_Y)
	if trial.name == "scenery":
		$Camera.position.x += 6.0  # a steady pan, so each layer's speed can be read
		$Camera.position_smoothing_enabled = false
	elif trial.close_up != Vector2.ZERO and trial.tick < trial.close_until:
		$Camera.zoom = Vector2.ONE * 4.0  # a close-up of one thing (the first-aid kit's green cross)
		$Camera.position_smoothing_enabled = false
		$Camera.position = Vector2(trial.close_up.x, Street.GROUND_Y + trial.close_up.y - 12.0)
	elif trial.close_up != Vector2.ZERO:
		$Camera.zoom = Vector2.ONE
		$Camera.position = Vector2(lerpf($Camera.position.x, (hero.x + dummy.x) * 0.5, 0.1), 540.0)
	else:
		$Camera.position.x = lerpf($Camera.position.x, (hero.x + dummy.x) * 0.5, 0.1)
		if trial.zoom != 1.0:  # in close on the two of them, the street at the bottom of the picture
			$Camera.zoom = Vector2.ONE * trial.zoom
			$Camera.position.y = Street.GROUND_Y + hero.z - 1080.0 / trial.zoom * 0.5 + 60.0
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
	flying_view.queue_redraw()
	obstacles_view.refresh()
	bars["hero"][1].size.x = 416.0 * hero.health / hero.max_health
	bars["enemy"][1].size.x = 416.0 * dummy.health / dummy.max_health
	if trial.tick >= trial.length:
		for line in trial.history:
			print(line)
		print("TRIAL DONE %s" % trial.name)
		get_tree().quit()


## The title (choose a hero, or continue a save), the story's opening, the end: arrows choose, A (punch) goes on.
func _show_title() -> void:
	if story.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(STORY_FILE))
		story = parsed if parsed is Dictionary else {}
	title_options = []
	if progress.has_save() and progress.mode != "rush":
		title_options.append("continue")
	title_options.append_array(["man", "woman"])
	title_choice = 0
	_show_screen("title")


func _show_screen(which: String) -> void:
	screen = which
	screen_ticks = 0
	if title_label == null:
		title_label = Label.new()
		title_label.position = Vector2(260, 260)
		title_label.size = Vector2(1400, 560)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var panel := ColorRect.new()  # a dark panel behind the words, so they read over the street
		panel.name = "Panel"
		panel.color = Color(0.03, 0.02, 0.06, 0.72)
		panel.size = title_label.size + Vector2(80, 40)
		panel.position = Vector2(-40, -20)
		panel.show_behind_parent = true
		title_label.add_child(panel)
		title_label.add_theme_font_size_override("font_size", 44)
		title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		$Hud.add_child(title_label)
	title_label.visible = true
	_draw_screen()


func _draw_screen() -> void:
	match screen:
		"title":
			var choose: Dictionary = story.get("choose", {})
			var names := {"continue": "CONTINUE (level %d)" % (progress.level + 1), "man": choose.get("him", "Him").to_upper(),
				"woman": choose.get("her", "Her").to_upper()}
			var row := []
			for i in title_options.size():
				var n: String = names[title_options[i]]
				row.append("▶ %s ◀" % n if i == title_choice else n.to_lower())
			title_label.text = "CYBERBRAWLING MY WAY TO MY LOVE!\n\n%s\n\n%s\n\n←  →  to choose   ·   A  to start\n\n%s" % [
				"\n".join(choose.get("lines", ["Choose your hero"])), "     ".join(row), _best_line()]
		"mode":
			var names := {"normal": "THE GAME", "harder": "HARDER", "rush": "BOSS RUSH", "helper": "HELPER: %s" % ("ON" if helper_on else "OFF")}
			var row := []
			for i in mode_options.size():
				var n: String = names[mode_options[i]]
				row.append("▶ %s ◀" % n if i == mode_choice else n.to_lower())
			title_label.text = "HOW DO YOU WANT IT?\n\n%s\n\n(the helper: when your last life goes, another for 2,000 of your score)\n\n%s" % [
				"     ".join(row), _best_line()]
		"offer":
			var opts := ["YES", "NO"]
			var row := []
			for i in 2:
				row.append("▶ %s ◀" % opts[i] if i == offer_choice else opts[i].to_lower())
			title_label.text = "ANOTHER LIFE FOR %s?\n\n%s" % [_fmt(level.life_price()), "     ".join(row)]
		"name":
			var shown := ""
			for i in 3:
				var ch: String = char(65 + name_letters[i])
				shown += ("[%s]" % ch if i == name_at else " %s " % ch)
			title_label.text = "NOT A SCRATCH!\nYOUR NAME GOES UP IN NEON.\n\n%s\n\n↑ ↓ to change   ·   A  for the next letter" % shown
		"pages":
			title_label.text = (pages[0] if not pages.is_empty() else "") + "\n\n\n(A to go on)"


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
					_show_pages(story.get("before", {}).get(str(progress.level + 1), []), "level")
				else:
					chosen_hero = pick
					mode_choice = 0
					_show_screen("mode")
		"mode":
			if mx != 0.0 and mx != title_mx:
				mode_choice = wrapi(mode_choice + int(mx), 0, mode_options.size())
				_draw_screen()
			if go:
				var m: String = mode_options[mode_choice]
				if m == "helper":
					helper_on = not helper_on
					screen_ticks = 0
					_draw_screen()
				else:
					progress.new_game(chosen_hero, m, helper_on)
					rush_carry = BossRush.fresh_carry()
					if m == "rush":
						_show_pages(["THE BOSS RUSH.", "Nine of them, one after another. Three lives for the lot. Win their prizes as you go."], "level")
					else:
						_show_pages([story.get("choose", {}).get("chosen", "")] + story.get("opening", []) +
							story.get("before", {}).get("1", []), "level")
		"offer":
			if mx != 0.0 and mx != title_mx:
				offer_choice = 1 - offer_choice
				_draw_screen()
			if go:
				screen = ""
				title_label.visible = false
				if offer_choice == 0:
					level.buy_life()
				else:
					level.decline_life()
		"name":
			var mz: float = signf(inp.get("mz", 0.0))
			if mz != 0.0 and mz != name_mz:
				name_letters[name_at] = wrapi(name_letters[name_at] - int(mz), 0, 26)
				_draw_screen()
			name_mz = mz
			if go:
				name_at += 1
				screen_ticks = 0
				if name_at >= 3:
					progress.set_name("".join(name_letters.map(func(n): return char(65 + n))))
					neon_next = true
					_show_pages(after_name[0], after_name[1])
				else:
					_draw_screen()
		"pages":
			if go or screen_ticks >= PAGE_TICKS:
				pages.pop_front()
				screen_ticks = 0
				if pages.is_empty():
					_after_pages()
				else:
					_draw_screen()
	title_mx = mx


## The story, a line at a time; then a level or the title.
func _show_pages(lines: Array, next: String) -> void:
	pages = lines.filter(func(l): return l != "")
	then = next
	if pages.is_empty():
		_after_pages()
	else:
		_show_screen("pages")


func _after_pages() -> void:
	if then == "level":
		screen = ""
		title_label.visible = false
		_start_level(progress.level_file(), progress.hero)
	else:
		progress.forget()
		_show_title()


## A level from its file, fresh: the hero as chosen, at full health with no pain (it heals between levels).
func _start_level(file: String, who: String) -> void:
	if progress != null and progress.mode == "rush":
		level = BossRush.start(progress.level, rush_carry, tune, 1)  # the boss rush: the next boss, in his room
	else:
		level = Level.new(Level.load_data(file), tune, 1)
	if progress != null:
		level.harder = progress.mode == "harder"
		level.helper = progress.helper
		level.bank = progress.total
		if neon_next and progress.name != "":  # the letters up in neon on this level's first screen (the team's list)
			neon_next = false
			var fl: Dictionary = level.plan["floors"][level.on]
			fl["signs"] = fl.get("signs", []) + [[level.hero.x + 700.0, 360, progress.name]]
	if progress != null and progress.cat:
		level.cat_fed = true
		level.cat = Vector2(level.hero.x - 90.0, 80.0)
	world = level.world
	hero = level.hero
	shown_world = world
	obstacles_view.setup(world, Street.GROUND_Y)
	$Street.setup(level.floors[0]["length"], tune["street_depth"])
	for v in level_views.values():
		v.queue_free()
	level_views = {}
	if friend_view != null:
		friend_view.queue_free()
		friend_view = null
	hero_view.queue_free()
	hero_view = HeroView.new(HERO_TINT.get(who, Color.WHITE))
	hero_view.name = "Hero"
	add_child(hero_view)
	hero_view.sync(hero, Street.GROUND_Y)
	items_seen = -1
	flips_seen = -1
	ended_for = 0
	bars["hero"][0].visible = true


## A boss rush fight over: won, on to the next boss with his prize (or the end); lost, the run's over.
func _after_rush_fight() -> void:
	if level.lost:
		progress.forget()
		_show_pages(["The boss rush is over.", "Best: %s" % _best_line()], "title")
		return
	progress.total = level.bank
	progress.add_score(level.score, level.helper_used)  # (each fight's end scores like a level won)
	rush_carry = BossRush.carry_out(level)
	progress.level += 1
	var lines: Array = [_tally_text()] if SHOW_SCORE else []
	if progress.level >= BossRush.fights().size():
		progress.forget()
		_show_pages(lines + ["ALL NINE. THE BOSS RUSH IS BEATEN.", "%s for the run." % _fmt(progress.total)], "title")
	else:
		_show_pages(lines + ["Next."], "level")


## A number as the game writes it: 12,345.
static func _fmt(n: int) -> String:
	var t := str(absi(n))
	var out := ""
	while t.length() > 3:
		out = "," + t.right(3) + out
		t = t.left(t.length() - 3)
	return ("-" if n < 0 else "") + t + out


## The title's best scores, one per mode (a ✚ beside one made with the helper).
func _best_line() -> String:
	if progress == null:
		return ""
	var parts := []
	for m in [["normal", "the game"], ["harder", "harder"], ["rush", "boss rush"]]:
		var b: Dictionary = progress.best.get(m[0], {})
		parts.append("%s %s%s" % [m[1], _fmt(int(b.get("score", 0))) if b.has("score") else "—", " ✚" if b.get("mark", false) else ""])
	return "BEST:  " + "   ·   ".join(parts)


## The level's end tally (the team's proposal; shown only with SHOW_SCORE): goons, finishers, finds, health, no-hit.
func _tally_text() -> String:
	var p: Dictionary = level.score_parts
	return "GOONS %s   FINISHERS %s   BLOCKS %s   FINDS %s   HEALTH %s   NO HIT %s\nTHIS LEVEL %s   ·   RUN %s" % [
		_fmt(p.get("goons", 0) + p.get("bosses", 0)), _fmt(p.get("finishers", 0)), _fmt(p.get("blocks", 0)), _fmt(p.get("finds", 0)),
		_fmt(p.get("health", 0)), _fmt(p.get("no_hit", 0)), _fmt(level.score), _fmt(level.bank + level.score)]


## The sparring friend, drawn friendly green, and his lesson's hint near the top of the screen.
func _show_friend() -> void:
	if level.friend != null and friend_view == null:
		friend_view = HeroView.new(Color(0.75, 1.35, 0.85))
		friend_view.name = "Friend"
		add_child(friend_view)
	if friend_view != null:
		friend_view.visible = level.friend != null and level.on == 0
		if friend_view.visible:
			friend_view.sync(level.friend, Street.GROUND_Y)
			friend_view.z_index = world.draw_order(level.friend)
	if hint_label == null:
		hint_label = Label.new()
		hint_label.position = Vector2(260, 150)
		hint_label.size = Vector2(1400, 60)
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.add_theme_font_size_override("font_size", 32)
		hint_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.75))
		hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		$Hud.add_child(hint_label)
	hint_label.text = "" if scene != null else level.hint()  # (a scripted scene shows its own notes)


## DJ Volt's records, spinning black discs at their height, and his bass wave: rings rolling out from his speakers.
## A level's signs (a floor's "signs": [x, height above the street, text, and the text it flickers to, if any]): neon
## letters on a dark board high on the wall; one that flickers drops its last word now and then (Pippin's gym sign,
## "GYM: NO PAIN NO GAIN" -> "NO PAIN NO").
func _draw_signs() -> void:
	if level == null:
		return
	var lift: Dictionary = level.plan["floors"][level.on].get("chrome_lift", {})
	if not lift.is_empty():  # Madame Chrome's glass lift: a glass shaft from the floor up to her balcony, its car where she is
		var lx: float = float(lift["x"])
		var foot: float = Street.GROUND_Y + float(lift["z_down"])
		var head: float = Street.GROUND_Y + float(lift["z_up"]) - float(lift["top"]) - 230.0
		sign_view.draw_rect(Rect2(lx - 55.0, head, 110.0, foot - head), Color(0.6, 0.85, 0.95, 0.12))
		sign_view.draw_rect(Rect2(lx - 55.0, head, 110.0, foot - head), Color(0.7, 0.9, 1.0, 0.6), false, 3.0)
		var car_y: float = 0.0
		for e in level.enemies:
			if e.get("kind", "") == "chrome" and not e["gone"] and absf(e["f"].x - lx) < 60.0:
				car_y = e["f"].y
		var car_floor: float = Street.GROUND_Y + float(lift["z_down"]) - car_y
		sign_view.draw_line(Vector2(lx - 55.0, car_floor), Vector2(lx + 55.0, car_floor), Color(0.85, 0.7, 0.3), 5.0)
	for lip in level.plan["floors"][level.on].get("lit_lips", []):  # level 6: every gap's lip lit, fog or not (Boromir)
		var top_y: float = Street.GROUND_Y - float(lip[1])
		var lx: float = float(lip[0])
		for k in 4:  # a hazard stripe down the lip's face
			sign_view.draw_rect(Rect2(lx - 6.0, top_y + k * 22.0, 12.0, 11.0), Color(0.95, 0.8, 0.1))
		sign_view.draw_line(Vector2(lx, top_y), Vector2(lx, top_y - 90.0), Color(0.3, 0.3, 0.32), 4.0)  # a lamp on a post
		sign_view.draw_circle(Vector2(lx, top_y - 94.0), 9.0, Color(1.0, 0.75, 0.35))
		sign_view.draw_circle(Vector2(lx, top_y - 94.0), 22.0, Color(1.0, 0.7, 0.3, 0.18))
	for r in level.plan["floors"][level.on].get("smooth", []):  # a smooth shiny floor (level 5's slot floor): light streaks
		var depth: float = level.tune["street_depth"]
		var x: float = float(r[0])
		while x < float(r[1]):
			sign_view.draw_colored_polygon(PackedVector2Array([Vector2(x, Street.GROUND_Y), Vector2(x + 30.0, Street.GROUND_Y),
				Vector2(x - 30.0, Street.GROUND_Y + depth), Vector2(x - 60.0, Street.GROUND_Y + depth)]), Color(1.0, 0.95, 0.8, 0.07))
			x += 140.0
	var font := ThemeDB.fallback_font
	for sg in level.plan["floors"][level.on].get("signs", []):
		var text: String = sg[2]
		if sg.size() > 3 and level.tick % 170 in [0, 1, 2, 3, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28]:
			text = sg[3]  # (a stutter, then a long half-second dark: then lit again)
		var full: PackedStringArray = (sg[2] as String).split("\n")  # (a second line comes smaller: "we're tired")
		var lines: PackedStringArray = text.split("\n")
		var sizes := [34, 24]
		var w := 0.0
		var tall := 0.0
		for i in full.size():
			w = maxf(w, font.get_string_size(full[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sizes[mini(i, 1)]).x)
			tall += sizes[mini(i, 1)] + 8.0
		var top := Vector2(float(sg[0]) - w * 0.5, Street.GROUND_Y - float(sg[1]) - tall)
		var board := Rect2(top + Vector2(-18.0, -10.0), Vector2(w + 36.0, tall + 20.0))
		sign_view.draw_rect(board, Color(0.07, 0.06, 0.09))
		sign_view.draw_rect(board, Color(0.3, 0.1, 0.25), false, 3.0)
		var y: float = top.y
		for i in lines.size():
			var sz: int = sizes[mini(i, 1)]
			y += sz
			var lw: float = font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			var at := Vector2(float(sg[0]) - (w if i == 0 else lw) * 0.5, y)  # (the first line keeps its place as it flickers)
			var tube: Color = Color(1.0, 0.55, 0.85) if i == 0 else Color(0.55, 0.95, 0.97)
			sign_view.draw_string(font, at + Vector2(2, 2), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(tube, 0.35))  # the glow
			sign_view.draw_string(font, at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, tube)
			y += 8.0


func _draw_flying() -> void:
	var flying: Array = level.projectiles.flying if level != null else (trial.projectiles.flying if trial != null else [])
	var clock: int = level.tick if level != null else (trial.tick if trial != null else 0)
	for p in flying:
		var at := Vector2(p["x"], Street.GROUND_Y + p["z"] - (p["y0"] + p["y1"]) * 0.5)
		if HeroView.WEAPON_LOOK.has(p["kind"]):  # a thrown weapon (the hero's, the Mechanic's wrench), spinning end over end
			var look: Array = HeroView.WEAPON_LOOK[p["kind"]]
			var d: Vector2 = Vector2.from_angle(float(clock) * 0.45) * look[0] * 0.5
			flying_view.draw_line(at - d, at + d, EDGE_INK, look[1] + 4.0)
			flying_view.draw_line(at - d, at + d, look[2], look[1])
			continue
		if p["kind"] == "card":  # Madame Chrome's playing card, spinning
			var a := float(clock) * 0.5
			var pts := PackedVector2Array()
			for c in [Vector2(-12, -17), Vector2(12, -17), Vector2(12, 17), Vector2(-12, 17)]:
				pts.append(at + c.rotated(a))
			flying_view.draw_colored_polygon(pts, Color(0.97, 0.96, 0.92))
			pts.append(pts[0])
			flying_view.draw_polyline(pts, Color(0.75, 0.1, 0.2), 2.0)
			continue
		if p["kind"] == "ball":  # Coach Crusher's medicine ball: big, brown, stitched
			flying_view.draw_circle(at, 26.0, Color(0.45, 0.28, 0.16))
			flying_view.draw_arc(at, 26.0, 0.0, TAU, 20, Color(0.08, 0.08, 0.1), 3.0)
			flying_view.draw_line(at + Vector2(-20, -10), at + Vector2(20, 10), Color(0.85, 0.8, 0.7), 2.0)
			continue
		if p["kind"] == "soup":  # hot soup: an orange splash
			flying_view.draw_circle(at, 18.0, Color(0.95, 0.55, 0.15, 0.9))
			flying_view.draw_circle(at + Vector2(-14, 6), 9.0, Color(0.98, 0.7, 0.3, 0.8))
			continue
		flying_view.draw_circle(at, 22.0, Color(0.06, 0.06, 0.08))
		flying_view.draw_circle(at, 8.0, Color(0.9, 0.3, 0.5))
		flying_view.draw_arc(at, 22.0, float(clock) * 0.6, float(clock) * 0.6 + 1.2, 8, Color(0.6, 0.6, 0.7), 2.0)
	# the umbrella, open over his head (level 1's, and the umbrella trial's); when it takes its blow it breaks: a
	# crumpled umbrella falls away for a moment
	if hero.shield > 0:
		var h := Vector2(hero.x, Street.GROUND_Y + hero.z - hero.y - 330.0)
		flying_view.draw_arc(h, 60.0, PI, TAU, 16, Color(0.2, 0.2, 0.25), 8.0)
		flying_view.draw_colored_polygon(PackedVector2Array([h + Vector2(-60, 0), h + Vector2(-42, -42), h + Vector2(0, -60),
			h + Vector2(42, -42), h + Vector2(60, 0)]), Color(0.85, 0.25, 0.45, 0.9))
		flying_view.draw_line(h, h + Vector2(0, 90), Color(0.2, 0.2, 0.25), 4.0)
	if shield_was > 0 and hero.shield == 0:
		umbrella_broke = Vector3(hero.x, hero.z - hero.y, 0.0)
	shield_was = hero.shield
	if umbrella_broke.z < 40.0:
		umbrella_broke.z += 1.0
		var k: float = umbrella_broke.z
		var b := Vector2(umbrella_broke.x + k * 3.0, Street.GROUND_Y + umbrella_broke.y - 330.0 + k * k * 0.18)
		flying_view.draw_colored_polygon(PackedVector2Array([b + Vector2(-40, 10), b + Vector2(-18, -30), b + Vector2(4, -6),
			b + Vector2(30, -34), b + Vector2(44, 12)]), Color(0.85, 0.25, 0.45, 0.9))  # torn, inside out
		flying_view.draw_line(b + Vector2(0, -6), b + Vector2(-20, 70), Color(0.2, 0.2, 0.25), 4.0)  # the bent stick
	# a weapon worn out: it snaps in two at the hand and the halves fall away (the testers, 2026-11-04: the breaking
	# moment wasn't in the pictures, only the empty hand after it)
	for b in breaks:
		b["t"] += 1
		var t: float = b["t"]
		var look: Array = HeroView.WEAPON_LOOK.get(b["kind"], [80.0, 8.0, Color(0.7, 0.7, 0.72)])
		var half: float = look[0] * 0.5
		var at := Vector2(b["x"], b["y"])
		if t < 7.0:
			for k in 6:  # the snap: a white burst
				var a := TAU * k / 6.0
				flying_view.draw_line(at + Vector2.from_angle(a) * 8.0, at + Vector2.from_angle(a) * (16.0 + t * 4.0), Color(1, 1, 0.9), 3.0)
		for piece in [[1.0, 2.2, 0.22, 0.26], [-1.0, 1.6, 0.30, -0.32]]:
			var c := at + Vector2(piece[0] * b["dir"] * t * piece[1], minf(t * t * piece[2], Street.GROUND_Y + 60.0 - b["y"]))
			var d := Vector2.from_angle(t * piece[3] - PI * 0.4) * half * 0.5
			flying_view.draw_line(c - d, c + d, EDGE_INK, look[1] + 4.0)
			flying_view.draw_line(c - d, c + d, look[2], look[1])
	breaks = breaks.filter(func(b): return b["t"] < 45)
	if level == null:
		return
	if level.cat.x > -1.0e8:  # the stray cat: a small grey cat, by its bins or at his heels
		var c := Vector2(level.cat.x, Street.GROUND_Y + level.cat.y)
		flying_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-22, 0), c + Vector2(-20, -22), c + Vector2(12, -24),
			c + Vector2(18, 0)]), Color(0.55, 0.55, 0.6))
		flying_view.draw_circle(c + Vector2(20, -28), 11.0, Color(0.55, 0.55, 0.6))
		flying_view.draw_colored_polygon(PackedVector2Array([c + Vector2(14, -36), c + Vector2(17, -46), c + Vector2(21, -37)]), Color(0.55, 0.55, 0.6))
		flying_view.draw_colored_polygon(PackedVector2Array([c + Vector2(22, -37), c + Vector2(27, -46), c + Vector2(29, -35)]), Color(0.55, 0.55, 0.6))
		flying_view.draw_line(c + Vector2(-22, -12), c + Vector2(-38, -34), Color(0.55, 0.55, 0.6), 4.0)
		if not level.cat_fed and level.cat_with > 0:
			flying_view.draw_arc(c + Vector2(0, -50), 14.0, -PI / 2, -PI / 2 + TAU * level.cat_with / level.CAT_FEED_TICKS, 16, Color(1, 0.8, 0.4), 4.0)
	if not level.plan["floors"][level.on].get("lift", {}).is_empty():  # a glass lift riding: the shaft's floors slide past
		var b: Vector2 = level.bounds()
		var ride: float = level.lift_ride()
		var going: float = 1.0 if level.plan["floors"][level.on]["lift"].get("down", true) else -1.0
		for k in 4:
			var y: float = fposmod(float(level.tick) * 9.0 * going * (1.0 if ride < 1.0 else 0.0) + k * 300.0, 1200.0) - 200.0
			flying_view.draw_line(Vector2(b.x - 400.0, y), Vector2(b.y + 400.0, y), Color(0.7, 0.75, 0.85, 0.35), 6.0)
		for gx in [b.x + 20.0, b.y - 20.0]:  # the glass walls' frames
			flying_view.draw_line(Vector2(gx, 80.0), Vector2(gx, Street.GROUND_Y + 160.0), Color(0.75, 0.85, 0.95, 0.6), 5.0)
	if not level.crane.is_empty():  # the docks' crane: its container swinging low on its cable, the crates' shadows
		var box: Dictionary = level.crane["container"]
		if not box.is_empty():
			var r := Rect2(box["x"] - level.CONTAINER_WIDTH * 0.5, Street.GROUND_Y + 40.0 - level.CONTAINER_TOP, level.CONTAINER_WIDTH, level.CONTAINER_TOP)
			flying_view.draw_line(Vector2(box["x"], r.position.y), Vector2(box["x"] - box["dir"] * 120.0, -400.0), Color(0.1, 0.1, 0.12), 4.0)
			flying_view.draw_rect(r, Color(0.85, 0.42, 0.15))
			for k in 9:
				var rx: float = r.position.x + 10.0 + k * (level.CONTAINER_WIDTH - 20.0) / 8.0
				flying_view.draw_line(Vector2(rx, r.position.y + 6), Vector2(rx, r.end.y - 6), Color(0.65, 0.3, 0.1), 3.0)
			flying_view.draw_rect(r, Color(0.08, 0.08, 0.1), false, 4.0)
		elif level.crane.get("warned", false):  # the horn: a flashing arrow at the side it comes from
			var b: Vector2 = level.bounds()
			var side: float = level.crane.get("from", 1.0)
			var cam: Vector2 = $Camera.get_screen_center_position()
			var ex: float = cam.x + side * 860.0
			if level.tick % 10 < 6:
				flying_view.draw_colored_polygon(PackedVector2Array([Vector2(ex, Street.GROUND_Y - 20.0), Vector2(ex - side * 60.0, Street.GROUND_Y - 60.0),
					Vector2(ex - side * 60.0, Street.GROUND_Y + 20.0)]), Color(1.0, 0.75, 0.1))
		for cr in level.crane["crates"]:
			var left: float = cr["at"] - level.tick
			var g := Vector2(cr["x"], Street.GROUND_Y + cr["z"])
			var grow: float = 1.0 - clampf(left / level.CRATE_WARN, 0.0, 1.0)
			flying_view.draw_set_transform(g, 0.0, Vector2(1.0, 0.35))
			flying_view.draw_circle(Vector2.ZERO, 20.0 + grow * 30.0, Color(0, 0, 0, 0.25 + grow * 0.35))
			flying_view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var c := g + Vector2(-30.0, -60.0 - left * 14.0)
			flying_view.draw_rect(Rect2(c, Vector2(60, 60)), Color(0.58, 0.44, 0.28))
			flying_view.draw_rect(Rect2(c, Vector2(60, 60)), Color(0.08, 0.08, 0.1), false, 3.0)
	for r in level.rings:  # a hard Bruiser's shock ring, spreading along the floor from his slam (jump it)
		var rad: float = (level.tick - r["at"]) * level.RING_SPEED
		var g := Vector2(r["x"], Street.GROUND_Y + r["z"])
		var fade: float = 1.0 - rad / level.RING_MAX
		flying_view.draw_set_transform(g, 0.0, Vector2(1.0, 0.5))
		flying_view.draw_arc(Vector2.ZERO, rad, 0.0, TAU, 48, Color(0.55, 0.85, 1.0, minf(1.0, 1.2 * fade)), 9.0)
		flying_view.draw_arc(Vector2.ZERO, maxf(rad - 10.0, 1.0), 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.5 * fade), 2.0)
		flying_view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for d in level.from_above:  # a wrench thrown down from the balcony: its shadow grows, the wrench falls into it
		var left: float = d["at"] - level.tick
		var g := Vector2(d["x"], Street.GROUND_Y + d["z"])
		var grow: float = 1.0 - clampf(left / level.CRATE_WARN, 0.0, 1.0)
		flying_view.draw_set_transform(g, 0.0, Vector2(1.0, 0.35))
		flying_view.draw_circle(Vector2.ZERO, 14.0 + grow * 20.0, Color(0, 0, 0, 0.25 + grow * 0.35))
		flying_view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var w := g + Vector2(0.0, -40.0 - left * 14.0)
		var spin: float = left * 0.35
		if d.get("kind", "wrench") == "card":  # Madame Chrome's card, tumbling down from her balcony
			flying_view.draw_set_transform(w, spin, Vector2.ONE)
			flying_view.draw_rect(Rect2(-12.0, -17.0, 24.0, 34.0), Color(0.97, 0.96, 0.92))
			flying_view.draw_rect(Rect2(-12.0, -17.0, 24.0, 34.0), Color(0.75, 0.1, 0.2), false, 2.0)
			flying_view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		var arm := Vector2.from_angle(spin) * 30.0
		flying_view.draw_line(w - arm, w + arm, Color(0.7, 0.72, 0.75), 8.0)
		flying_view.draw_circle(w + arm, 9.0, Color(0.7, 0.72, 0.75))
	for e in level.enemies:  # Mr. Static winding up his slam: sparks crackling over his head, growing till it lands
		var f = e["f"]
		if f.slam_in >= 0 and not e["gone"]:
			var h := Vector2(f.x, Street.GROUND_Y + f.z - f.y - 400.0 * KIND_SIZE.get(e["kind"], 1.0))
			var r: float = 18.0 + (level.SLAM_WINDUP - f.slam_in) * 1.5
			for k in 8:
				var a := TAU * k / 8.0 + float(level.tick) * 0.4
				flying_view.draw_line(h + Vector2.from_angle(a) * r * 0.4, h + Vector2.from_angle(a + 0.3) * r, Color(0.6, 0.9, 1.0), 3.0)
			flying_view.draw_circle(h, 8.0, Color(0.85, 0.95, 1.0))
	if level.plan["floors"][level.on].get("cab", false):  # the crane's cab: its walls, window and open door, in outline
		var cb: Vector2 = level.bounds()
		var top: float = Street.GROUND_Y - 470.0
		var low: float = Street.GROUND_Y + tune["street_depth"]
		var cc := Color(0.95, 0.75, 0.2)
		flying_view.draw_line(Vector2(cb.x + 10.0, top), Vector2(cb.y, top), cc, 6.0)  # the roof
		flying_view.draw_line(Vector2(cb.x + 10.0, top), Vector2(cb.x + 10.0, low), cc, 6.0)  # the back wall's side
		flying_view.draw_rect(Rect2(cb.x + 120.0, top + 60.0, cb.y - cb.x - 300.0, 170.0), Color(0.6, 0.8, 0.95, 0.5), false, 4.0)  # the window
		for px in [cb.y - 8.0, cb.y + 8.0]:  # the open door's frame, on the far side
			flying_view.draw_line(Vector2(px, top), Vector2(px, low), cc, 5.0)
		flying_view.draw_line(Vector2(cb.y, low), Vector2(cb.y + 60.0, low + 40.0), Color(0.5, 0.5, 0.55), 4.0)  # the sill, and the drop
		if level.cab_cat():  # the white cat from the first switch, up on the roof by the door: a wink (the team's page)
			ObstaclesView.white_cat(flying_view, Vector2(cb.y - 90.0, top - 18.0), "wink")
	if level.plan["floors"][level.on].get("ring", false):  # a boxing ring: corner posts and three ropes at each side
		var b: Vector2 = level.ropes()
		var depth: float = tune["street_depth"]
		var hit: Dictionary = level.rope_hit
		var age: int = level.tick - int(hit.get("at", -999))
		for side in [-1.0, 1.0]:
			var ex: float = (b.x - 30.0) if side < 0.0 else (b.y + 30.0)  # (just outside where they stop him)
			var give: float = 0.0
			if not hit.is_empty() and float(hit["side"]) == side and age < 24:
				give = 70.0 * (1.0 - age / 24.0) * (1.0 if age < 6 else 0.6)  # the ropes give where he hit them, then spring back
			for z in [0.0, depth]:  # the corner posts, back and front
				flying_view.draw_line(Vector2(ex, Street.GROUND_Y + z), Vector2(ex, Street.GROUND_Y + z - 200.0), Color(0.15, 0.15, 0.18), 10.0)
			for k in 3:
				var hgt: float = 70.0 + k * 55.0
				var pts := PackedVector2Array([Vector2(ex, Street.GROUND_Y - hgt)])
				if give > 0.0:
					pts.append(Vector2(ex + side * give, Street.GROUND_Y + float(hit["z"]) - hgt))
				pts.append(Vector2(ex, Street.GROUND_Y + depth - hgt))
				flying_view.draw_polyline(pts, [Color(0.9, 0.2, 0.2), Color(0.95, 0.95, 0.95), Color(0.2, 0.35, 0.9)][k], 5.0)
	for o in level.world.objects:  # level 4's punching bag on its chain, swinging when hit
		if o["kind"] != "bag":
			continue
		var mid := Vector2((float(o["x0"]) + float(o["x1"])) * 0.5, Street.GROUND_Y + (float(o["z0"]) + float(o["z1"])) * 0.5)
		var age: int = level.tick - int(o.get("swing_at", -9999))
		var swing: float = 0.0
		if age >= 0 and age < level.BAG_SWING:
			swing = float(o.get("swing_dir", 1.0)) * 0.6 * sin(PI * float(age) / level.BAG_SWING)
		var hook := mid + Vector2(0.0, -float(o["top"]) - 120.0)
		var down := Vector2(sin(swing), cos(swing))
		var bag_top := hook + down * 120.0
		flying_view.draw_line(hook, bag_top, Color(0.35, 0.35, 0.38), 4.0)  # the chain
		var across: Vector2 = Vector2(down.y, -down.x) * (float(o["x1"]) - float(o["x0"])) * 0.5
		var bag_end: Vector2 = bag_top + down * (float(o["top"]) - 40.0)
		var body := PackedVector2Array([bag_top - across, bag_top + across, bag_end + across, bag_end - across])
		flying_view.draw_colored_polygon(body, Color(0.62, 0.16, 0.16))
		flying_view.draw_polyline(body + PackedVector2Array([body[0]]), Color(0.08, 0.08, 0.1), 3.0)
		flying_view.draw_line(bag_top + down * 30.0 - across, bag_top + down * 30.0 + across, Color(0.85, 0.85, 0.8), 4.0)  # its band
	var fl_plan: Dictionary = level.plan["floors"][level.on]
	if fl_plan.has("railing_gap"):  # level 4's balcony: a low railing along its front edge, broken by the gap
		var g: Array = fl_plan["railing_gap"]
		var front: float = Street.GROUND_Y + tune["street_depth"] + 14.0
		var rail := Color(0.55, 0.55, 0.6)
		var x0 := 0.0
		for seg in [[x0, float(g[0])], [float(g[1]), float(fl_plan["length"])]]:
			for hgt in [110.0, 190.0]:  # the mid bar and the top rail
				flying_view.draw_line(Vector2(seg[0], front - hgt), Vector2(seg[1], front - hgt), rail, 6.0)
			var px: float = seg[0]
			while px <= seg[1]:  # posts every 160 px, and at each side of the gap
				flying_view.draw_line(Vector2(px, front), Vector2(px, front - 190.0), rail, 6.0)
				px += 160.0
			flying_view.draw_line(Vector2(seg[1], front), Vector2(seg[1], front - 190.0), rail, 6.0)
		# the gap: only a low bar, knee-high, the goons tip over it (the hero's held by the balcony's edge)
		var bx: float = float(g[0])
		while bx < float(g[1]):
			flying_view.draw_line(Vector2(bx, front - 70.0), Vector2(minf(bx + 30.0, float(g[1])), front - 70.0),
				Color(0.95, 0.8, 0.1) if int((bx - float(g[0])) / 30.0) % 2 == 0 else Color(0.1, 0.1, 0.12), 7.0)
			bx += 30.0
	for strip in level.plan["floors"][level.on].get("live", []):  # a live floor strip: hazard stripes, crackling when on
		var z0: float = strip[4] if strip.size() > 5 else 0.0
		var z1: float = strip[5] if strip.size() > 5 else tune["street_depth"]
		var top: float = Street.GROUND_Y + z0
		var beat: int = int(strip[2]) + int(strip[3])
		var on_now: bool = level.tick % beat < int(strip[2])
		var x: float = strip[0]
		while x < strip[1]:  # yellow and black, the warning
			flying_view.draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + 20.0, top), Vector2(x + 50.0, Street.GROUND_Y + z1),
				Vector2(x + 30.0, Street.GROUND_Y + z1)]), Color(0.95, 0.8, 0.1, 0.35))
			x += 60.0
		if on_now:
			for k in 3:
				var pts := PackedVector2Array()
				var y0: float = top + (z1 - z0) * (k + 0.5) / 3.0
				var px: float = strip[0]
				while px <= strip[1]:
					pts.append(Vector2(px, y0 + (8.0 if (int(px / 30.0) + k + level.tick / 3) % 2 == 0 else -8.0)))
					px += 30.0
				flying_view.draw_polyline(pts, Color(0.55, 0.85, 1.0, 0.9), 3.0)
	if level.tick < level.live_until:  # Mr. Static's slam: the floor live, crackling (jump it)
		var b: Vector2 = level.bounds()
		for k in 4:
			var pts := PackedVector2Array()
			var y0: float = Street.GROUND_Y + 30.0 + k * 34.0
			var x: float = b.x
			while x <= b.y:
				pts.append(Vector2(x, y0 + (10.0 if (int(x / 40.0) + k + level.tick / 3) % 2 == 0 else -10.0)))
				x += 40.0
			flying_view.draw_polyline(pts, Color(0.55, 0.85, 1.0, 0.85), 3.0)
	var since: int = level.tick - level.bass_at
	if level.bass_at > 0 and since < 30:
		for o in level.world.objects:
			if o["kind"] == "speaker" and not o["broken"]:
				var c := Vector2((o["x0"] + o["x1"]) * 0.5, Street.GROUND_Y + 10.0 - 120.0)
				for k in 3:
					var r := float(since) * 28.0 + k * 60.0
					flying_view.draw_arc(c, r, 0.0, TAU, 48, Color(0.6, 0.9, 1.0, maxf(0.0, 0.7 - float(since) / 30.0)), 6.0)


## The stairs' doorways and the switches on the floor he's on, for the obstacles view.
func _marks() -> Array:
	var out := []
	for l in level.plan.get("links", []):
		if int(l["from"]) == level.on and not l.get("auto", false):
			out.append({"kind": l.get("kind", "doorway"), "x": l["x"], "on": false})
	var room: Dictionary = level.plan["floors"][level.on].get("kitchen", {})
	if room.has("wet"):
		out.append({"kind": "wet", "x": room["wet"][0], "x1": room["wet"][1], "on": level.wet})
	if room.has("tap"):
		out.append({"kind": "tap", "x": room["tap"], "on": level.wet})
	var sw: Array = level.plan.get("switches", [])
	for i in sw.size():
		if int(sw[i]["floor"]) == level.on:
			out.append({"kind": "switch", "x": sw[i]["x"], "on": level.flipped.has(i), "y": float(sw[i].get("y", 0.0)),
				"cat": "asleep" if sw[i].get("cat", false) and not level.cats_moved.has(i) else ("up" if sw[i].get("cat", false) else "")})
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
