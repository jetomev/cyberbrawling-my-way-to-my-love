extends "res://tests/test_case.gd"
## The Crane Operator, level 6's boss (the team's roster, the bosses): from his cab a container swings low along the
## floor the hero is on (jump it), then crates drop (shadows first); a switch on each floor, once thrown, stops the crane along that floor for good (roster v7);
## all three thrown open the cab; in the cab there's no room to swing a weapon; P P K shoves him out, and that's it.

const Level := preload("res://scripts/sim/level.gd")
const HeroBot := preload("res://scripts/sim/hero_bot.gd")


func docks():
	return Level.new(Level.load_data("res://levels/crane_docks.json"), {}, 1)


## Steps until the crane's container has passed the hero (jumping on the cue if asked); returns [hit by it, crates hit].
func one_pass(l, jump: bool) -> Array:
	var hit := false
	var crate := false
	var passed := false
	for i in Level.CRANE_EVERY + 300:
		l.step({"jump": jump and l.crane_jump_cue()})
		for ev in l.events:
			if ev.get("kind", "") == "container" and ev["result"] == "hit":
				hit = true
			if ev.get("kind", "") == "crate" and ev["result"] == "hit":
				crate = true
		if not passed and not l.crane.get("container", {}).is_empty():
			passed = true
		if passed and l.crane.get("container", {}).is_empty() and l.crane["crates"].is_empty():
			break
	return [hit, crate, passed]


func test_the_container_swings_through_and_knocks_him_down() -> void:
	var l = docks()
	l.hero.x = 960.0
	var r := one_pass(l, false)
	check(r[2], "the crane swings a container along the floor")
	check(r[0], "standing there: it knocks him down")


func test_jump_it_and_it_passes_under_him() -> void:
	var l = docks()
	l.hero.x = 960.0
	var r := one_pass(l, true)
	check(r[2], "it swings through")
	check(not r[0], "jumped as it came: it passes under him")


func test_crates_drop_near_him_after_it() -> void:
	var l = docks()
	l.hero.x = 960.0
	var shadows := false
	for i in Level.CRANE_EVERY + 300:
		l.step({"jump": l.crane_jump_cue()})
		shadows = shadows or not l.crane.get("crates", []).is_empty()
	check(shadows, "then crates drop near him, their shadows first")


func test_a_switch_stops_the_crane() -> void:
	var l = docks()
	l.hero.x = 860.0
	l.hero.facing = 1
	for i in 12:
		l.step({"punch": i == 0})
	check(l.flipped.has(0), "the quay's switch thrown")
	var swung := false
	for i in Level.CRANE_EVERY + 100:
		l.step({})
		swung = swung or not l.crane["container"].is_empty()
	check(not swung, "the crane's stopped: no container")
	for i in Level.CRANE_EVERY * 3 + 600:  # (it used to start again after 600 ticks)
		l.step({})
		swung = swung or not l.crane["container"].is_empty()
	check(not swung, "and it stays stopped along this floor, for good (roster v7)")
	l._go_to(1, 300.0)  # up on the next floor, its switch not thrown: the crane still swings there
	for i in Level.CRANE_EVERY + 100:
		l.step({"jump": l.crane_jump_cue()})
		swung = swung or not l.crane["container"].is_empty()
	check(swung, "the next floor's switch not thrown: the container still swings along it")


func test_all_three_switches_open_the_cab_and_its_no_room_for_a_weapon() -> void:
	var l = docks()
	var door: Dictionary = l.floors[2]["world"].objects.filter(func(o): return o.get("name", "") == "cab")[0]
	l.flipped[0] = true
	l.flipped[1] = true
	check(not door["broken"], "two thrown: the cab's still shut")
	l._go_to(2, 1000.0)
	l.hero.x = 1060.0
	l.hero.facing = 1
	for i in 12:
		l.step({"punch": i == 0})
	check(door["broken"], "the third: the cab door opens")
	l._go_to(3, 150.0)
	l.hero.take_weapon("pipe")
	l.step({})
	l.hero.step({"punch": true})
	eq(l.hero.state, "punch", "in the cab, a weapon in hand still throws a jab: no room to swing it")


func test_a_push_kick_shoves_him_out_and_thats_it() -> void:
	var l = docks()
	l._go_to(3, 150.0)
	var op = l.enemies.filter(func(e): return e["kind"] == "crane_operator")[0]["f"]
	check(op.health > 10.0, "he's in his cab, fresh")
	l.events = [{"attacker": l.hero, "target": op, "result": "hit", "move": "punch"}]
	l._shoved_out()
	check(not op.defeated(), "a jab: no")
	var x0: float = op.x
	l.events = [{"attacker": l.hero, "target": op, "result": "hit", "move": "push_kick"}]
	l._shoved_out()
	eq(op.state, "launch", "P P K's push kick: he's off his feet, shoved out")
	var top := 0.0
	var out := false
	for i in Level.SHOVE_TICKS + 5:
		l.step({})
		top = maxf(top, op.y)
		out = out or l.events.any(func(ev): return ev.get("result", "") == "out_of_cab")
	check(absf(op.x - x0) >= Level.SHOVE_DISTANCE - 1.0, "carried out past the cab's side (%.0f px)" % absf(op.x - x0))
	check(top > 40.0, "in an arc, up and over (%.0f px up)" % top)
	check(out and op.defeated(), "out of the cab, and that's it")
	l.step({})
	check(l.won, "the level's won")


func test_the_bot_beats_the_crane_operator() -> void:
	var results := []
	for s in [1, 2, 3]:
		var l = Level.new(Level.load_data("res://levels/crane_docks.json"), {}, s)
		var bot = HeroBot.new(l.hero, s)
		for i in 20000:
			if l.won or l.lost:
				break
			bot.me = l.hero
			bot.goal = l.next_door()
			bot.goal_hit = l.goal_is_switch
			bot.jump_cue = l.crane_jump_cue()
			l.step(bot.think(l.standing()))
		results.append("won" if l.won else ("lost" if l.lost else "stuck at %s %.0f" % [l.where, l.hero.x]))
	check(not results.any(func(r): return r.begins_with("stuck")), "never stuck: %s" % [results])
	check(results.count("won") >= 2, "and wins on most seeds: %s" % [results])
