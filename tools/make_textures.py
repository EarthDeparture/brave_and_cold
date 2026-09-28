"""
M2 look-dev: procedural "painterly" texture generator (Blender numpy).

Generates the shared texture set into the Godot project:
  snow.png          - terrain albedo (low-contrast banded noise, cool tint)
  sparkle_noise.png - white noise for the snow sparkle shader
  wood.png          - cabin plank albedo (streaky, banded, plank seams)
  bark.png          - tree bark albedo (vertical groove streaks)
  flake.png         - soft alpha dot for snowfall particles

Run headless:
  blender.exe --background --python tools/make_textures.py -- <out_dir>

Design note: the "painterly" read comes from LOW-CONTRAST banded noise and a
tight palette, not from detail. This is a stand-in for hand-painted art (M6).
"""
import os
import sys

import bpy
import numpy as np


# ---------------------------------------------------------------- noise utils

def box_blur(a, iters):
    for _ in range(iters):
        a = (a + np.roll(a, 1, 0) + np.roll(a, -1, 0)
               + np.roll(a, 1, 1) + np.roll(a, -1, 1)) * 0.2
    return a


def octave(w, h, cells, rng):
    g = rng.random((cells, cells)).astype(np.float32)
    fy, fx = -(-h // cells), -(-w // cells)  # ceil so upsampling covers full extent
    up = np.kron(g, np.ones((fy, fx), np.float32))[:h, :w]
    return box_blur(up, max(1, min(fx, fy) // 2))


def fbm(w, h, base_cells, octaves, rng, persistence=0.5):
    total = np.zeros((h, w), np.float32)
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        total += amp * octave(w, h, base_cells * (2 ** o), rng)
        norm += amp
        amp *= persistence
    return total / norm


def posterize(v, bands):
    return np.floor(v * bands) / (bands - 1.0)


def save(path, rgb, alpha=None):
    h, w = rgb.shape[0], rgb.shape[1]
    rgba = np.ones((h, w, 4), np.float32)
    rgba[..., 0:3] = rgb if rgb.ndim == 3 else np.repeat(rgb[..., None], 3, axis=2)
    if alpha is not None:
        rgba[..., 3] = alpha
    img = bpy.data.images.new(os.path.basename(path), width=w, height=h, alpha=True)
    img.pixels.foreach_set(rgba.reshape(-1).astype(np.float32))
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    print(f"[make_textures] wrote {path}")


# ---------------------------------------------------------------- generators

def make_snow(out):
    rng = np.random.default_rng(101)
    v = fbm(512, 512, 4, 4, rng)                      # soft large shapes
    v = posterize(v, 9)                                # gentle banding = painterly
    v = box_blur(v, 2)
    v = 0.86 + 0.12 * v                                # compress to 0.86..0.98
    rgb = np.stack([v * 0.965, v * 0.985, np.minimum(1.0, v * 1.01 + 0.01)], axis=-1)
    save(os.path.join(out, "snow.png"), rgb)


def make_sparkle_noise(out):
    rng = np.random.default_rng(202)
    save(os.path.join(out, "sparkle_noise.png"), rng.random((256, 256)).astype(np.float32))


def make_wood(out):
    rng = np.random.default_rng(303)
    base = fbm(512, 512, 6, 4, rng)
    # horizontal grain: stretch x heavily so streaks run along planks
    grain = base[:, (np.arange(512) // 6) % 512]
    v = posterize(box_blur(grain, 1), 7)

    # plank seams every 64 px + per-plank tone jitter
    yy = np.arange(512)[:, None]
    plank_id = (yy // 64)
    jitter = rng.random((8, 1)).astype(np.float32)[plank_id.flatten()].reshape(512, 1)
    v = np.clip(v * (0.9 + 0.2 * jitter), 0, 1)
    seam = ((yy % 64) < 2)
    v = np.where(seam, v * 0.55, v)

    a = np.array([0.30, 0.19, 0.10], np.float32)      # dark brown
    b = np.array([0.56, 0.40, 0.23], np.float32)      # worn warm brown
    save(os.path.join(out, "wood.png"), a + (b - a) * v[..., None])


def make_bark(out):
    rng = np.random.default_rng(404)
    base = fbm(512, 512, 8, 4, rng)
    # vertical grooves: stretch y so streaks run up the trunk
    grooves = base[(np.arange(512) // 8) % 512, :]
    v = posterize(box_blur(grooves, 1), 6)
    a = np.array([0.13, 0.11, 0.10], np.float32)
    b = np.array([0.32, 0.27, 0.24], np.float32)
    save(os.path.join(out, "bark.png"), a + (b - a) * v[..., None])


def make_flake(out):
    w = 64
    yy, xx = np.mgrid[0:w, 0:w].astype(np.float32)
    r = np.sqrt((xx - w / 2 + 0.5) ** 2 + (yy - w / 2 + 0.5) ** 2) / (w / 2)
    alpha = np.clip(1.0 - r, 0.0, 1.0) ** 1.5
    save(os.path.join(out, "flake.png"), np.ones((w, w, 3), np.float32), alpha=alpha)


def main():
    argv = sys.argv
    if "--" not in argv or len(argv[argv.index("--") + 1:]) != 1:
        raise SystemExit("Usage: blender --background --python make_textures.py -- <out_dir>")
    out = os.path.abspath(argv[argv.index("--") + 1])
    os.makedirs(out, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    make_snow(out)
    make_sparkle_noise(out)
    make_wood(out)
    make_bark(out)
    make_flake(out)


main()
