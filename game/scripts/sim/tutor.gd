extends RefCounted
## The sparring friend on level 1's first screen (the team's level 1 layout: "Block, then early block, then the dizzy
## finisher, one at a time, a small hint the first time each. Then he waves you on."). A friendly fighter whose blows
## don't hurt and who can't be put down; he teaches by doing, and moves on when each lesson is done. The hero can walk
## straight past him: then he waves and the street goes on.
##
## Lessons: "block" (his slow punch, held off with D), "perfect" (the same, the guard up just as it lands), "dizzy"
## (two combos in a row on him: dazed), "finish" (a third combo while he's dazed). Then "done".

const Moves := preload("res://scripts/sim/moves.gd")

const LESSONS := ["block", "perfect", "dizzy", "finish", "done"]
const HINTS := {
	"block": "Your sparring friend throws a slow punch. Hold D to block it.",
	"perfect": "Now block just as it lands: a perfect block flashes and stops a combo dead.",
	"dizzy": "Land two combos in a row (A A A, or S S S) and he gets dizzy.",
	"finish": "He's dazed! A third combo now finishes him.",
	"done": "He waves you on. Go get them.",
}
const SWING_EVERY := 120  # ticks between his slow punches, while he's teaching blocks

var me  # the friend's fighter
var hero
var lesson := "block"
var wait := 60
var lesson_ticks := 0
var home := 0.0  # where he spars: he doesn't follow the hero down the street


func _init(friend, target) -> void:
	me = friend
	hero = target
	home = friend.x


## The hint for the lesson on now ("" once he's done and the hero has moved on).
func hint() -> String:
	return HINTS.get(lesson, "")


## Notes what just happened in the fight (from level.gd's events) and moves the lessons on.
func saw(events: Array) -> void:
	for e in events:
		if e.get("attacker") == me and e.get("target") == hero:
			if lesson == "block" and e["result"] in ["blocked", "perfect"]:
				_next()
			elif lesson == "perfect" and e["result"] == "perfect":
				_next()
		elif e.get("attacker") == hero and e.get("target") == me and e["result"] == "hit":
			if lesson == "finish" and Moves.is_finisher(e.get("move", "")):
				_next()
	if lesson == "dizzy" and me.state == "dizzy":
		_next()
	# walked straight past him: no lesson is forced on anyone
	if lesson != "done" and hero.x > home + 400.0:
		lesson = "done"
		lesson_ticks = 0
	me.health = me.max_health  # he can't be put down: it's practice


func _next() -> void:
	lesson = LESSONS[mini(LESSONS.find(lesson) + 1, LESSONS.size() - 1)]
	lesson_ticks = 0
	wait = 60


## His input this tick: face the hero; while teaching blocks, a slow punch now and then; otherwise he just guards.
func think() -> Dictionary:
	lesson_ticks += 1
	var inp := {}
	if me.state in ["hurt", "stagger", "push", "knockdown", "down", "get_up", "dizzy", "launch", "block_hit"]:
		return inp
	var dx: float = hero.x - me.x
	if me.facing != (1 if dx >= 0.0 else -1):
		inp["mx"] = signf(dx) * 0.01
	if lesson in ["block", "perfect"]:
		if absf(dx) > 120.0 and absf(me.x + signf(dx) * 4.0 - home) < 300.0:
			inp["mx"] = signf(dx)  # step in to spar, never far from his spot
		wait -= 1
		if wait <= 0 and absf(dx) <= 130.0:
			wait = SWING_EVERY
			inp["punch"] = true
	elif lesson == "done" and lesson_ticks > 60 and me.z > 4.0:
		inp["mz"] = -1.0  # he steps back to the shopfronts, out of the way
	return inp
