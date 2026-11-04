extends RefCounted
## Controlled trials for the testers (their ask, 2026-11-03: "short scripted clips where one thing happens on purpose
## and the number is on screen"). Each trial is the hero and a practice dummy (a thug who only does what the script
## says) on a bare street, a script of presses for both, and a line of numbers drawn on screen every frame. main.gd
## plays one with --trial <name>; scripts/trials.sh records them all into every build.
##
## combo_edge   a jab, then the next press 23, 24 and 25 frames after it ends: the cross (the chain goes on) or a jab
##              again (a new chain); the setting is combo_window_ticks
## injuries     low kicks on one leg: bruised at 2, swollen at 5, broken at 9; then the dummy walks: a limp
## weapon_wear  a stick (8 hits) swung at the dummy until it breaks
## disarm       a perfect block knocks his pipe loose; then a counter (a jab as he winds up) knocks a second one loose
## dizzy        two three-punch combos in a row: dazed for 150 frames
## scenery      the camera pans at 6 px a frame: each layer's speed on screen

const Fighter := preload("res://scripts/sim/fighter.gd")

const NAMES := ["combo_edge", "injuries", "weapon_wear", "disarm", "dizzy", "scenery"]

var name: String
var hero
var dummy
var tick := 0
var length := 0
var steps := []  # [tick, who ("hero"/"dummy"), input, note]
var note := ""  # what just happened, kept on screen a moment
var note_left := 0
var history := []  # every note with its frame, printed at the end
var data := {}  # numbers a trial keeps (the frame a blow ended, …)


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
			dummy.health = 999.0
			dummy.max_health = 999.0
			length = 520
			for i in 6:
				steps.append([10 + i * 50, "hero", {"kick": true}, ""])
		"weapon_wear":
			hero.take_weapon("stick")
			dummy.health = 999.0
			dummy.max_health = 999.0
			length = 8 * 45 + 60
			for i in 9:
				steps.append([10 + i * 45, "hero", {"punch": true}, ""])
		"disarm":
			dummy.take_weapon("pipe")
			dummy.health = 999.0
			dummy.max_health = 999.0
			length = 300
			steps.append([10, "dummy", {"punch": true}, ""])  # he swings the pipe; the hero's guard goes up just in time
			steps.append([160, "dummy", {"kick": true}, ""])  # then (a second pipe) a kick that the hero's jab beats
			steps.append([158, "hero", {"punch": true}, ""])  # the jab lands on frame 162, while his kick is still winding up
		"dizzy":
			dummy.health = 999.0
			dummy.max_health = 999.0
			length = 420
			for i in 6:
				steps.append([10 + i * 16 + (40 if i >= 3 else 0), "hero", {"punch": true}, ""])
		"scenery":
			length = 240


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
	if name in ["injuries", "weapon_wear", "dizzy"] and h.is_empty() and hero.state in ["idle", "walk"] and tick <= 330 \
			and absf(dummy.x - hero.x) > 100.0 and dummy.hittable():
		h["mx"] = signf(dummy.x - hero.x)
	match name:
		"disarm":
			if tick == 10 + 5:
				data["guard"] = true  # the hero raises his guard 5 frames into the swing: perfect when it lands
			if tick >= 15 and tick < 60:
				h["block"] = true
			if tick == 130:
				dummy.take_weapon("pipe")  # a second pipe, for the counter
		"injuries":
			if tick > 330:
				d["mx"] = 1.0  # the dummy walks away from the hero on his broken leg
				if tick == 331:
					data["walk_from"] = dummy.x
	return [h, d]


## What a fight event means here, put on screen for a moment.
func saw(events: Array) -> void:
	for e in events:
		var t := ""
		if e["result"] == "perfect":
			t = "PERFECT BLOCK"
		elif e["counter"]:
			t = "COUNTER"
		elif e["result"] == "hit":
			t = "HIT: %s" % e["move"]
		if e["drop"] != "":
			t += "  ·  %s knocked loose" % e["drop"]
		if e["broke"] != "":
			t += "  ·  %s BROKEN" % e["broke"]
		if e["worn"] != "":
			t += "  ·  the %s BREAKS (worn out)" % e["worn"]
		if t != "":
			_say(t)
	if name == "combo_edge" and data.has("pressed_at") and hero.attack_phase() == "startup" and hero.t == 0:
		var m: String = hero.state
		_say("pressed %d frames after the jab ended: %s" % [data["pressed_at"], "the CROSS (the chain goes on)" if m == "cross" else "a JAB (a new chain)"])
		data.erase("pressed_at")


func _say(t: String) -> void:
	note = t
	note_left = 75
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
		"weapon_wear":
			line = "hero holds: %s  ·  hits left: %d of %d  ·  a swing uses 1, the smash 2" % [hero.weapon if hero.weapon != "" else "nothing (fists)",
				hero.weapon_hits_left, 8]
		"disarm":
			line = "dummy holds: %s  ·  hero's guard: %s (perfect for its first %d frames)" % [dummy.weapon if dummy.weapon != "" else "nothing",
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
