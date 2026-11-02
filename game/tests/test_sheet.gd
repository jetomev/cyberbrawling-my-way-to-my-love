extends "res://tests/test_case.gd"
## The assistant team's posture sheet (2026-11-02, from coaching guides and motion studies): the guard, and every
## punch and kick in four poses (wind-up, hit, follow-through, back in guard). Rules for all of them: feet and hips
## start it, the spare hand stays home by the cheek, chin down, the hand or foot comes back the way it went, knees
## never lock but for the kicking leg at the hit, about 60% of the weight on the front foot when punching.

const Poses := preload("res://scripts/present/poses.gd")
const Moves := preload("res://scripts/sim/moves.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")


static func mid(bone: String, b: Dictionary) -> Vector2:
	var e: Array = Poses._end(bone, b)
	return e[0] - Vector2(Poses.BONES[bone][3] * 0.5, 0).rotated(e[1])


static func at(m: String, moment: String, t: Dictionary) -> Dictionary:
	return Poses.bake(Poses.angles(m, Poses.moment(m, moment, t), t), true)


static func written(m: String, moment: String) -> Dictionary:
	for k in Poses.SHOTS[m]:
		if k[0] == moment:
			return Poses.full(k[1])
	return Poses.full({})


func test_the_guard() -> void:
	var t := Tuning.fresh()
	var g := Poses.bake(Poses.angles("idle", 0, t), true)
	var head := mid("head", g)
	var front := mid("hand_f", g)
	var rear := mid("hand_b", g)
	for fist in [front, rear]:
		check(absf(fist.y - head.y) < 30.0, "fists at cheekbone height (%.0f px from the middle of the head)" % (fist.y - head.y))
	check(front.x - rear.x >= 25.0, "the front fist a forearm ahead of the rear one (%.0f px)" % (front.x - rear.x))
	check(Poses.GUARD["pivot_b"] >= 30.0 and Poses.GUARD["pivot_b"] <= 60.0, "the back foot turned out about 45 degrees")
	var heel: Vector2 = Poses._end("leg_b_lower", g)[0]
	check(heel.y < -1.0 and heel.y > -12.0, "the back heel slightly up (%.0f px)" % -heel.y)
	check(absf((Poses._end("toe_b", g)[0] as Vector2).y) < 1.0, "on the ball of the back foot")


func test_the_spare_hand_stays_home() -> void:
	var t := Tuning.fresh()
	for pair in [["punch", "b"], ["cross", "f"], ["hook", "b"], ["uppercut", "f"], ["elbow", "b"]]:
		for tt in range(0, Moves.length(pair[0], t) + 1):
			var b := Poses.bake(Poses.angles(pair[0], tt, t), true)
			# home: the rear fist at the cheek; the front fist a forearm ahead of it, or tucked to the cheek
			var d: float = mid("hand_" + pair[1], b).distance_to(mid("head", b))
			var home: float = 40.0 if pair[1] == "b" else 68.0
			check(d < home, "%s@%d: the spare fist stays home (%.0f px from the head)" % [pair[0], tt, d])
	for m in ["kick", "push_kick", "body_kick", "spin_kick"]:
		var b := at(m, "active", t)
		for side in ["f", "b"]:
			check(mid("hand_" + side, b).distance_to(mid("head", b)) < (40.0 if side == "b" else 68.0), "%s: both hands stay up at the hit (%s)" % [m, side])


func test_the_jab() -> void:
	var t := Tuning.fresh()
	var g := Poses.bake(Poses.angles("idle", 0, t), true)
	var w := at("punch", "windup", t)
	var hit := at("punch", "active", t)
	var follow := at("punch", "follow", t)
	var home := mid("hand_f", g)
	check(mid("hand_f", w).x >= home.x - 12.0, "the wind-up pulls nothing back (%.0f px)" % (mid("hand_f", w).x - home.x))
	check(written("punch", "windup")["step_f"] >= 4.0, "the front foot slides forward an inch")
	check(mid("hand_f", follow).distance_to(home) < mid("hand_f", hit).distance_to(home) - 20.0, "it snaps straight back")
	check(written("punch", "active")["hip_x"] <= 8.0, "almost no hip")


func test_the_cross() -> void:
	var t := Tuning.fresh()
	var ww := written("cross", "windup")
	for tt in range(0, Poses.moment("cross", "windup", t)):
		# every frame up to the wind-up (at the wind-up frame itself the arm, a frame ahead, is already on its way)
		var b := Poses.bake(Poses.angles("cross", tt, t), true)
		check(mid("hand_b", b).distance_to(mid("head", b)) < 40.0, "cross@%d: until it lets go the rear fist is still home" % tt)
	check(ww["rise_b"] >= 0.2 and ww["turn"] > 0.0, "the back heel lifts and the hips begin to turn first")
	var hit := at("cross", "active", t)
	check(absf(hit["leg_f_lower"]) <= 40.0, "the front leg is firm, a post (%.0f)" % hit["leg_f_lower"])
	var f: Vector2 = Poses._end("leg_f_lower", hit)[0]
	var bk: Vector2 = Poses._end("leg_b_lower", hit)[0]
	var hip: Vector2 = Poses._end("hip", hit)[0]
	var share: float = (hip.x - bk.x) / (f.x - bk.x)
	check(share >= 0.55 and share <= 0.8, "about 60%% of the weight on the front foot (%.0f%%)" % (share * 100.0))
	check(written("cross", "active")["pivot_b"] >= 40.0, "the back foot pivots on its ball")


func test_the_hook() -> void:
	var t := Tuning.fresh()
	check(written("hook", "windup")["hip_x"] > 0.0, "the wind-up dips the weight onto the front foot")
	var hit := at("hook", "active", t)
	check(written("hook", "active")["pivot_f"] >= 40.0, "the front foot pivots on its ball")
	var fist: Vector2 = Poses._end("hand_f", hit)[0]
	var elbow: Vector2 = Poses._end("arm_f_upper", hit)[0]
	check(absf(fist.y - elbow.y) <= 12.0, "the arm is a level hoop, the fist level with the elbow (%.0f px)" % (fist.y - elbow.y))
	var after: Vector2 = Poses._end("hand_f", at("hook", "follow", t))[0]
	check(after.x <= fist.x + 5.0, "it never swings past (%.0f px)" % (after.x - fist.x))


func test_the_uppercut_and_the_elbow() -> void:
	var t := Tuning.fresh()
	check(written("uppercut", "active")["turn"] > 0.0, "the uppercut turns the hips toward the punch")
	var after := at("uppercut", "follow", t)
	check(mid("hand_b", after).y >= mid("head", after).y - 12.0, "it rises to eye height, no higher")
	check(written("elbow", "windup")["hip_x"] > 0.0, "the elbow's wind-up puts the weight onto the front foot")
	var e := at("elbow", "active", t)
	check(mid("hand_f", e).distance_to(mid("head", e)) < 34.0, "the elbow's fist ends by his own ear (%.0f px)" % mid("hand_f", e).distance_to(mid("head", e)))
	var point: Vector2 = Poses._end("arm_f_upper", e)[0]
	check(point.y < mid("head", e).y + 34.0, "the elbow is raised to head height, at the jaw (%.0f px under the middle of the head)" % (point.y - mid("head", e).y))


func test_the_front_kick_chambers() -> void:
	var t := Tuning.fresh()
	var w := at("kick", "windup", t)
	var thigh: float = rad_to_deg(Poses._end("leg_f_upper", w)[1])
	check(absf(thigh) <= 20.0, "the knee comes up to hip height, the thigh level (%.0f degrees)" % thigh)
	var knee: Vector2 = Poses._end("leg_f_upper", w)[0]
	var foot: Vector2 = Poses._end("leg_f_lower", w)[0]
	check(absf(foot.x - knee.x) <= 18.0, "the foot hangs under the knee (%.0f px)" % (foot.x - knee.x))
	# (written: by the drawn wind-up frame the hips are already pushing forward, three frames ahead of the leg)
	var weight: float = written("kick", "windup")["hip_x"] - (Poses.STANCE["b"] as Vector2).x
	check(absf(weight) <= 25.0, "the weight onto the back foot: the hips over it (%.0f px)" % weight)
	var lean: float = written("kick", "active")["torso"]
	check(lean >= -16.0 and lean <= 0.0, "at the hit he leans back a touch (%.0f)" % lean)
	check(Poses.angles("kick", Poses.moment("kick", "follow", t), t)["leg_f_lower"] >= 60.0, "then the leg snaps back to the chamber")
	var push := at("push_kick", "windup", t)
	check((Poses._end("leg_f_upper", push)[0] as Vector2).y < knee.y, "the push kick chambers the knee higher")
	check(absf(Poses.angles("push_kick", Poses.moment("push_kick", "follow", t), t)["leg_f_lower"]) <= 15.0, "and holds the leg out a moment")


func test_the_round_kick_and_the_knee() -> void:
	var t := Tuning.fresh()
	var ww := written("roundhouse", "windup")
	check(ww["step_f"] > 0.0 and ww["hip_x"] > 0.0, "the round kick steps the front foot out and puts the weight on it")
	var r := at("roundhouse", "active", t)
	var rear := mid("hand_b", r)
	check(rear.y > (Poses._end("shoulder_b", r)[0] as Vector2).y and rear.x < mid("head", r).x, "the arm on the kicking side swings down and back to balance")
	check(mid("hand_f", r).distance_to(mid("head", r)) < 68.0, "the other hand guards the face")
	var kw := written("knee", "windup")
	check(kw["open_f"] == 1.0 and kw["open_b"] == 1.0, "the knee reaches with both hands open")
	var k := at("knee", "active", t)
	for side in ["f", "b"]:
		check(mid("hand_" + side, k).y > mid("chest", k).y, "and pulls them down onto the knee (%s)" % side)


func test_the_knee_reads_in_stages_and_the_round_kick_recoils() -> void:
	# the testers' joint review: the knee shows reach, grab, hip drive and pull-down before lowering; the round kick
	# shows its recoil
	var t := Tuning.fresh()
	var grab := written("knee", "sweep")
	check(grab["open_f"] == 0.0 and grab["open_b"] == 0.0, "between the reach and the knee the hands close on a grab")
	var g := at("knee", "sweep", t)
	check(mid("hand_f", g).x > mid("head", g).x + 25.0, "still out in front, holding")
	var hit := at("knee", "active", t)
	var after := at("knee", "follow", t)
	check(written("knee", "follow")["leg_f_upper"] <= -90.0, "the knee stays up while the pull finishes")
	check(mid("hand_f", after).y > mid("hand_f", hit).y, "the hands keep pulling down before the knee lowers")
	check(written("knee", "active")["hip_x"] > written("knee", "sweep")["hip_x"], "the hips drive forward into it")
	check(written("roundhouse", "follow")["leg_b_lower"] >= 90.0, "after the round kick lands the leg recoils, folding back")


func test_the_body_kick_is_a_snap_kick() -> void:
	# the testers asked: snap or push? A snap: chamber, flick, snap back (the push kick is the P, P, K finisher)
	var t := Tuning.fresh()
	var w := at("body_kick", "windup", t)
	check(absf(rad_to_deg(Poses._end("leg_b_upper", w)[1])) <= 20.0, "the rear knee comes up to hip height, the thigh level")
	check(Poses.angles("body_kick", Poses.moment("body_kick", "follow", t), t)["leg_b_lower"] >= 60.0, "then it snaps back to the chamber")
	check(Moves.data("body_kick", t)["effect"] != "push", "it doesn't shove")
