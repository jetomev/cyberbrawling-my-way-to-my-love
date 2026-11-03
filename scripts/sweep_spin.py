#!/usr/bin/env python3
"""The sweep's spin, frame by frame, with the whole circle in view (the testers, 02:29 on 0922751: "consecutive frames
of the spin at both speeds, keeping the full circle in view"). Javier & Claude.

Every frame of the sweep from the demo, a few before and after: on the left the game's side view with the street held
still (as the street-fixed sheets), on the right the foot's whole circle seen from above (worked out from the pose's
spin and the foot's reach, game/tools/sweep_above.gd) with that frame's place on it lit. All the frames on one sheet,
timed from the hit, and clips of the same at full and at half speed.

Usage: scripts/sweep_spin.py <frames dir> <marks file> <sweep_above.txt> <sweep:hit:start:end> <out.png> <out.mp4>
"""
import math
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from closeups import CLIP_PAD, GAME_H, GAME_W, PARTS, read_marks

TILE_H = 300
COLUMNS = 5


def above(rows, hit, now, size):
    """The circle from above: every frame's foot place faint, this frame's lit; he faces up."""
    img = Image.new("RGB", (size, size), (26, 26, 32))
    d = ImageDraw.Draw(img)
    c, s = size / 2, size / 2 / 130.0
    for r in (60, 120):
        d.ellipse([c - r * s, c - r * s, c + r * s, c + r * s], outline=(55, 55, 66))
    d.line([(c, c), (c, c - 125 * s)], fill=(90, 90, 110), width=2)
    d.ellipse([c - 10, c - 120 * s - 5, c + 10, c - 120 * s + 5], outline=(220, 110, 90), width=2)
    d.ellipse([c - 5, c - 5, c + 5, c + 5], fill=(200, 200, 210))
    pts = {}
    for tick, spin, reach in rows:
        a = math.radians(spin)
        pts[tick] = (c + reach * math.sin(a) * s, c - reach * math.cos(a) * s)
    order = sorted(pts)
    d.line([pts[t] for t in order], fill=(80, 80, 120), width=2)
    for t in order:
        x, y = pts[t]
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(110, 110, 160))
    if now in pts:
        x, y = pts[now]
        col = (255, 210, 120) if now == hit else (150, 200, 255)
        d.line([(c, c), (x, y)], fill=col, width=3)
        d.ellipse([x - 8, y - 8, x + 8, y + 8], fill=col)
    return img


def main():
    if len(sys.argv) != 7:
        sys.exit(__doc__)
    frames, marks = Path(sys.argv[1]), read_marks(sys.argv[2])
    rows, hit = [], None
    for line in open(sys.argv[3]):
        parts = line.split()
        if len(parts) == 3:
            rows.append((int(parts[0]), float(parts[1]), float(parts[2])))
        elif len(parts) == 2 and parts[0] == "hit":
            hit = int(parts[1])
    name, land, start, end = sys.argv[4].split(":")
    land, start, end = int(land), int(start), int(end)
    sheet_path, clip_path = Path(sys.argv[5]), Path(sys.argv[6])
    span = [f for f in range(start - CLIP_PAD, end + CLIP_PAD + 1) if (frames / f"f{f:08d}.png").exists()]
    if not rows or hit is None or not span or not all("street" in marks.get(f, {}) for f in span):
        sys.exit("FAILED no sweep frames, circle or street marks")
    w, h = Image.open(frames / f"f{span[0]:08d}.png").size
    k, u = w / GAME_W, h / GAME_H * 100
    sx0 = marks[span[0]]["street"][0] * k
    world = [(x * k - (marks[f]["street"][0] * k - sx0), y * k) for f in span for n, (x, y) in marks[f].items() if n in PARTS]
    pad = 0.7 * u
    x0, x1 = min(p[0] for p in world) - pad, max(p[0] for p in world) + pad
    y0, y1 = min(p[1] for p in world) - pad, max(p[1] for p in world) + pad
    bw, bh = int(x1 - x0), int(y1 - y0)
    tw = max(1, round(bw * TILE_H / bh))
    font = ImageFont.load_default(size=18)
    tiles = []
    for f in span:
        img = Image.open(frames / f"f{f:08d}.png").convert("RGB")
        dx = marks[f]["street"][0] * k - sx0
        side = img.crop((int(x0 + dx), int(y0), int(x0 + dx) + bw, int(y0) + bh)).resize((tw, TILE_H))
        tile = Image.new("RGB", (tw + TILE_H, TILE_H), (22, 22, 28))
        tile.paste(side, (0, 0))
        tick = f - land + hit  # the sweep's own frame, lined up on the hit
        tile.paste(above(rows, hit, tick, TILE_H), (tw, 0))
        dd = ImageDraw.Draw(tile)
        ms = round((f - land) * 1000 / 60)
        dd.rectangle([0, 0, 300, 26], fill=(0, 0, 0))
        dd.text((6, 4), "HIT" if f == land else f"sweep {ms:+d} ms", fill=(255, 255, 255), font=font)
        dd.text((tw + 6, TILE_H - 24), "from above", fill=(150, 150, 170), font=font)
        tiles.append(tile)
    tw2 = tw + TILE_H
    sheet = Image.new("RGB", (COLUMNS * (tw2 + 3), -(-len(tiles) // COLUMNS) * (TILE_H + 3)), (16, 16, 22))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % COLUMNS) * (tw2 + 3), (i // COLUMNS) * (TILE_H + 3)))
    sheet.save(sheet_path)
    tmp = clip_path.parent / ".sweep-spin"
    tmp.mkdir(exist_ok=True)
    for i, t in enumerate(tiles):
        t.resize((tw2 // 2 * 2, TILE_H)).save(tmp / f"f{i:05d}.png")
    for speed, suffix in [(1, ""), (2, "-half")]:
        vf = (f"setpts={speed}*PTS," if speed > 1 else "") + "format=yuv420p"
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", "60", "-i", str(tmp / "f%05d.png"),
                        "-vf", vf, "-r", "60", "-c:v", "libx264",
                        str(clip_path.with_name(clip_path.stem + suffix + ".mp4"))], check=True)
    for png in tmp.glob("f*.png"):
        png.unlink()
    tmp.rmdir()
    print(f"OK the sweep's spin with its circle: {sheet_path} ({len(tiles)} frames), {clip_path.name} and -half")


if __name__ == "__main__":
    main()
