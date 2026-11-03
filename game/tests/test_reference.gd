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


func test_the_flying_kick_is_a_flying_side_kick() -> void:
	# Javier played build a7c202b (2026-11-02 21:21, through the assistant team): "the flying kick, has to look like a
	# flying kick, not like a karate kid movie kick, is weird". The classic flying side kick: at the hit the body is
	# side-on and leans back away from the target, the kicking leg is driven out straight at hip height or above,
	# the other leg tucked tight under him. Then ("Wushu Basics", Commons, CC BY-SA 3.0) the knees stay tucked and
	# the arms go out wide for balance until the legs reach for the street.
	var t := Tuning.fresh()
	var d := Moves.data("air_kick", t)
	var hit := Poses.angles("air_kick", d["startup"], t)
	var b := Poses.bake(hit, false)
	check(hit["turn"] >= 70.0, "side-on at the hit (turned %.0f)" % hit["turn"])
	check(hit["torso"] <= -25.0, "leaning back, away from the target (%.0f)" % hit["torso"])
	check(absf(b["leg_f_lower"]) <= 10.0, "the kicking leg straight (%.0f)" % absf(b["leg_f_lower"]))
	var foot: Vector2 = Poses._end("leg_f_lower", b)[0]
	var hip: Vector2 = Poses._end("hip", b)[0]
	check(foot.y <= hip.y + 10.0 and foot.x > hip.x + 90.0, "driven out at hip height or above (%.0f px out, %.0f px under the hips)" % [foot.x - hip.x, foot.y - hip.y])
	check(absf(b["leg_b_lower"]) >= 100.0, "the other leg tucked tight under him (knee %.0f)" % absf(b["leg_b_lower"]))
	check(not (Poses.angles("air_kick", 0, t)["leg_f_upper"] < -60.0 and absf(Poses.angles("air_kick", 0, t)["leg_f_lower"]) > 100.0 and Poses.angles("air_kick", 0, t)["torso"] > 10.0), "no crane: the knee isn't held up front with the body leaning over it")
	for tick in range(Poses.moment("air_kick", "recoil", t), Poses.moment("air_kick", "recoil", t) + 30):
		var f := Poses.bake(Poses.angles("air_kick", tick, t), false)
		var wide: float = absf((Poses._end("hand_f", f)[0] as Vector2).x - (Poses._end("hand_b", f)[0] as Vector2).x)
		check(wide >= 60.0, "air_kick@%d: the arms out wide for balance (%.0f px apart)" % [tick, wide])
		check(absf(f["leg_f_lower"]) >= 60.0 and absf(f["leg_b_lower"]) >= 60.0, "air_kick@%d: the knees stay tucked (%.0f, %.0f)" % [tick, absf(f["leg_f_lower"]), absf(f["leg_b_lower"])])


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



func test_the_walk_and_the_run_keep_a_real_pace() -> void:
	# Javier (2026-11-02 21:21): "Walk is too slow, and running looks weird." Measured on CMU 16 (leg = thigh + shin):
	# an easy walk 1.33 legs a second, a stride of 1.47 legs; a jog about 4 legs a second, a stride every ~0.6 s
	# (about 2.4 legs), elbows bent 100-120, each arm swinging about 35 degrees, the swinging knee folding to ~90.
	var t := Tuning.fresh()
	var leg: float = Poses.BONES["leg_f_upper"][3] + Poses.BONES["leg_f_lower"][3]
	var walk: float = t["stroll_speed"] * 60.0 / leg
	check(walk >= 1.4 and walk <= 1.9, "a brisk walk: %.2f legs a second (an easy one is 1.33)" % walk)
	var wstride: float = t["stroll_speed"] * Poses.STROLL_CYCLE / leg
	check(wstride >= 1.3 and wstride <= 1.7, "a real stride walking: %.2f legs" % wstride)
	var cyc: float = Poses.RUN_CYCLE / 60.0
	check(cyc >= 0.5 and cyc <= 0.7, "running, a stride every %.2f s (not quick little steps)" % cyc)
	var rstride: float = t["run_speed"] * Poses.RUN_CYCLE / leg
	check(rstride >= 2.0, "long strides running: %.2f legs" % rstride)
	var lo := INF
	var hi := -INF
	var sink := 0.0
	var stand_hip: float = (Poses._end("hip", Poses.bake(Poses.angles("stand", 0, t), true))[0] as Vector2).y
	for tt in range(Poses.WALK_EASE_IN, Poses.WALK_EASE_IN + Poses.RUN_CYCLE):
		var p := Poses.angles("run", tt, t)
		var b := Poses.bake(p, true)
		lo = minf(lo, p["arm_f_upper"])
		hi = maxf(hi, p["arm_f_upper"])
		check(absf(b["arm_f_lower"]) >= 80.0, "run@%d: the elbow bent (%.0f)" % [tt, absf(b["arm_f_lower"])])
		sink = maxf(sink, (Poses._end("hip", b)[0] as Vector2).y - stand_hip)
	check(hi - lo >= 50.0, "the arms drive: %.0f degrees end to end" % (hi - lo))
	check(sink <= 16.0, "running tall, not a crouched shuffle (the hips sink %.0f px at most)" % sink)


func test_the_guard_is_alive() -> void:
	var t := Tuning.fresh()
	var lo := INF
	var hi := -INF
	for tt in 30:
		var y: float = (Poses._end("hip", Poses.bake(Poses.angles("idle", tt, t), true))[0] as Vector2).y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	check(hi - lo >= 2.0, "within half a second the knees give and come back (%.1f px)" % (hi - lo))


static func _thigh_up(b: Dictionary, side: String) -> float:
	# degrees above level, the thigh pointing forward (our rig: 0 = forward, -90 = straight up)
	return -rad_to_deg(Poses._end("leg_%s_upper" % side, b)[1])


func test_the_kicks_as_recorded() -> void:
	# CMU 135 (reference only), measured along the way each kick goes (scripts/mocap_ref.py strikes <take> foot), from
	# the kicking leg's hip joint, in leg lengths (thigh + shin). Where the posture sheet says otherwise it wins (the
	# front kick's lean back a touch at the hit; the round kick's full heel turn, which the testers asked for).
	var t := Tuning.fresh()
	var leg: float = Poses.BONES["leg_f_upper"][3] + Poses.BONES["leg_f_lower"][3]
	# the round kick (135_07, four kicks): about 180 ms out; the thigh chambered 23-30 degrees up; at the hit the leg
	# straight (under 13), the foot 0.44 legs above the hip, the body upright (within 4), the standing leg straight
	var rd := Moves.data("roundhouse", t)
	var ms: float = rd["startup"] * 1000.0 / 60.0
	check(ms >= 150.0 and ms <= 220.0, "round kick: %.0f ms out (recorded ~180)" % ms)
	var up := -INF
	for tick in range(0, rd["startup"]):
		up = maxf(up, _thigh_up(Poses.bake(Poses.angles("roundhouse", tick, t), true), "b"))
	check(up >= 20.0, "round kick: the knee chambered high first (thigh %.0f degrees up)" % up)
	var r := Poses.bake(Poses.angles("roundhouse", rd["startup"], t), true)
	check(absf(r["leg_b_lower"]) <= 15.0, "round kick: the leg straight at the hit (knee %.0f)" % absf(r["leg_b_lower"]))
	var h: float = ((Poses._end("hip", r)[0] as Vector2).y - (Poses._end("leg_b_lower", r)[0] as Vector2).y) / leg
	check(h >= 0.35, "round kick: the foot high, %.2f legs above the hip (recorded 0.44)" % h)
	check(absf(Poses.angles("roundhouse", rd["startup"], t)["torso"]) <= 10.0, "round kick: upright at the hit (%.0f)" % Poses.angles("roundhouse", rd["startup"], t)["torso"])
	check(absf(r["leg_f_lower"]) <= 15.0, "round kick: the standing leg straight (knee %.0f)" % absf(r["leg_f_lower"]))
	# the front snap kick (135_04, three kicks): about 110-130 ms out; at the hit the thigh 36-48 degrees up and the
	# knee still bent 40-68 (it snaps), the foot 0.3-0.4 legs above the hip; the body kick leans forward 10-14
	for pair in [["body_kick", "b"], ["front_kick", "f"]]:
		var d := Moves.data(pair[0], t)
		var b := Poses.bake(Poses.angles(pair[0], d["startup"], t), true)
		var thigh := _thigh_up(b, pair[1])
		check(thigh >= 30.0, "%s: the thigh well up at the hit (%.0f degrees)" % [pair[0], thigh])
		var knee: float = absf(b["leg_%s_lower" % pair[1]])
		check(knee >= 25.0 and knee <= 70.0, "%s: the knee still bent as it snaps (%.0f)" % [pair[0], knee])
		var fh: float = ((Poses._end("hip", b)[0] as Vector2).y - (Poses._end("leg_%s_lower" % pair[1], b)[0] as Vector2).y) / leg
		check(fh >= 0.25 and fh <= 0.55, "%s: the foot %.2f legs above the hip (recorded 0.3-0.4)" % [pair[0], fh])
	check(Poses.angles("body_kick", Moves.data("body_kick", t)["startup"], t)["torso"] >= 0.0, "the body kick doesn't lean back")
	# the side kick (135_11, seven kicks): 150-190 ms out, the leg straight, the standing leg straight, leaning away
	var sd := Moves.data("side_kick", t)
	ms = sd["startup"] * 1000.0 / 60.0
	check(ms >= 150.0 and ms <= 200.0, "side kick: %.0f ms out (recorded 150-190)" % ms)
	var sk := Poses.bake(Poses.angles("side_kick", sd["startup"], t), true)
	# (recorded within 8; the leg solver never locks a knee, so a straight standing leg draws at 10-15)
	check(absf(sk["leg_b_lower"]) <= 15.0, "side kick: the standing leg straight (knee %.0f)" % absf(sk["leg_b_lower"]))
