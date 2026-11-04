extends RefCounted
## A level as runs of fights on one or more floors (DESIGN, The levels: one floor in levels 1-2, two in 3-5, up to
## three in 6-8 where switches upstairs open doors below; the boss at the end). The layout is data (levels/levelN.json),
## so the team's layouts drop straight in. Plain logic like fighter.gd: it spawns the fighters, holds the hero at a wave
## until it's beaten (the floor "locks" there), moves him between floors by the stairs (walk into the doorway at the back
## of the street), lets a blow flip a switch that opens a door on another floor, and the level is won when the boss is
## down for good. Three lives per level; losing them all restarts the level from its start (D-15). Seeded, so a run
## replays the same (the bot plays every level on several seeds: L-8).
##
## The data, full form: {name, floors: [{name, length, obstacles, items, waves}...], links: [{from, x, to, to_x}...],
##   switches: [{floor, x, opens}...], boss: {floor, x, kind, health, weapon}}
## Obstacles: [kind, x0, x1, z0, z1, top, climbable, strength, name?] (a "door" with a name opens from a switch);
## items: [kind, x, z]; waves: [{at, enemies: [{kind, dx, z, weapon}]}...].
## The short form (level 1): one street ({length, obstacles, items, waves}), "stairs" at the end up to the boss's room
## ("upstairs_length", "boss").

const Fighter := preload("res://scripts/sim/fighter.gd")
const Fight := preload("res://scripts/sim/fight.gd")
const Brain := preload("res://scripts/sim/brain.gd")
const StreetWorld := preload("res://scripts/sim/street_world.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")
const Projectiles := preload("res://scripts/sim/projectiles.gd")
const Tutor := preload("res://scripts/sim/tutor.gd")

## Enemy types by name: health, how they fight (brain.gd tables), what they drop when put down for good, and blows
## that don't make them flinch. From the team's enemy table (art-in 2026-11-03): the Glow Punk, the warm-up (slap,
## slap, shove; drops food) and the Bruiser, the big lad (shrugs off a jab, "Iron Gut"; drops a bat).
const KINDS := {
	"thug": {"health": 12.0, "brain": "THUG"},
	"glow_punk": {"health": 8.0, "brain": "GLOW_PUNK", "drops": "takeaway"},
	"bruiser": {"health": 20.0, "brain": "BRUISER", "drops": "bat", "shrugs": ["punch"]},
	"boss": {"health": 40.0, "brain": "BOSS"},
	"dj_volt": {"health": 40.0, "brain": "DJ_VOLT", "drops": "bat"},
	"snick": {"health": 10.0, "brain": "SNICK", "weapon": "knife"},  # her knife falls when she's put down
	"bruiser_pipe": {"health": 20.0, "brain": "BRUISER", "weapon": "pipe", "shrugs": ["punch"], "snaps": true},
	"big_mama": {"health": 50.0, "brain": "BIG_MAMA", "weapon": "wok", "drops": "wrench"},
}
## DJ Volt's records (the team: "three records thrown like frisbees, low, middle, high"): their height bands above the
## street, how fast they fly, how far apart in time, what they do
const RECORDS := [[0.0, 60.0], [110.0, 180.0], [210.0, 280.0]]
const RECORD_SPEED := 9.0
const RECORD_GAP := 14
const RECORD_DAMAGE := 1.5
## "Bass Drop": a guard held this long while his speakers stand, and the music's wave pushes the hero back
const BASS_HOLD := 120
## Big Mama Noodle's kitchen (the team's level 2): her hot soup comes on the hero's third block in a row; running onto
## the wet patch by the sink she slips and is dazed at once; at half health she mops it dry; a blow on the tap floods it.
const SOUP_AFTER_BLOCKS := 3
const SOUP_DAMAGE := 2.0
const SLIP_DAZE := 150
const MAX_ON_SCREEN := 5  # never more than five enemies at once; the rest wait off screen (the team's fairness rules)
const OFF_SCREEN := 1150.0  # "from the left/right": they walk in from this far beyond the wave's spot
const AMBUSH := 260.0  # a hidden enemy jumps out when the hero comes this close
const LIVES := 3
const LOCK_MARGIN := 700.0  # a floor "locks" this far either side of a wave until it's beaten
const ATTACKERS := 2  # at most this many enemies attack at once; the rest wait their turn (a fair fight in a crowd)
const DOWN_TICKS := 150  # a fighter put down for good lies this long before he's gone (an enemy) or respawns (the hero)
const DOORWAY := 50.0  # standing this close to a stairs' x at the back of the street (z under DOORWAY_Z) takes them
const DOORWAY_Z := 12.0
const SWITCH_REACH := 30.0  # a blow whose reach covers a switch's x (± this) flips it

var data: Dictionary
var plan: Dictionary  # the level in its full form (short layouts are unfolded into it)
var tune: Dictionary
var floors := []  # each {name, length, world, waves, wave, active_wave, enemies}
var on := 0  # the floor he's on
var hero
var fight
var flipped := {}  # switch index -> true once flipped
var boss_spawned := false
var arrived_x := -1.0e9  # where he came up or down the stairs: that doorway doesn't take him straight back
var lives := LIVES
var won := false
var lost := false  # out of lives: the level restarts (restart())
var tick := 0
var hero_down_for := 0
var dice_seed := 1
var events := []  # this tick's fight events (for sounds and the view)
var collected := []  # what the hero has found (a matchbook, the torn photo)
var projectiles  # what's flying (records)
var held_guard := 0  # how long the hero has held his guard, for DJ Volt's Bass Drop
var bass_at := -1  # the tick the last bass wave went out (for the view and the sound)
var wet := true  # Big Mama's kitchen floor by the sink
var mopped := false  # she's mopped it once (at half health)
var blocks_in_row := 0  # the hero's blocks in a row against her (her hot soup)
var friend = null  # the sparring friend (level 1's first screen), a fighter on his own side
var tutor = null  # his lessons (sim/tutor.gd)
var hero_tune: Dictionary

## The floor he's on, as the game and the tests read it
var world:
	get: return floors[on]["world"]
var enemies: Array:
	get: return floors[on]["enemies"]
var wave: int:
	get: return floors[on]["wave"]
var active_wave: int:
	get: return floors[on]["active_wave"]
var where: String:
	get: return floors[on]["name"]


func _init(level_data: Dictionary, tuning: Dictionary = {}, seed_value := 1) -> void:
	data = level_data
	plan = unfold(level_data)
	hero_tune = tuning if not tuning.is_empty() else Tuning.fresh()
	dice_seed = seed_value
	restart()


## Reads a level's layout (levels/levelN.json).
static func load_data(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## The short form (one street, stairs at the end, the boss's room upstairs) as the full form.
static func unfold(d: Dictionary) -> Dictionary:
	if d.has("floors"):
		return d
	return {
		"name": d.get("name", ""),
		"floors": [
			{"name": "street", "length": d["length"], "obstacles": d.get("obstacles", []), "items": d.get("items", []),
				"waves": d.get("waves", [])},
			{"name": "upstairs", "length": d.get("upstairs_length", 1920.0), "obstacles": [], "items": [], "waves": []},
		],
		"links": [{"from": 0, "x": d["stairs"], "to": 1, "to_x": 200.0, "auto": true}],
		"switches": [],
		"boss": d.get("boss", {}).merged({"floor": 1, "x": 1200.0}),
	}


## The level from its start: what a save at the level's start restores (D-15).
func restart() -> void:
	tune = hero_tune  # the hero's own table, so the feel lab still reaches him
	floors = []
	for f in plan["floors"]:
		var w = StreetWorld.new()
		for o in f.get("obstacles", []):
			var obj: Dictionary = w.add(o[0], o[1], o[2], o[3], o[4], o[5], o[6], o[7])
			if o.size() > 8:
				obj["name"] = o[8]
			if o.size() > 9:
				obj["holds"] = o[9]  # a crate or a car with something inside: it falls out when it's smashed
		for it in f.get("items", []):  # food, first aid, a weapon lying ready; a 4th number: lying up high (a roof)
			w.drop(it[0], it[1], it[2], it[3] if it.size() > 3 else 0.0)
		floors.append({"name": f["name"], "length": f["length"], "world": w, "waves": f.get("waves", []), "wave": 0,
			"active_wave": -1, "enemies": [], "waiting": []})
	on = 0
	hero = Fighter.new(tune, 200.0, 80.0, world)
	fight = Fight.new()
	flipped = {}
	boss_spawned = false
	arrived_x = -1.0e9
	lives = LIVES
	won = false
	lost = false
	tick = 0
	hero_down_for = 0
	events = []
	collected = []
	projectiles = Projectiles.new()
	held_guard = 0
	bass_at = -1
	wet = true
	mopped = false
	blocks_in_row = 0
	friend = null
	tutor = null
	var spar: Dictionary = plan["floors"][0].get("friend", {})
	if not spar.is_empty():
		var t := Tuning.fresh()
		t["health"] = 999.0
		friend = Fighter.new(t, spar["x"], 80.0, floors[0]["world"])
		friend.team = 2  # his own side: blows land between him and the hero, never the thugs'
		friend.soft = true
		friend.facing = -1
		tutor = Tutor.new(friend, hero)
	_maybe_boss()


## The fighters on this floor now, the hero first (and the sparring friend, on his floor).
func everyone() -> Array:
	var out := [hero] + enemies.filter(func(e): return not e["gone"]).map(func(e): return e["f"])
	if friend != null and on == 0:
		out.append(friend)
	return out


## The lesson's hint on screen, while the sparring friend is teaching ("" otherwise).
func hint() -> String:
	if tutor == null or on != 0 or (tutor.lesson == "done" and tutor.lesson_ticks > 150):
		return ""
	return tutor.hint()


## The enemies on this floor still on their feet (or down but not out).
func standing() -> Array:
	return enemies.filter(func(e): return not e["gone"] and not e["f"].defeated()).map(func(e): return e["f"])


## How far the hero may go along this floor right now: a wave being fought locks him near it.
func bounds() -> Vector2:
	var length: float = floors[on]["length"]
	if active_wave >= 0:
		var at: float = floors[on]["waves"][active_wave]["at"]
		return Vector2(maxf(0.0, at - LOCK_MARGIN), minf(length, at + LOCK_MARGIN))
	return Vector2(0.0, length)


## One tick: the hero on this input, every enemy on its own mind, the blows settled, the waves, switches and floors.
func step(inp: Dictionary) -> void:
	if won or lost:
		return
	tick += 1
	var b := bounds()
	tune["street_left"] = b.x
	tune["street_right"] = b.y
	hero.step(inp)
	_take_turns()
	if friend != null and on == 0:
		friend.step(tutor.think())
	for e in enemies:
		if not e["gone"]:
			var think: Dictionary = e["brain"].think()
			if think.get("throw", false):
				e["volley"] = RECORDS.duplicate()  # his records go one after another
				e["volley_at"] = tick
			_volley(e)
			e["f"].step(think)
	var all := everyone()
	for id in world.step_hits(all):  # something smashed: whatever was inside falls out
		var o: Dictionary = world.objects[id]
		if o.has("holds"):
			world.drop(o["holds"], (o["x0"] + o["x1"]) * 0.5, clampf((o["z0"] + o["z1"]) * 0.5, 0.0, tune["street_depth"]))
	_collect()
	Fight.separate(all.filter(func(f): return f != friend))  # he never blocks the street
	events = fight.step(all, world)
	events.append_array(projectiles.step(all, 0.0, floors[on]["length"]))
	if tutor != null and on == 0:
		tutor.saw(events)
	_bass_drop()
	_kitchen()
	_switches()
	_waves()
	_links()
	_downs()


## The nearest ATTACKERS enemies on their feet may attack; the others hang back until one of them goes down.
func _take_turns() -> void:
	var up := enemies.filter(func(e): return not e["gone"] and not e["f"].defeated())
	up.sort_custom(func(a, b): return absf(a["f"].x - hero.x) < absf(b["f"].x - hero.x))
	for i in up.size():
		up[i]["brain"].allowed = i < ATTACKERS


## A thrower's volley, one record every RECORD_GAP ticks, from his hand toward the hero.
func _volley(e: Dictionary) -> void:
	if not e.has("volley") or e["volley"].is_empty() or e["f"].defeated() or e["f"].state in Fighter.HURT_STATES:
		return
	if (tick - e["volley_at"]) % RECORD_GAP != 0:
		return
	var band: Array = e["volley"].pop_front()
	var f = e["f"]
	var dir := 1.0 if hero.x >= f.x else -1.0
	projectiles.throw("record", f.x + dir * 40.0, f.z, band[0], band[1], dir * RECORD_SPEED, RECORD_DAMAGE, f.team)


## DJ Volt's Bass Drop: while either speaker stands, a guard held BASS_HOLD ticks brings the wave: it pushes the
## hero back. Smash both speakers and it's gone (the team's boss list: "smash them first").
func _bass_drop() -> void:
	var dj: Array = enemies.filter(func(e): return e.get("kind", "") == "dj_volt" and not e["f"].defeated())
	if dj.is_empty():
		return
	held_guard = held_guard + 1 if hero.blocking() != "" else 0
	var speakers: bool = world.objects.any(func(o): return o["kind"] == "speaker" and not o["broken"])
	if held_guard >= BASS_HOLD and speakers:
		held_guard = 0
		bass_at = tick
		hero._enter("idle")  # the wave tears his guard down
		hero.take_hit({"damage": 1.0, "effect": "push", "low": 0.0, "high": 300.0, "move": "bass"}, dj[0]["f"])
		events.append({"target": hero, "result": "bass", "kind": "bass"})


## Big Mama Noodle's kitchen: the soup, the wet patch, the mop, the tap (the floor's "kitchen": {wet: [x0, x1], tap: x}).
func _kitchen() -> void:
	var room: Dictionary = plan["floors"][on].get("kitchen", {})
	if room.is_empty():
		return
	var mama: Array = enemies.filter(func(e): return e.get("kind", "") == "big_mama" and not e["f"].defeated())
	if mama.is_empty():
		return
	var m = mama[0]["f"]
	# her soup: the hero's third block in a row (a blow of his landing on her breaks the run)
	for e in events:
		if e.get("attacker") == m and e.get("target") == hero:
			blocks_in_row = blocks_in_row + 1 if e["result"] in ["blocked", "perfect"] else 0
		elif e.get("attacker") == hero and e.get("result") == "hit":
			blocks_in_row = 0
	if blocks_in_row >= SOUP_AFTER_BLOCKS:
		blocks_in_row = 0
		var dir := 1.0 if hero.x >= m.x else -1.0
		projectiles.throw("soup", m.x + dir * 40.0, m.z, 110.0, 200.0, dir * 10.0, SOUP_DAMAGE, m.team)
		events.append({"target": hero, "result": "soup", "kind": "soup"})
	# the wet patch: running onto it she slips and is dazed at once
	var patch: Array = room.get("wet", [])
	if wet and patch.size() == 2 and m.state == "run" and m.x >= patch[0] and m.x <= patch[1]:
		m.dizzy_left = SLIP_DAZE
		m._enter("dizzy")
		events.append({"target": m, "result": "slip", "kind": "slip"})
	# at half health she mops it dry; a blow on the tap floods it again
	if not mopped and m.health <= m.max_health * 0.5:
		mopped = true
		wet = false
		events.append({"target": m, "result": "mopped", "kind": "mopped"})
	var box: Dictionary = hero.hit_box()
	if not wet and not box.is_empty() and room.has("tap") and box["x0"] - 30.0 <= room["tap"] and room["tap"] <= box["x1"] + 30.0:
		wet = true
		events.append({"target": hero, "result": "flooded", "kind": "tap"})


## Walking over a collectible (a matchbook, the torn photo) keeps it.
const COLLECTIBLES := ["matchbook", "photo"]


func _collect() -> void:
	for it in world.items.duplicate():
		if it["kind"] in COLLECTIBLES and absf(it["x"] - hero.x) <= 40.0 and absf(it["z"] - hero.z) <= 40.0 \
				and absf(it.get("y", 0.0) - hero.y) < 20.0:
			world.items.erase(it)
			collected.append(it["kind"])


func _spawn(kind: String, x: float, z: float, weapon := "", health := -1.0, wave_index := -1) -> void:
	var t := Tuning.fresh()
	t["health"] = health if health > 0.0 else KINDS[kind]["health"]
	t["street_right"] = floors[on]["length"] + 2000.0  # enemies walk in from beyond the lock
	t["street_left"] = -2000.0
	t["flat_line"] = tune.get("flat_line", false)
	var f = Fighter.new(t, x, z, world)
	f.team = 1
	f.can_climb = false  # enemies don't climb ladders (level 2)
	f.facing = -1 if x > hero.x else 1
	if weapon != "":
		f.take_weapon(weapon)
	f.shrugs = KINDS[kind].get("shrugs", [])
	if weapon == "" and KINDS[kind].has("weapon"):
		f.take_weapon(KINDS[kind]["weapon"])  # an enemy type's own weapon (Snick's knife)
	f.weapon_snaps = KINDS[kind].get("snaps", false)
	var how: Dictionary = Brain.TYPES[KINDS[kind]["brain"]]
	enemies.append({"f": f, "brain": Brain.new(f, hero, dice_seed * 100 + tick + enemies.size(), how), "gone": false,
		"down_for": 0, "boss": false, "wave": wave_index, "kind": kind, "dropped": false})


## Where an enemy of a wave comes in: walking in from off screen left or right, out of a door at the back of the
## street, or already there (hidden: he waits, still, until the hero comes close, then jumps out).
func _arrive(e: Dictionary, at: float, wave_index: int) -> void:
	var from: String = e.get("from", "here")
	var x: float = at + e.get("dx", 0.0)
	var z: float = e.get("z", 80.0)
	match from:
		"left":
			x = at - OFF_SCREEN
		"right":
			x = at + OFF_SCREEN
		"door":
			z = 0.0
	_spawn(e["kind"], x, z, e.get("weapon", ""), -1.0, wave_index)
	if e.get("hidden", false):
		enemies[-1]["brain"].dormant_until_within = AMBUSH


func _waves() -> void:
	var fl: Dictionary = floors[on]
	var waves: Array = fl["waves"]
	if fl["active_wave"] < 0 and fl["wave"] < waves.size() and hero.x >= waves[fl["wave"]]["at"] - 300.0:
		fl["active_wave"] = fl["wave"]
		fl["wave"] += 1
		fl["waiting"] = (waves[fl["active_wave"]]["enemies"] as Array).duplicate()
	# a wave's enemies come in as they may: those with "after_down" once that many of the wave are down, and never more
	# than MAX_ON_SCREEN standing at once (the rest wait off screen)
	if fl["active_wave"] >= 0 and not fl["waiting"].is_empty():
		var at: float = waves[fl["active_wave"]]["at"]
		var down: int = enemies.filter(func(e): return e["wave"] == fl["active_wave"] and e["f"].defeated()).size()
		for e in (fl["waiting"] as Array).duplicate():
			if standing().size() >= MAX_ON_SCREEN:
				break
			if int(e.get("after_down", 0)) <= down:
				fl["waiting"].erase(e)
				_arrive(e, at, fl["active_wave"])
	# what the put-down leave behind (the Glow Punk his food, the Bruiser his bat)
	for e in enemies:
		if e["f"].defeated() and not e["dropped"]:
			e["dropped"] = true
			var drop: String = KINDS.get(e["kind"], {}).get("drops", "")
			if drop != "":
				world.drop(drop, e["f"].x, e["f"].z)
	if fl["active_wave"] >= 0 and fl["waiting"].is_empty() and not enemies.any(func(e): return e["wave"] == fl["active_wave"] and not e["gone"] and not e["f"].defeated()):
		fl["active_wave"] = -1  # its thugs beaten: the floor opens on (a boss waiting further on doesn't hold it)
	var boss_down: bool = boss_spawned and enemies.any(func(e): return e["boss"] and e["f"].defeated())
	if boss_down:
		won = true


## Where the way on is, for a bot: the x of a doorway or ladder on this floor once its waves are beaten, or -1.
func next_door() -> float:
	if not cleared(on):
		return -1.0
	for l in plan.get("links", []):
		if int(l["from"]) == on and not l.get("auto", false) and int(l["to"]) > on:
			return float(l["x"])
	return -1.0


## A floor's waves all beaten?
func cleared(floor_index: int) -> bool:
	var fl: Dictionary = floors[floor_index]
	return fl["active_wave"] < 0 and fl["wave"] >= fl["waves"].size()


## The stairs: walking into a doorway at the back of the street (or, for the last stairs of a short layout, just
## reaching them) takes him to the floor it leads to, once this floor's waves are beaten.
func _links() -> void:
	if active_wave >= 0:
		return
	if arrived_x > -1.0e8:
		if absf(hero.x - arrived_x) > DOORWAY or hero.z > DOORWAY_Z + 30.0:
			arrived_x = -1.0e9  # he's stepped away from the doorway he came through
		else:
			return
	for l in plan.get("links", []):
		if int(l["from"]) != on:
			continue
		var auto: bool = l.get("auto", false)
		var at_door: bool = absf(hero.x - l["x"]) <= DOORWAY and hero.z <= DOORWAY_Z
		if (auto and hero.x >= l["x"] and cleared(on)) or (not auto and at_door and hero.on_ground()):
			_go_to(int(l["to"]), l["to_x"])
			return


func _go_to(floor_index: int, x: float) -> void:
	on = floor_index
	hero.world = world
	hero.x = x
	hero.z = 80.0
	hero._enter("idle")
	arrived_x = x
	_maybe_boss()


## The boss waits on his floor: he steps out the first time the hero arrives there.
func _maybe_boss() -> void:
	var boss: Dictionary = plan.get("boss", {})
	if boss_spawned or boss.is_empty() or int(boss.get("floor", 0)) != on:
		return
	boss_spawned = true
	_spawn(boss.get("kind", "boss"), boss.get("x", 1200.0), 80.0, boss.get("weapon", ""), boss.get("health", -1.0))
	enemies[-1]["boss"] = true


## A blow that reaches a switch flips it, once: the door it names opens, on whatever floor it stands.
func _switches() -> void:
	var box: Dictionary = hero.hit_box()
	if box.is_empty():
		return
	var switches: Array = plan.get("switches", [])
	for i in switches.size():
		var s: Dictionary = switches[i]
		if flipped.has(i) or int(s["floor"]) != on:
			continue
		if box["x0"] - SWITCH_REACH <= s["x"] and s["x"] <= box["x1"] + SWITCH_REACH:
			flipped[i] = true
			for fl in floors:
				for o in fl["world"].objects:
					if o.get("name", "") == s["opens"]:
						o["broken"] = true  # an open door no longer blocks


func _downs() -> void:
	for e in enemies:
		if not e["gone"] and e["f"].defeated() and not e["boss"]:
			e["down_for"] += 1
			if e["down_for"] >= DOWN_TICKS:
				e["gone"] = true  # he's out of the fight; his weapon, if any, already lies on the street
	if hero.defeated():
		hero_down_for += 1
		if hero_down_for >= DOWN_TICKS:
			hero_down_for = 0
			lives -= 1
			if lives <= 0:
				lost = true
				return
			hero.health = hero.max_health  # a life lost: up again, the fight goes on where it was
			hero._enter("get_up")
