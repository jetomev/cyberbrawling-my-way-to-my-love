extends "res://tests/test_case.gd"
## Motion from the hips out (D-21, Javier 2026-11-01: "still stiff as a pipe... no hip movements, not side
## movements, no back and shoulders moving with hits and kicks"): the hips move first and the fist or foot arrives
## last; the weight shifts while the planted feet stay put; the shoulders swing; the back bends into kicks; a raised
## leg keeps its aim when the pelvis tips.

const Poses := preload("res://scripts/present/poses.gd")
const Moves := preload("res://scripts/sim/moves.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")


func test_the_hips_lead_and_the_fist_or_foot_arrives_last() -> void:
	var t := Tuning.fresh()
	for m in ["punch", "cross", "hook", "power_punch", "elbow", "kick", "front_kick", "push_kick", "body_kick", "roundhouse", "spin_kick", "side_kick"]:
		var d := Moves.data(m, t)
		var wind := Poses.moment(m, "windup", t)
		var hit: int = d["startup"]
		# the hips run ahead of the clock, so measure them against their written wind-up and blow
		var hx_w: float = written(m, "windup")["hip_x"]
		var hx_h: float = written(m, "active")["hip_x"]
		var tip_w: Vector2 = Poses.tip(d["limb"], Poses.angles(m, wind, t))
		var tip_h: Vector2 = Poses.tip(d["limb"], Poses.angles(m, hit, t))
		# the tick each gets halfway: the hips must get there first
		var hips_half := -1
		var limb_half := -1
		for tt in range(0, hit + 1):
			var pose := Poses.angles(m, tt, t)
			if hips_half < 0 and (pose["hip_x"] - hx_w) / (hx_h - hx_w) >= 0.5:
				hips_half = tt
			if limb_half < 0 and tt >= wind and tip_w.distance_to(Poses.tip(d["limb"], pose)) >= 0.5 * tip_w.distance_to(tip_h):
				limb_half = tt
		check(hips_half >= 0 and limb_half >= 0 and hips_half < limb_half,
			"%s: the hips get halfway (tick %d) before the %s does (tick %d)" % [m, hips_half, d["limb"], limb_half])


func test_the_weight_shifts_and_the_feet_stay_put() -> void:
	var t := Tuning.fresh()
	var d := Moves.data("cross", t)
	var w := Poses.angles("cross", 0, t)
	var h := Poses.angles("cross", d["startup"], t)
	# (the posture sheet's cross: no pull-back load; the hips go forward onto a firm front leg, about 60% of the weight)
	check(h["hip_x"] >= 10.0, "the hips go forward onto the front foot on the cross (%.0f px)" % h["hip_x"])
	for pose in [w, h]:
		var still: Dictionary = pose.duplicate()
		still["hip_x"] = 0.0
		still["hip_turn"] = 0.0
		var moved := Poses.bake(pose, true)
		var fixed := Poses.bake(still, true)
		for side in ["f", "b"]:
			if Poses._planted(fixed, side):
				# the toes: a driving back leg lifts its heel on purpose, the ball of the foot stays put
				var a: Vector2 = Poses._end("toe_" + side, moved)[0]
				var b: Vector2 = Poses._end("toe_" + side, fixed)[0]
				check(a.distance_to(b) < 1.0, "the %s foot stays planted while the hips shift (moved %.1f px)" % [side, a.distance_to(b)])


func test_the_shoulders_swing() -> void:
	var t := Tuning.fresh()
	var b := Poses.bake(Poses.angles("cross", Moves.data("cross", t)["startup"], t), true)
	check(b["shoulder_b"] < -30.0, "the back shoulder comes forward on the cross (%.0f)" % b["shoulder_b"])
	# only the back arm reaches, the front arm stays in its guard: only the swing can move the front shoulder
	var only_back := Poses.bake(Poses.full({"arm_b_upper": -96.0, "cover_b": 0.0}), true)  # reaching, so not covering
	check(only_back["shoulder_f"] > 10.0, "as the back shoulder comes forward, the front one swings back (%.0f)" % only_back["shoulder_f"])


func test_the_back_bends_into_kicks() -> void:
	var t := Tuning.fresh()
	for m in ["front_kick", "body_kick", "spin_kick", "roundhouse", "side_kick"]:  # (the low kick stays upright)
		var b := Poses.bake(Poses.angles(m, Moves.data(m, t)["startup"], t), true)
		check(b["hip"] < -5.0, "%s: the pelvis tips back (%.0f)" % [m, b["hip"]])
		var chest: float = rad_to_deg(Poses._end("chest", b)[1])
		# (forward: the recorded front kick leans 10-14 degrees into it, CMU 135_04; back: at least 5)
		check(chest < -95.0 or chest > -78.0, "%s: the chest leans away from upright (%.0f)" % [m, chest])


func test_a_raised_leg_keeps_its_aim() -> void:
	var t := Tuning.fresh()
	var hit := Poses.angles("spin_kick", Moves.data("spin_kick", t)["startup"], t)
	var flat := hit.duplicate()
	flat["hip_turn"] = 0.0
	var a: Vector2 = Poses.tip("foot_f", hit)
	var b: Vector2 = Poses.tip("foot_f", flat)
	check(absf(a.y - b.y) < 6.0, "tipping the pelvis doesn't re-aim the kick (%.0f vs %.0f)" % [a.y, b.y])


## A move's pose as written for one of its moments (soft keys filled from the guard).
func written(move: String, moment: String) -> Dictionary:
	for k in Poses.SHOTS[move]:
		if k[0] == moment:
			return Poses.full(k[1])
	return Poses.full({})
