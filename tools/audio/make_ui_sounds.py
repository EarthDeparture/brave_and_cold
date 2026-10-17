"""Derive short menu UI sounds from foley already in the project (no new downloads).

ui_hover.wav : the attack of paper_turn.wav (~85 ms), fast fade -> a soft paper tick
ui_click.wav : switch_click.wav, trimmed of silence
ui_back.wav  : the click pitched down ~0.84 (slower playback)
ui_start.wav : thud.wav low-passed, a soft heavy "commit" for New Game / Continue

Usage: python tools/audio/make_ui_sounds.py   (run from the repo root)
"""
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "brave-and-cold"
SRC = ROOT / "assets/audio/sfx"
OUT = ROOT / "assets/audio/ui"
RATE = 22050


def read(name):
    w = wave.open(str(SRC / name))
    n, sr, ch, sw = w.getnframes(), w.getframerate(), w.getnchannels(), w.getsampwidth()
    raw = w.readframes(n)
    assert sw == 2
    s = struct.unpack("<%dh" % (n * ch), raw)
    if ch > 1:
        s = [sum(s[i:i + ch]) / ch for i in range(0, len(s), ch)]
    s = [v / 32768.0 for v in s]
    if sr != RATE:
        s = resample(s, sr / RATE)
    return s


def resample(s, step):
    """Linear resample: step > 1 shortens (pitch up), < 1 lengthens (pitch down)."""
    out, pos = [], 0.0
    while pos < len(s) - 1:
        i = int(pos); f = pos - i
        out.append(s[i] * (1 - f) + s[i + 1] * f)
        pos += step
    return out


def lowpass(s, hz):
    a = 1.0 - math.exp(-2.0 * math.pi * hz / RATE)
    y, out = 0.0, []
    for v in s:
        y += a * (v - y); out.append(y)
    return out


def trim(s, thr=0.02):
    i = next((k for k, v in enumerate(s) if abs(v) > thr), 0)
    j = len(s) - next((k for k, v in enumerate(reversed(s)) if abs(v) > thr), 0)
    return s[max(0, i - int(0.003 * RATE)):j]


def fade(s, fin_ms, fout_ms):
    n_in, n_out = int(fin_ms * RATE / 1000), int(fout_ms * RATE / 1000)
    s = list(s)
    for k in range(min(n_in, len(s))):
        s[k] *= k / max(1, n_in)
    for k in range(min(n_out, len(s))):
        s[-1 - k] *= (k / max(1, n_out)) ** 2
    return s


def norm(s, peak):
    m = max(1e-6, max(abs(v) for v in s))
    return [v * peak / m for v in s]


def write(name, s):
    OUT.mkdir(parents=True, exist_ok=True)
    w = wave.open(str(OUT / name), "wb")
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
    w.writeframes(struct.pack("<%dh" % len(s), *[int(max(-1, min(1, v)) * 32767) for v in s]))
    w.close()
    print(name, round(len(s) / RATE, 3), "s")


paper = trim(read("paper_turn.wav"))
# window around the loudest 10 ms of the first 0.3 s: the crisp part of the turn
win = int(0.010 * RATE)
best = max(range(0, min(len(paper), int(0.3 * RATE)) - win, win // 2),
           key=lambda k: sum(abs(v) for v in paper[k:k + win]))
start = max(0, best - int(0.012 * RATE))
hover = paper[start:start + int(0.085 * RATE)]
write("ui_hover.wav", norm(fade(lowpass(hover, 6000), 4, 55), 0.45))

click = trim(read("switch_click.wav"))
write("ui_click.wav", norm(fade(click, 1, 20), 0.6))
write("ui_back.wav", norm(fade(resample(click, 0.84), 1, 25), 0.55))

thud = trim(read("thud.wav"))
write("ui_start.wav", norm(fade(lowpass(thud, 900), 2, 120), 0.7))
