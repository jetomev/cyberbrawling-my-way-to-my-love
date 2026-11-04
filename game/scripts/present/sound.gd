extends Node
## The fight's sounds, wired to its moments (the hit sounds, voices and cracks of the pain system; docs/STYLE.md, The
## sound). It plays what's there: res://assets/audio/sfx/<name>-<n>.ogg, a few takes of each so a repeat doesn't sound
## robotic; a sound not there yet is silent, so the team's batches drop straight in (docs/ART-BRIEF.md). No file is
## needed for the game to run.
##
## The moments: a punch or a kick thrown (its whoosh), a blow landing (light or heavy by its damage), a blow on the
## guard, a bone breaking, a weapon breaking, feet landing; the voices (grunt, shout, pain, scream) when the team's
## voice batch lands.

const DIR := "res://assets/audio/sfx/"
const NAMES := ["punch_whoosh", "kick_whoosh", "hit_light", "hit_heavy", "block", "crack", "land", "step", "weapon_break", "bass_drop",
	"grunt", "shout", "pain", "scream"]
const TAKES := 3
const VOICES := 8  # sounds at once

var takes := {}  # name -> [AudioStream...], only the ones that exist
var players: Array[AudioStreamPlayer] = []
var next := 0
var dice := RandomNumberGenerator.new()
var played := []  # every name asked for, for the tests (kept short)


func _ready() -> void:
	for n in NAMES:
		var found := []
		for k in range(1, TAKES + 1):
			var path := "%s%s-%d.ogg" % [DIR, n, k]
			if ResourceLoader.exists(path):
				found.append(load(path))
		if not found.is_empty():
			takes[n] = found
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		players.append(p)


## Plays a take of a sound by name; silent if it isn't there yet.
func play(n: String, volume_db := 0.0) -> void:
	played.append(n)
	if played.size() > 64:
		played.pop_front()
	if not takes.has(n) or players.is_empty():
		return
	var p := players[next]
	next = (next + 1) % players.size()
	p.stream = takes[n][dice.randi_range(0, takes[n].size() - 1)]
	p.volume_db = volume_db
	p.pitch_scale = dice.randf_range(0.95, 1.05)
	p.play()


## The sounds for one tick of a fight: each fighter's blow as it starts, and every blow that landed.
func fight_tick(fighters: Array, events: Array) -> void:
	for f in fighters:
		var m: Dictionary = f.move()
		if not m.is_empty() and f.attack_phase() == "startup" and f.t == 0:
			var limb: String = m.get("limb", "")
			play("kick_whoosh" if limb.begins_with("foot") or limb.begins_with("leg") else "punch_whoosh", -6.0)
			if m.get("damage", 0) >= 3:
				play("shout", -4.0)
	for e in events:
		match e["result"]:
			"hit":
				var by = e.get("attacker")  # (a thrown record has no attacker: it hits light)
				var heavy: bool = by != null and (by.move().get("damage", 1) >= 3 or e.get("move", "") in ["sweep", "smash"])
				play("hit_heavy" if heavy else "hit_light")
				play("pain", -3.0)
			"blocked", "perfect":
				play("block")
			"bass":
				play("bass_drop")
		if e.get("broke", "") != "":
			play("crack")
			play("scream", -2.0)
		if e.get("worn", "") != "":
			play("weapon_break")
