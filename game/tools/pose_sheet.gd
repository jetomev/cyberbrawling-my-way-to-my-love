extends SceneTree
## Draws poses side by side, large, on a plain street, and quits after a few frames: for judging a stance or a moment
## of a move by eye (Javier, 2026-11-02 morning: "more attention to detail"). Run windowed through scripts/pose_sheet.sh,
## which records the frame. Arguments after "--": state:tick[:air] ..., e.g. idle:0 cross:active air_kick:3:air (a tick,
## or a moment name: windup, sweep, active, follow)

const Poses := preload("res://scripts/present/poses.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")
const HeroView := preload("res://scripts/present/hero_view.gd")

const SCALE := 1.7
var frames := 0


func _initialize() -> void:
	var items := OS.get_cmdline_user_args()
	if items.is_empty():
		items = ["idle:0"]
	var t := Tuning.fresh()
	var stage := Node2D.new()
	root.add_child(stage)
	stage.z_index = -10  # the back limbs draw one step behind the body: keep the backdrop further back still
	var sky := ColorRect.new()
	sky.color = Color(0.17, 0.17, 0.21)
	sky.size = Vector2(1920, 1080)
	stage.add_child(sky)
	var ground := ColorRect.new()
	ground.color = Color(0.32, 0.32, 0.36)
	ground.position = Vector2(0, 820)
	ground.size = Vector2(1920, 260)
	stage.add_child(ground)
	var step := 1920.0 / items.size()
	for i in items.size():
		var bits: PackedStringArray = items[i].split(":")
		var state := bits[0]
		var tick := 0
		if bits.size() > 1:
			tick = int(bits[1]) if bits[1].is_valid_int() else Poses.moment(state, bits[1], t)  # a tick, or windup/active/follow
		var air := bits.size() > 2 and bits[2] == "air"
		var v = HeroView.new()
		v.z_index = 10
		v.position = Vector2(step * (i + 0.5) - 20, 820 - (120 if air else 0))
		v.scale = Vector2.ONE * SCALE
		stage.add_child(v)
		v.apply(Poses.angles(state, tick, t), not air)
		var label := Label.new()
		label.text = items[i]
		label.position = Vector2(step * i + 12, 860)
		label.add_theme_font_size_override("font_size", 34)
		stage.add_child(label)


func _process(_delta: float) -> bool:
	frames += 1
	return frames > 3
