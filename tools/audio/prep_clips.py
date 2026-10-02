"""Turn downloaded creature sounds into game-ready clips.

Drop raw downloads into  audio_in/<kind>/   (kind = zombie, wolf, bear, deer; sub-folders are fine)
then run                 python tools/audio/prep_clips.py
Clips land in brave-and-cold/assets/audio/creatures/<kind>/<event>_NN.<ext>

What it does
  * works out the EVENT from the source file name (growl, groan, moan, scream, roar, howl, hurt/pain, death/die, snort...)
    anything it cannot classify goes to audio_in/_unsorted.txt so you can rename it (e.g. add 'growl' to the name) and re-run
  * with ffmpeg on PATH: mono, 44.1 kHz, trimmed silence, loudness-normalised, Ogg Vorbis (smallest, Godot imports it as is)
  * without ffmpeg: .wav is mixed to mono, silence-trimmed and peak-normalised to -3 dBFS (stdlib only); .ogg/.mp3 are copied untouched
  * clips longer than --max seconds (default 8) are skipped for non-howl events (long ambience is not a creature voice)
Licences: keep each pack's licence text / author credit (docs/audio_credits.md); CC-BY needs credit in the game.
"""
import argparse, array, os, re, shutil, subprocess, sys, wave

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
IN = os.path.join(ROOT, "audio_in")
OUT = os.path.join(ROOT, "brave-and-cold", "assets", "audio", "creatures")

KEYS = [  # first match wins; order matters
    ("death", r"death|dying|die\b|dies|dead|kill"),
    ("hurt", r"hurt|pain|hit\b|injur|whimper|whine|yelp|cry|screech"),
    ("howl", r"howl"),
    ("roar", r"roar"),
    ("snort", r"snort|huff|sniff"),
    ("alert", r"scream|shout|yell|rage|spot|alert|bellow|bleat"),
    ("attack", r"attack|bite|snap|lunge|swipe|claw"),
    ("growl", r"growl|snarl|rumble"),
    ("idle", r"groan|moan|idle|breath|rasp|mutter|ambient|walk"),
]
ALLOWED = {"zombie": {"idle", "alert", "attack", "hurt", "death", "growl"},
           "wolf": {"howl", "growl", "attack", "hurt", "death"},
           "bear": {"roar", "growl", "attack", "hurt", "death"},
           "deer": {"snort", "hurt", "death", "alert"}}


def classify(name):
    low = name.lower()
    for ev, pat in KEYS:
        if re.search(pat, low):
            return ev
    return ""


def wav_process(src, dst, max_s):
    with wave.open(src, "rb") as w:
        ch, sw, fr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
    if sw != 2:
        return False, "only 16-bit wav handled without ffmpeg"
    a = array.array("h")
    a.frombytes(raw)
    if sys.byteorder == "big":
        a.byteswap()
    if ch > 1:
        a = array.array("h", [sum(a[i:i + ch]) // ch for i in range(0, len(a) - ch + 1, ch)])
    thr = max(abs(x) for x in a) * 0.02 if len(a) else 0
    lo = 0
    while lo < len(a) and abs(a[lo]) < thr:
        lo += 1
    hi = len(a)
    while hi > lo and abs(a[hi - 1]) < thr:
        hi -= 1
    a = a[max(lo - fr // 50, 0):min(hi + fr // 20, len(a))]
    if not len(a):
        return False, "silent"
    if len(a) / fr > max_s:
        return False, "longer than %.0fs" % max_s
    peak = max(abs(x) for x in a)
    g = (32767 * 0.708) / peak if peak else 1.0
    a = array.array("h", [int(max(-32768, min(32767, x * g))) for x in a])
    if sys.byteorder == "big":
        a.byteswap()
    with wave.open(dst, "wb") as o:
        o.setnchannels(1)
        o.setsampwidth(2)
        o.setframerate(fr)
        o.writeframes(a.tobytes())
    return True, ""


def ffmpeg_process(src, dst):
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-ac", "1", "-ar", "44100",
           "-af", "silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse,loudnorm=I=-18:TP=-2",
           "-c:a", "libvorbis", "-q:a", "4", dst]
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.returncode == 0, r.stderr.strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--max", type=float, default=8.0)
    ap.add_argument("--dry", action="store_true")
    args = ap.parse_args()
    ff = shutil.which("ffmpeg") is not None
    print("ffmpeg:", "yes (ogg output)" if ff else "no (wav processed, ogg/mp3 copied)")
    unsorted, done = [], 0
    for kind in ALLOWED:
        d = os.path.join(IN, kind)
        if not os.path.isdir(d):
            continue
        counters = {}
        for dp, _, files in os.walk(d):
            for f in sorted(files):
                ext = os.path.splitext(f)[1].lower()
                if ext not in (".wav", ".ogg", ".mp3", ".flac"):
                    continue
                src = os.path.join(dp, f)
                ev = classify(os.path.relpath(src, d))
                if ev == "" or ev not in ALLOWED[kind]:
                    unsorted.append("%s: %s (event %s)" % (kind, os.path.relpath(src, IN), ev or "?"))
                    continue
                counters[ev] = counters.get(ev, 0) + 1
                base = os.path.join(OUT, kind)
                os.makedirs(base, exist_ok=True)
                stem = "%s_%02d" % (ev, counters[ev])
                if args.dry:
                    print("would", src, "->", stem)
                    continue
                if ff:
                    ok, why = ffmpeg_process(src, os.path.join(base, stem + ".ogg"))
                elif ext == ".wav":
                    ok, why = wav_process(src, os.path.join(base, stem + ".wav"), args.max if ev != "howl" else 30.0)
                elif ext in (".ogg", ".mp3"):
                    shutil.copy(src, os.path.join(base, stem + ext))
                    ok, why = True, ""
                else:
                    ok, why = False, "flac needs ffmpeg"
                if ok:
                    done += 1
                    print("ok  ", kind, stem, "<-", f)
                else:
                    counters[ev] -= 1
                    unsorted.append("%s: %s (%s)" % (kind, os.path.relpath(src, IN), why))
    if unsorted:
        os.makedirs(IN, exist_ok=True)
        with open(os.path.join(IN, "_unsorted.txt"), "w") as fh:
            fh.write("\n".join(unsorted) + "\n")
        print("%d file(s) not placed -> audio_in/_unsorted.txt" % len(unsorted))
    print("placed", done)


if __name__ == "__main__":
    main()
