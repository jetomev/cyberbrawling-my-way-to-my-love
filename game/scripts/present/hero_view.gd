extends Node2D
## Draws one fighter as grey cut-out parts on a Skeleton2D (D-4), posed from poses.gd every frame. Its origin is the
## spot on the street under the fighter's feet; a soft shadow stays there when the fighter jumps.

const Poses := preload("res://scripts/present/poses.gd")

const SHADES := [Color(0.62, 0.63, 0.68), Color(0.40, 0.41, 0.47)]  # front parts lighter, back parts darker
const OUTLINE := Color(0.08, 0.08, 0.10)

var skeleton: Skeleton2D
var bones := {}
var body: Node2D
var shadow: Polygon2D
var tint := Color.WHITE
var facing := 1.0
var body_y := 0.0  # the body's height off the street (sync sets it); a roll moves the body about it
## Switching between standing, walking, shuffling and running, the drawing blends from the last pose it drew into the
## new one over BLEND_TICKS frames (the run's first steps eased in from standing, wherever the legs really were, so a
## hand or foot jumped up to 131 px in one frame; a steady run's own biggest swing is about 36)
const LOCOMOTION := ["idle", "walk", "stand", "stroll", "run", "to_walk", "to_fight"]
const BLEND_TICKS := 6
const AIR := ["air_kick", "hammer_fist"]  # (a plain jump already lands smoothly: test_landing)
const LANDING := ["land", "idle", "stand", "walk", "stroll", "run"]
const LAND_BLEND_TICKS := 18
## Pain on the drawing (D-9, no blood): each part's tint by its stage, fresh / bruised (purple) / swollen (red, and a
## swollen head puffs up) / broken (dark); the grey-box stand-in for the real art's damage sheets.
const PAIN_TINT := [Color.WHITE, Color(0.9, 0.78, 1.05), Color(1.12, 0.72, 0.74), Color(0.78, 0.55, 0.62)]
## The weapon in the lead hand, drawn through the fist: its length and colour by kind (the team's art replaces it).
const WEAPON_LOOK := {"knife": [56.0, 8.0, Color(0.85, 0.87, 0.9)], "stick": [130.0, 10.0, Color(0.55, 0.42, 0.28)],
	"pipe": [120.0, 12.0, Color(0.62, 0.64, 0.68)], "wrench": [80.0, 14.0, Color(0.5, 0.52, 0.56)],
	"bat": [130.0, 16.0, Color(0.72, 0.58, 0.38)], "sword": [160.0, 9.0, Color(0.88, 0.9, 0.95)],
	"mic_stand": [170.0, 7.0, Color(0.15, 0.15, 0.18)], "cane": [140.0, 6.0, Color(0.85, 0.88, 0.95)],
	"baton": [110.0, 10.0, Color(0.4, 0.75, 1.0)]}
var weapon_drawn := ""
var weapon_node: Polygon2D
const PAIN_BONES := {
	"head": ["head", "neck"], "chest": ["chest", "belly"],
	"arm_f": ["arm_f_upper", "arm_f_lower", "hand_f"], "arm_b": ["arm_b_upper", "arm_b_lower", "hand_b"],
	"leg_f": ["leg_f_upper", "leg_f_lower", "foot_f", "toe_f"], "leg_b": ["leg_b_upper", "leg_b_lower", "foot_b", "toe_b"],
}
const HEAD_CLEAR := 12.0  # rolling, the head's drawn outline stays this far above the street
const OUTLINE_SINK := 5.0  # a standing foot's outline sits this far into the street line; a roll's does the same
var last_state := ""
var last_pose := {}
var blend_from := {}
var blend_left := 0
var blend_total := BLEND_TICKS
var since_touch := 999  # frames since the feet last touched down (for the landing's sink and rise)
var was_grounded := true


func _init(body_tint := Color.WHITE) -> void:
	tint = body_tint
	shadow = Polygon2D.new()
	shadow.name = "Shadow"
	shadow.color = Color(0, 0, 0, 0.35)
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(Vector2(cos(a) * 46.0, sin(a) * 11.0))
	shadow.polygon = pts
	add_child(shadow)
	body = Node2D.new()
	body.name = "Body"
	add_child(body)
	skeleton = Skeleton2D.new()
	skeleton.name = "Skeleton"
	body.add_child(skeleton)
	for name in Poses.BONES:  # parents come before children in BONES, and back parts before front parts
		var spec: Array = Poses.BONES[name]
		var bone := Bone2D.new()
		bone.name = name
		bone.position = spec[1]
		bone.rotation_degrees = spec[2]
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(maxf(spec[3], 1.0))
		bone.set_bone_angle(0.0)
		bone.rest = bone.transform
		(skeleton if spec[0] == "" else bones[spec[0]]).add_child(bone)
		bones[name] = bone
		if spec[3] > 0.0:
			bone.add_child(_part(name, spec))


func _part(name: String, spec: Array) -> Node2D:
	var length: float = spec[3]
	var w: float = spec[4] * 0.5
	var color: Color = SHADES[spec[5]] * tint
	var p: Node2D
	if name == "head":
		# a skull with a jaw and a nose on the face side (+y is forward), so the way he faces and tips his chin reads
		p = Node2D.new()
		p.add_child(_shape(PackedVector2Array([Vector2(length * 0.06, w * 0.15), Vector2(length * 0.02, w * 0.62),
			Vector2(length * 0.22, w * 1.02), Vector2(length * 0.42, w * 0.96), Vector2(length * 0.4, w * 0.3)]), color))
		p.add_child(_shape(_ellipse(Vector2(length * 0.55, 0), length * 0.47, w * 0.92), color))
		p.add_child(_shape(PackedVector2Array([Vector2(length * 0.5, w * 0.8), Vector2(length * 0.44, w * 1.14),
			Vector2(length * 0.36, w * 0.86)]), color))
	elif name.begins_with("shoulder"):
		p = _shape(_ellipse(Vector2(length * 0.5, 0), length * 0.62, w), color)
	elif name.begins_with("hand"):
		# a fist (a rounded block) and an open hand (flat, longer, a thumb); the pose shows one or the other
		p = Node2D.new()
		var fist := _shape(_ellipse(Vector2(length * 0.45, 0), length * 0.62, w * 0.95), color)
		fist.name = "Fist"
		var open := _shape(PackedVector2Array([Vector2(-2, -w * 0.5), Vector2(length + 6, -w * 0.4),
			Vector2(length + 8, w * 0.1), Vector2(length * 0.5, w * 0.45), Vector2(length * 0.55, w * 1.1),
			Vector2(length * 0.2, w * 1.0), Vector2(-2, w * 0.5)]), color)
		open.name = "Open"
		open.visible = false
		p.add_child(fist)
		p.add_child(open)
	elif name.begins_with("foot"):
		# heel at the ankle, the sole along the bone toward the ball of the foot
		p = _shape(PackedVector2Array([Vector2(-w * 0.9, -w * 0.9), Vector2(length * 0.55, -w * 0.7),
			Vector2(length + 2, -w * 0.45), Vector2(length + 2, w * 0.6), Vector2(-w * 1.1, w * 0.6)]), color)
	elif name == "belly":
		# from the hips in to the waist: the body tapers, it isn't a box
		p = _shape(PackedVector2Array([Vector2(-6, -w * 0.92), Vector2(length + 2, -w * 0.8), Vector2(length + 2, w * 0.8),
			Vector2(-6, w * 0.92)]), color)
	elif name == "chest":
		# from the waist out to the shoulders and the round of the back
		p = _shape(PackedVector2Array([Vector2(-4, -w * 0.8), Vector2(length * 0.7, -w * 1.08), Vector2(length + 4, -w * 0.95),
			Vector2(length + 6, w * 0.7), Vector2(length * 0.6, w * 0.95), Vector2(-4, w * 0.8)]), color)
	elif name.begins_with("toe"):
		p = _shape(PackedVector2Array([Vector2(-2, -w * 0.45), Vector2(length, -w * 0.15), Vector2(length + 2, w * 0.5),
			Vector2(-2, w * 0.5)]), color)
	else:
		# a rounded slab from joint to joint, a little past each end so the joins never gap
		p = _shape(PackedVector2Array([Vector2(-w * 0.6, -w), Vector2(length + w * 0.4, -w * 0.85),
			Vector2(length + w * 0.4, w * 0.85), Vector2(-w * 0.6, w)]), color)
	p.name = "Part"
	# back limbs draw behind the body
	if spec[5] == 1:
		p.z_index = -1
	return p


func _shape(points: PackedVector2Array, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	var line := Line2D.new()
	line.points = points
	line.closed = true
	line.width = 3.0
	line.default_color = OUTLINE
	poly.add_child(line)
	return poly


func _ellipse(centre: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## Puts the view where the fighter is and poses it. ground_y is the screen line of the street's far edge.
func sync(f, ground_y: float) -> void:
	position = Vector2(f.x, ground_y + f.z)
	z_index = int(f.z)
	body_y = -f.y / scale.y  # (a view drawn bigger or smaller still stands on the step it is on)
	facing = f.facing
	var grounded: bool = f.on_ground()
	if grounded and not was_grounded:
		since_touch = 0
	elif grounded:
		since_touch += 1
	was_grounded = grounded
	var floor_y: float = f.world.floor_at(f.x, f.z, f.y) if f.world != null else 0.0
	shadow.position.y = -floor_y / scale.y  # under his feet on whatever he stands on (a crate, a step, a landing)
	shadow.scale = Vector2.ONE * (1.0 - clampf((f.y - floor_y) / 200.0, 0.0, 1.0) * 0.45)  # smaller the higher above it
	var pose := Poses.landing(Poses.angles(f.state, f.t, f.tune), since_touch if grounded else -1, f.y - floor_y, f.vy < 0.0)
	pose["tumble_dir"] = float(f.roll_dir)
	# a broken arm hangs, bent wrong at the elbow, unless he's throwing a blow with it
	var striking := ""
	if f.move().has("limb"):
		striking = f.limb_part(f.move()["limb"])
	for side in ["f", "b"]:
		if f.broken("arm_" + side) and striking != "arm_" + side and not f.state in Poses.OFF_FEET:
			pose["cover_" + side] = 0.0
			pose["arm_%s_upper" % side] = 14.0
			pose["arm_%s_lower" % side] = 34.0
			pose["open_" + side] = 1.0
	if f.state != last_state and last_state in LOCOMOTION and f.state in LOCOMOTION and not last_pose.is_empty():
		blend_from = last_pose
		blend_left = BLEND_TICKS
		blend_total = BLEND_TICKS
	elif f.state != last_state and last_state in AIR and f.state in LANDING and not last_pose.is_empty():
		# touching down out of a jump or an air blow: the arms and legs come from where they were in the air (the
		# testers, f744019: the flying kick's landing was abrupt, a 155 px jump of a hand in one frame)
		blend_from = last_pose
		blend_left = LAND_BLEND_TICKS
		blend_total = LAND_BLEND_TICKS
	last_state = f.state
	if blend_left > 0:
		var mixed := Poses.blend(blend_from, pose, 1.0 - float(blend_left) / (blend_total + 1))
		if blend_total == LAND_BLEND_TICKS:
			# landing: only the upper body comes from the air; the legs and feet take the landing as it is, so the
			# planted feet stay where they touched down
			for k in pose:
				if (k as String).begins_with("leg_") or (k as String).begins_with("step_") or (k as String).begins_with("lift_") \
						or (k as String).begins_with("rise_") or (k as String).begins_with("pivot_") or k in ["feet", "hip_x", "hip_y"]:
					mixed[k] = pose[k]
		pose = mixed
		blend_left -= 1
	last_pose = pose
	apply(pose, grounded and not f.state in Poses.OFF_FEET)  # falling, lying, rising: placed by the outline, no planted feet
	body.modulate = Color(1.6, 1.6, 1.9) if f.blocking() == "perfect" else Color.WHITE  # a perfect block flashes
	for region in PAIN_BONES:
		var stage: int = f.pain_stage(region)
		for name in PAIN_BONES[region]:
			var part: Node2D = bones[name].get_node_or_null("Part")
			if part == null:
				continue
			# (apply() resets the limbs' modulate every frame for near/far; the body and head it leaves alone)
			if name in ["belly", "chest", "neck", "head"]:
				part.modulate = PAIN_TINT[stage]
			else:
				part.modulate *= PAIN_TINT[stage]
	_show_weapon(f.weapon)
	var head_part: Node2D = bones["head"].get_node("Part")
	head_part.scale = Vector2.ONE * (1.1 if f.pain_stage("head") >= 2 else 1.0)


func _show_weapon(kind: String) -> void:
	if kind == weapon_drawn:
		return
	weapon_drawn = kind
	if weapon_node == null:
		weapon_node = Polygon2D.new()
		weapon_node.name = "Weapon"
		weapon_node.rotation_degrees = -78.0  # held through the fist, pointing up and forward from the hand
		weapon_node.z_index = 1
		bones["hand_f"].add_child(weapon_node)
	weapon_node.visible = WEAPON_LOOK.has(kind)
	if not weapon_node.visible:
		return
	var look: Array = WEAPON_LOOK[kind]
	var l: float = look[0]
	var w: float = look[1] * 0.5
	weapon_node.polygon = PackedVector2Array([Vector2(-18, -w), Vector2(l, -w * (0.4 if kind in ["knife", "sword"] else 1.0)),
		Vector2(l, w * (0.4 if kind in ["knife", "sword"] else 1.0)), Vector2(-18, w)])
	weapon_node.color = look[2]


## Where the hips, hands, feet and the top of the head are drawn right now, in this view's own space (its origin is the spot under the
## fighter's feet), for the reviewers' close-ups (D-22). Works outside the scene tree.
func points() -> Dictionary:
	var out := {}
	for name in ["hip", "hand_f", "hand_b", "foot_f", "foot_b", "head"]:
		var t := Transform2D.IDENTITY
		var n: Node = bones[name]
		while n != self:
			t = (n as Node2D).transform * t
			n = n.get_parent()
		out[name] = t * Vector2(Poses.BONES["head"][3], 0) if name == "head" else t.origin  # the head: its top
	return out


## Rolling, the part that sets his height on the street (the head counts with its clearance), for the tests.
var contact := ""


## Where the shoulders are drawn (between the two shoulder joints), in the same space as points(): for the close-up of the
## shoulder carrying the roll (the testers, 00:57 on 66ce4c6). Kept out of points(), whose parts frame every close-up.
func shoulder_point() -> Vector2:
	var sum := Vector2.ZERO
	for name in ["arm_f_upper", "arm_b_upper"]:
		var t := Transform2D.IDENTITY
		var n: Node = bones[name]
		while n != self:
			t = (n as Node2D).transform * t
			n = n.get_parent()
		sum += t.origin
	return sum * 0.5


func apply(pose: Dictionary, grounded := true) -> void:
	var baked := Poses.bake(pose, grounded)
	for name in bones:
		var bone: Bone2D = bones[name]
		bone.rotation_degrees = Poses.BONES[name][2] + baked[name]
	bones["hip"].position = Poses.BONES["hip"][1] + Vector2(baked["hip_x"], baked["hip_y"])
	# a spin turns the whole body around the up axis. It never squashes him thin (the assistant team's third review:
	# a turn that flattens him to a line reads wrong): the arms and legs keep their thickness, only the chest narrows
	# as for a hip turn, and past 90 the drawing flips to face the other way, his back to us
	var spun := cos(deg_to_rad(baked["spin"]))
	body.scale.x = facing * (-1.0 if spun < 0.0 else 1.0)
	# the hips turn first and the shoulders follow: while the hips have come round and the shoulders haven't yet (or
	# the other way about), the upper body is mirrored back to where the shoulders still face
	var spun_top := cos(deg_to_rad(baked["spin_upper"]))
	bones["belly"].scale.y = -1.0 if (spun < 0.0) != (spun_top < 0.0) else 1.0
	# and the head looks round first, ahead of both (its face side flips over before the shoulders come round)
	var spun_head := cos(deg_to_rad(baked["spin_head"]))
	bones["head"].scale.y = -1.0 if (spun_top < 0.0) != (spun_head < 0.0) else 1.0
	# the hips and shoulders turn over (a turn, or a spin): the chest narrows, never below about half; past 90 the
	# far-side leg (with the hips) and arm (with the shoulders) come in front, lit as near
	var over := cos(deg_to_rad(baked["turn"] + baked["spin"]))
	var over_top := cos(deg_to_rad(baked["turn_upper"] + baked["spin_upper"]))
	# the waist turns with the hips and the chest with the shoulders, so the waist is seen leading
	bones["belly"].get_node("Part").scale.y = maxf(absf(over), 0.55)
	bones["chest"].get_node("Part").scale.y = maxf(absf(over_top), 0.55)
	for name in bones:
		var spec: Array = Poses.BONES[name]
		var part: Node2D = bones[name].get_node_or_null("Part")
		if part == null or name in ["belly", "chest", "neck", "head"]:
			continue
		var far: bool = spec[5] == 1
		var turned := over if name.begins_with("leg") or name.begins_with("foot") or name.begins_with("toe") else over_top
		if turned < 0.0:
			far = not far
		part.z_index = -1 if far else 0
		var drawn_far: bool = spec[5] == 1
		part.modulate = Color.WHITE if far == drawn_far else (Color(1.55, 1.55, 1.5) if drawn_far else Color(0.65, 0.65, 0.66))
	# a standing foot swung round on its ball: shorter as it turns, pointing back past 90. The toe moves with the foot
	# (the testers, 2026-11-02 20:30: the toe was left out in front, so the heel never showed to the target)
	for side in ["f", "b"]:
		var swing := cos(deg_to_rad(baked["pivot_" + side]))
		var x := maxf(absf(swing), 0.35) * (signf(swing) if swing != 0.0 else 1.0)
		for n in ["foot_" + side, "toe_" + side]:
			bones[n].get_node("Part").scale.x = x
		bones["toe_" + side].position = Poses.BONES["toe_" + side][1] * Vector2(x, 1.0)
	# an upper arm or forearm pointing at the camera draws shorter (and a leg while its knee turns past it): its drawn part shrinks along the bone and the next
	# joint moves in to match (moving the joint, not scaling the bone, so nothing below it is skewed)
	for side in ["f", "b"]:
		for pair in [["arm_%s_upper" % side, "arm_%s_lower" % side], ["arm_%s_lower" % side, "hand_" + side],
				["leg_%s_upper" % side, "leg_%s_lower" % side], ["leg_%s_lower" % side, "foot_" + side]]:
			var k := Poses.drawn_length(pair[0], baked)
			bones[pair[0]].get_node("Part").scale.x = k
			bones[pair[1]].position = Vector2(Poses.BONES[pair[0]][3] * k, 0)
	for side in ["f", "b"]:
		var hand: Node2D = bones["hand_" + side].get_node("Part")
		var open: bool = baked["open_" + side] > 0.5
		hand.get_node("Open").visible = open
		hand.get_node("Fist").visible = not open
	# a roll ("tumble") turns the whole drawing round about the hips, the way the roll goes along the street, and keeps
	# its lowest point on the street: he rolls along it, never through it
	body.rotation = 0.0
	body.position = Vector2(0.0, body_y)
	# turning on one planted foot, the drawing turns about that foot's ball: it stays where it was planted while the heel
	# swings round it and the body comes round over it (the testers, 02:29 on 0922751: the sweep's supporting foot
	# jumped across in a single frame as he spun; "keep the same forefoot planted, turn the heel around it")
	var on: float = baked.get("spin_on", 0.0)
	if on > 0.0:
		var side := "f" if on < 1.5 else "b"
		var planted: float = ((Poses._end("leg_%s_lower" % side, baked)[0] as Vector2).x + Poses.FOOT_LENGTH) * facing
		var t := Transform2D.IDENTITY
		var n: Node = bones["toe_" + side]
		while n != self:
			t = (n as Node2D).transform * t
			n = n.get_parent()
		body.position.x += planted - t.origin.x
	var tumble: float = pose.get("tumble", 0.0)
	if tumble != 0.0:
		var turn := Transform2D(deg_to_rad(tumble * pose.get("tumble_dir", 1.0)), Vector2.ZERO)
		var flip := Transform2D(0.0, body.scale, 0.0, Vector2.ZERO)
		var hip: Vector2 = flip * (bones["hip"].position as Vector2)
		var pos := Vector2(0.0, body_y) + hip - turn * hip
		var lowest := -INF
		contact = ""
		# by the drawn outline itself, every corner of every part (the testers, 00:57 on 66ce4c6: the close-up showed him
		# hovering; placed by the bones' centre lines, his back's thickness was only guessed). He rolls on his back and
		# shoulders; the tucked head's outline stays HEAD_CLEAR above the street (the testers, 2026-11-02 22:33)
		for name in bones:
			var part: Node = bones[name].get_node_or_null("Part")
			if part == null:
				continue
			var shapes: Array = part.find_children("*", "Polygon2D", true, false)
			if part is Polygon2D:
				shapes.append(part)
			for poly in shapes:
				if not (poly as CanvasItem).visible:
					continue
				var at := Transform2D.IDENTITY
				var n: Node = poly
				while n != body:
					at = (n as Node2D).transform * at
					n = n.get_parent()
				var whole := turn * flip * at
				for q in (poly as Polygon2D).polygon:
					var y: float = (pos + whole * q).y + (HEAD_CLEAR if name == "head" else -OUTLINE_SINK)
					if y > lowest:
						lowest = y
						contact = name
		body.rotation = turn.get_rotation()
		body.position = pos - Vector2(0.0, lowest - body_y)
