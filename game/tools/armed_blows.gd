extends SceneTree
## Every armed blow, weapon by weapon, for the testers (their ask on 67ca654: close-ups of the grips and the armed
## blocks; every changed blow through contact, landing and recovery; the knee and the uppercut labelled apart; the spins
## and return cuts through to their finish). Run windowed through scripts/armed_blows.sh, which records every frame and
## cuts sheets and clips from the segment lines this prints: "SEG <weapon> <name> <first frame> <last frame> <label>".
## Javier & Claude.

const Poses := preload("res://scripts/present/poses.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")
const Weapons := preload("res://scripts/sim/weapons.gd")
const Moves := preload("res://scripts/sim/moves.gd")
const HeroView := preload("res://scripts/present/hero_view.gd")

const WEAPONS := ["knife", "stick", "pipe", "wrench", "bat", "baguette", "sword", "lovelight"]
const HOLD := 24  # frames a grip or a block close-up holds
const CLOSE := 4.4  # how big a close-up draws him
const PAD := 6  # Ready frames before and after each blow
## Each punch-side press armed, and what it's called in the combos (Weapons.ARMED).
const PRESSES := {"swing": "P, 1st (the jab's place)", "backswing": "P P, 2nd (the cross's place)",
	"smash": "P P P, the finisher (the power punch's place)", "rising_swing": "P K P, 3rd: the uppercut",
	"handle_jab": "K P, 2nd: the elbow", "chop": "jump + P"}
## The kick-side presses, in case the weapon's weight turns them into strikes (Weapons.kick_armed).
const KICK_PRESSES := {"knee": "P K, 2nd: the knee", "body_kick": "K K, 2nd: the body kick",
	"side_kick": "K K K, the finisher: the side kick", "roundhouse": "K P K, the finisher: the roundhouse",
	"air_kick": "jump + K: the flying kick"}

var segments := []  # [weapon, name, label, kind ("grip", "block", "blow", "kick"), state, length, air]
var seg := 0
var tick := 0
var frame := 0
var view
var label: Label
var tune := Tuning.fresh()


func _initialize() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	stage.z_index = -10
	var sky := ColorRect.new()
	sky.color = Color(0.17, 0.17, 0.21)
	sky.size = Vector2(1280, 720)
	stage.add_child(sky)
	var ground := ColorRect.new()
	ground.color = Color(0.32, 0.32, 0.36)
	ground.position = Vector2(0, 600)
	ground.size = Vector2(1280, 120)
	stage.add_child(ground)
	view = HeroView.new()
	view.z_index = 10
	root.add_child(view)
	label = Label.new()
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 22)
	root.add_child(label)
	for w in WEAPONS:
		segments.append([w, "grip", "%s: the grip, Ready (close up)" % w.to_upper(), "grip", "idle", HOLD, false])
		segments.append([w, "block", "%s: the block (close up)" % w.to_upper(), "block", "block", HOLD, false])
		var done := {}
		for state in PRESSES:
			var who := [PRESSES[state]]
			for k in KICK_PRESSES:  # the kicks this weapon turns into this same strike
				if Weapons.kick_armed(k, w) == state:
					who.append(KICK_PRESSES[k] + "'s place")
			done[state] = true
			segments.append([w, state, "%s · %s: %s" % [w.to_upper(), state.replace("_", " "), "; ".join(who)], "blow", state,
				Moves.length(state, tune), state == "chop"])
		for k in KICK_PRESSES:
			var s: String = Weapons.kick_armed(k, w)
			if s == k:
				if k == "knee":  # the knee as a kick (the weapon kept in Ready), apart from the uppercut
					segments.append([w, "knee", "%s · knee: %s (stays a kick, the weapon held in Ready)" % [w.to_upper(), KICK_PRESSES[k]],
						"kick", "knee", Moves.length("knee", tune), false])
			elif not done.has(s):
				done[s] = true
				segments.append([w, s, "%s · %s: %s's place" % [w.to_upper(), s.replace("_", " "), KICK_PRESSES[k]], "blow", s,
					Moves.length(s, tune), false])
	_start(0)


func _start(i: int) -> void:
	seg = i
	tick = 0
	var s: Array = segments[i]
	view._show_weapon(s[0])
	var close: bool = s[3] in ["grip", "block"]
	view.scale = Vector2.ONE * (CLOSE if close else 2.0)
	view.position = Vector2(520, 600 - (110 if s[6] else 0))
	if close:  # up close on the hands (the testers on b24110b: the grips and blocks were unclear): the weapon hand mid-screen
		var pose: Dictionary = Poses.armed(Poses.angles(s[4], 0, tune), s[4], s[0], 0, tune)
		var baked: Dictionary = Poses.bake(pose, true)
		var hand: Vector2 = Poses._end("arm_%s_lower" % ("b" if pose.get("wpn_side", 0.0) >= 0.5 else "f"), baked)[0]
		var head: Vector2 = Poses._end("head", baked)[0]  # (the head in frame too: the chief of staff, 2168465)
		view.position = Vector2(640, 380) - hand.lerp(head, 0.45) * CLOSE
	print("SEG %s %s %d %d %s" % [s[0], s[1], frame, frame + _length(s) - 1, s[2]])


func _length(s: Array) -> int:
	return s[5] if s[3] in ["grip", "block"] else s[5] + PAD * 2


func _process(_delta: float) -> bool:
	var s: Array = segments[seg]
	var state: String = s[4]
	var t: int = tick
	var phase := ""
	if s[3] in ["blow", "kick"]:
		if tick < PAD or tick >= PAD + s[5]:
			state = "idle"
			t = 0
			phase = "Ready" if tick < PAD else "back in Ready (recovered)"
		else:
			t = tick - PAD
			var d: Dictionary = Moves.data(state, tune)
			phase = "wind-up" if t < d["startup"] else ("CONTACT" if t < d["startup"] + d["active"] else "follow-through, recovering")
	var pose: Dictionary = Poses.armed(Poses.angles(state, t, tune), state, s[0], t, tune)
	view.apply(pose, not s[6] or state == "idle")
	label.text = "%s\nframe %d of %d%s" % [s[2], tick + 1, _length(s), ("  ·  " + phase) if phase != "" else ""]
	tick += 1
	frame += 1
	if tick >= _length(s):
		if seg + 1 >= segments.size():
			print("ARMED DONE %d frames" % frame)
			return true
		_start(seg + 1)
	return false
