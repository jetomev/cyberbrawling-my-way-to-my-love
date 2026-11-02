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
		var poses := []
		for tt in range(0, Moves.length(pair[0], t) + 1):
			poses.append(Poses.angles(pair[0], tt, t))
		for bad in dropped(poses, pair[1]):
			check(false, "%s@%d: the spare fist stays home (%.0f px from the head)" % [pair[0], bad[0], bad[1]])
		check(true, "%s: spare hand checked on %d frames" % [pair[0], poses.size()])
	for m in ["kick", "front_kick", "push_kick", "body_kick", "spin_kick", "side_kick"]:
		var b := at(m, "active", t)
		for side in ["f", "b"]:
			check(mid("hand_" + side, b).distance_to(mid("head", b)) < (40.0 if side == "b" else 68.0), "%s: both hands stay up at the hit (%s)" % [m, side])


## The frames of a move where the spare fist has left home: [frame, how far from the middle of the head]. Home is the
## rear fist at the cheek, or the front fist a forearm ahead of it (or tucked to the cheek).
static func dropped(poses: Array, side: String) -> Array:
	var out := []
	for i in poses.size():
		var b := Poses.bake(poses[i], true)
		var d: float = mid("hand_" + side, b).distance_to(mid("head", b))
		if d >= (40.0 if side == "b" else 68.0):
			out.append([i, d])
	return out


func test_the_spare_hand_check_catches_a_dropped_hand() -> void:
	# the testers asked to see it catch one: a deliberately wrong jab, the rear hand dropped to the waist
	var t := Tuning.fresh()
	var real := []
	var wrong := []
	for tt in range(0, Moves.length("punch", t) + 1):
		var p := Poses.angles("punch", tt, t)
		real.append(p)
		var w := p.duplicate()
		w["cover_b"] = 0.0
		w["arm_b_upper"] = 10.0  # the rear arm hanging, the fist down by the waist
		w["arm_b_lower"] = -40.0
		wrong.append(w)
	eq(dropped(real, "b"), [], "the real jab: the spare fist stays home every frame")
	eq(dropped(wrong, "b").size(), wrong.size(), "the wrong jab: the check catches the dropped hand on every frame")


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
	check(point.y < mid("head", e).y + 22.0, "the elbow is raised to head height, within the head (%.0f px under its middle)" % (point.y - mid("head", e).y))


func test_the_front_kick_chambers() -> void:
	var t := Tuning.fresh()
	var w := at("front_kick", "windup", t)
	var thigh: float = rad_to_deg(Poses._end("leg_f_upper", w)[1])
	check(absf(thigh) <= 20.0, "the knee comes up to hip height, the thigh level (%.0f degrees)" % thigh)
	var knee: Vector2 = Poses._end("leg_f_upper", w)[0]
	var foot: Vector2 = Poses._end("leg_f_lower", w)[0]
	check(absf(foot.x - knee.x) <= 18.0, "the foot hangs under the knee (%.0f px)" % (foot.x - knee.x))
	# (written: by the drawn wind-up frame the hips are already pushing forward, three frames ahead of the leg)
	var weight: float = written("front_kick", "windup")["hip_x"] - (Poses.STANCE["b"] as Vector2).x
	check(absf(weight) <= 25.0, "the weight onto the back foot: the hips over it (%.0f px)" % weight)
	var lean: float = written("front_kick", "active")["torso"]
	check(lean >= -16.0 and lean <= 0.0, "at the hit he leans back a touch (%.0f)" % lean)
	check(Poses.angles("front_kick", Poses.moment("front_kick", "follow", t), t)["leg_f_lower"] >= 60.0, "then the leg snaps back to the chamber")
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


func test_the_jab_comes_home_the_way_it_went_out() -> void:
	# the testers' review of 0812a0e: the jab's fist dipped below its outward line at +33 ms and bent back at +50
	var t := Tuning.fresh()
	var out_from: Vector2 = Poses._end("hand_f", Poses.bake(Poses.angles("punch", 0, t), true))[0]
	var hit: int = Moves.data("punch", t)["startup"]
	var out_to: Vector2 = Poses._end("hand_f", Poses.bake(Poses.angles("punch", hit, t), true))[0]
	for tt in range(hit, Moves.length("punch", t) + 1):
		var fist: Vector2 = Poses._end("hand_f", Poses.bake(Poses.angles("punch", tt, t), true))[0]
		var off: float = Geometry2D.get_closest_point_to_segment(fist, out_from, out_to).distance_to(fist)
		check(off <= 8.0, "punch@%d: the fist comes back along its outward line (%.0f px off it)" % [tt, off])


func test_the_spin_kick_folds_back_before_it_lowers() -> void:
	# the testers' review of 0812a0e: the leg stayed long to +200 ms and lowered nearly straight (12 degrees at +250)
	var t := Tuning.fresh()
	var hit: int = Moves.data("spin_kick", t)["startup"]
	for ms in [200, 250]:
		var b := Poses.bake(Poses.angles("spin_kick", hit + roundi(ms * 60.0 / 1000.0), t), true)
		check(absf(b["leg_f_lower"]) >= 90.0, "+%d ms: the knee is folded back (%.0f degrees)" % [ms, absf(b["leg_f_lower"])])
		var knee: Vector2 = Poses._end("leg_f_upper", b)[0]
		check(knee.y < (Poses._end("hip", b)[0] as Vector2).y + 10.0, "+%d ms: a high chamber, the knee up at hip height" % ms)


func test_the_low_kick() -> void:
	# opens every kick chain (Javier, 2026-11-02 18:19): a small knee lift, the foot to the knee or shin, upright,
	# a quick return, the fastest kick
	var t := Tuning.fresh()
	check(written("kick", "windup")["leg_f_upper"] >= -60.0, "a small knee lift, not a chamber")
	var tip := Poses.tip("foot_f", Poses.angles("kick", Moves.data("kick", t)["startup"], t))
	check(-tip.y <= 100.0, "the foot goes to the knee or shin (%.0f px up)" % -tip.y)
	check(written("kick", "active")["torso"] >= 0.0, "the upper body stays upright")
	for m in ["front_kick", "body_kick", "push_kick", "roundhouse", "side_kick"]:
		check(Moves.length("kick", t) < Moves.length(m, t), "faster than the %s" % m)


func test_the_power_punch() -> void:
	# ends the three-punch chain (Javier, 2026-11-02 18:19): the posture sheet's power punch, from a bow stance
	var t := Tuning.fresh()
	var w := at("power_punch", "windup", t)
	check(written("power_punch", "windup")["hip_y"] >= 8.0, "the wind-up sinks into a wide stance")
	check(mid("hand_b", w).y > mid("chest", w).y, "the rear fist drawn back to the hip")
	var hit := at("power_punch", "active", t)
	check(written("power_punch", "active")["step_f"] >= 20.0, "the front foot steps and plants")
	check(absf(hit["leg_f_lower"]) >= 40.0 and absf(hit["leg_b_lower"]) <= 25.0, "a bow stance: front knee bent (%.0f), back leg straight (%.0f)" % [absf(hit["leg_f_lower"]), absf(hit["leg_b_lower"])])
	var f: Vector2 = Poses._end("leg_f_lower", hit)[0]
	var bk: Vector2 = Poses._end("leg_b_lower", hit)[0]
	var share: float = ((Poses._end("hip", hit)[0] as Vector2).x - bk.x) / (f.x - bk.x)
	check(share >= 0.62 and share <= 0.82, "about 70%% of the weight forward (%.0f%%)" % (share * 100.0))
	var fist: Vector2 = Poses._end("hand_b", hit)[0]
	check(fist.y > (Poses._end("shoulder_b", hit)[0] as Vector2).y, "the fist goes straight to the chest, under shoulder height")
	check(mid("hand_f", hit).y > mid("chest", hit).y, "the spare fist pulled back to the hip")
	var held: Vector2 = Poses._end("hand_b", at("power_punch", "follow", t))[0]
	check(held.distance_to(fist) < 6.0, "it holds the bow stance a beat (the fist moves %.0f px)" % held.distance_to(fist))


func test_the_side_kick() -> void:
	# ends the three-kick chain, to the face (Javier, 2026-11-02 18:19): the posture sheet's side kick
	var t := Tuning.fresh()
	var ww := written("side_kick", "windup")
	check(ww["step_b"] >= 40.0 and ww["hip_y"] < 0.0, "the back foot steps up and the body rises")
	var w := at("side_kick", "windup", t)
	check((Poses._end("leg_f_upper", w)[0] as Vector2).y < (Poses._end("hip", w)[0] as Vector2).y, "the kicking knee comes up above the hips")
	var wa := written("side_kick", "active")
	check(wa["pivot_b"] >= 150.0, "the standing foot turns its heel to the enemy")
	var hit := at("side_kick", "active", t)
	check(absf(hit["leg_f_lower"]) <= 10.0, "the leg drives out straight")
	var tip := Poses.tip("foot_f", Poses.angles("side_kick", Moves.data("side_kick", t)["startup"], t))
	check(-tip.y >= 170.0, "to the face (%.0f px up)" % -tip.y)
	check(wa["torso"] <= -35.0, "the body leans away in one line from head to heel")
	check(not Poses._planted(hit, "f"), "the whole body on the one standing foot")
	check(absf(Poses.angles("side_kick", Poses.moment("side_kick", "follow", t), t)["leg_f_lower"]) >= 90.0, "then the leg folds back")
	check(Moves.length("side_kick", t) >= 36, "slower: about two-thirds of a second (%d frames)" % Moves.length("side_kick", t))
