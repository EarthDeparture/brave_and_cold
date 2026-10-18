"""Weapon kit v3 albedo tiles: realistic materials with a TLD painterly hand (2026-10-18).

v2 tiles were flat sheet colours (lime, amber, red). v3 is what guns in a northern
valley are made of: oiled walnut, pale birch, grey laminate, blued and parkerised steel,
black anodised alloy, black synthetic, one hunter camo dip, rubber, brass, glass.
Tileable 1024 px; u runs along the gun (grain direction). Roughness/metal live in the
generator's PROPS table; wear is a vertex-colour mask used by the Godot weapon shader.

  tools/terrain/.venv/Scripts/python.exe tools/blender/gen_weapon_kit_v3_textures.py
"""
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

OUT = Path(__file__).parent / 'generated/weapon_kit_v3/textures'
OUT.mkdir(parents=True, exist_ok=True)
N = 1024


def c(*rgb):
    return np.array(rgb, np.float32) / 255.0


def noise(sx, sy=None, seed=0):
    """Tileable gaussian-filtered white noise, sigma sx along u, sy across."""
    r = np.random.default_rng(seed)
    n = r.normal(0, 1, (N, N)).astype(np.float32)
    n = gaussian_filter(n, sigma=(sy if sy is not None else sx, sx), mode='wrap')
    n -= n.mean(); n /= n.std() + 1e-6
    return n


def save(name, img):
    img = np.clip(img, 0, 1)
    Image.fromarray((img * 255 + 0.5).astype(np.uint8)).save(OUT / (name + '.png'))
    print('TEX', name, img.reshape(-1, 3).mean(0).round(3))


def ramp(t, cols):
    """Map t in [0,1] through a list of colours."""
    t = np.clip(t, 0, 1) * (len(cols) - 1)
    i = np.minimum(t.astype(int), len(cols) - 2)
    f = (t - i)[..., None]
    a = np.stack(cols)[i]; b = np.stack(cols)[i + 1]
    return a * (1 - f) + b * f


def wood(seed, base, dark, light, ring_freq, figure=0.35, pores=0.25):
    """Long grain along u: warped growth bands, soft painted figure, fine pore streaks."""
    yy, xx = np.mgrid[:N, :N].astype(np.float32) / N
    # gunstock blanks are quarter/straight grain: many fine, nearly parallel lines with a
    # gentle long wave (v3a review: wide wavy bands read as cartoon wood)
    warp = noise(300, 90, seed) * 0.012 + noise(60, 20, seed + 1) * 0.0025
    bands = np.sin((yy + warp) * np.pi * 2 * ring_freq)
    bands = 0.5 + 0.5 * np.sign(bands) * np.abs(bands) ** 1.6     # thin dark late-wood lines
    fig = noise(120, 30, seed + 2)                                   # soft colour drift (figure)
    pore = noise(6, 0.7, seed + 3)                                    # hairline pores along u
    t = 0.28 * bands + figure * 0.30 * fig + 0.42
    img = ramp(t, [dark, base, light])
    img *= (1 - pores * 0.12 * np.clip(pore, 0, 3)[..., None] / 3)
    img *= (1 + 0.035 * noise(3, 3, seed + 4))[..., None]            # painterly speckle
    return img


def metal(seed, base, streak=0.05, speck=0.03, mottle=0.04):
    img = np.ones((N, N, 3), np.float32) * base
    img *= (1 + streak * noise(220, 1.2, seed))[..., None]          # long brushing/polish
    img *= (1 + mottle * noise(70, 70, seed + 1))[..., None]         # bluing unevenness
    img *= (1 + speck * noise(1.2, 1.2, seed + 2))[..., None]
    return img


def camo(seed):
    """Hunter camo dip (woodland, muted): olive base, brown + dark + khaki blobs, branch strokes."""
    img = np.ones((N, N, 3), np.float32) * c(96, 92, 66)
    for k, col, thr, s in [(0, c(72, 58, 40), 0.55, 55), (1, c(40, 38, 30), 0.85, 38), (2, c(142, 132, 100), 0.95, 30)]:
        m = noise(s, s * 0.6, seed + 10 + k) > thr
        mm = gaussian_filter(m.astype(np.float32), 1.2, mode='wrap')[..., None]
        img = img * (1 - mm) + col * mm
    twig = noise(30, 2.0, seed + 20) > 1.6
    tw = gaussian_filter(twig.astype(np.float32), 0.8, mode='wrap')[..., None]
    img = img * (1 - tw * 0.8) + c(34, 30, 24) * tw * 0.8
    img *= (1 + 0.04 * noise(2, 2, seed + 21))[..., None]
    return img


def laminate(seed):
    """Grey/brown stacked veneer: thin stripes that wander, seen on the stock sides."""
    yy, xx = np.mgrid[:N, :N].astype(np.float32) / N
    # layers wander as contours (the stock surface cuts the veneer stack obliquely), random tone per layer
    warp = noise(300, 90, seed) * 0.010 + noise(4, 1, seed + 7) * 0.07 + noise(9, 2, seed + 9) * 0.02
    idx = np.floor((yy + warp) * 64)
    h = np.modf(np.abs(np.sin(idx * 12.9898 + seed) * 43758.5453))[0]
    lo, hi = c(70, 72, 70), c(118, 116, 108)
    img = lo[None, None, :] + (hi - lo)[None, None, :] * (0.25 + 0.6 * h)[..., None]
    img *= (1 + 0.04 * np.sin(idx * 2.1))[..., None]
    img = gaussian_filter(img, sigma=(1.1, 1.1, 0), mode='wrap')
    img *= (1 + 0.05 * noise(5, 1, seed + 1))[..., None]
    return img


TILES = {
    'walnut': lambda: wood(11, c(92, 56, 32), c(52, 30, 17), c(128, 82, 46), 26),
    'birch': lambda: wood(12, c(146, 104, 62), c(104, 70, 40), c(172, 132, 86), 30, figure=0.25, pores=0.15),   # stained, not raw
    'birch_dark': lambda: wood(13, c(118, 78, 44), c(80, 50, 28), c(146, 100, 60), 24),   # old military stain
    'laminate': lambda: laminate(14),
    'blued': lambda: metal(21, c(30, 33, 40), streak=0.07, mottle=0.06),
    'parkerized': lambda: metal(22, c(58, 58, 54), streak=0.01, speck=0.07, mottle=0.03),
    'alloy_black': lambda: metal(23, c(22, 22, 24), streak=0.02, speck=0.04, mottle=0.02),
    'steel_bright': lambda: metal(24, c(150, 152, 154), streak=0.10, mottle=0.03),
    'synthetic_black': lambda: metal(25, c(26, 26, 25), streak=0.0, speck=0.09, mottle=0.03),
    'camo_dip': lambda: camo(26),
    'rubber': lambda: metal(27, c(24, 23, 22), streak=0.0, speck=0.05, mottle=0.02),
    'brass': lambda: metal(28, c(176, 136, 62), streak=0.02, mottle=0.05),
    'glass': lambda: metal(29, c(20, 26, 30), streak=0.0, speck=0.0, mottle=0.03),
    'sling_canvas': lambda: wood(30, c(92, 84, 60), c(70, 64, 46), c(108, 100, 74), 40, figure=0.1, pores=0.3),
    'tape_grey': lambda: metal(31, c(120, 122, 120), streak=0.03, speck=0.05, mottle=0.05),
    'lamp_lens': lambda: metal(32, c(220, 220, 205), streak=0.0, speck=0.0, mottle=0.02),
    'hardwood_red': lambda: wood(33, c(120, 66, 38), c(84, 42, 24), c(146, 86, 52), 22, figure=0.15),   # SKS-type surplus hardwood
    'stainless': lambda: metal(34, c(118, 120, 122), streak=0.14, speck=0.01, mottle=0.02),            # bead-blasted / brushed
    'case_colour': lambda: metal(35, c(64, 58, 54), streak=0.03, speck=0.03, mottle=0.16),             # lever receiver, faded case colour
}

for k, f in TILES.items():
    save(k, f())
