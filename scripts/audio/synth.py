"""The instrument kit: every sound built from scratch with numpy/scipy (no samples, no instrument library, $0).
Javier & Claude, 2026-11-03. Taken from the assistant team's free 45-second music test (2026-11-02,
cyberbrawling-music-test-2026-11-02-source/make_test_track.py on the shelf), kept as they wrote it so the sound
matches what Javier heard; the cues and effects that use it are ours (make_music.py, make_sfx.py)."""
import numpy as np
from scipy import signal

SR = 48000
R = np.random.default_rng(7)

NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}

def hz(name):
    """'E5' -> frequency (A4 = 440)."""
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[pitch] + 12 * (octave + 1) - 69) / 12)


# ------------------------------------------------------------------ oscillators and shapes

def blep_saw(freq, n, phase0=0.0):
    """Band-limited saw (polyBLEP): bright without the fizz of a naive saw."""
    f = np.broadcast_to(np.asarray(freq, float), (n,))
    dt = f / SR
    ph = (phase0 + np.cumsum(dt)) % 1.0
    y = 2 * ph - 1
    a = ph < dt
    t = ph[a] / dt[a]; y[a] -= t + t - t * t - 1
    b = ph > 1 - dt
    t = (ph[b] - 1) / dt[b]; y[b] -= t * t + t + t + 1
    return y


def blep_square(freq, n, width=0.5):
    return 0.5 * (blep_saw(freq, n) - blep_saw(freq, n, phase0=width))


def env(n, a, d, s, r):
    """ADSR in seconds over n samples (release taken from the end)."""
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    e = np.full(n, s, float)
    a = min(a, n); e[:a] = np.linspace(0, 1, a, endpoint=False) if a else e[:a]
    d2 = min(d, max(0, n - a)); e[a:a + d2] = np.linspace(1, s, d2, endpoint=False) if d2 else e[a:a + d2]
    r = min(r, n); e[n - r:] *= np.linspace(1, 0, r) if r else 1
    return e


def lowpass_sweep(x, f_start, f_end, q=1.2, block=64):
    """Time-varying resonant low-pass (RBJ biquad, coefficients per block, state carried)."""
    out = np.empty_like(x)
    zi = np.zeros(2)
    n = len(x)
    fc = np.geomspace(max(f_start, 30), max(f_end, 30), max(1, n // block + 1))
    for i, s in enumerate(range(0, n, block)):
        w = 2 * np.pi * min(fc[i], SR * 0.45) / SR
        al = np.sin(w) / (2 * q); c = np.cos(w)
        b = np.array([(1 - c) / 2, 1 - c, (1 - c) / 2]); a = np.array([1 + al, -2 * c, 1 - al])
        out[s:s + block], zi = signal.lfilter(b / a[0], a / a[0], x[s:s + block], zi=zi)
    return out


def hp(x, fc, order=2):
    return signal.sosfilt(signal.butter(order, fc, "highpass", fs=SR, output="sos"), x)


def lp(x, fc, order=2):
    return signal.sosfilt(signal.butter(order, fc, "lowpass", fs=SR, output="sos"), x)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(signal.butter(order, [lo, hi], "bandpass", fs=SR, output="sos"), x)


def place(dst, src, at, gain=1.0):
    i = int(at * SR)
    if i >= len(dst):
        return
    m = min(len(src), len(dst) - i)
    dst[i:i + m] += src[:m] * gain


# ------------------------------------------------------------------ the instruments

def kick():
    n = int(0.42 * SR); t = np.arange(n) / SR
    f = 46 + 130 * np.exp(-t * 32)                       # the pitch drop is the punch
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7.5)
    click = hp(R.standard_normal(n), 2500) * np.exp(-t * 260) * 0.35
    return np.tanh(2.2 * (body + click)) * 0.95


def snare():
    n = int(0.32 * SR); t = np.arange(n) / SR
    tone = (np.sin(2 * np.pi * 186 * t) + 0.5 * np.sin(2 * np.pi * 330 * t)) * np.exp(-t * 28)
    noise = bp(R.standard_normal(n), 1400, 9000) * np.exp(-t * 15)
    return np.tanh(1.6 * (0.55 * tone + 0.9 * noise)) * 0.8


def clap():
    n = int(0.28 * SR); t = np.arange(n) / SR
    e = np.zeros(n)
    for k, at in enumerate((0.0, 0.011, 0.022)):          # three quick slaps make a clap
        i = int(at * SR); e[i:] += np.exp(-(t[: n - i]) * (180 if k < 2 else 22))
    return bp(R.standard_normal(n), 900, 5000) * e * 0.5


def hat(open_=False):
    n = int((0.30 if open_ else 0.06) * SR); t = np.arange(n) / SR
    metal = sum(blep_square(f, n) for f in (317, 432, 551, 677, 793, 1013))   # inharmonic squares, the 808 way
    x = hp(metal * 0.15 + R.standard_normal(n) * 0.6, 7000, 3)
    return x * np.exp(-t * (11 if open_ else 70)) * (0.30 if open_ else 0.24)


def riser(dur):
    n = int(dur * SR); t = np.arange(n) / SR
    x = lowpass_sweep(R.standard_normal(n), 300, 12000, q=3.0)
    return x * (t / dur) ** 2 * 0.35


def crash():
    n = int(1.8 * SR); t = np.arange(n) / SR
    return hp(R.standard_normal(n), 3500) * np.exp(-t * 2.6) * 0.22


def bass_note(f, dur, cutoff=1400):
    n = int(dur * SR)
    x = blep_saw(f, n) + 0.6 * blep_saw(f * 0.5, n) + 0.35 * blep_square(f * 1.003, n)
    x = lowpass_sweep(x, cutoff, 110, q=1.6)               # pluck: the filter snaps shut
    return np.tanh(1.8 * x) * env(n, 0.003, 0.08, 0.55, 0.02) * 0.5


def lead_note(f, dur, slide_from=None):
    n = int(dur * SR); t = np.arange(n) / SR
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - 0.18) / 0.2, 0, 1)   # vibrato comes in late
    fr = np.full(n, f)
    if slide_from:
        k = min(n, int(0.06 * SR)); fr[:k] = np.geomspace(slide_from, f, k)
    fr = fr * vib
    x = blep_saw(fr * 1.004, n) + blep_saw(fr * 0.996, n) + 0.5 * blep_square(fr * 2, n, 0.3)
    x = lowpass_sweep(x, 5200, 2200, q=1.1)
    return np.tanh(1.4 * x) * env(n, 0.006, 0.12, 0.75, 0.05) * 0.26


def pad_chord(freqs, dur):
    n = int(dur * SR)
    x = sum(blep_saw(f * d, n) for f in freqs for d in (0.997, 1.0, 1.004))
    return lp(x, 1600) * env(n, 0.5, 0.4, 0.8, 0.6) * 0.05


def arp_note(f, dur):
    n = int(dur * SR)
    return lowpass_sweep(blep_square(f, n, 0.25), 6000, 900, q=2.0) * env(n, 0.002, 0.06, 0.2, 0.02) * 0.11


