extends RefCounted
## The feel numbers, in one table, so the feel lab can change them while the game runs (L-1). Units: pixels and
## ticks; the game steps 60 ticks a second. Every fighter reads its own copy (fresh()), so a change is deliberate.

const DEFAULTS := {
	# moving along the street (x) and up/down its depth (z, the shallow street of D-13)
	"walk_speed": 4.0,
	"stroll_speed": 3.0,  # the walk stance's walk: brisk, 1.5 legs a second (CMU 16_15's easy walk is 1.33; Javier, 2026-11-02 21:21: "Walk is too slow")
	"run_speed": 8.0,  # W held (Javier, 2026-11-02 18:48: "the character needs to be able to walk, and run")
	"stance_switch_ticks": 8,  # X: from the fight stance to the walk stance and back
	"depth_speed": 2.4,
	"street_left": 0.0,
	"street_right": 3840.0,
	"street_depth": 160.0,
	"flat_line": false,  # true = no depth at all, the comparison build of D-13
	# jumping: height and time in the air decide gravity and the take-off speed
	"jump_height": 150.0,
	"jump_air_ticks": 40,
	"jump_squat_ticks": 4,  # the crouch before take-off (recorded jumps crouch, then drive up: CMU 16_01, 16_05)
	"jump_speed": 6.0,  # a running jump goes faster than walking, so a crate can be cleared
	"air_steer": 0.5,  # how much the stick can change a jump that's already going (0 = none, 1 = full)
	"land_ticks": 4,
	# attacks: start-up, active (can hit), recovery, all in ticks; reach in pixels from the body's centre
	"punch_startup": 4,
	"punch_active": 3,
	"punch_recovery": 8,
	"punch_reach": 128.0,
	"kick_startup": 5,  # the opening kick: the low kick, the fastest kick (Javier, 2026-11-02 18:19)
	"kick_active": 3,
	"kick_recovery": 9,
	"kick_reach": 112.0,
	"air_kick_startup": 6,  # the flying kick: chamber, then out (6 frames, the shortest that shows the chamber; was 3)
	"air_kick_active": 6,  # held out (was 10: a rigid hold); then it folds back, out until landing
	"air_kick_reach": 140.0,
	"hit_depth": 28.0,  # how far up/down the street a blow still connects
	# a button pressed a little early still counts, so moves chain without frame-perfect timing
	"buffer_ticks": 6,
	# combos (moves.gd): once a blow ends, the next press within this many ticks continues the chain
	"combo_window_ticks": 24,
	# blocking (D-19): a block's first ticks are a perfect block (with enemies: it stops their combo, can disarm)
	"perfect_block_ticks": 8,
	# climbing: push into something climbable this long, and it takes this long to get on top
	"climb_hold_ticks": 10,
	"climb_ticks": 18,
	"climb_max": 140.0,  # taller than this can't be climbed (jump up a step, or go around)
	# the view
	"camera_zoom": 1.0,
}


static func fresh() -> Dictionary:
	return DEFAULTS.duplicate(true)


static func gravity(t: Dictionary) -> float:
	var air: float = t["jump_air_ticks"]
	return 8.0 * t["jump_height"] / (air * air)


static func takeoff_speed(t: Dictionary) -> float:
	return 4.0 * t["jump_height"] / float(t["jump_air_ticks"])
