#!/usr/bin/env python3
"""Close-ups of the hips, hands and feet for every move in the recorded demo (D-22). Javier & Claude.

The assistant team's first ask (2026-11-02): the hero is small in the demo frame, so every build also carries close-up
stills. For each move, one row of four panels at the moment it lands: the whole body, the hips, both hands, both feet.
The demo writes where those parts are on every frame (`--marks`, in the 1920x1080 game's pixels); this scales them to
the movie's size and cuts the panels with ffmpeg.

Usage: scripts/closeups.py <frames dir> <marks file> <out dir> move:frame [move:frame ...]
Writes <out dir>/closeups/NN-<move>.png (one row each) and <out dir>/closeups.png (all rows). Prints OK and the count.
"""
import struct
import subprocess
import sys
from pathlib import Path

GAME_W, GAME_H = 1920, 1080
PANEL = 320  # each panel's side, in the picture the reviewers see
PARTS = ["hip", "hand_f", "hand_b", "foot_f", "foot_b"]


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    return struct.unpack(">II", head[16:24])


def read_marks(path):
    marks = {}
    for line in Path(path).read_text().splitlines():
        if line.startswith("#") or not line.strip():
            continue
        n = [int(v) for v in line.split()]
        marks[n[0]] = {p: (n[2 + 2 * i], n[3 + 2 * i]) for i, p in enumerate(PARTS)}
    return marks


def square(points, pad, least, w, h, lift=0):
    """A square around the points, padded, at least `least` wide, kept inside the frame (lift raises its top)."""
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    top = min(ys) - pad - lift
    side = max(max(xs) - min(xs) + 2 * pad, max(ys) - top + pad, least)
    side = int(min(side, w, h))
    cx = (min(xs) + max(xs)) / 2
    cy = (top + max(ys) + pad) / 2
    x = int(min(max(cx - side / 2, 0), w - side))
    y = int(min(max(cy - side / 2, 0), h - side))
    return side, x, y


def main():
    if len(sys.argv) < 5:
        sys.exit(__doc__)
    frames, marks_file, out = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
    marks = read_marks(marks_file)
    rows = out / "closeups"
    rows.mkdir(parents=True, exist_ok=True)
    made = []
    for n, item in enumerate(sys.argv[4:]):
        move, frame = item.split(":")
        frame = int(frame)
        if frame not in marks:
            sys.exit(f"FAILED no marks for {move} at frame {frame}")
        still = frames / f"f{frame:08d}.png"
        w, h = png_size(still)
        k = w / GAME_W  # the movie can be smaller than the game
        at = {p: (x * k, y * k) for p, (x, y) in marks[frame].items()}
        u = h / GAME_H * 100  # one unit: a tenth of the fighter's height, give or take
        panels = [
            ("whole body", square(list(at.values()), 0.45 * u, 2.6 * u, w, h, lift=1.1 * u)),
            ("hips", square([at["hip"]], 0.9 * u, 1.8 * u, w, h)),
            ("hands", square([at["hand_f"], at["hand_b"]], 0.4 * u, 1.5 * u, w, h)),
            ("feet", square([at["foot_f"], at["foot_b"]], 0.4 * u, 1.5 * u, w, h)),
        ]
        chains = []
        for i, (label, (side, x, y)) in enumerate(panels):
            text = f"{move} · {label}" if i == 0 else label
            chains.append(
                f"[s{i}]crop={side}:{side}:{x}:{y},scale={PANEL}:{PANEL}:flags=lanczos,"
                f"drawtext=text='{text}':x=8:y=8:fontsize=20:fontcolor=white:box=1:boxcolor=black@0.55[p{i}]"
            )
        graph = "[0]split=4[s0][s1][s2][s3];" + ";".join(chains) + ";[p0][p1][p2][p3]hstack=inputs=4"
        row = rows / f"{n:02d}-{move}.png"
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(still), "-filter_complex", graph,
                        "-frames:v", "1", str(row)], check=True)
        made.append(row)
    inputs = []
    for row in made:
        inputs += ["-i", str(row)]
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", *inputs, "-filter_complex",
                    f"vstack=inputs={len(made)}" if len(made) > 1 else "null", "-frames:v", "1",
                    str(out / "closeups.png")], check=True)
    print(f"OK {len(made)} close-up rows: {out / 'closeups.png'}")


if __name__ == "__main__":
    main()
