extends SceneTree
## Measurements for the build notes, taken on the drawing (the hero's drawn points), so a form question the testers
## keep raising gets a number: fixed, or proven (the testers, 00:57 on 66ce4c6, on the power punch's wide load: "measure
## it yourself against the posture sheet ... and put that number in the build notes"). Javier & Claude.
## Prints plain lines starting "- " (and their continuations), ready for build.md, then "len:<move>:<frames>" lines.

const Poses := preload("res://scripts/present/poses.gd")
const Moves := preload("res://scripts/sim/moves.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")
const HeroView := preload("res://scripts/present/hero_view.gd")


func _initialize() -> void:
	var t := Tuning.fresh()
	var v = HeroView.new()
	# the power punch's load: the feet apart against his shoulder width, where the hips sit between the feet
	v.apply(Poses.angles("idle", 0, t))
	var g: Dictionary = v.points()
	var guard: float = absf(g["foot_f"].x - g["foot_b"].x)
	var hit: int = Moves.data("power_punch", t)["startup"]
	# the loading frame: the widest held frame before the drive (the hips lead the drive by a frame or two, so the
	# drawing's last loaded frame comes a little before the load's own key)
	var load := 1
	var apart := 0.0
	var p: Dictionary = {}
	for tick in range(1, hit):
		v.apply(Poses.angles("power_punch", tick, t))
		var q: Dictionary = v.points()
		var w: float = absf(q["foot_f"].x - q["foot_b"].x)
		if w >= apart - 0.5:
			load = tick
			apart = w
			p = q
	var share: float = (p["hip"].x - p["foot_b"].x) / (p["foot_f"].x - p["foot_b"].x)
	print("- Power punch, the loading frame (%d ms before the hit): the feet %.0f px apart = %.1f shoulder widths (his" % [(hit - load) * 1000 / 60, apart, apart / Poses.SHOULDER_WIDTH])
	print("  shoulders are %.0f px across, from real bodies' proportions); the guard is %.0f px = %.1f shoulder widths. The" % [Poses.SHOULDER_WIDTH, guard, guard / Poses.SHOULDER_WIDTH])
	print("  load is %.1f times the guard. The hips sit %.0f%% of the way from the back foot to the front one (50%% = centred," % [apart / guard, share * 100.0])
	print("  as the sheet's horse stance), %.0f px off the street (%.0f in the guard). The team's sheet: guard \"shoulder-width and" % [-p["hip"].y, -g["hip"].y])
	print("  a bit\", horse stance \"a bit wider than shoulders\", 50/50.")
	# the sweep from above: how far round the foot goes at full reach
	var total := 0.0
	var prev = null
	var first := -1
	var last := -1
	for tick in Moves.length("sweep", t):
		var q := Poses.angles("sweep", tick, t)
		var b := Poses.bake(q, true)
		var reach: float = (Poses._end("leg_b_lower", b)[0] as Vector2).x - (Poses._end("hip", b)[0] as Vector2).x
		var a := deg_to_rad(q["spin"])
		var at := Vector2(reach * sin(a), -reach * cos(a))
		if absf(reach) >= 80.0:
			if prev != null:
				total += absf(rad_to_deg((prev as Vector2).angle_to(at)))
			prev = at
			if first < 0:
				first = tick
			last = tick
		else:
			prev = null
	var sh: int = Moves.data("sweep", t)["startup"]
	print("- Sweep, from above: the foot goes %.0f degrees round him at full reach (80 px or more out), from %d ms to %d ms" % [total, (first - sh) * 1000 / 60, (last - sh) * 1000 / 60])
	print("  around the hit (worked out from the pose's spin and the foot's reach; frames/sweep-from-above.png).")
	# every move's whole length, so the build can check each frame sheet covers its move start to finish
	for m in Moves.TABLE:
		print("len:%s:%d" % [m, Moves.length(m, t)])
	print("len:roll:%d" % t["roll_ticks"])
	v.free()
	quit(0)
