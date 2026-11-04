extends "res://tests/test_case.gd"
## The street in layers (docs/STYLE.md): as the camera moves, each layer slides at its own speed, the far ones slower,
## the foreground faster, and the foreground draws in front of the fighters.

const Street := preload("res://scripts/present/street.gd")


func test_each_layer_slides_at_its_own_speed() -> void:
	var s = Street.new()
	s._ready()
	s.follow(0.0)
	var at := {}
	for spec in Street.LAYERS:
		at[spec[0]] = s.layers[spec[0]].position.x
	s.follow(1000.0)
	for spec in Street.LAYERS:
		# on screen a layer moves (its own move - the camera's); seen against the camera it should move f per px
		var seen: float = 1000.0 - (s.layers[spec[0]].position.x - at[spec[0]])
		check(absf(seen - 1000.0 * spec[1]) < 0.01, "%s moves %.0f px on screen for 1000 of camera (want %.0f)" % [spec[0], seen, 1000.0 * spec[1]])
	var speeds: Array = Street.LAYERS.map(func(l): return l[1])
	var sorted := speeds.duplicate()
	sorted.sort()
	eq(speeds, sorted, "back to front, each layer faster than the one behind it")
	check(s.layers["fore"].z_index > 500, "the foreground draws in front of the fighters")
	check(s.layers["mid"].z_index < 0, "the buildings behind the street")
	s.free()
