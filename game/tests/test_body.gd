extends "res://tests/test_case.gd"
## The fuller body (D-20, Javier 2026-11-01: "too stiff … no feet, no hands … too little articulation"): the parts
## are there, the feet stand on the street, a heel rolls up as the back leg drives, shoulders turn into punches, the
## head follows the eyes, hands open to grab, and every strike winds up, lands, follows through and eases back.

const Poses := preload("res://scripts/present/poses.gd")
const Moves := preload("res://scripts/sim/moves.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")

const AIR := ["jump", "air_kick", "hammer_fist"]


func test_the_parts_are_there() -> void:
	for part in ["belly", "chest", "neck", "head", "shoulder_f", "shoulder_b", "hand_f", "hand_b", "foot_f", "foot_b",
			"toe_f", "toe_b"]:
		check(Poses.BONES.has(part), "the body has a %s" % part)
	eq(Poses.BONES.size(), 21, "21 bones (it was 11)")


## Every grounded pose the game can show: each loop tick and each move every 2 ticks.
func ground_poses() -> Array:
	var t := Tuning.fresh()
	var out := []
	for s in Poses.LOOPS:
		for tt in Poses.LOOPS[s][0]:
			out.append([s, tt, Poses.angles(s, tt, t)])
	for s in Poses.SHOTS:
		if s in AIR:
			continue
		var length := 30
		if Moves.is_move(s):
			length = Moves.length(s, t)
		for tt in range(0, length + 1, 2):
			out.append([s, tt, Poses.angles(s, tt, t)])
	return out


func test_feet_stand_on_the_street() -> void:
	var floating := []
	var sunk := []
	for p in ground_poses():
		var b := Poses.bake(p[2], true)
		var lowest := -INF
		for side in ["f", "b"]:
			var toe: Vector2 = Poses._end("toe_" + side, b)[0]
			var ankle: Vector2 = Poses._end("leg_%s_lower" % side, b)[0]
			if -ankle.y <= Poses.FOOT_LENGTH + Poses.TOE_LENGTH:
				lowest = maxf(lowest, toe.y)
				if toe.y > 1.0:
					sunk.append("%s@%d %s %.1f" % [p[0], p[1], side, toe.y])
		if lowest != -INF and lowest < -1.0:
			floating.append("%s@%d %.1f" % [p[0], p[1], lowest])
	eq(sunk, [], "no foot ever goes into the street")
	eq(floating, [], "the body never hovers over its planted foot")


func test_the_back_heel_rolls_up_when_the_back_leg_drives() -> void:
	var t := Tuning.fresh()
	var hit := Poses.bake(Poses.angles("cross", Moves.data("cross", t)["startup"], t), true)
	var heel: Vector2 = Poses._end("leg_b_lower", hit)[0]
	var toe: Vector2 = Poses._end("toe_b", hit)[0]
	check(heel.y < toe.y - 6.0, "on the cross the back heel is up (heel %.0f, toes %.0f)" % [heel.y, toe.y])
	var guard := Poses.bake(Poses.angles("idle", 0, t), true)
	var g_heel: Vector2 = Poses._end("leg_f_lower", guard)[0]
	check(g_heel.y > -6.0, "in the guard the front heel is down (%.0f)" % g_heel.y)


func test_shoulders_turn_into_punches() -> void:
	var t := Tuning.fresh()
	var hit := Poses.angles("cross", Moves.data("cross", t)["startup"], t)
	var b := Poses.bake(hit, true)
	check(b["shoulder_b"] < -30.0, "the back shoulder rolls forward on the cross (%.0f)" % b["shoulder_b"])
	var stiff := hit.duplicate()
	stiff["shoulder_b"] = 0.0
	var rolled_x: float = Poses.tip("hand_b", hit).x
	var stiff_x: float = Poses.tip("hand_b", stiff).x
	check(rolled_x > stiff_x + 5.0, "the roll carries the fist further (%.0f vs %.0f)" % [rolled_x, stiff_x])
	var arm_dir := func(pose):
		var e: Array = Poses._end("arm_b_upper", Poses.bake(pose, true))
		return snappedf(rad_to_deg(e[1]), 0.1)
	eq(arm_dir.call(hit), arm_dir.call(stiff), "the arm keeps its aim; only its root moves")


func test_the_head_follows_the_eyes() -> void:
	# a plain lean with no head tilt written in: only the automatic follow can keep the head nearer upright
	var lean := Poses.full({"torso": 30.0, "head": 0.0, "neck": 0.0})
	var b := Poses.bake(lean, true)
	var chest: float = rad_to_deg(Poses._end("chest", b)[1])
	var head: float = rad_to_deg(Poses._end("head", b)[1])
	check(absf(head + 90.0) < absf(chest + 90.0) - 5.0, "leaning 30 degrees, the head stays nearer upright (head %.0f, chest %.0f)" % [head, chest])


func test_hands_make_fists_and_open_to_grab() -> void:
	var t := Tuning.fresh()
	var guard := Poses.bake(Poses.angles("idle", 0, t), true)
	eq([guard["open_f"], guard["open_b"]], [0.0, 0.0], "fists in the guard")
	var climb := Poses.bake(Poses.angles("climb", 0, t), true)
	eq([climb["open_f"], climb["open_b"]], [1.0, 1.0], "open hands to grab a ledge")


func test_feet_point_in_the_air() -> void:
	var t := Tuning.fresh()
	var b := Poses.bake(Poses.angles("jump", 0, t), false)
	eq(b["foot_f"], 30.0, "in the air the feet point")


func test_every_strike_winds_up_follows_through_and_eases_back() -> void:
	var t := Tuning.fresh()
	for m in Moves.TABLE:
		if Moves.is_air(m):
			continue
		var d := Moves.data(m, t)
		var limb: String = d["limb"]
		var wind := Poses.moment(m, "windup", t)
		var hit_t: int = d["startup"]
		var follow := Poses.moment(m, "follow", t)
		var end := Moves.length(m, t)
		check(wind < hit_t, "%s: the wind-up comes before the blow" % m)
		var p_wind: Vector2 = Poses.drawn_tip(limb, Poses.angles(m, wind, t))
		var p_hit: Vector2 = Poses.drawn_tip(limb, Poses.angles(m, hit_t, t))
		check(p_wind.distance_to(p_hit) > 20.0, "%s: the blow travels from the wind-up (%.0f px)" % [m, p_wind.distance_to(p_hit)])
		if m != "uppercut":  # the uppercut rises; every other blow drives forward
			check(p_wind.x < p_hit.x - 10.0, "%s: pulled back on the wind-up (%.0f), out on the blow (%.0f)" % [m, p_wind.x, p_hit.x])
		check(follow > hit_t + d["active"] - 1 and follow < end, "%s: a follow-through inside the recovery" % m)
		var hit := Poses.angles(m, hit_t, t)
		var through := Poses.angles(m, follow, t)
		var moved := 0.0
		for k in hit:
			moved += absf(through[k] - hit[k])
		check(moved > 2.0, "%s: the follow-through carries the blow further" % m)
		# easing: the last stretch back to the guard moves less per tick than the middle of it
		var g := Poses.angles(m, end, t)
		var a1 := Poses.angles(m, end - 1, t)
		var mid := Poses.angles(m, (follow + end) / 2, t)
		var mid1 := Poses.angles(m, (follow + end) / 2 + 1, t)
		var last_step := 0.0
		var mid_step := 0.0
		for k in g:
			last_step += absf(g[k] - a1[k])
			mid_step += absf(mid1[k] - mid[k])
		check(last_step <= mid_step, "%s: it eases into the guard, no snap at the end" % m)
