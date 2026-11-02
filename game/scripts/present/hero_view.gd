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
	body.position.y = -f.y
	facing = f.facing
	var height := clampf(f.y / 200.0, 0.0, 1.0)
	shadow.scale = Vector2.ONE * (1.0 - height * 0.45)
	var grounded: bool = f.on_ground()
	if grounded and not was_grounded:
		since_touch = 0
	elif grounded:
		since_touch += 1
	was_grounded = grounded
	var floor_y: float = f.world.floor_at(f.x, f.z, f.y) if f.world != null else 0.0
	var pose := Poses.landing(Poses.angles(f.state, f.t, f.tune), since_touch if grounded else -1, f.y - floor_y, f.vy < 0.0)
	apply(pose, grounded)
	body.modulate = Color(1.6, 1.6, 1.9) if f.blocking() == "perfect" else Color.WHITE  # a perfect block flashes


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
	for n in ["belly", "chest"]:
		bones[n].get_node("Part").scale.y = maxf(absf(over_top), 0.55)
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
	# a standing foot swung round on its ball: shorter as it turns, pointing back past 90
	for side in ["f", "b"]:
		var swing := cos(deg_to_rad(baked["pivot_" + side]))
		var x := maxf(absf(swing), 0.35) * (signf(swing) if swing != 0.0 else 1.0)
		for n in ["foot_" + side, "toe_" + side]:
			bones[n].get_node("Part").scale.x = x
	# an upper arm or forearm pointing at the camera draws shorter: its drawn part shrinks along the bone and the next
	# joint moves in to match (moving the joint, not scaling the bone, so nothing below it is skewed)
	for side in ["f", "b"]:
		for pair in [["arm_%s_upper" % side, "arm_%s_lower" % side], ["arm_%s_lower" % side, "hand_" + side]]:
			var k := Poses.drawn_length(pair[0], baked)
			bones[pair[0]].get_node("Part").scale.x = k
			bones[pair[1]].position = Vector2(Poses.BONES[pair[0]][3] * k, 0)
	for side in ["f", "b"]:
		var hand: Node2D = bones["hand_" + side].get_node("Part")
		var open: bool = baked["open_" + side] > 0.5
		hand.get_node("Open").visible = open
		hand.get_node("Fist").visible = not open
