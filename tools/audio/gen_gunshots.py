"""Rifle report kit (weapons W7): open + moderated blasts per report class, bullet crack, environment tails and
action foley. Deterministic. numpy + scipy (tools/terrain/.venv).

python tools/audio/gen_gunshots.py [--zips DIR]

There are no firearm recordings in the Sonniss GDC 2026 bundle on disk, so the blast is synthesised from the
physics of a muzzle blast as heard at the shooter's ear:
  * Friedlander pressure pulse (positive phase 0.35-1.4 ms by calibre, then the negative phase),
  * the reflection off the snow 3-5 ms later (snow absorbs the top end -> low-passed),
  * the chest thump (45-110 Hz, decaying 40-120 ms) and the receiver's ring,
  * for supersonic rounds the bullet's N-wave crack, blended with a real recorded whip crack (a whip tip breaking the
    sound barrier is the same physics, on a small scale),
  * a muzzle brake adds a harsh 1-3 kHz side blast.
A MODERATOR does not just low-pass that: the gas leaves slowly through the baffles, so the moderated blast has its
own envelope (2-4 ms rise, short "thup/pfft" centred ~400-700 Hz), no chest thump, a faint baffle ting, and is
mixed ~20-30 dB down in the game. A supersonic bullet still cracks (the can cannot stop that) - the crack is a
separate layer the game adds on top. Tails are separate so the game can pick outdoor/indoor and scale them
(a moderated shot excites ~20 dB less echo; with a supersonic round the echo you hear is mostly the crack's).
Action foley (bolt, lever, semi clack) is cut from real metal mechanism recordings in the bundle.

Output: brave-and-cold/assets/audio/weapons/*.wav (44.1 kHz mono 16-bit, peak -1 dBFS; the game sets the
mix levels in GameAudio.REPORT_DB) and a measurement report tools/audio/gunshot_report.txt (peak, RMS, spectral
centroid, energy decay T20, length) - checked against real reference values because nobody here can listen.
Licence of the recorded layers: Sonniss GDC bundle, royalty-free.
"""
import argparse, glob, io, os, zipfile
import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "brave-and-cold", "assets", "audio", "weapons")
SR = 44100

SOURCES = {   # key -> (zip part, member substring)
    "whip": (2, "WEAPWhip_WHIP Snap Crack 05"),
    "latch": (2, "MECHLtch_Click Deep Mechanism Latch"),
    "cara_screw": (1, "Carabiner, Screwing Lock 01"),
    "cara_flick": (1, "Flicking Carabiner On Rope"),
    "lock": (1, "Tinkering Antique Lock"),
}


def load_sources(zdir):
    out = {}
    for k, (part, sub) in SOURCES.items():
        g = glob.glob(os.path.join(zdir, "*%dof5*.zip" % part))
        if not g: raise SystemExit("missing Sonniss part %d in %s" % (part, zdir))
        zf = zipfile.ZipFile(g[0])
        name = next(n for n in zf.namelist() if sub in n and n.endswith(".wav"))
        sr, x = wavfile.read(io.BytesIO(zf.read(name)))
        if x.dtype.kind == "i": x = x.astype(np.float64) / float(np.iinfo(x.dtype).max)
        elif x.dtype.kind == "u": x = (x.astype(np.float64) - 128.0) / 128.0
        else: x = x.astype(np.float64)
        if x.ndim > 1: x = x.mean(axis=1)
        g_ = np.gcd(SR, sr)
        out[k] = signal.resample_poly(x, SR // g_, sr // g_)
    return out


# ---------------------------------------------------------------- dsp helpers
def lp(x, f, order=2): return signal.sosfilt(signal.butter(order, min(f, SR * 0.45), "low", fs=SR, output="sos"), x)
def hp(x, f, order=2): return signal.sosfilt(signal.butter(order, f, "high", fs=SR, output="sos"), x)
def bp(x, a, b, order=2): return signal.sosfilt(signal.butter(order, [a, b], "band", fs=SR, output="sos"), x)
def secs(n): return np.arange(int(n * SR)) / SR
def place(dst, src, t, g=1.0):
    i = int(t * SR); n = min(len(src), len(dst) - i)
    if n > 0: dst[i:i + n] += src[:n] * g
def norm(x, peak_db=-1.0):
    return x * (10 ** (peak_db / 20.0) / (np.max(np.abs(x)) + 1e-12))
def fade(x, a=0.0005, b=0.03):
    x = x.copy(); na, nb = int(a * SR), int(b * SR)
    if na: x[:na] *= np.linspace(0, 1, na)
    if nb: x[-nb:] *= np.linspace(1, 0, nb) ** 2
    return x


def friedlander(td, b=1.6, length=None):
    t = secs(length or td * 12)
    return (1.0 - t / td) * np.exp(-b * t / td)


def nwave(dur):
    n = max(int(dur * SR), 4); w = np.linspace(1.0, -1.0, n)
    return np.concatenate([[0.0], w, [0.0]])


def sweep_sine(f0, f1, tau_f, decay, length):
    t = secs(length); f = f1 + (f0 - f1) * np.exp(-t / tau_f)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / decay)


def onset(x, thr_db=-30.0):
    e = np.abs(x); thr = np.max(e) * 10 ** (thr_db / 20.0)
    return int(np.argmax(e > thr))


def slice_at(x, t0, dur, pre=0.002):
    i = max(0, int((t0 - pre) * SR)); return x[i:i + int(dur * SR)]


def nth_onset(x, k, gap=0.25, thr_db=-24.0):
    hop = int(SR * 0.005); env = np.sqrt(np.convolve(x * x, np.ones(hop) / hop, "same"))[::hop]
    db = 20 * np.log10(env / (env.max() + 1e-12) + 1e-9)
    ons = []
    for i in range(4, len(db)):
        if db[i] - db[i - 4] > 14 and db[i] > thr_db and (not ons or (i - ons[-1]) * 0.005 > gap): ons.append(i)
    return ons[min(k, len(ons) - 1)] * 0.005 if ons else 0.0


def pitch(x, f):   # resample speed change (pitch and length together, like a smaller / bigger part)
    n = int(len(x) / f); return signal.resample(x, max(n, 8))


# ---------------------------------------------------------------- report classes
CLASSES = {
    #             td(ms) thump f0,f1,decay(s) amp  noise LP, decay, amp  ring f, amp  crack amp  brake
    # the pressure spike is by far the biggest thing at the ear; the thump and the gas noise sit well under it
    "rimfire":      dict(td=.35, th=(140, 85, .030, .10), nz=(4200, .020, .35), ring=(3600, .05), crack=0.0, brake=0.0, gr=.40),
    "intermediate": dict(td=.85, th=(95, 58, .050, .22), nz=(3000, .035, .40), ring=(2900, .04), crack=.55, brake=0.0, gr=.45),
    "medium":       dict(td=1.05, th=(85, 50, .060, .28), nz=(2800, .040, .45), ring=(2500, .035), crack=.60, brake=0.0, gr=.45),
    "magnum_brake": dict(td=1.35, th=(72, 44, .070, .32), nz=(2600, .050, .50), ring=(2200, .03), crack=.65, brake=.55, gr=.45),
}


def crack_layer(src, rng):
    n = nwave(rng.uniform(0.00022, 0.00034))
    w = src["whip"]; o = onset(w, -20.0)
    o += int(rng.uniform(-0.0004, 0.0004) * SR)
    real = hp(w[max(0, o - int(.0015 * SR)): o + int(rng.uniform(.014, .022) * SR)], rng.uniform(1300, 1900), 4)
    real = fade(real, 0.0002, 0.012) / (np.max(np.abs(real)) + 1e-9)
    out = np.zeros(int(.05 * SR)); place(out, n, 0.0, 1.0); place(out, real, 0.0003, 0.45)
    return hp(out, 1000, 2)


def blast_open(cls, src, seed):
    rng = np.random.default_rng(seed); c = CLASSES[cls]
    L = 0.42; x = np.zeros(int(L * SR))
    td = c["td"] * 1e-3 * rng.uniform(0.92, 1.08)
    p = friedlander(td, 1.6 * rng.uniform(.9, 1.1))
    direct = np.zeros_like(x); place(direct, p, 0.0)
    if c["crack"] > 0: place(direct, crack_layer(src, rng), 0.0, c["crack"] * 0.6)
    f0, f1, dec, amp = c["th"]
    place(direct, sweep_sine(f0 * rng.uniform(.95, 1.05), f1, 0.012, dec, 0.4), 0.0003, amp)
    nzf, nzd, nza = c["nz"]
    t = secs(L); nz = lp(rng.standard_normal(len(t)), nzf) * np.exp(-t / nzd)
    place(direct, nz / (np.max(np.abs(nz)) + 1e-9), 0.0001, nza)
    rf, ra = c["ring"]
    t = secs(0.06); ring = bp(rng.standard_normal(len(t)), rf * .75, rf * 1.3) * np.exp(-t / .012)   # steel rings as a noisy band, not a tone
    ring /= np.max(np.abs(ring)) + 1e-9
    place(direct, ring, 0.0008, ra)
    if c["brake"] > 0:   # side ports throw the blast back at the shooter: harsh, louder mid band
        t = secs(0.12); sb = bp(rng.standard_normal(len(t)), 900, 3200) * np.exp(-t / .03)
        place(direct, sb / (np.max(np.abs(sb)) + 1e-9), 0.0004, c["brake"])
    x += direct
    place(x, lp(direct, 1500), rng.uniform(0.0032, 0.0048), c["gr"])          # off the snow
    # near scatter off the shooter's surroundings in the first 300 ms (trunks, the ground further out)
    for k in range(10):
        d = rng.uniform(0.012, 0.30)
        place(x, lp(direct[:int(.03 * SR)], 3000 / (1 + d * 10)), d, rng.uniform(.04, .14) / (1 + d * 6))
    x = np.tanh(x * 1.0) / np.tanh(1.0)                                     # the ear / mic flattening the peak
    return fade(norm(x), 0.0, 0.15)


SUP = {   # moderated (gas through the baffles): no chest thump, slower rise, short
    "sup_rimfire": dict(rise=.0018, band=(220, 1400), nzd=.016, thup=(190, 120, .022, .45), res=(.55, 900, .25), ting=.025),
    "sup_centre":  dict(rise=.0030, band=(140, 1100), nzd=.030, thup=(125, 80, .045, .60), res=(1.0, 600, .35), ting=.02),
}


def blast_sup(cls, src, seed):
    rng = np.random.default_rng(seed); c = SUP[cls]
    x = np.zeros(int(0.22 * SR))
    t = secs(0.21)
    env = (1 - np.exp(-t / c["rise"])) * np.exp(-t / c["nzd"])
    nz = bp(rng.standard_normal(len(t)), *c["band"]) * env
    place(x, nz / (np.max(np.abs(nz)) + 1e-9), 0.0, 1.0)
    f0, f1, dec, amp = c["thup"]
    th = sweep_sine(f0, f1, .008, dec, 0.15) * (1 - np.exp(-secs(0.15) / c["rise"]))
    place(x, th, 0.0, amp)
    tdm, f, a = c["res"]
    place(x, lp(friedlander(tdm * 1e-3), f), 0.0005, a)                       # what pressure still leaks out
    tt = secs(0.12)
    ting = (np.sin(2 * np.pi * 4300 * tt) + .7 * np.sin(2 * np.pi * 6150 * tt)) * np.exp(-tt / .012)
    place(x, ting, 0.003, c["ting"])
    return fade(norm(x), 0.0, 0.05)


def tail_out(src, seed, crack_only=False):
    rng = np.random.default_rng(seed); L = 3.0 if not crack_only else 1.6
    x = np.zeros(int(L * SR))
    if crack_only:
        exc = hp(crack_layer(src, rng), 1200)
    else:
        exc = lp(friedlander(1.1e-3, length=0.03), 2500) + lp(rng.standard_normal(int(.03 * SR)) * np.exp(-secs(.03) / .008), 2000) * .3
    delays = np.sort(rng.uniform(0.15, 1.2 if crack_only else 2.6, 6 if crack_only else 9))
    for d in delays:   # tree lines and hillsides: further = later, quieter, darker
        cut = (4200 if crack_only else 3200) / (1 + d * 1.8)
        refl = lp(exc, cut)
        refl = np.convolve(refl, np.exp(-secs(0.05) / rng.uniform(.008, .02)), "full")[:int(.25 * SR)]   # a smeared face, not a mirror
        place(x, refl / (np.max(np.abs(refl)) + 1e-9), d, rng.uniform(.5, 1.0) / (1 + d * 2.2))
    t = secs(L)
    rt = 0.8 if crack_only else 1.8
    diff = rng.standard_normal(len(t)) * np.exp(-6.91 * t / rt) * (1 - np.exp(-t / 0.06))
    early, late = (bp(diff, 900, 4500), bp(diff, 700, 2500)) if crack_only else (lp(diff, 2200), lp(diff, 700))
    k = np.clip(t / 1.2, 0, 1)
    x += (early * (1 - k) + late * k) * (0.18 if crack_only else 0.28)
    if not crack_only:
        rum = lp(rng.standard_normal(len(t)), 140, 4) * np.exp(-t / 0.7) * (1 - np.exp(-t / .12))
        x += rum / (np.max(np.abs(rum)) + 1e-9) * 0.12
    return fade(norm(x, -3.0), 0.002, 0.4)


def tail_in(seed):
    rng = np.random.default_rng(seed); L = 0.9; x = np.zeros(int(L * SR))
    exc = lp(friedlander(1.0e-3, length=0.01), 6000)
    for k in range(40):   # a small timber room: dense slaps in the first 25 ms
        d = rng.uniform(0.0025, 0.025); place(x, lp(exc, rng.uniform(2500, 7000)), d, rng.uniform(.3, 1.0) * np.exp(-d / .012))
    t = secs(L)
    diff = lp(rng.standard_normal(len(t)), 4200) * np.exp(-6.91 * t / 0.38) * (1 - np.exp(-t / 0.004))
    x += diff * 0.35
    box = lp(rng.standard_normal(len(t)), 220) * np.exp(-t / 0.09)              # the cabin boom
    x += box / (np.max(np.abs(box)) + 1e-9) * 0.4
    return fade(norm(x, -3.0), 0.0005, 0.15)


def mech(src, seed):
    rng = np.random.default_rng(seed); out = {}
    latch, screw, flick, lock = src["latch"], src["cara_screw"], src["cara_flick"], src["lock"]
    def clip(x, t0, dur, f=1.0, hpf=250.0, lpf=7000.0):
        s = slice_at(x, t0, dur); s = lp(hp(pitch(s, f), hpf), lpf, 4); return fade(norm(s, -1.0), 0.0005, min(0.02, dur * 0.3))
    lo = nth_onset(latch, 0)
    out["bolt_up"] = clip(flick, nth_onset(flick, 1), 0.10, 1.0, 500, 6000)          # handle lifts: light snick
    out["bolt_back"] = clip(screw, nth_onset(screw, 0), 0.16, 0.80, 250, 5000)        # bolt slides back over the follower
    out["bolt_fwd"] = clip(screw, nth_onset(screw, 2), 0.14, 0.86, 250, 5000)        # forward, picking up the round
    out["bolt_down"] = clip(latch, lo, 0.14, 0.92, 150)                         # handle drops into its notch
    out["lever_open"] = clip(lock, nth_onset(lock, 0), 0.14, 0.95, 200)
    out["lever_close"] = clip(latch, lo, 0.16, 0.82, 120)
    out["semi_clack"] = clip(latch, lo, 0.07, 1.35, 700)                         # bolt carrier slams
    return out


# ---------------------------------------------------------------- measurement
def measure(x):
    pk = 20 * np.log10(np.max(np.abs(x)) + 1e-12)
    rms = 20 * np.log10(np.sqrt(np.mean(x[:max(int(.05 * SR), 1)] ** 2)) + 1e-12)   # first 50 ms: the impression
    f, P = signal.welch(x, SR, nperseg=2048)
    cen = float(np.sum(f * P) / (np.sum(P) + 1e-20))
    e = np.cumsum((x ** 2)[::-1])[::-1]; e /= e[0] + 1e-20
    edb = 10 * np.log10(e + 1e-20)
    i5, i25 = np.argmax(edb < -5), np.argmax(edb < -25)
    t20 = (i25 - i5) / SR * 3.0 if i25 > i5 else 0.0        # T20 x3 = RT60 estimate
    return pk, rms, cen, t20, len(x) / SR


def write(name, x, rep):
    os.makedirs(OUT, exist_ok=True)
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
    pk, rms, cen, t20, dur = measure(x)
    rep.append("%-22s peak %5.1f dBFS  rms50 %6.1f  centroid %5.0f Hz  RT60~ %4.2f s  len %4.2f s" % (name, pk, rms, cen, t20, dur))


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--zips", default=os.path.join(os.path.expanduser("~"), "Downloads"))
    a = ap.parse_args()
    src = load_sources(a.zips); rep = []
    for ci, cls in enumerate(CLASSES):
        for v in range(3): write("blast_%s_%d" % (cls, v), blast_open(cls, src, 1000 + 10 * ci + v), rep)
    for cls in SUP:
        for v in range(3): write("blast_%s_%d" % (cls, v), blast_sup(cls, src, 31 + v * 7 + len(cls)), rep)
    for v in range(3): write("crack_%d" % v, fade(norm(crack_layer(src, np.random.default_rng(70 + v))), 0, .01), rep)
    for v in range(2): write("tail_out_%d" % v, tail_out(src, 500 + v), rep)
    write("tail_crack_out", tail_out(src, 600, True), rep)
    write("tail_in", tail_in(700), rep)
    for k, x in mech(src, 800).items(): write(k, x, rep)
    with open(os.path.join(ROOT, "tools", "audio", "gunshot_report.txt"), "w") as fh: fh.write("\n".join(rep) + "\n")
    print("\n".join(rep))


if __name__ == "__main__":
    main()
