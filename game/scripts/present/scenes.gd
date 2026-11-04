extends RefCounted
## Scripted runs on the real levels, for the testers' picture proof of what lives in a level rather than on a bare
## street (their ask, 2026-11-04). main.gd plays one with --level <file> --scene <name>; scripts/trials.sh records
## them with the trials, sheets and all. The level's waves are set aside so only the thing shown happens.
##
## cat    level 1's stray cat by its bins: the hero stands by it (the ring fills), it's fed; he walks on and it follows
##        at his heels; then level 2 starts and the cat is there with him, and follows him on
## twins  Twin Loans (level 3's boss) in the roster yard's back room, the bot fighting them: each swap ("Interest"),
##        each brother tumbling down the stairs, "Compound" at half their health, both down and the stick
## chrome Madame Chrome (level 5's boss) in the casino, the bot fighting her: her three cards, then open; the sweep and
##        the jab; a combo used twice in a row parried; three kicks into the cane's wind-up snap it
## static Mr. Static (level 7's boss) in the power plant, the bot fighting him: the live floor, the shock off a perfect
##        block, his baton knocked loose by a counter, the water tank
## rook   Velvet Rook (level 8's boss) in the penthouse, the bot fighting him: Checkmate (his Enforcers through the
##        doors), the plain combos parried, his sword breaking on the third perfect block of his last cut
## coach  Coach Crusher (level 4's boss) in the gym, the bot fighting him: the medicine ball, the tackle (and the ropes
##        when it misses), punches into his gloves, kicks landing, two dizzies and he gives up

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
var rolling := {}  # who's tumbling now (said once per tumble)


func _init(scene: String) -> void:
	name = scene
	match name:
		"cat":
			length = 520
			zoom = 1.7
		"twins", "coach", "chrome", "static", "rook":
			length = 4800


## Sets the level up for the scene: no fights, the hero where it happens.
func setup(level) -> void:
	for fl in level.floors:
		fl["wave"] = fl["waves"].size()  # every wave set aside
	if level.friend != null:
		level.friend.x = -5000.0
	match name:
		"twins", "coach", "chrome", "static", "rook":
			if level.on == 0:
				level._go_to(1, 200.0 if name == "twins" else 300.0)  # straight into the boss's room: he steps out
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
		"twins", "coach", "chrome", "static", "rook":
			if tick == 2:
				_say({"twins": "Twin Loans: the short brother on the shop floor, the tall one at the top of the stairs",
					"coach": "Coach Crusher: big gloves that block every punch, so kicks only",
					"chrome": "Madame Chrome: the chrome cane; mix your combos, and kick into the cane's wind-up",
					"static": "Mr. Static: a crackling baton; don't block it, break it (kick into the wind-up)",
					"rook": "Velvet Rook: a sword from his cane; mixed combos only; perfect-block his last cut"}[name])
			for p in level.projectiles.flying:
				if p["kind"] == "card" and not p.has("said"):
					p["said"] = true
					if tick - said.get("cards_at", -999) > 60:
						said["cards_at"] = tick
						_say("she throws her CARDS (three in a row); then she's open")
			for p in level.projectiles.flying:
				if p["kind"] == "ball" and not p.has("said"):
					p["said"] = true
					_say("he throws the MEDICINE BALL")
			for ev in level.events:
				match ev.get("result", ""):
					"swap": _say("INTEREST: halfway through a combo the brothers SWAP places")
					"compound": _say("COMPOUND: at half their health together, both rush him at once")
					"tackle": _say("the TACKLE: he charges along the street")
					"ropes": _say("the tackle MISSES: he slams into the ROPES, dazed and open")
					"gives_up": _say("dizzied TWICE: Coach Crusher GIVES UP")
					"parried": _say(("a plain combo's end: he PARRIES it (%s)" if name == "rook" else "the same combo twice in a row: she PARRIES it (%s)") % ev.get("move", ""))
					"cane_snaps": _say("the third kick into the cane's wind-up: the cane SNAPS, and she's done")
					"slam": _say("he raises the baton over his head, crackling: the SLAM is coming (jump as it comes down)")
					"live": _say("the floor is LIVE for half a second%s" % (": the hero's up in the air, over it" if level.hero.y > 0.0 else ""))
					"shocked": _say("SHOCKED: %s" % ("a perfect block on the baton, and the hero gets the shock" if ev.get("kind", "") == "shock" else "on the live floor"))
					"shorts_out": _say("P P K into the WATER TANK: he SHORTS OUT, dizzy at once")
					"checkmate": _say("CHECKMATE: %d Enforcer%s through the doors (one per door switch still standing)" % [ev.get("called", 0), "" if ev.get("called", 0) == 1 else "s"])
					"sword_breaks": _say("the third perfect block on his last cut: his sword BREAKS; only fists now, slow and old")
					"blocked":
						if name == "coach" and ev.get("target") != level.hero and not said.has("gloves"):
							said["gloves"] = true
							_say("a punch into the GLOVES: blocked, no harm")
					"hit":
						if name == "static" and ev.get("attacker") == level.hero and ev.get("drop", "") == "baton":
							_say("a counter into his wind-up: the BATON flies out of his hand")
						if name == "coach" and ev.get("attacker") == level.hero and "kick" in ev.get("move", "") and not said.has("kick"):
							said["kick"] = true
							_say("a KICK lands: %s" % ev["move"])
			for f in level.tumbling:
				if not rolling.has(f):
					rolling[f] = true
					_say("%s goes TUMBLING down the stairs to the foot" % ("the hero" if f == level.hero else "a brother"))
			for f in rolling.keys():
				if not level.tumbling.has(f):
					rolling.erase(f)
			if level.won and not said.has("won"):
				said["won"] = true
				_say({"twins": "both brothers down: the level's won, and the tall one leaves the STICK",
					"coach": "Coach Crusher's beaten: the level's won",
					"chrome": "Madame Chrome's beaten: the level's won, and the PIPE is the prize",
					"static": "Mr. Static's beaten: the level's won, and RUBBER GLOVES are the prize",
					"rook": "Velvet Rook's beaten: the level's won, and a SWORD is the prize"}[name])
				length = tick + 120
			bot.me = level.hero
			bot.goal = level.next_door()
			var boss: Array = level.enemies.filter(func(e): return e["kind"] == "chrome")
			if name == "chrome" and tick < 420 and not boss.is_empty():
				# set up for the picture, said so on screen: her memory holds his last combo, P P P; she holds still; he
				# starts P P P again (the second blow she reads and parries)
				var e: Dictionary = boss[0]
				var f = e["f"]
				inp = {}
				if absf(f.x - level.hero.x) > 125.0 or absf(f.z - level.hero.z) > 10.0:
					inp = {"mx": signf(f.x - level.hero.x), "mz": clampf((f.z - level.hero.z) / 16.0, -1.0, 1.0)}
				elif not said.has("set"):
					said["set"] = tick
					e["last_combo"] = "PPP"
					e["brain"].wait = 240
					e["brain"].block_left = 0
					_say("set up for the picture: his last combo on her was P P P; now he starts P P P again")
				elif tick in [said["set"] + 20, said["set"] + 32, said["set"] + 44]:
					inp = {"punch": true}
				if said.has("set") and tick < said["set"] + 120:
					e["brain"].block_left = 0
					for ev in level.events:
						if ev.get("attacker") == level.hero and ev.get("target") == f and ev["result"] != "parried":
							_say("his %s: %s" % [ev.get("move", ""), ev["result"].to_upper()])
			elif tick < 600 and name == "twins":
				inp = {"block": true}  # first he just holds his guard: the brothers take turns on him and swap
				if tick == 3:
					_say("he holds his guard: one brother attacks while the other guards and waits his turn")
			else:
				inp = bot.think(level.standing())
				if tick == 600 and name == "twins":
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
		"rook":
			var c: Array = level.enemies.filter(func(e): return e["kind"] == "rook")
			if not c.is_empty():
				line = "Velvet Rook: %s, health %.0f of %.0f  ·  sword: %s, perfect blocks on his last cut %d of 3  ·  door switches standing: %d" % [
					c[0]["f"].state, c[0]["f"].health, c[0]["f"].max_health, "in hand" if c[0]["f"].weapon == "sword" else "BROKEN",
					c[0].get("sword_blocks", 0), level.world.objects.filter(func(o): return o["kind"] == "door_switch" and not o["broken"]).size()]
		"static":
			var c: Array = level.enemies.filter(func(e): return e["kind"] == "static")
			if not c.is_empty():
				line = "Mr. Static: %s, health %.0f of %.0f  ·  baton: %s  ·  floor: %s  ·  hero's rubber gloves: %s" % [c[0]["f"].state,
					c[0]["f"].health, c[0]["f"].max_health, "in hand" if c[0]["f"].weapon == "baton" else "KNOCKED LOOSE",
					"LIVE" if level.tick < level.live_until else "safe", "on" if level.hero.rubber else "no"]
		"chrome":
			var c: Array = level.enemies.filter(func(e): return e["kind"] == "chrome")
			if not c.is_empty():
				line = "Madame Chrome: %s, health %.0f of %.0f  ·  the cane: %s, kicks into its wind-up %d of 3  ·  his last combo on her: %s" % [
					c[0]["f"].state, c[0]["f"].health, c[0]["f"].max_health, c[0]["f"].weapon if c[0]["f"].weapon != "" else "SNAPPED",
					c[0].get("cane_kicks", 0), c[0].get("last_combo", "none")]
		"coach":
			var c: Array = level.enemies.filter(func(e): return e["kind"] == "coach")
			if not c.is_empty():
				line = "Coach Crusher: %s, health %.0f of %.0f  ·  dizzied %d of 2" % [c[0]["f"].state, c[0]["f"].health,
					c[0]["f"].max_health, c[0].get("dizzies", 0)]
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
