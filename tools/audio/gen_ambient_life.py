"""Ambient life voices (alive L1): distant wolf howls, great horned owl, raven calls, wing take-off.
Deterministic. numpy + scipy (tools/terrain/.venv).   python tools/audio/gen_ambient_life.py

There are no wolf-howl, owl or corvid recordings in the Sonniss GDC 2026 bundle on disk (scanned), so these are
synthesised from the published acoustics of each call and then placed far away (air absorption low-pass + a
forest/hill reverb), which is how the game uses them - distance hides most of the synthetic tells:
  * grey wolf howl: near-pure tone, f0 ~300-600 Hz, rises over ~0.5 s, long held glide with slow vibrato,
    2nd harmonic ~-12 dB, 3-7 s, breaks/falls at the end;
  * great horned owl: 4-5 soft hoots "hoo-h'hoo hoo hoo", f0 ~280 (male) / ~330 Hz (female), 0.15-0.5 s notes,
    almost pure tone, slight rise-fall in pitch;
  * common raven: harsh "kraa"/"kronk": glottal pulse train f0 ~350-550 Hz with jitter and sub-harmonics through
    formants ~1.1/1.9/3.0 kHz, 0.15-0.35 s, 1-3 calls;
  * take-off: 3-5 birds, flaps at ~5 Hz as band-passed air bursts, fading as they climb.
Output: brave-and-cold/assets/audio/ambient/*.wav (44.1 kHz mono 16-bit, peak -1 dBFS) and a report
tools/audio/ambient_life_report.txt (length, peak, rms, centroid, f0 estimate). NOBODY HAS LISTENED: Troy must.
"""
import glob, io, os, zipfile
import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "brave-and-cold", "assets", "audio", "ambient")
SR = 44100


def lp(x, f, order=4):
    return signal.sosfilt(signal.butter(order, f / (SR / 2), "low", output="sos"), x)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], "band", output="sos"), x)


def env_adsr(n, a, r):
    e = np.ones(n)
    na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    e[:na] = np.sin(np.linspace(0, np.pi / 2, na)) ** 2
    e[-nr:] *= np.cos(np.linspace(0, np.pi / 2, nr)) ** 2
    return e


def reverb(x, rng, rt=2.2, wet=0.5, echoes=(), damp=2500.0):
    """Forest/hill space: exponentially decaying filtered noise IR + a few discrete late reflections."""
    n = int(rt * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-6.9 * t / rt)
    ir = lp(ir, damp, 2)
    ir[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
    for d, g in echoes:
        k = int(d * SR)
        if k < n: ir[k:k + 400] += g * np.hanning(400) * 6.0
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    dry = np.concatenate([x, np.zeros(n)])
    w = np.zeros(len(dry))
    c = signal.fftconvolve(x, ir)[: len(dry)]
    w[: len(c)] = c
    return dry * (1 - wet) + w * wet * 1.6


def tone(f0, amps, rng, jitter=0.0):
    """Additive harmonics along an f0 contour (array, Hz)."""
    if jitter > 0:
        f0 = f0 * (1 + jitter * lp(rng.standard_normal(len(f0)), 30.0, 2) * 8)
    ph = 2 * np.pi * np.cumsum(f0) / SR
    out = np.zeros(len(f0))
    for k, a in enumerate(amps, 1):
        out += a * np.sin(k * ph + rng.uniform(0, 6.28))
    return out


def norm(x, peak_db=-1.0):
    return x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak_db / 20)


def fade_tail(x, s=0.25):
    n = int(s * SR)
    x[-n:] *= np.linspace(1, 0, n) ** 2
    return x


# ---------------------------------------------------------------- wolf howl (distant)
def howl(seed, f_lo, f_hi, dur, fall):
    rng = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    rise = 0.35 + rng.uniform(0, 0.4)
    f0 = f_lo + (f_hi - f_lo) * (1 - np.exp(-t / rise * 2.2))
    f0 += (f_hi * 0.035) * np.sin(2 * np.pi * 0.35 * t + rng.uniform(0, 6))       # slow glide wander
    if fall:   # the end falls away and breaks
        k = t > dur - 1.0
        f0[k] -= (f_hi - f_lo * 0.8) * ((t[k] - (dur - 1.0)) / 1.0) ** 1.6
    f0 *= 1 + 0.010 * np.sin(2 * np.pi * 5.4 * t) * np.clip((t - 0.8) / 1.0, 0, 1)  # late vibrato
    x = tone(f0, [1.0, 0.25, 0.08, 0.03], rng, jitter=0.0008)
    breath = bp(rng.standard_normal(n), 500, 1800) * 0.04
    e = env_adsr(n, 0.28, 0.7) * (1 + 0.12 * np.sin(2 * np.pi * 0.6 * t))
    x = (x + breath) * e
    x = lp(x, 1600)                        # several hundred metres of air + trees
    x = reverb(x, rng, rt=2.8, wet=0.55, echoes=[(0.42, 0.5), (0.95, 0.35), (1.6, 0.2)], damp=1400)
    return fade_tail(norm(x))


# ---------------------------------------------------------------- great horned owl
def owl(seed, f, pattern):
    rng = np.random.default_rng(seed)
    total = pattern[-1][0] + pattern[-1][1] + 0.2
    x = np.zeros(int(total * SR))
    for st, ln in pattern:
        n = int(ln * SR)
        t = np.arange(n) / SR
        f0 = f * (1 + 0.035 * np.sin(np.pi * t / ln) - 0.02 * t / ln) * rng.uniform(0.99, 1.01)
        h = tone(f0, [1.0, 0.05, 0.015], rng) * np.sin(np.pi * t / ln) ** 1.5
        h += bp(rng.standard_normal(n), f * 0.8, f * 2.5) * 0.02 * np.sin(np.pi * t / ln)
        k = int(st * SR)
        x[k:k + n] += h
    x = lp(x, 2200)
    x = reverb(x, rng, rt=1.2, wet=0.26, echoes=[(0.3, 0.2)], damp=1500)
    return fade_tail(norm(x))


# ---------------------------------------------------------------- raven
def croak(rng, f, ln):
    n = int(ln * SR)
    t = np.arange(n) / SR
    f0 = f * (1.04 - 0.10 * t / ln) * (1 + 0.04 * lp(rng.standard_normal(n), 80, 2) * 10)
    ph = np.cumsum(f0) / SR
    pulse = (ph % 1.0)
    src = (np.exp(-pulse * 9.0) - 0.11)          # glottal-ish pulse train: buzzy, rich in harmonics
    src += 0.35 * (((ph * 0.5) % 1.0) < 0.5) * np.exp(-pulse * 9.0)   # sub-harmonic -> the "kr" roughness
    src += 0.07 * rng.standard_normal(n)          # aspiration
    src *= 1 + 0.45 * np.sin(2 * np.pi * rng.uniform(55, 80) * t)     # rattle
    y = bp(src, 950, 1300) * 1.0 + bp(src, 1700, 2150) * 0.7 + bp(src, 2800, 3300) * 0.35 + bp(src, 450, 700) * 0.4
    return y * env_adsr(n, 0.015, 0.07)


def raven(seed, f, calls):
    rng = np.random.default_rng(seed)
    gap = 0.42
    x = np.zeros(int((calls * gap + 0.6) * SR))
    for i in range(calls):
        ln = rng.uniform(0.17, 0.30)
        c = croak(rng, f * rng.uniform(0.96, 1.04), ln)
        k = int((i * gap + rng.uniform(0, 0.05)) * SR)
        x[k:k + len(c)] += c * (1 - 0.15 * i)
    x = lp(x, 6000)
    x = reverb(x, rng, rt=0.9, wet=0.18, damp=3000)
    return fade_tail(norm(x))


# ---------------------------------------------------------------- take-off wings
def wings(seed, birds):
    rng = np.random.default_rng(seed)
    x = np.zeros(int(2.6 * SR))
    for b in range(birds):
        t0 = rng.uniform(0, 0.12)
        rate = rng.uniform(4.2, 5.6)
        for i in range(10):
            st = t0 + i / rate
            n = int(0.065 * SR)
            k = int(st * SR)
            if k + n >= len(x): break
            burst = bp(rng.standard_normal(n), 180, 1500) * np.sin(np.linspace(0, np.pi, n)) ** 3
            burst += bp(rng.standard_normal(n), 3000, 7000) * 0.04 * np.hanning(n)
            x[k:k + n] += burst * (0.92 ** (i * 1.4)) * rng.uniform(0.7, 1.0)
    x = reverb(x, rng, rt=0.8, wet=0.2, damp=4000)
    return fade_tail(norm(x))


# ---------------------------------------------------------------- aurora radio static (recorded)
def aurora_static():
    """A real powered-on ham receiver hiss (Sonniss GDC 2026, Epic Stock Media 'Fake Advertisements and Radio'),
    10 s cut into a seamless loop, band-limited like a small speaker, with slow swells added (the aurora
    'breathing' through the receiver)."""
    zdir = os.path.expanduser("~/Downloads")
    g = glob.glob(os.path.join(zdir, "*GameAudioBundle2of5*.zip"))
    if not g: raise SystemExit("missing Sonniss part 2")
    zf = zipfile.ZipFile(g[0])
    name = next(n for n in zf.namelist() if "COMStatic_Radio Ham Loop Static Hum" in n and n.endswith(".wav"))
    sr, x = wavfile.read(io.BytesIO(zf.read(name)))
    x = x.astype(np.float64) / (32768.0 if x.dtype == np.int16 else float(np.iinfo(x.dtype).max) if x.dtype.kind == "i" else 1.0)
    if x.ndim > 1: x = x.mean(axis=1)
    gg = np.gcd(SR, sr)
    x = signal.resample_poly(x, SR // gg, sr // gg)
    seg = x[int(4.0 * SR): int(14.6 * SR)]
    seg = bp(seg, 280, 3600, 3)
    n = len(seg); xf = int(0.6 * SR)
    loop = seg[: n - xf].copy()
    ramp = np.linspace(0, 1, xf)
    loop[:xf] = loop[:xf] * ramp + seg[n - xf:] * (1 - ramp)   # crossfade the tail into the head: seamless
    tt = np.arange(len(loop)) / SR
    swell = 0.75 + 0.25 * np.sin(2 * np.pi * tt / (len(loop) / SR) * 3 + 1.0)   # integer cycles: loops clean
    return norm(loop * swell, -3.0)


def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
    sp = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    cen = float(np.sum(fr * sp) / (np.sum(sp) + 1e-9))
    pk = fr[np.argmax(sp[fr > 150]) + np.sum(fr <= 150)]
    rms = 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9)
    return "%-12s %5.2f s  rms %6.1f dB  centroid %6.0f Hz  spectral peak %6.0f Hz" % (name, len(x) / SR, rms, cen, pk)


def main():
    rep = []
    rep.append(write("howl_far_0", howl(11, 340, 520, 5.2, True)))
    rep.append(write("howl_far_1", howl(12, 300, 450, 6.0, True)))     # deeper: big male
    rep.append(write("howl_far_2", howl(13, 420, 610, 4.0, False)))    # higher, younger
    rep.append(write("howl_far_3", howl(14, 380, 560, 3.2, True)))
    rep.append(write("owl_0", owl(21, 285, [(0.0, 0.32), (0.45, 0.14), (0.66, 0.38), (1.45, 0.42), (2.2, 0.44)])))
    rep.append(write("owl_1", owl(22, 335, [(0.0, 0.28), (0.40, 0.12), (0.58, 0.30), (1.1, 0.34), (1.65, 0.36)])))
    rep.append(write("raven_0", raven(31, 420, 2)))
    rep.append(write("raven_1", raven(32, 380, 3)))
    rep.append(write("raven_2", raven(33, 520, 1)))
    rep.append(write("raven_3", raven(34, 460, 2)))
    rep.append(write("wings_0", wings(41, 3)))
    rep.append(write("wings_1", wings(42, 4)))
    rep.append(write("aurora_static", aurora_static()))
    with open(os.path.join(ROOT, "tools", "audio", "ambient_life_report.txt"), "w") as f:
        f.write("\n".join(rep) + "\n")
    print("\n".join(rep))


if __name__ == "__main__":
    main()
