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
##   without "feet", "step_f" / "step_b" slide a planted foot along the street (a front-leg kick steps the back foot
##   up under the hips first, so he stands tall on it);
## - "fore_f" / "fore_b" (0 to 1) point that forearm at the camera: it draws shorter (down to FORE_SHORT of its length),
##   as a hook's forearm does coming across the body; "upper_f" / "upper_b" do the same for the upper arm (an elbow
##   out to the side, as on a hook's load). Hits are measured on the same shortened arm.
## - "tall" (0 to 1) on one leg, how far he rises onto it: 0 keeps the stance's bend (a front kick's standing knee,
##   about 40 degrees as recorded), 1 stands on a straight leg (a round kick or side kick, recorded within 8 degrees);
##   below 0 he sinks onto it (-1: a deep squat on the one leg, as a sweep spins low);
## - "tumble" (degrees) turns the whole drawing round in the picture's plane, around the hips, the way a roll goes
##   (hero_view.gd: the lowest drawn point stays on the street, so he rolls along it);
## - "land_spread" (0 or 1) falling to the street, the feet spread into the guard stance before they touch (a flying
##   kick lands staggered) instead of reaching together (a two-footed jump, as recorded);
## - "knees_out" (0 to 1) the back knee points back instead of forward: a horse stance, whose knees point out over
##   their own feet, seen from the front (the power punch's load). On the way the knee turns through pointing at the
##   camera, where the leg shows straight

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
	"spin", "turn", "pivot_f", "pivot_b", "fore_f", "fore_b", "feet", "step_f", "step_b", "lift_f", "lift_b", "spin_upper", "turn_upper", "upper_f", "upper_b", "spin_head", "relaxed", "tall", "tumble", "land_spread", "knees_out"]
## Keys that switch something on rather than bend it: a follow-through never carries them further.
const SWITCH_KEYS := ["open_f", "open_b", "cover_f", "cover_b", "rise_f", "rise_b", "spin", "turn", "pivot_f", "pivot_b",
	"fore_f", "fore_b", "feet", "step_f", "step_b", "lift_f", "lift_b", "spin_upper", "turn_upper", "upper_f", "upper_b",
	"spin_head", "relaxed", "tall", "tumble", "land_spread", "knees_out"]

## The whip (D-21): in a strike the hips move first and the fist or foot arrives last. Each key is read this many
## ticks ahead on the move's curve, so the hips lead, the spine follows, then the shoulder and the upper limb; the
## forearm, hand, shin and foot keep the move's own timing (so the blow still lands when the logic says it does).
## The head trails a tick behind.
const LEAD := {"hip_x": 3, "hip_turn": 3, "hip_y": 3, "spin": 3, "turn": 3, "pivot_f": 3, "pivot_b": 3, "torso": 2, "arm_f_upper": 1, "arm_b_upper": 1,
	"leg_f_upper": 1, "leg_b_upper": 1, "head": -1}
## Moves whose body may run at most this many frames ahead. The power punch loads low and wide and then drives all at
## once (the testers' joint session, 2026-11-02 20:30: no loading crouch showed 100 to 50 ms before contact, because
## the hips, three frames ahead, were already driving out of it).
const LEAD_CAP := {"power_punch": 2, "sweep": 1}
## Moves whose shoulders trail the hips by this many frames more than the move's own clock, so the waist is seen
## rolling through (the testers' joint session: on the round kick the waist and chest both froze at the hit). At the
## hit the hips are over while the chest is still coming round; it keeps turning through the next 50 ms.
const SHOULDER_LAG := {"roundhouse": 3}
## Moves whose held load ends this many frames before the blow (2 by default). The power punch holds its wide load to
## 50 ms before contact, as the testers asked, then drives all at once, the body two frames ahead of the fist.
const LOAD_END := {"power_punch": 1}
const FOOT_LENGTH := 24.0  # ankle to the ball of the foot
const SQUAT_LEG := 72.0  # hip to ankle in a deep squat on one leg ("tall" -1)
const KNEE_CLEAR := 15.0  # a swinging knee stays at least this far above the street
const KNEE_STAND := 14.0  # a standing knee stays at least this far above its ankle (no kneeling)
## His shoulder width, outside to outside. The game draws him from the side, where it never shows, so it comes from
## real bodies: in CMU's recordings (subjects 16 and 135) the shoulder joints sit 0.43 to 0.44 of a leg (thigh + shin)
## apart, 53 px on his 120 px legs, plus an arm's thickness (18 px) for the outside of the shoulders. What a stance's
## width is measured against (the testers, 00:57 on 66ce4c6: "feet apart vs shoulder width at the loading frame").
const SHOULDER_WIDTH := 71.0
const TOE_LENGTH := 11.0  # an ankle higher than foot + toes lets the foot point

## The guard, the fighter's home stance (Javier, 2026-11-02 morning: "posture and movements ... still terrible"; the
## assistant team: the stance first): feet wider than the shoulders, front foot 44 px ahead of the hips and the back
## foot 63 px behind, the front knee well bent and the back leg nearly straight, hips dropped (the legs solved for
## ankles 100 px under the hips; with the back foot only 50 px back its knee folded and any dip read as kneeling), weight
## between the feet, a slight lean in, chin down, both fists up at cheekbone height with the elbows in (cover_f,
## cover_b; the front fist a forearm ahead of the rear one), the back foot turned out 45 degrees with its heel slightly
## up, shoulders loose (the assistant team's posture sheet, 2026-11-02). Any move that uses an arm switches its cover off for itself.
const GUARD := {
	"torso": 10.0, "neck": 14.0, "head": 6.0, "hand_f": -15.0, "hand_b": -15.0,
	"arm_f_upper": -62.0, "arm_f_lower": -114.0, "arm_b_upper": -25.0, "arm_b_lower": -100.0,
	"leg_f_upper": -47.3, "leg_f_lower": 48.9, "leg_b_upper": 22.6, "leg_b_lower": 19.9, "hip_y": 0.0,
	"open_f": 0.0, "open_b": 0.0, "hip_x": 0.0, "hip_turn": 0.0, "cover_f": 1.0, "cover_b": 1.0, "rise_f": 0.0,
	"rise_b": 0.15, "spin": 0.0, "turn": 0.0, "pivot_f": 0.0, "pivot_b": 45.0, "fore_f": 0.0, "fore_b": 0.0,
	"feet": 0.0, "step_f": 0.0, "step_b": 0.0, "lift_f": 0.0, "lift_b": 0.0, "spin_upper": 0.0, "turn_upper": 0.0, "upper_f": 0.0, "upper_b": 0.0, "spin_head": 0.0, "relaxed": 0.0, "tall": 0.0, "tumble": 0.0, "land_spread": 0.0, "knees_out": 0.0,
}
const HEAD_LEAD := 6  # on a spin the head looks round first: it reads the spin this many frames ahead
## Where the ankles stand in the guard, from the hip joint: the guard's legs are solved for these spots.
const STANCE := {"f": Vector2(44.0, 100.0), "b": Vector2(-63.0, 100.0)}
## Where they stand in the walk stance ("relaxed" 1, feet mode): close together under the hips, legs nearly straight
## (Javier, 2026-11-02 18:48: the hero walks and runs, X switches between the fight stance and the walk stance).
const RELAXED := {"f": Vector2(12.0, 118.0), "b": Vector2(-10.0, 118.0)}
## The everyday walk: each foot planted most of the cycle, the legs passing each other, the arms swinging against them.
const STROLL_CYCLE := 58  # a brisk walk, about 1 s a cycle and a stride of 1.45 legs (CMU 16_15: 1.11 s, 1.47 legs)
const STROLL_STEP := 24
## The run: knees high, arms bent and pumping, a lean forward, and a moment with both feet off the street.
const RUN_CYCLE := 36  # a stride every 0.6 s, 2.4 legs long (CMU 16_08 at a jog); at 0.4 s it was quick little steps
const RUN_STEP := 27  # each foot on the street a quarter of the cycle: the rest is swing, with a flight between steps
## The walk is a fighter's shuffle, not a stroll (Javier, 2026-11-02 morning): the front foot steps out, the back foot
## follows, the feet never pass each other and the stance never breaks. A cycle of WALK_CYCLE ticks; each foot spends
## WALK_STEP of them in the air and the rest planted, sliding back under the body at exactly the walking speed, so a
## planted foot stays put on the street.
const WALK_CYCLE := 20
const WALK_EASE_IN := 4  # the first steps ease out of the guard
const WALK_STEP := 8
const FORE_SHORT := 0.4  # a forearm pointing straight at the camera draws at 40% of its length
## How far into its start-up a strike is cocked (the wind-up moment). Most cock late (0.7), so the blow reads as a
## snap; the swinging ones cock early, so the swing round to the target lasts long enough to be seen.
const WINDUP_AT := {"hook": 0.4, "roundhouse": 0.45, "spin_kick": 0.6, "knee": 0.34, "side_kick": 0.55, "power_punch": 0.4, "body_kick": 0.5, "front_kick": 0.5, "sweep": 0.35}
## Where a covering fist sits: from the middle of the head, forward and a little down, in front of the jaw. Far enough
## forward to show past the face: the far hand is drawn behind the head, and at (16, 16) it hid there, so all one saw
## of it was its forearm across the chest (the assistant team's third review, 2026-11-02).
const CHEEK := Vector2(30.0, 14.0)
const CHEEK_FRONT := Vector2(62.0, 14.0)  # the front fist in the guard: at cheekbone height, a forearm ahead (the sheet)

## The walk stance standing (also the base of the everyday walk), and the base of the run.
const STAND := {"feet": 1.0, "relaxed": 1.0, "cover_f": 0.0, "cover_b": 0.0, "pivot_b": 0.0, "rise_b": 0.0,
	"arm_f_upper": -8.0, "arm_f_lower": -15.0, "arm_b_upper": 8.0, "arm_b_lower": -15.0, "torso": 2.0, "neck": 0.0, "head": 0.0}
const RUN := {"feet": 1.0, "relaxed": 1.0, "cover_f": 0.0, "cover_b": 0.0, "pivot_b": 0.0, "rise_b": 0.0,
	"arm_f_lower": -95.0, "arm_b_lower": -95.0, "torso": 18.0, "neck": 4.0, "head": 2.0}

## Lying on his back on the street (knocked down, out): the whole drawing turned back a quarter, the body long, the
## knees a little up, the arms lying along his sides (arms flung back would prop him up off the street).
const LYING := {"tumble": -88.0, "torso": 0.0, "neck": 0.0, "head": -6.0, "cover_f": 0.0, "cover_b": 0.0, "hip_y": 0.0,
	"arm_f_upper": -25.0, "arm_f_lower": -10.0, "arm_b_upper": -8.0, "arm_b_lower": -10.0,
	"leg_f_upper": -30.0, "leg_f_lower": 50.0, "leg_b_upper": -5.0, "leg_b_lower": 10.0, "pivot_b": 0.0, "rise_b": 0.0}
## The states where he lies, falls or rises: the drawing is placed by its outline (no planted feet).
const OFF_FEET := ["knockdown", "down", "ko", "get_up", "launch", "tumble"]

## Looping states: [loop length in ticks, [tick, changes from GUARD], ...]
const LOOPS := {
	# the guard is never dead still: the weight rocks gently from the back leg to the front and back, knees giving
	# (it starts and ends at the plain guard, which is where every move ends, so nothing jumps between them)
	"idle": [60, [0, {}], [15, {"hip_x": -6.0, "hip_turn": -2.0, "hip_y": 0.0, "torso": 9.0, "head": 9.0}],
		[45, {"hip_x": 6.0, "hip_turn": 2.0, "hip_y": 4.0, "torso": 12.0, "head": 7.0}]],
	# the walk stance, standing: upright and easy, feet close, legs nearly straight, arms hanging, chin level, breathing
	"stand": [90, [0, STAND], [45, {"feet": 1.0, "relaxed": 1.0, "cover_f": 0.0, "cover_b": 0.0, "pivot_b": 0.0, "rise_b": 0.0,
		"arm_f_upper": -6.0, "arm_f_lower": -18.0, "arm_b_upper": 10.0, "arm_b_lower": -18.0, "torso": 4.0, "neck": 0.0,
		"head": 0.0, "hip_y": 1.5}]],
	"stroll": [64, [0, STAND], [32, STAND]],
	"run": [24, [0, RUN], [12, RUN]],
	"walk": [20, [0, {"feet": 1.0, "hip_y": 2.0, "hip_turn": -3.0, "torso": 12.0}],
		[5, {"feet": 1.0, "hip_y": -2.0, "hip_turn": 0.0, "torso": 11.0}],
		[10, {"feet": 1.0, "hip_y": 2.0, "hip_turn": 3.0, "torso": 12.0}],
		[15, {"feet": 1.0, "hip_y": -2.0, "hip_turn": 0.0, "torso": 11.0}]],
	# dazed (D-19: two hero combos in a row): the guard gone, arms hanging, knees soft, the body swaying slowly round
	# and the head lolling, open for the finishing combo
	"dizzy": [56, [0, {"relaxed": 1.0, "feet": 1.0, "cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": 4.0, "arm_f_lower": -10.0, "arm_b_upper": 14.0, "arm_b_lower": -8.0, "torso": 14.0, "neck": 10.0, "head": 22.0, "hip_x": -10.0, "hip_y": 10.0}],
		[28, {"relaxed": 1.0, "feet": 1.0, "cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": -6.0, "arm_f_lower": -20.0, "arm_b_upper": 6.0, "arm_b_lower": -16.0, "torso": -6.0, "neck": -4.0, "head": -18.0, "hip_x": 10.0, "hip_y": 6.0}]],
}

## One-shot states, keyed by named moments the tuning decides (see moment()). A strike runs wind-up, hit, hold,
## follow-through, then eases back to the guard; an empty "follow" means "carry the hit a little further", a written
## one is the move's own (a jab snaps straight back, a push kick holds, a front kick folds back to its chamber).
const SHOTS := {
	"jump": [["start", {"cover_f": 0.0, "cover_b": 0.0, "torso": 8.0, "head": 14.0, "leg_f_upper": 4.0, "leg_f_lower": 26.0,
			"leg_b_upper": 8.0, "leg_b_lower": 24.0, "arm_f_upper": 38.0, "arm_f_lower": -78.0, "arm_b_upper": 42.0,
			"arm_b_lower": -76.0, "hip_y": 0.0}],
		["rise", {"cover_f": 0.0, "cover_b": 0.0, "torso": 6.0, "head": 18.0, "leg_f_upper": -6.0, "leg_f_lower": 42.0,
			"leg_b_upper": -2.0, "leg_b_lower": 38.0, "arm_f_upper": 46.0, "arm_f_lower": -88.0, "arm_b_upper": 50.0,
			"arm_b_lower": -86.0, "hip_y": 0.0}],
		["peak", {"cover_f": 0.0, "cover_b": 0.0, "torso": 6.0, "head": 20.0, "leg_f_upper": -14.0, "leg_f_lower": 40.0,
			"leg_b_upper": -10.0, "leg_b_lower": 34.0, "arm_f_upper": 46.0, "arm_f_lower": -76.0, "arm_b_upper": 46.0,
			"arm_b_lower": -78.0, "hip_y": 0.0}],
		["fall", {"cover_f": 0.0, "cover_b": 0.0, "torso": 6.0, "head": 20.0, "leg_f_upper": -22.0, "leg_f_lower": 22.0,
			"leg_b_upper": -18.0, "leg_b_lower": 22.0, "arm_f_upper": 38.0, "arm_f_lower": -58.0, "arm_b_upper": 36.0,
			"arm_b_lower": -56.0, "hip_y": 0.0}]],
	# the crouch before take-off (CMU 16_05, 200 ms before it leaves the ground): the hips drop, the knees bend, the
	# spine leans well forward, the arms swing back; then the legs drive him up
	"jump_squat": [["start", {}],
		["end", {"cover_f": 0.0, "cover_b": 0.0, "hip_y": 16.0, "torso": 40.0, "head": -22.0, "arm_f_upper": 32.0,
			"arm_f_lower": -60.0, "arm_b_upper": 36.0, "arm_b_lower": -62.0}]],
	# the touchdown itself: the arms still open from the air, coming in to the guard over the landing; the sink and
	# rise of the legs is landing(), timed from the touchdown and running on into the guard
	"land": [["start", {"cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": -60.0, "arm_f_lower": -90.0, "arm_b_upper": -30.0,
		"arm_b_lower": -80.0, "torso": 14.0}],
		["end", {}]],
	# the jab (posture sheet): a tiny wind-up, the front foot sliding an inch and nothing pulled back; the arm straight
	# out at shoulder height, almost no hip; then it snaps straight back along the same line
	"punch": [["start", {}],
		["windup", {"step_f": 8.0, "hip_x": 1.0, "hip_turn": 1.0, "torso": 10.0}],
		["active", {"step_f": 8.0, "cover_f": 0.0, "hip_x": 3.0, "hip_turn": 3.0, "arm_f_upper": -98.0, "arm_f_lower": 0.0, "torso": 6.0, "head": 4.0}],
		["active_end", {"step_f": 8.0, "cover_f": 0.0, "hip_x": 3.0, "hip_turn": 3.0, "arm_f_upper": -98.0, "arm_f_lower": 0.0, "torso": 6.0, "head": 4.0}],
		["follow", {"step_f": 4.0, "hip_x": 1.0, "torso": 9.0}],
		["end", {}]],
	# the flying kick: a flying side kick (Javier, 2026-11-02 21:21: "has to look like a flying kick, not like a karate
	# kid movie kick"). Off the jump the knee chambers to the side with both legs drawn up; at the hit the body is
	# side-on and leans back away from the target, the kicking leg driven out straight, heel first, the other leg tucked
	# tight under him, the lead fist guarding and the rear arm back. Then ("Wushu Basics", Commons, CC BY-SA 3.0) the
	# legs fold up, the body comes round, the arms go out wide for balance, and the knees stay tucked until the legs
	# reach for the street (landing())
	"air_kick": [["start", {"turn": 55.0, "torso": -14.0, "head": 10.0, "hip_turn": -10.0, "hip_y": 0.0,
			"leg_f_upper": -78.0, "leg_f_lower": 125.0, "leg_b_upper": -45.0, "leg_b_lower": 130.0,
			"cover_b": 0.0, "arm_b_upper": 40.0, "arm_b_lower": -70.0}],
		["startup", {"turn": 85.0, "torso": -22.0, "head": 12.0, "hip_turn": -10.0, "hip_y": 0.0,
			"leg_f_upper": -104.0, "leg_f_lower": 0.0, "leg_b_upper": -88.0, "leg_b_lower": 150.0,
			"cover_b": 0.0, "arm_b_upper": 70.0, "arm_b_lower": -30.0}],
		["active_end", {"turn": 85.0, "torso": -22.0, "head": 12.0, "hip_turn": -10.0, "hip_y": 0.0,
			"leg_f_upper": -104.0, "leg_f_lower": 0.0, "leg_b_upper": -88.0, "leg_b_lower": 150.0,
			"cover_b": 0.0, "arm_b_upper": 70.0, "arm_b_lower": -30.0}],
		["recoil", {"land_spread": 1.0, "turn": 35.0, "torso": -10.0, "head": 10.0, "hip_turn": -8.0, "hip_y": 0.0,
			"leg_f_upper": -75.0, "leg_f_lower": 115.0, "leg_b_upper": -45.0, "leg_b_lower": 120.0,
			"cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": -75.0, "arm_f_lower": -15.0, "arm_b_upper": 80.0, "arm_b_lower": -15.0}],
		["tuck", {"land_spread": 1.0, "turn": 0.0, "torso": 0.0, "head": 6.0, "hip_turn": 0.0, "hip_y": 0.0,
			"leg_f_upper": -60.0, "leg_f_lower": 90.0, "leg_b_upper": -40.0, "leg_b_lower": 95.0,
			"cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": -70.0, "arm_f_lower": -15.0, "arm_b_upper": 75.0, "arm_b_lower": -15.0}]],
	# Z: the back sweep (the posture sheet; no recorded sweep exists in the libraries we use): sink low into the bow
	# stance with the hands going down; spin on the front foot, the back leg straight and low along the street, the
	# hands on or near the floor; the leg comes round to the ankles in front; finish the circle; rise to guard. The leg
	# stays straight out behind him while the whole body turns once, so the foot goes all the way round (the testers,
	# 00:57 on 66ce4c6: seen from above it cut through the middle and covered only part of the circle); it passes the
	# enemy's ankles halfway round, his back to the enemy, the way a back sweep does
	"sweep": [["start", {}],
		["windup", {"tall": -1.0, "hip_y": 32.0, "step_b": -75.0, "step_f": 8.0, "torso": 26.0, "head": -8.0, "cover_f": 0.0, "cover_b": 0.0, "open_f": 1.0, "open_b": 1.0,
			"arm_f_upper": 30.0, "arm_f_lower": -20.0, "arm_b_upper": 20.0, "arm_b_lower": -20.0, "leg_b_upper": 68.0, "leg_b_lower": 0.0}],
		["sweep", {"spin": 120.0, "pivot_f": 120.0, "tall": -1.0, "hip_y": 38.0, "torso": 34.0, "head": -10.0, "cover_f": 0.0, "cover_b": 0.0, "open_f": 1.0, "open_b": 1.0,
			"arm_f_upper": 20.0, "arm_f_lower": -10.0, "arm_b_upper": 10.0, "arm_b_lower": -10.0, "leg_b_upper": 68.0, "leg_b_lower": 0.0}],
		["active", {"spin": 180.0, "pivot_f": 180.0, "tall": -1.0, "hip_y": 38.0, "torso": 28.0, "head": -6.0, "cover_f": 0.0, "cover_b": 0.0, "open_f": 1.0, "open_b": 1.0,
			"arm_f_upper": 20.0, "arm_f_lower": -10.0, "arm_b_upper": 10.0, "arm_b_lower": -10.0, "leg_b_upper": 68.0, "leg_b_lower": 0.0}],
		["active_end", {"spin": 260.0, "pivot_f": 260.0, "tall": -1.0, "hip_y": 38.0, "torso": 24.0, "head": -4.0, "cover_f": 0.0, "cover_b": 0.0, "open_f": 1.0, "open_b": 1.0,
			"arm_f_upper": 20.0, "arm_f_lower": -10.0, "arm_b_upper": 10.0, "arm_b_lower": -10.0, "leg_b_upper": 68.0, "leg_b_lower": 0.0}],
		["follow", {"spin": 360.0, "pivot_f": 360.0, "tall": -0.8, "hip_y": 30.0, "torso": 18.0, "cover_f": 0.0, "cover_b": 0.0,
			"arm_f_upper": 30.0, "arm_f_lower": -40.0, "arm_b_upper": 20.0, "arm_b_lower": -40.0, "leg_b_upper": 66.0, "leg_b_lower": 6.0}],
		["end", {"spin": 360.0, "pivot_f": 360.0}]],
	# C: the evasion roll (Javier, 2026-11-02 21:56). No recorded roll yet (CMU 128_09 "Run Roll Underneath" waits on
	# Javier's yes to download); the team's roll reference (judo and aikido forward rolls, Muybridge's somersault plates):
	# dip side-on, chin tucked, the leading arm curved forward and down to guide; over the shoulder to the opposite hip
	# in a tight ball (knees to the chest), never over the head; come up facing the same way, back to guard
	"roll": [["start", {}],
		["roll_down", {"turn": 50.0, "hip_y": 40.0, "torso": 75.0, "head": 120.0, "cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": -85.0, "arm_f_lower": -20.0, "arm_b_upper": -75.0, "arm_b_lower": -20.0, "tumble": 0.0}],
		["roll_over", {"turn": 40.0, "torso": 115.0, "head": 120.0, "cover_f": 0.0, "cover_b": 0.0, "leg_f_upper": -105.0, "leg_f_lower": 140.0, "leg_b_upper": -105.0, "leg_b_lower": 140.0, "arm_f_upper": -110.0, "arm_f_lower": -20.0, "arm_b_upper": -40.0, "arm_b_lower": -110.0, "tumble": 180.0}],
		["roll_up", {"turn": 15.0, "hip_y": 28.0, "torso": 26.0, "head": 10.0, "cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": -30.0, "arm_f_lower": -70.0, "arm_b_upper": -20.0, "arm_b_lower": -70.0, "tumble": 340.0}],
		["end", {"tumble": 360.0}]],
	"climb": [["start", {"cover_f": 0.0, "cover_b": 0.0, "open_f": 1.0, "open_b": 1.0, "hand_f": -30.0, "hand_b": -30.0, "arm_f_upper": -165.0, "arm_f_lower": 0.0, "arm_b_upper": -150.0, "arm_b_lower": 0.0,
			"leg_f_upper": -20.0, "leg_f_lower": 30.0, "hip_y": 0.0}],
		["climb_mid", {"cover_f": 0.0, "cover_b": 0.0, "open_f": 1.0, "open_b": 1.0, "hand_f": 60.0, "hand_b": 60.0, "arm_f_upper": -60.0, "arm_f_lower": -30.0, "arm_b_upper": -40.0, "arm_b_lower": -30.0,
			"torso": 35.0, "leg_f_upper": -95.0, "leg_f_lower": 100.0, "leg_b_upper": 20.0, "leg_b_lower": 40.0, "hip_y": 10.0}],
		["end", {}]],
	# the cross (posture sheet): the back heel lifts and the hips begin to turn while the arm is still home; at the hit
	# the back foot has pivoted on its ball, hips and shoulders square, the front leg a firm post (the hips rise onto it),
	# about 60% of the weight forward, the front fist back by the cheek
	"cross": [["start", {}],
		["windup", {"rise_b": 0.4, "turn": 15.0, "hip_x": 4.0, "hip_turn": 4.0, "torso": 10.0}],
		["active", {"rise_b": 0.6, "pivot_b": 70.0, "cover_b": 0.0, "cover_f": 1.0, "turn": 50.0, "hip_x": 12.0, "hip_y": -12.0, "hip_turn": 16.0, "arm_b_upper": -108.0, "arm_b_lower": 0.0, "torso": 22.0, "head": -4.0}],
		["active_end", {"rise_b": 0.6, "pivot_b": 70.0, "cover_b": 0.0, "cover_f": 1.0, "turn": 50.0, "hip_x": 12.0, "hip_y": -12.0, "hip_turn": 16.0, "arm_b_upper": -108.0, "arm_b_lower": 0.0, "torso": 22.0, "head": -4.0}],
		["follow", {}],
		["end", {}]],
	# the hook (posture sheet; the testers' joint review): a compact load, the elbow out to the side at shoulder height
	# (the upper arm drawn short, pointing at us) with the fist level beside it; the elbow comes round forward, still
	# level, the waist leading; at the hit the arm is a level hoop and the front foot has pivoted
	"hook": [["start", {"cover_f": 0.0}],
		["windup", {"upper_f": 0.85, "cover_f": 0.0, "fore_f": 0.9, "turn": -20.0, "hip_x": 2.0, "hip_y": 5.0, "hip_turn": -10.0, "arm_f_upper": -100.0, "arm_f_lower": 26.0, "torso": -10.0, "head": 6.0}],
		["sweep", {"upper_f": 0.45, "cover_f": 0.0, "fore_f": 0.9, "turn": 20.0, "hip_x": 2.0, "hip_turn": 4.0, "arm_f_upper": -114.0, "arm_f_lower": 18.0, "torso": 12.0, "head": -6.0}],
		["active", {"cover_f": 0.0, "pivot_f": 80.0, "rise_f": 0.3, "fore_f": 0.6, "turn": 60.0, "hip_x": 6.0, "hip_turn": 24.0, "arm_f_upper": -120.0, "arm_f_lower": -10.0, "torso": 30.0, "head": -14.0}],
		["active_end", {"cover_f": 0.0, "pivot_f": 80.0, "rise_f": 0.3, "fore_f": 0.6, "turn": 60.0, "hip_x": 6.0, "hip_turn": 24.0, "arm_f_upper": -120.0, "arm_f_lower": -10.0, "torso": 30.0, "head": -14.0}],
		["follow", {"cover_f": 0.0, "pivot_f": 80.0, "rise_f": 0.3, "fore_f": 0.6, "turn": 64.0, "hip_x": 6.0, "hip_turn": 24.0, "arm_f_upper": -120.0, "arm_f_lower": -10.0, "torso": 30.0, "head": -14.0}],
		["end", {}]],
	"uppercut": [["start", {}],
		["windup", {"cover_b": 0.0, "cover_f": 1.0, "hip_x": -6.0, "hip_turn": 6.0, "arm_b_upper": 10.0, "arm_b_lower": -100.0, "torso": 14.0, "hip_y": 14.0}],
		["active", {"turn": 25.0, "rise_b": 0.6, "cover_b": 0.0, "cover_f": 1.0, "hip_x": 8.0, "hip_turn": -8.0, "arm_b_upper": -68.0, "arm_b_lower": -102.0, "torso": 6.0, "head": 4.0, "hip_y": -4.0}],
		["active_end", {"turn": 25.0, "rise_b": 0.6, "cover_b": 0.0, "cover_f": 1.0, "hip_x": 8.0, "hip_turn": -8.0, "arm_b_upper": -68.0, "arm_b_lower": -102.0, "torso": 6.0, "head": 4.0, "hip_y": -4.0}],
		["follow", {}],
		["end", {}]],
	# the knee (posture sheet; the testers' joint review): reach out with both hands open, close them on a grab, then
	# the knee drives up, the hips push forward and the hands pull the enemy down onto it; the knee stays up while the
	# pull finishes, and only then lowers
	"knee": [["start", {}],
		["windup", {"step_b": 30.0, "cover_f": 0.0, "cover_b": 0.0, "open_f": 1.0, "open_b": 1.0, "hip_x": -4.0, "leg_f_upper": -30.0, "leg_f_lower": 40.0, "arm_f_upper": -125.0, "arm_f_lower": -5.0, "arm_b_upper": -115.0, "arm_b_lower": -5.0, "torso": 12.0}],
		["sweep", {"step_b": 45.0, "cover_f": 0.0, "cover_b": 0.0, "open_f": 0.0, "open_b": 0.0, "hip_x": 0.0, "leg_f_upper": -70.0, "leg_f_lower": 95.0, "arm_f_upper": -112.0, "arm_f_lower": -35.0, "arm_b_upper": -104.0, "arm_b_lower": -35.0, "torso": 14.0}],
		["active", {"step_b": 50.0, "cover_f": 0.0, "cover_b": 0.0, "open_f": 0.0, "open_b": 0.0, "hip_x": 12.0, "hip_turn": -6.0, "leg_f_upper": -100.0, "leg_f_lower": 120.0, "torso": 18.0, "arm_f_upper": -45.0, "arm_f_lower": -40.0, "arm_b_upper": -40.0, "arm_b_lower": -40.0, "hip_y": 0.0}],
		["active_end", {"step_b": 50.0, "cover_f": 0.0, "cover_b": 0.0, "open_f": 0.0, "open_b": 0.0, "hip_x": 12.0, "hip_turn": -6.0, "leg_f_upper": -100.0, "leg_f_lower": 120.0, "torso": 18.0, "arm_f_upper": -45.0, "arm_f_lower": -40.0, "arm_b_upper": -40.0, "arm_b_lower": -40.0, "hip_y": 0.0}],
		["follow", {"step_b": 50.0, "cover_f": 0.0, "cover_b": 0.0, "open_f": 0.0, "open_b": 0.0, "hip_x": 10.0, "hip_turn": -6.0, "leg_f_upper": -96.0, "leg_f_lower": 118.0, "torso": 22.0, "arm_f_upper": -20.0, "arm_f_lower": -50.0, "arm_b_upper": -15.0, "arm_b_lower": -50.0, "hip_y": 0.0}],
		["end", {}]],
	"push_kick": [["start", {}],
		["windup", {"hip_x": -45.0, "hip_turn": -4.0, "leg_f_upper": -112.0, "leg_f_lower": 118.0, "torso": -4.0, "hip_y": 0.0}],
		["active", {"hip_x": 0.0, "hip_turn": -14.0, "leg_f_upper": -98.0, "leg_f_lower": -2.0, "torso": -16.0, "head": 12.0, "hip_y": 0.0}],
		["active_end", {"hip_x": 0.0, "hip_turn": -14.0, "leg_f_upper": -98.0, "leg_f_lower": -2.0, "torso": -16.0, "head": 12.0, "hip_y": 0.0}],
		["follow", {"hip_x": 8.0, "hip_turn": -14.0, "leg_f_upper": -98.0, "leg_f_lower": -2.0, "torso": -16.0, "head": 12.0, "hip_y": 0.0}],
		["end", {}]],
	# the body kick (K, K): a rear-leg snap kick to the body, as the posture sheet's front kick: the knee straight up
	# to hip height, the foot hanging under it; the hips push and the lower leg flicks out, leaning back a touch; then
	# it snaps back to the chamber. (A push kick is the P, P, K finisher; this one doesn't shove.)
	"body_kick": [["start", {}],
		["windup", {"step_f": -14.0, "hip_x": 6.0, "hip_turn": -4.0, "leg_b_upper": -90.0, "leg_b_lower": 90.0, "torso": -4.0, "hip_y": 0.0}],
		["load", {"step_f": -14.0, "hip_x": 6.0, "hip_turn": -4.0, "leg_b_upper": -90.0, "leg_b_lower": 90.0, "torso": -4.0, "hip_y": 0.0}],
		["active", {"step_f": -22.0, "hip_x": 34.0, "hip_turn": -12.0, "leg_b_upper": -132.0, "leg_b_lower": 50.0, "torso": 14.0, "head": 2.0, "hip_y": 0.0}],
		["active_end", {"step_f": -22.0, "hip_x": 34.0, "hip_turn": -12.0, "leg_b_upper": -132.0, "leg_b_lower": 50.0, "torso": 14.0, "head": 2.0, "hip_y": 0.0}],
		["follow", {"step_f": -18.0, "hip_x": 12.0, "hip_turn": -6.0, "leg_b_upper": -90.0, "leg_b_lower": 90.0, "torso": -6.0, "hip_y": 0.0}],
		["end", {}]],
	# (after the hit the leg folds back to a high chamber, knee up and shin tucked, before it lowers: the testers'
	# review of 0812a0e, a 12-degree bend on the way down didn't meet the posture sheet)
	"spin_kick": [["start", {}],
		["windup", {"step_b": 30.0, "spin": 170.0, "pivot_b": 170.0, "rise_b": 0.35, "hip_x": -4.0, "hip_turn": 14.0, "leg_f_upper": -95.0, "leg_f_lower": 120.0, "torso": 40.0, "head": -20.0, "hip_y": 6.0}],
		["sweep", {"step_b": 40.0, "spin": 290.0, "pivot_b": 290.0, "rise_b": 0.35, "hip_x": -8.0, "hip_turn": -10.0, "leg_f_upper": -112.0, "leg_f_lower": 85.0, "torso": -10.0, "head": 8.0, "hip_y": 0.0}],
		["active", {"step_b": 40.0, "spin": 360.0, "pivot_b": 360.0, "rise_b": 0.35, "hip_x": -14.0, "hip_turn": -24.0, "leg_f_upper": -122.0, "leg_f_lower": 0.0, "torso": -46.0, "head": 26.0, "hip_y": 0.0}],
		["active_end", {"step_b": 40.0, "spin": 360.0, "pivot_b": 360.0, "rise_b": 0.35, "hip_x": -14.0, "hip_turn": -24.0, "leg_f_upper": -122.0, "leg_f_lower": 0.0, "torso": -46.0, "head": 26.0, "hip_y": 0.0}],
		["follow", {"step_b": 40.0, "spin": 360.0, "pivot_b": 360.0, "rise_b": 0.35, "hip_x": -14.0, "hip_turn": -24.0, "leg_f_upper": -112.0, "leg_f_lower": 125.0, "torso": -20.0, "head": 14.0, "hip_y": 0.0}],
		["end", {"spin": 360.0, "pivot_b": 360.0}]],
	# the elbow (posture sheet; the testers' joint review): the weight onto the front foot and a small turn away; then
	# the waist turns first and the elbow swings across raised to head height (the cheek: as high as it reaches from
	# the shoulder), the forearm folded back so the fist ends by his own ear
	"elbow": [["start", {}],
		["windup", {"cover_f": 0.0, "hip_x": 6.0, "hip_turn": -5.0, "turn": -15.0, "arm_f_upper": -60.0, "arm_f_lower": -150.0, "torso": 6.0}],
		# the forearm level at head height, folded straight back across the face (the testers' joint session, 2026-11-02:
		# it sloped up across the face from contact to 100 ms after); it holds level through the follow-through
		["active", {"cover_f": 0.0, "upper_f": 0.0, "fore_f": 0.4, "turn": 40.0, "hip_x": 12.0, "hip_turn": 10.0, "arm_f_upper": -158.0, "arm_f_lower": -136.0, "torso": 24.0, "head": -4.0}],
		["active_end", {"cover_f": 0.0, "upper_f": 0.0, "fore_f": 0.4, "turn": 40.0, "hip_x": 12.0, "hip_turn": 10.0, "arm_f_upper": -158.0, "arm_f_lower": -136.0, "torso": 24.0, "head": -4.0}],
		["follow", {"cover_f": 0.0, "upper_f": 0.0, "fore_f": 0.4, "turn": 44.0, "hip_x": 12.0, "hip_turn": 10.0, "arm_f_upper": -158.0, "arm_f_lower": -136.0, "torso": 24.0, "head": -4.0}],
		["end", {}]],
	# the round kick (posture sheet): the front foot steps slightly out and takes the weight; the standing foot pivots
	# until its heel points at the enemy, the hips turn right over and the bent leg sweeps across; the arm on the kicking
	# side swings down and back to balance, the other hand guards the face
	"roundhouse": [["start", {}],
		["windup", {"step_f": 10.0, "turn": 40.0, "pivot_f": 95.0, "rise_f": 0.2, "hip_x": 10.0, "hip_turn": -10.0, "leg_b_upper": -60.0, "leg_b_lower": 115.0, "torso": -10.0, "hip_y": 0.0, "cover_b": 0.5}],
		["sweep", {"tall": 0.6, "step_f": 10.0, "turn": 90.0, "pivot_f": 150.0, "rise_f": 0.25, "hip_x": 24.0, "hip_turn": -20.0, "leg_b_upper": -128.0, "leg_b_lower": 110.0, "torso": -8.0, "head": 14.0, "hip_y": 0.0, "cover_b": 0.0, "arm_b_upper": 20.0, "arm_b_lower": -30.0}],
		["active", {"tall": 1.0, "step_f": -50.0, "turn": 165.0, "pivot_f": 180.0, "rise_f": 0.23, "hip_x": 30.0, "hip_turn": -30.0, "leg_b_upper": -118.0, "leg_b_lower": 6.0, "torso": -8.0, "head": 16.0, "hip_y": 0.0, "cover_b": 0.0, "arm_b_upper": 45.0, "arm_b_lower": -15.0}],
		["active_end", {"tall": 1.0, "step_f": -50.0, "turn": 195.0, "pivot_f": 180.0, "rise_f": 0.23, "hip_x": 30.0, "hip_turn": -38.0, "leg_b_upper": -118.0, "leg_b_lower": 6.0, "torso": -8.0, "head": 16.0, "hip_y": 0.0, "cover_b": 0.0, "arm_b_upper": 45.0, "arm_b_lower": -15.0}],
		["follow", {"tall": 1.0, "step_f": -50.0, "turn": 195.0, "pivot_f": 180.0, "rise_f": 0.23, "hip_x": 30.0, "hip_turn": -38.0, "leg_b_upper": -96.0, "leg_b_lower": 112.0, "torso": -8.0, "head": 16.0, "hip_y": 0.0, "cover_b": 0.0, "arm_b_upper": 45.0, "arm_b_lower": -15.0}],
		["end", {}]],
	"hammer_fist": [["start", {"cover_f": 0.0, "open_f": 0.0, "arm_f_upper": -170.0, "arm_f_lower": -20.0, "leg_f_upper": -60.0, "leg_f_lower": 95.0,
			"leg_b_upper": -20.0, "leg_b_lower": 105.0, "hip_y": 0.0}],
		["startup", {"cover_f": 0.0, "arm_f_upper": -55.0, "arm_f_lower": -10.0, "torso": 24.0, "head": -10.0, "leg_f_upper": -60.0,
			"leg_f_lower": 95.0, "leg_b_upper": -20.0, "leg_b_lower": 105.0, "hip_y": 0.0}]],
	# jump + P armed: the jumping chop, the hammer fist's shape with the weapon in the fist
	"chop": [["start", {"cover_f": 0.0, "open_f": 0.0, "arm_f_upper": -170.0, "arm_f_lower": -20.0, "leg_f_upper": -60.0, "leg_f_lower": 95.0,
			"leg_b_upper": -20.0, "leg_b_lower": 105.0, "hip_y": 0.0}],
		["startup", {"cover_f": 0.0, "arm_f_upper": -55.0, "arm_f_lower": -10.0, "torso": 24.0, "head": -10.0, "leg_f_upper": -60.0,
			"leg_f_lower": 95.0, "leg_b_upper": -20.0, "leg_b_lower": 105.0, "hip_y": 0.0}]],
	"block": [["start", {"cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": -38.0, "arm_f_lower": -140.0, "arm_b_upper": -30.0, "arm_b_lower": -145.0,
		"torso": 4.0, "head": 12.0,
		"hip_y": 6.0}]],
	# the front kick (posture sheet; kept, no press reaches it since the three-kick chain opens with the low kick): the
	# weight onto the back foot and the knee straight up to hip height, the foot
	# hanging under it (the chamber); then the hips push forward and the lower leg flicks out, leaning back a touch,
	# hands up; then the leg snaps back to the chamber and the foot sets down where it came from
	"front_kick": [["start", {}],
		["windup", {"hip_x": -45.0, "hip_turn": -4.0, "leg_f_upper": -90.0, "leg_f_lower": 90.0, "torso": -2.0, "hip_y": 0.0}],
		["load", {"hip_x": -45.0, "hip_turn": -4.0, "leg_f_upper": -90.0, "leg_f_lower": 90.0, "torso": -2.0, "hip_y": 0.0}],
		["active", {"hip_x": 20.0, "hip_turn": -12.0, "leg_f_upper": -132.0, "leg_f_lower": 50.0, "torso": -6.0, "head": 6.0, "hip_y": 0.0}],
		["active_end", {"hip_x": 20.0, "hip_turn": -12.0, "leg_f_upper": -132.0, "leg_f_lower": 50.0, "torso": -6.0, "head": 6.0, "hip_y": 0.0}],
		["follow", {"hip_x": -30.0, "hip_turn": -4.0, "leg_f_upper": -90.0, "leg_f_lower": 90.0, "torso": -4.0, "hip_y": 0.0}],
		["end", {}]],
	# the low kick, opening every kick chain (posture sheet; Javier, 2026-11-02 18:19: "the low kick could be the first
	# kick of the 3 kick combo (down, middle, side up)"): a small knee lift, then the front foot snaps forward and down
	# to the knee or shin, the upper body upright; a quick return. The fastest kick.
	"kick": [["start", {}],
		["windup", {"hip_x": -8.0, "hip_turn": -2.0, "leg_f_upper": -45.0, "leg_f_lower": 70.0, "torso": 10.0}],
		["active", {"hip_x": -4.0, "hip_turn": -8.0, "leg_f_upper": -58.0, "leg_f_lower": 4.0, "torso": 8.0}],
		["active_end", {"hip_x": -4.0, "hip_turn": -8.0, "leg_f_upper": -58.0, "leg_f_lower": 4.0, "torso": 8.0}],
		["follow", {"hip_x": -6.0, "hip_turn": -2.0, "leg_f_upper": -40.0, "leg_f_lower": 65.0, "torso": 10.0}],
		["end", {}]],
	# the power punch, ending the three-punch chain (posture sheet; Javier, 2026-11-02 18:19: "Power Button is part of
	# the 3 punch combination, it is the last punch"): sink into a wide stance, the rear fist drawn back to the hip; then
	# the front foot steps and plants, the back foot drives and pivots, a bow stance (front knee bent over the toes,
	# back leg straight, about 70% forward), the waist turns, the rear fist straight to the chest and the front fist
	# pulled back to the hip on purpose, kung fu style; hold it a beat (the freeze), then step back to guard
	"power_punch": [["start", {}],
		# loads low and wide (the back foot slides back, the hips sink and sit back) and holds it, then drives all at once.
		# The load is the sheet's horse stance: the hips in the middle of the feet (50/50) at about thigh level, both knees
		# bent alike (the testers sent it back four times as narrow; measured, the feet were already 2.3 shoulder widths
		# apart, but the hips sat right down over the front foot with the back knee near the street: a kneeling lunge, not
		# a wide stance)
		["windup", {"knees_out": 1.0, "hip_y": 36.0, "hip_x": -39.0, "step_b": -66.0, "turn": -15.0, "hip_turn": -6.0, "cover_b": 0.0, "arm_b_upper": 30.0, "arm_b_lower": -110.0, "torso": 4.0}],
		["load", {"knees_out": 1.0, "hip_y": 36.0, "hip_x": -39.0, "step_b": -66.0, "turn": -15.0, "hip_turn": -6.0, "cover_b": 0.0, "arm_b_upper": 30.0, "arm_b_lower": -110.0, "torso": 4.0}],
		["active", {"step_f": 30.0, "step_b": -30.0, "hip_x": 34.0, "hip_y": 8.0, "rise_b": 0.15, "pivot_b": 70.0, "hip_turn": 18.0, "torso": 16.0, "head": 2.0, "cover_b": 0.0, "arm_b_upper": -90.0, "arm_b_lower": 0.0, "cover_f": 0.0, "arm_f_upper": 40.0, "arm_f_lower": -110.0, "turn": 60.0}],
		["active_end", {"step_f": 30.0, "step_b": -30.0, "hip_x": 34.0, "hip_y": 8.0, "rise_b": 0.15, "pivot_b": 70.0, "hip_turn": 18.0, "torso": 16.0, "head": 2.0, "cover_b": 0.0, "arm_b_upper": -90.0, "arm_b_lower": 0.0, "cover_f": 0.0, "arm_f_upper": 40.0, "arm_f_lower": -110.0, "turn": 60.0}],
		["follow", {"step_f": 30.0, "step_b": -30.0, "hip_x": 34.0, "hip_y": 8.0, "rise_b": 0.15, "pivot_b": 70.0, "hip_turn": 18.0, "torso": 16.0, "head": 2.0, "cover_b": 0.0, "arm_b_upper": -90.0, "arm_b_lower": 0.0, "cover_f": 0.0, "arm_f_upper": 40.0, "arm_f_lower": -110.0, "turn": 62.0}],
		["end", {}]],
	# the side kick to the face, ending the three-kick chain (posture sheet): the back foot steps up behind the front
	# and the body rises, the kicking knee comes up across the body; then the standing foot turns its heel to the enemy
	# and the leg drives straight out, heel first, the body leaning away in one line from head to heel, hands up, the
	# whole body on the one foot; then the leg folds back. Slower: about two-thirds of a second
	"side_kick": [["start", {}],
		["windup", {"step_b": 50.0, "hip_y": -6.0, "hip_x": -4.0, "turn": 30.0, "pivot_b": 90.0, "leg_f_upper": -110.0, "leg_f_lower": 130.0, "torso": -8.0, "hip_turn": -8.0}],
		["active", {"tall": 1.0, "step_b": 60.0, "hip_x": 20.0, "turn": 85.0, "pivot_b": 180.0, "leg_f_upper": -116.0, "leg_f_lower": 0.0, "torso": -48.0, "head": 22.0, "hip_turn": -30.0}],
		["active_end", {"tall": 1.0, "step_b": 60.0, "hip_x": 20.0, "turn": 85.0, "pivot_b": 180.0, "leg_f_upper": -116.0, "leg_f_lower": 0.0, "torso": -48.0, "head": 22.0, "hip_turn": -30.0}],
		["follow", {"tall": 1.0, "step_b": 56.0, "hip_x": 4.0, "turn": 60.0, "pivot_b": 180.0, "leg_f_upper": -110.0, "leg_f_lower": 130.0, "torso": -20.0, "head": 10.0, "hip_turn": -12.0}],
		["end", {}]],
	# getting hit (Stage 1: an enemy that fights back; fight.gd). A plain hit: the head snaps back and the shoulders
	# give, the guard opened, then he settles back into it
	"hurt": [["start", {}],
		["hit_peak", {"torso": -14.0, "head": -26.0, "hip_x": -8.0, "cover_f": 0.3, "cover_b": 0.5, "arm_f_upper": -30.0, "arm_f_lower": -90.0}],
		["end", {}]],
	# a blow taken on the guard: the arms give a little and the body rocks back
	"block_hit": [["start", {"cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": -38.0, "arm_f_lower": -140.0, "arm_b_upper": -30.0, "arm_b_lower": -145.0, "torso": 4.0, "head": 12.0, "hip_y": 6.0}],
		["hit_peak", {"cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": -30.0, "arm_f_lower": -135.0, "arm_b_upper": -22.0, "arm_b_lower": -140.0, "torso": -6.0, "head": 4.0, "hip_x": -6.0, "hip_y": 8.0}],
		["end", {"cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": -38.0, "arm_f_lower": -140.0, "arm_b_upper": -30.0, "arm_b_lower": -145.0, "torso": 4.0, "head": 12.0, "hip_y": 6.0}]],
	# reeling back (the power punch, the hook): leaning away, arms flung open, the back foot catching him
	"stagger": [["start", {}],
		["hit_peak", {"torso": -26.0, "head": -32.0, "hip_x": -18.0, "step_b": -24.0, "cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": 20.0, "arm_f_lower": -50.0, "arm_b_upper": 50.0, "arm_b_lower": -40.0}],
		["reel", {"torso": -12.0, "head": -10.0, "hip_x": -10.0, "step_b": -16.0, "cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": -10.0, "arm_f_lower": -80.0, "arm_b_upper": 20.0, "arm_b_lower": -70.0}],
		["end", {}]],
	# shoved away (the push kick): folded at the waist, sliding back on his feet
	"push": [["start", {}],
		["hit_peak", {"torso": 30.0, "head": 20.0, "hip_x": -20.0, "hip_y": 10.0, "cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": 30.0, "arm_f_lower": -60.0, "arm_b_upper": 40.0, "arm_b_lower": -50.0}],
		["reel", {"torso": 14.0, "head": 4.0, "hip_x": -8.0, "cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": -20.0, "arm_f_lower": -90.0, "arm_b_upper": 10.0, "arm_b_lower": -80.0}],
		["end", {}]],
	# knocked down: the feet go out from under him and he falls back onto the street, then lies there
	"knockdown": [["start", {}],
		["hit_peak", {"torso": -30.0, "head": -30.0, "hip_x": -16.0, "cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": 40.0, "arm_f_lower": -40.0, "arm_b_upper": 70.0, "arm_b_lower": -30.0, "tumble": -20.0}],
		["fall_mid", {"torso": -10.0, "head": -10.0, "cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": 80.0, "arm_f_lower": -20.0, "arm_b_upper": 100.0, "arm_b_lower": -20.0, "leg_f_upper": -60.0, "leg_f_lower": 50.0, "leg_b_upper": -30.0, "leg_b_lower": 40.0, "tumble": -55.0}],
		["end", LYING]],
	"down": [["start", LYING]],
	"tumble": [["start", LYING]],  # rolling down the stairs, lying, carried down the steps by the level
	"ko": [["start", LYING]],
	# getting back up: rolls to sit, a knee under him, stands into the guard
	"get_up": [["start", LYING],
		["rise_mid", {"torso": 50.0, "head": -20.0, "cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": 30.0, "arm_f_lower": -30.0, "arm_b_upper": 60.0, "arm_b_lower": -10.0, "leg_f_upper": -100.0, "leg_f_lower": 130.0, "leg_b_upper": -60.0, "leg_b_lower": 140.0, "tumble": -50.0}],
		["rise_late", {"torso": 30.0, "head": 0.0, "hip_y": 50.0, "cover_f": 0.5, "cover_b": 0.5, "tumble": 0.0}],
		["end", {}]],
	# thrown up by the uppercut: arched back, limbs loose, coming round onto his back
	"launch": [["start", {"torso": -20.0, "head": -40.0, "cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": 60.0, "arm_f_lower": -30.0, "arm_b_upper": 90.0, "arm_b_lower": -20.0, "leg_f_upper": -20.0, "leg_f_lower": 30.0, "leg_b_upper": 10.0, "leg_b_lower": 30.0, "tumble": -15.0}],
		["fall_mid", {"torso": -10.0, "head": -20.0, "cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": 90.0, "arm_f_lower": -20.0, "arm_b_upper": 110.0, "arm_b_lower": -20.0, "leg_f_upper": -50.0, "leg_f_lower": 40.0, "leg_b_upper": -20.0, "leg_b_lower": 40.0, "tumble": -60.0}]],
	# the weapon blows (weapons.gd), the weapon in the lead hand: the swing comes from behind the shoulder, across and
	# level, the hips leading; the backswing cocks high across the body and cuts back down the other way; the overhead
	# smash lifts it high over the head and brings it straight down, the whole body over it
	"swing": [["start", {}],
		["windup", {"cover_f": 0.0, "arm_f_upper": 40.0, "arm_f_lower": -70.0, "turn": -25.0, "hip_turn": -6.0, "hip_x": -6.0, "torso": 6.0}],
		["active", {"cover_f": 0.0, "arm_f_upper": -92.0, "arm_f_lower": -6.0, "turn": 35.0, "hip_turn": 12.0, "hip_x": 12.0, "torso": 16.0, "step_f": 10.0}],
		["active_end", {"cover_f": 0.0, "arm_f_upper": -92.0, "arm_f_lower": -6.0, "turn": 35.0, "hip_turn": 12.0, "hip_x": 12.0, "torso": 16.0, "step_f": 10.0}],
		["follow", {"cover_f": 0.0, "arm_f_upper": -120.0, "arm_f_lower": -40.0, "turn": 45.0, "hip_turn": 14.0, "hip_x": 8.0, "torso": 14.0, "step_f": 6.0}],
		["end", {}]],
	"backswing": [["start", {}],
		["windup", {"cover_f": 0.0, "arm_f_upper": -150.0, "arm_f_lower": -50.0, "turn": 40.0, "hip_turn": 10.0, "torso": 4.0}],
		["active", {"cover_f": 0.0, "arm_f_upper": -78.0, "arm_f_lower": 0.0, "turn": -10.0, "hip_turn": -4.0, "hip_x": 10.0, "torso": 18.0, "step_f": 8.0}],
		["active_end", {"cover_f": 0.0, "arm_f_upper": -78.0, "arm_f_lower": 0.0, "turn": -10.0, "hip_turn": -4.0, "hip_x": 10.0, "torso": 18.0, "step_f": 8.0}],
		["follow", {"cover_f": 0.0, "arm_f_upper": -40.0, "arm_f_lower": -20.0, "turn": -20.0, "hip_x": 4.0, "torso": 14.0}],
		["end", {}]],
	"smash": [["start", {}],
		["windup", {"cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": -178.0, "arm_f_lower": -40.0, "arm_b_upper": -160.0, "arm_b_lower": -50.0, "torso": -8.0, "head": 10.0, "hip_x": -10.0, "rise_b": 0.3}],
		["load", {"cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": -178.0, "arm_f_lower": -40.0, "arm_b_upper": -160.0, "arm_b_lower": -50.0, "torso": -8.0, "head": 10.0, "hip_x": -10.0, "rise_b": 0.3}],
		["active", {"cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": -70.0, "arm_f_lower": 0.0, "arm_b_upper": -60.0, "arm_b_lower": -20.0, "torso": 30.0, "head": -6.0, "hip_x": 16.0, "hip_y": 14.0, "step_f": 14.0}],
		["active_end", {"cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": -70.0, "arm_f_lower": 0.0, "arm_b_upper": -60.0, "arm_b_lower": -20.0, "torso": 30.0, "head": -6.0, "hip_x": 16.0, "hip_y": 14.0, "step_f": 14.0}],
		["follow", {"cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": -45.0, "arm_f_lower": 0.0, "arm_b_upper": -40.0, "arm_b_lower": -20.0, "torso": 34.0, "head": -10.0, "hip_x": 14.0, "hip_y": 16.0, "step_f": 14.0}],
		["end", {}]],
	# P K P armed: the weapon low behind the hip, then up through him in an arc, the body rising onto the front foot
	"rising_swing": [["start", {}],
		["windup", {"cover_f": 0.0, "arm_f_upper": 50.0, "arm_f_lower": -10.0, "hip_y": 18.0, "torso": 22.0, "turn": -15.0}],
		["active", {"cover_f": 0.0, "arm_f_upper": -150.0, "arm_f_lower": -10.0, "hip_y": -8.0, "torso": -6.0, "head": -10.0, "turn": 30.0, "rise_b": 0.4, "step_f": 10.0}],
		["active_end", {"cover_f": 0.0, "arm_f_upper": -150.0, "arm_f_lower": -10.0, "hip_y": -8.0, "torso": -6.0, "head": -10.0, "turn": 30.0, "rise_b": 0.4, "step_f": 10.0}],
		["follow", {"cover_f": 0.0, "arm_f_upper": -165.0, "arm_f_lower": -30.0, "torso": -4.0, "turn": 25.0}],
		["end", {}]],
	# K P K armed: the butt of the weapon driven short and straight, in the elbow's place
	"handle_jab": [["start", {}],
		["windup", {"cover_f": 0.0, "arm_f_upper": -20.0, "arm_f_lower": -120.0, "hip_x": -4.0}],
		["active", {"cover_f": 0.0, "arm_f_upper": -80.0, "arm_f_lower": -40.0, "hip_x": 8.0, "hip_turn": 6.0, "torso": 14.0}],
		["active_end", {"cover_f": 0.0, "arm_f_upper": -80.0, "arm_f_lower": -40.0, "hip_x": 8.0, "hip_turn": 6.0, "torso": 14.0}],
		["follow", {}],
		["end", {}]],
	# the Grabber's bear hug (the team's roster): arms spread wide and back (the glint), then a lunge, both arms
	# reaching round, then the squeeze
	"grab": [["start", {}],
		["windup", {"cover_f": 0.0, "cover_b": 0.0, "open_f": 1.0, "open_b": 1.0, "arm_f_upper": 30.0, "arm_f_lower": -20.0, "arm_b_upper": 50.0, "arm_b_lower": -20.0, "torso": -4.0, "hip_x": -8.0}],
		["active", {"cover_f": 0.0, "cover_b": 0.0, "open_f": 1.0, "open_b": 1.0, "arm_f_upper": -96.0, "arm_f_lower": 0.0, "arm_b_upper": -88.0, "arm_b_lower": -5.0, "torso": 24.0, "hip_x": 22.0, "step_f": 26.0}],
		["active_end", {"cover_f": 0.0, "cover_b": 0.0, "open_f": 1.0, "open_b": 1.0, "arm_f_upper": -96.0, "arm_f_lower": 0.0, "arm_b_upper": -88.0, "arm_b_lower": -5.0, "torso": 24.0, "hip_x": 22.0, "step_f": 26.0}],
		["follow", {"cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": -96.0, "arm_f_lower": -40.0, "arm_b_upper": -88.0, "arm_b_lower": -40.0, "torso": 26.0, "hip_x": 26.0, "step_f": 28.0}],
		["end", {}]],
	# the weapon thrown: the arm cocks back high behind the head, the hips and chest drive, the arm whips through
	"throw": [["start", {}],
		["windup", {"cover_f": 0.0, "arm_f_upper": 150.0, "arm_f_lower": -70.0, "torso": -10.0, "hip_x": -10.0, "turn": -20.0}],
		["active", {"cover_f": 0.0, "arm_f_upper": -95.0, "arm_f_lower": 0.0, "torso": 20.0, "hip_x": 14.0, "turn": 30.0, "step_f": 16.0}],
		["active_end", {"cover_f": 0.0, "arm_f_upper": -95.0, "arm_f_lower": 0.0, "torso": 20.0, "hip_x": 14.0, "turn": 30.0, "step_f": 16.0}],
		["follow", {"cover_f": 0.0, "arm_f_upper": -60.0, "arm_f_lower": 10.0, "torso": 24.0, "hip_x": 16.0, "step_f": 16.0}],
		["end", {}]],
	# ducking under a high kick: down low, the chest over the knees, the head tucked, the guard kept up
	"duck": [["start", {}],
		["end", {"hip_y": 34.0, "torso": 46.0, "head": -26.0}]],
	# up out of a duck, the head driving into the face: the hips and chest lunge, the head leads (the Mechanic's)
	"headbutt": [["start", {}],
		["windup", {"torso": -16.0, "head": -12.0, "hip_x": -10.0, "hip_y": -14.0}],
		["active", {"torso": 30.0, "head": 18.0, "hip_x": 24.0, "step_f": 22.0}],
		["active_end", {"torso": 30.0, "head": 18.0, "hip_x": 24.0, "step_f": 22.0}],
		["follow", {"torso": 20.0, "head": 8.0, "hip_x": 16.0, "step_f": 18.0}],
		["end", {}]],
	# held in the bear hug: arms pinned to his sides, struggling
	"held": [["start", {"cover_f": 0.0, "cover_b": 0.0, "arm_f_upper": 4.0, "arm_f_lower": -30.0, "arm_b_upper": 8.0, "arm_b_lower": -30.0, "torso": -10.0, "head": -16.0, "hip_y": -6.0}]],
	# X switches stance (Javier, 2026-11-02 18:48): the guard eases down to standing easy, and back up again
	"to_walk": [["start", {"feet": 1.0}], ["end", STAND]],
	"to_fight": [["start", STAND], ["end", {"feet": 1.0}]]
}


static func moment(state: String, name: String, tune: Dictionary) -> int:
	match name:
		"start":
			return 0
		"end":
			match state:
				"land": return tune["land_ticks"]
				"to_walk", "to_fight": return tune["stance_switch_ticks"]
				"jump_squat": return tune["jump_squat_ticks"]
				"climb": return tune["climb_ticks"]
				"roll": return tune["roll_ticks"]
				"hurt", "block_hit", "stagger", "push", "knockdown", "get_up": return tune[state + "_ticks"]
				"launch": return tune["jump_air_ticks"]
				"duck": return 12  # (fighter.gd DUCK_TICKS)
			return Moves.length(state, tune)
		# getting hit: the blow's peak comes quickly, then the reaction plays out
		"hit_peak":
			return 3
		"reel":
			return 12
		"fall_mid":
			return 10
		"rise_mid":
			return int(tune["get_up_ticks"] * 0.4)
		"rise_late":
			return int(tune["get_up_ticks"] * 0.75)
		# the roll: down, over (upside down, a tight ball), up into a crouch
		"roll_down":
			return int(tune["roll_ticks"] * 0.15)
		"roll_over":
			return int(tune["roll_ticks"] * 0.5)
		"roll_up":
			return int(tune["roll_ticks"] * 0.85)
		"climb_mid":
			return tune["climb_ticks"] / 2
		# a jump's flight, at the same fractions of the air time as the recording (CMU 16_05)
		"rise":
			return int(tune["jump_air_ticks"] * 0.22)
		"peak":
			return int(tune["jump_air_ticks"] * 0.5)
		"fall":
			return int(tune["jump_air_ticks"] * 0.82)
	var d := Moves.data(state, tune)
	match name:
		"windup":
			return maxi(1, int(round(d["startup"] * WINDUP_AT.get(state, 0.7))))  # cocked a beat before the blow
		"sweep":
			# halfway round a swing, between the wind-up and the blow: a bent knee or elbow coming round
			return (moment(state, "windup", tune) + d["startup"]) / 2 + 1
		"load":
			# a held load ends LOAD_END frames before the blow (2, or a move's own): the drive is sudden
			return d["startup"] - LOAD_END.get(state, 2)
		"startup", "active":
			return d["startup"]
		"active_end":
			return d["startup"] + d["active"] - 1
		"follow":
			return d["startup"] + d["active"] - 1 + maxi(2, int(d["recovery"] * 0.35))
		"recoil":
			return d["startup"] + d["active"] - 1 + 5  # after a flying kick the leg folds back to its chamber
		"tuck":
			return d["startup"] + d["active"] - 1 + 12  # then the legs come under him for the landing
	return 0


static func full(changes: Dictionary) -> Dictionary:
	var out := GUARD.duplicate()
	out.merge(changes, true)
	# the shoulders turn with the hips unless the pose says otherwise (a move's clock makes them trail; see angles())
	for k in ["spin", "turn"]:
		if not changes.has(k + "_upper"):
			out[k + "_upper"] = out[k]
	if not changes.has("spin_head"):
		out["spin_head"] = out["spin"]
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
					if t < WALK_EASE_IN:
						pose = blend(full({"feet": 1.0}), pose, float(t) / WALK_EASE_IN)  # from the guard, no jump
				elif state == "idle":
					# a fighter's light bounce on top of the slow weight rock: the knees give a few px twice a second
					pose["hip_y"] = pose.get("hip_y", 0.0) + 3.0 * (0.5 - 0.5 * cos(TAU * float(t % 30) / 30.0))
					pose["torso"] = pose.get("torso", 0.0) + 1.0 * sin(TAU * float(t % 30) / 30.0)
				elif state == "stroll":
					pose.merge(_gait(t, STROLL_CYCLE, STROLL_STEP, tune["stroll_speed"], 24.0, 7.5, true), true)
					if t < WALK_EASE_IN:
						pose = blend(full(STAND), pose, float(t) / WALK_EASE_IN)
				elif state == "run":
					pose.merge(_gait(t, RUN_CYCLE, RUN_STEP, tune["run_speed"], 64.0, 40.0, true, 0.7), true)
					if t < WALK_EASE_IN:
						pose = blend(full(STAND), pose, float(t) / WALK_EASE_IN)
				return pose
		return full({})
	if SHOTS.has(state):
		var keys: Array = SHOTS[state]
		if keys.size() == 1:
			return full(keys[0][1])
		var poses := []
		for i in keys.size():
			var p: Dictionary = full(keys[i][1])
			if keys[i][0] == "follow" and (keys[i][1] as Dictionary).is_empty():
				p = overshoot(poses[i - 1])
			poses.append(p)
		var now := _shot_at(state, keys, poses, t, tune)
		if not Moves.is_move(state):
			return now
		var out := now.duplicate()
		var striker: String = Moves.data(state, tune)["limb"]  # the striking part keeps the move's own timing
		# the lead runs up to the end of the blow, then every part keeps the move's own clock, so the hand or foot comes
		# home the way it went out (the testers' review of 0812a0e: with the upper arm still leading on the way back,
		# the jab's fist dropped 39 px below its line)
		var blow_end := moment(state, "active_end", tune)
		for k in LEAD:
			if out.has(k) and k != striker:
				var lead: int = mini(LEAD[k], LEAD_CAP.get(state, LEAD[k]))
				out[k] = _shot_at(state, keys, poses, maxi(t, mini(t + lead, blow_end)), tune)[k]
		# the hips turn first and the chest and arms follow: "spin" and "turn" above are the hips (read ahead), these
		# are the shoulders, on the move's own clock (the assistant team's fourth review: show the hips leading)
		out["spin_upper"] = now.get("spin", 0.0)
		out["turn_upper"] = now.get("turn", 0.0)
		if SHOULDER_LAG.has(state):
			out["turn_upper"] = _shot_at(state, keys, poses, maxi(0, t - SHOULDER_LAG[state]), tune).get("turn", 0.0)
		out["spin_head"] = _shot_at(state, keys, poses, maxi(t, mini(t + HEAD_LEAD, blow_end)), tune).get("spin", 0.0)  # the head looks first
		return out
	return full({})


## The landing (the assistant team's fourth review, 2026-11-02: soften it). Falling the last REACH_HEIGHT px, the legs
## reach down for the street. The frame the feet touch stays sharp; then over the next frames the knees and hips take
## his weight (a sink of up to SINK px, deepest LAND_PEAK frames in) and he rises again by LAND_SETTLE frames, the feet
## staying where they landed. It runs on into the guard. since = frames since the touchdown, or -1 in the air.
const REACH_HEIGHT := 48.0
const LAND_REACH := {"leg_f_upper": -22.0, "leg_f_lower": 22.0, "leg_b_upper": -18.0, "leg_b_lower": 24.0}  # CMU 16_05 at touchdown
const STAGGER_HEIGHT := 90.0
const LAND_STAGGER := {"leg_f_upper": -47.3, "leg_f_lower": 48.9, "leg_b_upper": 22.6, "leg_b_lower": 19.9}  # the guard's legs
const SINK := 14.0
const LAND_PEAK := 4
const LAND_SETTLE := 14


static func landing(pose: Dictionary, since: int, height: float, falling: bool) -> Dictionary:
	var out := pose.duplicate()
	if since < 0:
		# a flying kick lands staggered: its feet spread into the guard stance in the air, so they don't jump into it at
		# touchdown (the testers, f744019: the landing was abrupt; the back foot jumped 70 px in one frame)
		var stagger: bool = out.get("land_spread", 0.0) > 0.5
		var reach_from := STAGGER_HEIGHT if stagger else REACH_HEIGHT
		if falling and height < reach_from:
			var k := clampf(1.0 - height / reach_from, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			var to: Dictionary = LAND_STAGGER if stagger else LAND_REACH
			for key in to:
				out[key] = lerpf(out.get(key, 0.0), to[key], k)
		return out
	var dip := sink_at(since)
	out["hip_y"] = out.get("hip_y", 0.0) + dip
	out["torso"] = out.get("torso", 0.0) + dip * 0.3  # the chest folds a little over the bent knees
	# the weight goes forward onto the front leg as it drops (he lands moving): the front knee takes the bend and the
	# back leg stays long instead of folding to a kneel (lifting the back heel here only bent it more)
	out["hip_x"] = out.get("hip_x", 0.0) + dip * 1.4
	return out


## How far the hips have sunk, `since` frames after a touchdown.
static func sink_at(since: int) -> float:
	if since <= 0 or since >= LAND_SETTLE:
		return 0.0
	if since <= LAND_PEAK:
		return SINK * sin(PI * 0.5 * float(since) / LAND_PEAK)
	var k := float(since - LAND_PEAK) / float(LAND_SETTLE - LAND_PEAK)
	return SINK * (1.0 - k * k * (3.0 - 2.0 * k))


## An everyday walk or a run at tick t: each foot swings forward over `step` ticks (lifted by up to `lift` px), then
## stays planted, sliding back under the body at `speed`, so it holds its place on the street; the back foot is half a
## cycle behind, so the legs pass each other. The arms swing against the legs by `arm` degrees. In a run the swing
## is longer than the stance, so twice a cycle both feet are off the street, and the body lifts in that moment.
## "ahead" is how far in front a foot lands, as a share of the half-stride: 1 lands as far ahead as it leaves behind;
## a runner lands closer under the body (the hips don't drop to reach far ahead) and pushes off further behind.
static func _gait(t: int, cycle: int, step: int, speed: float, lift: float, arm: float, heel_first := false, ahead := 1.0) -> Dictionary:
	var reach := speed * float(cycle - step) * 0.5
	var front := reach * ahead
	var back := 2.0 * reach - front
	var out := {"feet": 1.0, "relaxed": 1.0, "rise_b": 0.0}
	var airborne := 0
	for side in ["f", "b"]:
		var u := (t + (0 if side == "f" else cycle / 2)) % cycle
		if u < step:
			var k := float(u) / step
			out["step_" + side] = lerpf(-back, front, k * k * (3.0 - 2.0 * k))
			# the heel lifts behind straight after the push-off (the lift comes early in the swing), as recorded walks
			# and runs show; the toe then skims forward
			out["lift_" + side] = lift * sin(PI * (pow(k, 0.55) if heel_first else k))
			airborne += 1
		else:
			out["step_" + side] = front - speed * float(u - step)
			out["lift_" + side] = 0.0
	# the arms against the legs: the near arm forward as the far leg comes forward, and the other way about
	out["arm_f_upper"] = -8.0 - arm * out["step_b"] / maxf(reach, 1.0)
	out["arm_b_upper"] = 8.0 - arm * out["step_f"] / maxf(reach, 1.0)
	if airborne == 2:
		out["hip_y"] = -20.0 if lift > 40.0 else -4.0  # both feet off the street: the body is in the air, at its highest
	return out


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
	out["rise_b"] = 0.0  # shuffling, the back foot steps flat (a lifted heel let a planted foot slide)
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
	out["knees_out"] = pose.get("knees_out", 0.0)  # read by the leg solve
	if pose.get("feet", 0.0) > 0.5:
		# feet placed, legs bent to reach them (the hips are still level here; they shift and tip further down)
		var joint: Vector2 = _end("hip", out)[0]
		var to := {}
		var drop := 0.0
		for side in ["f", "b"]:
			# a rising heel lifts the ankle off the ball of the foot, which stays on its spot
			var tilt := deg_to_rad(90.0 * clampf(pose.get("rise_" + side, 0.0), 0.0, 1.0))
			var spot: Vector2 = (STANCE[side] as Vector2).lerp(RELAXED[side], clampf(pose.get("relaxed", 0.0), 0.0, 1.0))
			to[side] = spot + Vector2(pose.get("step_" + side, 0.0) + FOOT_LENGTH * (1.0 - cos(tilt)),
				-pose.get("lift_" + side, 0.0) - FOOT_LENGTH * sin(tilt))
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
	for k in ["rise_f", "rise_b", "spin", "turn", "pivot_f", "pivot_b", "fore_f", "fore_b", "upper_f", "upper_b"]:
		out[k] = pose.get(k, 0.0)
	out["spin_upper"] = pose.get("spin_upper", out["spin"])  # the shoulders (they trail the hips in a move)
	out["turn_upper"] = pose.get("turn_upper", out["turn"])
	out["spin_head"] = pose.get("spin_head", out["spin"])
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
	# turning on one planted foot (a spin, that foot pivoting on its ball): the hips are carried over it as he comes
	# edge-on, and on over to its other side as he comes round (the testers, 02:29: "carry the knee and hips smoothly
	# over it"); with the view turning the drawing about that foot's ball (hero_view.gd), nothing jumps at the flip
	var spin_now: float = pose.get("spin", 0.0)
	if cos(deg_to_rad(spin_now)) < 0.9999:  # turned at all (a half turn too)
		for side in anchors:
			if absf(pose.get("pivot_" + side, 0.0)) > 0.5:
				out["hip_x"] = lerpf(out["hip_x"], (anchors[side] as Vector2).x, 1.0 - absf(cos(deg_to_rad(spin_now))))
				out["spin_on"] = 1.0 if side == "f" else 2.0
				break
	out["hip"] = pelvis
	for side in ["f", "b"]:
		if not anchors.has(side):
			out["leg_%s_upper" % side] -= pelvis  # a raised leg keeps its aim: the pelvis bends the back, not the kick
	# a planted foot slid along the street by the move (feet mode already placed them)
	if pose.get("feet", 0.0) < 0.5:
		for side in anchors:
			anchors[side] = (anchors[side] as Vector2) + Vector2(pose.get("step_" + side, 0.0), 0)
	# standing on one leg (a kick, a knee), he stands tall on it: the hips rise or drop to keep that leg as long as it
	# is in the stance, slightly bent, instead of folding it under him
	if anchors.size() == 1 and grounded:
		var side: String = anchors.keys()[0]
		var to: Vector2 = (anchors[side] as Vector2) - (_end("hip", out)[0] as Vector2)
		var full: float = BONES["leg_%s_upper" % side][3] + BONES["leg_%s_lower" % side][3] - 1.0
		# (a two-bone leg bends fast as it shortens: tall goes to the solver's own limit, half a px short, never locked)
		var stance_len: float = minf((STANCE[side] as Vector2).length(), full)
		var tall: float = clampf(pose.get("tall", 0.0), -1.0, 1.0)
		var want: float = lerpf(stance_len, full + 0.5, tall) if tall >= 0.0 else lerpf(stance_len, SQUAT_LEG, -tall)
		if absf(to.x) < want:
			out["hip_y"] += to.y - sqrt(want * want - to.x * to.x)
	# a rising heel ("rise_"). On one leg (no flat foot left) the whole body goes up onto its toes. Otherwise the leg
	# drives straight: the ball of the foot stays put and the heel lifts just as far as a nearly straight leg needs
	var all_rise := rising.size() == anchors.size() and not rising.is_empty()
	if pose.get("feet", 0.0) > 0.5:
		rising.clear()  # placed feet already stand on their toes where they rise
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
		# at the least, up on the ball of the foot by the angle "rise_" says (the weight coming onto the toes, as in
		# a landing's crouch); more if the leg drives straight and needs it
		var tilt := deg_to_rad(90.0 * r)
		var lifted := Vector2(a.x + FOOT_LENGTH * (1.0 - cos(tilt)), a.y - FOOT_LENGTH * sin(tilt))
		var tilted := lifted
		if d >= reach + FOOT_LENGTH:
			lifted = a.lerp(ball - Vector2(0, FOOT_LENGTH), r)  # too far even on the toes: up on them, the hips sink
		elif d > reach - FOOT_LENGTH:
			# the ankle sits a foot's length from the ball and a straight leg's length from the hip: where they meet
			var along: float = (d * d + FOOT_LENGTH * FOOT_LENGTH - reach * reach) / (2.0 * d)
			var off := sqrt(maxf(0.0, FOOT_LENGTH * FOOT_LENGTH - along * along))
			var dir := to_hip / d
			var c1: Vector2 = ball + dir * along + Vector2(-dir.y, dir.x) * off
			var c2: Vector2 = ball + dir * along - Vector2(-dir.y, dir.x) * off
			var straight: Vector2 = c1 if c1.y < c2.y else c2
			if straight.y < tilted.y:
				lifted = a.lerp(straight, r)
		anchors[side] = lifted
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
	# … but never into a kneel: a standing knee stays KNEE_STAND above its ankle's street. If a dip or a wide stance would
	# fold it down, the hips give up just enough of the dip (a wide power punch load knelt, 2026-11-02 night)
	for i in 8:
		var low := 0.0
		for side in anchors:
			low = maxf(low, (_end("leg_%s_upper" % side, out)[0] as Vector2).y - ((anchors[side] as Vector2).y - KNEE_STAND))
		if low <= 0.5:
			break
		out["hip_y"] -= low
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
		# … and a swinging knee: it never sinks into the street either (a sweep's leg coming round knelt through it)
		if grounded and (_end("leg_%s_upper" % side, out)[0] as Vector2).y > -KNEE_CLEAR:
			_lift_knee(out, side)
			_settle_foot(out, side, grounded)
	_cover(out, pose)
	_hold(out, pose)
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


## Weapons held as they're really used (Javier, 2026-11-04; the team's grips and pose sheets, art-in 2026-11-04-weapon-
## grips-v2 and -weapon-poses): never over the shoulder. Each weapon's Ready, where the weapon hand sits from the hip
## joint (forward, up) and where the weapon points (degrees, 0 = straight at the enemy, -90 = straight up), whether both
## hands hold it, and its block. Heights from the hip: belt about 0, navel -20, chest -60, chin -95, head -115.
const WEAPON_READY := {
	"knife": {"at": Vector2(34, -10), "wpn": 0.0},  # belt height, close, blade forward and level
	"stick": {"at": Vector2(46, -112), "wpn": -100.0},  # head height in front of the face, tip up and a little back
	"pipe": {"at": Vector2(58, -90), "wpn": -48.0},  # chin height in front, tip up and forward, elbow bent
	"wrench": {"at": Vector2(44, -62), "wpn": -35.0},  # chest height, jaw forward, tighter
	"bat": {"at": Vector2(36, -26), "wpn": -45.0, "two": true},  # hands at the belly, a diagonal, tip at the enemy's head
	"baguette": {"at": Vector2(36, -26), "wpn": -45.0, "two": true},  # held like the bat (Pippin)
	"sword": {"at": Vector2(42, -20), "wpn": -18.0, "two": true},  # a fist before the navel, point at his throat
	"lovelight": {"at": Vector2(42, -20), "wpn": -18.0, "two": true},  # as the sword
	"cane": {"at": Vector2(48, -40), "wpn": -8.0},  # a fencer: point at your chest (Madame Chrome)
	"baton": {"at": Vector2(46, -105), "wpn": -60.0},  # up in front at head height, tip forward (Mr. Static)
	"mic_stand": {"at": Vector2(40, -45), "wpn": -10.0, "two": true},  # a staff across the body (DJ Volt)
}
const WEAPON_REST := 80.0  # walking, standing easy: the weapon hangs low at his side, tip down (a little forward)...
## ...a long one angled forward so its tip just reaches the street (the Bruiser's pipe tip on the floor, roster v5):
## how far each reaches past the fist (the drawn length less the grip), and the fist's height when it hangs.
const WEAPON_REACH := {"knife": 38.0, "stick": 112.0, "pipe": 102.0, "wrench": 62.0, "bat": 112.0, "baguette": 112.0,
	"sword": 142.0, "lovelight": 152.0, "mic_stand": 152.0, "cane": 122.0, "baton": 92.0}
const HANG_HEIGHT := 92.0
const WEAPON_SWING_REL := -78.0  # in a swing (till each weapon's own swings are drawn): through the fist, as before
const FENCE := Vector2(50, -70)  # the free hand with a one-handed weapon: up before the chest, open (a fence)
const BLOCK_AT := Vector2(46, -55)  # blocking: the weapon held across the body before the chest
const READY_STATES := ["idle", "walk", "to_fight"]
## The weapon's own blows (it moves with the arm through the fist) and lying on the street (it goes where the arm goes);
## anything else armed, a kick among them, keeps the weapon in its Ready ("kicks with the weapon held in its Ready
## place, not swung about": the pose sheet).
const WEAPON_MOVES := ["swing", "backswing", "smash", "rising_swing", "handle_jab", "chop", "low_swing", "throw"]
const LYING_STATES := ["knockdown", "down", "get_up", "launch", "ko", "tumble", "held", "land_hard"]
const BLOCK_STATES := ["block", "block_hit"]
const REST_STATES := ["stand", "stroll", "run", "to_walk"]


## The weapon in hand on top of a pose: hold keys for bake (_hold) and the weapon's own angle. Every pose with a
## weapon carries all the keys (0 when unused), so a blend from one pose to the next moves them smoothly.
static func armed(pose: Dictionary, state: String, weapon: String) -> Dictionary:
	if weapon == "":
		return pose
	var out := pose.duplicate()
	var g: Dictionary = WEAPON_READY.get(weapon, WEAPON_READY["pipe"])
	var two: bool = g.get("two", false)
	for k in ["hold_f", "hold_b", "wpn_hold"]:
		out[k] = 0.0
	out["hold_fx"] = g["at"].x
	out["hold_fy"] = g["at"].y
	out["hold_bx"] = FENCE.x
	out["hold_by"] = FENCE.y
	out["wpn"] = g["wpn"]
	out["wpn_len"] = 1.0
	var relaxed: bool = pose.get("relaxed", 0.0) >= 0.5
	if state in REST_STATES or (relaxed and state in READY_STATES):
		var reach: float = WEAPON_REACH.get(weapon, 100.0)
		out["wpn"] = minf(WEAPON_REST, rad_to_deg(asin(minf(1.0, HANG_HEIGHT / reach))))  # hanging low, tip down
		out["wpn_hold"] = 1.0
	elif not state in WEAPON_MOVES and not state in LYING_STATES:
		var at: Vector2 = g["at"]
		var dir_deg: float = g["wpn"]
		if state in BLOCK_STATES:
			if weapon == "knife":  # never with the blade: the knife hand back to the hip, the free forearm up (Pippin)
				at = Vector2(22, -6)
				dir_deg = 0.0
				out["cover_b"] = 1.0
			else:
				at = BLOCK_AT
				dir_deg = 0.0
				out["wpn_len"] = 0.45  # across the body: seen end-on from the side, it draws short
		out["hold_fx"] = at.x
		out["hold_fy"] = at.y
		out["hold_f"] = 1.0
		out["cover_f"] = 0.0
		out["wpn"] = dir_deg
		out["wpn_hold"] = 1.0
		if two:  # the other hand on the handle, a fist further down it
			var down := at - Vector2.from_angle(deg_to_rad(dir_deg)) * 17.0
			out["hold_bx"] = down.x
			out["hold_by"] = down.y
			out["hold_b"] = 1.0
			out["cover_b"] = 0.0
		elif not (weapon == "knife" and state in BLOCK_STATES):
			out["hold_b"] = 1.0  # the free hand up, open, a fence
			out["cover_b"] = 0.0
			out["open_b"] = 1.0
	return out


## Brings a weapon hand (and a two-handed weapon's other hand, or the free hand's fence) to where the pose holds it, by
## a two-bone solve of the arm from the hip joint's spot (the elbow down); then works out the weapon's angle in the
## hand ("wpn_rel") from the way it should point.
static func _hold(out: Dictionary, pose: Dictionary) -> void:
	var hip := Vector2(pose.get("hip_x", 0.0), BONES["hip"][1].y + pose.get("hip_y", 0.0))
	for side in ["f", "b"]:
		var c: float = pose.get("hold_" + side, 0.0)
		if c <= 0.0:
			continue
		var upper: String = "arm_%s_upper" % side
		var lower: String = "arm_%s_lower" % side
		var target: Vector2 = hip + Vector2(pose.get("hold_%sx" % side, 0.0), pose.get("hold_%sy" % side, 0.0))
		var root: Array = _end("shoulder_" + side, out)
		var l1: float = BONES[upper][3]
		var l2: float = BONES[lower][3]
		var to: Vector2 = target - root[0]
		var d := clampf(to.length(), absf(l1 - l2) + 0.5, l1 + l2 - 0.5)
		var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
		var arm := to.angle() + acos(cos_a)  # the elbow below the line: down
		var elbow: Vector2 = root[0] + Vector2(l1, 0).rotated(arm)
		var fore := (target - elbow).angle()
		out[upper] = lerpf(out[upper], rad_to_deg(arm - root[1]) - BONES[upper][2], c)
		out[lower] = lerpf(out[lower], rad_to_deg(fore - arm) - BONES[lower][2], c)
		out["hand_" + side] = lerpf(out["hand_" + side], 0.0, c)
	if pose.has("wpn"):
		var hand: Array = _end("hand_f", out)
		var rel: float = wrapf(pose["wpn"] - rad_to_deg(hand[1]), -180.0, 180.0)
		out["wpn_rel"] = rad_to_deg(lerp_angle(deg_to_rad(WEAPON_SWING_REL), deg_to_rad(rel), clampf(pose.get("wpn_hold", 0.0), 0.0, 1.0)))
		out["wpn_len"] = pose.get("wpn_len", 1.0)


static func _planted(out: Dictionary, side: String) -> bool:
	return -(_end("leg_%s_lower" % side, out)[0] as Vector2).y <= FOOT_LENGTH + TOE_LENGTH


## Lifts a swinging leg's knee to KNEE_CLEAR above the street, the thigh keeping its side, the shin reaching back
## toward where the ankle was (straight along that line if it can't reach it).
static func _lift_knee(out: Dictionary, side: String) -> void:
	var upper := "leg_%s_upper" % side
	var lower := "leg_%s_lower" % side
	var hip_end: Array = _end("hip", out)
	var joint: Vector2 = hip_end[0] + (BONES[upper][1] as Vector2).rotated(hip_end[1])
	var knee: Vector2 = _end(upper, out)[0]
	var ankle: Vector2 = _end(lower, out)[0]
	var l1: float = BONES[upper][3]
	var l2: float = BONES[lower][3]
	var dy := clampf(-KNEE_CLEAR - joint.y, -l1, l1)
	var dx := sqrt(maxf(l1 * l1 - dy * dy, 0.0)) * (1.0 if knee.x >= joint.x else -1.0)
	var thigh := Vector2(dx, dy).angle()
	var k2 := joint + Vector2(dx, dy)
	var want := Vector2(ankle.x, minf(ankle.y, -2.0))
	var shin := (want - k2).angle()
	out[upper] = rad_to_deg(thigh - hip_end[1]) - BONES[upper][2]
	out[lower] = rad_to_deg(shin - thigh) - BONES[lower][2]


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
	# "knees_out" turns the back knee round the line from hip to ankle until it points back. Half way it points at the
	# camera: seen from the side the knee then sits on that line and both bones draw shorter, so the foot stays put
	var out_k: float = clampf(out.get("knees_out", 0.0), 0.0, 1.0) if side == "b" else 0.0
	out["short_%s_upper" % side] = 1.0
	out["short_%s_lower" % side] = 1.0
	if out_k > 0.0:
		var axis := to.normalized() * d
		var foot_of := joint + to.normalized() * (l1 * cos_a)  # the knee's circle round that line has its middle here
		knee = foot_of + (knee - foot_of) * cos(PI * out_k)
		thigh = (knee - joint).angle()
		out["short_%s_upper" % side] = maxf((knee - joint).length() / l1, 0.05)
		out["short_%s_lower" % side] = maxf((joint + axis - knee).length() / l2, 0.05)
		target = joint + axis
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


## How long a bone draws, as a share of its length: a forearm pointing at the camera ("fore_") looks shorter, and
## so do the thigh and shin while a knee turns round past it ("knees_out").
static func drawn_length(bone: String, baked: Dictionary) -> float:
	if bone in ["arm_f_lower", "arm_b_lower"]:
		return 1.0 - (1.0 - FORE_SHORT) * clampf(baked.get("fore_" + bone.substr(4, 1), 0.0), 0.0, 1.0)
	if bone in ["arm_f_upper", "arm_b_upper"]:
		return 1.0 - (1.0 - FORE_SHORT) * clampf(baked.get("upper_" + bone.substr(4, 1), 0.0), 0.0, 1.0)
	if bone in ["leg_f_upper", "leg_b_upper", "leg_f_lower", "leg_b_lower"]:
		return baked.get("short_" + bone.substr(4), 1.0)  # a knee turning round past the camera ("knees_out")
	return 1.0


## Where a bone's far end sits, relative to the feet, for a pose, facing right (for tests and hit checks).
static func tip(bone: String, pose: Dictionary, grounded := true) -> Vector2:
	return _end(bone, bake(pose, grounded))[0]


## … and where it is drawn: past a quarter turn of a spin the view flips the drawing to face the other way (his back
## to us), so a foot reaching back in the pose reaches forward on the screen (the back sweep's hit); and turning on a
## planted foot, the drawing turns about that foot.
static func drawn_tip(bone: String, pose: Dictionary, grounded := true) -> Vector2:
	var baked := bake(pose, grounded)
	var at: Vector2 = _end(bone, baked)[0]
	var flip := -1.0 if cos(deg_to_rad(pose.get("spin", 0.0))) < 0.0 else 1.0
	var shift := 0.0
	var on: float = baked.get("spin_on", 0.0)
	if on > 0.0:
		# turning on a planted foot the view turns the drawing about that foot's ball (hero_view.gd), so the ball stays
		# where it was planted; the foot draws shorter as it swings round (never below a third)
		var side := "f" if on < 1.5 else "b"
		var ankle: float = (_end("leg_%s_lower" % side, baked)[0] as Vector2).x
		var swing := cos(deg_to_rad(baked["pivot_" + side]))
		var x := maxf(absf(swing), 0.35) * (signf(swing) if swing != 0.0 else 1.0)
		shift = (ankle + FOOT_LENGTH) - flip * (ankle + FOOT_LENGTH * x)
	return Vector2(flip * at.x + shift, at.y)
