"""Procedural painterly terrain textures for Terrain3D (tileable, 1024 px).

Outputs to brave-and-cold/assets/terrain/: <name>_alb.png (RGB albedo + A height), <name>_nrm.png (RGB normal + A roughness).
Style: soft, low-detail, hand-painted look (The Long Dark). Cool shadows are added by lighting, not baked.
Run: uv run python gen_textures.py
"""
from pathlib import Path
import numpy as np
from PIL import Image

N = 1024
OUT = Path(__file__).resolve().parents[2] / "brave-and-cold" / "assets" / "terrain"
rng = np.random.default_rng(7)


def fbm(octaves, base=4, gain=0.5, seed=0):
    """Tileable fractal noise via periodic value noise upsampling (bicubic-ish via FFT low-pass)."""
    r = np.random.default_rng(seed)
    out = np.zeros((N, N), np.float32)
    amp, tot = 1.0, 0.0
    fx = np.fft.fftfreq(N)[:, None]
    fy = np.fft.fftfreq(N)[None, :]
    rad = np.sqrt(fx * fx + fy * fy) + 1e-9
    for o in range(octaves):
        f = base * (2 ** o) / N
        white = r.standard_normal((N, N)).astype(np.float32)
        spec = np.fft.fft2(white) * np.exp(-((rad / f) ** 2))
        layer = np.real(np.fft.ifft2(spec)).astype(np.float32)
        layer /= layer.std() + 1e-9
        out += layer * amp
        tot += amp
        amp *= gain
    out /= tot
    return out


def norm01(a):
    a = a - a.min()
    return a / (a.max() + 1e-9)


def to_normal(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    nz = np.ones_like(h)
    ln = np.sqrt(dx * dx + dy * dy + nz * nz)
    return np.stack([(-dx / ln) * 0.5 + 0.5, (-dy / ln) * 0.5 + 0.5, nz / ln * 0.5 + 0.5], -1)


def lerp(a, b, t):
    return a + (b - a) * t[..., None]


def save(name, rgb, height, rough, nstrength):
    OUT.mkdir(parents=True, exist_ok=True)
    alb = np.dstack([np.clip(rgb, 0, 1), np.clip(height, 0, 1)])
    Image.fromarray((alb * 255).astype(np.uint8), "RGBA").save(OUT / f"{name}_alb.png")
    nrm = np.dstack([to_normal(height, nstrength), np.clip(rough, 0, 1)])
    Image.fromarray((nrm * 255).astype(np.uint8), "RGBA").save(OUT / f"{name}_nrm.png")
    print("wrote", name)


def snow():
    big = norm01(fbm(3, 2, 0.5, 1))
    ripple = norm01(fbm(4, 10, 0.55, 2))
    h = 0.6 * big + 0.4 * ripple
    base = np.array([0.90, 0.93, 0.98])
    shade = np.array([0.74, 0.82, 0.94])
    rgb = lerp(np.broadcast_to(base, (N, N, 3)).copy(), np.broadcast_to(shade, (N, N, 3)).copy(), (1 - big) * 0.55)
    sparkle = (norm01(fbm(1, 220, 1.0, 3)) > 0.985).astype(np.float32) * 0.06
    rgb += sparkle[..., None]
    save("snow", rgb, h, np.full((N, N), 0.72, np.float32), 9.0)


def rock():
    facets = norm01(fbm(3, 3, 0.6, 4))
    steps = np.round(facets * 6) / 6.0  # flat faceted planes = painted look
    fine = norm01(fbm(3, 24, 0.5, 5))
    h = 0.85 * steps + 0.15 * fine
    dark = np.array([0.24, 0.24, 0.28])
    light = np.array([0.52, 0.50, 0.50])
    rgb = lerp(np.broadcast_to(dark, (N, N, 3)).copy(), np.broadcast_to(light, (N, N, 3)).copy(), h)
    warm = norm01(fbm(2, 3, 0.5, 6))
    rgb[..., 0] += (warm - 0.5) * 0.06
    save("rock", rgb, h, np.full((N, N), 0.88, np.float32), 9.0)


def forest_floor():
    blot = norm01(fbm(3, 5, 0.55, 7))
    needles = norm01(fbm(4, 40, 0.6, 8))
    h = 0.5 * blot + 0.5 * needles
    dark = np.array([0.10, 0.11, 0.14])
    mid = np.array([0.24, 0.22, 0.22])
    rgb = lerp(np.broadcast_to(dark, (N, N, 3)).copy(), np.broadcast_to(mid, (N, N, 3)).copy(), blot ** 1.5)
    patch = (norm01(fbm(3, 3, 0.5, 9)) > 0.72).astype(np.float32)  # thin snow crust patches
    rgb = lerp(rgb, np.broadcast_to(np.array([0.82, 0.86, 0.92]), (N, N, 3)).copy(), patch * 0.25)
    save("forest", rgb, h, np.full((N, N), 0.9, np.float32), 6.0)


def ice():
    cracks = fbm(3, 6, 0.5, 10)
    ridge = 1.0 - np.abs(cracks) * 2.0
    crack_mask = norm01(np.clip(ridge, 0, 1)) ** 6
    base = norm01(fbm(3, 3, 0.5, 11))
    deep = np.array([0.30, 0.52, 0.62])
    pale = np.array([0.66, 0.84, 0.90])
    rgb = lerp(np.broadcast_to(deep, (N, N, 3)).copy(), np.broadcast_to(pale, (N, N, 3)).copy(), base)
    rgb = lerp(rgb, np.broadcast_to(np.array([0.92, 0.97, 1.0]), (N, N, 3)).copy(), crack_mask * 0.7)
    drift = norm01(fbm(3, 4, 0.55, 12))
    dmask = np.clip((drift - 0.55) * 4.0, 0, 1)
    rgb = lerp(rgb, np.broadcast_to(np.array([0.88, 0.92, 0.98]), (N, N, 3)).copy(), dmask * 0.85)
    save("ice", rgb, 0.4 * base + 0.2 * crack_mask + 0.3 * dmask, np.full((N, N), 0.18, np.float32), 3.0)


if __name__ == "__main__":
    snow(); rock(); forest_floor(); ice()
