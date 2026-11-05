extends RefCounted
## The boss rush (the assistant team's agreed list, 2026-11-05): the nine bosses in order, each fought in his own room
## (levels/boss_rush.json), three lives for the whole run, a bowl of noodles between fights, the hero starting with
## nothing and earning each boss's prize as he wins, the Lovelight handed over before the Godfather (his lost-round rule
## still holds). Each fight's end scores like a level won; the helper's allowed, with its mark. Javier & Claude.

const Level := preload("res://scripts/sim/level.gd")
const Weapons := preload("res://scripts/sim/weapons.gd")
const FILE := "res://levels/boss_rush.json"
const LIVES := 3


static func fights() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	return parsed.get("fights", []) if parsed is Dictionary else []


## What a run carries from fight to fight: lives, health, the weapon in hand, Mr. Static's rubber gloves.
static func fresh_carry() -> Dictionary:
	return {"lives": LIVES, "health": -1.0, "weapon": "", "rubber": false}


## Fight i, ready to play: in the boss's room, the hero as the run left him (nothing at the start), a bowl of noodles
## at his feet after the first fight, the Lovelight in his hand for the Godfather.
static func start(i: int, carry: Dictionary, tune: Dictionary, seed: int):
	var f: Dictionary = fights()[i]
	var l = Level.new(Level.load_data("res://levels/%s.json" % f["level"]), tune, seed)
	if l.hero.weapon != "":
		l.hero.drop_weapon()  # (a level's own start weapon: the rush starts with nothing)
	l._go_to(int(f["floor"]), float(f["x"]))
	l.lives = int(carry["lives"])
	if float(carry["health"]) > 0.0:
		l.hero.health = minf(float(carry["health"]), l.hero.max_health)
	if carry["weapon"] != "":
		l.hero.take_weapon(carry["weapon"])
	l.hero.rubber = carry["rubber"]
	if f.has("hand"):
		if l.hero.weapon != "":
			l.hero.drop_weapon()
		l.hero.take_weapon(f["hand"])  # handed over before the Godfather
	if i > 0:
		l.world.drop("noodles", l.hero.x + 90.0, l.hero.z)  # one bowl between fights
	return l


## A fight won: what the run carries on (his prize, if it's a weapon, in his hand; the rubber gloves on).
static func carry_out(l) -> Dictionary:
	var prize: String = ""
	for e in l.enemies:
		if e["boss"]:
			prize = e.get("drops", Level.KINDS.get(e["kind"], {}).get("drops", ""))
	var weapon: String = prize if Weapons.is_weapon(prize) else l.hero.weapon
	return {"lives": l.lives, "health": l.hero.health, "weapon": weapon, "rubber": l.hero.rubber or prize == "rubber_gloves"}
