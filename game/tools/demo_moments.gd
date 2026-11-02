extends SceneTree
## Prints, for the first time each move shows up in the demo, "name:land:start:end" in movie frames: the frame it lands
## (the active blow; for climb and block, 8 ticks in), its first frame and its last, for scripts/build.sh's stills,
## close-ups and timed strips. Also "landing:touch:start:end" for the first landing after the flying kick: from 6 frames
## before the feet touch down to 10 frames after he is back up (the team's third review asked to see it frame by frame).
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
	var start := {}
	var land := {}
	var last := {}
	var prev := ""
	var touch := -1
	var printed_landing := false
	for i in Demo.length():
		f.step(Demo.input_at(i))
		w.step_hits([f])
		var key: String = f.state
		var frame := i + MOVIE_OFFSET
		if key != prev or f.t == 0:  # a new move begins (a chained move changes state; a repeat restarts t)
			if prev != "" and land.has(prev) and not seen.has(prev):
				seen[prev] = true
				print("%s:%d:%d:%d" % [prev, land[prev], start[prev], last[prev]])
			if not seen.has(key):
				start[key] = frame
				land.erase(key)
		if seen.has("air_kick") and not printed_landing:
			if key == "land" and touch < 0:
				touch = frame
			elif touch >= 0 and key != "land":
				printed_landing = true
				print("landing:%d:%d:%d" % [touch, touch - 6, mini(frame + 9, Demo.length() - 1 + MOVIE_OFFSET)])
		prev = key
		last[key] = frame
		var ready := Moves.is_move(key) and f.attack_phase() == "active"
		if key in ["climb", "block"]:
			ready = f.t == 8
		if ready and not land.has(key) and not seen.has(key):
			land[key] = frame
	if land.has(prev) and not seen.has(prev):
		print("%s:%d:%d:%d" % [prev, land[prev], start[prev], last[prev]])
	quit(0)
