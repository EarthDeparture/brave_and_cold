"""Weathered title logo for the main menu, from the bundled OFL Cormorant Garamond.

OFL 1.1 restricts redistributing the font software, not artwork made with it, so a
rendered logo is fine to ship. Output: brave-and-cold/assets/ui/logo.png (RGBA, trimmed).

Look (TLD-like title): wide letter-spaced serif caps, worn edges, a faint frost on the
top edges, warm off-white body, very soft dark halo so it reads over bright sky.
Deterministic (fixed seed). Usage: python tools/ui/make_logo.py [--preview]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2] / "brave-and-cold"
FONT = ROOT / "assets/fonts/Cormorant_Garamond/static/CormorantGaramond-SemiBold.ttf"
OUT = ROOT / "assets/ui/logo.png"
TEXT = "BRAVE AND COLD"
SIZE = 300          # px font size for the render (logo is ~3000 px wide)
TRACK = 0.16        # letter spacing as a fraction of SIZE
WORD_GAP = 0.30     # extra space between words, fraction of SIZE
PAD = 120
rng = np.random.default_rng(20261017)


def fbm(h, w, octaves=5, base=6):
    """Cheap fractal value noise in [0,1] (bicubic upsampled random grids)."""
    acc = np.zeros((h, w), np.float32); amp, tot = 1.0, 0.0
    for o in range(octaves):
        gh, gw = base * 2 ** o + 1, int(base * 2 ** o * w / h) + 1
        g = Image.fromarray((rng.random((gh, gw)) * 255).astype(np.uint8))
        acc += amp * np.asarray(g.resize((w, h), Image.BICUBIC), np.float32) / 255.0
        tot += amp; amp *= 0.55
    return acc / tot


def render_mask():
    font = ImageFont.truetype(str(FONT), SIZE)
    widths = [font.getlength(ch) + (SIZE * WORD_GAP if ch == " " else SIZE * TRACK) for ch in TEXT]
    W = int(sum(widths) + PAD * 2); H = int(SIZE * 1.6 + PAD * 2)
    m = Image.new("L", (W, H), 0); d = ImageDraw.Draw(m)
    x = PAD
    for ch, w in zip(TEXT, widths):
        d.text((x, PAD), ch, font=font, fill=255)
        x += w
    return np.asarray(m, np.float32) / 255.0


def blur(arr, r):
    return np.asarray(Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), np.float32) / 255.0


def main():
    a = render_mask()
    H, W = a.shape
    n = fbm(H, W)
    fine = fbm(H, W, octaves=3, base=60)
    b = blur(a, 5)
    edge = np.clip(1.0 - np.abs(b - 0.5) * 2.0, 0, 1)            # band around glyph borders
    wear = np.clip((n * 0.7 + fine * 0.3 - 0.42) * 5.0, 0, 1)      # 1 = intact
    alpha = a * (1.0 - edge * (1.0 - wear) * 0.95)                  # worn edges
    chips = np.clip((fbm(H, W, octaves=2, base=90) - 0.78) * 12.0, 0, 1)
    alpha *= 1.0 - chips * 0.55 * a                                 # sparse, partial chips (v1 read as marble)
    sc = Image.new("L", (W, H), 0); sd = ImageDraw.Draw(sc)
    for _ in range(14):                                             # faint long scratches
        x0 = rng.uniform(PAD, W - PAD); y0 = rng.uniform(PAD, H - PAD)
        ang = rng.normal(-0.25, 0.15); L = rng.uniform(150, 520)
        sd.line([(x0, y0), (x0 + L * np.cos(ang), y0 + L * np.sin(ang))], fill=int(rng.uniform(120, 220)), width=int(rng.integers(1, 3)))
    alpha *= 1.0 - np.asarray(sc.filter(ImageFilter.GaussianBlur(0.7)), np.float32) / 255.0 * 0.9
    alpha = np.clip(alpha, 0, 1)

    ys = np.linspace(0, 1, H, dtype=np.float32)[:, None]
    top = PAD / H; bot = (PAD + SIZE * 1.05) / H
    t = np.clip((ys - top) / (bot - top), 0, 1)[..., None]
    body = np.array([0.90, 0.88, 0.82], np.float32); frost = np.array([0.97, 0.98, 1.0], np.float32)
    col = np.broadcast_to(frost * (1 - t) + body * t, (H, W, 3)).copy()
    up = np.zeros_like(a); up[4:] = a[:-4]
    rim = np.clip(a - up, 0, 1) * np.clip(n * 1.6 - 0.3, 0, 1)       # frost catching top edges
    col += rim[..., None] * 0.10
    col *= (0.88 + 0.12 * fine)[..., None]                          # faint grime

    halo = np.roll(blur(a, 18), 6, axis=0) * 0.45 * (1.0 - a)       # soft dark halo, outside the glyphs only
    # (inside, worn holes show the sky, not black specks)
    out_a = alpha + halo * (1 - alpha)
    rgb = (col * alpha[..., None]) / np.maximum(out_a[..., None], 1e-4)
    img = np.dstack([np.clip(rgb, 0, 1), np.clip(out_a, 0, 1)])
    im = Image.fromarray((img * 255).astype(np.uint8), "RGBA")
    im = im.crop(im.getbbox())
    # ship at 1920 px wide (4K title width ~1870 px); the game samples it with mipmaps
    im = im.resize((1920, round(im.height * 1920 / im.width)), Image.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    im.save(OUT, optimize=True)
    print(OUT, im.size)
    if "--preview" in sys.argv:
        bw = im.width + 400
        bg = Image.open(ROOT / "assets/ui/menu_bg_lookout.jpg").convert("RGBA").resize((bw, int(bw * 9 / 16)))
        bg.alpha_composite(im, (200, 380))
        crop = bg.crop((150, 300, 150 + im.width + 100, 380 + im.height + 80))
        crop.convert("RGB").save(ROOT.parent / "shots/logo_preview.png")


if __name__ == "__main__":
    main()
