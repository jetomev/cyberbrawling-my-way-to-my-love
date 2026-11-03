extends "res://tests/test_case.gd"
## The landing (the assistant team's fourth review, 2026-11-02): the legs reach for the street in the last of the
## fall, the touchdown frame stays sharp, then the knees and hips take his weight over a few frames and he rises
## again, the feet staying where they landed; the arms come in to the guard instead of snapping.

const Poses := preload("res://scripts/present/poses.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")
const Fighter := preload("res://scripts/sim/fighter.gd")
const StreetWorld := preload("res://scripts/sim/street_world.gd")
const HeroView := preload("res://scripts/present/hero_view.gd")


func test_the_sink_and_the_rise() -> void:
	eq(Poses.sink_at(0), 0.0, "the touchdown frame itself stays sharp")
	var peak := 0.0
	var peak_at := 0
	for s in range(0, Poses.LAND_SETTLE + 1):
		if Poses.sink_at(s) > peak:
			peak = Poses.sink_at(s)
			peak_at = s
	check(peak >= 14.0, "the knees and hips take his weight (%.0f px deep)" % peak)
	check(peak_at >= 2 and peak_at <= 6, "over a few frames, not one (deepest %d frames in)" % peak_at)
	for s in range(peak_at, Poses.LAND_SETTLE):
		check(Poses.sink_at(s + 1) <= Poses.sink_at(s), "then he rises, never dipping again (frame %d)" % s)
	eq(Poses.sink_at(Poses.LAND_SETTLE), 0.0, "and is back up")


func test_the_legs_reach_for_the_street() -> void:
	var t := Tuning.fresh()
	var air := Poses.angles("air_kick", Poses.moment("air_kick", "recoil", t), t)  # after a flying kick, the leg folded
	var tucked: Vector2 = Poses._end("leg_f_lower", Poses.bake(air, false))[0]
	var near: Vector2 = Poses._end("leg_f_lower", Poses.bake(Poses.landing(air, -1, 6.0, true), false))[0]
	check(near.y > tucked.y + 20.0, "falling the last few px, the feet reach down (%.0f px lower)" % (near.y - tucked.y))
	eq(Poses.landing(air, -1, 200.0, true), air, "high in the air, nothing changes")
	eq(Poses.landing(air, -1, 6.0, false), air, "going up, the legs stay tucked")


func test_a_real_landing_sinks_and_rises_without_snapping() -> void:
	var tune := Tuning.fresh()
	var f = Fighter.new(tune, 400.0, 80.0, StreetWorld.grey_street())
	var v = HeroView.new()
	var hips := []
	var hands := []
	var feet := []
	var touch := -1
	var was_up := false
	for i in 120:
		f.step({"jump": i == 2})
		v.sync(f, 0.0)
		var p: Dictionary = v.points()
		hips.append((p["hip"] as Vector2).y - v.body.position.y)
		hands.append(p["hand_b"])
		feet.append(p["foot_f"])
		was_up = was_up or not f.on_ground()
		if touch < 0 and was_up and f.on_ground():
			touch = i
	check(touch > 0, "he jumps and lands (touchdown at tick %d)" % touch)
	if touch < 0:
		v.free()
		return
	var standing: float = hips[touch]
	var deepest := 0.0
	for k in range(touch, mini(touch + 8, hips.size())):
		deepest = maxf(deepest, hips[k] - standing)
	check(deepest >= 12.0, "after touchdown the hips sink (%.0f px)" % deepest)
	check(absf(hips[mini(touch + Poses.LAND_SETTLE + 4, hips.size() - 1)] - hips[1]) < 8.0, "and rise back to his standing height before the jump")
	for k in range(touch, mini(touch + 6, hands.size() - 1)):
		var step: float = (hands[k + 1] as Vector2).distance_to(hands[k])
		check(step < 30.0, "frame %d: the rear hand comes in, no snap (%.0f px)" % [k, step])
	for k in range(touch + 1, mini(touch + Poses.LAND_SETTLE, feet.size())):
		check(absf((feet[k] as Vector2).x - (feet[touch + 1] as Vector2).x) < 3.0, "frame %d: the front foot stays where it landed" % k)
	v.free()
