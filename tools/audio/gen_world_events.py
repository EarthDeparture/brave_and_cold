"""World events (A4) audio. Deterministic. numpy + scipy (tools/terrain/.venv).   python tools/audio/gen_world_events.py

  * shot_far_0..3: another survivor shooting 500-1500 m away. Built from the game's own (Sonniss-derived) rifle blasts,
    not synthesised: air absorption (steep low-pass ~0.8-1.4 kHz, the crack is gone), then a valley space - a long
    reverb with discrete slap echoes off the ridges (0.4-2.4 s). Placed by AmbientLife._play_far in its true direction.
  * fluoro_buzz: fluorescent tube / ballast hum loop, 2.0 s seamless (120 Hz mains-double + odd-ish harmonics,
    slow beating), for aurora electrics. 120 Hz * 2 s = 240 whole cycles so the loop has no click.
  * fluoro_tick: the starter/ballast click of a tube trying to strike.
  * elec_pop: the buzz-and-pop of a fixture dying when the grid goes.
Output brave-and-cold/assets/audio/ambient/*.wav. NOBODY HAS LISTENED: Troy must (sound board).
"""
import os, sys
import numpy as np
from scipy import signal
from scipy.io import wavfile

sys.path.insert(0, os.path.dirname(__file__))
from gen_ambient_life import lp, bp, reverb, norm, fade_tail, SR, OUT, ROOT  # noqa: E402

WEAP = os.path.join(ROOT, "brave-and-cold", "assets", "audio", "weapons")


def read(name):
    sr, x = wavfile.read(os.path.join(WEAP, name))
    x = x.astype(np.float64)
    if x.ndim > 1: x = x.mean(axis=1)
    x /= 32768.0 if np.abs(x).max() > 2 else 1.0
    if sr != SR: x = signal.resample_poly(x, SR, sr)
    return x


def write(name, x):
    y = np.clip(x, -1, 1)
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, (y * 32767).astype(np.int16))
    print("wrote", name, "%.2fs" % (len(y) / SR), "peak %.2f" % np.abs(y).max())


def shot_far(seed, src, cut, rt):
    rng = np.random.default_rng(seed)
    x = read(src)[: int(0.6 * SR)]
    x = lp(x, cut, 6)                       # air absorption: the supersonic crack and the high band are gone
    x = lp(x, cut * 1.3, 2)
    x = np.concatenate([np.zeros(int(0.02 * SR)), x])
    ech = [(rng.uniform(0.35, 0.6), 0.45), (rng.uniform(1.0, 1.5), 0.32), (rng.uniform(1.8, 2.4), 0.2)]
    y = reverb(x, rng, rt=rt, wet=0.72, echoes=ech, damp=cut * 0.8)
    return fade_tail(norm(y, -2.0), 0.6)


def fluoro_buzz():
    n = int(2.0 * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for h, a in [(1, 1.0), (2, 0.55), (3, 0.42), (4, 0.18), (5, 0.22), (7, 0.12), (9, 0.07)]:
        y += a * np.sin(2 * np.pi * 120.0 * h * t + h * 0.7)
    y = np.tanh(y * 1.6)                     # the ballast's slightly clipped, gritty edge
    y *= 0.85 + 0.15 * np.sin(2 * np.pi * 1.5 * t)   # slow beating (1.5 Hz * 2 s = 3 cycles: loops clean)
    rng = np.random.default_rng(7)
    hiss = bp(rng.standard_normal(n), 3000, 7000) * 0.03
    y = bp(y, 90, 5000) + hiss
    # make the loop seamless: crossfade the filter start-up with the end
    k = int(0.05 * SR)
    y[:k] = y[:k] * np.linspace(0, 1, k) + y[-k:] * np.linspace(1, 0, k)
    return norm(y, -6.0)


def fluoro_tick():
    rng = np.random.default_rng(11)
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    click = rng.standard_normal(n) * np.exp(-t * 90)
    ring = np.sin(2 * np.pi * 2400 * t) * np.exp(-t * 60) * 0.4
    return norm(bp(click, 600, 9000) + ring, -4.0)


def elec_pop():
    rng = np.random.default_rng(13)
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    buzz = np.tanh(3 * np.sin(2 * np.pi * 120 * t)) * np.exp(-t * 6) * (t < 0.35)
    pop = rng.standard_normal(n) * np.exp(-np.maximum(t - 0.33, 0) * 45) * (t > 0.33)
    thump = np.sin(2 * np.pi * 70 * t) * np.exp(-np.maximum(t - 0.33, 0) * 18) * (t > 0.33) * 0.8
    y = bp(buzz, 100, 4000) * 0.5 + bp(pop, 300, 8000) + thump
    return fade_tail(norm(y, -1.0), 0.2)


def main():
    srcs = [("blast_medium_0.wav", 1100, 3.4), ("blast_medium_1.wav", 900, 3.8),
            ("blast_intermediate_0.wav", 1400, 3.0), ("blast_magnum_brake_1.wav", 800, 4.2)]
    for i, (s, c, rt) in enumerate(srcs):
        write("shot_far_%d" % i, shot_far(100 + i, s, c, rt))
    write("fluoro_buzz", fluoro_buzz())
    write("fluoro_tick", fluoro_tick())
    write("elec_pop", elec_pop())


if __name__ == "__main__":
    main()
