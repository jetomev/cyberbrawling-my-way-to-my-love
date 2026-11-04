#!/usr/bin/env python3
"""First sound effects, drafts for Javier's ear. Javier & Claude, 2026-11-03 (docs/STYLE.md, The sound).

Free and from scratch (synth.py's filters and noise, no samples, no download). Three takes of each, so a repeated hit
doesn't sound robotic; the game picks one at random. Pain is heard, never bled (D-9): the crack is here, the voices
(grunts, screams) come with the pain system.

Usage: scripts/audio/make_sfx.py OUT_DIR       (writes <name>-1.ogg … <name>-3.ogg)
"""
import os
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np  # noqa: E402
from scipy.io import wavfile  # noqa: E402

from synth import SR, bp, hp, lp, lowpass_sweep  # noqa: E402

# what each one is, for the Dailies page
WHERE = {
    "punch_whoosh": "A punch cutting the air (plays on every punch, hit or miss).",
    "kick_whoosh": "A kick swinging through, longer and lower than the punch.",
    "hit_light": "A jab or a low kick landing: a slap on the body.",
    "hit_heavy": "A power punch, a side kick or the sweep landing: a thud with a low boom under it.",
    "block": "A blow stopped by the guard: forearms taking it.",
    "step": "A sneaker on the wet street (the walk and the run).",
    "land": "Feet hitting the street after a jump or a flying kick.",
    "crack": "A bone giving way, for the broken arm and leg (the pain system). No blood, ever.",
}


def t_(dur):
    return np.arange(int(dur * SR)) / SR


def whoosh(rng, dur, lo, hi):
    """Noise through a band that sweeps up and back down, loudest in the middle: air moving past."""
    t = t_(dur)
    n = rng.standard_normal(len(t))
    shape = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.6
    x = lowpass_sweep(n, lo, hi, q=2.2) - lowpass_sweep(n, lo * 0.5, hi * 0.4, q=1.0) * 0.6
    return hp(x, 250) * shape * 0.8


def thud(rng, dur, f0, f1, decay):
    """A body hit: a short pitch-dropping sine (the mass) under filtered noise (the slap)."""
    t = t_(dur)
    f = f1 + (f0 - f1) * np.exp(-t * 40)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * decay)
    slap = bp(rng.standard_normal(len(t)), 900, 5500) * np.exp(-t * 70)
    return np.tanh(2.0 * (body * 0.9 + slap * 0.7))


def make(name, rng):
    j = rng.uniform(0.92, 1.08)  # each take a little different in pitch and length
    if name == "punch_whoosh":
        return whoosh(rng, 0.16 * j, 600 * j, 5200 * j) * 0.9
    if name == "kick_whoosh":
        return whoosh(rng, 0.28 * j, 300 * j, 3200 * j)
    if name == "hit_light":
        return thud(rng, 0.18, 220 * j, 110 * j, 30) * 0.85
    if name == "hit_heavy":
        x = thud(rng, 0.45, 160 * j, 52 * j, 9)
        t = t_(0.45)
        boom = np.sin(2 * np.pi * 45 * j * t) * np.exp(-t * 7) * 0.6
        return np.tanh(1.6 * (x + boom)) * 0.95
    if name == "block":
        x = thud(rng, 0.2, 340 * j, 180 * j, 40) * 0.6
        t = t_(0.2)
        cloth = lp(rng.standard_normal(len(t)), 2500) * np.exp(-t * 25) * 0.5
        return np.tanh(1.5 * (x + cloth)) * 0.8
    if name == "step":
        t = t_(0.16)
        tap = thud(rng, 0.16, 180 * j, 90 * j, 60) * 0.35
        splash = hp(rng.standard_normal(len(t)), 3000) * np.exp(-((t - 0.02) / 0.03) ** 2) * 0.35
        return tap + splash
    if name == "land":
        t = t_(0.35)
        x = thud(rng, 0.35, 140 * j, 60 * j, 14) * 0.8
        splash = hp(rng.standard_normal(len(t)), 2500) * np.exp(-t * 18) * 0.35
        return x + splash
    if name == "crack":
        t = t_(0.3)
        snaps = np.zeros(len(t))
        for at in (0.0, 0.012 * j, 0.027 * j):  # a crack is a few snaps on top of each other
            i = int(at * SR)
            snaps[i:] += bp(rng.standard_normal(len(t) - i), 1800, 9000) * np.exp(-t[: len(t) - i] * 90)
        crunch = bp(rng.standard_normal(len(t)), 300, 1500) * np.exp(-t * 30) * 0.5
        return np.tanh(2.5 * (snaps + crunch)) * 0.8
    raise KeyError(name)


def write(x, out):
    pad = np.zeros(int(0.03 * SR))
    x = np.concatenate([x, pad])
    x = x / np.max(np.abs(x)) * 10 ** (-1 / 20)
    st = np.stack([x, x], 1)
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, "x.wav")
        wavfile.write(wav, SR, (st * 32767).astype(np.int16))
        subprocess.run(["sox", wav, "-C", "6", str(out)], check=True)


def main(out):
    out.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(11)
    for name in WHERE:
        for k in (1, 2, 3):
            write(make(name, rng), out / f"{name}-{k}.ogg")
    print(f"OK {len(WHERE)} sound effects, 3 takes each, in {out}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(Path(sys.argv[1]))
