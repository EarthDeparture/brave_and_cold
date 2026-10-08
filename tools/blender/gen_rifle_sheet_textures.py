"""Hand-painted style albedo tiles for the rifle sheet kit (Troy's reference sheet, 2026-10-08).
Painterly flat colour + brush-stroke grain / soft camo blobs, tileable, 1024 px.
Run with the terrain venv python (numpy, scipy, PIL):
  tools/terrain/.venv/Scripts/python.exe tools/blender/gen_rifle_sheet_textures.py
"""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

OUT = Path(__file__).parent / 'generated/rifle_sheet_kit_v2/textures'
OUT.mkdir(parents=True, exist_ok=True)
N = 1024
rng = np.random.default_rng(20261008)


def c(*rgb):
    return np.array(rgb, dtype=np.float32) / 255.0


def noise(scale_px, stretch=1.0, seed=None):
    """Tileable smooth noise: blurred white noise, x stretched by `stretch`."""
    r = np.random.default_rng(seed) if seed is not None else rng
    n = r.normal(0, 1, (N, N)).astype(np.float32)
    n = gaussian_filter(n, sigma=(scale_px, scale_px * stretch), mode='wrap')
    n -= n.mean(); n /= (n.std() + 1e-6)
    return n


def stroke_layer(img, color, count, length, thick, alpha, jitter=0.25, seed=0):
    """Painted dashes along u (x). Wraps at tile edges so the tile repeats cleanly."""
    r = np.random.default_rng(seed)
    yy, xx = np.mgrid[:N, :N]
    for _ in range(count):
        cx, cy = r.uniform(0, N, 2)
        L = r.uniform(length * (1 - jitter), length * (1 + jitter))
        T = r.uniform(thick * 0.6, thick * 1.3)
        bend = r.uniform(-0.04, 0.04)
        x0, x1 = int(cx - L / 2 - 4), int(cx + L / 2 + 4)
        y0, y1 = int(cy - T * 3 - 8), int(cy + T * 3 + 8)
        xs = np.arange(x0, x1); ys = np.arange(y0, y1)
        gx, gy = np.meshgrid(xs, ys)
        dx = (gx - cx) / (L / 2)
        dy = (gy - cy - bend * (gx - cx)) / T
        # tapered dash: thick in the middle, pointed at both ends
        prof = np.clip(1 - dx * dx, 0, 1) ** 0.6
        m = np.clip(1.0 - np.abs(dy) / np.maximum(prof, 1e-3), 0, 1)
        m = np.clip(m * 2.2, 0, 1) * (np.abs(dx) < 1)
        ix = np.mod(gx, N); iy = np.mod(gy, N)
        a = (m * alpha)[..., None]
        img[iy, ix] = img[iy, ix] * (1 - a) + color * a
    return img


def wood(base, dark, light, density=1.0, seed=1):
    img = np.ones((N, N, 3), np.float32) * base
    band = noise(26, stretch=9, seed=seed)       # long soft bands along the grain
    img *= (1 + 0.07 * band[..., None])
    # Few bold painted marks, like the sheet: thick tapered dashes, not hairline grain.
    img = stroke_layer(img, dark, int(55 * density), 190, 7.0, 0.80, seed=seed + 10)
    img = stroke_layer(img, dark * 0.9, int(45 * density), 95, 4.5, 0.75, seed=seed + 11)
    img = stroke_layer(img, light, int(30 * density), 150, 4.0, 0.40, seed=seed + 12)
    return img


def camo(base, layers, scale, seed=3):
    img = np.ones((N, N, 3), np.float32) * base
    for i, (col, thr) in enumerate(layers):
        n = noise(scale, stretch=1.6, seed=seed + i * 7) + 0.35 * noise(scale / 3, seed=seed + i * 7 + 1)
        m = np.clip((n - thr) * 3.5, 0, 1)[..., None]   # soft painted edge, not a hard cutout
        img = img * (1 - m) + col * m
    return img


def mottle(base, amount=0.06, scratches=0, seed=5):
    img = np.ones((N, N, 3), np.float32) * base
    img *= (1 + amount * noise(48, seed=seed)[..., None] + amount * 0.25 * noise(6, seed=seed + 1)[..., None])
    if scratches:
        img = stroke_layer(img, np.clip(base * 1.55, 0, 1), scratches, 60, 1.2, 0.5, seed=seed + 2)
    return img


TEX = {
    # stocks / furniture
    'wood_brown': wood(c(150, 92, 55), c(96, 55, 30), c(176, 118, 74), seed=1),
    'wood_orange': wood(c(232, 132, 92), c(176, 84, 50), c(246, 168, 128), seed=2),
    'wood_amber': wood(c(214, 128, 52), c(150, 78, 28), c(232, 164, 92), seed=3),
    'wood_grain': wood(c(140, 118, 96), c(84, 66, 50), c(176, 156, 132), density=1.8, seed=4),
    'wood_lime': wood(c(132, 192, 84), c(84, 146, 56), c(170, 214, 120), seed=5),
    'camo_green': camo(c(150, 140, 98), [(c(86, 112, 58), 0.15), (c(58, 62, 40), 0.7), (c(200, 190, 142), 1.05)], 46, seed=6),
    'camo_grey': camo(c(150, 152, 150), [(c(120, 122, 122), 0.2), (c(92, 94, 95), 0.8), (c(184, 184, 180), 1.0)], 34, seed=7),
    # metal / parts
    'metal_dark': mottle(c(66, 69, 72), 0.05, scratches=90, seed=8),
    'metal_grey': mottle(c(118, 121, 124), 0.05, scratches=70, seed=9),
    'scope_dark': mottle(c(54, 56, 58), 0.05, scratches=40, seed=10),
    'scope_red': mottle(c(192, 48, 40), 0.05, scratches=50, seed=11),
    'scope_green': mottle(c(58, 104, 54), 0.07, scratches=40, seed=12),
    'scope_brown': mottle(c(128, 98, 58), 0.07, scratches=30, seed=13),
    'copper': mottle(c(196, 118, 72), 0.08, scratches=40, seed=14),
    'tape_green': mottle(c(104, 140, 80), 0.10, seed=15),
    'strap_brown': wood(c(118, 78, 46), c(86, 54, 30), c(140, 98, 62), density=0.5, seed=16),
    'rubber_white': mottle(c(222, 222, 216), 0.04, seed=17),
    'rubber_dark': mottle(c(46, 47, 48), 0.05, seed=18),
    'lens_orange': mottle(c(244, 160, 60), 0.05, seed=19),
    'glass': mottle(c(26, 32, 42), 0.04, seed=20),
    'brass': mottle(c(204, 160, 80), 0.06, seed=21),
    'steel': mottle(c(140, 143, 146), 0.05, scratches=50, seed=22),
}
files = {}
for name, img in TEX.items():
    p = OUT / f'{name}.png'
    Image.fromarray(np.clip(img * 255, 0, 255).astype('uint8')).save(p, optimize=True)
    files[p.name] = hashlib.sha256(p.read_bytes()).hexdigest()
(OUT / 'manifest.json').write_text(json.dumps({'original': True, 'seed': 20261008, 'size': N, 'files': files}, indent=2) + '\n', encoding='utf-8', newline='\n')
print('RIFLE_SHEET_TEXTURES', len(files))


# ---------------------------------------------------------------- field kit (survival props sheet)
POUT = Path(__file__).parent / 'generated/field_kit_sheet_v2/textures'
POUT.mkdir(parents=True, exist_ok=True)


def grime(base, dark, light=None, scale=30, amount=0.55, seed=40):
    img = mottle(base, 0.05, seed=seed)
    # Soft, sparse grunge: large scale and half strength so painted colour stays flat (sheet look).
    n = noise(scale * 2.2, stretch=1.2, seed=seed + 1)
    m = np.clip((n - 0.7) * 1.2, 0, 1)[..., None] * amount * 0.55
    img = img * (1 - m) + dark * m
    if light is not None:
        n2 = noise(scale * .6, seed=seed + 2)
        m2 = np.clip((n2 - 1.4) * 1.5, 0, 1)[..., None] * 0.35
        img = img * (1 - m2) + light * m2
    return img


PROP = {
    'canvas': grime(c(118, 128, 80), c(92, 100, 62), c(152, 160, 112), 40, 0.5, seed=41),
    'leather': grime(c(116, 72, 50), c(84, 50, 34), c(146, 98, 70), 26, 0.5, seed=42),
    'rust': grime(c(156, 76, 48), c(104, 50, 34), c(186, 108, 70), 22, 0.6, seed=43),
    'red': grime(c(196, 62, 56), c(150, 44, 40), c(220, 110, 100), 34, 0.45, seed=44),
    'steel': grime(c(128, 130, 134), c(100, 102, 106), c(166, 168, 170), 30, 0.5, seed=45),
    'dark_steel': grime(c(82, 84, 88), c(60, 62, 66), c(116, 118, 122), 30, 0.4, seed=46),
    'ochre': grime(c(232, 206, 64), c(186, 160, 40), None, 30, 0.35, seed=47),
    'gold': grime(c(222, 176, 56), c(170, 128, 40), c(246, 214, 120), 20, 0.35, seed=48),
    'blue': grime(c(118, 170, 222), c(92, 140, 196), c(170, 206, 238), 40, 0.35, seed=49),
    'wood': wood(c(214, 128, 62), c(160, 82, 36), c(234, 166, 102), seed=50),
    'rubber': mottle(c(54, 55, 57), 0.05, seed=51),
    'cotton': grime(c(228, 226, 216), c(196, 192, 180), None, 30, 0.4, seed=52),
    'white': mottle(c(238, 238, 234), 0.03, seed=53),
    'glass': mottle(c(40, 46, 56), 0.04, seed=54),
    'stone': grime(c(150, 150, 146), c(110, 110, 106), c(186, 186, 182), 16, 0.5, seed=55),
    'green': grime(c(98, 116, 74), c(74, 88, 54), None, 30, 0.4, seed=56),
    'case_grey': grime(c(178, 180, 180), c(140, 142, 144), c(206, 208, 208), 30, 0.45, seed=57),
    'tape_yellow': grime(c(226, 170, 52), c(180, 126, 36), None, 20, 0.35, seed=58),
    'cloth': grime(c(232, 232, 226), c(196, 196, 188), None, 12, 0.45, seed=59),
}
pfiles = {}
for name, img in PROP.items():
    p = POUT / f'{name}.png'
    Image.fromarray(np.clip(img * 255, 0, 255).astype('uint8')).save(p, optimize=True)
    pfiles[p.name] = hashlib.sha256(p.read_bytes()).hexdigest()
(POUT / 'manifest.json').write_text(json.dumps({'original': True, 'seed': 20261008, 'files': pfiles}, indent=2) + '\n', encoding='utf-8', newline='\n')
print('FIELD_KIT_SHEET_TEXTURES', len(pfiles))
