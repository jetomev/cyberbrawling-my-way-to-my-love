extends RefCounted
## The feel numbers, in one table, so the feel lab can change them while the game runs (L-1). Units: pixels and
## ticks; the game steps 60 ticks a second. Every fighter reads its own copy (fresh()), so a change is deliberate.

const DEFAULTS := {
	# moving along the street (x) and up/down its depth (z, the shallow street of D-13)
	"walk_speed": 4.0,
	"depth_speed": 2.4,
	"street_left": 0.0,
	"street_right": 3840.0,
	"street_depth": 160.0,
	"flat_line": false,  # true = no depth at all, the comparison build of D-13
	# jumping: height and time in the air decide gravity and the take-off speed
	"jump_height": 150.0,
	"jump_air_ticks": 40,
	"air_steer": 0.5,  # how much the stick can change a jump that's already going (0 = none, 1 = full)
	"land_ticks": 4,
	# attacks: start-up, active (can hit), recovery, all in ticks; reach in pixels from the body's centre
	"punch_startup": 4,
	"punch_active": 3,
	"punch_recovery": 8,
	"punch_reach": 112.0,
	"kick_startup": 7,
	"kick_active": 4,
	"kick_recovery": 12,
	"kick_reach": 125.0,
	"hit_depth": 28.0,  # how far up/down the street a blow still connects
	# a button pressed a little early still counts, so moves chain without frame-perfect timing
	"buffer_ticks": 6,
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
