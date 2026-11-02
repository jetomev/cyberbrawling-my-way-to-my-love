extends Node2D
## The grey-box street: a far wall of grey blocks, the shallow street you walk on, a curb, lane marks every few
## steps, and a few crates so walking reads as moving. Flat shapes only; the layered art comes in Stage 3.

const GROUND_Y := 760.0  # screen line of the street's far edge (z = 0)

var length := 3840.0
var depth := 160.0


func setup(street_length: float, street_depth: float) -> void:
	length = street_length
	depth = street_depth
	queue_redraw()


func _draw() -> void:
	var near := GROUND_Y + depth
	draw_rect(Rect2(-400, 0, length + 800, GROUND_Y), Color(0.10, 0.10, 0.14))  # night sky
	var rng := RandomNumberGenerator.new()
	rng.seed = 7  # the same skyline every run
	var bx := -400.0
	while bx < length + 400.0:  # far buildings
		var w := rng.randf_range(160, 340)
		var h := rng.randf_range(220, 520)
		draw_rect(Rect2(bx, GROUND_Y - h, w - 12, h), Color(0.19, 0.19, 0.24))
		for wy in range(int(GROUND_Y - h + 30), int(GROUND_Y - 60), 54):
			for wx in range(int(bx + 20), int(bx + w - 40), 46):
				if rng.randf() < 0.3:
					draw_rect(Rect2(wx, wy, 18, 24), Color(0.30, 0.30, 0.36))
		bx += w
	draw_rect(Rect2(-400, GROUND_Y - 36, length + 800, 36), Color(0.27, 0.27, 0.31))  # sidewalk
	draw_rect(Rect2(-400, GROUND_Y, length + 800, depth), Color(0.34, 0.34, 0.38))  # the street
	draw_rect(Rect2(-400, near, length + 800, 1080 - near), Color(0.22, 0.22, 0.26))  # near curb and gutter
	draw_line(Vector2(-400, near), Vector2(length + 400, near), Color(0.5, 0.5, 0.55), 4.0)
	var mark := 0.0
	while mark < length:  # lane marks every 240 px: they show speed and position
		draw_rect(Rect2(mark, GROUND_Y + depth * 0.5 - 3, 110, 6), Color(0.52, 0.52, 0.56))
		mark += 240.0
	for cx in [900.0, 1700.0, 2600.0, 3300.0]:  # crates against the far wall
		draw_rect(Rect2(cx, GROUND_Y - 96, 110, 96), Color(0.45, 0.42, 0.38))
		draw_rect(Rect2(cx, GROUND_Y - 96, 110, 96), Color(0.1, 0.1, 0.1), false, 3.0)
