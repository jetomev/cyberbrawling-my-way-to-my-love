#!/usr/bin/env python3
"""Cuts the armed-blows recording (scripts/armed_blows.sh) into what the testers read: grips.png (each weapon's grip
and block, close up), <weapon>/NN-<blow>-N.png (every frame of each blow, 30 to a sheet, in order), <weapon>.mp4 and
<weapon>-half.mp4 (the weapon's whole run at full and half speed). Javier & Claude."""
import os, re, subprocess, sys, shutil

frames_dir, out = sys.argv[1], sys.argv[2]
segs = []
for line in open(os.path.join(out, "segments.txt")):
    m = re.match(r"^SEG (\S+) (\S+) (\d+) (\d+) (.*)$", line.rstrip("\n"))
    if m:
        segs.append((m[1], m[2], int(m[3]), int(m[4]), m[5]))
# (the recording has one frame more than the tool counts at its start: frame 0 is drawn before the first tick)
LAST = max(int(n[1:9]) for n in os.listdir(frames_dir) if re.match(r"^f\d{8}\.png$", n))
def path(f):
    return os.path.join(frames_dir, "f%08d.png" % min(f + 1, LAST))

def tile(frames, dest, cols, width):
    tmp = dest + ".d"
    os.makedirs(tmp, exist_ok=True)
    for i, f in enumerate(frames):
        shutil.copy(path(f), os.path.join(tmp, "s%03d.png" % i))
    rows = (len(frames) + cols - 1) // cols
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", "1", "-i", os.path.join(tmp, "s%03d.png"),
                    "-vf", "scale=%d:-1,tile=%dx%d" % (width, cols, rows), "-frames:v", "1", dest], check=True)
    shutil.rmtree(tmp)

grips = []
by_weapon = {}
for w, name, a, b, label in segs:
    by_weapon.setdefault(w, []).append((name, a, b))
    if name in ("grip", "block"):
        grips.append((a + b) // 2)
tile(grips, os.path.join(out, "grips.png"), 4, 480)
for w, name, a, b, label in segs:  # and each close-up on its own, full size
    if name in ("grip", "block"):
        shutil.copy(path((a + b) // 2), os.path.join(out, "%s-%s.png" % (w, name)))
for w, items in by_weapon.items():
    os.makedirs(os.path.join(out, w), exist_ok=True)
    n = 0
    for name, a, b in items:
        if name in ("grip", "block"):
            continue
        n += 1
        frames = list(range(a, b + 1))
        for page in range(0, len(frames), 30):
            tile(frames[page:page + 30], os.path.join(out, w, "%02d-%s-%d.png" % (n, name, page // 30 + 1)), 6, 320)
        # each blow's whole movement, Ready to Ready, at full and half speed (the testers on b24110b)
        for half, suffix in ((False, ""), (True, "-half")):
            cmd = ["ffmpeg", "-loglevel", "error", "-y", "-framerate", "60", "-start_number", str(min(a + 1, LAST)), "-i",
                   os.path.join(frames_dir, "f%08d.png"), "-frames:v", str(b - a + 1)]
            cmd += (["-vf", "setpts=2*PTS", "-r", "60"] if half else []) + ["-c:v", "libx264", "-pix_fmt", "yuv420p",
                    os.path.join(out, w, "%02d-%s%s.mp4" % (n, name, suffix))]
            subprocess.run(cmd, check=True)
    first, last = items[0][1], items[-1][2]
    for half, suffix in ((False, ""), (True, "-half")):
        cmd = ["ffmpeg", "-loglevel", "error", "-y", "-framerate", "60", "-start_number", str(first + 1), "-i",
               os.path.join(frames_dir, "f%08d.png"), "-frames:v", str(last - first + 1)]
        cmd += (["-vf", "setpts=2*PTS", "-r", "60"] if half else []) + ["-c:v", "libx264", "-pix_fmt", "yuv420p",
                os.path.join(out, w + suffix + ".mp4")]
        subprocess.run(cmd, check=True)
print("cut %d segments for %d weapons" % (len(segs), len(by_weapon)))
