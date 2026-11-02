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
		var tip := Poses.tip(d["limb"], Poses.angles(m, d["startup"], t))
		check(absf(tip.x - d["reach"]) <= 15.0, "%s: drawn tip at %.0f px, reach %.0f" % [m, tip.x, d["reach"]])
		check(-tip.y >= d["low"] and -tip.y <= d["high"], "%s: tip height %.0f inside %.0f..%.0f" % [m, -tip.y, d["low"], d["high"]])
	var fist := Poses.tip("arm_f_lower", Poses.angles("punch", t["punch_startup"], t))
	var foot := Poses.tip("leg_f_lower", Poses.angles("kick", t["kick_startup"], t))
	check(fist.y < -150.0 and fist.y > -240.0, "the jab is at head-to-chest height (%.0f)" % fist.y)
	check(foot.y < -90.0 and foot.y > -200.0, "the front kick is at body height (%.0f)" % foot.y)


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
	for i in Demo.length():
		f.step(Demo.input_at(i))
		w.step_hits([f])
		seen[f.state] = true
		if f.x > 2724.0 and f.y == 0.0 and f.state != "climb":
			past_crate_two_on_ground = true
	for s in STATES + ["cross", "hook", "body_kick", "spin_kick", "knee", "uppercut", "elbow", "roundhouse", "hammer_fist"]:
		check(seen.has(s), "the demo shows %s" % s)
	check(w.objects[0]["broken"], "it smashes the first crate")
	check(not w.objects[2]["broken"] and past_crate_two_on_ground, "it jumps the second crate")
	check(not w.objects[1]["broken"], "the car survives")
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
