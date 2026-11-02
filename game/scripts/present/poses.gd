extends RefCounted
## The grey-box body (D-4: cut-out parts on 2D bones) and its poses, as plain data, so tests can read them without a
## scene. The real art later replaces each grey part with a drawn one on the same bone: belly, chest, neck, head,
## shoulders, upper and lower arms, hands (a fist or an open hand), thighs, shins, feet and toes (D-20).
##
## A bone points along its own +x. Its rest angle is relative to its parent; poses add an offset in degrees. With
## the body facing right: for bones hanging down (legs, arms, shoulders), a negative offset swings them forward; a
## positive "torso" leans the body forward (shared between belly and chest); a positive lower-leg offset bends the
## knee, a negative forearm offset bends the elbow up. "hip_y" moves the whole body down in pixels.
##
## Poses are written in a few keys and bake() fills in the rest, so every move gets the same body sense:
## - the neck takes back part of the lean, so the head follows the eyes instead of the spine;
## - a shoulder rolls forward as its arm reaches, moving the arm's root, not the arm's aim;
## - a foot on the ground keeps its toes on the street: flat when the ankle is low, rolled onto the toes (heel up) as
##   the leg lifts the ankle, pointed once the ankle is higher than the foot is long, or in the air;
## - the body settles until its lower planted foot stands on the street;
## - "open_f" / "open_b" (0 or 1) open a hand; hands are fists otherwise;
## - "cover_f" / "cover_b" (0 to 1) bring that fist up to the cheek, wherever the head is, the elbow down: the free hand
##   guards the face while the other one strikes (the assistant team's review, 2026-11-02);
## - "rise_f" / "rise_b" (0 to 1) put that planted foot up on its toes, heel off the street: the standing foot pivots
##   on the spinning kicks;
## - "spin" (degrees) turns the whole body around the up axis: hero_view.gd squeezes the drawing by its cosine, so at
##   90 the fighter is edge-on and at 180 he shows his back. A spin ends on a whole turn (360 = facing again);
## - "turn" (degrees) turns only the hips and shoulders over, the legs keep their size: the chest narrows, and past 90
##   the far-side arm and leg come in front of the body (his back shows), as on a roundhouse or a cross;
## - "pivot_f" / "pivot_b" (degrees) swing a standing foot round on its ball: at 180 the heel points at the target;
## - "feet" (0 or 1) places the feet instead of bending the legs: each ankle goes to its stance spot (STANCE) moved
##   by "step_f" / "step_b" (px forward) and lifted by "lift_f" / "lift_b" (px), and the legs bend to reach it;
## - "fore_f" / "fore_b" (0 to 1) point that forearm at the camera: it draws shorter (down to FORE_SHORT of its length),
##   as a hook's forearm does coming across the body. Hits are measured on the same shortened arm.

const Moves := preload("res://scripts/sim/moves.gd")

## Parents come before their children; back limbs before the body, front limbs after (that is the drawing order).
## name: [parent, position on the parent bone, rest angle, length, width, shade (0 = front, 1 = back)]
const BONES := {
	"hip": ["", Vector2(0, -125), 0.0, 0.0, 0.0, 0],
	"leg_b_upper": ["hip", Vector2(0, 0), 90.0, 62.0, 26.0, 1],
	"leg_b_lower": ["leg_b_upper", Vector2(62, 0), 0.0, 58.0, 21.0, 1],
	"foot_b": ["leg_b_lower", Vector2(58, 0), -90.0, 24.0, 13.0, 1],
	"toe_b": ["foot_b", Vector2(24, 0), 0.0, 11.0, 11.0, 1],
	"belly": ["hip", Vector2(0, 0), -90.0, 40.0, 44.0, 0],
	"chest": ["belly", Vector2(40, 0), 0.0, 46.0, 50.0, 0],
	"shoulder_b": ["chest", Vector2(42, 0), 180.0, 14.0, 20.0, 1],
	"arm_b_upper": ["shoulder_b", Vector2(14, 0), 0.0, 44.0, 18.0, 1],
	"arm_b_lower": ["arm_b_upper", Vector2(44, 0), 0.0, 44.0, 15.0, 1],
	"hand_b": ["arm_b_lower", Vector2(44, 0), 0.0, 16.0, 17.0, 1],
	"neck": ["chest", Vector2(46, 0), 0.0, 12.0, 17.0, 0],
	"head": ["neck", Vector2(12, 0), 0.0, 44.0, 40.0, 0],
	"leg_f_upper": ["hip", Vector2(0, 0), 90.0, 62.0, 26.0, 0],
	"leg_f_lower": ["leg_f_upper", Vector2(62, 0), 0.0, 58.0, 21.0, 0],
	"foot_f": ["leg_f_lower", Vector2(58, 0), -90.0, 24.0, 13.0, 0],
	"toe_f": ["foot_f", Vector2(24, 0), 0.0, 11.0, 11.0, 0],
	"shoulder_f": ["chest", Vector2(42, 0), 180.0, 14.0, 20.0, 0],
	"arm_f_upper": ["shoulder_f", Vector2(14, 0), 0.0, 44.0, 18.0, 0],
	"arm_f_lower": ["arm_f_upper", Vector2(44, 0), 0.0, 44.0, 15.0, 0],
	"hand_f": ["arm_f_lower", Vector2(44, 0), 0.0, 16.0, 17.0, 0],
}

## Keys a pose may hold besides bones: shared or automatic parts that bake() turns into bone angles.
const SOFT_KEYS := ["hip_x", "hip_y", "hip_turn", "torso", "open_f", "open_b", "cover_f", "cover_b", "rise_f", "rise_b",
	"spin", "turn", "pivot_f", "pivot_b", "fore_f", "fore_b", "feet", "step_f", "step_b", "lift_f", "lift_b"]
## Keys that switch something on rather than bend it: a follow-through never carries them further.
const SWITCH_KEYS := ["open_f", "open_b", "cover_f", "cover_b", "rise_f", "rise_b", "spin", "turn", "pivot_f", "pivot_b",
	"fore_f", "fore_b", "feet", "step_f", "step_b", "lift_f", "lift_b"]

## The whip (D-21): in a strike the hips move first and the fist or foot arrives last. Each key is read this many
## ticks ahead on the move's curve, so the hips lead, the spine follows, then the shoulder and the upper limb; the
## forearm, hand, shin and foot keep the move's own timing (so the blow still lands when the logic says it does).
## The head trails a tick behind.
const LEAD := {"hip_x": 3, "hip_turn": 3, "hip_y": 3, "spin": 2, "turn": 2, "pivot_f": 3, "pivot_b": 3, "torso": 2, "arm_f_upper": 1, "arm_b_upper": 1,
	"leg_f_upper": 1, "leg_b_upper": 1, "head": -1}
const FOOT_LENGTH := 24.0  # ankle to the ball of the foot
const TOE_LENGTH := 11.0  # an ankle higher than foot + toes lets the foot point

## The guard, the fighter's home stance (Javier, 2026-11-02 morning: "posture and movements ... still terrible"; the
## assistant team: the stance first): feet wider than the shoulders, front foot 44 px ahead of the hips and the back
## foot 63 px behind, the front knee well bent and the back leg nearly straight, hips dropped (the legs solved for
## ankles 100 px under the hips; with the back foot only 50 px back its knee folded and any dip read as kneeling), weight
## between the feet, a slight lean in, chin down, both fists up at the cheeks with the elbows in (cover_f, cover_b; the
## front fist a little further forward), shoulders loose. Any move that uses an arm switches its cover off for itself.
const GUARD := {
	"torso": 10.0, "neck": 14.0, "head": 6.0, "hand_f": -15.0, "hand_b": -15.0,
	"arm_f_upper": -62.0, "arm_f_lower": -114.0, "arm_b_upper": -25.0, "arm_b_lower": -100.0,
	"leg_f_upper": -47.3, "leg_f_lower": 48.9, "leg_b_upper": 22.6, "leg_b_lower": 19.9, "hip_y": 0.0,
	"open_f": 0.0, "open_b": 0.0, "hip_x": 0.0, "hip_turn": 0.0, "cover_f": 1.0, "cover_b": 1.0, "rise_f": 0.0,
	"rise_b": 0.0, "spin": 0.0, "turn": 0.0, "pivot_f": 0.0, "pivot_b": 0.0, "fore_f": 0.0, "fore_b": 0.0,
	"feet": 0.0, "step_f": 0.0, "step_b": 0.0, "lift_f": 0.0, "lift_b": 0.0,
}
## Where the ankles stand in the guard, from the hip joint: the guard's legs are solved for these spots.
const STANCE := {"f": Vector2(44.0, 100.0), "b": Vector2(-63.0, 100.0)}
## The walk is a fighter's shuffle, not a stroll (Javier, 2026-11-02 morning): the front foot steps out, the back foot
## follows, the feet never pass each other and the stance never breaks. A cycle of WALK_CYCLE ticks; each foot spends
## WALK_STEP of them in the air and the rest planted, sliding back under the body at exactly the walking speed, so a
## planted foot stays put on the street.
const WALK_CYCLE := 24
const WALK_STEP := 10
const FORE_SHORT := 0.4  # a forearm pointing straight at the camera draws at 40% of its length
## How far into its start-up a strike is cocked (the wind-up moment). Most cock late (0.7), so the blow reads as a
## snap; the swinging ones cock early, so the swing round to the target lasts long enough to be seen.
const WINDUP_AT := {"hook": 0.4, "roundhouse": 0.45, "spin_kick": 0.5}
## Where a covering fist sits: from the middle of the head, forward and a little down, in front of the jaw. Far enough
## forward to show past the face: the far hand is drawn behind the head, and at (16, 16) it hid there, so all one saw
## of it was its forearm across the chest (the assistant team's third review, 2026-11-02).
const CHEEK := Vector2(30.0, 14.0)
const CHEEK_FRONT := Vector2(42.0, 18.0)  # the front fist in the guard: up at the cheek, a little further out

## Looping states: [loop length in ticks, [tick, changes from GUARD], ...]
const LOOPS := {
	# the guard is never dead still: the weight rocks gently from the back leg to the front and back, knees giving
	"idle": [60, [0, {"hip_x": -6.0, "hip_turn": -2.0, "hip_y": 0.0, "torso": 9.0, "head": 9.0}],
		[30, {"hip_x": 6.0, "hip_turn": 2.0, "hip_y": 4.0, "torso": 12.0, "head": 7.0}]],
	"walk": [24, [0, {"feet": 1.0, "hip_y": 2.0, "hip_turn": -3.0, "torso": 12.0}],
		[6, {"feet": 1.0, "hip_y": -2.0, "hip_turn": 0.0, "torso": 11.0}],
		[12, {"feet": 1.0, "hip_y": 2.0, "hip_turn": 3.0, "torso": 12.0}],
		[18, {"feet": 1.0, "hip_y": -2.0, "hip_turn": 0.0, "torso": 11.0}]],
}

## One-shot states, keyed by named moments the tuning decides (see moment()). A strike runs wind-up, hit, hold,
## follow-through, then eases back to the guard; an empty "follow" means "carry the hit a little further".
const SHOTS := {
	"jump": [["start", {"cover_f": 0.0, "cover_b": 0.0, "open_f": 1.0, "open_b": 1.0, "leg_f_upper": -60.0, "leg_f_lower": 95.0, "leg_b_upper": -20.0, "leg_b_lower": 105.0,
		"arm_f_upper": -70.0, "arm_b_upper": -45.0, "hip_y": 0.0}]],
	"land": [["start", {"hip_y": 16.0, "rise_b": 0.6, "torso": 16.0}],
		["end", {}]],
	"punch": [["start", {"cover_f": 0.0}],
		["windup", {"cover_f": 0.0, "hip_x": -2.0, "hip_turn": -2.0, "arm_f_upper": -45.0, "arm_f_lower": -125.0, "torso": 4.0}],
		["active", {"cover_f": 0.0, "hip_x": 3.0, "hip_turn": 3.0, "arm_f_upper": -98.0, "arm_f_lower": 0.0, "torso": 6.0, "head": -6.0}],
		["active_end", {"cover_f": 0.0, "hip_x": 3.0, "hip_turn": 3.0, "arm_f_upper": -98.0, "arm_f_lower": 0.0, "torso": 6.0, "head": -6.0}],
		["follow", {}],
		["end", {}]],
	"air_kick": [["start", {"cover_f": 0.0, "cover_b": 0.0, "leg_f_upper": -60.0, "leg_f_lower": 95.0, "leg_b_upper": -20.0, "leg_b_lower": 105.0,
		"arm_f_upper": -70.0, "arm_b_upper": -45.0, "hip_y": 0.0}],
		["startup", {"cover_f": 0.0, "cover_b": 0.0, "leg_f_upper": -92.0, "leg_f_lower": -4.0, "leg_b_upper": 34.0, "leg_b_lower": 85.0, "torso": -22.0,
			"head": 14.0, "arm_f_upper": -30.0, "arm_f_lower": -60.0, "arm_b_upper": 40.0, "arm_b_lower": -40.0, "hip_y": 0.0}],
		["active_end", {"cover_f": 0.0, "cover_b": 0.0, "leg_f_upper": -92.0, "leg_f_lower": -4.0, "leg_b_upper": 34.0, "leg_b_lower": 85.0, "torso": -22.0,
			"head": 14.0, "arm_f_upper": -30.0, "arm_f_lower": -60.0, "arm_b_upper": 40.0, "arm_b_lower": -40.0, "hip_y": 0.0}],
		["tuck", {"cover_f": 0.0, "cover_b": 0.0, "leg_f_upper": -70.0, "leg_f_lower": 105.0, "leg_b_upper": -10.0, "leg_b_lower": 95.0, "torso": 4.0,
			"arm_f_upper": -60.0, "arm_f_lower": -90.0, "arm_b_upper": -30.0, "arm_b_lower": -80.0, "hip_y": 0.0}]],
	"climb": [["start", {"cover_f": 0.0, "cover_b": 0.0, "open_f": 1.0, "open_b": 1.0, "hand_f": -30.0, "hand_b": -30.0, "arm_f_upper": -165.0, "arm_f_lower": 0.0, "arm_b_upper": -150.0, "arm_b_lower": 0.0,
			"leg_f_upper": -20.0, "leg_f_lower": 30.0, "hip_y": 0.0}],
		["climb_mid", {"cover_f": 0.0, "cover_b": 0.0, "open_f": 1.0, "open_b": 1.0, "hand_f": 60.0, "hand_b": 60.0, "arm_f_upper": -60.0, "arm_f_lower": -30.0, "arm_b_upper": -40.0, "arm_b_lower": -30.0,
			"torso": 35.0, "leg_f_upper": -95.0, "leg_f_lower": 100.0, "leg_b_upper": 20.0, "leg_b_lower": 40.0, "hip_y": 10.0}],
		["end", {}]],
	"cross": [["start", {}],
		["windup", {"cover_b": 0.0, "cover_f": 1.0, "turn": -20.0, "hip_x": -10.0, "hip_turn": -8.0, "arm_b_upper": -10.0, "arm_b_lower": -120.0, "torso": -2.0}],
		["active", {"rise_b": 1.0, "cover_b": 0.0, "cover_f": 1.0, "turn": 50.0, "hip_x": 17.0, "hip_turn": 16.0, "arm_b_upper": -108.0, "arm_b_lower": 0.0, "torso": 32.0, "head": -16.0}],
		["active_end", {"rise_b": 1.0, "cover_b": 0.0, "cover_f": 1.0, "turn": 50.0, "hip_x": 17.0, "hip_turn": 16.0, "arm_b_upper": -108.0, "arm_b_lower": 0.0, "torso": 32.0, "head": -16.0}],
		["follow", {}],
		["end", {}]],
	"hook": [["start", {"cover_f": 0.0}],
		["windup", {"cover_f": 0.0, "fore_f": 1.0, "turn": -30.0, "hip_x": -10.0, "hip_turn": -14.0, "arm_f_upper": -140.0, "arm_f_lower": -138.0, "torso": -10.0, "head": 6.0}],
		["sweep", {"cover_f": 0.0, "fore_f": 0.9, "turn": 20.0, "hip_x": 2.0, "hip_turn": 4.0, "arm_f_upper": -86.0, "arm_f_lower": -100.0, "torso": 12.0, "head": -6.0}],
		["active", {"cover_f": 0.0, "fore_f": 0.45, "turn": 60.0, "hip_x": 12.0, "hip_turn": 24.0, "arm_f_upper": -112.0, "arm_f_lower": -46.0, "torso": 30.0, "head": -14.0}],
		["active_end", {"cover_f": 0.0, "fore_f": 0.45, "turn": 60.0, "hip_x": 12.0, "hip_turn": 24.0, "arm_f_upper": -112.0, "arm_f_lower": -46.0, "torso": 30.0, "head": -14.0}],
		["follow", {}],
		["end", {}]],
	"uppercut": [["start", {}],
		["windup", {"cover_b": 0.0, "cover_f": 1.0, "hip_x": -6.0, "hip_turn": 6.0, "arm_b_upper": 10.0, "arm_b_lower": -100.0, "torso": 14.0, "hip_y": 14.0}],
		["active", {"rise_b": 0.6, "cover_b": 0.0, "cover_f": 1.0, "hip_x": 8.0, "hip_turn": -8.0, "arm_b_upper": -68.0, "arm_b_lower": -102.0, "torso": 6.0, "head": 4.0, "hip_y": -4.0}],
		["active_end", {"rise_b": 0.6, "cover_b": 0.0, "cover_f": 1.0, "hip_x": 8.0, "hip_turn": -8.0, "arm_b_upper": -68.0, "arm_b_lower": -102.0, "torso": 6.0, "head": 4.0, "hip_y": -4.0}],
		["follow", {}],
		["end", {}]],
	"knee": [["start", {"cover_f": 0.0, "cover_b": 0.0}],
		["windup", {"cover_f": 0.0, "cover_b": 0.0, "hip_x": -4.0, "leg_f_upper": -40.0, "leg_f_lower": 60.0, "arm_f_upper": -80.0, "arm_b_upper": -70.0}],
		["active", {"cover_f": 0.0, "cover_b": 0.0, "hip_x": 6.0, "hip_turn": -6.0, "leg_f_upper": -100.0, "leg_f_lower": 120.0, "torso": 14.0, "arm_f_upper": -40.0, "arm_f_lower": -40.0, "arm_b_upper": -40.0, "arm_b_lower": -40.0, "hip_y": 0.0}],
		["active_end", {"cover_f": 0.0, "cover_b": 0.0, "hip_x": 6.0, "hip_turn": -6.0, "leg_f_upper": -100.0, "leg_f_lower": 120.0, "torso": 14.0, "arm_f_upper": -40.0, "arm_f_lower": -40.0, "arm_b_upper": -40.0, "arm_b_lower": -40.0, "hip_y": 0.0}],
		["follow", {}],
		["end", {}]],
	"push_kick": [["start", {}],
		["windup", {"hip_x": -6.0, "hip_turn": -4.0, "leg_f_upper": -80.0, "leg_f_lower": 110.0, "torso": -6.0, "hip_y": 0.0}],
		["active", {"hip_x": 14.0, "hip_turn": -14.0, "leg_f_upper": -98.0, "leg_f_lower": -2.0, "torso": -30.0, "head": 16.0, "hip_y": 0.0}],
		["active_end", {"hip_x": 14.0, "hip_turn": -14.0, "leg_f_upper": -98.0, "leg_f_lower": -2.0, "torso": -30.0, "head": 16.0, "hip_y": 0.0}],
		["follow", {}],
		["end", {}]],
	"body_kick": [["start", {}],
		["windup", {"hip_x": 6.0, "hip_turn": -4.0, "leg_b_upper": -40.0, "leg_b_lower": 80.0, "torso": -10.0, "hip_y": 0.0}],
		["active", {"hip_x": 12.0, "hip_turn": -12.0, "leg_b_upper": -95.0, "leg_b_lower": 0.0, "torso": -28.0, "head": 16.0, "hip_y": 0.0}],
		["active_end", {"hip_x": 12.0, "hip_turn": -12.0, "leg_b_upper": -95.0, "leg_b_lower": 0.0, "torso": -28.0, "head": 16.0, "hip_y": 0.0}],
		["follow", {}],
		["end", {}]],
	"spin_kick": [["start", {}],
		["windup", {"spin": 170.0, "rise_b": 1.0, "hip_x": -4.0, "hip_turn": 14.0, "leg_f_upper": -95.0, "leg_f_lower": 120.0, "torso": 40.0, "head": -20.0, "hip_y": 6.0}],
		["sweep", {"spin": 290.0, "rise_b": 1.0, "hip_x": -8.0, "hip_turn": -10.0, "leg_f_upper": -112.0, "leg_f_lower": 85.0, "torso": -10.0, "head": 8.0, "hip_y": 0.0}],
		["active", {"spin": 360.0, "rise_b": 1.0, "hip_x": -14.0, "hip_turn": -24.0, "leg_f_upper": -122.0, "leg_f_lower": 0.0, "torso": -46.0, "head": 26.0, "hip_y": 0.0}],
		["active_end", {"spin": 360.0, "rise_b": 1.0, "hip_x": -14.0, "hip_turn": -24.0, "leg_f_upper": -122.0, "leg_f_lower": 0.0, "torso": -46.0, "head": 26.0, "hip_y": 0.0}],
		["follow", {}],
		["end", {"spin": 360.0}]],
	"elbow": [["start", {"cover_f": 0.0}],
		["windup", {"cover_f": 0.0, "cover_b": 1.0, "hip_x": -5.0, "hip_turn": -5.0, "arm_f_upper": -60.0, "arm_f_lower": -150.0, "torso": -4.0}],
		["active", {"cover_f": 0.0, "cover_b": 1.0, "hip_x": 12.0, "hip_turn": 10.0, "arm_f_upper": -100.0, "arm_f_lower": -160.0, "torso": 24.0, "head": -10.0}],
		["active_end", {"cover_f": 0.0, "cover_b": 1.0, "hip_x": 12.0, "hip_turn": 10.0, "arm_f_upper": -100.0, "arm_f_lower": -160.0, "torso": 24.0, "head": -10.0}],
		["follow", {}],
		["end", {}]],
	"roundhouse": [["start", {}],
		["windup", {"turn": 40.0, "pivot_f": 60.0, "rise_f": 0.2, "hip_x": 4.0, "hip_turn": -10.0, "leg_b_upper": -60.0, "leg_b_lower": 115.0, "torso": -14.0, "hip_y": 0.0}],
		["sweep", {"turn": 90.0, "pivot_f": 120.0, "rise_f": 0.4, "hip_x": 10.0, "hip_turn": -20.0, "leg_b_upper": -100.0, "leg_b_lower": 95.0, "torso": -30.0, "head": 14.0, "hip_y": 0.0}],
		["active", {"turn": 165.0, "pivot_f": 170.0, "rise_f": 0.6, "hip_x": 14.0, "hip_turn": -30.0, "leg_b_upper": -106.0, "leg_b_lower": 52.0, "torso": -26.0, "head": 16.0, "hip_y": 0.0}],
		["active_end", {"turn": 165.0, "pivot_f": 170.0, "rise_f": 0.6, "hip_x": 14.0, "hip_turn": -30.0, "leg_b_upper": -106.0, "leg_b_lower": 52.0, "torso": -26.0, "head": 16.0, "hip_y": 0.0}],
		["follow", {}],
		["end", {}]],
	"hammer_fist": [["start", {"cover_f": 0.0, "open_f": 0.0, "arm_f_upper": -170.0, "arm_f_lower": -20.0, "leg_f_upper": -60.0, "leg_f_lower": 95.0,
			"leg_b_upper": -20.0, "leg_b_lower": 105.0, "hip_y": 0.0}],
		["startup", {"cover_f": 0.0, "arm_f_upper": -55.0, "arm_f_lower": -10.0, "torso": 24.0, "head": -10.0, "leg_f_upper": -60.0,
			"leg_f_lower": 95.0, "leg_b_upper": -20.0, "leg_b_lower": 105.0, "hip_y": 0.0}]],
	"block": [["start", {"cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": -38.0, "arm_f_lower": -140.0, "arm_b_upper": -30.0, "arm_b_lower": -145.0,
		"torso": 4.0, "head": 12.0,
		"hip_y": 6.0}]],
	"kick": [["start", {}],
		["windup", {"hip_x": -6.0, "hip_turn": -4.0, "leg_f_upper": -72.0, "leg_f_lower": 105.0, "torso": -8.0, "hip_y": 0.0}],
		["active", {"hip_x": 12.0, "hip_turn": -12.0, "leg_f_upper": -100.0, "leg_f_lower": 0.0, "torso": -26.0, "head": 18.0, "hip_y": 0.0}],
		["active_end", {"hip_x": 12.0, "hip_turn": -12.0, "leg_f_upper": -100.0, "leg_f_lower": 0.0, "torso": -26.0, "head": 18.0, "hip_y": 0.0}],
		["follow", {}],
		["end", {}]],
}


static func moment(state: String, name: String, tune: Dictionary) -> int:
	match name:
		"start":
			return 0
		"end":
			match state:
				"land": return tune["land_ticks"]
				"climb": return tune["climb_ticks"]
			return Moves.length(state, tune)
		"climb_mid":
			return tune["climb_ticks"] / 2
	var d := Moves.data(state, tune)
	match name:
		"windup":
			return maxi(1, int(round(d["startup"] * WINDUP_AT.get(state, 0.7))))  # cocked a beat before the blow
		"sweep":
			# halfway round a swing, between the wind-up and the blow: a bent knee or elbow coming round
			return (moment(state, "windup", tune) + d["startup"]) / 2 + 1
		"startup", "active":
			return d["startup"]
		"active_end":
			return d["startup"] + d["active"] - 1
		"follow":
			return d["startup"] + d["active"] - 1 + maxi(2, int(d["recovery"] * 0.35))
		"tuck":
			return d["startup"] + d["active"] - 1 + 6  # after a flying kick, the knee pulls back in for the landing
	return 0


static func full(changes: Dictionary) -> Dictionary:
	var out := GUARD.duplicate()
	out.merge(changes, true)
	return out


## A hit carried a little past itself: 12% further from the guard, every key.
static func overshoot(hit: Dictionary) -> Dictionary:
	var out := {}
	for k in hit:
		out[k] = hit[k] + (hit[k] - GUARD.get(k, 0.0)) * 0.12 if not k in SWITCH_KEYS else hit[k]
	return out


static func blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var s := k * k * (3.0 - 2.0 * k)  # ease in and out, so moves read as snaps, not slides
	var out := {}
	for key in a:
		out[key] = lerpf(a[key], b.get(key, a[key]), s)
	return out


## The pose (soft keys and bone offsets) for a state, t ticks into it.
static func angles(state: String, t: int, tune: Dictionary) -> Dictionary:
	if LOOPS.has(state):
		var spec: Array = LOOPS[state]
		var length: int = spec[0]
		var keys := spec.slice(1)
		var tt := t % length
		for i in keys.size():
			var k0: Array = keys[i]
			var k1: Array = keys[(i + 1) % keys.size()]
			var t1: int = k1[0] if i + 1 < keys.size() else length
			if tt >= k0[0] and tt < t1:
				var pose := blend(full(k0[1]), full(k1[1]), float(tt - k0[0]) / float(t1 - k0[0]))
				if state == "walk":
					pose.merge(_walk_feet(t, tune), true)
				return pose
		return full({})
	if SHOTS.has(state):
		var keys: Array = SHOTS[state]
		if keys.size() == 1:
			return full(keys[0][1])
		var poses := []
		for i in keys.size():
			var p: Dictionary = full(keys[i][1])
			if keys[i][0] == "follow":
				p = overshoot(poses[i - 1])
			poses.append(p)
		var now := _shot_at(state, keys, poses, t, tune)
		if not Moves.is_move(state):
			return now
		var out := now.duplicate()
		var striker: String = Moves.data(state, tune)["limb"]  # the striking part keeps the move's own timing
		for k in LEAD:
			if out.has(k) and k != striker:
				out[k] = _shot_at(state, keys, poses, maxi(0, t + LEAD[k]), tune)[k]
		return out
	return full({})


## Where the feet are in the shuffle at tick t: each foot steps out over WALK_STEP ticks (lifted, eased), then stays
## planted, sliding back under the body at the walking speed. The back foot steps half a cycle after the front.
static func _walk_feet(t: int, tune: Dictionary) -> Dictionary:
	var v: float = tune["walk_speed"]
	var reach := v * float(WALK_CYCLE - WALK_STEP) * 0.5  # how far a foot lands ahead of its stance spot
	var out := {"feet": 1.0}
	for side in ["f", "b"]:
		var u := (t + (0 if side == "f" else WALK_CYCLE / 2)) % WALK_CYCLE
		if u < WALK_STEP:
			var k := float(u) / WALK_STEP
			out["step_" + side] = lerpf(-reach, reach, k * k * (3.0 - 2.0 * k))
			out["lift_" + side] = 14.0 * sin(PI * k)
		else:
			out["step_" + side] = reach - v * float(u - WALK_STEP)
			out["lift_" + side] = 0.0
	return out


static func _shot_at(state: String, keys: Array, poses: Array, t: int, tune: Dictionary) -> Dictionary:
	for i in range(keys.size() - 1):
		var a: int = moment(state, keys[i][0], tune)
		var b: int = moment(state, keys[i + 1][0], tune)
		if t < b or i == keys.size() - 2:
			var k := 1.0 if b <= a else clampf(float(t - a) / float(b - a), 0.0, 1.0)
			return blend(poses[i], poses[i + 1], k)
	return poses[-1]


## Turns a pose into an angle for every bone (degrees, added to the rest angle), plus hip_y and the open hands.
## grounded = the fighter stands on something (feet plant); false = in the air (feet point).
static func bake(pose: Dictionary, grounded := true) -> Dictionary:
	var out := {}
	for b in BONES:
		out[b] = pose.get(b, 0.0)
	if pose.get("feet", 0.0) > 0.5:
		# feet placed, legs bent to reach them (the hips are still level here; they shift and tip further down)
		var joint: Vector2 = _end("hip", out)[0]
		var to := {}
		var drop := 0.0
		for side in ["f", "b"]:
			to[side] = STANCE[side] + Vector2(pose.get("step_" + side, 0.0), -pose.get("lift_" + side, 0.0))
			# a stance stretched wider than a leg reaches: the hips drop just enough (they never drag a foot)
			var span: float = BONES["leg_%s_upper" % side][3] + BONES["leg_%s_lower" % side][3] - 1.0
			var tx: float = (to[side] as Vector2).x
			if absf(tx) < span:
				drop = maxf(drop, (to[side] as Vector2).y - sqrt(span * span - tx * tx))
		for side in ["f", "b"]:
			_reach_with_leg(out, side, joint + to[side] - Vector2(0, drop))
	var lean: float = pose.get("torso", 0.0)
	var pelvis: float = pose.get("hip_turn", 0.0)
	# the pelvis tips first and the spine bends the rest of the way: the total lean is still "torso"
	out["belly"] += lean * 0.4 - pelvis
	out["chest"] += lean * 0.6
	out["neck"] += -lean * 0.35  # the head follows the eyes, not the spine
	var rolls := {}
	for side in ["f", "b"]:
		# a shoulder rolls forward as its arm reaches
		var reach: float = pose.get("arm_%s_upper" % side, 0.0) - GUARD["arm_%s_upper" % side]
		rolls[side] = clampf(reach * 0.8, -75.0, 25.0) * (1.0 - pose.get("cover_" + side, 0.0))  # a guard isn't a reach
	for side in ["f", "b"]:
		# … and the other shoulder swings back, the way a body turns into a punch; the arms keep their aim
		var other := "b" if side == "f" else "f"
		var roll: float = pose.get("shoulder_" + side, rolls[side] - rolls[other] * 0.4)
		out["shoulder_" + side] = roll
		out["arm_%s_upper" % side] -= roll
	out["hip_x"] = 0.0
	out["hip_y"] = pose.get("hip_y", 0.0) if not grounded else 0.0
	out["open_f"] = pose.get("open_f", 0.0)
	out["open_b"] = pose.get("open_b", 0.0)
	for k in ["rise_f", "rise_b", "spin", "turn", "pivot_f", "pivot_b", "fore_f", "fore_b"]:
		out[k] = pose.get(k, 0.0)
	for side in ["f", "b"]:
		_settle_foot(out, side, grounded)
	if not grounded:
		out["hip"] = pelvis
		for side in ["f", "b"]:
			out["leg_%s_upper" % side] -= pelvis
		_cover(out, pose)
		return out
	# the body stands on its feet. Start from the lower ankle on the street (feet flat), or bent knees can leave both
	# feet "settled" on their toes, a stable but wrong answer; then settle until the lower planted foot's toes touch
	# a leg the move swings (a kick leaving the street or coming back) is "in use": the other one is stood on
	var using := {}
	for side in ["f", "b"]:
		using[side] = pose.get("feet", 0.0) < 0.5 and absf(pose.get("leg_%s_upper" % side, 0.0) - GUARD["leg_%s_upper" % side]) \
			+ absf(pose.get("leg_%s_lower" % side, 0.0) - GUARD["leg_%s_lower" % side]) > 0.5
	var stood := ["f", "b"].filter(func(sd): return not using[sd])
	if stood.is_empty():
		stood = ["f", "b"]
	var ankle_low := -INF
	for side in stood:
		ankle_low = maxf(ankle_low, (_end("leg_%s_lower" % side, out)[0] as Vector2).y)
	out["hip_y"] -= ankle_low
	for side in ["f", "b"]:
		_settle_foot(out, side, grounded)
	# (flat feet decide the height: a heel rising onto its toes is that leg reaching, not the body going up; and a leg
	# the move is using, a kick just leaving the street or coming back to it, never lifts the one he stands on)
	for i in 16:
		var lowest := -INF
		var flat := -INF
		var standing := -INF
		for side in ["f", "b"]:
			if _planted(out, side):
				var toe_y: float = (_end("toe_" + side, out)[0] as Vector2).y
				lowest = maxf(lowest, toe_y)
				if out.get("rise_" + side, 0.0) < 0.5:
					flat = maxf(flat, toe_y)
					if not using[side]:
						standing = maxf(standing, toe_y)
		if standing != -INF:
			lowest = standing
		elif flat != -INF:
			lowest = flat
		if lowest == -INF or absf(lowest) < 0.05:
			break
		out["hip_y"] -= lowest
		for side in ["f", "b"]:
			_settle_foot(out, side, grounded)
	# the weight shifts and the pelvis tips while the planted feet stay where they are: the legs bend to keep them
	var anchors := {}
	var rising := []
	for side in ["f", "b"]:
		if _planted(out, side) and (not using[side] or stood.size() == 2):
			anchors[side] = _end("leg_%s_lower" % side, out)[0]
			if out.get("rise_" + side, 0.0) > 0.0:
				rising.append(side)
	# standing, "hip_y" is a dip on top of the stance (knees giving, a crouch): applied after the feet are set, so the
	# legs bend to keep them (before, the settle wiped it out and the idle's breathing never showed)
	out["hip_y"] += pose.get("hip_y", 0.0)
	out["hip_x"] = pose.get("hip_x", 0.0)
	out["hip"] = pelvis
	for side in ["f", "b"]:
		if not anchors.has(side):
			out["leg_%s_upper" % side] -= pelvis  # a raised leg keeps its aim: the pelvis bends the back, not the kick
	# a rising heel ("rise_"). On one leg (no flat foot left) the whole body goes up onto its toes. Otherwise the leg
	# drives straight: the ball of the foot stays put and the heel lifts just as far as a nearly straight leg needs
	var all_rise := rising.size() == anchors.size() and not rising.is_empty()
	for side in rising:
		var r := clampf(out["rise_" + side], 0.0, 1.0)
		var a: Vector2 = anchors[side]
		var ball := a + Vector2(FOOT_LENGTH, 0)
		if all_rise:
			var tilt := deg_to_rad(90.0 * r)
			anchors[side] = Vector2(a.x + FOOT_LENGTH * (1.0 - cos(tilt)), a.y - FOOT_LENGTH * sin(tilt))
			out["hip_y"] -= FOOT_LENGTH * sin(tilt) / rising.size()
			continue
		var joint: Vector2 = _end("hip", out)[0]
		var reach: float = (BONES["leg_%s_upper" % side][3] + BONES["leg_%s_lower" % side][3]) * 0.97
		var to_hip := joint - ball
		var d := to_hip.length()
		var lifted := a  # close enough to the hips to stand flat
		if d >= reach + FOOT_LENGTH:
			lifted = ball - Vector2(0, FOOT_LENGTH)  # too far even on the toes: up on them, the hips sink below
		elif d > reach - FOOT_LENGTH:
			# the ankle sits a foot's length from the ball and a straight leg's length from the hip: where they meet
			var along: float = (d * d + FOOT_LENGTH * FOOT_LENGTH - reach * reach) / (2.0 * d)
			var off := sqrt(maxf(0.0, FOOT_LENGTH * FOOT_LENGTH - along * along))
			var dir := to_hip / d
			var c1: Vector2 = ball + dir * along + Vector2(-dir.y, dir.x) * off
			var c2: Vector2 = ball + dir * along - Vector2(-dir.y, dir.x) * off
			lifted = c1 if c1.y < c2.y else c2
			if lifted.y > a.y:
				lifted = a
		anchors[side] = a.lerp(lifted, r)
	# a leg too short for the shift: sink the hips just enough for it to reach (a fighter drops his weight)
	for side in anchors:
		var hip_end: Array = _end("hip", out)
		var joint: Vector2 = hip_end[0] + (BONES["leg_%s_upper" % side][1] as Vector2).rotated(hip_end[1])
		var span: float = BONES["leg_%s_upper" % side][3] + BONES["leg_%s_lower" % side][3] - 1.0
		var to: Vector2 = anchors[side] - joint
		if to.length() > span and absf(to.x) < span:
			out["hip_y"] += to.y - sqrt(span * span - to.x * to.x)
	for side in anchors:
		_reach_with_leg(out, side, anchors[side])
		_settle_foot(out, side, grounded)
	# the street stops a swinging foot: a kick leaving or coming back to the ground skims it, never goes through it
	for side in ["f", "b"]:
		if anchors.has(side):
			continue
		_settle_foot(out, side, grounded)
		var low := maxf((_end("toe_" + side, out)[0] as Vector2).y, (_end("leg_%s_lower" % side, out)[0] as Vector2).y)
		if low > 0.0:
			_reach_with_leg(out, side, (_end("leg_%s_lower" % side, out)[0] as Vector2) - Vector2(0, low))
			_settle_foot(out, side, grounded)
	_cover(out, pose)
	return out


## The front fist guards a little further out, but tucks in to the cheek while the rear hand is out striking.
static func _cheek(side: String, pose: Dictionary) -> Vector2:
	return CHEEK if side == "b" else CHEEK.lerp(CHEEK_FRONT, clampf(pose.get("cover_b", 1.0), 0.0, 1.0))


## Brings a covering fist to the cheek (CHEEK from the middle of the head), the elbow kept down: a two-bone solve for
## the arm, blended with the written arm by how much the hand covers. Runs last, once the head has found its place.
static func _cover(out: Dictionary, pose: Dictionary) -> void:
	for side in ["f", "b"]:
		var c: float = pose.get("cover_" + side, 0.0)
		if c <= 0.0:
			continue
		var upper: String = "arm_%s_upper" % side
		var lower: String = "arm_%s_lower" % side
		var hand: String = "hand_" + side
		var head: Array = _end("head", out)
		var cheek: Vector2 = head[0] - Vector2(BONES["head"][3] * 0.5, 0).rotated(head[1]) + _cheek(side, pose)
		var root: Array = _end("shoulder_" + side, out)
		var l1: float = BONES[upper][3]
		var l2: float = BONES[lower][3]
		# the wrist sits half a fist below the knuckles' middle, the fist pointing up
		var to: Vector2 = cheek + Vector2(0, BONES[hand][3] * 0.5) - root[0]
		var d := clampf(to.length(), absf(l1 - l2) + 0.5, l1 + l2 - 0.5)
		var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
		var arm := to.angle() + acos(cos_a)  # the elbow below the line from shoulder to fist: elbow down
		var elbow: Vector2 = root[0] + Vector2(l1, 0).rotated(arm)
		var fore := (cheek + Vector2(0, BONES[hand][3] * 0.5) - elbow).angle()
		out[upper] = lerpf(out[upper], rad_to_deg(arm - root[1]) - BONES[upper][2], c)
		out[lower] = lerpf(out[lower], rad_to_deg(fore - arm) - BONES[lower][2], c)
		out[hand] = lerpf(out[hand], rad_to_deg(-PI / 2.0 - fore) - BONES[hand][2], c)


static func _planted(out: Dictionary, side: String) -> bool:
	return -(_end("leg_%s_lower" % side, out)[0] as Vector2).y <= FOOT_LENGTH + TOE_LENGTH


## Bends a leg so its ankle lands on target (two bones, the knee pointing forward, as knees do).
static func _reach_with_leg(out: Dictionary, side: String, target: Vector2) -> void:
	var upper := "leg_%s_upper" % side
	var lower := "leg_%s_lower" % side
	var hip_end: Array = _end("hip", out)
	var joint: Vector2 = hip_end[0] + (BONES[upper][1] as Vector2).rotated(hip_end[1])
	var l1: float = BONES[upper][3]
	var l2: float = BONES[lower][3]
	var to := target - joint
	var d := clampf(to.length(), absf(l1 - l2) + 0.5, l1 + l2 - 0.5)
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var thigh := to.angle() - acos(cos_a)  # the smaller angle: the knee forward
	var knee := joint + Vector2(l1, 0).rotated(thigh)
	var shin := (target - knee).angle()
	out[upper] = rad_to_deg(thigh - hip_end[1]) - BONES[upper][2]
	out[lower] = rad_to_deg(shin - thigh) - BONES[lower][2]


## A planted foot keeps the ball of the foot and the toes on the street: the heel rises exactly as far as the leg
## lifts the ankle. An ankle higher than the foot is long, or a fighter in the air, lets the foot point.
static func _settle_foot(out: Dictionary, side: String, grounded: bool) -> void:
	var shin: Array = _end("leg_%s_lower" % side, out)
	var ankle: Vector2 = shin[0]
	var shin_deg: float = rad_to_deg(shin[1])
	var foot := "foot_" + side
	var toe := "toe_" + side
	var height := -ankle.y
	if grounded and height <= FOOT_LENGTH:
		var tilt := rad_to_deg(asin(clampf(height / FOOT_LENGTH, 0.0, 1.0)))
		out[foot] = tilt - shin_deg - BONES[foot][2]  # world angle 0 = flat, pointing forward
		out[toe] = -tilt  # the toes stay flat on the street
	elif grounded and height <= FOOT_LENGTH + TOE_LENGTH:
		# pushing off: the foot stands up on the tips of its toes
		out[foot] = 90.0 - shin_deg - BONES[foot][2]
		out[toe] = rad_to_deg(asin(clampf((height - FOOT_LENGTH) / TOE_LENGTH, 0.0, 1.0))) - 90.0
	else:
		out[foot] = 30.0  # pointed
		out[toe] = 10.0


## The far end of a bone and its world angle (radians), for baked angles. Screen axes: +x forward, +y down.
static func _end(bone: String, baked: Dictionary) -> Array:
	var chain: Array[String] = []
	var b := bone
	while b != "":
		chain.push_front(b)
		b = BONES[b][0]
	var pos := Vector2(baked.get("hip_x", 0.0), baked.get("hip_y", 0.0))
	var ang := 0.0
	var stretch := 1.0  # the parent bone's drawn length, as a share of its real one
	for name in chain:
		var spec: Array = BONES[name]
		pos += (spec[1] as Vector2).rotated(ang) * stretch
		ang += deg_to_rad(spec[2] + baked.get(name, 0.0))
		stretch = drawn_length(name, baked)
	return [pos + Vector2(BONES[bone][3] * stretch, 0).rotated(ang), ang]


## How long a bone draws, as a share of its length: a forearm pointing at the camera ("fore_") looks shorter.
static func drawn_length(bone: String, baked: Dictionary) -> float:
	if bone in ["arm_f_lower", "arm_b_lower"]:
		return 1.0 - (1.0 - FORE_SHORT) * clampf(baked.get("fore_" + bone.substr(4, 1), 0.0), 0.0, 1.0)
	return 1.0


## Where a bone's far end sits, relative to the feet, for a pose, facing right (for tests and hit checks).
static func tip(bone: String, pose: Dictionary, grounded := true) -> Vector2:
	return _end(bone, bake(pose, grounded))[0]
