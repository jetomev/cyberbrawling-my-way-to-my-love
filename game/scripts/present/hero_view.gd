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


func _part(name: String, spec: Array) -> Polygon2D:
	var length: float = spec[3]
	var w: float = spec[4] * 0.5
	var p := Polygon2D.new()
	p.name = "Part"
	if name == "head":
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			pts.append(Vector2(length * 0.5 + cos(a) * length * 0.5, sin(a) * w))
		p.polygon = pts
	else:
		# a rounded slab from joint to joint, a little past each end so the joins never gap
		p.polygon = PackedVector2Array([Vector2(-w * 0.6, -w), Vector2(length + w * 0.4, -w * 0.85),
			Vector2(length + w * 0.4, w * 0.85), Vector2(-w * 0.6, w)])
	p.color = SHADES[spec[5]] * tint
	var line := Line2D.new()
	line.points = p.polygon
	line.closed = true
	line.width = 3.0
	line.default_color = OUTLINE
	p.add_child(line)
	# the back arm draws behind the torso; children of a later sibling draw on top otherwise
	if spec[5] == 1:
		p.z_index = -1
	return p


## Puts the view where the fighter is and poses it. ground_y is the screen line of the street's far edge.
func sync(f, ground_y: float) -> void:
	position = Vector2(f.x, ground_y + f.z)
	z_index = int(f.z)
	body.position.y = -f.y
	body.scale.x = f.facing
	var height := clampf(f.y / 200.0, 0.0, 1.0)
	shadow.scale = Vector2.ONE * (1.0 - height * 0.45)
	apply(Poses.angles(f.state, f.t, f.tune))


func apply(pose: Dictionary) -> void:
	for name in bones:
		var bone: Bone2D = bones[name]
		bone.rotation_degrees = Poses.BONES[name][2] + pose.get(name, 0.0)
	bones["hip"].position.y = Poses.BONES["hip"][1].y + pose.get("hip_y", 0.0)
