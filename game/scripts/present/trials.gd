extends RefCounted
## Controlled trials for the testers (their ask, 2026-11-03: "short scripted clips where one thing happens on purpose
## and the number is on screen"). Each trial is the hero and a practice dummy (a thug who only does what the script
## says) on a bare street, a script of presses for both, and a line of numbers drawn on screen every frame. main.gd
## plays one with --trial <name>; scripts/trials.sh records them all into every build.
##
## combo_edge   a jab, then the next press 23, 24 and 25 frames after it ends: the cross (the chain goes on) or a jab
##              again (a new chain); the setting is combo_window_ticks
## injuries     low kicks on one leg: bruised at 2, swollen at 5, broken at 9; then the dummy walks: a limp
## broken_arm   the hero's lead arm broken: his jab lands at half; holding a pipe, A still throws a jab, not a swing
## weapon_wear  a stick (8 hits) swung at the dummy until it breaks
## weapons      the knife, pipe, wrench, bat and sword, each swung until it breaks: its hits on screen
## disarm       a perfect block knocks his pipe loose: it leaves his hand, lies on the street, the hero picks it up
## counter      a jab into his kick's wind-up knocks his pipe loose
## dizzy        two three-punch combos in a row: dazed; then the third combo, the finishing chain, while he's dazed
## records      DJ Volt's records: a middle one dodged by stepping up the street, a low one jumped, a HIGH one rolled
##              under, and a middle one perfect-blocked back into him (the hit and its damage on screen)
## bass_drop    the guard held two seconds while his speakers stand: the wave pushes the hero back; both speakers
##              smashed, the same guard: nothing
## scenery      the camera pans at 6 px a frame: each layer's speed on screen
## umbrella     level 1's umbrella: the hero takes it up, it takes the dummy's blow for him (no damage) and breaks;
##              the next blow lands
## first_aid    the first-aid kit up close (the team's props sheet: a GREEN cross on white), then the hurt hero walks
##              over it: his health before and after
##
## Every trial logs its moments ("frame N: ..."); the ones that matter most are its key moments, and trials.sh lays
## each key moment out with the 4 frames after it, a row apiece (the testers, 2026-11-04). The weapons trials keep
## every swing in the log but only each weapon's breaking hit is key.

const Fighter := preload("res://scripts/sim/fighter.gd")
const Weapons := preload("res://scripts/sim/weapons.gd")
const Moves := preload("res://scripts/sim/moves.gd")
const Projectiles := preload("res://scripts/sim/projectiles.gd")
const Level := preload("res://scripts/sim/level.gd")

const NAMES := ["combo_edge", "injuries", "broken_arm", "weapon_wear", "weapons", "disarm", "counter", "dizzy", "records",
	"bass_drop", "scenery", "umbrella", "first_aid"]
const WEAPON_ROUND := ["knife", "pipe", "wrench", "bat", "sword"]
const SWING_EVERY := 32  # frames between swings in the weapon trials (each a fresh swing, not a chain)

var name: String
var hero
var dummy
var tick := 0
var length := 0
var steps := []  # [tick, who ("hero"/"dummy"), input, note]
var note := ""  # what just happened, kept on screen a moment
var note_left := 0
var history := []  # every note with its frame, printed at the end
var data := {}  # numbers a trial keeps
var projectiles = Projectiles.new()  # what's flying (the records trial)
var held := 0  # how long the hero's guard has been up (the bass_drop trial)
var close_up := Vector2.ZERO  # a spot the camera looks at up close (x, depth), until close_until
var close_until := 0
var zoom := 1.0  # the camera closer in on the two of them (the testers read small pictures)


func _init(trial: String, h, d) -> void:
	name = trial
	hero = h
	dummy = d
	match name:
		"combo_edge":
			# a jab (15 frames: it ends on the 15th frame after its press), then the next press 23, 24 and 25 frames
			# after that; the dummy stands out of reach so nothing else happens
			dummy.x = hero.x + 600.0
			length = 3 * 90
			var jab: int = hero.attack_length("punch")
			for i in 3:
				var at := 10 + i * 90
				steps.append([at, "hero", {"punch": true}, ""])
				steps.append([at + jab + 23 + i, "hero", {"punch": true}, "%d" % (23 + i)])
		"injuries":
			_tough_dummy()
			length = 520
			for i in 6:
				steps.append([10 + i * 50, "hero", {"kick": true}, ""])
		"broken_arm":
			_tough_dummy()
			hero.pain["arm_f"] = hero.tune["pain_broken"]
			length = 220
			steps.append([20, "hero", {"punch": true}, ""])  # a jab with the broken arm
			steps.append([130, "hero", {"punch": true}, ""])  # with the pipe in hand (given at 100): still a jab
		"weapon_wear":
			zoom = 1.8
			hero.take_weapon("stick")
			_tough_dummy()
			length = 8 * 45 + 60
			for i in 9:
				steps.append([10 + i * 45, "hero", {"punch": true}, ""])
		"weapons":
			zoom = 1.8
			_tough_dummy()
			var at := 10
			for kind in WEAPON_ROUND:
				data[at - 2] = kind  # the weapon handed over just before its first swing
				for i in Weapons.TABLE[kind]["hits"]:
					steps.append([at, "hero", {"punch": true}, ""])
					at += SWING_EVERY
				at += 40
			length = at + 30
		"disarm":
			dummy.take_weapon("pipe")
			_tough_dummy()
			length = 260
			steps.append([10, "dummy", {"punch": true}, ""])  # he swings the pipe; the hero's guard goes up just in time
		"counter":
			dummy.take_weapon("pipe")
			_tough_dummy()
			length = 150
			steps.append([30, "dummy", {"kick": true}, ""])  # his kick (it winds up 5 frames)
			steps.append([28, "hero", {"punch": true}, ""])  # the jab lands on frame 32, while his kick is still winding up
		"dizzy":
			_tough_dummy()
			length = 400
			for i in 9:  # three three-punch combos: two make him dizzy, the third lands while he's dazed
				steps.append([10 + i * 16 + (40 if i >= 3 else 0) + (40 if i >= 6 else 0), "hero", {"punch": true}, ""])
		"records":
			_tough_dummy()
			dummy.x = hero.x + 600.0
			length = 430
		"bass_drop":
			_tough_dummy()
			dummy.x = hero.x + 500.0
			for o in [[hero.x - 200.0, "speaker_left"], [hero.x + 760.0, "speaker_right"]]:
				var sp: Dictionary = hero.world.add("speaker", o[0], o[0] + 80.0, 0.0, 30.0, 200.0, false, 6)
				sp["name"] = o[1]
			length = 420
		"scenery":
			length = 240
		"umbrella":
			zoom = 1.6
			_tough_dummy()
			hero.world.drop("umbrella", hero.x + 40.0, hero.z)
			length = 220
			steps.append([90, "dummy", {"punch": true}, ""])  # his first blow: the umbrella takes it
			steps.append([160, "dummy", {"punch": true}, ""])  # his second: nothing left to take it
		"first_aid":
			dummy.x = hero.x + 900.0  # out of the way
			hero.health = hero.max_health * 0.4
			hero.world.drop("first_aid", hero.x + 160.0, hero.z)
			close_up = Vector2(hero.x + 160.0, hero.z)
			close_until = 90
			length = 200


func _tough_dummy() -> void:
	dummy.health = 999.0
	dummy.max_health = 999.0


## This frame's input for the hero and the dummy.
func inputs() -> Array:
	tick += 1
	var h := {}
	var d := {}
	for s in steps:
		if s[0] == tick:
			(h if s[1] == "hero" else d).merge(s[2])
			if s[3] != "":
				data["pressed_at"] = int(s[3])
	# between blows the hero steps back into reach of the dummy (blows drive him back)
	if name in ["injuries", "weapon_wear", "weapons", "dizzy", "broken_arm"] and h.is_empty() and hero.state in ["idle", "walk"] \
			and (tick <= 330 or name != "injuries") and absf(dummy.x - hero.x) > 100.0 and dummy.hittable():
		h["mx"] = signf(dummy.x - hero.x)
	match name:
		"weapons", "weapon_wear":
			if data.has(tick) and data[tick] is String:
				hero.take_weapon(data[tick])
				_say("the hero takes the %s: %d hits in it" % [data[tick], Weapons.TABLE[data[tick]]["hits"]], false)
				data["swings"] = 0
			if h.has("punch"):
				hero.chain = ""  # each a fresh swing, so every press is the same blow and wears it by one
			if dummy.state == "idle":
				dummy.x = hero.x + 100.0  # the dummy steps back in, so no swing misses: every one lands and wears it
		"broken_arm":
			if tick == 100:
				hero.take_weapon("pipe")
				_say("the hero picks up a pipe; his lead arm is still broken")
		"disarm":
			if tick >= 15 and tick < 60:
				h["block"] = true  # up 5 frames into his swing: perfect when it lands
			if tick >= 60 and tick < 100:
				d["mx"] = 1.0  # the dummy backs off, leaving the pipe where it fell
			if tick >= 110 and hero.weapon == "" and not hero.world.items.is_empty():
				h["mx"] = signf(hero.world.items[0]["x"] - hero.x)  # the hero walks to the pipe
		"records":
			# three records from the DJ (the dummy), 90 frames apart: middle, low, middle
			for r in [[20, 110.0, 180.0], [110, 0.0, 60.0], [200, 210.0, 280.0], [300, 110.0, 180.0]]:
				if tick == r[0]:
					projectiles.throw("record", dummy.x - 40.0, dummy.z, r[1], r[2], -Level.RECORD_SPEED, Level.RECORD_DAMAGE, dummy.team)
					_say("he throws a record: %s (%d to %d px up)" % [{0: "LOW", 110: "MIDDLE", 210: "HIGH"}[int(r[1])], int(r[1]), int(r[2])])
			if tick >= 40 and tick < 75:
				h["mz"] = -1.0  # the first: step up the street, out of its line
			if tick >= 75 and tick < 110:
				h["mz"] = 1.0  # and back
			if tick == 150:
				h["jump"] = true  # the low one: jump it
			if tick == 236:
				h["roll"] = true  # the high one: roll under it, timed so it passes while he's round
			if tick >= 322 and tick < 345:
				h["block"] = true  # the last: the guard up just as it arrives, a perfect block
		"bass_drop":
			if tick >= 20 and tick < 160:
				h["block"] = true  # the guard held, speakers standing
			if tick == 200:
				for o in hero.world.objects:
					if o["kind"] == "speaker":
						o["broken"] = true
				_say("both speakers smashed")
			if tick >= 230 and tick < 380:
				h["block"] = true  # the same guard, speakers gone
			held = held + 1 if hero.blocking() != "" else 0
			var standing: bool = hero.world.objects.any(func(o): return o["kind"] == "speaker" and not o["broken"])
			if held >= Level.BASS_HOLD and standing:
				held = 0
				data["waves"] = data.get("waves", 0) + 1
				hero._enter("idle")
				hero.take_hit({"damage": 1.0, "effect": "push", "low": 0.0, "high": 300.0, "move": "bass"}, dummy)
				_say("BASS DROP: the guard held %d frames with a speaker standing; the wave pushes him back" % Level.BASS_HOLD)
			if tick == 379:
				_say("the guard held %d frames with both speakers gone: no wave (%d wave in all)" % [150, data.get("waves", 0)])
		"umbrella":
			if tick >= 10 and tick < 30:
				h["mx"] = 1.0  # walks onto it: he takes it up
			if tick == 30 and hero.shield > 0:
				_say("the hero takes up the umbrella: it will take ONE blow for him")
			if tick < 85:
				dummy.x = hero.x + 110.0  # the dummy stands in reach, facing him
				dummy.facing = -1
		"first_aid":
			if tick == 2:
				_say("the first-aid kit, up close: a GREEN cross on white (the team's props sheet)")
			if tick >= 110 and tick < 150 and not data.has("healed"):
				h["mx"] = 1.0  # the hurt hero walks over it
				if hero.world.items.is_empty():
					data["healed"] = true
					_say("he walks over the kit: health %.1f → %.1f of %.0f" % [hero.max_health * 0.4, hero.health, hero.max_health])
		"injuries":
			if tick > 330:
				d["mx"] = 1.0  # the dummy walks away from the hero on his broken leg
				if tick == 331:
					data["walk_from"] = dummy.x
	if name == "disarm" and data.get("held", "") == "street" and hero.weapon == "pipe":
		_say("the hero walks over the pipe: it's in HIS hand now")
	data["held"] = "dummy" if dummy.weapon != "" else ("hero" if hero.weapon != "" else "street")
	if dummy.state == "dizzy":
		data["dizzy_seen"] = true
	return [h, d]


## What a fight event means here, put on screen for a moment.
func saw(events: Array) -> void:
	if name == "records":
		for e in projectiles.step([hero, dummy], 0.0, 4000.0):
			if e["target"] == hero:
				match e["result"]:
					"perfect": _say("the record meets the hero's guard: PERFECT, it flies back at him")
					"blocked": _say("the record meets the hero's guard: a plain BLOCK (too early for a perfect one)")
					_: _say("the record HITS the hero")
			else:
				var dmg: float = e["projectile"]["damage"]
				_say("his own record HITS DJ Volt (sent back by the perfect block): damage %.1f, his health %.1f → %.1f" % [
					dmg, dummy.health + dmg, dummy.health])
		for p in projectiles.flying:
			if not p.has("passed") and p["vx"] < 0.0 and p["x"] < hero.x - 60.0:
				p["passed"] = true
				_say("the record flies past: %s" % ("over him, he jumped it" if hero.y > 0.0 else ("he rolled under it" if hero.state == "roll" else "he stepped out of its line")))
	for e in events:
		var t := ""
		if e["result"] == "umbrella":
			_say("the umbrella TAKES his blow: no damage to the hero (health %.1f), and it BREAKS" % hero.health)
			continue
		if e["result"] == "perfect":
			t = "PERFECT BLOCK"
		elif e["counter"]:
			t = "COUNTER (caught winding up)"
		elif e["result"] == "hit":
			t = "HIT: %s, damage %s" % [e["move"], str(e["attacker"].move().get("damage", "?"))]
			if name == "broken_arm" and e["attacker"] == hero:
				t += " (whole: %s; his lead arm is BROKEN)" % str(Moves.data(e["move"], hero.tune)["damage"])
		if e["drop"] != "":
			t += "  ·  the %s leaves his hand, onto the street" % e["drop"]
		if e["broke"] != "":
			t += "  ·  %s BROKEN" % e["broke"]
		if e["worn"] != "":
			t += "  ·  the %s BREAKS (worn out)" % e["worn"]
		if name == "dizzy" and e["result"] == "hit" and e["move"] == "power_punch" and data.get("dizzy_seen", false):
			t += "  ·  the third combo, landed while he's DAZED: the finishing chain"
		if t != "":
			# the weapons trials: every swing is logged, only a weapon's breaking hit is a key moment
			_say(t, not name in ["weapons", "weapon_wear"] or e["worn"] != "")
	if name == "combo_edge" and data.has("pressed_at") and hero.attack_phase() == "startup" and hero.t == 0:
		var m: String = hero.state
		_say("pressed %d frames after the jab ended: %s" % [data["pressed_at"], "the CROSS (the chain goes on)" if m == "cross" else "a JAB (a new chain)"])
		data.erase("pressed_at")
	if name == "broken_arm" and tick == 131:
		_say("A with the pipe in hand: %s" % ("a JAB, not a swing (a broken arm can't swing it)" if hero.state == "punch" else hero.state.to_upper()))


func _say(t: String, key := true) -> void:
	note = t
	note_left = 90
	history.append(("frame %d: %s" if key else "frame %d · %s") % [tick, t])


## The numbers on screen this frame.
func overlay(street_speeds: Dictionary = {}) -> String:
	if note_left > 0:
		note_left -= 1
	var line := ""
	match name:
		"combo_edge":
			line = "combo window: %d frames (combo_window_ticks)   ·   hero: %s, frame %d" % [hero.tune["combo_window_ticks"], hero.state, hero.t]
		"injuries":
			var p: float = dummy.pain["leg_f"]
			line = "dummy's lead leg: %.0f pain points  ·  %s  (bruised at %.0f, swollen at %.0f, broken at %.0f)" % [p,
				["fresh", "bruised", "swollen", "BROKEN"][dummy.pain_stage("leg_f")], dummy.tune["pain_bruised"],
				dummy.tune["pain_swollen"], dummy.tune["pain_broken"]]
			if data.has("walk_from") and tick > 340:
				var speed: float = absf(dummy.x - data["walk_from"]) / float(tick - 331)
				line += "\nwalking: %.1f px a frame (sound legs: %.1f; a broken leg limps at %.0f%%)" % [speed, dummy.tune["walk_speed"], dummy.tune["limp"] * 100.0]
		"broken_arm":
			line = "hero's lead arm: %s  ·  holds: %s  ·  a blow with a broken arm lands at half; a broken lead arm can't swing a weapon" % [
				["fresh", "bruised", "swollen", "BROKEN"][hero.pain_stage("arm_f")], hero.weapon if hero.weapon != "" else "nothing"]
		"weapon_wear", "weapons":
			var held: String = hero.weapon
			var total: int = Weapons.TABLE[held]["hits"] if held != "" else 0
			line = "hero holds: %s  ·  hits left: %d of %d  ·  a swing that lands uses 1 (a miss, a guard or a kick: none)" % [
				held if held != "" else "nothing (fists)", hero.weapon_hits_left, total]
		"disarm", "counter":
			var where: String = {"dummy": "in the DUMMY's hand", "hero": "in the HERO's hand", "street": "on the STREET"}[data.get("held", "dummy")]
			if data.get("held", "") == "street" and not hero.world.items.is_empty():
				where += " at x %d" % int(hero.world.items[0]["x"])
			line = "the pipe: %s  ·  hero's guard: %s (perfect for its first %d frames)" % [where,
				hero.blocking() if hero.blocking() != "" else "down", hero.tune["perfect_block_ticks"]]
		"records":
			var flying: Array = projectiles.flying.map(func(p): return "%s %d-%d px up, x %d" % ["record", int(p["y0"]), int(p["y1"]), int(p["x"])])
			line = "flying: %s  ·  hero: %s, %d px up the street, %d px off the ground" % [", ".join(flying) if not flying.is_empty() else "nothing",
				hero.state, int(hero.z), int(hero.y)]
		"bass_drop":
			var standing: int = hero.world.objects.filter(func(o): return o["kind"] == "speaker" and not o["broken"]).size()
			line = "speakers standing: %d  ·  guard held: %d of %d frames  ·  waves so far: %d" % [standing, held, Level.BASS_HOLD, data.get("waves", 0)]
		"dizzy":
			line = "combo finishers landed in a row: %d  ·  dizzy: %s  ·  frames left: %d of %d" % [dummy.finishers_taken,
				"YES" if dummy.state == "dizzy" else "no", dummy.dizzy_left, dummy.tune["dizzy_ticks"]]
		"umbrella":
			line = "umbrella: %s  ·  hero's health: %.1f of %.0f" % [
				"in his hand, takes 1 more blow" if hero.shield > 0 else ("BROKEN" if tick > 30 else "leaning on the wall"),
				hero.health, hero.max_health]
		"first_aid":
			line = "first-aid kit: %s  ·  hero's health: %.1f of %.0f" % ["used" if data.has("healed") else "on the street",
				hero.health, hero.max_health]
		"scenery":
			var parts := []
			for k in street_speeds:
				parts.append("%s %.2f" % [k, street_speeds[k]])
			line = "camera: 6.00 px a frame  ·  layers on screen, px a frame: " + ", ".join(parts)
	return ("TRIAL: %s   ·   frame %d\n" % [name, tick]) + line + ("\n" + note if note_left > 0 else "")
