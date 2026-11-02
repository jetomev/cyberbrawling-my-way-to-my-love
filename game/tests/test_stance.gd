extends "res://tests/test_case.gd"
## The stance and the posture under every move (Javier, 2026-11-02 morning: "posture and movements ... still
## terrible ... more attention to detail"; the assistant team: the stance first, then the posture through every move).
## The guard is low and wide with the weight between the feet, the chin is down, the guard is never dead still, the
## walk is a fighter's shuffle, and a planted foot stays where it is through every strike.

const Poses := preload("res://scripts/present/poses.gd")
const Moves := preload("res://scripts/sim/moves.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")


static func bend(baked: Dictionary, side: String) -> float:
	return absf(baked["leg_%s_lower" % side])


static func ankle(baked: Dictionary, side: String) -> Vector2:
	return Poses._end("leg_%s_lower" % side, baked)[0]


func test_the_stance_is_low_and_wide() -> void:
	var t := Tuning.fresh()
	var g := Poses.bake(Poses.angles("idle", 0, t), true)
	var f := ankle(g, "f")
	var b := ankle(g, "b")
	check(f.x - b.x >= 95.0, "the feet stand wider than the shoulders (%.0f px apart)" % (f.x - b.x))
	check(bend(g, "f") >= 35.0, "the front knee is well bent (%.0f)" % bend(g, "f"))
	check(bend(g, "b") >= 10.0 and bend(g, "b") <= 40.0, "the back leg is nearly straight, never locked (%.0f)" % bend(g, "b"))
	var hip: Vector2 = Poses._end("hip", g)[0]
	check(-hip.y <= 110.0, "the hips are dropped (%.0f px up; standing tall they were 125)" % -hip.y)
	var middle := (f.x + b.x) * 0.5
	check(absf(hip.x - middle) <= 0.25 * (f.x - b.x), "the weight sits between the feet (%.0f px from the middle)" % (hip.x - middle))
	for side in ["f", "b"]:
		check(absf((Poses._end("toe_" + side, g)[0] as Vector2).y) < 1.0 and absf(ankle(g, side).y) < 1.0, "the %s foot is flat on the street" % side)


func test_the_chin_is_down() -> void:
	var g := Poses.bake(Poses.angles("idle", 0, Tuning.fresh()), true)
	var head: float = rad_to_deg(Poses._end("head", g)[1])
	check(head > -88.0, "the head tips forward, chin down (%.0f; straight up is -90)" % head)


func test_the_guard_is_never_dead_still() -> void:
	var t := Tuning.fresh()
	var a := Poses.bake(Poses.angles("idle", 15, t), true)
	var b := Poses.bake(Poses.angles("idle", 45, t), true)
	check(absf(b["hip_x"] - a["hip_x"]) >= 10.0, "the weight rocks from the back leg to the front (%.0f px)" % absf(b["hip_x"] - a["hip_x"]))
	# the knees give: a dip written into a pose really lowers the hips (it used to be wiped out by the feet settling)
	var flat := Poses.bake(Poses.full({}), true)
	var dip := Poses.bake(Poses.full({"hip_y": 10.0}), true)
	var drop: float = (Poses._end("hip", dip)[0] as Vector2).y - (Poses._end("hip", flat)[0] as Vector2).y
	check(absf(drop - 10.0) < 1.0, "a 10 px dip lowers the hips 10 px (%.1f)" % drop)
	check(Poses.angles("idle", 45, t)["hip_y"] - Poses.angles("idle", 15, t)["hip_y"] >= 3.0, "the knees give as the weight comes forward")
	var start := Poses.angles("idle", 0, t)
	var guard := Poses.full({})
	for k in guard:
		check(is_equal_approx(start[k], guard[k]), "the idle starts at the plain guard, where every move ends (%s)" % k)


func test_the_walk_is_a_shuffle() -> void:
	var t := Tuning.fresh()
	var v: float = t["walk_speed"]
	var last := {}
	for tt in range(0, 2 * Poses.WALK_CYCLE + 1):
		var pose := Poses.angles("walk", tt, t)
		var b := Poses.bake(pose, true)
		var f := ankle(b, "f")
		var bk := ankle(b, "b")
		check(f.x - bk.x > 40.0, "walk@%d: the feet never pass each other (%.0f px apart)" % [tt, f.x - bk.x])
		for side in ["f", "b"]:
			# where the toes are on the street: the body travels at the walking speed
			var world: float = v * tt + (Poses._end("toe_" + side, b)[0] as Vector2).x
			var planted: bool = pose["lift_" + side] == 0.0
			if planted and last.has(side) and tt > Poses.WALK_EASE_IN:
				check(absf(world - last[side]) < 0.5, "walk@%d: the planted %s foot stays put (slid %.1f px)" % [tt, side, world - last[side]])
			last[side] = world if planted else null
			if not planted:
				last.erase(side)
	var lifted := false
	for tt in Poses.WALK_CYCLE:
		lifted = lifted or Poses.angles("walk", tt, t)["lift_f"] > 8.0
	check(lifted, "a stepping foot leaves the street")


func test_planted_feet_stay_put_through_every_strike() -> void:
	var t := Tuning.fresh()
	var g := Poses.bake(Poses.angles("idle", 0, t), true)
	for m in ["punch", "cross", "hook", "elbow", "uppercut", "kick", "push_kick", "body_kick", "knee", "block"]:
		var length := Moves.length(m, t) if Moves.is_move(m) else 20
		for tt in range(0, length + 1):
			var b := Poses.bake(Poses.angles(m, tt, t), true)
			var striker: String = Moves.data(m, t)["limb"].split("_")[1] if Moves.is_move(m) else ""
			for side in ["f", "b"]:
				if side == striker and m in ["kick", "push_kick", "body_kick", "knee"]:
					continue  # the kicking leg leaves the street; this is about the one he stands on
				if not Poses._planted(b, side):
					continue
				# the ball of the foot against the guard's, both measured from the hips' home spot (no hip shift)
				var toe: Vector2 = Poses._end("toe_" + side, b)[0]
				# where the move slides it to (a step-up before a front-leg kick), or else where it stood in the guard
				var home: Vector2 = (Poses._end("toe_" + side, g)[0] as Vector2) + Vector2(Poses.angles(m, tt, t)["step_" + side], 0)
				check(absf(toe.x - home.x) < 4.0, "%s@%d: the planted %s foot stays on its spot (%.1f px off)" % [m, tt, side, toe.x - home.x])


func test_a_front_leg_kick_stands_tall_on_the_back_foot() -> void:
	# the first stance build: the front kicks were thrown out of a lunge, the standing leg slanting far behind
	var t := Tuning.fresh()
	for m in ["kick", "push_kick", "knee", "spin_kick"]:
		var b := Poses.bake(Poses.angles(m, Moves.data(m, t)["startup"], t), true)
		var hip: Vector2 = Poses._end("hip", b)[0]
		var foot: Vector2 = ankle(b, "b")
		check(absf(foot.x - hip.x) < 30.0, "%s: the standing foot has stepped up under the hips (%.0f px off)" % [m, foot.x - hip.x])
