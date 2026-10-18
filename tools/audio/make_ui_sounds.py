"""Menu UI sounds, built from project foley plus a small synthesized tick (no downloads).

v2 (after tools/audio/analyze_ui_sounds.py; nobody could listen in the loop):
  v1 hover was an 85 ms flat broadband noise burst (reads as static "shh"); v1 start had
  92% of its energy below 150 Hz (centroid 69 Hz), i.e. near-silent on laptop speakers.

ui_hover.wav : 40 ms soft tick: band-limited noise (1.2-3.4 kHz) with a 7 ms exponential
               decay + a quiet damped 1.4 kHz "body" (like a fingertip on card stock)
ui_click.wav : switch_click.wav, gently trimmed, 3 ms fade-in, small low shelf cut
ui_back.wav  : the click pitched to 0.84 (lower = going back)
ui_start.wav : a wooden latch clack (gate_latch.wav) over the thud's body band-passed to
               160-2500 Hz (4-pole), so it carries on small speakers; 420 ms

Usage: python tools/audio/make_ui_sounds.py   (run from the repo root)
"""
import struct
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2] / "brave-and-cold"
SRC = ROOT / "assets/audio/sfx"
OUT = ROOT / "assets/audio/ui"
RATE = 44100
rng = np.random.default_rng(20261017)


def read(name):
    w = wave.open(str(SRC / name))
    n, sr, ch, sw = w.getnframes(), w.getframerate(), w.getnchannels(), w.getsampwidth()
    x = np.frombuffer(w.readframes(n), np.int16).astype(np.float64) / 32768.0
    if ch > 1:
        x = x.reshape(-1, ch).mean(axis=1)
    if sr != RATE:
        x = np.interp(np.arange(0, len(x) * RATE / sr) * sr / RATE, np.arange(len(x)), x)
    return x


def onepole_lp(x, hz):
    a = 1.0 - np.exp(-2.0 * np.pi * hz / RATE)
    y = np.empty_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc); y[i] = acc
    return y


def bandpass(x, lo, hi):
    """Two cascaded one-pole LP minus LP: a gentle band-pass, no ringing."""
    lp_hi = onepole_lp(onepole_lp(x, hi), hi)
    lp_lo = onepole_lp(onepole_lp(x, lo), lo)
    return lp_hi - lp_lo


def trim(x, thr=0.01):
    idx = np.where(np.abs(x) > thr)[0]
    if len(idx) == 0:
        return x
    return x[max(0, idx[0] - int(0.002 * RATE)): idx[-1] + int(0.004 * RATE)]


def fade(x, fin_ms, fout_ms):
    x = x.copy()
    ni, no = int(fin_ms * RATE / 1000), int(fout_ms * RATE / 1000)
    if ni: x[:ni] *= np.linspace(0, 1, ni)
    if no: x[-no:] *= np.linspace(1, 0, no) ** 2
    return x


def norm(x, peak):
    return x * (peak / max(1e-9, np.max(np.abs(x))))


def write(name, x):
    OUT.mkdir(parents=True, exist_ok=True)
    w = wave.open(str(OUT / name), "wb")
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
    w.writeframes(struct.pack("<%dh" % len(x), *(np.clip(x, -1, 1) * 32767).astype(np.int16)))
    w.close()
    print(name, round(len(x) / RATE * 1000), "ms")


# hover: soft tick
n = int(0.040 * RATE)
t = np.arange(n) / RATE
env = np.exp(-t / 0.007)
noise = bandpass(bandpass(rng.standard_normal(n), 1200, 3400), 1200, 3400) * env
body = np.sin(2 * np.pi * 1400 * t) * np.exp(-t / 0.004) * 0.35
hover = fade(noise + body, 1.0, 12)
write("ui_hover.wav", norm(hover, 0.5))

# click / back
click = trim(read("switch_click.wav"))
click = click - onepole_lp(click, 180) * 0.6          # low shelf cut: less "thump" in the click
click = fade(click[: int(0.060 * RATE)], 3.0, 25)
write("ui_click.wav", norm(click, 0.6))
back = np.interp(np.arange(0, len(click), 0.84), np.arange(len(click)), click)
write("ui_back.wav", norm(fade(back, 3.0, 30), 0.55))

# start: latch clack + mid-band thud body
latch = trim(read("gate_latch.wav"))
thud = trim(read("thud.wav"))
thud_body = bandpass(bandpass(thud, 160, 2500), 160, 2500)   # 4 poles each side: v2a still had 87% < 150 Hz
L = int(0.42 * RATE)
mix = np.zeros(L)
lt = norm(latch[: L], 0.55)
mix[: len(lt)] += lt
off = int(0.035 * RATE)
tb = norm(thud_body[: L - off], 0.5)
mix[off: off + len(tb)] += tb
write("ui_start.wav", norm(fade(mix, 2.0, 140), 0.75))
