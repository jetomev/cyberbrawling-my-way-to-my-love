extends Node2D
## Draws what stands on the street (street_world.gd) as grey boxes with a top and a front, each at its own depth so
## fighters pass in front of or behind it. A broken crate becomes a low heap of boards.

const StreetWorld := preload("res://scripts/sim/street_world.gd")

## The props as the team's props sheet has them (art-in 2026-11-03), in the picked look, "Neon ink" (bold dark
## outlines, two tones, a thin neon rim on the lit edge): a wooden crate, a boxy old car, an orange-and-white road
## barrier, a red hydrant, a green metal dumpster, black speakers. Grey-box stand-ins until the team's pictures land.
const COLORS := {"crate": Color(0.58, 0.44, 0.28), "car": Color(0.36, 0.42, 0.52), "barrier": Color(0.95, 0.5, 0.15),
	"hydrant": Color(0.78, 0.18, 0.16), "dumpster": Color(0.2, 0.42, 0.3), "speaker": Color(0.16, 0.16, 0.2),
	"tank": Color(0.36, 0.55, 0.7), "door_switch": Color(0.85, 0.7, 0.2),
	"toolbox": Color(0.75, 0.15, 0.12), "moped": Color(0.2, 0.55, 0.75), "counter": Color(0.6, 0.75, 0.8),
	"case": Color(0.62, 0.48, 0.3), "sofa": Color(0.45, 0.25, 0.4), "fridge": Color(0.85, 0.86, 0.84),
	"safe": Color(0.3, 0.32, 0.34), "watches": Color(0.5, 0.36, 0.22), "wall": Color(0.22, 0.2, 0.24),
	"stall": Color(0.55, 0.38, 0.24), "fountain": Color(0.55, 0.56, 0.6), "cart": Color(0.45, 0.32, 0.2),
	"tile": Color(0.85, 0.82, 0.72), "table": Color(0.62, 0.5, 0.36)}
const RIM := Color(1.0, 0.24, 0.65)  # the magenta neon rim (#ff3ea5) on the edge facing the signs
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
		if m["kind"] == "wet":  # Big Mama's wet floor by the sink: shiny blue while it's wet
			var c := Color(0.45, 0.7, 1.0, 0.45) if m["on"] else Color(0.5, 0.5, 0.55, 0.15)
			loose.draw_rect(Rect2(m["x"], ground_y + 20.0, m["x1"] - m["x"], 130.0), c)
			if m["on"]:
				for k in 5:
					loose.draw_line(Vector2(m["x"] + 30 + k * 50, ground_y + 50 + (k % 2) * 40), Vector2(m["x"] + 60 + k * 50, ground_y + 50 + (k % 2) * 40), Color(0.85, 0.95, 1.0, 0.7), 3.0)
		elif m["kind"] == "tap":  # the sink's tap on the back wall, dripping
			loose.draw_rect(Rect2(x - 40, ground_y - 110, 80, 40), Color(0.75, 0.78, 0.82))
			loose.draw_rect(Rect2(x - 40, ground_y - 110, 80, 40), EDGE, false, 3.0)
			loose.draw_rect(Rect2(x - 6, ground_y - 140, 12, 30), Color(0.6, 0.62, 0.66))
			loose.draw_circle(Vector2(x, ground_y - 100 + (Time.get_ticks_msec() / 40 % 30)), 4.0, Color(0.5, 0.75, 1.0))
		elif m["kind"] == "ladder":  # the long ladder up to the next floor, against the back wall
			for rx in [x - 30.0, x + 24.0]:
				loose.draw_rect(Rect2(rx, ground_y - 420.0, 6.0, 420.0), Color(0.55, 0.42, 0.25))
			var ry := ground_y - 20.0
			while ry > ground_y - 420.0:
				loose.draw_line(Vector2(x - 30.0, ry), Vector2(x + 30.0, ry), Color(0.6, 0.47, 0.3), 4.0)
				ry -= 34.0
			loose.draw_colored_polygon(PackedVector2Array([Vector2(x - 14, ground_y - 440), Vector2(x + 14, ground_y - 440),
				Vector2(x, ground_y - 462)]), Color(0.7, 0.7, 0.75))
		elif m["kind"] == "doorway":  # a dark doorway in the back wall: the stairs
			loose.draw_rect(Rect2(x - 46, ground_y - 160, 92, 160), Color(0.04, 0.04, 0.06))
			loose.draw_rect(Rect2(x - 46, ground_y - 160, 92, 160), EDGE.lightened(0.3), false, 3.0)
			loose.draw_colored_polygon(PackedVector2Array([Vector2(x - 14, ground_y - 120), Vector2(x + 14, ground_y - 120),
				Vector2(x, ground_y - 140)]), Color(0.7, 0.7, 0.75))
		elif m["kind"] == "switch":  # a panel on the back wall with a lever; green once flipped
			loose.draw_rect(Rect2(x - 22, ground_y - 130, 44, 60), Color(0.3, 0.3, 0.34))
			loose.draw_rect(Rect2(x - 22, ground_y - 130, 44, 60), EDGE, false, 3.0)
			loose.draw_circle(Vector2(x, ground_y - 112), 8.0, Color(0.3, 0.9, 0.4) if m["on"] else Color(0.9, 0.3, 0.3))
	for it in world.items:
		var at := Vector2(it["x"], ground_y + it["z"] - it.get("y", 0.0))  # up on a roof, it's drawn up there
		if it["kind"] == "pipe":
			loose.draw_line(at + Vector2(-46, -4), at + Vector2(46, -10), EDGE, 12.0)
			loose.draw_line(at + Vector2(-44, -4), at + Vector2(44, -10), Color(0.62, 0.64, 0.68), 7.0)
		elif it["kind"] == "soda":  # a can
			loose.draw_rect(Rect2(at + Vector2(-7, -22), Vector2(14, 22)), Color(0.85, 0.2, 0.3))
			loose.draw_rect(Rect2(at + Vector2(-7, -22), Vector2(14, 22)), EDGE, false, 2.0)
		elif it["kind"] == "umbrella":  # a folded umbrella leaning against the wall
			loose.draw_line(at + Vector2(-6, 0), at + Vector2(14, -70), Color(0.85, 0.25, 0.45), 9.0)
			loose.draw_line(at + Vector2(14, -70), at + Vector2(10, -82), Color(0.2, 0.2, 0.25), 3.0)
		elif it["kind"] == "trophy":  # a gold-painted trophy (for score)
			loose.draw_rect(Rect2(at + Vector2(-12, -34), Vector2(24, 18)), Color(0.95, 0.78, 0.2))
			loose.draw_rect(Rect2(at + Vector2(-4, -16), Vector2(8, 10)), Color(0.85, 0.68, 0.15))
			loose.draw_rect(Rect2(at + Vector2(-10, -6), Vector2(20, 6)), Color(0.85, 0.68, 0.15))
			loose.draw_rect(Rect2(at + Vector2(-12, -34), Vector2(24, 34)), EDGE, false, 2.0)
		elif it["kind"] == "matchbook":  # a small red book of matches (to collect)
			loose.draw_rect(Rect2(at + Vector2(-10, -8), Vector2(20, 8)), Color(0.8, 0.2, 0.2))
			loose.draw_rect(Rect2(at + Vector2(-10, -8), Vector2(20, 8)), Color(1, 0.9, 0.5), false, 2.0)
		elif it["kind"] == "photo":  # a torn photo (to collect)
			loose.draw_rect(Rect2(at + Vector2(-12, -6), Vector2(24, 6)), Color(0.95, 0.93, 0.85))
			loose.draw_rect(Rect2(at + Vector2(-12, -6), Vector2(24, 6)), EDGE, false, 2.0)
		elif it["kind"] == "protein_bar":  # a wrapped bar
			loose.draw_rect(Rect2(at + Vector2(-16, -8), Vector2(32, 8)), Color(0.45, 0.3, 0.2))
			loose.draw_rect(Rect2(at + Vector2(-16, -8), Vector2(32, 8)), EDGE, false, 2.0)
			loose.draw_rect(Rect2(at + Vector2(-6, -8), Vector2(12, 8)), Color(0.95, 0.75, 0.2))
		elif it["kind"] in ["shake", "water"]:  # a tall cup with a straw, a water bottle
			var c := Color(0.95, 0.6, 0.75) if it["kind"] == "shake" else Color(0.55, 0.8, 0.95)
			loose.draw_rect(Rect2(at + Vector2(-8, -30), Vector2(16, 30)), c)
			loose.draw_rect(Rect2(at + Vector2(-8, -30), Vector2(16, 30)), EDGE, false, 2.0)
			loose.draw_line(at + Vector2(3, -30), at + Vector2(7, -42), EDGE, 3.0)
		elif it["kind"] in ["mints", "chocolates", "shrimp", "snack"]:  # level 5's food: a bowl, a box, a plate, a bar
			var c2: Color = {"mints": Color(0.95, 0.97, 1.0), "chocolates": Color(0.45, 0.25, 0.15), "shrimp": Color(1.0, 0.6, 0.55),
				"snack": Color(0.95, 0.55, 0.2)}[it["kind"]]
			loose.draw_rect(Rect2(at + Vector2(-16, -12), Vector2(32, 12)), c2)
			loose.draw_rect(Rect2(at + Vector2(-16, -12), Vector2(32, 12)), EDGE, false, 2.0)
		elif it["kind"] in ["coins", "key"]:  # slot coins, the casino key (gold, for score)
			loose.draw_circle(at + Vector2(0, -8), 8.0, Color(0.95, 0.8, 0.2))
			loose.draw_arc(at + Vector2(0, -8), 8.0, 0.0, TAU, 12, EDGE, 2.0)
			if it["kind"] == "key":
				loose.draw_line(at + Vector2(6, -8), at + Vector2(26, -8), Color(0.95, 0.8, 0.2), 4.0)
		elif it["kind"] == "note":  # the vending machine's apology note
			loose.draw_rect(Rect2(at + Vector2(-12, -14), Vector2(24, 14)), Color(1, 1, 0.95))
			loose.draw_rect(Rect2(at + Vector2(-12, -14), Vector2(24, 14)), EDGE, false, 2.0)
		elif it["kind"] == "glove":  # a signed red boxing glove (for score)
			loose.draw_circle(at + Vector2(0, -14), 14.0, Color(0.85, 0.15, 0.15))
			loose.draw_arc(at + Vector2(0, -14), 14.0, 0.0, TAU, 16, EDGE, 2.0)
			loose.draw_line(at + Vector2(-6, -16), at + Vector2(6, -10), Color(1, 1, 1), 2.0)
		elif it["kind"] == "whistle":  # Coach's whistle on its cord (a joke trophy)
			loose.draw_circle(at + Vector2(0, -8), 8.0, Color(0.8, 0.82, 0.86))
			loose.draw_arc(at + Vector2(0, -8), 8.0, 0.0, TAU, 12, EDGE, 2.0)
			loose.draw_arc(at + Vector2(0, -14), 16.0, PI, TAU, 12, Color(0.9, 0.3, 0.3), 2.0)
		elif it["kind"] in ["apple", "bowl"]:  # an apple, a bowl of noodles
			loose.draw_circle(at + Vector2(0, -10), 10.0, Color(0.85, 0.15, 0.2) if it["kind"] == "apple" else Color(0.95, 0.9, 0.7))
			loose.draw_arc(at + Vector2(0, -10), 10.0, 0.0, TAU, 16, EDGE, 2.0)
		elif it["kind"] in ["food", "takeaway", "sandwich"]:  # a takeaway box (a sandwich: drawn the same for now)
			loose.draw_rect(Rect2(at + Vector2(-18, -22), Vector2(36, 22)), Color(0.92, 0.9, 0.84))
			loose.draw_rect(Rect2(at + Vector2(-18, -22), Vector2(36, 22)), EDGE, false, 2.0)
			loose.draw_rect(Rect2(at + Vector2(-18, -14), Vector2(36, 5)), Color(0.85, 0.3, 0.25))
		elif it["kind"] == "rubber_gloves":  # Mr. Static's prize: a pair of thick yellow rubber gloves
			for dx in [-12.0, 12.0]:
				loose.draw_rect(Rect2(at + Vector2(dx - 9, -18), Vector2(18, 18)), Color(0.95, 0.8, 0.15))
				loose.draw_rect(Rect2(at + Vector2(dx - 9, -18), Vector2(18, 18)), EDGE, false, 2.0)
		elif it["kind"] == "first_aid":  # a white kit with a GREEN cross (the team: not red, so it's no real charity's mark)
			loose.draw_rect(Rect2(at + Vector2(-20, -24), Vector2(40, 24)), Color(0.95, 0.95, 0.95))
			loose.draw_rect(Rect2(at + Vector2(-20, -24), Vector2(40, 24)), EDGE, false, 2.0)
			loose.draw_rect(Rect2(at + Vector2(-3, -21), Vector2(6, 18)), Color(0.15, 0.7, 0.3))
			loose.draw_rect(Rect2(at + Vector2(-9, -15), Vector2(18, 6)), Color(0.15, 0.7, 0.3))
		else:  # another weapon, by its look in the hand
			loose.draw_line(at + Vector2(-34, -4), at + Vector2(34, -8), EDGE, 10.0)
			loose.draw_line(at + Vector2(-32, -4), at + Vector2(32, -8), Color(0.7, 0.7, 0.72), 5.0)


func _draw_object(n: Node2D, o: Dictionary) -> void:
	var base: Color = COLORS.get(o["kind"], Color(0.5, 0.5, 0.5))
	var near: float = ground_y + o["z1"]
	var far: float = ground_y + o["z0"]
	var w: float = o["x1"] - o["x0"]
	if o["kind"] == "chandelier":  # (before the broken-door look: a dropped chandelier lies smashed on the floor)
		var top: float = o["top"]
		# crystal on a chain, high over the floor; dropped, it lies smashed below
		var cx: float = (o["x0"] + o["x1"]) * 0.5
		var hang: float = near - top if not o["broken"] else ground_y + 110.0 - 30.0
		if not o["broken"]:
			n.draw_line(Vector2(cx, near - top - 160.0), Vector2(cx, hang), Color(0.6, 0.6, 0.62), 3.0)  # the chain
		for k in 5:
			var a: float = PI * (0.15 + 0.175 * k)
			var tip := Vector2(cx, hang) + Vector2(cos(a), sin(a)) * Vector2(w * 0.6, 40.0) * (1.0 if not o["broken"] else 1.4)
			n.draw_line(Vector2(cx, hang), tip, Color(0.85, 0.9, 1.0), 3.0)
			n.draw_circle(tip, 6.0, Color(0.8, 0.95, 1.0))
		n.draw_circle(Vector2(cx, hang), 12.0, Color(0.95, 0.85, 0.4))
		return
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
	if o["kind"] == "bag":  # level 4's punching bag: drawn swinging every frame in main.gd's flying layer
		return
	if o["kind"] == "gap":  # a gap in the fire escape: the dark street far below shows through (jump it)
		n.draw_rect(Rect2(o["x0"], far, w, near - far), Color(0.04, 0.04, 0.06))
		n.draw_line(Vector2(o["x0"], far), Vector2(o["x0"], near), Color(0.5, 0.5, 0.55), 4.0)
		n.draw_line(Vector2(o["x1"], far), Vector2(o["x1"], near), Color(0.5, 0.5, 0.55), 4.0)
		return
	if o["kind"] == "stairs":  # a flight up the back of the room: treads and risers, the landing, a banister in front
		_draw_stairs(n, o, near, far)
		return
	if o["kind"] == "ladder":  # two rails and rungs, leaning on what it reaches
		for rx in [o["x0"], o["x1"] - 6.0]:
			n.draw_rect(Rect2(rx, near - top, 6.0, top), Color(0.55, 0.42, 0.25))
			n.draw_rect(Rect2(rx, near - top, 6.0, top), EDGE, false, 2.0)
		var ry := near - 20.0
		while ry > near - top:
			n.draw_line(Vector2(o["x0"], ry), Vector2(o["x1"], ry), Color(0.6, 0.47, 0.3), 4.0)
			ry -= 34.0
		return
	if o["kind"] == "balcony":  # a deck across the back of the room on slim columns, a brass rail along its edge
		n.draw_rect(Rect2(o["x0"], far - top, w, near - far), Color(0.42, 0.3, 0.35))  # the deck
		n.draw_rect(Rect2(o["x0"], near - top, w, 18.0), Color(0.55, 0.4, 0.45))  # its front edge
		n.draw_rect(Rect2(o["x0"], far - top, w, near - far + 18.0), EDGE, false, 3.0)
		var px: float = o["x0"] + 20.0
		while px < o["x1"]:
			n.draw_rect(Rect2(px, near - top + 18.0, 10.0, top - 18.0), Color(0.3, 0.26, 0.3))  # the columns
			px += 240.0
		n.draw_line(Vector2(o["x0"], near - top - 50.0), Vector2(o["x1"], near - top - 50.0), Color(0.85, 0.7, 0.3), 4.0)  # the rail
		return
	if o["kind"] == "awning":  # a stall's striped canopy roof up high, the stall under it open
		var roof := Rect2(o["x0"], far - top, w, near - far)
		n.draw_rect(Rect2(o["x0"], near - top, w, 26.0), Color(0.85, 0.25, 0.4))
		for i in int(w / 40.0):
			if i % 2 == 0:
				n.draw_rect(Rect2(o["x0"] + i * 40.0, near - top, 40.0, 26.0), Color(0.95, 0.92, 0.85))
		n.draw_rect(roof, Color(0.7, 0.2, 0.32))
		n.draw_rect(roof, EDGE, false, 3.0)
		n.draw_rect(Rect2(o["x0"], near - top, w, 26.0), EDGE, false, 3.0)
		for px in [o["x0"] + 6.0, o["x1"] - 12.0]:
			n.draw_rect(Rect2(px, near - top + 26.0, 6.0, top - 26.0), Color(0.3, 0.3, 0.34))
		return
	var top_face := Rect2(o["x0"], far - top, w, near - far)
	var front := Rect2(o["x0"], near - top, w, top)
	n.draw_rect(top_face, base.lightened(0.18))
	n.draw_rect(front, base)
	n.draw_rect(Rect2(front.position + Vector2(front.size.x * 0.6, 0), Vector2(front.size.x * 0.4, front.size.y)), base.darkened(0.25))  # the shadow tone
	n.draw_line(front.position + Vector2(2, 2), Vector2(front.position.x + 2, front.end.y - 2), RIM, 3.0)  # the rim on the lit edge
	n.draw_line(top_face.position + Vector2(2, 2), Vector2(top_face.end.x - 2, top_face.position.y + 2), RIM, 2.0)
	if o["kind"] == "barrier":  # orange and white stripes
		var stripes := int(top / 40.0)
		for i in stripes:
			if i % 2 == 1:
				n.draw_rect(Rect2(front.position.x, front.position.y + i * 40.0, w, 40.0), Color(0.95, 0.95, 0.92))
	n.draw_rect(top_face, EDGE, false, 4.0)
	n.draw_rect(front, EDGE, false, 4.0)
	if o["kind"] == "crate":
		n.draw_line(front.position, front.end, EDGE, 3.0)
		n.draw_line(Vector2(front.end.x, front.position.y), Vector2(front.position.x, front.end.y), EDGE, 3.0)
		if o["strength"] < 4:  # cracked by a blow
			n.draw_line(front.position + Vector2(w * 0.3, 10), front.position + Vector2(w * 0.55, top * 0.6), Color(0.9, 0.9, 0.85), 3.0)
	elif o["kind"] == "car":
		for wx in [o["x0"] + w * 0.2, o["x1"] - w * 0.2]:  # wheels
			n.draw_circle(Vector2(wx, near - 4.0), 24.0, Color(0.12, 0.12, 0.14))
		n.draw_rect(Rect2(o["x0"] + w * 0.2, near - top + 12.0, w * 0.6, top * 0.35), base.lightened(0.35))


## The stairs (the team's level 3 page): steps of about 40 px from the foot up to the landing, the space under the
## flight closed in dark, a banister on the front side in the neon-ink rim.
const STEP_W := 40.0
const WOOD := Color(0.42, 0.3, 0.22)


func _draw_stairs(n: Node2D, o: Dictionary, near: float, far: float) -> void:
	var land_x: float = o["x1"] - StreetWorld.LANDING
	var side := PackedVector2Array([Vector2(o["x0"], near), Vector2(land_x, near - o["top"]), Vector2(o["x1"], near - o["top"]),
		Vector2(o["x1"], near)])
	n.draw_colored_polygon(side, WOOD.darkened(0.45))  # the flight's side, closed underneath
	var x: float = o["x0"]
	while x < land_x - 0.5:
		var h: float = StreetWorld.step_height(o, minf(x + STEP_W, land_x))
		var w: float = minf(STEP_W, land_x - x)
		n.draw_rect(Rect2(x, far - h, w, near - far), WOOD.lightened(0.15))  # the tread
		n.draw_rect(Rect2(x, near - h, w, h - StreetWorld.step_height(o, x) + 2.0), WOOD)  # the riser
		n.draw_rect(Rect2(x, far - h, w, near - far), EDGE, false, 2.0)
		x += STEP_W
	n.draw_rect(Rect2(land_x, far - o["top"], o["x1"] - land_x, near - far), WOOD.lightened(0.2))  # the landing
	n.draw_rect(Rect2(land_x, far - o["top"], o["x1"] - land_x, near - far), EDGE, false, 3.0)
	n.draw_polyline(side, EDGE, 4.0)
	var rail := 90.0  # the banister, along the front edge, a hand's height above the steps
	n.draw_line(Vector2(o["x0"], near - rail), Vector2(land_x, near - o["top"] - rail), RIM, 4.0)
	n.draw_line(Vector2(land_x, near - o["top"] - rail), Vector2(o["x1"], near - o["top"] - rail), RIM, 4.0)
	var px: float = o["x0"]
	while px <= land_x:
		var h: float = StreetWorld.step_height(o, px)
		n.draw_line(Vector2(px, near - h), Vector2(px, near - h - rail), EDGE, 3.0)
		px += STEP_W * 3.0
