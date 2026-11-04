#!/usr/bin/env python3
"""First music cue, a draft for Javier's ear: level 1, "Neon Row". Javier & Claude, 2026-11-03 (Javier: "move forward
please"; docs/STYLE.md, The sound).

Free, the Karatecation way: our own notes, every instrument built from scratch by synth.py (the assistant team's kit
from their 45-second test), mastered with sox. Gritty, neon, beat-driven, no singing. 124 beats a minute (a touch
faster than the test, it's the brightest level), E minor with a lift to G major in the hook. 32 bars, about a minute,
and it **loops**: the echo and reverb tail is folded back onto the start, so a long fight never hits a gap.

  bars  1-8   the street: pads, bass, a light beat, the arpeggio
  bars  9-16  the fight: the full beat, the lead's verse
  bars 17-24  the hook: brighter chords, the lead up high, open hats
  bars 25-28  the breather: half-time, the arpeggio alone with the bass
  bars 29-32  the build: a snare roll and a rising sweep back into bar 1

Usage: scripts/audio/make_music.py OUT.ogg
"""
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np  # noqa: E402
from scipy.io import wavfile  # noqa: E402

from synth import (SR, arp_note, bass_note, clap, crash, hat, hz, kick, lead_note, lp, pad_chord, place,  # noqa: E402
                   riser, snare)

BPM = 124
STEP = 60 / BPM / 4  # one sixteenth
BAR = STEP * 16
BARS = 32
TAIL = 4.0
N = int((BARS * BAR + TAIL) * SR)
LOOP = int(BARS * BAR * SR)

CHORD = {"Em": ["E3", "G3", "B3"], "C": ["C3", "E3", "G3"], "G": ["G3", "B3", "D4"], "D": ["D3", "F#3", "A3"],
         "Am": ["A3", "C4", "E4"], "B": ["B2", "D#3", "F#3"]}
ROOT = {"Em": "E2", "C": "C2", "G": "G2", "D": "D2", "Am": "A1", "B": "B1"}
VERSE = ["Em", "C", "G", "D", "Em", "C", "Am", "B"]
HOOK = ["G", "D", "Em", "C", "G", "D", "C", "B"]
CHORDS = VERSE + VERSE + HOOK + ["Em", "C", "Em", "C"] + ["Am", "C", "D", "B"]

LEAD_VERSE = [  # (note or None, sixteenths), 16 per bar
    [("B4", 4), ("E5", 2), ("G5", 2), ("F#5", 4), ("E5", 4)],
    [("G5", 4), ("E5", 4), ("C5", 4), (None, 4)],
    [("D5", 2), ("G5", 2), ("B5", 4), ("A5", 4), ("G5", 4)],
    [("F#5", 8), ("A5", 4), ("D5", 4)],
    [("B4", 4), ("E5", 2), ("G5", 2), ("B5", 4), ("A5", 2), ("G5", 2)],
    [("E5", 8), ("G5", 4), ("C6", 4)],
    [("A5", 4), ("C6", 4), ("B5", 4), ("A5", 4)],
    [("F#5", 4), ("D#5", 4), ("B4", 8)],
]
LEAD_HOOK = [
    [("D6", 4), ("B5", 2), ("D6", 2), ("G6", 8)],
    [("F#6", 4), ("E6", 2), ("D6", 2), ("A5", 8)],
    [("B5", 4), ("E6", 4), ("G6", 4), ("E6", 4)],
    [("E6", 6), ("D6", 2), ("C6", 4), ("G5", 4)],
    [("D6", 4), ("B5", 2), ("D6", 2), ("G6", 4), ("A6", 4)],
    [("F#6", 8), ("D6", 8)],
    [("E6", 4), ("G6", 4), ("E6", 4), ("C6", 4)],
    [("D#6", 4), ("F#6", 4), ("B5", 8)],
]
BASS_PAT = [(0, 0), (2, 12), (3, 0), (6, 0), (8, 0), (10, 12), (11, 0), (14, 7)]  # (step, +semitones)


def semis(f, k):
    return f * 2 ** (k / 12)


def section(bar):
    return "street" if bar < 8 else "fight" if bar < 16 else "hook" if bar < 24 else "breather" if bar < 28 else "build"


def build():
    drums, bass, lead, pad, arp, fx = (np.zeros(N) for _ in range(6))
    K, S, C, H, O = kick(), snare(), clap(), hat(), hat(True)
    kicks = []
    for bar, ch in enumerate(CHORDS):
        t0, sec = bar * BAR, section(bar)
        place(pad, pad_chord([hz(x) * (2 if sec == "hook" else 1) for x in CHORD[ch]], BAR), t0, 1.3 if sec == "hook" else 1.0)
        for st, k in BASS_PAT if sec != "breather" else [(0, 0), (8, 0), (11, 12)]:
            place(bass, bass_note(semis(hz(ROOT[ch]), k), STEP * 1.5, cutoff=700 if sec == "street" else 1700), t0 + st * STEP)
        # the beat
        kick_steps = {"street": [0, 8], "fight": [0, 4, 8, 12], "hook": [0, 4, 8, 12], "breather": [0], "build": [0, 4, 8, 12]}[sec]
        for st in kick_steps:
            place(drums, K, t0 + st * STEP)
            kicks.append(t0 + st * STEP)
        for st in range(0, 16, 2):
            place(drums, H, t0 + st * STEP, 0.9 if st % 4 == 2 else 0.55)
        if sec in ("fight", "hook", "build"):
            for st in (4, 12):
                place(drums, S, t0 + st * STEP); place(drums, C, t0 + st * STEP, 0.6)
            for st in range(1, 16, 2):
                place(drums, H, t0 + st * STEP + STEP * 0.1, 0.3)
        if sec == "hook":
            for st in (2, 6, 10, 14):
                place(drums, O, t0 + st * STEP, 0.6)
        if sec == "breather":
            place(drums, C, t0 + 12 * STEP, 0.8)
        if sec == "build":  # a snare roll that fills in toward the loop point
            every = [4, 2, 2, 1][bar - 28]
            for st in range(0, 16, every):
                place(drums, S, t0 + st * STEP, 0.25 + 0.5 * (bar - 28 + st / 16) / 4)
        if bar == 30:
            place(fx, riser(2 * BAR), t0)
        if bar in (8, 16):
            place(fx, crash(), t0)
        # the lead
        line = LEAD_VERSE[bar - 8] if sec == "fight" else LEAD_HOOK[bar - 16] if sec == "hook" else []
        pos, prev = 0, None
        for nm, ln in line:
            if nm:
                f = hz(nm)
                slide = prev if prev and abs(np.log2(f / prev)) < 0.6 else None
                place(lead, lead_note(f, ln * STEP * 0.95, slide_from=slide), t0 + pos * STEP)
                prev = f
            pos += ln
        # the arpeggio: the street, the breather, and under the hook
        if sec in ("street", "breather", "hook"):
            tones = [hz(x) * 4 for x in CHORD[ch]]
            for st in range(16):
                place(arp, arp_note(tones[st % 3] * (2 if st % 8 == 7 else 1), STEP * 0.9), t0 + st * STEP,
                      0.6 if sec == "hook" else 1.0)
    return drums, bass, lead, pad, arp, fx, kicks


def dotted_delay(x, mix=0.28, fb=0.38):
    """The neon glow: a dotted-eighth echo, ping-ponged (as the team's test)."""
    d = int(STEP * 3 * SR)
    left, right = x.copy(), x.copy()
    tap, side = x.copy(), 0
    for i in range(5):
        tap = np.concatenate([np.zeros(d), tap[:-d]]) * (fb if i else 1)
        tap = lp(tap, 4500, 1)
        (left if side == 0 else right)[:] += tap * mix
        side ^= 1
    return left, right


def sidechain(kicks_at, n):
    g = np.ones(n)
    for t in kicks_at:
        i = int(t * SR); k = min(int(0.2 * SR), n - i)
        if k > 0:
            g[i:i + k] = np.minimum(g[i:i + k], 1 - 0.5 * np.exp(-np.arange(k) / SR * 14))
    return g


def main(out):
    drums, bass, lead, pad, arp, fx, kicks = build()
    pump = sidechain(kicks, N)
    ll, lr = dotted_delay(lead)
    al, ar = dotted_delay(arp, mix=0.35)
    L = drums + bass * pump + pad * pump * 0.9 + ll + al * 0.8 + ar * 0.2 + fx
    Rr = drums + bass * pump + pad * pump * 1.1 + lr + ar * 0.8 + al * 0.2 + fx
    mix = np.stack([L, Rr], 1)
    mix = np.tanh(1.15 * mix / np.max(np.abs(mix)) * 1.3) * 0.9
    with tempfile.TemporaryDirectory() as d:
        dry, wet = os.path.join(d, "dry.wav"), os.path.join(d, "wet.wav")
        wavfile.write(dry, SR, (mix * 32767).astype(np.int16))
        subprocess.run(["sox", dry, wet, "gain", "-4", "reverb", "18", "40", "55"], check=True)
        _, x = wavfile.read(wet)
        x = x.astype(np.float64) / 32767
        # the loop: fold everything after the last bar back onto the start, then keep exactly 32 bars
        tail = x[LOOP:]
        x = x[:LOOP].copy()
        x[:len(tail)] += tail
        x = x / np.max(np.abs(x)) * 10 ** (-1 / 20)  # peak at -1 dB
        loop_wav = os.path.join(d, "loop.wav")
        wavfile.write(loop_wav, SR, (x * 32767).astype(np.int16))
        subprocess.run(["sox", loop_wav, "-C", "6", out], check=True)
    print(f"OK {out}: {LOOP / SR:.1f} s, {BARS} bars at {BPM} BPM, loops")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
