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
## scenery      the camera pans at 6 px a frame: each layer's speed on screen

const Fighter := preload("res://scripts/sim/fighter.gd")
const Weapons := preload("res://scripts/sim/weapons.gd")
const Moves := preload("res://scripts/sim/moves.gd")

const NAMES := ["combo_edge", "injuries", "broken_arm", "weapon_wear", "weapons", "disarm", "counter", "dizzy", "scenery"]
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
			hero.take_weapon("stick")
			_tough_dummy()
			length = 8 * 45 + 60
			for i in 9:
				steps.append([10 + i * 45, "hero", {"punch": true}, ""])
		"weapons":
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
		"scenery":
			length = 240


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
				_say("the hero takes the %s: %d hits in it" % [data[tick], Weapons.TABLE[data[tick]]["hits"]])
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
	for e in events:
		var t := ""
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
			_say(t)
	if name == "combo_edge" and data.has("pressed_at") and hero.attack_phase() == "startup" and hero.t == 0:
		var m: String = hero.state
		_say("pressed %d frames after the jab ended: %s" % [data["pressed_at"], "the CROSS (the chain goes on)" if m == "cross" else "a JAB (a new chain)"])
		data.erase("pressed_at")
	if name == "broken_arm" and tick == 131:
		_say("A with the pipe in hand: %s" % ("a JAB, not a swing (a broken arm can't swing it)" if hero.state == "punch" else hero.state.to_upper()))


func _say(t: String) -> void:
	note = t
	note_left = 90
	history.append("frame %d: %s" % [tick, t])


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
		"dizzy":
			line = "combo finishers landed in a row: %d  ·  dizzy: %s  ·  frames left: %d of %d" % [dummy.finishers_taken,
				"YES" if dummy.state == "dizzy" else "no", dummy.dizzy_left, dummy.tune["dizzy_ticks"]]
		"scenery":
			var parts := []
			for k in street_speeds:
				parts.append("%s %.2f" % [k, street_speeds[k]])
			line = "camera: 6.00 px a frame  ·  layers on screen, px a frame: " + ", ".join(parts)
	return ("TRIAL: %s   ·   frame %d\n" % [name, tick]) + line + ("\n" + note if note_left > 0 else "")
