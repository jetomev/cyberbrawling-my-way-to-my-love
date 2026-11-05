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
## proof_coach     Coach Crusher's tackle stepped aside, into the ropes, then the hero finishes him (kicks only)
## proof_chrome    three kicks into Madame Chrome's cane wind-ups: the cane breaks, and she's done
## proof_crane     the crane's third switch, the cab door opening, into the cab, the fight, the push kick out
## proof_static    a kick into Mr. Static's wind-up knocks the baton loose; P P K by the tank shorts him out; finished
## proof_rook      both door switches smashed (Checkmate calls nobody); three perfect blocks on his last cut: the sword
##                 breaks
## proof_ropes     Coach Crusher's tackle stepped aside: he hits the ropes, they give, he bounces back off them, dazed
## proof_cab       in the crane's cab with a pipe: no room to swing (a punch comes out) while he fights back; P P K
##                 shoves him out of the cab, over the side
## proof_gap       level 4's balcony: the hero walks into the railing gap and the edge holds him; then P P K on a Wrench
##                 Mechanic standing in the gap: over the low bar he goes, down to the ring hall, out of the fight
## proof_bag       level 4's punching bag: a jab swings it into the Mechanic standing behind it, knocked down
## proof_above     level 4's ring hall under the balcony: a wrench thrown down lands on the hero standing still; he
##                 steps out of the next one's shadow and it clangs on the floor
## proof_signs     a level's signs on its ground floor, one after another (the hero set under each, a second each)
## proof_run_F<f>s<s>   the robot's own run (the seed from --seed, as in the balance numbers), fast-forwarded unseen to
##                 floor f's screen s, then every frame of it there: from walking in till he leaves it or the level is
##                 lost, every enemy's health and the hero's lives on screen (the testers on ea9e996: "each whole
##                 encounter, start to finish", and where the robot's failed finishes go wrong)
## (The boss proofs start their boss part-worn where a whole fight would run to many pages: said so on screen.)

const NAMES := ["proof_headbutt", "proof_doorman", "proof_dancer", "proof_enforcer", "proof_lookout", "proof_grabber",
	"proof_swap", "proof_shove", "proof_climb", "proof_escape", "proof_coach", "proof_chrome", "proof_crane", "proof_static",
	"proof_rook", "proof_ropes", "proof_cab", "proof_gap", "proof_bag", "proof_above", "proof_signs"]
const HeroBot := preload("res://scripts/sim/hero_bot.gd")
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
var bot = null


func _init(proof: String) -> void:
	name = proof


func setup(level) -> void:
	var h = level.hero
	if name.begins_with("proof_run_"):
		_run_setup(level)
		return
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
			# level 3's own Twin Loans shop, the hero in at the door, the bot playing him and rushing in (the testers: a
			# real fight); the brothers open with their swap (the team's third ruling)
			level._go_to(3, 150.0)
			level.step({})
			foe = level.enemies.filter(func(e): return e["kind"] == "twin_short")[0]
			other = level.enemies.filter(func(e): return e["kind"] == "twin_tall")[0]
			zoom = 1.0
			length = 900
			bot = HeroBot.new(h, 2)
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
			# Twin Loans' shop: the hero halfway up its stairs, both brothers on the landing above, rushing down at him
			level._go_to(1, 300.0)
			level.step({})
			foe = level.enemies.filter(func(e): return e["kind"] == "twin_tall")[0]
			other = level.enemies.filter(func(e): return e["kind"] == "twin_short")[0]
			_on_flight(level, h, 1150.0)
			h.facing = -1
			for e in [foe, other]:
				e["f"].x = 1440.0 if e == foe else 1490.0
				e["f"].z = 15.0
				e["f"].y = 400.0
				e["brain"].wait = 0
			level.compound = true  # both at him at once (Compound), rushing down the flight
			zoom = 1.0
		"proof_coach", "proof_chrome", "proof_static", "proof_rook":
			var floor_of := {"proof_coach": 1, "proof_chrome": 2, "proof_static": 1, "proof_rook": 1}
			level._go_to(floor_of[name], 300.0)
			level.step({})
			var kind: String = {"proof_coach": "coach", "proof_chrome": "chrome", "proof_static": "static", "proof_rook": "rook"}[name]
			foe = level.enemies.filter(func(e): return e["kind"] == kind)[0]
			foe["brain"].wait = 9999
			foe["brain"].dormant_until_within = 0.0001  # (still, even with the hero walking past him)
			zoom = 1.2
			length = 2400
			if name in ["proof_coach", "proof_static"]:
				foe["f"].health = 10.0  # part-worn, so the finish comes in one sequence (said on screen)
			if name == "proof_coach":
				foe["f"].x = h.x + 420.0
				foe["f"].z = h.z
			if name == "proof_rook":
				foe["f"].x = 1800.0  # beyond the second door switch: the hero never walks across his spot
			if name == "proof_static":
				foe["f"].x = 1450.0  # by the water tank
				h.x = 1330.0
				foe["f"].z = h.z
		"proof_ropes":
			level._go_to(1, 300.0)
			level.step({})
			foe = level.enemies.filter(func(e): return e["kind"] == "coach")[0]
			foe["brain"].wait = 9999
			foe["brain"].dormant_until_within = 0.0001
			foe["f"].x = h.x + 420.0
			foe["f"].z = h.z
			zoom = 1.0
			length = 600
		"proof_cab":
			for i in 3:
				level.flipped[i] = true  # all three crane switches thrown, the cab open (said on screen)
			level._go_to(3, 150.0)
			level.step({})
			foe = level.enemies.filter(func(e): return e["kind"] == "crane_operator")[0]
			h.take_weapon("pipe")
			zoom = 1.2
			length = 2400
		"proof_signs":
			level.floors[0]["wave"] = level.floors[0]["waves"].size()  # (no fights: just the walls)
			data["signs"] = level.plan["floors"][0].get("signs", [])
			zoom = 1.0
			length = 30 + 70 * maxi(1, (data["signs"] as Array).size())
		"proof_above":
			level.floors[0]["wave"] = level.floors[0]["waves"].size()  # the ring hall's goon set aside
			h.x = 4300.0
			h.z = 80.0
			zoom = 1.2
			length = 500
		"proof_bag":
			level.floors[0]["wave"] = level.floors[0]["waves"].size()  # the weights room's goons set aside
			var bag: Dictionary = level.world.objects.filter(func(o): return o["kind"] == "bag")[0]
			h.drop_weapon()  # (empty-handed: a plain jab)
			h.x = bag["x0"] - 60.0
			h.z = 40.0
			h.facing = 1
			foe = _bring(level, "wrench_mechanic", bag["x1"] + 50.0, 40.0)
			zoom = 1.4
			length = 400
		"proof_gap":
			level._go_to(1, 2700.0, 0.0, 120.0)
			level.floors[1]["wave"] = level.floors[1]["waves"].size()  # the balcony's goons set aside: just the one in the gap
			level.step({})
			h.drop_weapon()  # (empty-handed, so P P K ends in the push kick: the stick he walks in with would swing)
			foe = _bring(level, "wrench_mechanic", 2900.0, level.tune["street_depth"])
			var k: Dictionary = foe["brain"].kind.duplicate()
			k["block_chance"] = 0.0  # (for this picture he doesn't block: said on screen)
			foe["brain"].kind = k
			zoom = 1.2
			length = 900
		"proof_crane":
			level.flipped[0] = true  # the quay's and the stack's switches already thrown (said on screen)
			level.flipped[1] = true
			level._go_to(2, 950.0)
			level.step({})
			zoom = 1.0
			length = 2400
			bot = HeroBot.new(h, 1)


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
	if name.begins_with("proof_run_"):
		return _run_inputs(level, evs)
	match name:
		"proof_ropes":
			if tick == 9:
				_start("Coach Crusher's tackle: the hero steps out of his line")
				level._coach(foe, {"tackle": true})
			if (foe.has("tackle") or foe.get("tackle_next", false)) and h.state in ["idle", "walk", "block"]:
				inp["mz"] = 1.0 if h.z < 130.0 else 0.0
			for ev in evs:
				match ev.get("result", ""):
					"ropes":
						_say("he slams into the ROPES: they give")
					"rebound":
						data["rebound"] = tick
						_say("and BOUNCE him back into the ring: he stands dazed, open (K K K now)")
			if data.has("rebound") and tick >= data["rebound"] + 12:
				_end("dazed off the ropes, %.0f px back into the ring" % absf(f.x - (level.ropes().x if level.rope_hit.get("side", 1.0) < 0.0 else level.ropes().y)))
			if tick > 500 and ended < 0:
				_end("(no rebound came: the proof ran out of time)")
		"proof_cab":
			if tick == 9:
				_start("in the crane's cab, a pipe in his hand, the Crane Operator fighting back")
			for ev in evs:
				var r: String = ev.get("result", "")
				if r == "horn":
					data["resisted"] = data.get("resisted", 0) + 1
					_say("he RESISTS: his horn blasts the hero back")
				elif ev.get("target") == f and ev.get("attacker") == h and r in ["blocked", "perfect"]:
					data["resisted"] = data.get("resisted", 0) + 1
					_say("he RESISTS: blocks it")
				elif ev.get("attacker") == f and ev.get("target") == h and r == "hit":
					data["resisted"] = data.get("resisted", 0) + 1
					_say("he RESISTS: hits back")
				elif r == "shoved_out":
					_say("P P K: the push kick SHOVES him out of the cab")
				elif r == "out_of_cab":
					_end("OUT of the cab, over the side and gone: that's it")
			if h.state in ["punch", "cross", "power_punch"] and h.weapon == "pipe" and h.attack_serial != data.get("swing_serial", -1):
				data["swing_serial"] = h.attack_serial
				data["refused"] = data.get("refused", 0) + 1
				_say("no room to swing: the PIPE stays in his hand, a %s comes out (refused %d)" % [h.state.replace("_", " ").to_upper(), data["refused"]])
			if tick > 9 and (data.get("refused", 0) < 2 or data.get("resisted", 0) < 1) and h.weapon != "":
				inp = _swing_at(level, f)  # a weapon press each time he's in reach
			elif tick > 9 and not foe.has("shoved"):
				if not data.has("ppk"):
					data["ppk"] = true
					var k: Dictionary = foe["brain"].kind.duplicate()
					k["block_chance"] = 0.0  # (for the shove he stops blocking: said on screen, as in the crane proof)
					foe["brain"].kind = k
					foe["brain"].block_left = 0
					data["thrown"] = 0
					data["serial"] = h.attack_serial
					_say("now P P K at him (for this shove he stops blocking)")
				if h.state in ["kick", "body_kick", "side_kick"]:
					data["thrown"] = 0  # (the chain came out as kicks: start the P P K over)
					data["serial"] = h.attack_serial
				_combo(level, inp, ["punch", "punch", "kick"], ["punch", "cross", "push_kick"])
				if data.get("thrown", 0) >= 3 and h.state in Fighter.GROUND_STATES:
					data["thrown"] = 0
			if tick > 2300 and ended < 0:
				_end("(he wasn't shoved out: the proof ran out of time)")
		"proof_signs":
			var k: int = (tick - 10) / 70
			if tick == 9:
				_start("%d sign(s) on this level's street" % (data["signs"] as Array).size())
			if tick >= 10 and (tick - 10) % 70 == 0 and k < (data["signs"] as Array).size():
				h.x = float(data["signs"][k][0]) - 150.0
				_say("sign %d: %s" % [k + 1, (data["signs"][k][2] as String).replace("\n", " / ")])
			if tick == length - 25:
				_end("every sign shown")
		"proof_above":
			if tick == 9:
				_start("under the balcony: the two Mechanics up there throw wrenches down (shadow first)")
			if data.has("hit") and not level.from_above.is_empty() and absf(level.from_above[0]["x"] - h.x) < 70.0:
				inp["mx"] = 1.0  # the second one: out of its shadow
			for ev in evs:
				if ev.get("kind", "") == "wrench_from_above":
					if ev.get("result", "") == "hit" and not data.has("hit"):
						data["hit"] = tick
						_say("standing still: the wrench LANDS on him (health %.0f)" % h.health)
					elif ev.get("result", "") == "wrench_clang" and data.has("hit"):
						_end("out of its shadow: the next one CLANGS on the floor, missed")
			if tick > 480 and ended < 0:
				_end("(the proof ran out of time)")
		"proof_bag":
			if tick == 9:
				_start("the punching bag, a Mechanic standing behind it")
			if tick > 20 and not data.has("swung"):
				inp["punch"] = tick % 12 == 0
			for ev in evs:
				match ev.get("result", ""):
					"bag_swing":
						data["swung"] = tick
						_say("the jab SWINGS the bag, away from him")
					"hit":
						if ev.get("kind", "") == "bag" and ev.get("target") == f:
							_end("into the Mechanic behind it: KNOCKED DOWN (the bag doesn't break)")
			if tick > 350 and ended < 0:
				_end("(the bag never reached him: the proof ran out of time)")
		"proof_gap":
			if tick == 9:
				_start("the balcony's railing gap: the hero (empty-handed) walks into it")
			if tick > 9 and tick <= 70:
				inp["mz"] = 1.0  # straight at the front edge, in the gap
				inp["mx"] = 0.01 if tick < 20 else 0.0
				data["front"] = maxf(data.get("front", 0.0), h.z)
			elif tick == 71:
				_say("the edge HOLDS him: z %.0f of %.0f, still on the balcony (for him the gap's a wall)" % [data["front"], level.tune["street_depth"]])
			elif tick > 100 and not foe.has("over_rail"):
				if not data.has("ppk"):
					data["ppk"] = true
					data["thrown"] = 0
					data["serial"] = h.attack_serial
					_say("now P P K at the Mechanic standing in the gap (for this picture he doesn't block)")
				_combo(level, inp, ["punch", "punch", "kick"], ["punch", "cross", "push_kick"])
				if data.get("thrown", 0) >= 3 and h.state in Fighter.GROUND_STATES:
					data["thrown"] = 0
			for ev in evs:
				match ev.get("result", ""):
					"over_the_rail": _say("the push kick tips him OVER the low bar")
					"down_below": _end("down to the ring hall below: out of the fight, counted as beaten, nothing dropped")
			if tick > 850 and ended < 0:
				_end("(he never went over: the proof ran out of time)")
		"proof_coach":
			if tick == 9:
				_start("Coach Crusher's tackle: step out of his line, and he hits the ropes (he starts part-worn: 10 of 40)")
				level._coach(foe, {"tackle": true})
			if (foe.has("tackle") or foe.get("tackle_next", false)) and h.state in ["idle", "walk", "block"]:
				inp["mz"] = 1.0 if h.z < 130.0 else 0.0  # step out of his line, and stay out till he's past
			elif tick > 9 and not foe.has("tackle") and not foe.get("tackle_next", false):
				foe["brain"].dormant_until_within = 0.0
				inp = _kick_at(level, f)
			for ev in evs:
				match ev.get("result", ""):
					"ropes": _say("he slams into the ROPES: dazed, open (K K K now)")
					"gives_up": _say("dizzied twice: he GIVES UP")
			if f.defeated():
				_end("Coach Crusher's down")
		"proof_chrome":
			if tick == 9:
				_start("three kicks into Madame Chrome's cane wind-ups")
				foe["brain"].dormant_until_within = 0.0
				foe["brain"].wait = 0
			if tick > 9:
				if f.attack_phase() == "startup" and f.t <= 3 and absf(f.x - h.x) < 135.0 and h.state in Fighter.GROUND_STATES + ["block"]:
					inp = {"kick": true}  # into the wind-up, as it starts
				elif absf(f.x - h.x) > 110.0 or absf(f.z - h.z) > 8.0:
					inp = {"mx": signf(f.x - h.x) if absf(f.x - h.x) > 110.0 else 0.0, "mz": clampf((f.z - h.z) / 16.0, -1.0, 1.0)}
				else:
					inp = {"block": true}
			for ev in evs:
				if ev.get("attacker") == h and ev.get("target") == f and ev.get("counter", false) and ev.get("move", "") in level.KICKS:
					_say("a kick into her wind-up: %d of 3" % foe.get("cane_kicks", 0))
				if ev.get("result", "") == "cane_snaps":
					_end("the third: the CANE BREAKS, and she's done")
		"proof_static":
			if tick == 9:
				_start("Mr. Static by his water tank (part-worn: 10 of 40): a kick into his baton's wind-up")
				foe["brain"].dormant_until_within = 0.0
				foe["brain"].wait = 0
			if tick > 9:
				if f.weapon == "baton":
					if f.attack_phase() == "startup" and absf(f.x - h.x) < 190.0 and h.state in Fighter.GROUND_STATES + ["block"]:
						inp = {"kick": true}
					elif absf(f.x - h.x) > 150.0:
						inp = {"mx": signf(f.x - h.x)}
					else:
						inp = {"block": true}
				elif not data.has("shorted"):
					_combo(level, inp, ["punch", "punch", "kick"], ["punch", "cross", "push_kick"])  # P P K, into the tank behind him
					if data.get("thrown", 0) >= 3 and h.state in Fighter.GROUND_STATES:
						data["thrown"] = 0  # (not by the tank yet: again)
				else:
					inp = _kick_at(level, f)
			for ev in evs:
				if ev.get("attacker") == h and ev.get("target") == f and ev.get("drop", "") == "baton":
					_say("the kick into his wind-up: the BATON flies out of his hand")
				if ev.get("result", "") == "shorts_out":
					data["shorted"] = true
					_say("P P K into the WATER TANK: he SHORTS OUT, dizzy")
			if f.defeated():
				_end("Mr. Static's down")
		"proof_rook":
			var doors: Array = level.world.objects.filter(func(o): return o["kind"] == "door_switch")
			var up: Array = doors.filter(func(o): return not o["broken"])
			if tick == 9:
				_start("first both door switches smashed, then three perfect blocks on Velvet Rook's last cut")
			if tick > 9 and not up.is_empty():
				var o: Dictionary = up[0]
				var ox: float = o["x0"] - 50.0 if h.x < o["x0"] else o["x1"] + 50.0
				if absf(h.x - ox) > 8.0 or absf(h.z - 12.0) > 6.0:
					inp = {"mx": signf(ox - h.x) if absf(h.x - ox) > 8.0 else 0.0, "mz": clampf((12.0 - h.z) / 16.0, -1.0, 1.0)}
				else:
					h.facing = 1 if o["x0"] > h.x else -1
					inp = {"kick": tick % 18 == 0}
			elif tick > 9:
				if not data.has("doors_down"):
					data["doors_down"] = tick
					_say("both door switches SMASHED: his Enforcers can't come in")
				if tick == data["doors_down"] + 45:
					foe["brain"].dormant_until_within = 0.0  # (released once the hero's guard is up)
					foe["brain"].wait = 0
				# guard up, but dropped as his overhead starts and raised again 5 frames before it lands: a perfect block
				var late: bool = f.state == "smash" and f.t >= 4 and f.t <= 5
				inp = {} if late else {"block": absf(f.x - h.x) < 260.0}
				if absf(f.x - h.x) > 200.0:
					inp["mx"] = signf(f.x - h.x)
			for ev in evs:
				match ev.get("result", ""):
					"checkmate": _say("CHECKMATE: %d Enforcers come (the door switches are down)" % ev.get("called", 0))
					"perfect":
						if ev.get("attacker") == f and ev.get("move", "") == "smash":
							_say("a PERFECT block on his last cut: %d of 3" % foe.get("sword_blocks", 0))
					"sword_breaks": _end("the third: his SWORD BREAKS")
		"proof_crane":
			if tick == 9:
				_start("the crane's third switch, up top (the first two already thrown): the cab opens, into the cab")
			bot.me = h
			bot.goal = level.next_door()
			bot.goal_hit = level.goal_is_switch
			bot.jump_cue = level.crane_jump_cue()
			bot.dodge_x = level.shadow_cue()
			inp = bot.think(level.standing())
			var cab_op: Array = level.enemies.filter(func(e): return e["kind"] == "crane_operator" and not e["f"].defeated())
			if level.plan["floors"][level.on].get("cab", false) and not cab_op.is_empty():
				if foe.is_empty() or foe.get("kind", "") != "crane_operator":
					foe = cab_op[0]  # in the cab: P P K at him, on purpose (the push kick shoves him out)
					var k: Dictionary = foe["brain"].kind.duplicate()
					k["block_chance"] = 0.0  # (for this proof he doesn't raise his guard: said on screen)
					foe["brain"].kind = k
					_say("in the cab, P P K at him (for this picture he doesn't block)")
				inp = {}
				_combo(level, inp, ["punch", "punch", "kick"], ["punch", "cross", "push_kick"])
				if data.get("thrown", 0) >= 3 and h.state in Fighter.GROUND_STATES:
					data["thrown"] = 0
			for ev in evs:
				match ev.get("result", ""):
					"cab_open": _say("the third switch: the CAB door opens")
					"horn": _say("in the cab: his HORN shoves the hero back")
					"shoved_out": _end("P P K: SHOVED OUT of his cab, and that's it")
			var op: Array = level.enemies.filter(func(e): return e["kind"] == "crane_operator")
			if not op.is_empty() and op[0]["f"].defeated():
				_end("the Crane Operator's down (by blows in the cab, not the push kick)")
			if level.plan["floors"][level.on].get("cab", false) and not data.has("cab"):
				data["cab"] = true
				_say("into the cab: no room to swing a weapon")
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
			# the opening: from the frame the hero walks in to the hero's first blow landing after their opening combo
			bot.me = h
			bot.goal = level.next_door()
			inp = bot.think(level.standing())
			if tick == 2:
				_start("the hero walks into Twin Loans' shop, the robot playing him and going straight for them")
			for ev in evs:
				var r: String = ev.get("result", "")
				if r == "opening":
					data["opener"] = foe if ev.get("target") == foe["f"] else other
					_say("they OPEN: the %s brother starts his combo (nothing rocks him till they've swapped)" % [
						"short" if data["opener"]["kind"] == "twin_short" else "tall"])
				if r == "swap" and not data.has("crossing"):
					data["crossing"] = tick
					_say("his second blow starts: they CROSS, each walking to where the other stood")
				if r == "swapped" and not data.has("swapped"):
					data["swapped"] = tick
					_say("crossed: they've SWAPPED places (%d frames, %.1f s)" % [tick - data["crossing"], (tick - data["crossing"]) / 60.0])
			if data.has("swapped") and ended < 0:
				var w: Dictionary = data["opener"]
				if w["brain"].plan.is_empty() and w["f"].attack_phase() == "" and not data.has("over"):
					data["over"] = tick
					_say("their opening combo's over")
				if data.has("over") and (evs.any(func(ev): return ev.get("attacker") == h and ev.get("result", "") == "hit") \
						or tick > data["over"] + 120):
					_end("the hero's blow lands on a brother: from here a quick player can cut their combos short")
			if tick > 800 and ended < 0:
				_end("(no opening came: the proof ran out of time)")
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
				_start("the hero, halfway up Twin Loans' stairs, both brothers rushing down at him: down and off he goes")
			if tick >= 10 and ended < 0:
				inp["mx"] = -1.0
				if h.y < 1.0 and h.x < _flight(level)["x0"] - 40.0:
					inp["mz"] = 1.0  # off the foot, back out into the street
					if h.z > 60.0:
						_end("off the stairs, on the street (%.0f px out into it)" % h.z)
			if tick > 400 and ended < 0:
				_end("(the proof ran out of time)")
	return inp


## Kicks at a boss, stepping in to reach him and lining up with him (Coach Crusher's gloves take every punch).
## Steps into reach and presses punch now and then (with a weapon in hand that's a swing, where there's room).
func _swing_at(level, f) -> Dictionary:
	var h = level.hero
	var inp := {}
	if absf(f.x - h.x) > 110.0 or absf(f.z - h.z) > 8.0:
		inp["mx"] = signf(f.x - h.x) if absf(f.x - h.x) > 110.0 else 0.0
		inp["mz"] = clampf((f.z - h.z) / 16.0, -1.0, 1.0)
	elif h.facing != (1 if f.x >= h.x else -1):
		inp["mx"] = signf(f.x - h.x) * 0.01
	elif h.state in Fighter.GROUND_STATES and tick % 17 == 0:
		inp["punch"] = true
	return inp


func _kick_at(level, f) -> Dictionary:
	var h = level.hero
	var inp := {}
	if absf(f.x - h.x) > 110.0 or absf(f.z - h.z) > 8.0:
		inp["mx"] = signf(f.x - h.x) if absf(f.x - h.x) > 110.0 else 0.0
		inp["mz"] = clampf((f.z - h.z) / 16.0, -1.0, 1.0)
	elif h.facing != (1 if f.x >= h.x else -1):
		inp["mx"] = signf(f.x - h.x) * 0.01
	elif h.state in Fighter.GROUND_STATES and tick % 13 == 0:
		inp["kick"] = true
	return inp


## A three-press combo at the proof's enemy (presses, and the moves they throw), stepping in when he's out of reach.
func _combo(level, inp: Dictionary, presses: Array, moves: Array) -> void:
	var h = level.hero
	var f = foe["f"]
	if h.state in moves and h.attack_serial != data.get("serial", -1):
		data["serial"] = h.attack_serial  # a blow thrown (a press too soon after the last one is dropped: not counted)
		data["thrown"] = data.get("thrown", 0) + 1
	if data.get("thrown", 0) >= 3 or not h.state in Fighter.GROUND_STATES:
		return
	if absf(f.x - h.x) > 115.0 or absf(f.z - h.z) > 8.0:
		inp["mx"] = signf(f.x - h.x) if absf(f.x - h.x) > 115.0 else 0.0
		inp["mz"] = clampf((f.z - h.z) / 16.0, -1.0, 1.0)
		return
	if h.facing != (1 if f.x >= h.x else -1):
		inp["mx"] = signf(f.x - h.x) * 0.01
		return
	inp[presses[data.get("thrown", 0)]] = true


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
## The robot's run: the seed (main.gd's --seed), the room it's headed for ("F1s2": floor 1, screen 2).
const RUN_MAX := 45000  # (as the balance numbers: twelve minutes, then it's given up)
const RUN_SCREEN := 1920.0


func _run_where(level) -> String:
	return "F%ds%d" % [level.on, int(level.hero.x / RUN_SCREEN) + 1]


func _run_cues(level) -> void:
	bot.me = level.hero
	bot.goal = level.next_door()
	bot.goal_hit = level.goal_is_switch
	bot.jump_cue = level.crane_jump_cue()
	bot.dodge_x = level.shadow_cue()


func _run_setup(level) -> void:
	var args := OS.get_cmdline_user_args()
	var si := args.find("--seed")
	data["seed"] = int(args[si + 1]) if si >= 0 and si + 1 < args.size() else 1
	data["room"] = name.trim_prefix("proof_run_")
	bot = HeroBot.new(level.hero, data["seed"])
	zoom = 1.0
	for i in RUN_MAX:  # unseen, exactly the balance numbers' loop, till he walks into the room
		if level.won or level.lost or _run_where(level) == data["room"]:
			break
		_run_cues(level)
		level.step(bot.think(level.standing()))
	data["found"] = _run_where(level) == data["room"] and not level.lost
	data["lives"] = level.lives
	data["health"] = level.hero.health
	length = RUN_MAX if data["found"] else 120


func _run_inputs(level, evs: Array) -> Dictionary:
	var h = level.hero
	if tick == 1:
		if data["found"]:
			_start("the robot (seed %d) walks into %s: health %.0f, lives %d (it got here unseen, as in the balance numbers)" % [
				data["seed"], data["room"], data["health"], data["lives"]])
		else:
			_start("(the robot, seed %d, never reached %s: %s)" % [data["seed"], data["room"], "the level was lost first" if level.lost else "the level was won first"])
			_end("nothing to show")
	if level.lives < data["lives"]:
		data["lives"] = level.lives
		_say("a LIFE LOST in %s (%d left)" % [data["room"], level.lives])
	if ended < 0 and started >= 0 and tick > 1:
		if level.lost:
			_end("the level is LOST here (no lives left)")
		elif level.won:
			_end("the level is WON")
		elif _run_where(level) != data["room"]:
			_end("he walks out of %s into %s: health %.0f, lives %d" % [data["room"], _run_where(level), h.health, level.lives])
	_run_cues(level)
	return bot.think(level.standing())


func overlay(level) -> String:
	if note_left > 0:
		note_left -= 1
	var h = level.hero
	if name.begins_with("proof_run_"):
		var up: Array = level.enemies.filter(func(e): return not e["gone"] and not e["f"].defeated())
		var line := "hero: %s, health %.0f of %.0f, lives %d, weapon %s  ·  %s, x %.0f" % [h.state, h.health, h.max_health,
			level.lives, h.weapon if h.weapon != "" else "none", _run_where(level), h.x]
		var who := up.map(func(e): return "%s %s %.0f%s" % [e["kind"], e["f"].state, e["f"].health,
			" (whistled in)" if e.get("whistled", false) else ""])
		line += "\nup: %s" % (", ".join(who) if not who.is_empty() else "nobody")
		return ("PROOF: robot run %s, seed %d   ·   frame %d%s\n" % [data.get("room", ""), data.get("seed", 1), tick,
			"   ·   sequence frame %d" % (tick - started) if started >= 0 and ended < 0 else ""]) + line + ("\n" + note if note_left > 0 else "")
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
	if name in ["proof_coach", "proof_static"]:
		line += "  ·  (he starts part-worn, 10 of 40: the whole fight would run to many pages)"
	if name == "proof_cab":
		line += "  ·  in hand: %s  ·  swings refused %d  ·  he resisted %d" % [h.weapon if h.weapon != "" else "nothing", data.get("refused", 0), data.get("resisted", 0)]
	if name == "proof_crane":
		line += "  ·  %s  ·  switches thrown %d of 3" % [level.where, level.flipped.size()]
	if name == "proof_rook" and f != null:
		line += "  ·  door switches standing %d  ·  perfect blocks on his last cut %d of 3" % [
			level.world.objects.filter(func(o): return o["kind"] == "door_switch" and not o["broken"]).size(), foe.get("sword_blocks", 0)]
	if name == "proof_chrome" and f != null:
		line += "  ·  kicks into the cane's wind-up %d of 3" % foe.get("cane_kicks", 0)
	return ("PROOF: %s   ·   frame %d%s\n" % [name.trim_prefix("proof_"), tick,
		"   ·   sequence frame %d" % (tick - started) if started >= 0 and ended < 0 else ""]) + line + ("\n" + note if note_left > 0 else "")
