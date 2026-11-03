#!/usr/bin/env python3
"""The reviewers' stills of every move in the recorded demo (D-22). Javier & Claude.

The assistant team reviews every build before Javier plays it, and reads pictures, not video. From the demo's frames
and its marks (`--marks`: where the hips, hands, feet and the top of the head are on every frame, in the 1920x1080
game's pixels; the movie can be smaller) this cuts, for each move:

- moves.png: the whole body as the move lands, one panel per move, framed from the marks (head to feet);
- closeups/NN-<move>.png (and all of them in closeups.png): as it lands, the whole body, the hips, the hands, the feet;
- strips/NN-<move>.png: the move from its first frame to its last, at fixed time steps (every STEP frames, lined up so
  the landing frame is one of them), four rows (whole body, hips, hands, feet). Each row keeps one frame for the whole
  move, so the parts are seen moving, not re-centred;
- strips/NN-<move>-hit.png: the same rows, every single frame from HIT_BEFORE frames before the hit to HIT_AFTER after
  (the team's second review: more frames close together around each strike);
- for "landing" (the first landing after the flying kick), strips/NN-landing-1.png, -2.png...: every frame from the
  last moments in the air to him back up, CHUNK frames a picture (the third review); the same for any window asked
  for by hand as "<move>-frames:<hit>:<start>:<end>" (times are labelled from the hit).

- clips/NN-<move>.mp4 and clips/NN-<move>-half.mp4: the move moving, close on the whole body, from a few frames before
  it starts to a few after it ends, at full speed and at half speed (Javier, 2026-11-02 evening: "stiff as a tree";
  the stills had been hiding it).
- frames/NN-<move>.png: every frame of that clip, in order, at the game's 60 frames a second, ten to a row, each with
  its time (from the hit; a walk or run cycle, from its first frame), on the clip's own fixed framing (the testers read
  pictures only; until 2026-11-02 they cut these by hand from the clips, and a cropping slip showed how that goes).
- frames/NN-<move>-street.png and clips/NN-<move>-street.mp4 (and -street-half.mp4): the same frames with the STREET
  held still instead of the hero: the game's camera follows him, so the build undoes its panning (each marks line
  ends with where the street's origin is on screen) and crops a box as wide as his whole travel. His travel along the
  street shows (the testers, 2026-11-02 22:33: "keep the camera fixed on the street").

Usage: scripts/closeups.py <frames dir> <marks file> <out dir> move:land:start:end [...]
Prints an OK line with the counts.
"""
import struct
import subprocess
import sys
from pathlib import Path

GAME_W, GAME_H = 1920, 1080
PANEL = 320  # a close-up panel's side
STRIP_PANEL = 170  # a timed strip's panel side
STEP = 3  # frames between stills in a timed strip (50 ms at 60 frames a second)
HIT_BEFORE, HIT_AFTER = 6, 3  # the hit strip: every frame from 100 ms before the hit to 50 ms after
CHUNK = 10  # frames a picture in an every-frame sequence
PARTS = ["hip", "hand_f", "hand_b", "foot_f", "foot_b", "head"]
ROWS = ["whole body", "hips", "hands", "feet"]


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
        if len(n) >= 4 + 2 * len(PARTS):
            marks[n[0]]["street"] = (n[2 + 2 * len(PARTS)], n[3 + 2 * len(PARTS)])
        if len(n) >= 6 + 2 * len(PARTS):
            marks[n[0]]["shoulder"] = (n[4 + 2 * len(PARTS)], n[5 + 2 * len(PARTS)])
    return marks


def square(points, pad, least, w, h):
    """A square around the points, padded, at least `least` wide, kept inside the frame."""
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    side = int(min(max(max(xs) - min(xs) + 2 * pad, max(ys) - min(ys) + 2 * pad, least), w, h))
    cx = (min(xs) + max(xs)) / 2
    cy = (min(ys) + max(ys)) / 2
    x = int(min(max(cx - side / 2, 0), w - side))
    y = int(min(max(cy - side / 2, 0), h - side))
    return side, x, y


def boxes(points_by_frame, u, w, h):
    """The four crops (whole body, hips, hands, feet) around the parts over the given frames."""
    def gather(names):
        return [at[n] for at in points_by_frame for n in names]
    return [
        square(gather(PARTS), 0.7 * u, 2.8 * u, w, h),  # room around the head and feet
        square(gather(["hip"]), 0.9 * u, 1.8 * u, w, h),
        square(gather(["hand_f", "hand_b"]), 0.4 * u, 1.5 * u, w, h),
        square(gather(["foot_f", "foot_b"]), 0.4 * u, 1.5 * u, w, h),
    ]


def panel(src, box, size, text):
    side, x, y = box
    label = f",drawtext=text='{text}':x=6:y=6:fontsize={max(14, size // 16)}:fontcolor=white:box=1:boxcolor=black@0.55" \
        if text else ""
    # opaque in the end: a see-through label box would otherwise leave the picture with a transparency layer
    return f"[{src}]crop={side}:{side}:{x}:{y},scale={size}:{size}:flags=lanczos{label},format=rgb24"


def ffmpeg(inputs, graph, out):
    args = ["ffmpeg", "-loglevel", "error", "-y"]
    for i in inputs:
        args += ["-i", str(i)]
    subprocess.run(args + ["-filter_complex", graph, "-frames:v", "1", str(out)], check=True)


def stack(files, how, out):
    if len(files) == 1:
        ffmpeg(files, "null", out)
    else:
        ffmpeg(files, f"{how}=inputs={len(files)}", out)


def strip(steps, land, move, path, still, at, k, u, w, h):
    """Columns at the given frames, rows for the whole body, hips, hands and feet, each row on one fixed frame."""
    fixed = boxes([at(f, k) for f in steps], u, w, h)
    parts = []
    for c, f in enumerate(steps):
        ms = round((f - land) * 1000 / 60)
        if "-cycle" in move:
            when = f"{ms:+d} ms"  # a walk or run cycle: times from its first frame
        else:
            when = ("TOUCH" if move == "landing" else "HIT") if f == land else f"{ms:+d} ms"
        parts.append(f"[{c}]split=4[c{c}r0][c{c}r1][c{c}r2][c{c}r3]")
        for r, b in enumerate(fixed):
            text = (f"{move} {when}" if c == 0 else when) if r == 0 else (ROWS[r] if c == 0 else "")
            parts.append(panel(f"c{c}r{r}", b, STRIP_PANEL, text) + f"[c{c}p{r}]")
        parts.append(f"[c{c}p0][c{c}p1][c{c}p2][c{c}p3]vstack=inputs=4[col{c}]")
    cols = "".join(f"[col{c}]" for c in range(len(steps)))
    parts.append(f"{cols}hstack=inputs={len(steps)}" if len(steps) > 1 else f"{cols}null")
    ffmpeg([still(f) for f in steps], ";".join(parts), path)
    return path


CLIP_PAD = 8  # frames before and after a move in its clip
CLIP_SIZE = 480
SHEET_SIZE = 240  # a frame sheet's tile side
SHEET_COLUMNS = 10


def frame_sheet(frames, start, end, zero, label, path, at, k, u, w, h):
    """Every frame of the clip (the same span and the same fixed framing), in order, ten to a row, each with its time
    from frame `zero`."""
    span = [f for f in range(start - CLIP_PAD, end + CLIP_PAD + 1) if (frames / f"f{f:08d}.png").exists()]
    side, x, y = boxes([at(f, k) for f in span], u, w, h)[0]
    rows = -(-len(span) // SHEET_COLUMNS)
    when = f"%{{eif\\:(n+{span[0] - zero})*1000/60\\:d}} ms"
    vf = (f"crop={side}:{side}:{x}:{y},scale={SHEET_SIZE}:{SHEET_SIZE}:flags=lanczos,"
          f"drawtext=text='{label} {when}':x=5:y=5:fontsize=17:fontcolor=white:box=1:boxcolor=black@0.6,"
          f"tile={SHEET_COLUMNS}x{rows}:padding=2:color=0x16161c,format=rgb24")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", "60", "-start_number", str(span[0]),
                    "-i", str(frames / "f%08d.png"), "-frames:v", str(len(span)), "-vf", vf, "-frames:v", "1",
                    str(path)], check=True)
    return len(span)


STREET_TILE_H = 240  # a street-fixed sheet's tile height (its width follows the travel)


def street_fixed(frames, start, end, zero, label, sheet_path, clip_path, marks, k, u):
    """The clip's frames with the street held still: each crop moves with the camera's pan, the box as wide as the
    whole travel. A sheet (every frame, timed) and clips at full and half speed. Returns False without street marks."""
    from PIL import Image, ImageDraw
    span = [f for f in range(start - CLIP_PAD, end + CLIP_PAD + 1) if (frames / f"f{f:08d}.png").exists()]
    if not all("street" in marks.get(f, {}) for f in span):
        return False
    sx0 = marks[span[0]]["street"][0] * k
    world = [(x * k - (marks[f]["street"][0] * k - sx0), y * k) for f in span for n, (x, y) in marks[f].items() if n in PARTS]
    pad = 0.7 * u
    x0, x1 = min(p[0] for p in world) - pad, max(p[0] for p in world) + pad
    y0, y1 = min(p[1] for p in world) - pad, max(p[1] for p in world) + pad
    if y1 - y0 < 2.8 * u:
        y0, y1 = (y0 + y1) / 2 - 1.4 * u, (y0 + y1) / 2 + 1.4 * u
    bw, bh = int(x1 - x0), int(y1 - y0)
    tw = max(1, round(bw * STREET_TILE_H / bh))
    cols = max(1, min(10, 2400 // (tw + 2)))
    rows = -(-len(span) // cols)
    sheet = Image.new("RGB", (cols * (tw + 2), rows * (STREET_TILE_H + 2)), (22, 22, 28))
    tmp = clip_path.parent / f".street-{clip_path.stem}"
    tmp.mkdir(exist_ok=True)
    for i, f in enumerate(span):
        dx = marks[f]["street"][0] * k - sx0
        img = Image.open(frames / f"f{f:08d}.png").convert("RGB")
        tile = img.crop((int(x0 + dx), int(y0), int(x0 + dx) + bw, int(y0) + bh)).resize((tw, STREET_TILE_H))
        d = ImageDraw.Draw(tile)
        ms = int((f - zero) * 1000 / 60)
        d.rectangle([0, 0, 150, 20], fill=(0, 0, 0))
        d.text((4, 4), f"{label} {ms} ms", fill=(255, 255, 255))
        sheet.paste(tile, ((i % cols) * (tw + 2), (i // cols) * (STREET_TILE_H + 2)))
        big = img.crop((int(x0 + dx), int(y0), int(x0 + dx) + bw, int(y0) + bh))
        big = big.resize((max(2, round(bw * CLIP_SIZE / bh)) // 2 * 2, CLIP_SIZE))
        big.save(tmp / f"f{i:05d}.png")
    sheet.save(sheet_path)
    for speed, suffix in [(1, ""), (2, "-half")]:
        vf = (f"setpts={speed}*PTS," if speed > 1 else "") + "format=yuv420p"
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", "60", "-i", str(tmp / "f%05d.png"),
                        "-vf", vf, "-r", "60", "-c:v", "libx264",
                        str(clip_path.with_name(clip_path.stem + suffix + ".mp4"))], check=True)
    for png in tmp.glob("f*.png"):
        png.unlink()
    tmp.rmdir()
    return True


def shoulder_closeup(frames, start, end, zero, label, sheet_path, clip_path, marks, k, u):
    """The shoulders up close through a move (the testers, 00:57 on 66ce4c6: "show the shoulder carrying the roll"): a
    square that follows the shoulders, big enough to show the street under them, with a ring on the shoulder mark;
    every frame on a sheet, timed, and clips at full and half speed. Returns False without shoulder marks."""
    from PIL import Image, ImageDraw, ImageFont
    font = ImageFont.load_default(size=30)
    span = [f for f in range(start - CLIP_PAD, end + CLIP_PAD + 1) if (frames / f"f{f:08d}.png").exists()]
    if not all("shoulder" in marks.get(f, {}) for f in span):
        return False
    side = int(2.0 * u)
    cols = SHEET_COLUMNS
    sheet = Image.new("RGB", (cols * (SHEET_SIZE + 2), -(-len(span) // cols) * (SHEET_SIZE + 2)), (22, 22, 28))
    tmp = clip_path.parent / f".shoulder-{clip_path.stem}"
    tmp.mkdir(exist_ok=True)
    for i, f in enumerate(span):
        img = Image.open(frames / f"f{f:08d}.png").convert("RGB")
        sx, sy = marks[f]["shoulder"][0] * k, marks[f]["shoulder"][1] * k
        x = int(min(max(sx - side / 2, 0), img.width - side))
        y = int(min(max(sy - side / 2, 0), img.height - side))
        crop = img.crop((x, y, x + side, y + side)).resize((CLIP_SIZE, CLIP_SIZE))
        d = ImageDraw.Draw(crop)
        cx, cy = (sx - x) * CLIP_SIZE / side, (sy - y) * CLIP_SIZE / side
        d.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], outline=(255, 200, 80), width=3)
        ms = int((f - zero) * 1000 / 60)
        d.rectangle([0, 0, CLIP_SIZE, 44], fill=(0, 0, 0))
        d.text((8, 6), f"roll {ms} ms · shoulders ringed", fill=(255, 255, 255), font=font)
        crop.save(tmp / f"f{i:05d}.png")
        sheet.paste(crop.resize((SHEET_SIZE, SHEET_SIZE)), ((i % cols) * (SHEET_SIZE + 2), (i // cols) * (SHEET_SIZE + 2)))
    sheet.save(sheet_path)
    for speed, suffix in [(1, ""), (2, "-half")]:
        vf = (f"setpts={speed}*PTS," if speed > 1 else "") + "format=yuv420p"
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", "60", "-i", str(tmp / "f%05d.png"),
                        "-vf", vf, "-r", "60", "-c:v", "libx264",
                        str(clip_path.with_name(clip_path.stem + suffix + ".mp4"))], check=True)
    for png in tmp.glob("f*.png"):
        png.unlink()
    tmp.rmdir()
    return True


def clip(frames, start, end, label, path, at, k, u, w, h):
    """The move at full speed and at half speed, on one fixed frame that holds the whole body throughout."""
    span = [f for f in range(start - CLIP_PAD, end + CLIP_PAD + 1) if (frames / f"f{f:08d}.png").exists()]
    side, x, y = boxes([at(f, k) for f in span], u, w, h)[0]
    look = (f"crop={side}:{side}:{x}:{y},scale={CLIP_SIZE}:{CLIP_SIZE}:flags=lanczos,"
            f"drawtext=text='{label}':x=8:y=8:fontsize=24:fontcolor=white:box=1:boxcolor=black@0.55")
    for speed, suffix in [(1, ""), (2, "-half")]:
        vf = look + (f",setpts={speed}*PTS" if speed > 1 else "") + ",format=yuv420p"
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", "60", "-start_number", str(span[0]),
                        "-i", str(frames / "f%08d.png"), "-frames:v", str(len(span) * speed), "-vf", vf, "-r", "60",
                        "-c:v", "libx264", str(path.with_name(path.stem + suffix + ".mp4"))], check=True)


def main():
    if len(sys.argv) < 5:
        sys.exit(__doc__)
    frames, marks, out = Path(sys.argv[1]), read_marks(sys.argv[2]), Path(sys.argv[3])
    moves = []
    for item in sys.argv[4:]:
        move, land, start, end = item.split(":")
        moves.append((move, int(land), int(start), int(end)))
    for d in ["closeups", "strips", "moves", "clips", "frames"]:
        (out / d).mkdir(parents=True, exist_ok=True)

    def still(frame):
        return frames / f"f{frame:08d}.png"

    def at(frame, k):
        if frame not in marks:
            sys.exit(f"FAILED no marks for frame {frame}")
        return {p: (x * k, y * k) for p, (x, y) in marks[frame].items()}

    rows, strips, tiles = [], [], []
    sheets = 0
    streets = 0
    for n, (move, land, start, end) in enumerate(moves):
        w, h = png_size(still(land))
        k = w / GAME_W
        u = h / GAME_H * 100  # one unit: about a tenth of the fighter's height
        # as it lands: one panel for moves.png, a row of four close-ups
        here = boxes([at(land, k)], u, w, h)
        tile = out / "moves" / f"{n:02d}.png"
        ffmpeg([still(land)], panel(0, here[0], PANEL, move), tile)
        tiles.append(tile)
        graph = "[0]split=4[s0][s1][s2][s3];" + ";".join(
            panel(f"s{i}", b, PANEL, f"{move} · {ROWS[i]}" if i == 0 else ROWS[i]) + f"[p{i}]" for i, b in enumerate(here)
        ) + ";[p0][p1][p2][p3]hstack=inputs=4"
        row = out / "closeups" / f"{n:02d}-{move}.png"
        ffmpeg([still(land)], graph, row)
        rows.append(row)
        label = move.replace("-cycle-frames", "").replace("-frames", "")
        clip(frames, start, end, label, out / "clips" / f"{n:02d}-{label}.mp4", at, k, u, w, h)
        sheets += 1
        frame_sheet(frames, start, end, start if "-cycle" in move else land, label,
                    out / "frames" / f"{n:02d}-{label}.png", at, k, u, w, h)
        if street_fixed(frames, start, end, start if "-cycle" in move else land, label,
                        out / "frames" / f"{n:02d}-{label}-street.png", out / "clips" / f"{n:02d}-{label}-street.mp4",
                        marks, k, u):
            streets += 1
        if label == "roll" and not shoulder_closeup(frames, start, end, start, label,
                                                    out / "frames" / f"{n:02d}-roll-shoulder.png",
                                                    out / "clips" / f"{n:02d}-roll-shoulder.mp4", marks, k, u):
            sys.exit("FAILED no shoulder marks for the roll's close-up")
        if move == "landing" or move.endswith("-frames"):
            # every frame of a window: the landing, or any "<move>-frames:<hit>:<start>:<end>" asked for by hand
            frames_all = list(range(start, end + 1))
            for c in range(0, len(frames_all), CHUNK):
                part = out / "strips" / f"{n:02d}-{move}-{c // CHUNK + 1}.png"
                strips.append(strip(frames_all[c:c + CHUNK], land, move, part, still, at, k, u, w, h))
            continue
        # the timed strip: every STEP frames, lined up on the landing frame; then every frame around the hit
        steps = [f for f in range(start, end + 1) if (f - land) % STEP == 0]
        strips.append(strip(steps, land, move, out / "strips" / f"{n:02d}-{move}.png", still, at, k, u, w, h))
        close = [f for f in range(max(start, land - HIT_BEFORE), min(end, land + HIT_AFTER) + 1)]
        strips.append(strip(close, land, move, out / "strips" / f"{n:02d}-{move}-hit.png", still, at, k, u, w, h))
    stack(rows, "vstack", out / "closeups.png")
    # moves.png: four panels a row; a short last row is filled with blank panels
    lines = []
    for i in range(0, len(tiles), 4):
        group = tiles[i:i + 4]
        real = len(group)
        group = group + [group[-1]] * (4 - real)
        graph = ";".join(f"[{j}]" + ("format=rgb24,lutrgb=r=0:g=0:b=0" if j >= real else "null") + f"[t{j}]" for j in range(4)) \
            + ";" + "".join(f"[t{j}]" for j in range(4)) + "hstack=inputs=4"
        line = out / "moves" / f"row{i // 4}.png"
        ffmpeg(group, graph, line)
        lines.append(line)
    stack(lines, "vstack", out / "moves.png")
    print(f"OK {len(moves)} moves: moves.png, {len(rows)} close-up rows, {len(strips)} timed strips "
          f"(every {STEP} frames = {round(STEP * 1000 / 60)} ms, and every frame around each hit), {sheets} frame sheets, {streets} street-fixed")


if __name__ == "__main__":
    main()
