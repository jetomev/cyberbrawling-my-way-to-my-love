#!/usr/bin/env python3
"""Our hero beside the recording he was measured from, frame by frame (D-30). Javier & Claude.

The testers' ask (2026-11-02): the recorded skeleton BESIDE the hero, at the same moments, the same scale. For each of
the moves drawn from recorded motion, one picture: the hero from the demo's own frames on top, the recording below,
as a stick figure scaled so both bodies have the same leg length (thigh and shin), standing on the same street line,
centred on the hips.

"The same moment" is the same point in the move: the two are lined up on its events (for a jump: the crouch, the
take-off, the top, the touchdown, the deepest of the landing, back up) and spread evenly between them, because a game
jump is not timed like a real one. Each column says both times, so where the timing differs it shows.

Reference only: the recordings (CMU, mocap.cs.cmu.edu) are read from outside this repository (scripts/mocap_ref.py);
these pictures go to the build's folder in ~/Documents/Cyberbrawling/builds, never into the game.

Usage: scripts/reference_strips.py <frames dir> <marks file> <out dir> <demo moments...>
Writes <out dir>/reference/NN-<move>-side-by-side.png. Prints an OK line.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import closeups  # noqa: E402  (the marks, the crops)
import mocap_ref  # noqa: E402  (the recordings)

from PIL import Image, ImageDraw  # noqa: E402

CELL = 220
COLUMNS = 13


def anchors_for(name, win):
    """Pairs (hero movie frame, recording ms) the move is lined up on, from the demo's own moments."""
    land, start, end = win
    if name == "jump":  # the crate jump (crouch at start, touchdown at land) and CMU 16_05, a forward jump
        return "16_05", [(start, 750), (start + 4, 1175), (start + 24, 1325), (land, 1525), (land + 4, 1700),
                         (land + 14, 1800)], start - 2, end
    if name == "flying_kick":  # the flying kick (it starts at start, lands its blow at land) and CMU 135_04's kick
        return "135_04", [(start, 2950), (start + 6, 3100), (start + 11, 3150), (start + 16, 3250),
                          (start + 23, 3400)], start - 3, start + 26
    if name == "walk":  # the everyday walk: the front heel strikes 26 frames into its cycle; CMU 16_15
        return "16_15", [(start + 26, 1100), (start + 90, 2250)], start + 4, min(end, start + 4 + 64)
    if name == "stance":  # the guard, and CMU 135_04's stance before its first kick
        return "135_04", [(start, 0), (end, (end - start) * 1000.0 / 60.0)], start, end
    raise KeyError(name)


def ms_at(anchors, frame):
    """The recording's time for a hero frame: straight lines between the anchors (and beyond the ends)."""
    pts = sorted(anchors)
    if frame <= pts[0][0]:
        (f0, m0), (f1, m1) = pts[0], pts[1]
    elif frame >= pts[-1][0]:
        (f0, m0), (f1, m1) = pts[-2], pts[-1]
    else:
        for a, b in zip(pts, pts[1:]):
            if a[0] <= frame <= b[0]:
                (f0, m0), (f1, m1) = a, b
                break
    return m0 + (m1 - m0) * (frame - f0) / max(f1 - f0, 1)


def main():
    if len(sys.argv) < 5:
        sys.exit(__doc__)
    frames, marks, out = Path(sys.argv[1]), closeups.read_marks(sys.argv[2]), Path(sys.argv[3])
    wins = {}
    for item in sys.argv[4:]:
        name, land, start, end = item.split(":")
        key = {"plainjump": "jump", "air_kick": "flying_kick", "stroll-cycle-frames": "walk",
               "idle-cycle-frames": "stance"}.get(name)
        if key:
            wins[key] = (int(land), int(start), int(end))
    (out / "reference").mkdir(parents=True, exist_ok=True)
    made = 0
    for n, name in enumerate(["jump", "flying_kick", "walk", "stance"]):
        if name not in wins:
            continue
        take, anchors, first, last = anchors_for(name, wins[name])
        hero_frames = sorted({round(first + i * (last - first) / (COLUMNS - 1)) for i in range(COLUMNS)})
        hero_frames = [f for f in hero_frames if f in marks]
        w, h = closeups.png_size(frames / f"f{hero_frames[0]:08d}.png")
        k = w / closeups.GAME_W
        u = h / closeups.GAME_H * 100
        pts = [{p: (x * k, y * k) for p, (x, y) in marks[f].items()} for f in hero_frames]
        side, bx, by = closeups.boxes(pts, u, w, h)[0]
        zoom = CELL / side
        # the same body size: the same leg length (our rig's thigh and shin are 62 + 58 px in the 1920x1080 game; the
        # recording's are measured on its first frame). (Hip heights don't compare: the hero's guard is a crouch.)
        hero_leg = 120.0 * k * zoom
        skel, rec = mocap_ref.load(take)
        view = mocap_ref.side_view(skel, rec)
        r0 = view[0]
        rec_leg = sum(((r0[b][0] - r0[a][0]) ** 2 + (r0[b][1] - r0[a][1]) ** 2) ** 0.5
                      for a, b in [("lhipjoint", "lfemur"), ("lfemur", "ltibia")])
        scale = hero_leg / rec_leg
        # the street line: the hero's ankles on his first (standing) frame; the camera never moves up or down
        street = (max(pts[0]["foot_f"][1], pts[0]["foot_b"][1]) - by) * zoom
        sheet = Image.new("RGB", (CELL * len(hero_frames), CELL * 2 + 36), (34, 34, 42))
        d = ImageDraw.Draw(sheet)
        for c, f in enumerate(hero_frames):
            img = Image.open(frames / f"f{f:08d}.png").convert("RGB").crop((bx, by, bx + side, by + side))
            sheet.paste(img.resize((CELL, CELL)), (c * CELL, 0))
            p = pts[c]
            hip_x = (p["hip"][0] - bx) * zoom
            ms = ms_at(anchors, f)
            i = max(0, min(len(view) - 1, round(ms * mocap_ref.FPS / 1000.0)))
            q = view[i]
            ox, oy = c * CELL + hip_x, CELL + 18
            gy = oy + street
            d.line([(c * CELL, gy), ((c + 1) * CELL, gy)], fill=(80, 80, 92), width=2)
            rx, ry = q["root"]

            def at(j):
                return (ox + (q[j][0] - rx) * scale, gy - q[j][1] * scale)
            for a1, b1 in mocap_ref.LINKS:
                near = a1[0] == "l" or b1[0] == "l"
                d.line([at(a1), at(b1)], fill=(225, 225, 235) if near else (125, 125, 145), width=4)
            hx, hy = at("head")
            r = 0.9 * scale
            d.ellipse([hx - r, hy - r, hx + r, hy + r], outline=(225, 225, 235), width=3)
            hero_ms = (f - first) * 1000.0 / 60.0
            d.text((c * CELL + 4, CELL + 2), f"hero {hero_ms:.0f} ms", fill=(240, 240, 240))
            d.text((c * CELL + 4, 2 * CELL + 20), f"{take} {ms:.0f} ms", fill=(200, 200, 210))
            d.line([((c + 1) * CELL - 1, 0), ((c + 1) * CELL - 1, 2 * CELL + 36)], fill=(20, 20, 26), width=2)
        d.text((4, 4), name.replace("_", " "), fill=(255, 220, 120))
        path = out / "reference" / f"{n:02d}-{name}-side-by-side.png"
        sheet.save(path)
        made += 1
    print(f"OK {made} side-by-side pictures: {out / 'reference'}")


if __name__ == "__main__":
    main()
