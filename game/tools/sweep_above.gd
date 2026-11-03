extends SceneTree
## The sweep seen from above, for the testers (2026-11-02 23:29: "the sweep from a clearer angle, so its circle
## shows"). The game draws only from the side, where a circle on the street looks like a leg swinging back and forth.
## This prints, for every frame of the sweep, the body's spin and how far the sweeping foot reaches forward of the hips
## in the body's own frame; scripts/sweep_above.py draws the foot's path from above. Javier & Claude.
## Prints "frame spin reach" lines, then "hit <frame>".

const Poses := preload("res://scripts/present/poses.gd")
const Moves := preload("res://scripts/sim/moves.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")


func _initialize() -> void:
	var t := Tuning.fresh()
	for tick in Moves.length("sweep", t):
		var p := Poses.angles("sweep", tick, t)
		var b := Poses.bake(p, true)
		var reach: float = (Poses._end("leg_b_lower", b)[0] as Vector2).x - (Poses._end("hip", b)[0] as Vector2).x
		print("%d %.1f %.1f" % [tick, p["spin"], reach])
	print("hit %d" % Moves.data("sweep", t)["startup"])
	quit(0)
