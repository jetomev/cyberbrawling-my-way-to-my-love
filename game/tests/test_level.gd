extends "res://tests/test_case.gd"
## The level (Stage 1: a grey level 1 with the boss upstairs): the street locks at each wave until it's beaten, the
## stairs take him up to the boss, the boss down wins the level, three lives and then the level restarts (D-15); and
## a bot plays it through on several seeds (L-8).

const Level := preload("res://scripts/sim/level.gd")
const Weapons := preload("res://scripts/sim/weapons.gd")
const Fight := preload("res://scripts/sim/fight.gd")
const HeroBot := preload("res://scripts/sim/hero_bot.gd")


func level(seed_value := 1):
	return Level.new(Level.load_data("res://tests/levels/grey_level1.json"), {}, seed_value)


## Puts every standing enemy down for good, as if beaten (the boss too, unless spared).
func beat_them(l, spare_the_boss := false) -> void:
	for e in l.enemies:
		if e["gone"] or e["f"].defeated() or (spare_the_boss and e["boss"]):
			continue
		e["f"].health = 0.0
		e["f"]._enter("ko")


func walk_to(l, x: float, ticks := 4000) -> void:
	var start: String = l.where
	for i in ticks:
		if l.hero.x >= x or l.won or l.lost or l.where != start:
			return
		l.step({"mx": 1.0})


func test_level_one_loads() -> void:
	var l = level()
	check(l.data["waves"].size() >= 3, "level 1 has its waves (%d)" % l.data["waves"].size())
	eq(l.lives, 3, "three lives (D-15)")
	eq(l.where, "street", "it starts on the street")
	eq(l.enemies.size(), 0, "nobody there until he walks up")


func test_the_street_locks_at_a_wave_until_its_beaten() -> void:
	var l = level()
	var at: float = l.data["waves"][0]["at"]
	walk_to(l, at)
	eq(l.active_wave, 0, "walking up to the first wave starts it")
	check(l.standing().size() >= 2, "its thugs are there (%d)" % l.standing().size())
	var lock: float = at + Level.LOCK_MARGIN
	eq(l.bounds().y, lock, "the street locks %d px past the wave" % int(Level.LOCK_MARGIN))
	beat_them(l)  # (so they don't fight back while he tries to walk on)
	for e in l.enemies:
		e["f"].health = 12.0
		e["f"]._enter("idle")
		e["brain"].wait = 100000
	for i in 600:
		l.step({"mx": 1.0})
	check(l.hero.x <= lock + 0.5, "while they stand he can't walk on past the lock (%.0f, lock %.0f)" % [l.hero.x, lock])
	beat_them(l)
	l.step({})
	eq(l.active_wave, -1, "beaten, the street opens")
	walk_to(l, lock + 200.0, 600)
	check(l.hero.x > lock, "and he walks on")


func test_up_the_stairs_to_the_boss_and_the_level_is_won() -> void:
	var l = level()
	for w in l.data["waves"].size():
		walk_to(l, l.data["waves"][w]["at"])
		l.step({})
		beat_them(l)
		l.step({})
	walk_to(l, l.data["stairs"] + 10.0)
	l.step({})
	eq(l.where, "upstairs", "past the last wave, the stairs take him up")
	eq(l.standing().size(), 1, "the boss waits there")
	eq(l.standing()[0].max_health, float(l.data["boss"]["health"]), "with his own health")
	check(not l.won, "not won yet")
	beat_them(l)
	l.step({})
	check(l.won, "the boss down for good: the level is won")


func test_three_lives_then_the_level_restarts() -> void:
	var l = level()
	for life in 3:
		l.hero.health = 0.0
		l.hero._enter("ko")
		for i in Level.DOWN_TICKS + 2:
			l.step({})
	check(l.lost, "the third life gone: the level is lost")
	l.restart()
	eq(l.lives, 3, "it restarts from the level's start with three lives")
	eq(l.hero.health, l.hero.max_health, "fresh")
	eq(l.where, "street", "on the street")


func test_a_life_lost_he_gets_up_where_he_was() -> void:
	var l = level()
	walk_to(l, 900.0)
	var x: float = l.hero.x
	l.hero.health = 0.0
	l.hero._enter("ko")
	for i in Level.DOWN_TICKS + 2:
		l.step({})
	eq(l.lives, 2, "one life gone")
	check(not l.lost, "the level goes on")
	eq(l.hero.health, l.hero.max_health, "up again, healed")
	check(absf(l.hero.x - x) < 1.0, "where he fell")


func test_the_bot_plays_level_one_through() -> void:
	# L-8: a bot plays every level on several seeds; a level it can't finish is a finding
	var results := []
	for s in [1, 2, 3]:
		var l = level(s)
		var bot = HeroBot.new(l.hero, s)
		for i in 30000:
			if l.won or l.lost:
				break
			if l.where == "upstairs" and bot.me != l.hero:
				bot.me = l.hero
			l.step(bot.think(l.standing()))
		results.append("won" if l.won else "%s at %.0f, wave %d, %s" % ["lost" if l.lost else "stuck", l.hero.x, l.wave, l.where])
	check(not results.any(func(r): return r.begins_with("stuck")), "the bot is never stuck: %s" % [results])
	check(results.count("won") >= 2, "and wins on most seeds: %s" % [results])


func test_only_two_attack_at_once() -> void:
	var l = level()
	walk_to(l, l.data["waves"][0]["at"])
	beat_them(l)
	l.step({})
	var w: Dictionary = l.data["waves"][1]
	walk_to(l, w["at"])
	for i in 30:
		l.step({})
	var turns: Array = l.enemies.filter(func(e): return not e["gone"]).map(func(e): return e["brain"].allowed)
	check(turns.size() >= 3, "a wave of three (%d)" % turns.size())
	eq(turns.count(true), Level.ATTACKERS, "only two may attack; the third waits his turn")


func test_food_and_first_aid_heal_the_hero() -> void:
	var l = level()
	check(l.data["items"].any(func(i): return i[0] == "food"), "level 1 has food on the street")
	var food: Array = ["food", 420.0, 80.0]
	l.world.drop("food", food[1], food[2])
	l.hero.health = 5.0
	for i in 60:
		l.step({"mx": 1.0})
	check(l.hero.health > 5.0, "walking over the food, hurt, he eats it (%.0f)" % l.hero.health)
	check(not l.world.items.any(func(i): return i["x"] == food[1]), "and it's gone")


## A two-floor layout (tests/levels/two_floors.json): stairs up at x 1500 and back down; a gate on the street at
## x 2000 that a switch upstairs at x 1800 opens; the boss beyond the gate.
func two_floors():
	return Level.new(Level.load_data("res://tests/levels/two_floors.json"), {}, 1)


func to_doorway(l, x: float) -> void:
	for i in 600:
		if absf(l.hero.x - x) <= 20.0 and l.hero.z <= Level.DOORWAY_Z:
			return
		var inp := {}
		if absf(l.hero.x - x) > 20.0:
			inp["mx"] = 1.0 if x > l.hero.x else -1.0
		if l.hero.z > Level.DOORWAY_Z:
			inp["mz"] = -1.0
		var floor_was: int = l.on
		l.step(inp)
		if l.on != floor_was:
			return


func test_the_stairs_take_him_up_through_the_doorway_at_the_back() -> void:
	var l = two_floors()
	walk_to(l, 900.0)
	beat_them(l, true)
	for i in 3:
		l.step({})
	walk_to(l, 1500.0)
	for i in 30:
		l.step({})
	eq(l.on, 0, "walking past the stairs along the front of the street, he stays")
	to_doorway(l, 1500.0)
	eq(l.on, 1, "into the doorway at the back: up the stairs")
	eq(l.where, "upstairs", "upstairs")
	for i in 30:
		l.step({})
	eq(l.on, 1, "he isn't bounced straight back down")
	for i in 40:
		l.step({"mz": 1.0, "mx": 1.0})
	to_doorway(l, 300.0)
	eq(l.on, 0, "stepping away and back into that doorway takes him down again")


func test_no_stairs_while_a_wave_is_on() -> void:
	var l = two_floors()
	walk_to(l, 900.0)
	check(l.active_wave >= 0, "a wave is on")
	for e in l.enemies:
		e["brain"].wait = 100000
	l.hero.x = 1500.0
	l.hero.z = 0.0
	for i in 5:
		l.step({})
	eq(l.on, 0, "the stairs wait until the wave is beaten")


func test_a_switch_upstairs_opens_the_gate_below() -> void:
	var l = two_floors()
	walk_to(l, 900.0)
	beat_them(l, true)
	for i in 3:
		l.step({})
	walk_to(l, 2100.0, 400)
	check(l.hero.x < 2000.0, "the gate stops him (%.0f)" % l.hero.x)
	l.hero.x = 1600.0
	to_doorway(l, 1500.0)
	eq(l.on, 1, "up the stairs")
	for i in 30:
		l.step({"mz": 1.0})
	walk_to(l, 1700.0)
	l.step({"punch": true})
	for i in 10:
		l.step({})
	check(l.flipped.has(0), "a blow on the switch flips it")
	check(l.floors[0]["world"].objects.any(func(o): return o.get("name", "") == "gate" and o["broken"]), "and the gate below is open")
	to_doorway(l, 300.0)
	eq(l.on, 0, "back down")
	check(not l.world.blocks(2020.0, 80.0, 0.0), "the gate no longer stops anyone (and the boss comes through it)")


func test_the_boss_down_wins_a_multi_floor_level() -> void:
	var l = two_floors()
	eq(l.standing().filter(func(f): return f.max_health == 40.0).size(), 1, "the boss waits on the street, beyond the gate")
	beat_them(l)
	l.step({})
	check(l.won, "the boss down for good wins it")


## Level 1 as the team laid it out (levels/level1.json)
func real_level(seed_value := 1):
	return Level.new(Level.load_data("res://levels/level1.json"), {}, seed_value)


## Smashes everything breakable in the way, as a player would (the barrier, the car, the crates).
func clear_path(l) -> void:
	for o in l.floors[0]["world"].objects:
		if o["breakable"]:
			o["broken"] = true


## The wave at index w on the street: walks there (earlier waves beaten for him, the way cleared).
func reach_wave(l, w: int) -> void:
	clear_path(l)
	for i in w:
		walk_to(l, l.floors[0]["waves"][i]["at"])
		for k in 400:
			beat_them(l, true)
			l.step({})
			if l.active_wave < 0:
				break
	walk_to(l, l.floors[0]["waves"][w]["at"] - 250.0)
	l.step({})


func test_level_one_is_the_teams_layout() -> void:
	var l = real_level()
	eq(l.floors[0]["length"], 7 * 1920.0, "seven street screens")
	var count := 0
	for w in l.floors[0]["waves"]:
		count += w["enemies"].size()
	eq(count, 17, "17 enemies on the street")
	eq(l.floors.size(), 2, "the street and the boss's room upstairs")


func test_enemies_come_from_the_sides_a_door_or_hiding() -> void:
	var l = real_level()
	reach_wave(l, 0)
	var at: float = l.floors[0]["waves"][0]["at"]
	for e in l.enemies:
		check(e["f"].x > at + Level.LOCK_MARGIN, "wave 1 walks in from off screen right, past the lock (%.0f)" % e["f"].x)
	reach_wave(l, 1)
	var hidden: Array = l.enemies.filter(func(e): return e["wave"] == 1 and e["brain"].dormant_until_within > 0.0)
	eq(hidden.size(), 1, "one waits hidden (the lamppost)")
	var x: float = hidden[0]["f"].x
	for i in 30:
		l.step({})
	eq(hidden[0]["f"].x, x, "still, while the hero is further off")
	eq(l.enemies.filter(func(e): return e["wave"] == 1).size(), 1, "the others wait until one is down")
	beat_them(l, true)
	l.step({})
	l.step({})
	var later: Array = l.enemies.filter(func(e): return e["wave"] == 1 and not e["f"].defeated())
	eq(later.size(), 3, "one down: the other three come in")
	check(later.any(func(e): return e["f"].z <= 10.0), "one out of a door at the back of the street")
	check(later.filter(func(e): return e["f"].x < l.hero.x - 100.0).size() == 2, "two from the left, behind him (at the fight's own screen edge: the team's second ruling)")


func test_never_more_than_five_at_once() -> void:
	var l = real_level()
	reach_wave(l, 3)
	var peak := 0
	for k in 6:
		peak = maxi(peak, l.standing().size())
		var one = l.standing()[0] if not l.standing().is_empty() else null
		if one != null:
			one.health = 0.0
			one._enter("ko")
		for i in 3:
			l.step({})
	check(peak >= 3, "the bakery fight really started (peak %d standing)" % peak)
	check(peak <= Level.MAX_ON_SCREEN, "at most five standing at once (peak %d)" % peak)


func test_they_leave_their_drops_and_crates_their_contents() -> void:
	var l = real_level()
	reach_wave(l, 0)
	beat_them(l, true)
	l.step({})
	check(l.world.items.filter(func(i): return i["kind"] == "takeaway").size() >= 2, "each Glow Punk leaves food")
	var crate: Dictionary = l.world.objects.filter(func(o): return o.get("holds", "") == "soda")[0]
	crate["strength"] = 0
	crate["broken"] = true
	l.hero.x = crate["x0"] - 60.0
	l.hero.z = 40.0
	var before: int = l.world.items.size()
	# smash it the way the game does: a blow on it
	crate["broken"] = false
	crate["strength"] = 1
	for i in 30:
		l.step({"kick": i == 0})
	check(crate["broken"], "the crate is smashed")
	check(l.world.items.size() > before, "and the soda inside falls out")


func test_the_bruiser_shrugs_off_a_jab() -> void:
	var l = real_level()
	reach_wave(l, 2)
	for i in 120:
		l.step({})
	var b = l.enemies.filter(func(e): return e["kind"] == "bruiser")[0]["f"]
	b._enter("idle")
	var hp: float = b.health
	b.take_hit({"damage": 1, "effect": "", "low": 120.0, "high": 230.0, "move": "punch"}, l.hero)
	check(b.health < hp, "a jab hurts him")
	eq(b.state, "idle", "but he doesn't flinch (Iron Gut)")
	b.take_hit({"damage": 2, "effect": "", "low": 0.0, "high": 110.0, "move": "kick"}, l.hero)
	eq(b.state, "hurt", "a kick does")


func test_the_bot_plays_the_teams_level_one_through() -> void:
	var results := []
	for s in [1, 2, 3]:
		var l = real_level(s)
		var bot = HeroBot.new(l.hero, s)
		for i in 30000:
			if l.won or l.lost:
				break
			bot.me = l.hero
			l.step(bot.think(l.standing()))
		results.append("won" if l.won else "%s at %.0f, wave %d, %s" % ["lost" if l.lost else "stuck", l.hero.x, l.wave, l.where])
	check(not results.any(func(r): return r.begins_with("stuck")), "the bot is never stuck: %s" % [results])
	check(results.count("won") >= 2, "and wins on most seeds: %s" % [results])


## DJ Volt, level 1's boss (the team's boss list)
func at_the_boss(seed_value := 1):
	var l = real_level(seed_value)
	clear_path(l)
	for i in l.floors[0]["waves"].size():
		walk_to(l, l.floors[0]["waves"][i]["at"])
		for k in 400:
			beat_them(l, true)
			l.step({})
			if l.active_wave < 0:
				break
	walk_to(l, 7 * 1920.0)
	l.step({})
	return l


func test_dj_volt_waits_upstairs_with_his_mic_stand() -> void:
	var l = at_the_boss()
	eq(l.where, "the club upstairs", "up the club's back stairs")
	var dj = l.enemies.filter(func(e): return e["boss"])[0]
	eq(dj["kind"], "dj_volt", "DJ Volt")
	eq(dj["f"].weapon, "mic_stand", "with his mic stand")


func test_from_range_he_throws_records_low_middle_high() -> void:
	var l = at_the_boss()
	var bands := []
	for i in 200:
		l.step({})
		for p in l.projectiles.flying:
			if not p.has("seen"):
				p["seen"] = true
				bands.append(int(p["y0"]))
	check(bands.size() >= 3, "records thrown (%s)" % [bands])
	eq(bands.slice(0, 3), [0, 110, 210], "low, middle, high")


func test_the_bass_drop_needs_his_speakers() -> void:
	var l = at_the_boss()
	for e in l.enemies:
		e["brain"].dormant_until_within = 1.0  # keep him still (he waits until the hero is within 1 px), so only the guard matters
	var pushed := false
	for i in Level.BASS_HOLD + 30:
		l.step({"block": true})
		pushed = pushed or l.bass_at > 0
	check(pushed, "a guard held two seconds while his speakers stand: the wave pushes him back")
	for o in l.world.objects:
		if o["kind"] == "speaker":
			o["broken"] = true
	l.bass_at = -1
	for i in Level.BASS_HOLD + 30:
		l.step({"block": true})
	eq(l.bass_at, -1, "both speakers smashed: no more wave")


func test_he_drops_the_bat() -> void:
	var l = at_the_boss()
	beat_them(l)
	l.step({})
	check(l.won, "DJ Volt down: level 1 won")
	check(l.world.items.any(func(i): return i["kind"] == "bat"), "and his prize, the bat, on the floor")


## The sparring friend on level 1's first screen (sim/tutor.gd)
func test_the_sparring_friend_teaches_one_thing_at_a_time() -> void:
	var l = real_level()
	check(l.friend != null, "he's there on screen 1")
	eq(l.tutor.lesson, "block", "first: block his slow punch")
	check(l.hint().contains("Hold D"), "with a hint on screen: %s" % l.hint())
	for i in 300:  # up to him, stopping in front (he doesn't block the street, so you could walk through)
		if l.hero.x >= l.friend.x - 120.0:
			break
		l.step({"mx": 1.0})
	# hold the guard while he punches: the block lesson passes; then a perfect block
	for i in 300:
		l.step({"block": true})
		if l.tutor.lesson != "block":
			break
	eq(l.tutor.lesson, "perfect", "blocked: now the perfect block")
	eq(l.hero.health, l.hero.max_health, "his blows never hurt")
	var passed := false
	for i in 600:
		# raise the guard just before his punch lands: the moment he starts it
		var up: bool = l.friend.attack_phase() == "startup"
		l.step({"block": up or l.hero.state == "block" and l.hero.t < 6})
		if l.tutor.lesson != "perfect":
			passed = true
			break
	check(passed, "a perfect block passes it")
	eq(l.tutor.lesson, "dizzy", "then: two combos in a row")
	l.friend.dizzy_left = 120
	l.friend._enter("dizzy")
	l.step({})
	eq(l.tutor.lesson, "finish", "dazed: now the third combo")
	l.tutor.saw([{"attacker": l.hero, "target": l.friend, "result": "hit", "move": "power_punch"}])
	eq(l.tutor.lesson, "done", "a finisher on him: done, he waves you on")
	check(l.friend.health > 0.0 and not l.friend.defeated(), "and he was never put down")


func test_you_can_walk_straight_past_him() -> void:
	var l = real_level()
	var home: float = l.friend.x
	walk_to(l, home + 500.0, 600)
	check(l.hero.x > home + 400.0, "he never blocks the street (%.0f, his spot %.0f)" % [l.hero.x, home])
	eq(l.tutor.lesson, "done", "walked past: no lesson forced")


## Level 2, the Night Market (the team's settled layout) and Big Mama Noodle
func level_two(seed_value := 1):
	return Level.new(Level.load_data("res://levels/level2.json"), {}, seed_value)


func test_level_two_is_the_teams_settled_layout() -> void:
	var l = level_two()
	var count := 0
	for w in l.floors[0]["waves"]:
		count += w["enemies"].size()
	eq(count, 19, "19 enemies on the street")
	check(l.floors[0]["world"].objects.any(func(o): return o["kind"] == "ladder"), "the short ladder to the awning")
	check(l.plan["links"][0].get("kind", "") == "ladder", "the long ladder up to the kitchen")
	eq(l.plan["boss"]["kind"], "big_mama", "Big Mama Noodle upstairs")


func in_the_kitchen():
	var l = level_two()
	for o in l.floors[0]["world"].objects:
		if o["breakable"]:
			o["broken"] = true
	for i in l.floors[0]["waves"].size():
		l.floors[0]["wave"] = l.floors[0]["waves"].size()
	l._go_to(1, 300.0)
	for e in l.enemies:
		e["brain"].dormant_until_within = 1.0  # still, unless a test moves her
	return l


func test_big_mamas_soup_comes_on_the_third_block() -> void:
	var l = in_the_kitchen()
	var m = l.enemies[0]["f"]
	m.x = l.hero.x + 110.0
	m.facing = -1
	var soups := 0
	for i in 3:
		l.events = [{"attacker": m, "target": l.hero, "result": "blocked"}]
		l._kitchen()
		soups += l.projectiles.flying.filter(func(p): return p["kind"] == "soup").size()
	eq(soups, 1, "the third block in a row brings the hot soup")


func test_she_slips_on_the_wet_patch() -> void:
	var l = in_the_kitchen()
	var m = l.enemies[0]["f"]
	var patch: Array = l.plan["floors"][1]["kitchen"]["wet"]
	m.x = (patch[0] + patch[1]) * 0.5
	m._enter("run")
	l.events = []
	l._kitchen()
	eq(m.state, "dizzy", "running onto the wet patch she slips, dazed at once")
	m._enter("idle")
	m.health = m.max_health * 0.5
	l._kitchen()
	check(not l.wet, "at half health she mops it dry")
	m._enter("run")
	l._kitchen()
	check(m.state != "dizzy", "dry, no slip")
	l.hero.x = l.plan["floors"][1]["kitchen"]["tap"] - 100.0
	l.hero.facing = 1
	l.hero.step({"punch": true})
	for i in 6:
		l.hero.step({})
		l._kitchen()
	check(l.wet, "a punch on the tap floods it again")


func test_her_wok_smash_knocks_a_guard_open() -> void:
	var l = in_the_kitchen()
	var m = l.enemies[0]["f"]
	var smash: Dictionary = Weapons.swing_data("smash", "wok")
	check(smash.get("guard_break", false), "the wok's smash breaks guards")
	for i in 20:
		l.hero.step({"block": true})  # a plain guard, held
	m.x = l.hero.x + 100.0
	eq(l.hero.take_hit(smash, m), "guard_broken", "it knocks the guard open")
	eq(l.hero.state, "stagger", "he reels")


func test_the_pipe_bruisers_pipe_snaps() -> void:
	var l = level_two()
	var w = l.floors[0]["world"]
	l._spawn("bruiser_pipe", 600.0, 80.0)
	var b = l.enemies[-1]["f"]
	eq(b.weapon, "pipe", "he carries his pipe")
	var before: int = w.items.size()
	b.health = 0.1
	var fight := Fight.new()
	l.hero.x = 480.0
	l.hero.facing = 1
	l.hero.step({"punch": true})
	for i in 10:
		l.hero.step({})
		b.step({})
		fight.step([l.hero, b], w)
	eq(b.weapon, "", "knocked down, he loses it")
	eq(w.items.filter(func(i): return i["kind"] == "pipe").size(), 0, "but it snapped: nothing to pick up (the pipe is level 5's prize)")


func test_the_bot_plays_level_two_through() -> void:
	var results := []
	for s in [1, 2, 3]:
		var l = level_two(s)
		var bot = HeroBot.new(l.hero, s)
		for i in 30000:
			if l.won or l.lost:
				break
			bot.me = l.hero
			bot.goal = l.next_door()
			l.step(bot.think(l.standing()))
		results.append("won" if l.won else "%s at %.0f, wave %d, %s" % ["lost" if l.lost else "stuck", l.hero.x, l.wave, l.where])
	check(not results.any(func(r): return r.begins_with("stuck")), "the bot is never stuck: %s" % [results])
	check(results.count("won") >= 2, "and wins on most seeds: %s" % [results])


func test_the_umbrella_takes_one_blow_then_breaks() -> void:
	var l = real_level()
	var u: Array = l.plan["floors"][0]["items"].filter(func(i): return i[0] == "umbrella")[0]
	l.hero.x = u[1] - 80.0
	l.hero.z = u[2]
	for i in 40:
		l.step({"mx": 1.0})
	eq(l.hero.shield, 1, "walking over the umbrella, he takes it up")
	var hp: float = l.hero.health
	eq(l.hero.take_hit({"damage": 3, "effect": ""}, l.friend), "umbrella", "it takes the blow")
	eq(l.hero.health, hp, "he isn't hurt")
	eq(l.hero.shield, 0, "and it's broken")
	eq(l.hero.take_hit({"damage": 3, "effect": ""}, l.friend), "hit", "the next blow lands")


func test_stand_by_the_stray_cat_and_it_follows() -> void:
	var l = real_level()
	l.floors[0]["wave"] = l.floors[0]["waves"].size()  # the street's fights already won
	l.hero.x = l.cat.x - 40.0
	l.hero.z = l.cat.y
	for i in Level.CAT_FEED_TICKS + 5:
		l.step({})
	check(l.cat_fed, "standing by it a moment: fed")
	check("cat" in l.collected, "and kept")
	for i in 200:
		l.step({"mx": -1.0})
	check(absf(l.cat.x - l.hero.x) < 160.0, "it trots at his heels (%.0f, he's at %.0f)" % [l.cat.x, l.hero.x])



## Level 3, Pawn Row (the team's agreed page, 2026-11-04)
func test_level_three_is_the_teams_agreed_layout() -> void:
	var d: Dictionary = Level.load_data("res://levels/level3.json")
	var l = Level.new(d, {}, 1)
	eq(l.floors.size(), 4, "the street, the flat above and the fire escape, the street again, Twin Loans' shop")
	eq(l.hero.weapon, "wrench", "he walks in with Big Mama's wrench")
	var kinds := []
	for fl in d["floors"]:
		for w in fl["waves"]:
			for e in w["enemies"]:
				kinds.append(e["kind"])
	eq(kinds.size(), 17, "17 placed, and the Whistler's first two Mechanics make the page's 19 (21 if he whistles twice)")
	check(not kinds.has("glow_punk"), "no Glow Punks in level 3")
	check(d["floors"][0]["obstacles"].any(func(o): return o[0] == "stairs"), "the pawn shop's stairs")
	check(d["floors"][1]["obstacles"].any(func(o): return o[0] == "gap"), "the fire escape's gap")
	eq(d["boss"]["kind"], "twin_short", "Twin Loans")


func test_the_bot_plays_level_three_and_is_never_stuck() -> void:
	var results := []
	for s in [1, 2, 3]:
		var l = Level.new(Level.load_data("res://levels/level3.json"), {}, s)
		var bot = HeroBot.new(l.hero, s)
		var deepest := 0
		for i in 40000:
			if l.won or l.lost:
				break
			bot.me = l.hero
			bot.goal = l.next_door()
			l.step(bot.think(l.standing()))
			deepest = maxi(deepest, l.on)
		results.append("won" if l.won else ("lost on floor %d" % deepest if l.lost else "STUCK on floor %d at %.0f" % [l.on, l.hero.x]))
	check(not results.any(func(r): return r.begins_with("STUCK")), "never stuck: %s" % [results])
	check(results.all(func(r): return r == "won" or r.ends_with("2") or r.ends_with("3")), "down the fire escape every time: %s" % [results])


## Levels 4 to 10, drafts from Merry's levels page (the Council, 2026-11-04: "build them as drafts so nothing waits")
func test_the_draft_levels_load_and_say_so() -> void:
	var names: Array = Level.load_data("res://levels/levels.json")["levels"]
	eq(names.size(), 10, "all ten levels in the play order")
	for n in ["level3", "level4", "level5", "level6"]:  # (settled from the team's agreed pages)
		check(not Level.load_data("res://levels/%s.json" % n).get("draft", false), "%s is settled, not a draft" % n)
	for n in ["level7", "level8", "level9", "level10"]:
		var d: Dictionary = Level.load_data("res://levels/%s.json" % n)
		check(d.get("draft", false), "%s is marked a draft" % n)
		check(d["about"].contains("NOT BUILT YET"), "%s lists what isn't built yet" % n)
		var l = Level.new(d, {}, 1)
		check(l.floors.size() >= 2, "%s has its floors (%d)" % [n, l.floors.size()])
		check(not d.get("boss", {}).is_empty() or not d.get("win", {}).is_empty(), "%s ends in a boss or a prize" % n)


func test_the_bot_is_never_stuck_in_a_draft_level() -> void:
	var results := []
	for n in ["level4", "level5", "level6", "level7", "level8", "level9", "level10"]:
		var l = Level.new(Level.load_data("res://levels/%s.json" % n), {}, 1)
		var bot = HeroBot.new(l.hero, 1)
		for i in 30000:
			if l.won or l.lost:
				break
			bot.me = l.hero
			bot.goal = l.next_door()
			bot.goal_hit = l.goal_is_switch
			bot.jump_cue = l.crane_jump_cue()
			bot.dodge_x = l.shadow_cue()
			bot.climb = l.climb_cue()
			l.step(bot.think(l.standing()))
		results.append("%s %s" % [n, "won" if l.won else ("lost on floor %d" % l.on if l.lost else "STUCK on floor %d at %.0f" % [l.on, l.hero.x])])
	check(not results.any(func(r): return r.contains("STUCK")), "never stuck: %s" % [results])


## A wave's late arrivals ("after_down": come in once that many of the wave are down) can always come: never waiting
## on more than the rest of the wave (2026-11-04: level 9's lookout waited for three down after a cut left two, and
## the screen never cleared).
func test_every_wave_can_finish() -> void:
	var names: Array = Level.load_data("res://levels/levels.json")["levels"].duplicate()
	names.append_array(["roster_yard", "coach_gym", "chrome_casino", "static_plant", "rook_penthouse", "crane_docks", "tower_top"])
	var waves := 0
	for n in names:
		var d: Dictionary = Level.load_data("res://levels/%s.json" % n)
		for fi in d["floors"].size():
			for wi in d["floors"][fi].get("waves", []).size():
				var list: Array = d["floors"][fi]["waves"][wi].get("enemies", [])
				waves += 1
				for e in list:
					check(int(e.get("after_down", 0)) <= list.size() - 1, "%s F%d wave %d: the %s waits for %d down, the wave has %d others" % [
						n, fi, wi, e["kind"], int(e.get("after_down", 0)), list.size() - 1])
	check(waves > 20, "the waves were really read (%d)" % waves)



## Level 5, settled (art-in 2026-11-04-level5-layout-final): 20 enemies (10 Snicks, 5 Doormen, 5 Dancers), the Doorman
## met alone first, no pipe on the street, the vending machine: a snack, a note, then over onto whoever's in front.
func test_level_5_as_the_team_settled_it() -> void:
	var d: Dictionary = Level.load_data("res://levels/level5.json")
	var kinds := {}
	for f in d["floors"]:
		for w in f.get("waves", []):
			for e in w["enemies"]:
				kinds[e["kind"]] = kinds.get(e["kind"], 0) + 1
	eq(kinds, {"doorman": 5, "snick": 9, "neon_dancer": 5}, "19 enemies: 9 Snicks, 5 Doormen, 5 Dancers (the testers' ruling after the shield rule, 2026-11-05)")
	eq(d["floors"][0]["waves"][0]["enemies"].map(func(e): return e["kind"]), ["doorman"], "the Doorman, first time, alone")
	check(not d["floors"].any(func(f): return f.get("items", []).any(func(i): return i[0] == "pipe")), "no pipe on the street")
	eq(d["boss"].get("drops", ""), "pipe", "the pipe is Madame Chrome's prize")
	var l = Level.new(d, {}, 1)
	var vend: Dictionary = l.world.objects.filter(func(o): return o["kind"] == "vending")[0]
	l._spawn("doorman", (vend["x0"] + vend["x1"]) * 0.5, vend["z1"] + 40.0)
	var doorman = l.enemies[-1]["f"]
	l.hero.x = vend["x0"] - 40.0
	var drops := []
	for k in 3:
		vend["hits"] = vend.get("hits", 0) + 1
		vend["hit_team"] = l.hero.team
		vend["hit_move"] = "kick"
		var before: int = l.world.items.size()
		l._vending()
		if l.world.items.size() > before:
			drops.append(l.world.items[-1]["kind"])
	eq(drops, ["snack", "note"], "first kick a snack, second an apology note")
	check(vend["broken"], "the third tips it over")
	eq(doorman.state, "knockdown", "onto the Doorman in front of it, shield or no shield")


func test_level_5s_second_escalator_snick_waits_at_the_top_till_the_first_is_down() -> void:
	var l = Level.new(Level.load_data("res://levels/level5.json"), {}, 1)
	var fl: Dictionary = l.floors[0]
	var w: int = fl["waves"].map(func(x): return x["at"]).find(6750.0)
	check(w >= 0, "(screen 4's wave)")
	fl["wave"] = w
	l.hero.x = 6750.0
	l.step({})
	var sn: Array = l.enemies.filter(func(e): return e["wave"] == w)
	eq(sn.size(), 2, "both Snicks in sight on the escalator")
	var second: Dictionary = sn.filter(func(e): return e.has("waits_till_down"))[0]
	var x0: float = second["f"].x
	for i in 120:
		l.step({})
	check(absf(second["f"].x - x0) < 1.0 and second["f"].attack_phase() == "", "the second waits at the top, still, while the first fights")
	var first: Dictionary = sn.filter(func(e): return e != second)[0]
	first["f"].health = 0.0
	first["f"]._enter("ko")
	l.step({})
	check(not second.has("waits_till_down"), "the first down: the second comes down")
	var b: Array = Level.load_data("res://levels/level5.json")["floors"][1]["obstacles"].filter(func(o): return o[0] == "buffet")
	check(b[0][2] <= 300.0, "the shrimp plate at the balcony's left end, at the top of the escalator (x %d-%d)" % [b[0][1], b[0][2]])


func test_level_5s_balcony_doorman_starts_on_the_right_half_and_the_second_snick_waits_by_the_tables() -> void:
	var l = Level.new(Level.load_data("res://levels/level5.json"), {}, 1)
	l._go_to(1, 300.0)
	l.hero.x = 650.0  # (just past the wave's line)
	l.step({})
	var door: Array = l.enemies.filter(func(e): return e["kind"] == "doorman")
	check(not door.is_empty() and door[0]["f"].x >= 960.0, "the Doorman starts on the balcony's right half (x %.0f), never at the top of the escalator" % (door[0]["f"].x if not door.is_empty() else -1.0))
	var sn: Array = l.enemies.filter(func(e): return e["kind"] == "snick")
	eq(sn.size(), 2, "both Snicks in sight")
	var waiting: Array = sn.filter(func(e): return e.has("waits_till_down"))
	eq(waiting.size(), 1, "one waits his turn")
	check(waiting[0]["f"].x > 760.0 and waiting[0]["f"].x < 1000.0, "by the card tables (x %.0f)" % waiting[0]["f"].x)
	door[0]["f"].health = 0.0
	door[0]["f"]._enter("ko")
	l.step({})
	check(waiting[0].has("waits_till_down"), "the Doorman down doesn't send him: he waits for the first Snick")
	var first: Dictionary = sn.filter(func(e): return e != waiting[0])[0]
	first["f"].health = 0.0
	first["f"]._enter("ko")
	l.step({})
	check(not waiting[0].has("waits_till_down"), "the first Snick down: he comes")
