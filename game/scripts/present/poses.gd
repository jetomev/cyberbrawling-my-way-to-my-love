extends RefCounted
## The grey-box body (D-4: cut-out parts on 2D bones) and its poses, as plain data, so tests can read them without a
## scene. The real art later replaces each grey part with a drawn one on the same bone.
##
## A bone points along its own +x. Its rest angle is relative to its parent; poses add an offset in degrees. With
## the body facing right: for bones hanging down (legs, arms), a negative offset swings them forward; for the
## torso, a positive offset leans it forward; a positive lower-leg offset bends the knee, a negative forearm offset
## bends the elbow up. "hip_y" moves the whole body down in pixels (a crouch, a bob).

## Parents come before their children. name: [parent, position on the parent bone, rest angle, length, width, shade (0 = front, 1 = back)]
const BONES := {
	"hip": ["", Vector2(0, -125), 0.0, 0.0, 0.0, 0],
	"torso": ["hip", Vector2(0, 0), -90.0, 85.0, 48.0, 0],
	"head": ["torso", Vector2(88, 0), 0.0, 46.0, 40.0, 0],
	"leg_b_upper": ["hip", Vector2(0, 0), 90.0, 62.0, 26.0, 1],
	"leg_b_lower": ["leg_b_upper", Vector2(62, 0), 0.0, 63.0, 22.0, 1],
	"arm_b_upper": ["torso", Vector2(78, 0), 180.0, 52.0, 19.0, 1],
	"arm_b_lower": ["arm_b_upper", Vector2(52, 0), 0.0, 50.0, 16.0, 1],
	"leg_f_upper": ["hip", Vector2(0, 0), 90.0, 62.0, 26.0, 0],
	"leg_f_lower": ["leg_f_upper", Vector2(62, 0), 0.0, 63.0, 22.0, 0],
	"arm_f_upper": ["torso", Vector2(78, 0), 180.0, 52.0, 19.0, 0],
	"arm_f_lower": ["arm_f_upper", Vector2(52, 0), 0.0, 50.0, 16.0, 0],
}

const GUARD := {
	"torso": 8.0, "head": -8.0,
	"arm_f_upper": -50.0, "arm_f_lower": -85.0, "arm_b_upper": -25.0, "arm_b_lower": -100.0,
	"leg_f_upper": -16.0, "leg_f_lower": 12.0, "leg_b_upper": 16.0, "leg_b_lower": 12.0, "hip_y": 5.0,
}

## Looping states: [loop length in ticks, [tick, changes from GUARD], ...]
const LOOPS := {
	"idle": [60, [0, {}], [30, {"hip_y": 9.0, "arm_f_upper": -46.0}]],
	"walk": [32,
		[0, {"leg_f_upper": -30.0, "leg_f_lower": 8.0, "leg_b_upper": 26.0, "leg_b_lower": 28.0, "hip_y": 6.0}],
		[8, {"leg_f_upper": 0.0, "leg_f_lower": 30.0, "leg_b_upper": 0.0, "leg_b_lower": 4.0, "hip_y": 1.0}],
		[16, {"leg_f_upper": 26.0, "leg_f_lower": 28.0, "leg_b_upper": -30.0, "leg_b_lower": 8.0, "hip_y": 6.0}],
		[24, {"leg_f_upper": 0.0, "leg_f_lower": 4.0, "leg_b_upper": 0.0, "leg_b_lower": 30.0, "hip_y": 1.0}]],
}

## One-shot states, keyed by named moments the tuning decides (see moment()).
const SHOTS := {
	"jump": [["start", {"leg_f_upper": -60.0, "leg_f_lower": 95.0, "leg_b_upper": -20.0, "leg_b_lower": 105.0,
		"arm_f_upper": -70.0, "arm_b_upper": -45.0, "hip_y": 0.0}]],
	"land": [["start", {"leg_f_upper": -38.0, "leg_f_lower": 62.0, "leg_b_upper": 8.0, "leg_b_lower": 55.0, "hip_y": 24.0}],
		["end", {}]],
	"punch": [["start", {}],
		["startup", {"arm_f_upper": -35.0, "arm_f_lower": -110.0, "torso": 2.0}],
		["active", {"arm_f_upper": -98.0, "arm_f_lower": 0.0, "torso": 12.0, "head": -10.0, "arm_b_upper": -5.0,
			"leg_f_upper": -24.0, "leg_b_upper": 24.0}],
		["active_end", {"arm_f_upper": -98.0, "arm_f_lower": 0.0, "torso": 12.0, "head": -10.0, "arm_b_upper": -5.0,
			"leg_f_upper": -24.0, "leg_b_upper": 24.0}],
		["end", {}]],
	"air_kick": [["start", {"leg_f_upper": -60.0, "leg_f_lower": 95.0, "leg_b_upper": -20.0, "leg_b_lower": 105.0,
		"arm_f_upper": -70.0, "arm_b_upper": -45.0, "hip_y": 0.0}],
		["startup", {"leg_f_upper": -92.0, "leg_f_lower": -4.0, "leg_b_upper": 34.0, "leg_b_lower": 85.0, "torso": -22.0,
			"head": 14.0, "arm_f_upper": -30.0, "arm_f_lower": -60.0, "arm_b_upper": 40.0, "arm_b_lower": -40.0, "hip_y": 0.0}]],
	"climb": [["start", {"arm_f_upper": -165.0, "arm_f_lower": 0.0, "arm_b_upper": -150.0, "arm_b_lower": 0.0,
			"leg_f_upper": -20.0, "leg_f_lower": 30.0, "hip_y": 0.0}],
		["climb_mid", {"arm_f_upper": -60.0, "arm_f_lower": -30.0, "arm_b_upper": -40.0, "arm_b_lower": -30.0,
			"torso": 35.0, "leg_f_upper": -95.0, "leg_f_lower": 100.0, "leg_b_upper": 20.0, "leg_b_lower": 40.0, "hip_y": 10.0}],
		["end", {}]],
	"kick": [["start", {}],
		["startup", {"leg_f_upper": -72.0, "leg_f_lower": 105.0, "torso": -8.0, "hip_y": 0.0}],
		["active", {"leg_f_upper": -100.0, "leg_f_lower": 0.0, "torso": -26.0, "head": 18.0, "leg_b_upper": 8.0,
			"leg_b_lower": 4.0, "hip_y": 0.0}],
		["active_end", {"leg_f_upper": -100.0, "leg_f_lower": 0.0, "torso": -26.0, "head": 18.0, "leg_b_upper": 8.0,
			"leg_b_lower": 4.0, "hip_y": 0.0}],
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
			return tune[state + "_startup"] + tune[state + "_active"] + tune[state + "_recovery"]
		"climb_mid":
			return tune["climb_ticks"] / 2
		"startup":
			return tune[state + "_startup"]
		"active":
			return tune[state + "_startup"]
		"active_end":
			return tune[state + "_startup"] + tune[state + "_active"] - 1
	return 0


static func full(changes: Dictionary) -> Dictionary:
	var out := GUARD.duplicate()
	out.merge(changes, true)
	return out


static func blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var s := k * k * (3.0 - 2.0 * k)  # ease in and out, so moves read as snaps, not slides
	var out := {}
	for key in a:
		out[key] = lerpf(a[key], b.get(key, a[key]), s)
	return out


## The angle offsets (and hip_y) for a state, t ticks into it.
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
				return blend(full(k0[1]), full(k1[1]), float(tt - k0[0]) / float(t1 - k0[0]))
		return full({})
	if SHOTS.has(state):
		var keys: Array = SHOTS[state]
		if keys.size() == 1:
			return full(keys[0][1])
		for i in range(keys.size() - 1):
			var a: int = moment(state, keys[i][0], tune)
			var b: int = moment(state, keys[i + 1][0], tune)
			if t < b or i == keys.size() - 2:
				var k := 1.0 if b <= a else clampf(float(t - a) / float(b - a), 0.0, 1.0)
				return blend(full(keys[i][1]), full(keys[i + 1][1]), k)
	return full({})


## Where a bone's far end sits, relative to the feet, for a pose, facing right (plain maths, for tests and hit
## checks). Screen axes: +x forward, +y down.
static func tip(bone: String, pose: Dictionary) -> Vector2:
	var chain: Array[String] = []
	var b := bone
	while b != "":
		chain.push_front(b)
		b = BONES[b][0]
	var pos := Vector2(0, pose.get("hip_y", 0.0))
	var ang := 0.0
	for name in chain:
		var spec: Array = BONES[name]
		pos += (spec[1] as Vector2).rotated(ang)
		ang += deg_to_rad(spec[2] + pose.get(name, 0.0))
	return pos + Vector2(BONES[bone][3], 0).rotated(ang)
