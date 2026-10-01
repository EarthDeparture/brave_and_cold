"""
Run: blender.exe --background --factory-startup --python gen_vm_tex.py -- <out_dir>
Procedural, tileable 512x512 hand-paint-style textures for the first-person viewmodel (numpy ships with Blender).
Writes vm_<name>.png into out_dir/tex. Albedo only; roughness/metal live on the glTF materials.
"""
import sys, os
import numpy as np
import bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(os.path.join(argv[0] if argv else ".", "tex"))
os.makedirs(OUT, exist_ok=True)
N = 512
rng = np.random.default_rng(11)


def pnoise(sx=8.0, sy=8.0, seed=None):
    """Periodic noise 0..1. sx/sy = approx feature count across the tile (lower = smoother)."""
    r = np.random.default_rng(seed) if seed is not None else rng
    a = r.standard_normal((N, N))
    F = np.fft.fft2(a)
    fy = np.fft.fftfreq(N)[:, None] * N
    fx = np.fft.fftfreq(N)[None, :] * N
    f = np.exp(-((fx / sx) ** 2 + (fy / sy) ** 2))
    b = np.real(np.fft.ifft2(F * f))
    b -= b.min()
    b /= max(b.max(), 1e-6)
    return b


def lerp(a, b, t):
    t = t[..., None]
    return np.array(a) * (1 - t) + np.array(b) * t


def save(name, rgb):
    rgb = np.clip(rgb, 0.0, 1.0)
    img = bpy.data.images.new("vm_" + name, N, N, alpha=False)
    px = np.ones((N, N, 4), dtype=np.float32)
    px[..., :3] = rgb
    img.pixels.foreach_set(px.ravel())
    img.filepath_raw = os.path.join(OUT, f"vm_{name}.png")
    img.file_format = "PNG"
    img.save()
    print("TEX", name)


def wood(name, dark, light, rings=9.0):
    # grain runs along U (image x): long streaks vary mostly with y
    streak = pnoise(sx=3.0, sy=60.0, seed=1)
    warp = pnoise(sx=3.0, sy=4.0, seed=2)
    y = (np.arange(N)[:, None] / N) * np.ones((1, N))
    bands = 0.5 + 0.5 * np.sin(2 * np.pi * (y * rings + warp * 0.8))
    fine = pnoise(sx=4.0, sy=140.0, seed=3)
    t = 0.45 * bands + 0.35 * streak + 0.2 * fine
    t = np.clip((t - 0.2) * 1.4, 0, 1)
    c = lerp(dark, light, t)
    pores = (pnoise(sx=90.0, sy=90.0, seed=4) > 0.82).astype(np.float64) * pnoise(sx=2.0, sy=40.0, seed=5)
    c *= (1.0 - 0.25 * pores[..., None])
    mott = pnoise(sx=3.0, sy=3.0, seed=6)
    c *= (0.88 + 0.24 * mott[..., None])
    save(name, c)


def knit(name, base, hi, w=32, h=40):
    yy, xx = np.mgrid[0:N, 0:N]
    fx = (xx % w) / w
    fy = (yy % h) / h
    # two legs of a V per cell (stockinette), plus neighbour wrap
    dA = np.abs(fx - 0.5 * fy)
    dB = np.abs(fx - (1.0 - 0.5 * fy))
    d = np.minimum(np.minimum(dA, dB), np.minimum(np.abs(fx - 0.5 * fy - 1), np.abs(fx - 0.5 * fy + 1)))
    strand = np.exp(-(d / 0.17) ** 2)
    rounded = strand * (0.65 + 0.35 * np.sin(np.pi * np.clip(fy, 0, 1)))
    fuzz = pnoise(sx=170.0, sy=170.0, seed=7)
    slub = pnoise(sx=14.0, sy=30.0, seed=8)
    t = np.clip(rounded * (0.75 + 0.5 * slub) + 0.35 * (fuzz - 0.5), 0, 1)
    c = lerp(np.array(base) * 0.75, hi, t)
    save(name, c)


def leather(name, base):
    mott = pnoise(sx=6.0, sy=6.0, seed=9)
    grain = pnoise(sx=130.0, sy=130.0, seed=10)
    cr = pnoise(sx=9.0, sy=3.5, seed=12)
    crease = np.exp(-((cr - 0.5) / 0.035) ** 2)
    cr2 = pnoise(sx=3.5, sy=9.0, seed=13)
    crease += np.exp(-((cr2 - 0.5) / 0.035) ** 2)
    c = np.array(base)[None, None, :] * (0.78 + 0.34 * mott[..., None] + 0.12 * (grain[..., None] - 0.5))
    c *= (1.0 - 0.16 * np.clip(crease, 0, 1)[..., None])
    save(name, c)


def fabric(name, base):
    yy, xx = np.mgrid[0:N, 0:N]
    weave = 0.5 + 0.25 * np.sin(xx * 2 * np.pi / 4) * np.sin(yy * 2 * np.pi / 4) + 0.25 * np.sin(xx * 2 * np.pi / 8 + yy * 2 * np.pi / 8)
    folds = pnoise(sx=5.0, sy=3.0, seed=14)
    dirt = pnoise(sx=12.0, sy=12.0, seed=15)
    c = np.array(base)[None, None, :] * (0.78 + 0.18 * weave[..., None]) * (0.72 + 0.5 * folds[..., None]) * (0.85 + 0.2 * dirt[..., None])
    save(name, c)


def steel(name, base, wear):
    streak = pnoise(sx=2.5, sy=170.0, seed=16)
    mott = pnoise(sx=7.0, sy=7.0, seed=17)
    scratch = np.exp(-((pnoise(sx=2.0, sy=120.0, seed=18) - 0.5) / 0.02) ** 2)
    c = np.array(base)[None, None, :] * (0.8 + 0.3 * streak[..., None]) * (0.85 + 0.3 * mott[..., None])
    c = c + np.array(wear)[None, None, :] * (0.55 * scratch[..., None] + 0.25 * (pnoise(sx=60.0, sy=60.0, seed=19) > 0.86)[..., None])
    save(name, c)


def rubber(name):
    n = pnoise(sx=120.0, sy=120.0, seed=20)
    save(name, np.array([0.06, 0.06, 0.065])[None, None, :] * (0.7 + 0.6 * n[..., None]))


if __name__ == "__main__":
    wood("walnut", (0.17, 0.085, 0.035), (0.46, 0.27, 0.12))
    wood("ash", (0.40, 0.26, 0.13), (0.72, 0.55, 0.34), rings=6.0)
    knit("wool", (0.30, 0.27, 0.24), (0.62, 0.58, 0.52))
    leather("leather", (0.50, 0.32, 0.17))
    fabric("fabric", (0.30, 0.34, 0.25))
    steel("blued", (0.13, 0.14, 0.17), (0.35, 0.36, 0.38))
    steel("steel", (0.50, 0.51, 0.54), (0.35, 0.35, 0.35))
    rubber("rubber")

