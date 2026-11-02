extends SceneTree
## Prints the demo's movie frame where each move first lands ("name:frame" per line), for scripts/build.sh's strip.
## Run headless: godot --headless --path game -s res://tools/demo_moments.gd

const Fighter := preload("res://scripts/sim/fighter.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")
const Demo := preload("res://scripts/sim/demo.gd")
const StreetWorld := preload("res://scripts/sim/street_world.gd")
const Moves := preload("res://scripts/sim/moves.gd")

## Movie frame f shows the hero after f + 1 ticks, which is the state after step i = f here: measured 2026-11-02 on the
## cross's fastest frame against the demo's --marks (frame 692 showed tick 693, frame 693 tick 694). It was 2 before,
## which put every still two frames late.
const MOVIE_OFFSET := 0


func _initialize() -> void:
	var w = StreetWorld.grey_street()
	var f = Fighter.new(Tuning.fresh(), 400.0, 80.0, w)
	var seen := {}
	for i in Demo.length():
		f.step(Demo.input_at(i))
		w.step_hits([f])
		var key: String = f.state
		var ready := Moves.is_move(key) and f.attack_phase() == "active"
		if key in ["climb", "block"]:
			ready = f.t == 8
		if ready and not seen.has(key):
			seen[key] = true
			print("%s:%d" % [key, i + MOVIE_OFFSET])
	quit(0)
