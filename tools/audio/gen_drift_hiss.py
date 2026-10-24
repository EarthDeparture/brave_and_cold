"""Blowing-snow hiss (plan A2). python tools/audio/gen_drift_hiss.py
No snow / blizzard / spindrift recording exists in the Sonniss GDC 2026 bundle (searched all 5 parts). So this starts
from a REAL storm recording - 344 Audio "Extreme Winds Vol 1 / Eye Of The Storm" (the same pack as sfx/wind.wav, a
different stretch) - and keeps only what blowing snow adds over plain wind:
  * the airborne grain hiss: the recording band-passed 2.2-9 kHz (the roar below is the wind loop's job),
  * sparse grain ticks: crystals striking cloth and snow, 3-10 kHz clicks at a Poisson rate that swells with gusts,
  * slow gust swell taken from the recording's own low-band envelope.
Output brave-and-cold/assets/audio/ambient/drift_hiss.wav: 14 s mono 44.1 kHz, seamless loop (0.6 s crossfade).
NOBODY HAS LISTENED: Troy must (sound board).
"""
import glob, io, os, wave, zipfile
import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "brave-and-cold", "assets", "audio", "ambient", "drift_hiss.wav")
SR = 44100
MEMBER = "Eye Of The Storm"
START_S, DUR_S = 61.0, 14.6


def read_slice():
    z = glob.glob(os.path.expanduser(r"~\Downloads\Sonniss.com-GDC2026-GameAudioBundle1of5.zip"))[0]
    with zipfile.ZipFile(z) as f:
        name = [i.filename for i in f.infolist() if MEMBER in i.filename and i.filename.lower().endswith(".wav")][0]
        with f.open(name) as fh:
            w = wave.open(fh)
            sr, ch, sw = w.getframerate(), w.getnchannels(), w.getsampwidth()
            w.setpos(int(START_S * sr))
            raw = w.readframes(int(DUR_S * sr))
    if sw == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3)
        x = (b[:, 0].astype(np.int32) | (b[:, 1].astype(np.int32) << 8) | (b[:, 2].astype(np.int32) << 16))
        x = np.where(x & 0x800000, x - 0x1000000, x).astype(np.float64) / 8388608.0
    elif sw == 2:
        x = np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0
    else:
        x = np.frombuffer(raw, dtype=np.int32).astype(np.float64) / 2147483648.0
    x = x.reshape(-1, ch).mean(axis=1)
    print("source", name.split("/")[-1], sr, "Hz", ch, "ch", sw * 8, "bit")
    return signal.resample_poly(x, SR, sr) if sr != SR else x


def bp(x, lo, hi, order=4):
    return signal.sosfilt(signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], "band", output="sos"), x)


def main():
    rng = np.random.default_rng(23)
    src = read_slice()
    n = len(src)
    hiss = bp(src, 2200, 9000)
    env = np.abs(bp(src, 60, 400))   # gust envelope from the recording's own roar
    env = signal.sosfilt(signal.butter(2, 1.2 / (SR / 2), "low", output="sos"), env)
    env = env / (env.max() + 1e-9)
    ticks = np.zeros(n)
    rate = 180.0 * (0.35 + env)       # ticks per second, swelling with the gusts
    p = rng.random(n) < rate / SR
    idx = np.nonzero(p)[0]
    for i in idx:
        L = int(rng.uniform(0.0006, 0.002) * SR)
        if i + L >= n: continue
        ticks[i:i + L] += rng.uniform(-1, 1) * np.exp(-np.linspace(0, 6, L)) * rng.uniform(0.3, 1.0)
    ticks = bp(ticks, 3000, 10000, 2)
    y = hiss / (np.sqrt(np.mean(hiss ** 2)) + 1e-9) * 0.16 + ticks / (np.sqrt(np.mean(ticks ** 2)) + 1e-9) * 0.05
    y *= 0.55 + 0.6 * env
    # seamless loop: crossfade the last 0.6 s into the start
    k = int(0.6 * SR)
    fade = np.linspace(0, 1, k)
    y[:k] = y[:k] * fade + y[-k:] * (1 - fade)
    y = y[:-k]
    y = y / (np.abs(y).max() + 1e-9) * 10 ** (-3 / 20)
    wavfile.write(OUT, SR, (y * 32767).astype(np.int16))
    print("wrote", OUT, "%.1f s" % (len(y) / SR), "rms %.1f dBFS" % (20 * np.log10(np.sqrt(np.mean(y ** 2)) + 1e-9)))


if __name__ == "__main__":
    main()
