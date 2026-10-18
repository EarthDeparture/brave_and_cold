"""Title lockup for the main menu: a painted emblem + hand-cut wordmark.

v2 (v1 was the bundled font with wear on top: not lettered, no emblem, dimmer than text):
  * Hand-cut letters. Cormorant Garamond (OFL; artwork made with it is fine to ship) is
    only the skeleton: each glyph gets its own small rotation, baseline and width jitter,
    then its outline is re-cut by thresholding the blurred glyph against two noise
    octaves, which gives the uneven, slightly swollen edges of brush/knife-cut signage
    lettering. Stroke weight is pushed up a little (threshold below 0.5) for presence.
  * Emblem: an ochre winter-sun disc, a lone spruce in front, a snow ridge cutting the
    disc, drawn as jittered polygons at 4x and downsampled.
  * Brighter body (0.95 off-white), light wear only, soft outer halo.
Output: brave-and-cold/assets/ui/logo.png (RGBA, 1920 px wide, trimmed). Deterministic.
Usage: python tools/ui/make_logo.py [--preview]
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2] / "brave-and-cold"
FONT = ROOT / "assets/fonts/Cormorant_Garamond/static/CormorantGaramond-SemiBold.ttf"
OUT = ROOT / "assets/ui/logo.png"
TEXT = "BRAVE AND COLD"
SIZE = 300
TRACK = 0.15
WORD_GAP = 0.28
PAD = 120
OCHRE = (204, 163, 92)
rng = np.random.default_rng(20261017)


def fbm(h, w, octaves=5, base=6):
    acc = np.zeros((h, w), np.float32); amp, tot = 1.0, 0.0
    for o in range(octaves):
        gh, gw = base * 2 ** o + 1, int(base * 2 ** o * w / h) + 1
        g = Image.fromarray((rng.random((gh, gw)) * 255).astype(np.uint8))
        acc += amp * np.asarray(g.resize((w, h), Image.BICUBIC), np.float32) / 255.0
        tot += amp; amp *= 0.55
    return acc / tot


def blur(arr, r):
    return np.asarray(Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), np.float32) / 255.0


def wordmark_mask():
    """Glyph-by-glyph: each letter slightly rotated, shifted and widened, like cut by hand."""
    font = ImageFont.truetype(str(FONT), SIZE)
    asc, desc = font.getmetrics()
    advances = [font.getlength(ch) + (SIZE * WORD_GAP if ch == " " else SIZE * TRACK) for ch in TEXT]
    W = int(sum(advances) + PAD * 2); H = int(asc + desc + PAD * 2)
    m = Image.new("L", (W, H), 0)
    x = PAD
    for ch, adv in zip(TEXT, advances):
        if ch != " ":
            gw = int(font.getlength(ch) + SIZE * 0.4)
            g = Image.new("L", (gw, asc + desc + 40), 0)
            ImageDraw.Draw(g).text((SIZE * 0.2, 20), ch, font=font, fill=255)
            sx = 1.0 + rng.normal(0, 0.018)
            g = g.resize((max(1, int(g.width * sx)), g.height), Image.BICUBIC)
            g = g.rotate(rng.normal(0, 0.9), resample=Image.BICUBIC, expand=False)
            dy = int(rng.normal(0, SIZE * 0.008))
            m.paste(Image.fromarray(np.maximum(np.asarray(m.crop((int(x - SIZE * 0.2), PAD - 20 + dy, int(x - SIZE * 0.2) + g.width, PAD - 20 + dy + g.height))), np.asarray(g))), (int(x - SIZE * 0.2), PAD - 20 + dy))
        x += adv
    return np.asarray(m, np.float32) / 255.0, asc


def hand_cut(a):
    """Re-cut outlines: threshold the blurred glyph against noise (uneven, swollen edges)."""
    H, W = a.shape
    soft = blur(a, 3.2)
    wob = fbm(H, W, octaves=3, base=26) * 0.6 + fbm(H, W, octaves=2, base=120) * 0.4
    thr = 0.42 + (wob - 0.5) * 0.22          # < 0.5: a touch bolder than the font
    cut = np.clip((soft - thr) * 9.0, 0, 1)
    return cut


def emblem(px):
    """Winter sun low behind a slope, two spruces. Drawn at 4x, returns RGBA px x px.
    v2a review: the snow took half the disc (read as an egg) and the tree was a thin
    pagoda; now a low, sloped ridge in cool grey and a broad drooping spruce + a small one."""
    S = px * 4
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy, r = S * 0.5, S * 0.5, S * 0.42
    for k in range(60, 0, -1):
        t = k / 60.0
        col = tuple(int(c * (0.78 + 0.22 * (1 - t) ** 1.5)) for c in OCHRE) + (255,)
        d.ellipse((cx - r * t, cy - r * t, cx + r * t, cy + r * t), fill=col)
    disc = Image.new("L", (S, S), 0); ImageDraw.Draw(disc).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    # sloped snow ridge: higher on the left, low on the right, slight hand wobble
    pts = []
    for i in range(41):
        u = i / 40
        x = cx - r * 1.05 + u * r * 2.1
        y = cy + r * (0.60 - 0.22 * (1 - u) ** 1.6) + rng.normal(0, r * 0.008)
        pts.append((x, y))
    snow = Image.new("L", (S, S), 0); ImageDraw.Draw(snow).polygon(pts + [(cx + r * 1.1, S), (cx - r * 1.1, S)], fill=255)
    snow = Image.fromarray(np.minimum(np.asarray(snow), np.asarray(disc)))
    im.paste((196, 202, 212, 255), (0, 0), snow)

    def spruce(tx, base_y, height, width, tiers):
        dark = (18, 20, 24, 255)
        top_y = base_y - height
        for i in range(tiers):
            t = i / (tiers - 1)
            y0 = top_y + height * 0.92 * (t ** 0.85)
            half = width * (0.10 + 0.90 * t) * (1 + rng.normal(0, 0.07)) * 0.5
            hgt = height * (0.10 + 0.04 * t)
            droop = hgt * 0.45
            d.polygon([(tx + rng.normal(0, width * 0.01), y0 - hgt * 0.6),
                       (tx + half, y0 + droop + rng.normal(0, width * 0.015)),
                       (tx + half * 0.6, y0 + droop * 0.6),
                       (tx + half * 0.3, y0 + droop * 0.95),
                       (tx, y0 + droop * 0.75),
                       (tx - half * 0.3, y0 + droop * 0.95),
                       (tx - half * 0.6, y0 + droop * 0.6),
                       (tx - half, y0 + droop + rng.normal(0, width * 0.015))], fill=dark)
        d.rectangle((tx - width * 0.035, base_y - height * 0.06, tx + width * 0.035, base_y + height * 0.03), fill=dark)

    spruce(cx - r * 0.20, cy + r * 0.44, r * 1.18, r * 0.80, 12)
    spruce(cx + r * 0.46, cy + r * 0.58, r * 0.56, r * 0.38, 8)
    # clip everything to the disc, then a thin uneven hand-inked ring
    a = np.asarray(im).copy(); a[..., 3] = np.minimum(a[..., 3], np.asarray(disc)); im = Image.fromarray(a)
    d = ImageDraw.Draw(im)
    for k in range(2):
        o = r + S * 0.005 * k
        d.ellipse((cx - o, cy - o, cx + o, cy + o), outline=(16, 16, 18, 230 - 90 * k), width=max(1, S // 220))
    return im.resize((px, px), Image.LANCZOS)


def main():
    a, asc = wordmark_mask()
    a = hand_cut(a)
    H, W = a.shape
    n = fbm(H, W); fine = fbm(H, W, octaves=3, base=60)
    # light wear only: a few chips at edges
    edge = np.clip(1.0 - np.abs(blur(a, 4) - 0.5) * 2.0, 0, 1)
    wear = np.clip((n * 0.7 + fine * 0.3 - 0.36) * 5.0, 0, 1)
    alpha = np.clip(a * (1.0 - edge * (1.0 - wear) * 0.55), 0, 1)
    ys = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    top = PAD / H; bot = (PAD + SIZE * 0.95) / H
    t = np.clip((ys - top) / (bot - top), 0, 1)
    col = np.broadcast_to(np.array([0.99, 0.99, 1.0], np.float32) * (1 - t) + np.array([0.95, 0.93, 0.87], np.float32) * t, (H, W, 3)).copy()
    col *= (0.97 + 0.03 * fine)[..., None]   # v2a mottling read as smudges
    word = np.dstack([col, alpha])
    word_im = Image.fromarray((np.clip(word, 0, 1) * 255).astype(np.uint8), "RGBA")
    word_im = word_im.crop(word_im.getbbox())

    cap = int(SIZE * 0.66)                 # cap height of the font at SIZE (approx.)
    em_px = int(word_im.height * 1.45)
    em = emblem(em_px)
    gap = int(SIZE * 0.32)
    LW = em_px + gap + word_im.width + PAD * 2
    LH = max(em_px, word_im.height) + PAD * 2
    lock = Image.new("RGBA", (LW, LH), (0, 0, 0, 0))
    lock.alpha_composite(em, (PAD, (LH - em_px) // 2))
    lock.alpha_composite(word_im, (PAD + em_px + gap, (LH - word_im.height) // 2))
    # soft dark halo behind everything (outside the art only)
    la = np.asarray(lock, np.float32) / 255.0
    halo = np.roll(blur(la[..., 3], 20), 6, axis=0) * 0.5 * (1.0 - la[..., 3])
    out_a = la[..., 3] + halo
    rgb = la[..., :3] * (la[..., 3] / np.maximum(out_a, 1e-4))[..., None]
    final = Image.fromarray((np.dstack([np.clip(rgb, 0, 1), np.clip(out_a, 0, 1)]) * 255).astype(np.uint8), "RGBA")
    final = final.crop(final.getbbox())
    final = final.resize((1920, round(final.height * 1920 / final.width)), Image.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    final.save(OUT, optimize=True)
    print(OUT, final.size, "cap", cap)
    if "--preview" in sys.argv:
        bg = Image.open(ROOT / "assets/ui/menu_bg_lookout.jpg").convert("RGBA").resize((2560, 1440))
        f2 = final.resize((1100, round(final.height * 1100 / 1920)), Image.LANCZOS)
        bg.alpha_composite(f2, (150, 230))
        bg.crop((100, 150, 1400, 520)).convert("RGB").save(ROOT.parent / "shots/logo_preview.png")
        big = Image.new("RGBA", final.size, (40, 44, 58, 255)); big.alpha_composite(final)
        big.convert("RGB").save(ROOT.parent / "shots/logo_big.png")


if __name__ == "__main__":
    main()
