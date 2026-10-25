"""Original winter twig atlas. Pillow only; no sampled reference artwork."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import random, math, json, hashlib
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tools/blender/generated/winter_tree_diversity_v1"


def make_tile(seed, family):
    rng = random.Random(seed)
    scale = 2
    image = Image.new("RGBA", (512 * scale, 512 * scale))
    draw = ImageDraw.Draw(image)

    def line(a, b, color, width):
        draw.line([tuple(round(v * scale) for v in a), tuple(round(v * scale) for v in b)], fill=color, width=max(1, round(width * scale)))

    # A twig, rather than a triangular sheet or a white blob. The outer gutter
    # stays empty so mip filtering cannot join neighbouring atlas cells.
    origin, tip = (36, 283), (472, 250)
    line(origin, tip, (68, 57, 44, 255), 7)
    line((36, 279), (468, 247), (99, 86, 66, 255), 2)
    branches = 14 if family == "fir" else 11
    for index in range(branches):
        t = .1 + .77 * index / (branches - 1)
        x = origin[0] + (tip[0] - origin[0]) * t
        y = origin[1] + (tip[1] - origin[1]) * t
        for sign in [-1, 1]:
            reach = (116 if family == "fir" else 99) * math.sin(t * math.pi) * rng.uniform(.78, 1.15)
            end = (x + reach * .7, y + sign * reach)
            line((x, y), end, (70, 67, 47, 255), 3)
            needles = 19 if family == "fir" else 13
            for n in range(needles):
                u = .07 + .9 * n / needles
                bx, by = x + (end[0] - x) * u, y + (end[1] - y) * u
                length = rng.uniform(18, 36) if family == "pine" else rng.uniform(12, 22)
                for side in [-1, 1]:
                    angle = math.atan2(end[1] - y, end[0] - x) + side * rng.uniform(.45, 1.15)
                    ex, ey = bx + math.cos(angle) * length, by + math.sin(angle) * length
                    tone = rng.uniform(.76, 1.18)
                    base = (42, 71, 62) if family == "fir" else (45, 77, 66)
                    color = tuple(int(c * tone) for c in base) + (255,)
                    line((bx, by), (ex, ey), (20, 38, 33, 255), 3.4)
                    line((bx, by - .4), (ex, ey - .4), color, 2.0)
                    line((bx + 1, by - 1), (ex, ey - 1), (71, 92, 77, 255), .8)
                    # Broken dusting: needles remain legible underneath. Dense
                    # resting snow is separate, genuinely thick mesh geometry.
                    if sign < 0 and rng.random() < .14:
                        start = rng.uniform(.15, .45)
                        line((bx + (ex - bx) * start, by + (ey - by) * start - 2), (ex - 1, ey - 2), (179, 196, 203, 245), 3.5)
                        line((bx + (ex - bx) * start, by + (ey - by) * start - 3), (ex - 1, ey - 3), (213, 222, 219, 250), 1.6)
            if sign < 0:
                # Uneven connected snow ridges, not white stitching on every
                # needle. Their shadowed lower edge provides painted depth.
                length = math.hypot(end[0] - x, end[1] - y)
                dx, dy = (end[0] - x) / length, (end[1] - y) / length
                perp = (-dy, dx)
                top, bottom = [], []
                for step in range(8):
                    t = .12 + step / 8 * .82
                    cx, cy = x + (end[0] - x) * t, y + (end[1] - y) * t - 4
                    width = rng.uniform(4, 10) * math.sin(t * math.pi)
                    top.append(((cx + perp[0] * width) * scale, (cy + perp[1] * width) * scale))
                    bottom.append(((cx - perp[0] * width) * scale, (cy - perp[1] * width) * scale))
                draw.polygon(top + list(reversed(bottom)), fill=(195, 209, 211, 255))
                line((x + 7, y - 7), (end[0] - 12, end[1] - 7), (225, 231, 226, 250), 3.0)
    return image.resize((512, 512), Image.Resampling.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", (1024, 1024))
    for tile, (seed, family) in enumerate([(613, "pine"), (719, "fir"), (823, "fir"), (929, "pine")]):
        atlas.alpha_composite(make_tile(seed, family), ((tile % 2) * 512, (tile // 2) * 512))
    path = OUT / "winter_twigs.png"
    atlas.save(path)
    make_far_boughs(atlas)
    make_bark()
    (OUT / "texture_provenance.json").write_text(json.dumps({
        "origin": "Original procedural drawing using Python/Pillow; no reference pixels or external textures",
        "size": [1024, 1024], "format": "RGBA8 sRGB; transparent botanical twig silhouettes",
        "seeds": [613, 719, 823, 929], "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "tile_order_top_left": ["open pine", "full fir", "weathered spruce", "spare pine"],
        "mip_gutter_px": 24,
        "bark_textures": {name: hashlib.sha256((OUT / name).read_bytes()).hexdigest() for name in ["winter_bark.png", "winter_bark_normal.png"]},
        "bark_origin": "Original NumPy height fields and Pillow birch scars; OpenGL +Y tangent normal map",
        "far_bough_sha256": hashlib.sha256((OUT / "winter_boughs_far.png").read_bytes()).hexdigest(),
        "far_bough_origin": "Original twig tiles composed along the same four branchlet positions; baked foliage coverage for reduced distant planes",
    }, indent=2) + "\n", newline="\n")
    print("WINTER_TWIG_ATLAS", path)


def make_far_boughs(atlas):
    result = Image.new("RGBA", (1024, 1024))
    for tile in range(4):
        source = atlas.crop(((tile % 2) * 512, (tile // 2) * 512, (tile % 2 + 1) * 512, (tile // 2 + 1) * 512))
        source = source.crop(source.getchannel("A").getbbox())
        canvas = Image.new("RGBA", (512, 512))

        def spray(length, width, root, angle):
            image = source.resize((length, width), Image.Resampling.LANCZOS)
            c, s = math.cos(angle), math.sin(angle)
            ax, ay = root
            # Inverse rigid transform about the root of this original twig.
            transformed = image.transform((512, 512), Image.Transform.AFFINE, (c, s, -c * ax - s * ay, -s, c, s * ax - c * ay + width * .5), Image.Resampling.BICUBIC)
            canvas.alpha_composite(transformed)

        spray(404, 182, (30, 256), 0)
        for fraction in [.30, .63]:
            for side in [-1, 1]:
                spray(round(360 * (.84 - fraction * .45)), 110, (30 + fraction * 360, 256), side * (.75 - fraction * .2))
        result.alpha_composite(canvas, ((tile % 2) * 512, (tile // 2) * 512))
    result.save(OUT / "winter_boughs_far.png")


def make_bark():
    rng = np.random.default_rng(6151)
    y, x = np.mgrid[0:1024, 0:512]
    phase = x * .16 + np.sin(y * .013) * 1.7 + np.sin(y * .047 + x * .018) * .9
    furrow = np.power((np.sin(phase) + 1) * .5, 3)
    grit = rng.normal(0, .025, x.shape)
    h = np.clip(.30 + furrow * .32 + np.sin(y * .08 + x * .11) * .028 + grit, 0, 1)
    dark = np.stack([57 + h * 91, 52 + h * 74, 43 + h * 53], axis=2)
    birch = np.stack([184 + grit * 120 + np.sin(y * .12) * 4, 184 + grit * 120 + np.sin(y * .12) * 4, 173 + grit * 110], axis=2)
    pale = Image.fromarray(np.uint8(np.clip(birch, 0, 255)), "RGB")
    draw = ImageDraw.Draw(pale)
    scar_rng = random.Random(7219)
    for index in range(70):
        cx, cy = scar_rng.randint(-30, 510), scar_rng.randint(0, 1023)
        width, height = scar_rng.randint(9, 85), scar_rng.randint(1, 6)
        draw.polygon([(cx, cy), (cx + width * .4, cy - 1), (cx + width, cy + 1), (cx + width * .76, cy + height), (cx + 2, cy + height)], fill=(75, 82, 76))
        draw.line([(cx + 1, cy + height + 1), (cx + width * .75, cy + height + 1)], fill=(209, 213, 194), width=1)
    atlas = Image.new("RGB", (1024, 1024))
    atlas.paste(Image.fromarray(np.uint8(np.clip(dark, 0, 255)), "RGB"), (0, 0)); atlas.paste(pale, (512, 0))
    atlas.save(OUT / "winter_bark.png")
    pale_h = np.asarray(pale.convert("L"), dtype=float) / 255
    heights = np.concatenate([h, pale_h], axis=1)
    gy, gx = np.gradient(heights)
    normals = np.stack([-gx * 3, gy * 3, np.ones_like(gx)], axis=2)
    normals /= np.linalg.norm(normals, axis=2, keepdims=True)
    Image.fromarray(np.uint8(np.clip((normals * .5 + .5) * 255, 0, 255)), "RGB").save(OUT / "winter_bark_normal.png")


if __name__ == "__main__":
    main()
