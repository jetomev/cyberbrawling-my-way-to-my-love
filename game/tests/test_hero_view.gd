extends "res://tests/test_case.gd"
## The grey-box body on bones: the skeleton is whole, every move has a pose, the poses only name real bones, the
## walk loops without a hitch, the drawn fist and foot reach where the logic says a blow lands, and the demo shows
## every move.

const Poses := preload("res://scripts/present/poses.gd")
const HeroView := preload("res://scripts/present/hero_view.gd")
const Fighter := preload("res://scripts/sim/fighter.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")
const Demo := preload("res://scripts/sim/demo.gd")

const STATES := ["idle", "walk", "jump", "land", "punch", "kick"]


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
			check(key == "hip_y" or Poses.BONES.has(key), "pose key %s is a bone" % key)


func test_every_move_has_a_pose() -> void:
	var t := Tuning.fresh()
	var guard := Poses.full({})
	for s in STATES:
		check(Poses.LOOPS.has(s) or Poses.SHOTS.has(s), "%s has a pose" % s)
		var a := Poses.angles(s, 3, t)
		eq(a.size(), guard.size(), "%s sets every bone" % s)
	var punch := Poses.angles("punch", t["punch_startup"], t)
	check(punch["arm_f_upper"] < guard["arm_f_upper"] - 30.0, "the punch throws the front arm forward")


func test_walk_loops_without_a_hitch() -> void:
	var t := Tuning.fresh()
	var length: int = Poses.LOOPS["walk"][0]
	var a := Poses.angles("walk", 0, t)
	var b := Poses.angles("walk", length, t)
	for k in a:
		check(is_equal_approx(a[k], b[k]), "walk %s matches across the loop" % k)
	var last := Poses.angles("walk", length - 1, t)
	check(absf(last["leg_f_upper"] - a["leg_f_upper"]) < 8.0, "the last frame flows into the first")


func test_drawn_blows_reach_where_they_hit() -> void:
	var t := Tuning.fresh()
	var fist := Poses.tip("arm_f_lower", Poses.angles("punch", t["punch_startup"], t))
	var foot := Poses.tip("leg_f_lower", Poses.angles("kick", t["kick_startup"], t))
	check(absf(fist.x - t["punch_reach"]) <= 15.0, "drawn fist at %.0f px, the punch reaches %.0f" % [fist.x, t["punch_reach"]])
	check(absf(foot.x - t["kick_reach"]) <= 15.0, "drawn foot at %.0f px, the kick reaches %.0f" % [foot.x, t["kick_reach"]])
	check(fist.y < -150.0 and fist.y > -240.0, "the punch is at head-to-chest height (%.0f)" % fist.y)
	check(foot.y < -90.0 and foot.y > -200.0, "the kick is at body height (%.0f)" % foot.y)


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
	var f = Fighter.new(Tuning.fresh(), 400.0, 80.0)
	var seen := {}
	for i in Demo.length():
		f.step(Demo.input_at(i))
		seen[f.state] = true
		check(f.x >= f.tune["street_left"] and f.x <= f.tune["street_right"], "stays on the street") if i % 60 == 0 else null
	for s in STATES:
		check(seen.has(s), "the demo shows %s" % s)
	var presses := 0
	for i in Demo.length():
		var inp := Demo.input_at(i)
		presses += int(inp.get("punch", false)) + int(inp.get("kick", false)) + int(inp.get("jump", false))
	eq(presses, 6, "each button press fires once, not every tick of its step")
