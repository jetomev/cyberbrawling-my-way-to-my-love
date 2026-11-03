#!/usr/bin/env python3
"""The sweep seen from above (the testers, 2026-11-02 23:29: "the sweep from a clearer angle, so its circle shows").
Javier & Claude.

The game draws only from the side. This reads, per frame, the body's spin and the sweeping foot's reach forward of the
hips in the body's own frame (game/tools/sweep_above.gd), turns the reach by the spin, and draws the foot's path from
above: the hips in the middle, the way he faces, a dot a frame with times, the target's ankles ahead. Worked out from
the pose's numbers, not drawn by the game; the picture says so.

Usage: scripts/sweep_above.py <tool output file> <out.png>
"""
import math
import sys

from PIL import Image, ImageDraw

rows = []
hit = None
for line in open(sys.argv[1]):
    parts = line.split()
    if len(parts) == 3:
        rows.append((int(parts[0]), float(parts[1]), float(parts[2])))
    elif len(parts) == 2 and parts[0] == "hit":
        hit = int(parts[1])
if not rows or hit is None:
    sys.exit("FAILED no sweep frames from the tool")
W, H, S = 760, 820, 2.2  # picture size, px per game px
cx, cy = W // 2, 420
img = Image.new("RGB", (W, H), (26, 26, 32))
d = ImageDraw.Draw(img)
d.text((16, 14), "The sweep, seen from above (worked out from the pose's numbers: the spin and the foot's reach;", fill=(240, 220, 140))
d.text((16, 32), "the game itself draws only from the side). A dot a frame; times from the hit; he faces up.", fill=(240, 220, 140))
for r in (60, 120):
    d.ellipse([cx - r * S, cy - r * S, cx + r * S, cy + r * S], outline=(55, 55, 66))
d.line([(cx, cy), (cx, cy - 150 * S)], fill=(90, 90, 110), width=2)
d.polygon([(cx, cy - 158 * S), (cx - 8, cy - 140 * S), (cx + 8, cy - 140 * S)], fill=(90, 90, 110))
d.text((cx + 10, cy - 156 * S), "facing (toward the enemy)", fill=(150, 150, 170))
ty = cy - 120 * S
d.ellipse([cx - 14, ty - 8, cx + 14, ty + 8], outline=(220, 110, 90), width=3)
d.text((cx + 18, ty - 6), "the enemy's ankles", fill=(220, 110, 90))
d.ellipse([cx - 9, cy - 9, cx + 9, cy + 9], fill=(200, 200, 210))
d.text((cx + 12, cy + 4), "his hips", fill=(200, 200, 210))
prev = None
n = len(rows)
for i, (tick, spin, reach) in enumerate(rows):
    a = math.radians(spin)
    # the body-frame forward reach turned by the spin; up the picture is the way he faces (spin 0)
    x, y = reach * math.sin(a), -reach * math.cos(a)
    px, py = cx + x * S, cy + y * S
    shade = int(90 + 165 * i / max(n - 1, 1))
    col = (255, 210, 120) if tick == hit else (shade, shade, 255)
    if prev:
        d.line([prev, (px, py)], fill=(110, 110, 150), width=2)
    d.ellipse([px - 5, py - 5, px + 5, py + 5], fill=col)
    if tick % 3 == 0 or tick == hit:
        ms = round((tick - hit) * 1000 / 60)
        d.text((px + 7, py - 7), "HIT" if tick == hit else f"{ms:+d}", fill=col)
    prev = (px, py)
img.save(sys.argv[2])
print(f"OK the sweep from above: {sys.argv[2]}")
