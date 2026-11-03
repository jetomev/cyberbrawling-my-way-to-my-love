extends "res://tests/test_case.gd"
## The grey-box body on bones: the skeleton is whole, every move has a pose, the poses only name real bones, the
## walk loops without a hitch, the drawn fist and foot reach where the logic says a blow lands, and the demo shows
## every move.

const Poses := preload("res://scripts/present/poses.gd")
const HeroView := preload("res://scripts/present/hero_view.gd")
const Fighter := preload("res://scripts/sim/fighter.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")
const Demo := preload("res://scripts/sim/demo.gd")
const StreetWorld := preload("res://scripts/sim/street_world.gd")

const STATES := ["idle", "walk", "jump", "land", "punch", "kick", "air_kick", "climb", "block"]
const Moves := preload("res://scripts/sim/moves.gd")


func test_skeleton_is_whole() -> void:
	var seen := []
	for name in Poses.BONES:
		var parent: String = Poses.BONES[name][0]
		check(parent == "" or parent in seen, "%s comes after its parent %s" % [name, parent])
		seen.append(name)
	var v = HeroView.new()
	eq(v.bones.size(), Poses.BONES.size(), "every bone is built")
	check(v.skeleton is Skeleton2D, "the parts hang on a Skeleton2D")
	var parts := 0
	for name in v.bones:
		check(v.bones[name] is Bone2D, "%s is a Bone2D" % name)
		if v.bones[name].get_node_or_null("Part") != null:
			parts += 1
	eq(parts, Poses.BONES.size() - 1, "a grey part on every bone but the hip")
	v.free()


func test_poses_name_only_real_bones() -> void:
	var tables := [Poses.GUARD]
	for s in Poses.LOOPS:
		for k in Poses.LOOPS[s].slice(1):
			tables.append(k[1])
	for s in Poses.SHOTS:
		for k in Poses.SHOTS[s]:
			tables.append(k[1])
	for table in tables:
		for key in table:
			check(key in Poses.SOFT_KEYS or Poses.BONES.has(key), "pose key %s is a bone or a soft key" % key)


func test_every_move_has_a_pose() -> void:
	var t := Tuning.fresh()
	var guard := Poses.full({})
	for s in STATES + Moves.TABLE.keys():
		check(Poses.LOOPS.has(s) or Poses.SHOTS.has(s), "%s has a pose" % s)
		var a := Poses.angles(s, 3, t)
		eq(a.size(), guard.size(), "%s sets every bone" % s)
	var punch := Poses.angles("punch", t["punch_startup"], t)
	check(punch["arm_f_upper"] < guard["arm_f_upper"] - 30.0, "the punch throws the front arm forward")


func test_walk_loops_without_a_hitch() -> void:
	var t := Tuning.fresh()
	var length: int = Poses.LOOPS["walk"][0]
	# (the first steps ease out of the guard, so compare a cycle in with the next one)
	var a := Poses.angles("walk", length, t)
	var b := Poses.angles("walk", 2 * length, t)
	for k in a:
		check(is_equal_approx(a[k], b[k]), "walk %s matches across the loop" % k)
	var last := Poses.angles("walk", 2 * length - 1, t)
	check(absf(last["leg_f_upper"] - a["leg_f_upper"]) < 8.0, "the last frame flows into the first")


func test_drawn_blows_reach_where_they_hit() -> void:
	# every ground move: the striking limb's drawn tip lands within 15 px of the logic's reach, at a height inside
	# the band the logic uses for hits (the picture never lies about what connects)
	var t := Tuning.fresh()
	for m in Moves.TABLE:
		if Moves.is_air(m):
			continue
		var d := Moves.data(m, t)
		var tip := Poses.drawn_tip(d["limb"], Poses.angles(m, d["startup"], t))  # as drawn (a spin flips it)
		check(absf(tip.x - d["reach"]) <= 15.0, "%s: drawn tip at %.0f px, reach %.0f" % [m, tip.x, d["reach"]])
		check(-tip.y >= d["low"] and -tip.y <= d["high"], "%s: tip height %.0f inside %.0f..%.0f" % [m, -tip.y, d["low"], d["high"]])
	var fist := Poses.tip("arm_f_lower", Poses.angles("punch", t["punch_startup"], t))
	var foot := Poses.tip("leg_f_lower", Poses.angles("front_kick", Moves.data("front_kick", t)["startup"], t))
	var low := Poses.tip("foot_f", Poses.angles("kick", t["kick_startup"], t))
	check(fist.y < -150.0 and fist.y > -240.0, "the jab is at head-to-chest height (%.0f)" % fist.y)
	check(foot.y < -90.0 and foot.y > -200.0, "the front kick is at body height (%.0f)" % foot.y)
	check(low.y > -100.0, "the low kick goes to the knee (%.0f)" % low.y)


func test_view_follows_the_fighter() -> void:
	var f = Fighter.new()
	var v = HeroView.new()
	f.x = 1234.0
	f.z = 50.0
	f.facing = -1
	f.y = 80.0
	v.sync(f, 760.0)
	eq(v.position, Vector2(1234.0, 810.0), "stands on the street at its depth")
	eq(v.body.scale.x, -1.0, "faces left")
	eq(v.body.position.y, -80.0, "the body rises with a jump")
	eq(v.shadow.position, Vector2.ZERO, "the shadow stays on the ground")
	eq(v.z_index, 50, "nearer fighters draw on top")
	v.free()


func test_demo_shows_every_move() -> void:
	var w = StreetWorld.grey_street()
	var f = Fighter.new(Tuning.fresh(), 400.0, 80.0, w)
	var seen := {}
	var past_crate_two_on_ground := false
	var roll_from := INF
	var roll_went := 0.0
	for i in Demo.length():
		var was: String = f.state
		f.step(Demo.input_at(i))
		w.step_hits([f])
		seen[f.state] = true
		if f.state == "roll" and was != "roll" and roll_from == INF:
			roll_from = f.x
		if was == "roll" and f.state != "roll" and roll_went == 0.0:
			roll_went = absf(f.x - roll_from)
		if f.x > 2724.0 and f.y == 0.0 and f.state != "climb":
			past_crate_two_on_ground = true
	for s in STATES + ["cross", "power_punch", "push_kick", "body_kick", "side_kick", "knee", "uppercut", "elbow", "roundhouse", "hammer_fist", "sweep", "roll"]:
		check(seen.has(s), "the demo shows %s" % s)
	check(w.objects[0]["broken"], "it smashes the first crate")
	check(not w.objects[2]["broken"] and past_crate_two_on_ground, "it jumps the second crate")
	check(not w.objects[1]["broken"], "the car survives")
	check(roll_went >= 100.0, "the demo's first roll travels along the street, not stuck on something (%.0f px)" % roll_went)
	var presses := 0
	var button_steps := 0
	for st in Demo.STEPS:
		button_steps += int(st[1].get("punch", false)) + int(st[1].get("kick", false)) + int(st[1].get("jump", false))
	for i in Demo.length():
		var inp := Demo.input_at(i)
		presses += int(inp.get("punch", false)) + int(inp.get("kick", false)) + int(inp.get("jump", false))
	eq(presses, button_steps, "each button press fires once, not every tick of its step")


func test_the_close_up_points_follow_the_drawing() -> void:
	# the reviewers' close-ups (D-22) are cut around these points, so they must sit on the drawn hips, hands and feet
	var t := Tuning.fresh()
	var v = HeroView.new()
	v.apply(Poses.angles("idle", 0, t))
	var guard: Dictionary = v.points()
	eq(guard.keys(), ["hip", "hand_f", "hand_b", "foot_f", "foot_b", "head"], "hips, both hands, both feet, the head")
	check(guard["head"].y < guard["hip"].y - 100.0, "the head point is the top of the head (%.0f)" % guard["head"].y)
	check(absf(guard["hip"].y - v.bones["hip"].position.y) < 1.0, "the hip point is at the hips (%.0f)" % guard["hip"].y)
	for side in ["f", "b"]:
		check(guard["foot_" + side].y > -40.0 and guard["foot_" + side].y < 4.0, "the %s foot point is on the street (%.0f)" % [side, guard["foot_" + side].y])
		check(guard["hand_" + side].y < guard["hip"].y, "the %s hand point is above the hips in the guard" % side)
	v.apply(Poses.angles("cross", Moves.data("cross", t)["startup"], t))
	var hit: Dictionary = v.points()
	check(hit["hand_b"].x > guard["hand_b"].x + 40.0, "on the cross the back hand point goes out with the fist (%.0f to %.0f)" % [guard["hand_b"].x, hit["hand_b"].x])
	v.body.scale.x = -1.0
	check(v.points()["hand_b"].x < 0.0, "facing left, the points turn with the body")
	v.free()


func _at(v, name: String) -> Vector2:
	var t := Transform2D.IDENTITY
	var n: Node = v.bones[name]
	while n != v:
		t = (n as Node2D).transform * t
		n = n.get_parent()
	return t.origin


func test_a_pivoted_standing_foot_shows_its_heel_to_the_target() -> void:
	# the testers' joint session (2026-11-02 20:30) on build a26ccd7: on the side kick and the round kick the standing
	# foot's toe still pointed at the target at the hit and just after. The pose had the pivot; the drawing flipped the
	# foot back but left the toe out in front. At the hit and 50 ms after, the toe is behind the ankle (heel forward).
	var t := Tuning.fresh()
	var v = HeroView.new()
	v.apply(Poses.angles("idle", 0, t))
	check(_at(v, "toe_f").x > _at(v, "foot_f").x + 10.0, "in the guard the front toe points ahead (the check can see a toe ahead)")
	for pair in [["side_kick", "b"], ["roundhouse", "f"]]:
		var hit: int = Moves.data(pair[0], t)["startup"]
		for tick in [hit, hit + 3]:
			v.apply(Poses.angles(pair[0], tick, t))
			var ankle := _at(v, "foot_" + pair[1])
			var toe := _at(v, "toe_" + pair[1])
			check(toe.x < ankle.x - 10.0, "%s@%d: the standing toe points away from the target, heel to it (toe %.0f, ankle %.0f)" % [pair[0], tick, toe.x, ankle.x])
	v.free()


func test_the_roll_turns_a_full_circle_along_the_street() -> void:
	# the drawn body tumbles all the way round, rolling on the street (never drawn through it), and ends upright
	var t := Tuning.fresh()
	var v = HeroView.new()
	var most := 0.0  # the turn added up frame by frame (a rotation reads -180..180)
	var prev := 0.0
	var lowest := -INF
	for tick in t["roll_ticks"]:
		var p := Poses.angles("roll", tick, t)
		p["tumble_dir"] = 1.0
		v.apply(p)
		most += wrapf(v.body.rotation_degrees - prev, -180.0, 180.0)
		prev = v.body.rotation_degrees
		for name in v.bones:
			lowest = maxf(lowest, _at(v, name).y)
		lowest = maxf(lowest, v.points()["head"].y)  # the top of the head too
	check(absf(most) >= 300.0, "a full circle (%.0f degrees)" % most)
	check(lowest <= 2.0, "rolling on the street, never through it (%.0f px under it)" % lowest)
	v.apply(Poses.angles("idle", 0, t))
	check(absf(v.body.rotation_degrees) < 0.5, "upright again after it")
	v.free()


func _worst_jump(script: Array, skip := 0) -> Array:
	# drive a fighter through [ticks, input] steps; the biggest frame-to-frame jump of a drawn foot or hand, with the
	# body's own travel taken out, and the frame it happened on
	var f = Fighter.new()
	var v = HeroView.new()
	var last := {}
	var worst := 0.0
	var at := -1
	var n := 0
	for step in script:
		for i in step[0]:
			f.step(step[1])
			v.sync(f, 0.0)
			var pts: Dictionary = v.points()
			if not last.is_empty() and n >= skip:
				for k in ["foot_f", "foot_b", "hand_f", "hand_b"]:
					var d: float = ((pts[k] - pts["hip"]) - (last[k] - last["hip"])).length()
					if d > worst:
						worst = d
						at = n
			last = pts
			n += 1
	v.free()
	return [worst, at]


func test_starting_to_run_flows_from_the_last_step() -> void:
	# the run's first steps snapped: they eased in from standing, not from wherever the legs were. Into a run from the
	# everyday walk and from the fighting shuffle, and out of it again, no foot or hand jumps further in one frame than
	# it does in a steady run (plus a little)
	var steady: float = _worst_jump([[60, {"mx": 1.0, "run": true}]], 20)[0]
	var cases := {
		"from the walk": [[1, {"stance": true}], [20, {}], [37, {"mx": 1.0}], [20, {"mx": 1.0, "run": true}]],
		"from the shuffle": [[29, {"mx": 1.0}], [20, {"mx": 1.0, "run": true}]],
		"stopping": [[30, {"mx": 1.0, "run": true}], [20, {}]],
	}
	for name in cases:
		var c: Array = _worst_jump(cases[name])
		check(c[0] <= steady + 6.0, "%s: the biggest jump of a hand or foot is %.0f px (frame %d; a steady run's is %.0f)" % [name, c[0], c[1], steady])


func test_the_roll_goes_over_the_shoulder_not_the_head() -> void:
	# a real roll tucks the chin to the chest: upside down, the upper back and shoulder take the street, not the head
	var t := Tuning.fresh()
	var v = HeroView.new()
	var seen := 0
	for tick in t["roll_ticks"]:
		var p := Poses.angles("roll", tick, t)
		if p["tumble"] < 150.0 or p["tumble"] > 210.0:
			continue
		p["tumble_dir"] = 1.0
		v.apply(p)
		seen += 1
		# (the testers, 2026-11-02 22:33, on 98a076f: at 8 px the head still came too close: tucked clear)
		check(v.points()["head"].y <= -20.0, "roll@%d (turned %.0f): the head clear of the street (%.0f px)" % [tick, p["tumble"], -v.points()["head"].y])
	check(seen >= 2, "the roll passes upside down (%d frames)" % seen)
	v.free()


func test_the_roll_dips_side_on_with_the_arm_guiding() -> void:
	# the team's roll reference (judo and aikido forward rolls): in the dip he is side-on, chin tucked, the leading arm
	# reaching forward and down, curved like a hoop, to guide him over the shoulder
	var t := Tuning.fresh()
	var p := Poses.angles("roll", Poses.moment("roll", "roll_down", t), t)
	check(p["turn"] >= 40.0, "side-on in the dip (turned %.0f)" % p["turn"])
	var b := Poses.bake(p, true)
	var shoulder: Vector2 = Poses._end("shoulder_f", b)[0]
	var hand: Vector2 = Poses._end("hand_f", b)[0]
	check(hand.x > shoulder.x + 20.0 and hand.y > shoulder.y + 30.0, "the leading arm reaching forward and down (hand %.0f ahead, %.0f below the shoulder)" % [hand.x - shoulder.x, hand.y - shoulder.y])
	check(absf(b["arm_f_lower"]) >= 15.0 and absf(b["arm_f_lower"]) <= 70.0, "curved like a hoop, not locked or folded (elbow %.0f)" % absf(b["arm_f_lower"]))


func test_the_roll_goes_hand_then_back() -> void:
	# the testers asked to see the shoulder carrying the roll (00:57 on 66ce4c6); the close-up showed him hovering on
	# the head's clearance with nothing touching. Now he is placed by his drawn outline: the guiding hand touches first,
	# then the back carries him, upper back to lower back (whose surface is the hips' too), and he comes up onto his
	# feet. Between the hand and the back the tucked head's clearance holds him a few px up for four frames (67 ms):
	# held there
	var t := Tuning.fresh()
	var v = HeroView.new()
	var order: Array[String] = []
	var back := 0
	var on_head := 0
	for tick in t["roll_ticks"]:
		var p := Poses.angles("roll", tick, t)
		if p["tumble"] == 0.0:
			continue
		p["tumble_dir"] = 1.0
		v.apply(p)
		var part: String = {"hand_f": "hand", "hand_b": "hand", "arm_f_lower": "hand", "chest": "back", "shoulder_f": "back",
			"shoulder_b": "back", "belly": "back", "hip": "hips"}.get(v.contact, "")
		if part == "back":
			back += 1
		if v.contact == "head" or v.contact == "neck":
			on_head += 1
		if part != "" and (order.is_empty() or order[-1] != part):
			order.append(part)
	eq(order, ["hand", "back"] as Array[String], "the guiding hand, then the back")
	check(back >= 8, "the back carries him for more than a tenth of a second (%d frames)" % back)
	check(on_head <= 4, "on the head's clearance for at most 4 frames (%d)" % on_head)
	v.free()


func test_the_flying_kick_lands_into_a_balanced_guard() -> void:
	# the testers' joint session on f744019 (23:29): the flying kick's landing is abrupt; it should absorb into a
	# balanced guard. Through the touchdown no hand or foot jumps further in a frame than in a steady run, and the hips
	# sink and come back up over several frames
	var steady: float = _worst_jump([[60, {"mx": 1.0, "run": true}]], 20)[0]
	var f = Fighter.new(Tuning.fresh(), 1200.0)
	var v = HeroView.new()
	var last := {}
	var worst := 0.0
	var at := -1
	var hips := []
	var touch := -1
	var script := [[1, {"jump": true, "mx": 1.0}], [8, {"mx": 1.0}], [1, {"kick": true}], [80, {}]]
	var n := 0
	for st in script:
		for i in st[0]:
			var was_air: bool = not f.on_ground()
			f.step(st[1])
			v.sync(f, 0.0)
			var pts: Dictionary = v.points()
			if was_air and f.on_ground() and touch < 0:
				touch = n
			if touch >= 0:
				hips.append(pts["hip"].y - v.body.position.y)
				if not last.is_empty() and n - touch <= 20:
					for k in ["foot_f", "foot_b", "hand_f", "hand_b"]:
						var d: float = ((pts[k] - pts["hip"]) - (last[k] - last["hip"])).length()
						if d > worst:
							worst = d
							at = n - touch
			last = pts
			n += 1
	check(touch >= 0, "it lands")
	check(worst <= steady + 6.0, "landing, no hand or foot jumps more than in a steady run (%.0f px, %d frames after touchdown; run %.0f)" % [worst, at, steady])
	var deepest := 0
	for i in hips.size():
		if hips[i] > hips[deepest]:
			deepest = i
	check(hips[deepest] - hips[0] >= 8.0 and deepest >= 2, "the knees take it: the hips sink (%.0f px, deepest %d frames in)" % [hips[deepest] - hips[0], deepest])
	v.free()
