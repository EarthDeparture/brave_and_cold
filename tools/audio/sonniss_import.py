"""Import + normalise the hand-picked clips from the Sonniss GDC 2026 bundle (pure stdlib, no ffmpeg/numpy).

python tools/audio/sonniss_import.py [--zips DIR] [--only substring]

For each MANIFEST row: reads just the needed slice of the member WAV straight out of the zip (16/24/32-bit int or float,
any channel count / rate), mixes to mono, resamples to 44.1 kHz, trims/fades (one-shots) or crossfades into a seamless loop,
then normalises GATED RMS to the row's target (peak capped at -3 dBFS) and writes 16-bit mono WAV.
A level report goes to tools/audio/sonniss_report.txt.
Licence: Sonniss GDC bundle, royalty-free, no attribution required (see docs/audio_credits.md).
"""
import argparse, array, glob, math, os, sys, zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
AUD = os.path.join(ROOT, "brave-and-cold", "assets", "audio")
OUTR = 44100
PEAK_CAP = 0.708  # -3 dBFS

# dest (under assets/audio), zip part, member substring, start_s, dur_s, mode, target RMS dBFS, speed
# mode: shot = onset-trimmed one-shot ; loop = seamless loop ; "hit" = loudest-onset window
CREATURE = -20.0
MANIFEST = [
    ("creatures/wolf/growl_01.wav", 2, "Werewolf Growl Menacing", 0, 6.0, "shot", CREATURE, 1.0),
    ("creatures/wolf/attack_01.wav", 2, "Werewolf Growl Menacing", 0, 6.0, "shot", CREATURE, 1.15),
    ("creatures/wolf/hurt_01.wav", 1, "Dog Shuffle, Grunt", 0, 4.0, "shot", CREATURE, 1.0),
    ("creatures/bear/roar_01.wav", 1, "Large Herbivore Roar 01", 0, 7.0, "shot", CREATURE, 1.0),
    ("creatures/bear/growl_01.wav", 2, "Werewolf Growl Menacing", 0, 6.0, "shot", CREATURE, 0.75),
    ("creatures/bear/attack_01.wav", 1, "T Rex", 0, 4.0, "shot", CREATURE, 1.0),
    ("creatures/zombie/attack_01.wav", 2, "Orc Male Attack Long Heavy", 0, 4.0, "shot", CREATURE, 0.9),
    ("creatures/zombie/death_01.wav", 2, "Flutter Death Vocal Stuttered", 0, 6.0, "shot", CREATURE, 1.0),
    ("creatures/zombie/hurt_01.wav", 2, "Sea Beast Creature Pain", 0, 5.0, "shot", CREATURE, 1.1),
    ("creatures/zombie/idle_01.wav", 2, "Screeching Breath Inhale Weak", 0, 4.0, "shot", CREATURE, 0.85),
    ("creatures/zombie/idle_02.wav", 5, "Violent Humanoid Creature Exhale", 0, 3.0, "shot", CREATURE, 0.85),
    ("creatures/zombie/idle_03.wav", 5, "Panting Male 02", 0, 5.0, "shot", CREATURE, 0.8),
    ("sfx/wind.wav", 1, "Eye Of The Storm", 60, 24.0, "loop", -19.0, 1.0),
    ("sfx/fire.wav", 3, "Dropping Fresh Pine Branches", 30, 24.0, "loop", -20.0, 1.0),
    ("sfx/rustle.wav", 3, "ClothMovement24", 0, 1.3, "shot", -21.0, 1.0),
    ("sfx/thud.wav", 1, "4 x Punch, Body 02", 0, 0.5, "hit", -12.0, 0.7),
    ("sfx/chop.wav", 1, "Spear And Stick Impact", 0, 0.45, "hit", -14.0, 0.8),
    ("sfx/hammer.wav", 2, "Tire Iron Metallic Hit", 0, 0.6, "hit", -16.0, 1.0),
]


def find_zip(dirp, part):
    g = glob.glob(os.path.join(dirp, "*%dof5*.zip" % part))
    return g[0] if g else None


def read_slice(zf, member, start_s, dur_s):
    with zf.open(member) as f:
        hdr = f.read(12)
        if hdr[:4] != b"RIFF":
            raise ValueError("not RIFF")
        fmt = None
        while True:
            h = f.read(8)
            if len(h) < 8:
                raise ValueError("no data chunk")
            cid, size = h[:4], int.from_bytes(h[4:], "little")
            if cid == b"fmt ":
                b = f.read(size + (size & 1))
                tag, ch, rate, _, _, bits = (int.from_bytes(b[0:2], "little"), int.from_bytes(b[2:4], "little"),
                                             int.from_bytes(b[4:8], "little"), 0, 0, int.from_bytes(b[14:16], "little"))
                if tag == 0xFFFE and size >= 26:
                    tag = int.from_bytes(b[24:26], "little")
                fmt = (tag, ch, rate, bits)
            elif cid == b"data":
                break
            else:
                skip(f, size + (size & 1))
        tag, ch, rate, bits = fmt
        bw = bits // 8
        bpf = bw * ch
        total = size // bpf if size != 0xFFFFFFFF else 1 << 40
        s0 = min(int(start_s * rate), max(total - 1, 0))
        n = min(int(dur_s * rate), total - s0)
        skip(f, s0 * bpf)
        raw = f.read(n * bpf)
    return tag, ch, rate, bw, raw


def skip(f, n):
    while n > 0:
        c = f.read(min(n, 1 << 20))
        if not c:
            break
        n -= len(c)


def decode(tag, ch, bw, raw):
    n = len(raw) // bw
    raw = raw[:n * bw]
    if tag == 3:
        a = array.array("f" if bw == 4 else "d")
        a.frombytes(raw)
        v = list(a)
    elif bw == 2:
        a = array.array("h")
        a.frombytes(raw)
        v = [x / 32768.0 for x in a]
    elif bw == 3:
        out = bytearray(n * 4)
        out[1::4] = raw[0::3]
        out[2::4] = raw[1::3]
        out[3::4] = raw[2::3]
        a = array.array("i")
        a.frombytes(bytes(out))
        v = [x / 2147483648.0 for x in a]
    elif bw == 4:
        a = array.array("i")
        a.frombytes(raw)
        v = [x / 2147483648.0 for x in a]
    else:
        raise ValueError("bit depth %d" % (bw * 8))
    if ch > 1:
        cols = [v[c::ch] for c in range(ch)]
        v = [sum(t) / ch for t in zip(*cols)]
    return v


def resample(v, rate_in, rate_out):
    if rate_in == rate_out or not v:
        return v
    r = rate_in / rate_out
    m = int(len(v) / r)
    if r > 1.0:  # box filter average (anti-alias) via prefix sums
        ps = [0.0]
        acc = 0.0
        for x in v:
            acc += x
            ps.append(acc)
        out = []
        for j in range(m):
            a, b = j * r, (j + 1) * r
            ia, ib = int(a), min(int(b), len(v))
            out.append((ps[ib] - ps[ia]) / max(ib - ia, 1))
        return out
    out = []
    for j in range(m):
        p = j * r
        i = int(p)
        fr = p - i
        x1 = v[i + 1] if i + 1 < len(v) else v[i]
        out.append(v[i] * (1 - fr) + x1 * fr)
    return out


def trim_shot(v, hit=False):
    pk = max(abs(x) for x in v) if v else 0
    if pk <= 0:
        return v
    thr = pk * (0.12 if hit else 0.02)
    lo = next((i for i, x in enumerate(v) if abs(x) >= thr), 0)
    hi = len(v) - 1
    while hi > lo and abs(v[hi]) < pk * 0.02:
        hi -= 1
    lo = max(lo - int(OUTR * 0.015), 0)
    hi = min(hi + int(OUTR * 0.08), len(v) - 1)
    v = v[lo:hi + 1]
    fi, fo = int(OUTR * 0.003), min(int(OUTR * 0.04), len(v) // 2)
    for i in range(min(fi, len(v))):
        v[i] *= i / fi
    for i in range(fo):
        v[len(v) - 1 - i] *= i / fo
    return v


def make_loop(v, fade_s):
    f = int(fade_s * OUTR)
    n = len(v) - f
    out = v[:n]
    for i in range(f):
        t = i / f
        out[i] = v[i] * math.sin(t * math.pi / 2) + v[n + i] * math.cos(t * math.pi / 2)
    return out


def gated_rms(v):
    blk = 2048
    ps = [sum(x * x for x in v[i:i + blk]) / len(v[i:i + blk]) for i in range(0, len(v) - blk + 1, blk)] or \
         [sum(x * x for x in v) / max(len(v), 1)]
    mx = max(ps)
    sel = [p for p in ps if p >= mx * 0.1]
    return math.sqrt(sum(sel) / len(sel)) if sel else 0.0


def softclip(x, t=0.45):
    """Transparent below t, tanh knee up to the -3 dBFS cap above it (keeps crackle/impact RMS up without hard clipping)."""
    a = abs(x)
    if a <= t:
        return x
    y = t + (PEAK_CAP - t) * math.tanh((a - t) / (PEAK_CAP - t))
    return y if x > 0 else -y


def reach(v, rms, tgt, pk):
    """Gain that lands the gated RMS on the target; when the peaks would exceed the cap the soft knee takes over (iterated)."""
    g = (10 ** (tgt / 20)) / rms
    lim = pk * g > PEAK_CAP
    for _ in range(12):
        r = gated_rms([softclip(x * g) for x in v]) if lim else (10 ** (tgt / 20))
        if abs(20 * math.log10(r / (10 ** (tgt / 20)))) < 0.25:
            break
        g *= (10 ** (tgt / 20)) / r
    return g, lim


def db(x):
    return 20 * math.log10(x) if x > 1e-9 else -99.0


def write16(path, v):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    a = array.array("h", [int(max(-1.0, min(1.0, x)) * 32767) for x in v])
    if sys.byteorder == "big":
        a.byteswap()
    data = a.tobytes()
    with open(path, "wb") as o:
        o.write(b"RIFF" + (36 + len(data)).to_bytes(4, "little") + b"WAVEfmt " + (16).to_bytes(4, "little") +
                (1).to_bytes(2, "little") + (1).to_bytes(2, "little") + OUTR.to_bytes(4, "little") +
                (OUTR * 2).to_bytes(4, "little") + (2).to_bytes(2, "little") + (16).to_bytes(2, "little") +
                b"data" + len(data).to_bytes(4, "little") + data)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--zips", default=os.path.join(os.path.expanduser("~"), "Downloads"))
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    zips, rep = {}, []
    for dest, part, key, st, dur, mode, tgt, speed in MANIFEST:
        if args.only and args.only not in dest:
            continue
        zp = zips.get(part)
        if zp is None:
            p = find_zip(args.zips, part)
            if not p:
                print("MISSING zip part", part)
                continue
            zp = zips[part] = zipfile.ZipFile(p)
        names = [n for n in zp.namelist() if key in n and n.lower().endswith(".wav")]
        if not names:
            print("NOT FOUND", key)
            continue
        member = names[0]
        extra = 1.5 if mode == "loop" else 0.0
        tag, ch, rate, bw, raw = read_slice(zp, member, st, dur + extra)
        v = decode(tag, ch, bw, raw)
        mean = sum(v) / max(len(v), 1)
        v = [x - mean for x in v]
        v = resample(v, int(rate * speed), OUTR)
        if mode == "loop":
            v = make_loop(v, extra)
        else:
            v = trim_shot(v, mode == "hit")
            if mode == "hit":
                v = v[:int(dur * OUTR)]
        rms = gated_rms(v)
        pk = max(abs(x) for x in v) if v else 0
        if rms <= 0:
            print("SILENT", dest)
            continue
        g, lim = reach(v, rms, tgt, pk)
        v = [softclip(x * g) for x in v]
        write16(os.path.join(AUD, dest), v)
        line = "%-34s %5.2fs  rms %6.1f dBFS  peak %5.1f  %s  <- %s" % (
            dest, len(v) / OUTR, db(gated_rms(v)), db(max(abs(x) for x in v)), "PEAK-LIMITED" if lim else "", member.split("/")[0])
        print(line)
        rep.append(line)
    if not args.only:
        with open(os.path.join(ROOT, "tools", "audio", "sonniss_report.txt"), "w", encoding="utf-8") as fh:
            fh.write("\n".join(rep) + "\n")


if __name__ == "__main__":
    main()
