extends "res://tests/test_case.gd"
## Form, from the assistant team's reviews (2026-11-02). First round (build e7a5106): the free hand guards the face
## while the other one strikes; the hook swings wide; the spinning kicks turn and pivot. Second round (6809c7d): the
## guard keeps both hands up; the jab and the cross read apart; the hook's swing lasts long enough to see; the
## spinning kicks chamber and sweep with a bent knee, turn the hips and shoulders over and pivot the standing foot
## round; after a flying kick the knee tucks back in for the landing.

const Poses := preload("res://scripts/present/poses.gd")
const Moves := preload("res://scripts/sim/moves.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")
const HeroView := preload("res://scripts/present/hero_view.gd")

const FREE := {"punch": "b", "cross": "f", "hook": "b", "elbow": "b", "uppercut": "f"}


static func middle(bone: String, baked: Dictionary) -> Vector2:
	var e: Array = Poses._end(bone, baked)
	return e[0] - Vector2(Poses.BONES[bone][3] * 0.5, 0).rotated(e[1])


func test_the_free_hand_guards_the_face() -> void:
	var t := Tuning.fresh()
	for m in FREE:
		var side: String = FREE[m]
		var b := Poses.bake(Poses.angles(m, Moves.data(m, t)["startup"], t), true)
		var head := middle("head", b)
		var fist := middle("hand_" + side, b)
		check(fist.distance_to(head) < 36.0, "%s: the free fist is at the face (%.0f px from the middle of the head)" % [m, fist.distance_to(head)])
		check(fist.x > head.x - 4.0, "%s: in front of the face, not behind it (%.0f vs %.0f)" % [m, fist.x, head.x])
		var elbow: Vector2 = Poses._end("arm_%s_upper" % side, b)[0]
		check(elbow.y > fist.y + 20.0, "%s: the elbow stays down under the fist (%.0f vs %.0f)" % [m, elbow.y, fist.y])


## How far the striking hand or foot bows away from a straight line, on its way from the guard to the blow.
static func arc(m: String, t: Dictionary) -> float:
	var d := Moves.data(m, t)
	var a := Poses.tip(d["limb"], Poses.angles(m, 0, t))
	var b := Poses.tip(d["limb"], Poses.angles(m, d["startup"], t))
	var most := 0.0
	for tt in range(0, d["startup"] + 1):
		var p := Poses.tip(d["limb"], Poses.angles(m, tt, t))
		most = maxf(most, absf((b - a).cross(p - a)) / maxf((b - a).length(), 1.0))
	return most


func test_the_hook_swings_sideways() -> void:
	# third review: the hook read as lifting the forearm. Seen from the side, a swing is the fist travelling level at
	# head height with the elbow up, the forearm across the body (drawn shorter, pointing at the camera)
	# (the testers' joint review: a compact load, then a level elbow-and-fist arc; the earlier "travels far forward"
	# measure fought the compact load)
	var t := Tuning.fresh()
	var d := Moves.data("hook", t)
	var w := Poses.moment("hook", "windup", t)
	for tt in range(w, d["startup"] + 1):
		var bb := Poses.bake(Poses.angles("hook", tt, t), true)
		var el: Vector2 = Poses._end("arm_f_upper", bb)[0]
		var fist: Vector2 = Poses._end("hand_f", bb)[0]
		var sh: Vector2 = Poses._end("shoulder_f", bb)[0]
		check(absf(el.y - sh.y) <= 15.0, "hook@%d: the elbow stays up at shoulder height (%.0f px off)" % [tt, el.y - sh.y])
		check(absf(fist.y - el.y) <= 26.0, "hook@%d: the fist travels level with the elbow (%.0f px off)" % [tt, fist.y - el.y])
	var load := Poses.bake(Poses.angles("hook", w, t), true)
	check((Poses._end("hand_f", load)[0] as Vector2).x >= (Poses._end("head", load)[0] as Vector2).x, "a compact load: the fist isn't drawn back behind the head")
	var b := Poses.bake(Poses.angles("hook", d["startup"], t), true)
	var elbow: Vector2 = Poses._end("arm_f_upper", b)[0]
	var shoulder: Vector2 = Poses._end("shoulder_f", b)[0]
	check(absf(elbow.y - shoulder.y) < 12.0, "at contact the elbow is up, level with the shoulder (%.0f px off)" % absf(elbow.y - shoulder.y))
	check(Poses.angles("hook", Poses.moment("hook", "sweep", t), t)["fore_f"] > 0.8, "coming round, the forearm points across the body (drawn short)")
	var cross := Poses.angles("cross", d["startup"], t)
	var hook := Poses.angles("hook", d["startup"], t)
	check(hook["hip_turn"] > cross["hip_turn"] + 5.0, "the hook turns the hips more than the cross (%.0f vs %.0f)" % [hook["hip_turn"], cross["hip_turn"]])


func test_the_spin_kick_turns_all_the_way_round() -> void:
	var t := Tuning.fresh()
	var d := Moves.data("spin_kick", t)
	var back := false
	for tt in range(0, d["startup"] + 1):
		var s: float = Poses.bake(Poses.angles("spin_kick", tt, t), true)["spin"]
		back = back or absf(fmod(s, 360.0) - 180.0) < 30.0
	check(back, "on the way in, the spin kick shows its back")
	var hit := Poses.bake(Poses.angles("spin_kick", d["startup"], t), true)
	eq(fmod(hit["spin"], 360.0), 0.0, "and lands facing the target again")
	var after := Poses.bake(Poses.angles("spin_kick", Moves.length("spin_kick", t), t), true)
	eq(fmod(after["spin"], 360.0), 0.0, "the recovery doesn't spin him back the other way")
	for tt in range(d["startup"], Moves.length("spin_kick", t) + 1):
		check(Poses.angles("spin_kick", tt, t)["spin"] >= 360.0 - 0.01, "no un-spin at tick %d" % tt)


func test_the_spinning_kicks_pivot_and_turn_more() -> void:
	var t := Tuning.fresh()
	var stand := {"spin_kick": "b", "roundhouse": "f"}
	for m in stand:
		var b := Poses.bake(Poses.angles(m, Moves.data(m, t)["startup"], t), true)
		var heel: Vector2 = Poses._end("leg_%s_lower" % stand[m], b)[0]
		var toe: Vector2 = Poses._end("toe_" + stand[m], b)[0]
		# on the ball of the foot to pivot, but low enough that the foot turning round shows (fourth review)
		check(heel.y < toe.y - 8.0 and heel.y > toe.y - 18.0, "%s: the standing heel is up, pivoting on the ball of the foot (heel %.0f, toes %.0f)" % [m, heel.y, toe.y])
		check(absf(toe.y) < 1.0, "%s: and the toes are on the street (%.1f)" % [m, toe.y])
		for plain in ["kick", "body_kick"]:
			var p := Poses.angles(plain, Moves.data(plain, t)["startup"], t)
			var h := Poses.angles(m, Moves.data(m, t)["startup"], t)
			check(absf(h["hip_turn"]) > absf(p["hip_turn"]) + 6.0, "%s turns the hips more than the %s (%.0f vs %.0f)" % [m, plain, h["hip_turn"], p["hip_turn"]])
	var r := Poses.bake(Poses.angles("roundhouse", Moves.data("roundhouse", t)["startup"], t), true)
	check(r["turn"] > 100.0, "the roundhouse turns the hips and shoulders over, his back showing (%.0f degrees)" % r["turn"])
	check(r["pivot_f"] > 120.0, "and swings the standing foot round, heel to the target (%.0f degrees)" % r["pivot_f"])
	for plain in ["kick", "body_kick"]:
		var p := Poses.bake(Poses.angles(plain, Moves.data(plain, t)["startup"], t), true)
		eq([p["spin"], p["turn"]], [0.0, 0.0], "the %s doesn't turn over" % plain)


func test_the_drawing_turns_with_the_spin() -> void:
	# the third review: no squashing him to a sliver; the limbs keep their thickness, the chest narrows, he flips round
	var v = HeroView.new()
	for spin in range(0, 361, 10):
		v.apply(Poses.full({"spin": float(spin)}))
		check(absf(v.body.scale.x) == 1.0, "at %d degrees he keeps his full width (%.2f)" % [spin, v.body.scale.x])
		check(v.bones["chest"].get_node("Part").scale.y >= 0.55, "at %d degrees the chest keeps at least half its width" % spin)
	v.apply(Poses.full({"spin": 90.0}))
	check(v.bones["chest"].get_node("Part").scale.y < 0.6, "edge-on, the chest is at its narrowest")
	v.apply(Poses.full({"spin": 180.0}))
	check(v.body.scale.x < 0.0, "at 180 he faces the other way")
	eq(v.bones["arm_b_upper"].get_node("Part").z_index, 0, "and the far arm comes in front: his back shows")
	v.apply(Poses.full({"spin": 360.0}))
	check(v.body.scale.x > 0.0, "a whole turn faces the front again")
	eq(v.bones["arm_b_upper"].get_node("Part").z_index, -1, "with the far arm behind again")
	v.free()


func test_the_guard_keeps_both_hands_up() -> void:
	var t := Tuning.fresh()
	var poses := [["idle", 0], ["idle", 30], ["walk", 0], ["walk", 16]]
	for p in poses:
		var b := Poses.bake(Poses.angles(p[0], p[1], t), true)
		var head := middle("head", b)
		var rear := middle("hand_b", b)
		var front := middle("hand_f", b)
		check(rear.distance_to(head) < 36.0 and rear.x - head.x > 22.0, "%s@%d: the rear fist at the cheek (%.0f px off)" % [p[0], p[1], rear.distance_to(head)])
		check(front.y < head.y + 50.0 and front.x > head.x + 15.0, "%s@%d: the front fist up and out in front (%.0f, %.0f from the head)" % [p[0], p[1], front.x - head.x, front.y - head.y])
	for tt in range(0, Moves.length("punch", t) + 1):
		# all through a jab, coming back too, the rear fist stays at the cheek
		var b := Poses.bake(Poses.angles("punch", tt, t), true)
		var gap: Vector2 = middle("hand_b", b) - middle("head", b)
		check(gap.length() < 36.0 and gap.x > 22.0, "punch@%d: the rear fist stays at the cheek, in front of the face where it shows (%.0f, %.0f)" % [tt, gap.x, gap.y])
	# the arms that work leave the guard: the cross's rear fist goes out, the climb's hands grab
	var cross := Poses.bake(Poses.angles("cross", Moves.data("cross", t)["startup"], t), true)
	var guard := Poses.bake(Poses.angles("idle", 0, t), true)
	check(middle("hand_b", cross).x > middle("hand_b", guard).x + 60.0, "the cross's rear fist leaves the cheek (%.0f px out)" % (middle("hand_b", cross).x - middle("hand_b", guard).x))


func test_the_jab_and_the_cross_read_apart() -> void:
	var t := Tuning.fresh()
	var jab := Poses.angles("punch", Moves.data("punch", t)["startup"], t)
	var cross := Poses.angles("cross", Moves.data("cross", t)["startup"], t)
	var jab_w := written("punch", "windup")
	var cross_w := written("cross", "windup")
	check(cross["hip_x"] - cross_w["hip_x"] > 2.5 * (jab["hip_x"] - jab_w["hip_x"]), "the cross drives the hips much further (%.0f vs %.0f px)" % [cross["hip_x"] - cross_w["hip_x"], jab["hip_x"] - jab_w["hip_x"]])
	check(cross["torso"] > jab["torso"] + 15.0, "the cross leans in, the jab stays upright (%.0f vs %.0f)" % [cross["torso"], jab["torso"]])
	check(cross["turn"] >= 40.0 and jab["turn"] == 0.0, "the cross turns the shoulders over, the jab doesn't (%.0f vs %.0f)" % [cross["turn"], jab["turn"]])
	check(Moves.data("cross", t)["reach"] > Moves.data("punch", t)["reach"] + 20.0, "the cross reaches further than the jab")


func test_the_swings_last_long_enough_to_see() -> void:
	var t := Tuning.fresh()
	for m in ["hook", "roundhouse", "spin_kick"]:
		var swing: int = Moves.data(m, t)["startup"] - Poses.moment(m, "windup", t)
		check(swing >= 4, "%s: %d ticks from the wind-up to the blow (a snap is 2)" % [m, swing])
		var sweep := Poses.moment(m, "sweep", t)
		check(sweep > Poses.moment(m, "windup", t) and sweep < Moves.data(m, t)["startup"], "%s: the sweep comes between them" % m)


func test_the_spinning_kicks_sweep_with_a_bent_knee() -> void:
	var t := Tuning.fresh()
	for m in ["roundhouse", "spin_kick"]:
		var d := Moves.data(m, t)
		var leg: String = "leg_%s_lower" % d["limb"].substr(5)
		var thigh: String = "leg_%s_upper" % d["limb"].substr(5)
		var mid := Poses.angles(m, Poses.moment(m, "sweep", t), t)
		var hit := Poses.angles(m, d["startup"], t)
		# the knee comes up first, the shin folded; then the shin sweeps round to the target
		check(mid[leg] > 60.0, "%s: halfway round, the knee is bent (%.0f)" % [m, mid[leg]])
		check(absf(mid[thigh] - hit[thigh]) < 20.0, "%s: and the thigh is already up near its aim (%.0f vs %.0f)" % [m, mid[thigh], hit[thigh]])


func test_the_flying_kick_tucks_the_knee_to_land() -> void:
	# (since the recorded front kick: chamber, out, a moment held, folded back to the chamber, then the legs under him)
	var t := Tuning.fresh()
	var kicking := Poses.angles("air_kick", Moves.data("air_kick", t)["startup"], t)
	var folded := Poses.angles("air_kick", Poses.moment("air_kick", "recoil", t), t)
	var after := Poses.angles("air_kick", Poses.moment("air_kick", "tuck", t), t)
	check(kicking["leg_f_lower"] < 10.0, "the flying kick is straight when it lands (%.0f)" % kicking["leg_f_lower"])
	check(folded["leg_f_lower"] > 100.0, "then the leg folds back to its chamber (%.0f)" % folded["leg_f_lower"])
	var b := Poses.bake(after, false)
	var foot: Vector2 = Poses._end("leg_f_lower", b)[0]
	check(absf(foot.x) < 70.0, "the foot comes back under the body for the landing (%.0f px out)" % foot.x)


func test_the_drawing_turns_the_shoulders_and_pivots_the_foot() -> void:
	var v = HeroView.new()
	v.apply(Poses.full({}))
	var arm: Node2D = v.bones["arm_b_upper"].get_node("Part")
	var leg: Node2D = v.bones["leg_b_upper"].get_node("Part")
	eq([arm.z_index, leg.z_index], [-1, -1], "in the guard the far arm and leg are behind the body")
	v.apply(Poses.full({"turn": 130.0}))
	eq([arm.z_index, leg.z_index], [0, 0], "turned over, they come in front (his back shows)")
	eq(v.bones["arm_f_upper"].get_node("Part").z_index, -1, "and the near arm goes behind")
	check(v.bones["chest"].get_node("Part").scale.y < 0.9, "the chest narrows as it turns")
	v.apply(Poses.full({"pivot_f": 160.0}))
	check(v.bones["foot_f"].get_node("Part").scale.x < -0.5, "a foot swung round on its ball points back")
	v.free()


## A move's pose as written for one of its moments (the hips run ahead of the clock, so compare these).
static func written(move: String, moment: String) -> Dictionary:
	for k in Poses.SHOTS[move]:
		if k[0] == moment:
			return Poses.full(k[1])
	return Poses.full({})


func test_a_forearm_at_the_camera_draws_short_and_hits_where_drawn() -> void:
	var v = HeroView.new()
	var pose := Poses.full({"cover_f": 0.0, "arm_f_upper": -90.0, "arm_f_lower": -40.0, "fore_f": 1.0, "upper_f": 0.5})
	v.apply(pose)
	eq(snappedf(v.bones["arm_f_lower"].get_node("Part").scale.x, 0.01), Poses.FORE_SHORT, "the forearm draws at its short length")
	eq(v.bones["hand_f"].get_node("Part").scale, Vector2.ONE, "the fist keeps its own size")
	eq(v.bones["arm_f_lower"].scale, Vector2.ONE, "nothing below it is skewed (no bone is scaled)")
	var drawn: Vector2 = v.points()["hand_f"]
	var logic: Vector2 = Poses._end("arm_f_lower", Poses.bake(pose, true))[0] + Vector2(0, -125) - Poses.BONES["hip"][1]
	check(drawn.distance_to(logic) < 1.0, "the drawn wrist is where the hit check thinks it is (%.1f px apart)" % drawn.distance_to(logic))
	v.free()


func test_the_roundhouse_and_the_spin_kick_land_differently() -> void:
	# third review: at contact the roundhouse looked like the spin kick
	var t := Tuning.fresh()
	var r := Poses.angles("roundhouse", Moves.data("roundhouse", t)["startup"], t)
	var s := Poses.angles("spin_kick", Moves.data("spin_kick", t)["startup"], t)
	check(r["leg_b_lower"] > 30.0, "the roundhouse lands with the knee still bent, sweeping through (%.0f)" % r["leg_b_lower"])
	check(s["leg_f_lower"] < 10.0, "the spin kick lands with the leg straight (%.0f)" % s["leg_f_lower"])
	check(r["turn"] >= 150.0, "the roundhouse's waist and shoulders are turned over, his back to us (%.0f)" % r["turn"])
	check(fmod(s["spin"], 360.0) == 0.0 and s["turn"] == 0.0, "the spin kick lands facing front")
	check(r["torso"] > s["torso"] + 12.0, "the roundhouse turns upright, the spin kick leans far back (%.0f vs %.0f)" % [r["torso"], s["torso"]])


func test_the_hips_lead_the_turn() -> void:
	# fourth review: on the spin and the roundhouse they couldn't see the hips leading
	var t := Tuning.fresh()
	var spin_lead := false
	for tt in range(0, Moves.data("spin_kick", t)["startup"] + 1):
		var p := Poses.angles("spin_kick", tt, t)
		spin_lead = spin_lead or (p["spin"] > 90.0 and p["spin_upper"] < 90.0)  # (not past 270: cos would pass that)
	check(spin_lead, "the spin kick's hips come round while the shoulders still face the front")
	var turn_lead := false
	for tt in range(0, Moves.data("roundhouse", t)["startup"] + 1):
		var p := Poses.angles("roundhouse", tt, t)
		turn_lead = turn_lead or (p["turn"] >= 90.0 and p["turn_upper"] < 90.0)
	check(turn_lead, "the roundhouse's hips turn over before the shoulders do")
	var v = HeroView.new()
	v.apply(Poses.full({"spin": 120.0, "spin_upper": 60.0}))
	check(v.body.scale.x < 0.0 and v.bones["belly"].scale.y < 0.0, "drawn: hips round, the upper body mirrored back to where the shoulders face")
	eq([v.bones["leg_b_upper"].get_node("Part").z_index, v.bones["arm_b_upper"].get_node("Part").z_index], [0, -1], "the far leg has come in front with the hips; the far arm hasn't yet")
	v.free()


func test_the_standing_foot_pivots_where_it_shows() -> void:
	var t := Tuning.fresh()
	var v = HeroView.new()
	var narrowest := 1.0
	for tt in range(0, Moves.data("spin_kick", t)["startup"] + 1):
		v.apply(Poses.angles("spin_kick", tt, t))
		narrowest = minf(narrowest, absf(v.bones["foot_b"].get_node("Part").scale.x))
	check(narrowest < 0.5, "the spin kick's standing foot turns round gradually, edge-on on the way (%.2f wide)" % narrowest)
	var hit := Poses.angles("roundhouse", Moves.data("roundhouse", t)["startup"], t)
	v.apply(hit)
	check(v.bones["foot_f"].get_node("Part").scale.x < -0.5 and hit["rise_f"] <= 0.35, "the roundhouse's standing foot points back, flat enough to see it")
	v.free()


func test_on_the_spin_the_head_looks_first() -> void:
	# the testers' joint review: show the head looking first, and the hips before the shoulders
	var t := Tuning.fresh()
	var head_first := false
	for tt in range(0, Moves.data("spin_kick", t)["startup"] + 1):
		var p := Poses.angles("spin_kick", tt, t)
		head_first = head_first or (p["spin_head"] > 90.0 and p["spin"] < 90.0)  # (not past 270 either: cos would pass that)
	check(head_first, "the head has looked round over the shoulder while the hips still face the front")
	var v = HeroView.new()
	v.apply(Poses.full({"spin": 60.0, "spin_upper": 30.0, "spin_head": 130.0}))
	check(v.bones["head"].scale.y < 0.0 and v.body.scale.x > 0.0, "drawn: the face has turned to look back while the body hasn't yet")
	v.free()
