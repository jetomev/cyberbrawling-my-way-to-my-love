extends Node2D
## The grey-box street in layers (docs/STYLE.md, The layers): the sky, the far skyline, the block across the street,
## the shopfronts right behind the fighters, the street itself, and a foreground of lampposts that passes in front of
## them. Each layer slides at its own speed as the camera moves (follow()), so the city has depth; the street you walk
## on moves with the world. Flat grey shapes only: the team's level art replaces each layer (Stage 3). What stands on
## the street is obstacles_view.gd.

const GROUND_Y := 760.0  # screen line of the street's far edge (z = 0)
## [name, how fast it slides against the camera (1 = with the street), drawn in front of the fighters]
const LAYERS := [["sky", 0.0, false], ["far", 0.15, false], ["mid", 0.45, false], ["wall", 0.8, false],
	["fore", 1.25, true]]
const SPAN := 1300.0  # each layer is drawn this far past the screen's edges

var length := 3840.0
var depth := 160.0
var layers := {}  # name -> its Node2D


func _ready() -> void:
	for spec in LAYERS:
		var n := Node2D.new()
		n.name = spec[0]
		n.z_index = 900 if spec[2] else -5  # behind the street's own drawing, or in front of everyone
		n.draw.connect(_draw_layer.bind(n, spec[0], spec[1]))
		add_child(n)
		layers[spec[0]] = n


func setup(street_length: float, street_depth: float) -> void:
	length = street_length
	depth = street_depth
	queue_redraw()
	for n in layers.values():
		n.queue_redraw()


## Slides every layer for the camera's centre x: a layer at speed f is seen to move f px for each px of camera.
func follow(camera_x: float) -> void:
	for spec in LAYERS:
		layers[spec[0]].position.x = camera_x * (1.0 - spec[1])


## Where a layer at speed f draws, along x in its own space, to cover the whole street's camera travel.
func _span(f: float) -> Vector2:
	return Vector2(-SPAN, length * f + SPAN)


func _draw_layer(n: Node2D, name: String, f: float) -> void:
	var s := _span(f)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)  # the same city every run
	match name:
		"sky":
			n.draw_rect(Rect2(-SPAN, 0, 2 * SPAN, GROUND_Y), Color(0.09, 0.09, 0.13))
			n.draw_rect(Rect2(-SPAN, GROUND_Y - 260, 2 * SPAN, 260), Color(0.12, 0.11, 0.17))  # the city's glow
		"far":  # a hazy skyline, small and pale
			var bx := s.x
			while bx < s.y:
				var w := rng.randf_range(70, 160)
				var h := rng.randf_range(160, 380)
				n.draw_rect(Rect2(bx, GROUND_Y - 120 - h, w, h + 120), Color(0.15, 0.15, 0.2))
				bx += w + rng.randf_range(-8, 10)
		"mid":  # the block across the street: tall, windows, a few lit
			var bx := s.x
			while bx < s.y:
				var w := rng.randf_range(220, 380)
				var h := rng.randf_range(260, 480)
				n.draw_rect(Rect2(bx, GROUND_Y - 40 - h, w - 14, h), Color(0.19, 0.19, 0.24))
				for wy in range(int(GROUND_Y - 40 - h + 30), int(GROUND_Y - 120), 56):
					for wx in range(int(bx + 22), int(bx + w - 50), 50):
						n.draw_rect(Rect2(wx, wy, 20, 26), Color(0.36, 0.34, 0.3) if rng.randf() < 0.22 else Color(0.25, 0.25, 0.3))
				bx += w
		"wall":  # the shopfronts right behind the fighters: a sidewalk, shutters, doors, lit windows
			n.draw_rect(Rect2(s.x, GROUND_Y - 150, s.y - s.x, 150), Color(0.23, 0.23, 0.28))
			var x := s.x
			while x < s.y:
				var kind := rng.randi_range(0, 2)
				var w := rng.randf_range(220, 320)
				if kind == 0:  # a rolled-down shutter
					n.draw_rect(Rect2(x + 20, GROUND_Y - 128, w - 40, 128), Color(0.3, 0.3, 0.34))
					for ly in range(int(GROUND_Y - 120), int(GROUND_Y), 12):
						n.draw_line(Vector2(x + 20, ly), Vector2(x + w - 20, ly), Color(0.22, 0.22, 0.26), 2.0)
				elif kind == 1:  # a lit shop window
					n.draw_rect(Rect2(x + 20, GROUND_Y - 128, w - 40, 96), Color(0.38, 0.36, 0.3))
					n.draw_rect(Rect2(x + 20, GROUND_Y - 150, w - 40, 22), Color(0.32, 0.3, 0.36))
				else:  # a door
					n.draw_rect(Rect2(x + w * 0.4, GROUND_Y - 140, 90, 140), Color(0.15, 0.15, 0.19))
				x += w
			n.draw_rect(Rect2(s.x, GROUND_Y - 30, s.y - s.x, 30), Color(0.27, 0.27, 0.31))  # the sidewalk
		"fore":  # lampposts passing in front: dark, thin, far apart, so they never hide a fight for long
			var x := s.x + 400.0
			while x < s.y:
				n.draw_rect(Rect2(x, 120, 22, 960), Color(0.05, 0.05, 0.07, 0.85))
				n.draw_rect(Rect2(x - 70, 110, 92, 16), Color(0.05, 0.05, 0.07, 0.85))
				n.draw_circle(Vector2(x - 66, 132), 14.0, Color(0.55, 0.5, 0.36, 0.6))
				x += rng.randf_range(1500, 2100)


func _draw() -> void:  # the street itself, at the world's own speed
	var near := GROUND_Y + depth
	draw_rect(Rect2(-SPAN, GROUND_Y, length + 2 * SPAN, depth), Color(0.34, 0.34, 0.38))  # the street
	draw_rect(Rect2(-SPAN, near, length + 2 * SPAN, 1080 - near), Color(0.22, 0.22, 0.26))  # near curb and gutter
	draw_line(Vector2(-SPAN, near), Vector2(length + SPAN, near), Color(0.5, 0.5, 0.55), 4.0)
	var mark := 0.0
	while mark < length:  # lane marks every 240 px: they show speed and position
		draw_rect(Rect2(mark, GROUND_Y + depth * 0.5 - 3, 110, 6), Color(0.52, 0.52, 0.56))
		mark += 240.0
