extends RefCounted
## Scripted runs on the real levels, for the testers' picture proof of what lives in a level rather than on a bare
## street (their ask, 2026-11-04). main.gd plays one with --level <file> --scene <name>; scripts/trials.sh records
## them with the trials, sheets and all. The level's waves are set aside so only the thing shown happens.
##
## cat    level 1's stray cat by its bins: the hero stands by it (the ring fills), it's fed; he walks on and it follows
##        at his heels; then level 2 starts and the cat is there with him, and follows him on
## twins  Twin Loans (level 3's boss) in the roster yard's back room, the bot fighting them: each swap ("Interest"),
##        each brother tumbling down the stairs, "Compound" at half their health, both down and the stick

const LEVEL2 := "res://levels/level2.json"
const HeroBot := preload("res://scripts/sim/hero_bot.gd")

var name: String
var tick := 0
var length := 0
var note := ""
var note_left := 0
var history := []
var next_level := ""  # a level main.gd should start now (then cleared)
var in_level := 1
var walk_from := 0.0
var zoom := 1.0  # the camera closer in (the cat is small)
var bot = null  # a scene the bot plays (twins)
var said := {}


func _init(scene: String) -> void:
	name = scene
	match name:
		"cat":
			length = 520
			zoom = 1.7
		"twins":
			length = 4800


## Sets the level up for the scene: no fights, the hero where it happens.
func setup(level) -> void:
	for fl in level.floors:
		fl["wave"] = fl["waves"].size()  # every wave set aside
	if level.friend != null:
		level.friend.x = -5000.0
	match name:
		"twins":
			if level.on == 0:
				level._go_to(1, 200.0)  # straight into the back room: the brothers step out
				bot = HeroBot.new(level.hero, 1)
		"cat":
			if in_level == 1:
				level.hero.x = level.cat.x + 50.0
				level.hero.z = level.cat.y
				level.hero.facing = -1


## This frame's input for the hero.
func inputs(level) -> Dictionary:
	tick += 1
	var inp := {}
	match name:
		"twins":
			if tick == 2:
				_say("Twin Loans: the short brother on the shop floor, the tall one at the top of the stairs")
			for ev in level.events:
				match ev.get("result", ""):
					"swap": _say("INTEREST: halfway through a combo the brothers SWAP places")
					"compound": _say("COMPOUND: at half their health together, both rush him at once")
			for f in level.tumbling:
				if not said.has(f):
					said[f] = true
					_say("%s goes TUMBLING down the stairs to the foot" % ("the hero" if f == level.hero else "a brother"))
			for f in said.keys():
				if not level.tumbling.has(f):
					said.erase(f)
			if level.won and not said.has("won"):
				said["won"] = true
				_say("both brothers down: the level's won, and the tall one leaves the STICK")
				length = tick + 120
			bot.me = level.hero
			bot.goal = level.next_door()
			if tick < 600:
				inp = {"block": true}  # first he just holds his guard: the brothers take turns on him and swap
				if tick == 3:
					_say("he holds his guard: one brother attacks while the other guards and waits his turn")
			else:
				inp = bot.think(level.standing())
				if tick == 600:
					_say("now he fights back (the bot plays him)")
		"cat":
			if in_level == 1:
				if tick == 40:
					_say("level 1, by the bins: the stray cat. The hero stands by it and the ring over it fills (%d of %d)" % [level.cat_with, level.CAT_FEED_TICKS])
				if level.cat_fed and not history.any(func(h): return "FED" in h):
					_say("the cat is FED (%d frames by it): it will follow him" % level.CAT_FEED_TICKS)
					walk_from = level.hero.x
				if level.cat_fed and tick < 220:
					inp["mx"] = 1.0  # he walks on
				if tick == 200:
					_say("he walks on %d px: the cat trots at his heels, %d px behind" % [int(level.hero.x - walk_from), int(level.hero.x - level.cat.x)])
				if tick == 260:
					next_level = LEVEL2
					in_level = 2
			else:
				if tick == 266:
					_say("level 2 begins: the cat came along, at his heels (%d px behind)" % int(level.hero.x - level.cat.x))
				if tick >= 300 and tick < 460:
					inp["mx"] = 1.0
				if tick == 459:
					_say("in level 2 it follows him on: %d px behind" % int(level.hero.x - level.cat.x))
	return inp


func _say(t: String) -> void:
	note = t
	note_left = 90
	history.append("frame %d: %s" % [tick, t])


func overlay(level) -> String:
	if note_left > 0:
		note_left -= 1
	var line := ""
	match name:
		"twins":
			var tw: Array = level.enemies.filter(func(e): return e["kind"].begins_with("twin"))
			line = "Twin Loans: %s  ·  together %.0f of %.0f health%s" % [
				", ".join(tw.map(func(e): return "%s %s %.0f" % ["tall" if e["kind"] == "twin_tall" else "short", e["f"].state, e["f"].health])),
				tw.reduce(func(s, e): return s + e["f"].health, 0.0), tw.reduce(func(s, e): return s + e["f"].max_health, 0.0),
				"  ·  COMPOUND" if level.compound else ""]
		"cat":
			line = "level %d  ·  the cat: %s  ·  %d px from the hero" % [in_level,
				"FED, following" if level.cat_fed else "by its bins, %d of %d frames stood by it" % [level.cat_with, level.CAT_FEED_TICKS],
				int(absf(level.hero.x - level.cat.x))]
	return ("TRIAL: %s   ·   frame %d\n" % [name, tick]) + line + ("\n" + note if note_left > 0 else "")
