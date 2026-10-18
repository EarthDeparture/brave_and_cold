"""Objective checks for menu UI sounds (nobody on the dev side can listen in this loop).

For each WAV: duration, peak dBFS, RMS dBFS, crest, DC offset, onset step (first-sample
jump = click risk), tail level (does it end in silence), spectral centroid / rolloff (85%),
share of energy above 8 kHz (harsh) and below 150 Hz (mud). Also a spectrogram sheet.
Optional: a recorded in-engine mix (menu_mix.wav) gets short-term loudness of each event
over the wind bed.

Usage: python tools/audio/analyze_ui_sounds.py [dir] [--mix path.wav] [--png out.png]
"""
import sys
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]


def load(p):
    w = wave.open(str(p))
    sr, ch, sw, n = w.getframerate(), w.getnchannels(), w.getsampwidth(), w.getnframes()
    raw = w.readframes(n)
    dt = {1: np.int8, 2: np.int16, 4: np.int32}[sw]
    x = np.frombuffer(raw, dt).astype(np.float64) / float(2 ** (8 * sw - 1))
    if ch > 1:
        x = x.reshape(-1, ch).mean(axis=1)
    return x, sr


def db(v):
    return 20 * np.log10(max(v, 1e-9))


def spectrum_stats(x, sr):
    win = np.hanning(len(x)) if len(x) > 8 else np.ones(len(x))
    X = np.abs(np.fft.rfft(x * win)) ** 2
    f = np.fft.rfftfreq(len(x), 1 / sr)
    tot = X.sum() + 1e-18
    centroid = float((f * X).sum() / tot)
    cum = np.cumsum(X) / tot
    rolloff = float(f[np.searchsorted(cum, 0.85)])
    hi = float(X[f > 8000].sum() / tot)
    lo = float(X[f < 150].sum() / tot)
    return centroid, rolloff, hi, lo


def stats(x, sr):
    peak = np.max(np.abs(x))
    rms = np.sqrt(np.mean(x ** 2))
    c, r, hi, lo = spectrum_stats(x, sr)
    tail = np.sqrt(np.mean(x[-max(8, int(0.005 * sr)):] ** 2))
    return {
        "ms": 1000 * len(x) / sr, "peak_db": db(peak), "rms_db": db(rms), "crest_db": db(peak) - db(rms),
        "dc": float(np.mean(x)), "onset_step": float(abs(x[0])), "tail_db": db(tail),
        "centroid_hz": c, "rolloff_hz": r, "hi8k": hi, "lo150": lo,
    }


def spectrogram(x, sr, w=420, h=150, max_ms=400):
    n = 256; hop = 32
    x = np.concatenate([x, np.zeros(int(sr * max_ms / 1000))])[: int(sr * max_ms / 1000)]
    frames = [np.abs(np.fft.rfft(x[i:i + n] * np.hanning(n))) for i in range(0, len(x) - n, hop)]
    S = 20 * np.log10(np.array(frames).T + 1e-7)
    S = np.clip((S + 90) / 90, 0, 1)[::-1]
    img = Image.fromarray((S * 255).astype(np.uint8)).resize((w, h))
    return img.convert("RGB")


def main():
    args = sys.argv[1:]
    d = Path(args[0]) if args and not args[0].startswith("--") else ROOT / "brave-and-cold/assets/audio/ui"
    png = Path(args[args.index("--png") + 1]) if "--png" in args else ROOT / "shots/ui_sound_report.png"
    files = sorted(d.glob("*.wav"))
    rows = []
    sheet = Image.new("RGB", (900, 170 * len(files)), (12, 12, 12))
    dr = ImageDraw.Draw(sheet)
    for i, p in enumerate(files):
        x, sr = load(p)
        s = stats(x, sr)
        rows.append((p.stem, s))
        sheet.paste(spectrogram(x, sr), (470, i * 170 + 10))
        txt = [f"{p.stem}", f"{s['ms']:.0f} ms  peak {s['peak_db']:.1f}  rms {s['rms_db']:.1f}  crest {s['crest_db']:.1f}",
               f"centroid {s['centroid_hz']:.0f} Hz  rolloff85 {s['rolloff_hz']:.0f} Hz",
               f">8k {s['hi8k']*100:.1f}%  <150 {s['lo150']*100:.1f}%  dc {s['dc']:.4f}",
               f"onset step {s['onset_step']:.3f}  tail {s['tail_db']:.1f} dB"]
        for k, t in enumerate(txt):
            dr.text((10, i * 170 + 12 + k * 18), t, fill=(230, 230, 200) if k == 0 else (190, 190, 190))
    sheet.save(png)
    for name, s in rows:
        print(name, " ".join(f"{k}={v:.3f}" if isinstance(v, float) else f"{k}={v}" for k, v in s.items()))
    if "--mix" in args:
        mx, sr = load(args[args.index("--mix") + 1])
        blk = int(0.010 * sr)
        st = np.array([db(np.sqrt(np.mean(mx[i:i + blk] ** 2))) for i in range(0, len(mx) - blk, blk)])
        bed = np.median(st)
        print(f"MIX bed(median 10ms rms) {bed:.1f} dB  max {st.max():.1f} dB  peak {db(np.max(np.abs(mx))):.1f} dBFS")
        ev = np.where(st > bed + 3)[0]
        groups = np.split(ev, np.where(np.diff(ev) > 3)[0] + 1) if len(ev) else []
        for g in groups:
            if len(g):
                print(f"  event t={g[0]*10/1000:.2f}s  dur {len(g)*10} ms  above bed +{st[g].max()-bed:.1f} dB")
        # Masking check in the band the UI ticks live in (1-4 kHz): the wind is mostly below it,
        # so this is what the ear separates. --marks t1,t2,... (s) prints each event's band level.
        if "--marks" in args:
            X = np.fft.rfft(mx); f = np.fft.rfftfreq(len(mx), 1 / sr)
            X[(f < 1000) | (f > 4000)] = 0
            band = np.fft.irfft(X, len(mx))
            bst = np.array([db(np.sqrt(np.mean(band[i:i + blk] ** 2))) for i in range(0, len(band) - blk, blk)])
            bbed = np.median(bst)
            gust = np.percentile(bst, 95)
            print(f"BAND 1-4k bed {bbed:.1f} dB  95th pct (gusts) {gust:.1f} dB = +{gust-bbed:.1f}")
            for tok in args[args.index("--marks") + 1].split(","):
                name, t = tok.split(":")
                i0 = int(float(t) / 0.010)
                pk = bst[max(0, i0 - 3): i0 + 8].max()
                print(f"  {name:6s} t={float(t):.2f}  band peak +{pk-bbed:.1f} dB over bed, {pk-gust:+.1f} dB vs gusts")


if __name__ == "__main__":
    main()
