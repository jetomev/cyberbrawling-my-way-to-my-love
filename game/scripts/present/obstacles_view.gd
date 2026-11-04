extends Node2D
## Draws what stands on the street (street_world.gd) as grey boxes with a top and a front, each at its own depth so
## fighters pass in front of or behind it. A broken crate becomes a low heap of boards.

const COLORS := {"crate": Color(0.50, 0.45, 0.38), "car": Color(0.36, 0.42, 0.52), "barrier": Color(0.55, 0.50, 0.30),
	"hydrant": Color(0.72, 0.22, 0.2), "dumpster": Color(0.24, 0.38, 0.28), "speaker": Color(0.2, 0.2, 0.24)}
const EDGE := Color(0.08, 0.08, 0.10)

var world
var ground_y := 760.0
var items := {}  # object id -> its Node2D


func setup(street_world, street_ground_y: float) -> void:
	for id in items:  # a new street (a level's restart, upstairs): the old things go
		items[id].queue_free()
	items = {}
	if loose != null:
		loose.queue_free()
		loose = null
	world = street_world
	ground_y = street_ground_y
	for o in world.objects:
		var n := Node2D.new()
		n.name = "%s_%d" % [o["kind"], o["id"]]
		n.z_index = int(o["z1"])
		n.draw.connect(_draw_object.bind(n, o))
		add_child(n)
		items[o["id"]] = n


func refresh() -> void:
	for id in items:
		items[id].queue_redraw()
	refresh_items()


## Things lying on the street (a dropped pipe, …), redrawn when one is dropped or picked up.
var loose: Node2D


func refresh_items() -> void:
	if loose == null:
		loose = Node2D.new()
		loose.name = "Loose"
		loose.z_index = 0
		loose.draw.connect(_draw_loose)
		add_child(loose)
	loose.queue_redraw()


## Marks on the back of the street from the level: stairs' doorways and switches ({kind, x, on}).
var marks: Array = []


func set_marks(list: Array) -> void:
	marks = list
	refresh_items()


func _draw_loose() -> void:
	for m in marks:
		var x: float = m["x"]
		if m["kind"] == "doorway":  # a dark doorway in the back wall: the stairs
			loose.draw_rect(Rect2(x - 46, ground_y - 160, 92, 160), Color(0.04, 0.04, 0.06))
			loose.draw_rect(Rect2(x - 46, ground_y - 160, 92, 160), EDGE.lightened(0.3), false, 3.0)
			loose.draw_colored_polygon(PackedVector2Array([Vector2(x - 14, ground_y - 120), Vector2(x + 14, ground_y - 120),
				Vector2(x, ground_y - 140)]), Color(0.7, 0.7, 0.75))
		elif m["kind"] == "switch":  # a panel on the back wall with a lever; green once flipped
			loose.draw_rect(Rect2(x - 22, ground_y - 130, 44, 60), Color(0.3, 0.3, 0.34))
			loose.draw_rect(Rect2(x - 22, ground_y - 130, 44, 60), EDGE, false, 3.0)
			loose.draw_circle(Vector2(x, ground_y - 112), 8.0, Color(0.3, 0.9, 0.4) if m["on"] else Color(0.9, 0.3, 0.3))
	for it in world.items:
		var at := Vector2(it["x"], ground_y + it["z"])
		if it["kind"] == "pipe":
			loose.draw_line(at + Vector2(-46, -4), at + Vector2(46, -10), EDGE, 12.0)
			loose.draw_line(at + Vector2(-44, -4), at + Vector2(44, -10), Color(0.62, 0.64, 0.68), 7.0)
		elif it["kind"] == "soda":  # a can
			loose.draw_rect(Rect2(at + Vector2(-7, -22), Vector2(14, 22)), Color(0.85, 0.2, 0.3))
			loose.draw_rect(Rect2(at + Vector2(-7, -22), Vector2(14, 22)), EDGE, false, 2.0)
		elif it["kind"] == "matchbook":  # a small red book of matches (to collect)
			loose.draw_rect(Rect2(at + Vector2(-10, -8), Vector2(20, 8)), Color(0.8, 0.2, 0.2))
			loose.draw_rect(Rect2(at + Vector2(-10, -8), Vector2(20, 8)), Color(1, 0.9, 0.5), false, 2.0)
		elif it["kind"] == "photo":  # a torn photo (to collect)
			loose.draw_rect(Rect2(at + Vector2(-12, -6), Vector2(24, 6)), Color(0.95, 0.93, 0.85))
			loose.draw_rect(Rect2(at + Vector2(-12, -6), Vector2(24, 6)), EDGE, false, 2.0)
		elif it["kind"] in ["food", "takeaway"]:  # a takeaway box
			loose.draw_rect(Rect2(at + Vector2(-18, -22), Vector2(36, 22)), Color(0.92, 0.9, 0.84))
			loose.draw_rect(Rect2(at + Vector2(-18, -22), Vector2(36, 22)), EDGE, false, 2.0)
			loose.draw_rect(Rect2(at + Vector2(-18, -14), Vector2(36, 5)), Color(0.85, 0.3, 0.25))
		elif it["kind"] == "first_aid":  # a white kit with a red cross
			loose.draw_rect(Rect2(at + Vector2(-20, -24), Vector2(40, 24)), Color(0.95, 0.95, 0.95))
			loose.draw_rect(Rect2(at + Vector2(-20, -24), Vector2(40, 24)), EDGE, false, 2.0)
			loose.draw_rect(Rect2(at + Vector2(-3, -21), Vector2(6, 18)), Color(0.85, 0.15, 0.15))
			loose.draw_rect(Rect2(at + Vector2(-9, -15), Vector2(18, 6)), Color(0.85, 0.15, 0.15))
		else:  # another weapon, by its look in the hand
			loose.draw_line(at + Vector2(-34, -4), at + Vector2(34, -8), EDGE, 10.0)
			loose.draw_line(at + Vector2(-32, -4), at + Vector2(32, -8), Color(0.7, 0.7, 0.72), 5.0)


func _draw_object(n: Node2D, o: Dictionary) -> void:
	var base: Color = COLORS.get(o["kind"], Color(0.5, 0.5, 0.5))
	var near: float = ground_y + o["z1"]
	var far: float = ground_y + o["z0"]
	var w: float = o["x1"] - o["x0"]
	if o["broken"] and o["kind"] != "crate":  # an opened gate or door: only its posts are left
		n.draw_rect(Rect2(o["x0"] - 6, near - 240, 10, 240), base.darkened(0.3))
		n.draw_rect(Rect2(o["x1"] - 4, far - 240, 10, 240), base.darkened(0.3))
		return
	if o["broken"]:
		for i in 4:  # boards on the ground
			var r := Rect2(o["x0"] + i * w * 0.22, near - 14.0 - (i % 2) * 8.0, w * 0.4, 9.0)
			n.draw_rect(r, base.darkened(0.15))
			n.draw_rect(r, EDGE, false, 2.0)
		return
	var top: float = o["top"]
	var top_face := Rect2(o["x0"], far - top, w, near - far)
	var front := Rect2(o["x0"], near - top, w, top)
	n.draw_rect(top_face, base.lightened(0.18))
	n.draw_rect(front, base)
	n.draw_rect(top_face, EDGE, false, 3.0)
	n.draw_rect(front, EDGE, false, 3.0)
	if o["kind"] == "crate":
		n.draw_line(front.position, front.end, EDGE, 3.0)
		n.draw_line(Vector2(front.end.x, front.position.y), Vector2(front.position.x, front.end.y), EDGE, 3.0)
		if o["strength"] < 4:  # cracked by a blow
			n.draw_line(front.position + Vector2(w * 0.3, 10), front.position + Vector2(w * 0.55, top * 0.6), Color(0.9, 0.9, 0.85), 3.0)
	elif o["kind"] == "car":
		for wx in [o["x0"] + w * 0.2, o["x1"] - w * 0.2]:  # wheels
			n.draw_circle(Vector2(wx, near - 4.0), 24.0, Color(0.12, 0.12, 0.14))
		n.draw_rect(Rect2(o["x0"] + w * 0.2, near - top + 12.0, w * 0.6, top * 0.35), base.lightened(0.35))
