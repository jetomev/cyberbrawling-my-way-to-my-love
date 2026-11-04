#!/usr/bin/env python3
"""Three style frames for Javier to pick from, drawn by our own script for $0 (no generator, no download). Javier &
Claude, 2026-11-03 (Javier: "move forward please"; docs/STYLE.md).

The same level 1 moment (the hero in his stance facing a thug, on Neon Row after rain) drawn three ways:
  A "Neon ink"    bold dark outlines, flat two-tone shapes, a thin neon rim on the lit edge
  B "Soft glow"   no outlines, soft shading, glow around every light
  C "Grit comic"  a rough inky line, heavy shadows, halftone dots
plus the colour arc: the same street lit for each level, neon to grit (the palette table in docs/STYLE.md).

These are drafts to choose a direction, not game art: the picked direction goes to ChatGPT (docs/PROMPTS.md, Batch 1)
after Javier's yes. Written as SVG and turned into PNG with rsvg-convert.

Usage: scripts/art/style_frames.py OUT_DIR          (writes frame-a.png, frame-b.png, frame-c.png, arc.png)
"""
import math
import random
import subprocess
import sys
from pathlib import Path

W, H = 1920, 1080
STREET = 760  # where the street starts (the bottom third, a little more)
GROUND = 930  # where the fighters' feet are

# docs/STYLE.md, colour by level
LEVELS = [
    ("1 · Neon Row", dict(sky="#1b1035", glow="#5b1f6e", far="#2b1d4f", mid="#241a3d", wall="#2c2340", street="#23202f",
                          sign1="#ff3ea5", sign2="#2de2e6", sign3="#ffb347", win="#ffd27a")),
    ("2 · market alley", dict(sky="#1a1a33", glow="#4a2f3a", far="#28263d", mid="#232238", wall="#2d283a", street="#262330",
                              sign1="#ffb347", sign2="#2de2e6", sign3="#ff6f61", win="#ffcf8a")),
    ("3-5 · the docks", dict(sky="#141c2a", glow="#3b3530", far="#1f2733", mid="#1c222c", wall="#262a31", street="#22252b",
                             sign1="#ff9b3d", sign2="#6fa7c9", sign3="#ff9b3d", win="#e8a860")),
    ("6-8 · factories", dict(sky="#1c1d17", glow="#3a3420", far="#26261d", mid="#22221b", wall="#2b2a22", street="#24221d",
                             sign1="#c8d36a", sign2="#ff7a2f", sign3="#9aa25a", win="#b8a65a")),
    ("9 · the tower", dict(sky="#16161a", glow="#3a1c1c", far="#202024", mid="#1d1d21", wall="#28282c", street="#2a2a2e",
                           sign1="#ff3b30", sign2="#8a8f99", sign3="#ff3b30", win="#a88080")),
    ("10 · the top", dict(sky="#1a0f0d", glow="#4a1a10", far="#24150f", mid="#20130f", wall="#2a1a15", street="#2b1c18",
                          sign1="#e0402a", sign2="#ff8a3d", sign3="#e0402a", win="#c0583a")),
]

STYLES = {
    "a": dict(name="Neon ink", outline=5.0, rough=False, soft=False, halftone=False, rim=4.0, shade=0.42, dark=0.62),
    "b": dict(name="Soft glow", outline=0.0, rough=False, soft=True, halftone=False, rim=5.0, shade=0.5, dark=0.7),
    "c": dict(name="Grit comic", outline=4.0, rough=True, soft=False, halftone=True, rim=3.0, shade=0.55, dark=0.45),
}
INK = "#0b0714"


def shade(hexcol, k):
    """A colour times k (k < 1 darker)."""
    r, g, b = (int(hexcol[i:i + 2], 16) for i in (1, 3, 5))
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(c * k))) for c in (r, g, b))


def mix(a, b, t):
    ra, ga, ba = (int(a[i:i + 2], 16) for i in (1, 3, 5))
    rb, gb, bb = (int(b[i:i + 2], 16) for i in (1, 3, 5))
    return "#%02x%02x%02x" % (round(ra + (rb - ra) * t), round(ga + (gb - ga) * t), round(ba + (bb - ba) * t))


def capsule(p, q, w):
    """A rounded bar from p to q, w wide: one body part."""
    (x1, y1), (x2, y2) = p, q
    a = math.atan2(y2 - y1, x2 - x1)
    nx, ny = -math.sin(a) * w / 2, math.cos(a) * w / 2
    r = w / 2
    return (f"M{x1 + nx:.1f},{y1 + ny:.1f} L{x2 + nx:.1f},{y2 + ny:.1f} "
            f"A{r:.1f},{r:.1f} 0 0 0 {x2 - nx:.1f},{y2 - ny:.1f} L{x1 - nx:.1f},{y1 - ny:.1f} "
            f"A{r:.1f},{r:.1f} 0 0 0 {x1 + nx:.1f},{y1 + ny:.1f} Z")


class Svg:
    def __init__(self, style):
        self.s = style
        self.defs, self.body, self.n = [], [], 0

    def uid(self, p):
        self.n += 1
        return f"{p}{self.n}"

    def add(self, x):
        self.body.append(x)

    def stroke_attr(self, w=None):
        w = self.s["outline"] if w is None else w
        if not w:
            return 'stroke="none"'
        f = ' filter="url(#rough)"' if self.s["rough"] else ""
        return f'stroke="{INK}" stroke-width="{w}" stroke-linejoin="round"{f}'

    def part(self, d, lit, light, dx=0.0, dy=0.0, width=30.0):
        """One cut-out part: a neon rim on the lit edge, the lit tone, the shadow away from the light, an outline.
        light is the rim colour, (dx, dy) the direction the light comes from."""
        s = self.s
        cid = self.uid("c")
        self.defs.append(f'<clipPath id="{cid}"><path d="{d}"/></clipPath>')
        rim, k = s["rim"], width * s["shade"]
        blur = ' filter="url(#soft)"' if s["soft"] else ""
        g = [f'<g clip-path="url(#{cid})">',
             f'<path d="{d}" fill="{light}"/>',
             f'<path d="{d}" fill="{lit}" transform="translate({-dx * rim:.1f},{-dy * rim:.1f})"/>',
             f'<path d="{d}" fill="{shade(lit, s["dark"])}" transform="translate({-dx * k:.1f},{-dy * k:.1f})"{blur}/>']
        if s["halftone"]:
            g.append(f'<path d="{d}" fill="url(#dots)" opacity="0.5"/>')
        g.append("</g>")
        self.add("".join(g))
        if s["outline"]:
            self.add(f'<path d="{d}" fill="none" {self.stroke_attr()}/>')
        if s["soft"]:
            self.add(f'<path d="{d}" fill="none" stroke="{light}" stroke-width="3" opacity="0.35" filter="url(#glow)"/>')

    def svg(self, w=W, h=H):
        defs = "".join(self.defs)
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {W} {H}">'
                f'<defs>{FILTERS}{defs}</defs>{"".join(self.body)}</svg>')


FILTERS = (
    '<filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="9"/></filter>'
    '<filter id="bigglow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="26"/></filter>'
    '<filter id="soft" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="7"/></filter>'
    '<filter id="ripple" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency="0.004 0.09" '
    'numOctaves="2" seed="4"/><feDisplacementMap in="SourceGraphic" scale="26" xChannelSelector="R" yChannelSelector="G"/>'
    '<feGaussianBlur stdDeviation="1.5"/></filter>'
    '<filter id="rough" x="-5%" y="-5%" width="110%" height="110%"><feTurbulence type="fractalNoise" baseFrequency="0.06" '
    'numOctaves="2" seed="9"/><feDisplacementMap in="SourceGraphic" scale="5" xChannelSelector="R" yChannelSelector="G"/></filter>'
    '<pattern id="dots" width="9" height="9" patternUnits="userSpaceOnUse"><circle cx="4.5" cy="4.5" r="1.9" fill="#000"/></pattern>'
    '<pattern id="bigdots" width="14" height="14" patternUnits="userSpaceOnUse"><circle cx="7" cy="7" r="2.6" fill="#000"/></pattern>'
)


# ------------------------------------------------------------------ the street

def street(v, pal, rng):
    """Sky, skyline, the block across the street with its signs, the shopfronts, the wet street and its reflections."""
    s = v.s
    v.defs.append(f'<linearGradient id="skyg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{shade(pal["sky"], 0.7)}"/>'
                  f'<stop offset="0.75" stop-color="{pal["sky"]}"/><stop offset="1" stop-color="{pal["glow"]}"/></linearGradient>')
    v.add(f'<rect width="{W}" height="{STREET}" fill="url(#skyg)"/>')
    # far skyline
    x = -20
    while x < W:
        bw, bh = rng.randint(70, 150), rng.randint(180, 380)
        v.add(f'<rect x="{x}" y="{STREET - 120 - bh}" width="{bw}" height="{bh + 120}" fill="{pal["far"]}"/>')
        for wy in range(STREET - 100 - bh, STREET - 140, 22):
            for wx in range(x + 10, x + bw - 10, 18):
                if rng.random() < 0.18:
                    v.add(f'<rect x="{wx}" y="{wy}" width="6" height="9" fill="{pal["win"]}" opacity="0.55"/>')
        x += bw + rng.randint(-10, 14)
    # the block across the street
    signs = []
    x = -40
    for bw in (360, 300, 420, 340, 380, 320):
        top = rng.randint(210, 330)
        v.add(f'<rect x="{x}" y="{top}" width="{bw}" height="{STREET - top}" fill="{pal["mid"]}" {v.stroke_attr(3)}/>')
        for wy in range(top + 30, STREET - 150, 70):  # windows
            for wx in range(x + 30, x + bw - 50, 80):
                on = rng.random() < 0.3
                v.add(f'<rect x="{wx}" y="{wy}" width="38" height="44" fill="{pal["win"] if on else shade(pal["mid"], 0.6)}"'
                      f' opacity="{0.8 if on else 1}" {v.stroke_attr(2)}/>')
        fe = x + bw - 120  # a fire escape
        for fy in range(top + 80, STREET - 160, 110):
            v.add(f'<path d="M{fe},{fy} h90 M{fe},{fy - 26} h90 M{fe + 8},{fy} v-26 M{fe + 82},{fy} v-26 M{fe + 20},{fy} l50,-110"'
                  f' stroke="{INK}" stroke-width="3" fill="none"/>')
        signs.append((x, bw, top))
        x += bw
    words = ["RAMEN", "HOTEL", "24H", "PAWN", "OPEN", "BAR"]
    neon = [pal["sign1"], pal["sign2"], pal["sign3"]]
    sign_shapes = []
    for i, (x, bw, top) in enumerate(signs):
        col = neon[i % 3]
        if i % 2 == 0:  # a vertical blade sign
            sx, sy, sw, sh = x + 40, top + 40, 64, 260
        else:
            sx, sy, sw, sh = x + 50, top + 60, bw - 120, 70
        sign_shapes.append((sx, sy, sw, sh, col, words[i]))
    for sx, sy, sw, sh, col, word in sign_shapes:
        if s["soft"] or not s["outline"]:
            v.add(f'<rect x="{sx}" y="{sy}" width="{sw}" height="{sh}" rx="8" fill="{col}" opacity="0.55" filter="url(#bigglow)"/>')
        else:
            v.add(f'<rect x="{sx - 6}" y="{sy - 6}" width="{sw + 12}" height="{sh + 12}" rx="10" fill="{col}" opacity="0.25" filter="url(#glow)"/>')
        v.add(f'<rect x="{sx}" y="{sy}" width="{sw}" height="{sh}" rx="8" fill="{shade(pal["mid"], 0.5)}" stroke="{col}" stroke-width="5"/>')
        if sw < sh:
            for j, ch in enumerate(word[:5]):
                v.add(f'<text x="{sx + sw / 2}" y="{sy + 48 + j * 48}" font-family="DejaVu Sans" font-weight="bold" font-size="40"'
                      f' text-anchor="middle" fill="{col}">{ch}</text>')
        else:
            v.add(f'<text x="{sx + sw / 2}" y="{sy + sh / 2 + 15}" font-family="DejaVu Sans" font-weight="bold" font-size="42"'
                  f' text-anchor="middle" fill="{col}" letter-spacing="6">{word}</text>')
    # the shopfronts right behind the fighters
    wall_top = STREET - 150
    v.add(f'<rect x="0" y="{wall_top}" width="{W}" height="150" fill="{pal["wall"]}" {v.stroke_attr(3)}/>')
    for x, kind in ((60, "shutter"), (420, "noodle"), (900, "door"), (1180, "shutter"), (1560, "noodle")):
        if kind == "shutter":
            v.add(f'<rect x="{x}" y="{wall_top + 22}" width="260" height="128" fill="{shade(pal["wall"], 1.35)}" {v.stroke_attr(3)}/>')
            for ly in range(wall_top + 34, STREET, 12):
                v.add(f'<path d="M{x},{ly} h260" stroke="{shade(pal["wall"], 0.7)}" stroke-width="2"/>')
        elif kind == "noodle":
            v.add(f'<rect x="{x}" y="{wall_top + 22}" width="300" height="128" fill="{pal["win"]}" opacity="0.85" {v.stroke_attr(3)}/>')
            v.add(f'<rect x="{x}" y="{wall_top + 22}" width="300" height="34" fill="{pal["sign1"]}" {v.stroke_attr(3)}/>')
            for j in range(5):  # hanging lanterns
                v.add(f'<circle cx="{x + 30 + j * 60}" cy="{wall_top + 10}" r="11" fill="{pal["sign3"]}" {v.stroke_attr(2)}/>')
        else:
            v.add(f'<rect x="{x}" y="{wall_top + 10}" width="110" height="140" fill="{shade(pal["wall"], 0.55)}" {v.stroke_attr(3)}/>')
    # the street
    v.add(f'<rect x="0" y="{STREET}" width="{W}" height="{H - STREET}" fill="{pal["street"]}"/>')
    v.add(f'<rect x="0" y="{STREET}" width="{W}" height="14" fill="{shade(pal["street"], 1.6)}" {v.stroke_attr(3)}/>')  # kerb
    # reflections of the signs in the wet street, upside down, rippled
    refl = []
    for sx, sy, sw, sh, col, word in sign_shapes:
        # squashed: the street is seen from above, so a sign high up reflects short and close to the kerb
        ry = STREET + 14 + (STREET - sy - sh) * 0.42
        refl.append(f'<rect x="{sx}" y="{ry:.0f}" width="{sw}" height="{sh * 0.42:.0f}" fill="{col}"/>')
    ref = "".join(refl)
    if s["soft"]:
        v.add(f'<g opacity="0.45" filter="url(#bigglow)">{ref}</g>')
        v.add(f'<g opacity="0.35" filter="url(#ripple)">{ref}</g>')
    elif s["halftone"]:
        v.add(f'<g opacity="0.5" filter="url(#ripple)">{ref}</g>')
        v.add(f'<rect x="0" y="{STREET + 14}" width="{W}" height="{H - STREET}" fill="url(#bigdots)" opacity="0.35"/>')
    else:
        v.add(f'<g opacity="0.55" filter="url(#ripple)">{ref}</g>')
    for px, pw in ((240, 300), (980, 220), (1500, 340)):  # puddles
        v.add(f'<ellipse cx="{px}" cy="{GROUND + 60}" rx="{pw / 2}" ry="18" fill="{shade(pal["street"], 0.7)}" opacity="0.8"/>')
        v.add(f'<path d="M{px - pw / 3},{GROUND + 56} h{pw / 4}" stroke="{pal["sign2"]}" stroke-width="3" opacity="0.6"/>')
    # rain
    for _ in range(140):
        rx, ry = rng.randint(0, W), rng.randint(0, H)
        v.add(f'<path d="M{rx},{ry} l-6,28" stroke="#c9d6ff" stroke-width="1.6" opacity="0.18"/>')


# ------------------------------------------------------------------ the fighters

def fighter(v, at, face, pose, clothes, light, ldir, scale=1.0):
    """A cut-out fighter: far limbs first and darker, then the body, then the near limbs."""
    x0, y0 = at

    def P(name):
        px, py = pose[name]
        return (x0 + face * px * scale, y0 + py * scale)

    def part(a, b, w, col, far=False):
        c = shade(col, 0.72) if far else col
        lc = shade(light, 0.7) if far else light
        v.part(capsule(P(a), P(b), w * scale), c, lc, ldir[0], ldir[1], w * scale)

    sk, top, pants, shoes = clothes["skin"], clothes["top"], clothes["pants"], clothes["shoes"]
    sleeve = clothes.get("sleeve", top)
    # far side
    part("hip", "kneeB", 40, pants, True); part("kneeB", "ankleB", 31, pants, True); part("ankleB", "toeB", 18, shoes, True)
    part("shoulderB", "elbowB", 27, sleeve, True); part("elbowB", "handB", 23, sk if sleeve != top else top, True)
    hx, hy = P("handB")
    v.part(capsule((hx - 1, hy), (hx + 1, hy), 27 * scale), shade(sk, 0.72), shade(light, 0.7), *ldir, 27 * scale)
    # body
    part("hip", "belly", 58, pants if clothes.get("low_top") else top)
    part("belly", "chest", 70, top)
    part("chest", "neck", 22, sk)
    hx, hy = P("head")
    v.part(capsule((hx - 4 * face * scale, hy - 6 * scale), (hx + 4 * face * scale, hy + 8 * scale), 56 * scale), sk, light, *ldir, 56 * scale)
    v.part(capsule((hx - 10 * face * scale, hy - 18 * scale), (hx + 6 * face * scale, hy - 20 * scale), 44 * scale), clothes["hair"],
           light, *ldir, 44 * scale)
    # near side
    part("hip", "kneeF", 41, pants); part("kneeF", "ankleF", 32, pants); part("ankleF", "toeF", 19, shoes)
    part("shoulderF", "elbowF", 28, sleeve); part("elbowF", "handF", 24, sk if sleeve != top else top)
    hx, hy = P("handF")
    v.part(capsule((hx - 1, hy), (hx + 1, hy), 29 * scale), sk, light, *ldir, 29 * scale)


STANCE = dict(  # the hero's fighting stance, facing right, feet on 0
    hip=(0, -170), belly=(4, -215), chest=(10, -262), neck=(14, -282), head=(20, -312),
    kneeF=(46, -92), ankleF=(62, -10), toeF=(90, -4), kneeB=(-36, -86), ankleB=(-70, -10), toeB=(-44, -4),
    shoulderF=(16, -262), elbowF=(56, -228), handF=(70, -286), shoulderB=(6, -262), elbowB=(20, -214), handB=(44, -278),
)
THUG = dict(  # the thug, square and upright, fists low
    hip=(0, -172), belly=(2, -218), chest=(4, -266), neck=(6, -286), head=(10, -314),
    kneeF=(30, -90), ankleF=(40, -10), toeF=(68, -4), kneeB=(-28, -90), ankleB=(-44, -10), toeB=(-16, -4),
    shoulderF=(8, -266), elbowF=(40, -214), handF=(64, -238), shoulderB=(0, -266), elbowB=(-6, -210), handB=(24, -232),
)


def frame(key, pal, with_fighters=True, seed=3):
    v = Svg(STYLES[key])
    rng = random.Random(seed)
    street(v, pal, rng)
    if with_fighters:
        for cx in (660, 1240):  # contact shadows
            v.add(f'<ellipse cx="{cx}" cy="{GROUND + 2}" rx="120" ry="16" fill="#000" opacity="0.45"/>')
        fighter(v, (660, GROUND), 1, STANCE,
                dict(skin="#c98d6a", top="#2c3352", pants="#24252f", shoes="#e2e2ea", hair="#17121a"),
                pal["sign1"], (-0.7, -0.7))
        fighter(v, (1240, GROUND), -1, THUG,
                dict(skin="#b07a5a", top="#7a7f88", sleeve="#b07a5a", pants="#3d302b", shoes="#2a2626", hair="#2a1a14"),
                pal["sign2"], (0.7, -0.7), scale=1.1)
    # the foreground lamppost
    lp = v.stroke_attr(4)
    v.add(f'<rect x="1600" y="180" width="26" height="{H - 180}" fill="#141019" {lp}/>')
    v.add(f'<path d="M1613,190 q0,-60 -110,-60 h-40" stroke="#141019" stroke-width="18" fill="none"/>')
    v.add(f'<ellipse cx="1455" cy="140" rx="60" ry="18" fill="{pal["win"]}" {lp}/>')
    v.add(f'<ellipse cx="1455" cy="160" rx="90" ry="40" fill="{pal["win"]}" opacity="0.25" filter="url(#bigglow)"/>')
    return v


def render(svg_text, out, w=W, h=H):
    src = out.with_suffix(".svg")
    src.write_text(svg_text)
    subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h), "-o", str(out), str(src)], check=True)
    src.unlink()


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    pal1 = LEVELS[0][1]
    for key in STYLES:
        render(frame(key, pal1).svg(), out / f"frame-{key}.png")
    # the colour arc: the street lit for each level, small, side by side in two rows
    from PIL import Image, ImageDraw, ImageFont
    tiles = []
    for i, (name, pal) in enumerate(LEVELS):
        p = out / f".arc-{i}.png"
        render(frame("a", pal, with_fighters=False, seed=5).svg(640, 360), p, 640, 360)
        im = Image.open(p).convert("RGB")
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, 640, 40], fill=(0, 0, 0))
        d.text((12, 6), "Level " + name, fill=(255, 255, 255), font=ImageFont.load_default(size=26))
        tiles.append(im)
        p.unlink()
    sheet = Image.new("RGB", (3 * 644, 2 * 364), (12, 10, 16))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % 3) * 644, (i // 3) * 364))
    sheet.save(out / "arc.png")
    print(f"OK style frames: {', '.join(f'frame-{k}.png' for k in STYLES)} and arc.png in {out}")


if __name__ == "__main__":
    main()
