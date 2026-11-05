extends "res://tests/test_case.gd"
## The boss rush (the team's agreed list): nine bosses, each in his own room, three lives for the run, noodles between
## fights, nothing in hand at the start, each prize earned, the Lovelight before the Godfather.

const BossRush := preload("res://scripts/sim/boss_rush.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")


func test_nine_bosses_each_in_his_room() -> void:
	var fights: Array = BossRush.fights()
	eq(fights.size(), 9, "nine (level 9 has no boss)")
	var kinds := []
	for i in fights.size():
		var l = BossRush.start(i, BossRush.fresh_carry(), Tuning.fresh(), 1)
		var bosses: Array = l.enemies.filter(func(e): return e["boss"])
		if fights[i]["level"] == "level6":
			check(l.plan.get("crane", {}).get("floors", []).any(func(n): return int(n) == l.on), "the Crane Operator's yard: his crane on the floor he starts on")
			kinds.append("crane_operator")
		else:
			check(not bosses.is_empty(), "%s: the boss is there" % fights[i]["level"])
			kinds.append(bosses[0]["kind"] if not bosses.is_empty() else "?")
	eq(kinds, ["dj_volt", "big_mama", "twin_short", "coach", "chrome", "crane_operator", "static", "rook", "godfather"], "in order")


func test_nothing_in_hand_at_the_start_noodles_between_and_the_lovelight_for_the_godfather() -> void:
	var first = BossRush.start(0, BossRush.fresh_carry(), Tuning.fresh(), 1)
	eq(first.hero.weapon, "", "the first fight: nothing in hand")
	eq(first.lives, 3, "three lives for the run")
	check(not first.world.items.any(func(it): return it["kind"] == "noodles"), "(no noodles before the first)")
	var carry := {"lives": 2, "health": 17.0, "weapon": "bat", "rubber": false}
	var second = BossRush.start(1, carry, Tuning.fresh(), 1)
	eq([second.lives, second.hero.health, second.hero.weapon], [2, 17.0, "bat"], "the run's lives, health and weapon carried in")
	check(second.world.items.any(func(it): return it["kind"] == "noodles"), "a bowl of noodles between fights")
	var gf = BossRush.start(8, carry, Tuning.fresh(), 1)
	eq(gf.hero.weapon, "lovelight", "the Lovelight handed over before the Godfather")


func test_each_prize_is_earned() -> void:
	var l = BossRush.start(0, BossRush.fresh_carry(), Tuning.fresh(), 1)
	var out: Dictionary = BossRush.carry_out(l)
	eq(out["weapon"], "bat", "DJ Volt's prize, the bat, in hand for the next")
	var s = BossRush.start(6, BossRush.fresh_carry(), Tuning.fresh(), 1)
	check(BossRush.carry_out(s)["rubber"], "Mr. Static's rubber gloves, kept on")
