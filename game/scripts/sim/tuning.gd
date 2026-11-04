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
	"roll_ticks": 32,  # C: the evasion roll (Javier, 2026-11-02 21:56), about half a second
	"roll_speed": 9.0,  # along the street the way the arrows point: about 1.3 body lengths (the team's roll reference
	# guesses two; the feel lab decides)
	"roll_evade_from": 0.2,  # he can't be hit only while round, over the shoulder (the team's roll reference): open in
	"roll_evade_to": 0.8,  # the dip and coming up, so a dodge has to be timed
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
	# getting hit (Stage 1: an enemy that fights back): health, and how long each reaction lasts
	"health": 30.0,  # the hero's (a level's waves need it: the bot lost level 1 on every seed at 20); an enemy's tuning sets its own
	"block_damage": 0.25,  # a plain block takes a quarter of the blow (D-19: less pain than a clean hit); perfect: none
	"hurt_ticks": 14,  # a plain hit: a flinch
	"block_hit_ticks": 10,  # a blow taken on the guard
	"stagger_ticks": 28,  # reeling back (the power punch, the hook, the roundhouse)
	"push_ticks": 18,  # shoved away (the push kick), fast at first
	"push_speed": 9.0,
	"knockback": 3.0,  # how far a plain hit moves him, px a tick at first
	"knockdown_ticks": 22,  # falling (the side kick, the sweep, a spin kick)
	"down_ticks": 50,  # lying on the street; he can't be hit there
	"get_up_ticks": 24,
	"launch_height": 110.0,  # the uppercut throws him up
	# D-19: two hero combos in a row make an enemy dizzy, the window for a finishing combo
	"dizzy_window_ticks": 240,  # the second finisher must land within this of the first, with no blow of his between
	"dizzy_ticks": 150,  # how long he stands dazed, open
	# pain, not blood (D-9): pain points on a part for each stage, and what a broken leg does to his speed
	"pain_bruised": 2.0,
	"pain_swollen": 5.0,
	"pain_broken": 9.0,
	"limp": 0.6,
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
