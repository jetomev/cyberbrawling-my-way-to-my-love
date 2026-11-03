#!/usr/bin/env python3
"""Reference only: read a recorded human motion and look at it from the side, to measure and to draw from.
Javier & Claude.

Javier, 2026-11-02 19:09: base the hero's movement on recorded human motion, "reference only" (we measure and draw
our own poses). The recordings are CMU's (mocap.cs.cmu.edu) and live OUTSIDE this repository
(~/Programs/cyberbrawling-reference/cmu, see its README for the terms and the credit). This script reads them from
there; nothing it reads is ever written into the game. It prints measurements and draws stick-figure strips into
scratch/ (git-ignored).

  scripts/mocap_ref.py strip   <take> <from_s> <to_s> <step_ms> [--out file.png]   a stick figure every step_ms
  scripts/mocap_ref.py measure <take> <from_s> <to_s> <step_ms>                    angles and heights, our rig's terms
  scripts/mocap_ref.py events  <take>                                               feet off and on the ground, the peak
  scripts/mocap_ref.py strikes <take> <hand|foot>                                   every punch or kick: timing, shape

<take> is e.g. 16_05 (the subject's .asf is found beside it). Seen from the side, facing right: x forward, y up.
"""
import math
import sys
from pathlib import Path

REF = Path.home() / "Programs" / "cyberbrawling-reference" / "cmu"
FPS = 120.0


def rot(axis, deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    if axis == "x":
        return [[1, 0, 0], [0, c, -s], [0, s, c]]
    if axis == "y":
        return [[c, 0, s], [0, 1, 0], [-s, 0, c]]
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def apply(m, v):
    return [sum(m[i][k] * v[k] for k in range(3)) for i in range(3)]


def tr(m):
    return [[m[j][i] for j in range(3)] for i in range(3)]


def euler(order, values):
    """Rotations applied in the order given (e.g. "xyz"): the matrix is R_last ... R_first."""
    m = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    for axis, deg in zip(order, values):
        m = mul(rot(axis, deg), m)
    return m


def read_asf(path):
    bones = {}
    parents = {}
    lines = Path(path).read_text().splitlines()
    section = ""
    cur = None
    root_order = "xyz"
    root_axis = "xyz"
    for raw in lines:
        line = raw.strip()
        if line.startswith(":"):
            section = line.split()[0]
            if section == ":root":
                pass
            continue
        if section == ":root":
            bits = line.split()
            if bits and bits[0] == "order":
                root_order = "".join(b[1].lower() for b in bits[1:] if b.lower().startswith("r"))
            if bits and bits[0] == "axis":
                root_axis = bits[1].lower()
        elif section == ":bonedata":
            bits = line.split()
            if not bits:
                continue
            if bits[0] == "begin":
                cur = {"dof": []}
            elif bits[0] == "end":
                bones[cur["name"]] = cur
                cur = None
            elif bits[0] == "name":
                cur["name"] = bits[1]
            elif bits[0] == "direction":
                cur["dir"] = [float(x) for x in bits[1:4]]
            elif bits[0] == "length":
                cur["len"] = float(bits[1])
            elif bits[0] == "axis":
                cur["axis"] = [float(x) for x in bits[1:4]]
                cur["axis_order"] = bits[4].lower()
            elif bits[0] == "dof":
                cur["dof"] = [b.lower() for b in bits[1:]]
        elif section == ":hierarchy":
            bits = line.split()
            if not bits or bits[0] in ("begin", "end"):
                continue
            for child in bits[1:]:
                parents[child] = bits[0]
    for name, b in bones.items():
        c = euler(b["axis_order"], b["axis"])
        b["C"] = c
        b["Ci"] = tr(c)
        b["parent"] = parents.get(name, "root")
    order = []

    def visit(name):
        for child, p in parents.items():
            if p == name:
                order.append(child)
                visit(child)
    visit("root")
    return {"bones": bones, "order": order, "root_order": root_order, "root_axis": root_axis}


def read_amc(path):
    frames = []
    cur = None
    for raw in Path(path).read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith(":"):
            continue
        bits = line.split()
        if len(bits) == 1 and bits[0].isdigit():
            cur = {}
            frames.append(cur)
            continue
        if cur is not None:
            cur[bits[0]] = [float(x) for x in bits[1:]]
    return frames


def pose(skel, frame):
    """Every joint's position (the far end of each bone, and the root), in the recording's 3D space (y up)."""
    r = frame["root"]
    root_rot = euler(skel["root_order"], r[3:6])
    glob = {"root": root_rot}
    pos = {"root": r[0:3]}
    for name in skel["order"]:
        b = skel["bones"][name]
        vals = frame.get(name, [])
        angles = []
        order = ""
        for i, d in enumerate(b["dof"]):
            if d.startswith("r") and i < len(vals):
                angles.append(vals[i])
                order += d[1]
        m = euler(order, angles) if order else [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
        local = mul(b["C"], mul(m, b["Ci"]))
        g = mul(glob[b["parent"]], local)
        glob[name] = g
        v = apply(g, [b["dir"][i] * b["len"] for i in range(3)])
        p = pos[b["parent"]]
        pos[name] = [p[i] + v[i] for i in range(3)]
    return pos


def load(take):
    subject = take.split("_")[0]
    skel = read_asf(REF / f"{subject}.asf")
    frames = read_amc(REF / f"{take}.amc")
    return skel, frames


def side_view(skel, frames):
    """2D, seen from the side and facing right: the horizontal axis is the way the body travels (or, standing still,
    the way the hips face), y up; the street is at y = 0 (the lowest toe in the take)."""
    poses = [pose(skel, f) for f in frames]
    travel = [poses[-1]["root"][0] - poses[0]["root"][0], poses[-1]["root"][2] - poses[0]["root"][2]]
    if math.hypot(*travel) < 5.0:
        # standing in place: face the way the hips point (from the right hip to the left hip, turned 90 degrees)
        mid = poses[len(poses) // 2]
        across = [mid["lhipjoint"][0] - mid["rhipjoint"][0], mid["lhipjoint"][2] - mid["rhipjoint"][2]]
        travel = [across[1], -across[0]]
    n = math.hypot(*travel)
    ux, uz = travel[0] / n, travel[1] / n
    out = []
    for p in poses:
        out.append({k: (v[0] * ux + v[2] * uz, v[1]) for k, v in p.items()})
    floor = min(min(q["ltoes"][1], q["rtoes"][1]) for q in out)
    x0 = out[0]["root"][0]
    return [{k: (v[0] - x0, v[1] - floor) for k, v in q.items()} for q in out]


LINKS = [("root", "lhipjoint"), ("lhipjoint", "lfemur"), ("lfemur", "ltibia"), ("ltibia", "lfoot"), ("lfoot", "ltoes"),
         ("root", "rhipjoint"), ("rhipjoint", "rfemur"), ("rfemur", "rtibia"), ("rtibia", "rfoot"), ("rfoot", "rtoes"),
         ("root", "lowerback"), ("lowerback", "upperback"), ("upperback", "thorax"), ("thorax", "lowerneck"),
         ("lowerneck", "upperneck"), ("upperneck", "head"), ("thorax", "lclavicle"), ("lclavicle", "lhumerus"),
         ("lhumerus", "lradius"), ("lradius", "lwrist"), ("thorax", "rclavicle"), ("rclavicle", "rhumerus"),
         ("rhumerus", "rradius"), ("rradius", "rwrist")]


def angle(a, b):
    """The direction from a to b, in degrees, our rig's way: 0 = forward, 90 = straight down, -90 = straight up."""
    return math.degrees(math.atan2(-(b[1] - a[1]), b[0] - a[0]))


def bend(a, b, c):
    """How much a joint at b is bent, in degrees (0 = straight)."""
    v1 = (b[0] - a[0], b[1] - a[1])
    v2 = (c[0] - b[0], c[1] - b[1])
    d = math.degrees(math.atan2(v1[0] * v2[1] - v1[1] * v2[0], v1[0] * v2[0] + v1[1] * v2[1]))
    return abs(d)


def measure_frame(q):
    m = {"hip_h": q["root"][1]}
    for s in "lr":
        m[s + "_thigh"] = angle(q[s + "hipjoint"], q[s + "femur"])
        m[s + "_knee"] = bend(q[s + "hipjoint"], q[s + "femur"], q[s + "tibia"])
        m[s + "_ankle_h"] = q[s + "tibia"][1]
        m[s + "_toe_h"] = q[s + "toes"][1]
        m[s + "_upper_arm"] = angle(q[s + "clavicle"], q[s + "humerus"])
        m[s + "_elbow"] = bend(q[s + "clavicle"], q[s + "humerus"], q[s + "radius"])
        m[s + "_ahead"] = q[s + "tibia"][0] - q["root"][0]
    m["spine"] = angle(q["root"], q["thorax"]) + 90.0  # 0 = upright, + = leaning forward
    m["head"] = angle(q["lowerneck"], q["head"]) + 90.0
    return m


def frames_between(view, a, b, step_ms):
    i0 = max(0, int(a * FPS))
    i1 = min(len(view) - 1, int(b * FPS))
    step = max(1, int(round(step_ms * FPS / 1000.0)))
    return list(range(i0, i1 + 1, step))


def cmd_strip(take, a, b, step_ms, out):
    from PIL import Image, ImageDraw
    skel, frames = load(take)
    view = side_view(skel, frames)
    idx = frames_between(view, a, b, step_ms)
    allx = [v[0] for i in idx for v in view[i].values()]
    ally = [v[1] for i in idx for v in view[i].values()]
    span = max(max(ally), 1.0)
    cell = 220
    scale = (cell - 30) / (span + 4.0)
    width = cell * len(idx)
    img = Image.new("RGB", (width, cell + 20), (40, 40, 50))
    d = ImageDraw.Draw(img)
    for n, i in enumerate(idx):
        q = view[i]
        ox = n * cell + cell / 2 - q["root"][0] * scale
        def p(k):
            return (ox + q[k][0] * scale, cell - 5 - q[k][1] * scale)
        d.line([(n * cell, cell - 5), ((n + 1) * cell, cell - 5)], fill=(90, 90, 100), width=2)
        for a1, b1 in LINKS:
            near = a1[0] == "l" or b1[0] == "l"
            d.line([p(a1), p(b1)], fill=(220, 220, 230) if near else (130, 130, 150), width=4)
        hx, hy = p("head")
        d.ellipse([hx - 9, hy - 9, hx + 9, hy + 9], outline=(220, 220, 230), width=3)
        d.text((n * cell + 6, cell + 3), f"{take} {i / FPS * 1000.0:.0f} ms", fill=(230, 230, 230))
    img.save(out)
    print(f"OK {out} ({len(idx)} frames, light = left side, dark = right)")


def cmd_measure(take, a, b, step_ms):
    skel, frames = load(take)
    view = side_view(skel, frames)
    keys = ["hip_h", "spine", "head", "l_thigh", "l_knee", "l_toe_h", "r_thigh", "r_knee", "r_toe_h", "l_upper_arm",
            "l_elbow", "r_upper_arm", "r_elbow", "l_ahead", "r_ahead"]
    print("ms     " + " ".join(f"{k:>11}" for k in keys))
    for i in frames_between(view, a, b, step_ms):
        m = measure_frame(view[i])
        print(f"{i / FPS * 1000.0:6.0f} " + " ".join(f"{m[k]:11.1f}" for k in keys))


def cmd_events(take):
    skel, frames = load(take)
    view = side_view(skel, frames)
    off = [min(q["ltoes"][1], q["rtoes"][1]) for q in view]
    hip = [q["root"][1] for q in view]
    ground = 1.5
    airborne = [o > ground for o in off]
    print(f"{take}: {len(view)} frames, {len(view) / FPS:.2f} s; standing hip height {hip[0]:.1f}")
    for i in range(1, len(view)):
        if airborne[i] != airborne[i - 1]:
            print(f"  {'off the ground' if airborne[i] else 'touches down '} at {i / FPS * 1000.0:6.0f} ms (frame {i})")
    top = max(range(len(view)), key=lambda i: hip[i])
    low = min(range(len(view)), key=lambda i: hip[i])
    print(f"  hips highest at {top / FPS * 1000.0:.0f} ms ({hip[top]:.1f}), lowest at {low / FPS * 1000.0:.0f} ms ({hip[low]:.1f})")


def _flat(v):
    return (v[0], v[2])


def strikes(skel, frames, limb):
    """Every strike with the hands ("hand") or the feet ("foot") in a take. Each is seen along the way the blow goes
    (a side kick goes out sideways to the hips, so a plain side view would hide it): x toward the target, y up.
    Returns a list of dicts: the start, the full extension and the return (frame numbers), and the measurements."""
    poses = [pose(skel, f) for f in frames]
    floor = min(min(q["ltoes"][1], q["rtoes"][1]) for q in poses)
    ends = {"hand": ("lwrist", "rwrist"), "foot": ("ltoes", "rtoes")}[limb]
    out = []
    for end in ends:
        side = end[0]
        other = "r" if side == "l" else "l"
        dist = [math.dist(_flat(q[end]), _flat(q["root"])) for q in poses]
        rest = sorted(dist)[len(dist) // 4]  # a quiet reach: most of the time the limb is home
        top = max(dist)
        if top - rest < 6.0:
            continue
        i = 1
        while i < len(dist) - 1:
            if dist[i] > rest + 0.6 * (top - rest) and dist[i] >= dist[i - 1] and dist[i] >= dist[i + 1]:
                peak = max(range(i, min(len(dist), i + 30)), key=lambda k: dist[k])
                lo = rest + 0.1 * (dist[peak] - rest)
                a = peak
                while a > 0 and dist[a] > lo:
                    a -= 1
                b = peak
                while b < len(dist) - 1 and dist[b] > lo:
                    b += 1
                hold = [k for k in range(a, b + 1) if dist[k] >= dist[peak] - 0.05 * (dist[peak] - rest)]
                q = poses[peak]
                ax = (_flat(q[end])[0] - _flat(q["root"])[0], _flat(q[end])[1] - _flat(q["root"])[1])
                n = math.hypot(*ax)
                ux, uz = ax[0] / n, ax[1] / n

                def at(k, j):
                    v = poses[k][j]
                    return ((v[0] - poses[a]["root"][0]) * ux + (v[2] - poses[a]["root"][2]) * uz, v[1] - floor)

                def yaw(k, s2):
                    f = poses[k][s2 + "foot"]
                    t = poses[k][s2 + "toes"]
                    d = (t[0] - f[0], t[2] - f[2])
                    return math.degrees(math.acos(max(-1.0, min(1.0, (d[0] * ux + d[1] * uz) / max(math.hypot(*d), 1e-6)))))

                m = {"end": end, "start": a, "peak": peak, "back": b,
                     "out_ms": (peak - a) / FPS * 1000.0, "held_ms": (hold[-1] - hold[0]) / FPS * 1000.0,
                     "in_ms": (b - peak) / FPS * 1000.0,
                     "reach": dist[peak] - rest, "height": at(peak, end)[1] - at(peak, "root")[1],
                     "lean": angle(at(peak, "root"), at(peak, "thorax")) + 90.0,
                     "hips_moved": at(peak, "root")[0] - at(a, "root")[0]}
                if limb == "foot":
                    # from the kicking leg's hip joint (the game's "hip" is the hip joint, not the middle of the pelvis)
                    m["height"] = at(peak, end)[1] - at(peak, side + "hipjoint")[1]
                    m["chamber"] = max(at(k, side + "femur")[1] - at(k, side + "hipjoint")[1] for k in range(a, peak + 1))
                    m["thigh_up"] = max(-angle(at(k, side + "hipjoint"), at(k, side + "femur")) if at(k, side + "femur")[0] > at(k, side + "hipjoint")[0] else -90.0 for k in range(a, peak + 1))
                    m["knee_at_hit"] = bend(at(peak, side + "hipjoint"), at(peak, side + "femur"), at(peak, side + "tibia"))
                    m["stand_knee"] = bend(at(peak, other + "hipjoint"), at(peak, other + "femur"), at(peak, other + "tibia"))
                    m["stand_toe_start"] = yaw(a, other)
                    m["stand_toe_hit"] = yaw(peak, other)
                    m["chamber_ms"] = (max(range(a, peak + 1), key=lambda k: at(k, side + "femur")[1]) - a) / FPS * 1000.0
                else:
                    m["elbow_at_hit"] = bend(at(peak, side + "clavicle"), at(peak, side + "humerus"), at(peak, side + "radius"))
                    m["spare_hand"] = at(peak, other + "wrist")[1] - at(peak, "lowerneck")[1]
                    m["front_step"] = max(at(peak, "ltibia")[0], at(peak, "rtibia")[0]) - max(at(a, "ltibia")[0], at(a, "rtibia")[0])
                out.append(m)
                i = b + 1
            else:
                i += 1
    return sorted(out, key=lambda m: m["peak"])


def cmd_strikes(take, limb):
    skel, frames = load(take)
    found = strikes(skel, frames, limb)
    leg = None
    s0 = pose(skel, frames[0])
    leg = math.dist(s0["lhipjoint"], s0["lfemur"]) + math.dist(s0["lfemur"], s0["ltibia"])
    print(f"{take}, {limb} strikes: {len(found)} (leg {leg:.1f}; lengths below are in legs)")
    for m in found:
        extra = " ".join(f"{k} {v / leg if k in ('reach', 'height', 'chamber', 'hips_moved', 'spare_hand', 'front_step') else v:.2f}"
                         if isinstance(v, float) else f"{k} {v}" for k, v in m.items() if k not in ("start", "peak", "back"))
        print(f"  {m['start'] / FPS:6.2f}s  {extra}")


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    cmd, take = sys.argv[1], sys.argv[2]
    if cmd == "events":
        return cmd_events(take)
    if cmd == "strikes":
        return cmd_strikes(take, sys.argv[3])
    a, b, step = float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5])
    if cmd == "strip":
        out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else f"scratch/ref-{take}.png"
        return cmd_strip(take, a, b, step, out)
    if cmd == "measure":
        return cmd_measure(take, a, b, step)
    sys.exit(__doc__)


if __name__ == "__main__":
    main()
