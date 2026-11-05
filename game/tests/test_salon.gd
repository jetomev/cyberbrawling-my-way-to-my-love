extends "res://tests/test_case.gd"
## Level 5's boss room, Madame Chrome's salon (the team's agreed page): the floor and a balcony across the back, her
## glass lift between them (up she goes, two rounds of three cards thrown down at him, shadow first, then down again for
## the sweep and the jab), the spiral stair up to her (a ladder), the chandelier a blow from the balcony drops on her.

const Level := preload("res://scripts/sim/level.gd")


func salon():
	var l = Level.new(Level.load_data("res://levels/level5.json"), {}, 1)
	l._go_to(4, 1300.0, 0.0, 110.0)
	l.step({})
	var e: Dictionary = l.enemies.filter(func(e): return e["kind"] == "chrome")[0]
	return [l, e]


func test_the_room_has_its_balcony_stair_lift_and_chandelier() -> void:
	var d: Dictionary = Level.load_data("res://levels/level5.json")
	var fl: Dictionary = d["floors"][4]
	var kinds: Array = fl["obstacles"].map(func(o): return o[0])
	for k in ["balcony", "ladder", "chandelier", "table"]:
		check(k in kinds, "the salon has its %s" % k)
	check(fl.has("chrome_lift"), "and her glass lift")
	check(fl["items"].any(func(it): return it[0] == "chocolates"), "the chocolates: the room's only food")


func test_up_in_her_lift_her_cards_down_at_him_then_down_again() -> void:
	var le: Array = salon()
	var l = le[0]
	var e: Dictionary = le[1]
	var f = e["f"]
	var seen := {}
	var top := 0.0
	for i in 900:
		l.step({})
		top = maxf(top, f.y)
		for ev in l.events:
			var r: String = ev.get("result", "")
			if r in ["lift_up", "lift_down", "card_down"]:
				seen[r] = seen.get(r, 0) + 1
		if seen.has("lift_down"):
			break
	eq(seen.get("lift_up", 0), 1, "she rides her lift up")
	check(top >= 219.0, "all the way to the balcony (%.0f px)" % top)
	eq(seen.get("card_down", 0), 3 * Level.ROUNDS_UP, "two rounds of three cards thrown down at him (time to follow her up)")
	eq(seen.get("lift_down", 0), 1, "then down again")
	for i in Level.LIFT_TICKS + 5:
		l.step({})
	check(f.y < 1.0, "back on the floor")


func test_up_there_she_never_walks_off_the_edge() -> void:
	var le: Array = salon()
	var l = le[0]
	var f = le[1]["f"]
	var was_up := false
	var fell := false
	for i in 600:
		l.step({})
		if f.y > 219.0:
			was_up = true
		if was_up and f.y < 1.0 and not le[1].has("ride") and not l.events.any(func(ev): return ev.get("result", "") == "lift_down"):
			fell = fell or le[1].get("down_after", -1) >= 0
	check(was_up, "(she went up)")
	check(not fell, "and came down only in her lift")


func test_the_chandelier_drops_only_to_a_blow_from_the_balcony_and_stuns_her() -> void:
	var le: Array = salon()
	var l = le[0]
	var f = le[1]["f"]
	var ch: Dictionary = l.world.objects.filter(func(o): return o["kind"] == "chandelier")[0]
	var h = l.hero
	le[1]["brain"].wait = 9999
	le[1]["brain"].dormant_until_within = 1.0  # (she stands where she's put)
	f.x = 1500.0  # (out of the way while he punches from the floor)
	h.x = 660.0
	h.z = 100.0
	h.facing = 1
	for i in 30:  # from the floor: out of reach
		l.step({"punch": i % 12 == 0})
	check(not ch["broken"], "punched at from the floor: it hangs on")
	f.x = 800.0  # now under it (its fall reaches 90 px from its middle, 740)
	f.z = 100.0
	f._enter("idle")
	h.z = 35.0
	h.y = 220.0
	var dropped := false
	for i in 30:
		l.step({"punch": i % 12 == 0})
		dropped = dropped or l.events.any(func(ev): return ev.get("result", "") == "chandelier_drop")
		if dropped:
			break
	check(dropped and ch["broken"], "from the balcony: it drops")
	eq(f.state, "dizzy", "right on her: stunned")
