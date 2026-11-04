extends RefCounted
## The testers' start-to-result proofs (their send-backs, 2026-11-04: "one unbroken sequence, start frame through the
## outcome, numbers on screen"): each a scripted run on a real level where one trick happens once, from its first
## frame to its result. The log marks the two ends ("frame N: START ...", "frame M: END ..."), and scripts/trials.sh
## lays out every frame between them, in order, pages of 60. main.gd plays one with --level <file> --scene proof_<name>.
##
## proof_headbutt  the Wrench Mechanic ducks the side kick (K K K's end) and comes up with a headbutt
## proof_doorman   a jab off the riot shield, then a low kick into his bash knocks the shield aside and lands
## proof_dancer    a pipe swing she slips on her skates; K K K knocks her off them; the same swing then lands
## proof_enforcer  the jab caught on his blade, and his cut straight back
## proof_lookout   the lookout whistles, and the two goons he calls walk in to the hero
## proof_grabber   the bear hug through the hero's guard, three quick punches, free, the Grabber off balance
## proof_swap      Twin Loans' whole combo: it starts, they swap places halfway, it ends
## proof_shove     a push kick on the stairs: the enemy tumbles to the foot and lies there
## proof_climb     a Twin Loans brother shoved down the stairs, climbing all the way back up (slowly)
## proof_escape    the hero walks down the flight and off its foot, back onto the street

const NAMES := ["proof_headbutt", "proof_doorman", "proof_dancer", "proof_enforcer", "proof_lookout", "proof_grabber",
	"proof_swap", "proof_shove", "proof_climb", "proof_escape"]
const StreetWorld := preload("res://scripts/sim/street_world.gd")
const Fighter := preload("res://scripts/sim/fighter.gd")

var name: String
var tick := 0
var length := 900
var note := ""
var note_left := 0
var history := []
var next_level := ""  # (main.gd asks; proofs stay on their level)
var zoom := 1.6
var foe: Dictionary = {}  # the enemy entry the proof is about
var other: Dictionary = {}
var started := -1
var ended := -1
var seen_tick := -1
var data := {}


func _init(proof: String) -> void:
	name = proof


func setup(level) -> void:
	var h = level.hero
	match name:
		"proof_headbutt":
			foe = _bring(level, "wrench_mechanic", h.x + 120.0)
		"proof_doorman":
			foe = _bring(level, "doorman", h.x + 110.0)
		"proof_dancer":
			h.take_weapon("pipe")
			foe = _bring(level, "neon_dancer", h.x + 110.0)
		"proof_enforcer":
			foe = _bring(level, "enforcer", h.x + 120.0)
		"proof_lookout":
			foe = _bring(level, "lookout", h.x + 500.0)
			zoom = 1.0
		"proof_grabber":
			foe = _bring(level, "grabber", h.x + 220.0)
		"proof_swap":
			level._go_to(1, 300.0)
			level.step({})
			foe = level.enemies.filter(func(e): return e["kind"] == "twin_short")[0]
			other = level.enemies.filter(func(e): return e["kind"] == "twin_tall")[0]
			other["f"].x = level.hero.x + 320.0
			other["f"].y = 0.0
			other["f"].z = level.hero.z
			foe["f"].x = level.hero.x + 130.0
			foe["f"].z = level.hero.z
			foe["brain"].wait = 30
			zoom = 1.3
		"proof_shove":
			_on_flight(level, h, 1600.0)
			h.facing = -1
			foe = _bring(level, "thug", 1490.0, 15.0)
			zoom = 1.0
		"proof_climb":
			level._go_to(1, 300.0)
			level.step({})
			var short: Dictionary = level.enemies.filter(func(e): return e["kind"] == "twin_short")[0]
			short["f"].health = 0.0
			short["f"]._enter("ko")  # just the one brother here
			foe = level.enemies.filter(func(e): return e["kind"] == "twin_tall")[0]
			_on_flight(level, h, 1450.0)
			h.facing = -1
			foe["f"].x = 1340.0
			foe["f"].y = StreetWorld.step_height(_flight(level), 1340.0)
			foe["f"].z = 15.0
			foe["f"].facing = 1
			foe["brain"].wait = 9999
			foe["brain"].dormant_until_within = 1.0  # still till the shove lands (no guard up)
			zoom = 0.8
			length = 1100
		"proof_escape":
			_on_flight(level, h, 1500.0)
			h.facing = -1
			foe = _bring(level, "thug", 1880.0, 15.0)  # one up on the landing above him
			zoom = 1.0


## An enemy placed (on a flight if it's there), facing the hero, standing still till the script lets him go.
func _bring(level, kind: String, x: float, z := -1.0) -> Dictionary:
	level._spawn(kind, x, level.hero.z if z < 0.0 else z)
	var e: Dictionary = level.enemies[-1]
	e["brain"].wait = 9999
	e["brain"].dormant_until_within = 1.0
	e["f"].facing = -1 if e["f"].x > level.hero.x else 1
	return e


func _flight(level) -> Dictionary:
	return level.world.objects.filter(func(o): return o["kind"] == "stairs")[0]


func _on_flight(level, f, x: float) -> void:
	f.x = x
	f.z = 15.0
	f.y = StreetWorld.step_height(_flight(level), x)


func _start(t: String) -> void:
	if started < 0:
		started = tick
		_say("START: " + t)


func _end(t: String) -> void:
	if started >= 0 and ended < 0:
		ended = tick
		_say("END: " + t)
		length = tick + 60


func _say(t: String) -> void:
	note = t
	note_left = 120
	history.append("frame %d: %s" % [tick, t])


## This frame's input for the hero, and what the proof's enemy is let do.
func inputs(level) -> Dictionary:
	tick += 1
	var inp := {}
	var h = level.hero
	var fresh: bool = level.tick != seen_tick
	seen_tick = level.tick
	var evs: Array = level.events if fresh else []
	var f = foe.get("f")
	match name:
		"proof_headbutt":
			if tick == 19:
				_start("K K K at the Wrench Mechanic; the side kick at the end goes to his face")
			if tick >= 20:
				_kkk(level, inp)  # (stepping back in between kicks: they drive him back)
			if data.get("kicks", 0) >= 3 and not data.has("on"):
				data["on"] = true
				foe["brain"].dormant_until_within = 0.0  # (his brain on: a duck lines up his headbutt)
			for ev in evs:
				if ev.get("target") == f and ev.get("attacker") == h:
					_say("the %s: %s" % [ev.get("move", ""), ev["result"].to_upper()])
				if ev.get("attacker") == f and ev.get("move", "") == "headbutt":
					_end("up out of the duck, his HEADBUTT: %s" % ev["result"].to_upper())
			if tick > 200 and ended < 0:
				_end("no headbutt came (the proof failed)")
		"proof_doorman":
			if tick == 9:
				_start("a jab straight at the Doorman's riot shield")
			if tick == 10:
				inp["punch"] = true
			if tick == 70:
				foe["brain"].dormant_until_within = 0.0
				foe["brain"].plan = ["punch"]  # his shield bash
			if tick == 71:
				inp["kick"] = true  # the low kick, into the bash as it winds up
			for ev in evs:
				if ev.get("target") == f and ev.get("attacker") == h:
					_say("the %s: %s%s" % [ev.get("move", ""), ev["result"].to_upper(), "  ·  the SHIELD knocked aside" if ev.get("drop", "") == "shield" or f.weapon == "" else ""])
					if ev["move"] == "kick" and f.weapon == "":
						_end("the low kick into his bash: the shield's knocked aside and the kick %s" % ev["result"].to_upper())
			if tick > 200 and ended < 0:
				_end("the shield held (the proof failed)")
		"proof_dancer":
			if tick == 9:
				_start("a pipe swing at the Neon Dancer on her skates")
			if tick == 10:
				inp["punch"] = true
			if tick >= 60 and not data.has("off"):
				_kkk(level, inp)  # K K K: the side kick knocks her off her feet
			if data.has("up_at") and tick == data["up_at"]:
				inp["punch"] = true  # the same pipe swing again
			if not data.has("off") and not f.too_quick:
				data["off"] = tick
				_say("knocked off her feet: the SKATES are off")
			if data.has("off") and not data.has("up_at") and f.state in Fighter.GROUND_STATES:
				data["up_at"] = tick + 4
				if absf(f.x - h.x) > 130.0:
					data["walk"] = true
			if data.get("walk", false) and absf(f.x - h.x) > 120.0 and not data.has("swung"):
				inp["mx"] = signf(f.x - h.x)
				data["up_at"] = tick + 1
			for ev in evs:
				if ev.get("target") == f and ev.get("attacker") == h:
					_say("the %s: %s" % [ev.get("move", ""), ev["result"].to_upper()])
					if ev["move"] == "swing" and data.has("off"):
						data["swung"] = true
						_end("off her skates, the same pipe swing: %s" % ev["result"].to_upper())
			if tick > 500 and ended < 0:
				_end("(the proof ran out of time)")
		"proof_enforcer":
			if tick == 9:
				_start("a jab at the Enforcer")
			if tick == 10:
				inp["punch"] = true
				foe["brain"].dormant_until_within = 0.0
			for ev in evs:
				if ev.get("target") == f and ev.get("attacker") == h:
					_say("the jab: %s on his blade" % ev["result"].to_upper())
				if ev.get("attacker") == f and ev.get("target") == h:
					_end("his cut straight back: %s" % ev["result"].to_upper())
			if tick > 200 and ended < 0:
				_end("no cut came back (the proof failed)")
		"proof_lookout":
			for ev in evs:
				if ev.get("result", "") == "whistle":
					_start("the lookout WHISTLES: two goons called")
			if started >= 0 and ended < 0:
				var called: Array = level.enemies.filter(func(e): return e["kind"] == "glow_punk")
				if called.size() >= 2 and called.all(func(e): return absf(e["f"].x - h.x) < 360.0):
					_end("both goons he called are at the hero (one in, one waiting his turn)")
			inp["block"] = true
			if tick > 800 and ended < 0:
				_end("(the goons didn't arrive in time)")
		"proof_grabber":
			if tick == 9:
				_start("the Grabber steps in on the hero's guard")
				foe["brain"].dormant_until_within = 0.0
				foe["brain"].wait = 0
			inp["block"] = h.state != "held" and not data.has("held")
			if h.state == "held" and not data.has("held"):
				data["held"] = tick
				_say("the BEAR HUG, right through the guard")
			if data.has("held") and tick in [data["held"] + 6, data["held"] + 12, data["held"] + 18]:
				inp["punch"] = true
			if data.has("held") and h.state != "held" and not data.has("free"):
				data["free"] = tick
				_say("three quick punches: FREE")
			if data.has("free") and f.state == "stagger":
				_end("the Grabber's off balance (stagger)")
			if tick > 300 and ended < 0:
				_end("(the proof ran out of time)")
		"proof_swap":
			inp["block"] = true
			var b = foe["brain"]
			if started < 0 and not b.plan.is_empty():
				_start("the short brother starts his combo; the tall one guards")
			for ev in evs:
				if ev.get("result", "") == "swap":
					_say("halfway through: they SWAP places")
			if started >= 0 and ended < 0 and tick > started + 4 and b.plan.is_empty() and f.attack_phase() == "" \
					and other["brain"].plan.is_empty() and other["f"].attack_phase() == "":
				_end("the combo's over")
			if tick > 400 and ended < 0:
				_end("(the proof ran out of time)")
		"proof_shove":
			if tick == 9:
				_start("P P K at the enemy below him on the stairs")
			if tick in [10, 22, 34]:
				inp[["punch", "punch", "kick"][[10, 22, 34].find(tick)]] = true
			if level.tumbling.has(f) and not data.has("tumble"):
				data["tumble"] = tick
				_say("the push kick: he TUMBLES down the flight")
			if data.has("tumble") and not level.tumbling.has(f) and f.state in ["down", "ko"]:
				_end("at the foot of the stairs, down (%.0f px up: on the street)" % f.y)
			if tick > 300 and ended < 0:
				_end("(the proof ran out of time)")
		"proof_climb":
			if tick == 9:
				_start("P P K at the tall brother on the stairs")
			if tick in [10, 22, 34]:
				inp[["punch", "punch", "kick"][[10, 22, 34].find(tick)]] = true
			if level.tumbling.has(f) and not data.has("tumble"):
				data["tumble"] = tick
				_say("he TUMBLES to the foot")
				foe["brain"].wait = 0
				foe["brain"].dormant_until_within = 0.0
			if data.has("tumble") and f.state in Fighter.GROUND_STATES and not data.has("climb"):
				data["climb"] = tick
				_say("up again, he starts back up the stairs, slowly")
			if data.has("climb") and f.y >= 300.0:
				_end("he's back up (%.1f seconds after the tumble)" % ((tick - data["tumble"]) / 60.0))
			inp["block"] = tick > 40
			if tick > 1050 and ended < 0:
				_end("(the proof ran out of time)")
		"proof_escape":
			if tick == 9:
				_start("the hero, halfway up the flight, an enemy on the landing above: down he goes")
			if tick >= 10 and ended < 0:
				inp["mx"] = -1.0
				if h.y < 1.0 and h.x < _flight(level)["x0"] - 40.0:
					inp["mz"] = 1.0  # off the foot, back out into the street
					if h.z > 60.0:
						_end("off the stairs, on the street (%.0f px out into it)" % h.z)
			if tick > 400 and ended < 0:
				_end("(the proof ran out of time)")
	return inp


## K K K at the proof's enemy, one press as each kick ends, stepping back in when the last drove him out of reach (the
## chain allows the step: a press inside the combo window still continues it).
func _kkk(level, inp: Dictionary) -> void:
	var h = level.hero
	var f = foe["f"]
	if h.state in ["kick", "body_kick", "side_kick"] and h.attack_serial != data.get("serial", -1):
		data["serial"] = h.attack_serial  # a kick thrown (a press too soon after the last one is dropped: not counted)
		data["kicks"] = data.get("kicks", 0) + 1
	if data.get("kicks", 0) >= 3 or not h.state in Fighter.GROUND_STATES:
		return
	if absf(f.x - h.x) > 115.0:
		inp["mx"] = signf(f.x - h.x)
		return
	if h.facing != (1 if f.x >= h.x else -1):
		inp["mx"] = signf(f.x - h.x) * 0.01
		return
	inp["kick"] = true


## The numbers on screen.
func overlay(level) -> String:
	if note_left > 0:
		note_left -= 1
	var h = level.hero
	var f = foe.get("f")
	var line := "hero: %s, health %.1f, %.0f px up" % [h.state, h.health, h.y]
	if f != null:
		line += "  ·  %s: %s, health %.1f, %.0f px up%s" % [foe.get("kind", ""), f.state, f.health, f.y,
			", weapon %s" % f.weapon if f.weapon != "" else ""]
	if name == "proof_dancer" and f != null:
		line += "  ·  skates: %s" % ("ON (too quick for slow weapons)" if f.too_quick else "OFF")
	if name == "proof_swap" and not other.is_empty():
		line += "\n%s: x %.0f  ·  %s: x %.0f  ·  the hero at x %.0f" % [foe["kind"], foe["f"].x, other["kind"], other["f"].x, h.x]
	if name == "proof_lookout":
		var called: Array = level.enemies.filter(func(e): return e["kind"] == "glow_punk")
		line += "  ·  called: %d, nearest %s px off" % [called.size(), str(int(called.map(func(e): return absf(e["f"].x - h.x)).min())) if not called.is_empty() else "-"]
	return ("PROOF: %s   ·   frame %d%s\n" % [name.trim_prefix("proof_"), tick,
		"   ·   sequence frame %d" % (tick - started) if started >= 0 and ended < 0 else ""]) + line + ("\n" + note if note_left > 0 else "")
