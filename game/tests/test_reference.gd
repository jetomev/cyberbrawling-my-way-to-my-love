extends "res://tests/test_case.gd"
## Movement measured from recorded human motion, reference only (Javier, 2026-11-02 19:09: "yes to the switch";
## "reference only (we measure and draw our own poses)"). The recordings are CMU's (mocap.cs.cmu.edu), kept outside
## this repository; scripts/mocap_ref.py measures them. What these tests hold are the measured facts our own poses
## follow: a jump crouches first, extends to leave the ground and swings its legs forward to land; a flying kick has
## the front kick's shape; an everyday walk has a real cadence and a small arm swing; the guard is never dead still.

const Poses := preload("res://scripts/present/poses.gd")
const Moves := preload("res://scripts/sim/moves.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")


func test_a_jump_crouches_first() -> void:
	# CMU 16_05: the hips drop about 14%, the knees bend to about 70, the spine leans about 45 forward, the arms swing
	# back, for about 200 ms before the feet leave the ground
	var t := Tuning.fresh()
	check(t["jump_squat_ticks"] >= 3, "a crouch before take-off (%d frames)" % t["jump_squat_ticks"])
	var guard := Poses.bake(Poses.angles("idle", 0, t), true)
	var crouch := Poses.bake(Poses.angles("jump_squat", t["jump_squat_ticks"], t), true)
	var drop: float = (Poses._end("hip", crouch)[0] as Vector2).y - (Poses._end("hip", guard)[0] as Vector2).y
	check(drop >= 12.0, "the hips drop (%.0f px)" % drop)
	check(crouch["belly"] + crouch["chest"] >= 25.0 or Poses.angles("jump_squat", t["jump_squat_ticks"], t)["torso"] >= 30.0, "the spine leans well forward")
	var arm: float = rad_to_deg(Poses._end("arm_f_upper", crouch)[1])
	check(arm > 95.0, "the arms swing back (the upper arm points %.0f, down is 90)" % arm)


func test_a_jump_extends_then_reaches_for_the_landing() -> void:
	# CMU 16_05: leaving the ground the legs are nearly straight and the body upright; through the flight the legs
	# swing from under him to forward, knees only half bent, reaching for the street
	var t := Tuning.fresh()
	var off := Poses.angles("jump", 0, t)
	var fall := Poses.angles("jump", Poses.moment("jump", "fall", t), t)
	check(off["leg_f_lower"] <= 30.0 and off["leg_b_lower"] <= 30.0, "leaving the ground the legs are nearly straight")
	check(off["torso"] <= 10.0, "the body upright in the air")
	check(off["leg_f_upper"] - fall["leg_f_upper"] >= 20.0, "the legs swing forward through the flight (%.0f)" % (off["leg_f_upper"] - fall["leg_f_upper"]))
	check(fall["leg_f_lower"] <= 30.0, "reaching for the street, the knees only a little bent")


func test_the_flying_kick_has_the_front_kicks_shape() -> void:
	# CMU 135_04: the knee comes up with the spine leaning forward over it; the leg snaps out as the body comes
	# upright; a moment held; then it folds back to the chamber
	var t := Tuning.fresh()
	var d := Moves.data("air_kick", t)
	check(d["startup"] >= 6, "time to show the chamber before the kick (%d frames)" % d["startup"])
	check(Poses.angles("air_kick", 0, t)["torso"] >= 15.0, "in the chamber the body leans over the knee")
	var hit := Poses.angles("air_kick", d["startup"], t)
	check(hit["torso"] <= 8.0, "at the kick the body is upright")
	check(Poses.angles("air_kick", 0, t)["leg_f_lower"] >= 100.0, "the chamber: the knee up, the foot folded under it")
	check(Poses.angles("air_kick", Poses.moment("air_kick", "recoil", t), t)["leg_f_lower"] >= 120.0, "after it, the leg folds back")


func test_an_everyday_walk_has_a_real_cadence() -> void:
	# CMU 16_15: about 1.1 s a cycle, the arms swinging about 7 degrees, the swinging knee bending to about 70 with the
	# heel up behind while the standing knee stays soft
	var t := Tuning.fresh()
	var seconds := Poses.STROLL_CYCLE / 60.0
	check(seconds >= 0.9 and seconds <= 1.3, "a cycle of %.2f s" % seconds)
	var arm_lo := INF
	var arm_hi := -INF
	var swing_knee := 0.0
	for tt in range(Poses.WALK_EASE_IN, Poses.WALK_EASE_IN + Poses.STROLL_CYCLE):
		var p := Poses.angles("stroll", tt, t)
		arm_lo = minf(arm_lo, p["arm_f_upper"])
		arm_hi = maxf(arm_hi, p["arm_f_upper"])
		var b := Poses.bake(p, true)
		for side in ["f", "b"]:
			if p["lift_" + side] > 0.0:
				swing_knee = maxf(swing_knee, absf(b["leg_%s_lower" % side]))
	check(arm_hi - arm_lo <= 24.0, "a small arm swing (%.0f degrees end to end)" % (arm_hi - arm_lo))
	check(swing_knee >= 45.0, "the swinging knee bends, the heel up behind (%.0f)" % swing_knee)


func test_the_guard_is_alive() -> void:
	var t := Tuning.fresh()
	var lo := INF
	var hi := -INF
	for tt in 30:
		var y: float = (Poses._end("hip", Poses.bake(Poses.angles("idle", tt, t), true))[0] as Vector2).y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	check(hi - lo >= 2.0, "within half a second the knees give and come back (%.1f px)" % (hi - lo))
