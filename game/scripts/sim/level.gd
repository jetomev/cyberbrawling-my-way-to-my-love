extends RefCounted
## A level as a run of fights along the street (Stage 1: a grey level 1 with the boss upstairs). The layout is data
## (levels/levelN.json: the street's length, its obstacles, where each wave of thugs waits, the stairs, the boss room),
## so the team's layouts drop straight in. Plain logic like fighter.gd: it spawns the fighters, holds the hero at a
## wave until it's beaten (the street "locks" there), takes him upstairs at the end, and the level is won when the boss
## is down for good. Three lives per level; losing them all restarts the level from its start (D-15). Seeded, so a
## run replays the same (the bot plays every level on several seeds: L-8).
##
## The data: {name, length, obstacles: [[kind, x0, x1, z0, z1, top, climbable, strength]...], items: [[kind, x, z]...],
##   waves: [{at, enemies: [{kind, dx, z, weapon}]}...], stairs, boss: {kind, health, weapon}, upstairs_length}

const Fighter := preload("res://scripts/sim/fighter.gd")
const Fight := preload("res://scripts/sim/fight.gd")
const Brain := preload("res://scripts/sim/brain.gd")
const StreetWorld := preload("res://scripts/sim/street_world.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")

## Enemy types by name: health, and how they fight (brain.gd tables). The team's enemy table fills this out.
const KINDS := {
	"thug": {"health": 12.0, "brain": "THUG"},
	"boss": {"health": 40.0, "brain": "BOSS"},
}
const LIVES := 3
const LOCK_MARGIN := 700.0  # the street "locks" this far either side of a wave until it's beaten
const ATTACKERS := 2  # at most this many enemies attack at once; the rest wait their turn (a fair fight in a crowd)
const DOWN_TICKS := 150  # a fighter put down for good lies this long before he's gone (an enemy) or respawns (the hero)

var data: Dictionary
var tune: Dictionary
var world
var hero
var fight
var enemies := []  # each {f, brain, gone}
var wave := 0  # the next wave to start
var active_wave := -1  # the wave being fought, or -1
var where := "street"  # "street", then "upstairs" for the boss
var lives := LIVES
var won := false
var lost := false  # out of lives: the level restarts (restart())
var tick := 0
var hero_down_for := 0
var dice_seed := 1
var events := []  # this tick's fight events (for sounds and the view)
var hero_tune: Dictionary


func _init(level_data: Dictionary, tuning: Dictionary = {}, seed_value := 1) -> void:
	data = level_data
	hero_tune = tuning if not tuning.is_empty() else Tuning.fresh()
	dice_seed = seed_value
	restart()


## Reads a level's layout (levels/levelN.json).
static func load_data(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## The level from its start: what a save at the level's start restores (D-15).
func restart() -> void:
	tune = hero_tune  # the hero's own table, so the feel lab still reaches him
	tune["street_right"] = data["length"]
	world = StreetWorld.new()
	for o in data.get("obstacles", []):
		world.add(o[0], o[1], o[2], o[3], o[4], o[5], o[6], o[7])
	for it in data.get("items", []):  # food, first aid, a weapon lying ready: [kind, x, z]
		world.drop(it[0], it[1], it[2])
	hero = Fighter.new(tune, 200.0, 80.0, world)
	fight = Fight.new()
	enemies = []
	wave = 0
	active_wave = -1
	where = "street"
	lives = LIVES
	won = false
	lost = false
	tick = 0
	hero_down_for = 0
	events = []


## The fighters on the street now, the hero first.
func everyone() -> Array:
	return [hero] + enemies.filter(func(e): return not e["gone"]).map(func(e): return e["f"])


## The enemies still on their feet (or down but not out).
func standing() -> Array:
	return enemies.filter(func(e): return not e["gone"] and not e["f"].defeated()).map(func(e): return e["f"])


## How far the hero may go along the street right now: a wave being fought locks him near it.
func bounds() -> Vector2:
	if active_wave >= 0:
		var at: float = data["waves"][active_wave]["at"]
		return Vector2(maxf(0.0, at - LOCK_MARGIN), minf(data["length"], at + LOCK_MARGIN))
	return Vector2(0.0, data["length"] if where == "street" else data.get("upstairs_length", 1920.0))


## One tick: the hero on this input, every enemy on its own mind, the blows settled, the waves and the floors moved on.
func step(inp: Dictionary) -> void:
	if won or lost:
		return
	tick += 1
	var b := bounds()
	tune["street_left"] = b.x
	tune["street_right"] = b.y
	hero.step(inp)
	_take_turns()
	for e in enemies:
		if not e["gone"]:
			e["f"].step(e["brain"].think())
	var all := everyone()
	world.step_hits(all)
	Fight.separate(all)
	events = fight.step(all, world)
	_waves()
	_downs()


## The nearest ATTACKERS enemies on their feet may attack; the others hang back until one of them goes down.
func _take_turns() -> void:
	var up := enemies.filter(func(e): return not e["gone"] and not e["f"].defeated())
	up.sort_custom(func(a, b): return absf(a["f"].x - hero.x) < absf(b["f"].x - hero.x))
	for i in up.size():
		up[i]["brain"].allowed = i < ATTACKERS


func _spawn(kind: String, x: float, z: float, weapon := "") -> void:
	var t := Tuning.fresh()
	t["health"] = KINDS[kind]["health"]
	t["street_right"] = tune["street_right"] + 2000.0  # enemies walk in from beyond the lock
	t["street_left"] = -2000.0
	t["flat_line"] = tune.get("flat_line", false)
	var f = Fighter.new(t, x, z, world)
	f.team = 1
	f.facing = -1 if x > hero.x else 1
	if weapon != "":
		f.take_weapon(weapon)
	var how: Dictionary = Brain.TYPES[KINDS[kind]["brain"]]
	enemies.append({"f": f, "brain": Brain.new(f, hero, dice_seed * 100 + enemies.size(), how), "gone": false, "down_for": 0})


func _waves() -> void:
	if where == "street":
		var waves: Array = data["waves"]
		if active_wave < 0 and wave < waves.size() and hero.x >= waves[wave]["at"] - 300.0:
			active_wave = wave
			wave += 1
			for e in waves[active_wave]["enemies"]:
				_spawn(e["kind"], waves[active_wave]["at"] + e["dx"], e.get("z", 80.0), e.get("weapon", ""))
		if active_wave >= 0 and standing().is_empty():
			active_wave = -1  # beaten: the street opens on
		# the stairs: once every wave is beaten and he reaches them, up to the boss
		if active_wave < 0 and wave >= waves.size() and hero.x >= data["stairs"]:
			_go_upstairs()
	elif where == "upstairs" and standing().is_empty() and not enemies.is_empty():
		won = true


func _go_upstairs() -> void:
	where = "upstairs"
	world = StreetWorld.new()  # the boss's room: a bare floor (the team's layout gives it things)
	hero.world = world
	hero.x = 200.0
	hero.z = 80.0
	hero._enter("idle")
	enemies = []
	var boss: Dictionary = data["boss"]
	_spawn(boss.get("kind", "boss"), 1200.0, 80.0, boss.get("weapon", ""))
	enemies[0]["f"].tune["health"] = boss.get("health", KINDS["boss"]["health"])
	enemies[0]["f"].max_health = enemies[0]["f"].tune["health"]
	enemies[0]["f"].health = enemies[0]["f"].max_health


func _downs() -> void:
	for e in enemies:
		if not e["gone"] and e["f"].defeated():
			e["down_for"] += 1
			if e["down_for"] >= DOWN_TICKS and where == "street":
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
