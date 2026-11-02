extends "res://tests/test_case.gd"
## Form, from the assistant team's first review (2026-11-02, build e7a5106): the free hand guards the face while the
## other one strikes; the hook swings wide; the spinning kicks turn the body and pivot on the standing foot, so the
## four kicks stop looking alike.

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
		check(fist.distance_to(head) < 28.0, "%s: the free fist is at the face (%.0f px from the middle of the head)" % [m, fist.distance_to(head)])
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


func test_the_hook_swings_wide() -> void:
	var t := Tuning.fresh()
	var hook := arc("hook", t)
	for m in ["punch", "cross"]:
		check(hook > 2.0 * arc(m, t), "the hook's arc (%.0f px) is more than twice the %s's (%.0f px)" % [hook, m, arc(m, t)])
	var hit := Poses.angles("hook", Moves.data("hook", t)["startup"], t)
	var cross := Poses.angles("cross", Moves.data("cross", t)["startup"], t)
	check(hit["hip_turn"] > cross["hip_turn"] + 5.0, "the hook turns the hips more than the cross (%.0f vs %.0f)" % [hit["hip_turn"], cross["hip_turn"]])


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
		check(heel.y < toe.y - 15.0, "%s: the standing heel is up, pivoting on the toes (heel %.0f, toes %.0f)" % [m, heel.y, toe.y])
		check(absf(toe.y) < 1.0, "%s: and the toes are on the street (%.1f)" % [m, toe.y])
		for plain in ["kick", "body_kick"]:
			var p := Poses.angles(plain, Moves.data(plain, t)["startup"], t)
			var h := Poses.angles(m, Moves.data(m, t)["startup"], t)
			check(absf(h["hip_turn"]) > absf(p["hip_turn"]) + 6.0, "%s turns the hips more than the %s (%.0f vs %.0f)" % [m, plain, h["hip_turn"], p["hip_turn"]])
	var r := Poses.bake(Poses.angles("roundhouse", Moves.data("roundhouse", t)["startup"], t), true)
	check(r["spin"] > 30.0 and r["spin"] < 90.0, "the roundhouse turns the body into the kick (%.0f degrees)" % r["spin"])
	for plain in ["kick", "body_kick"]:
		eq(Poses.bake(Poses.angles(plain, Moves.data(plain, t)["startup"], t), true)["spin"], 0.0, "the %s doesn't turn" % plain)


func test_the_drawing_turns_with_the_spin() -> void:
	var v = HeroView.new()
	v.apply(Poses.full({"spin": 90.0}))
	check(absf(v.body.scale.x) < 0.1, "at 90 degrees the body is edge-on (%.2f wide)" % v.body.scale.x)
	v.apply(Poses.full({"spin": 180.0}))
	check(v.body.scale.x < -0.99, "at 180 he shows his back (%.2f)" % v.body.scale.x)
	v.apply(Poses.full({"spin": 360.0}))
	check(v.body.scale.x > 0.99, "a whole turn faces the front again (%.2f)" % v.body.scale.x)
	v.free()
