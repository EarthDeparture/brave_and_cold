"""Hydrology pass for valley_b.

River: REAL channel extracted from lidar canopy height (water returns give canopy ~0 in a continuous winding
band). Lake: authored ellipse in a treeless meadow. Both are carved into the DTM (soft banks).
Outputs into brave-and-cold/data/maps/<name>/:
  height.r16 (re-encoded; original kept as height_orig.r16), meta.json (z_min updated),
  water_mask.png (255 = water), water_level.r16 (level ASL, same z encoding as height), water.json (lake + z range).
World coords: x = px - size/2, z = py - size/2. Godot y = ASL - z_min.
Run: uv run python carve_water.py valley_b
"""
import json
import sys
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

name = sys.argv[1] if len(sys.argv) > 1 else "valley_b"
D = Path(__file__).resolve().parents[2] / "brave-and-cold" / "data" / "maps" / name
meta = json.loads((D / "meta.json").read_text())
N = int(meta["size_m"])
orig = D / "height_orig.r16"
if not orig.exists():
    (D / "height.r16").replace(orig)
    meta["z_min_orig"] = meta["z_min_m"]
    meta["z_max_orig"] = meta["z_max_m"]
zmin0, zmax0 = meta["z_min_orig"], meta["z_max_orig"]
raw = np.fromfile(orig, dtype="<u2").reshape(N, N).astype(np.float32)
h = zmin0 + raw / 65535.0 * (zmax0 - zmin0)
can = np.array(Image.open(D / "canopy.png").convert("L")).astype(np.float32) / 255.0 * 40.0

# --- real river channel from canopy
base = ndi.minimum_filter(h, size=151)
low = (h - base) < 9.0
m0 = (can < 0.5) & low
m0 = ndi.binary_opening(m0, structure=np.ones((5, 5)))
lab, n = ndi.label(m0)
sizes = ndi.sum(m0, lab, range(1, n + 1))
order = np.argsort(sizes)[::-1]
keep_ids = [int(i) + 1 for i in order[:3] if sizes[i] > 3000]
river = np.isin(lab, keep_ids)
river = ndi.binary_closing(river, structure=np.ones((3, 3)), iterations=2)
river = ndi.binary_fill_holes(river)

# --- lake in a treeless meadow (authored)
LRX, LRY, LANG = 100.0, 62.0, 0.0
# search: flattest treeless spot near river level, clear of the river
_win = (2 * int(LRY), 2 * int(LRX))
_m = ndi.uniform_filter(h, _win)
_sd = np.sqrt(np.maximum(ndi.uniform_filter(h * h, _win) - _m * _m, 0))
_cm = ndi.uniform_filter(can, _win)
_rv = ndi.distance_transform_edt(~river)
_riv_h = h[river]
_ok = (_cm < 25.0) & (_rv > 75) & (_m < float(_riv_h.max()) + 30.0)
_ok[:130, :] = False; _ok[-130:, :] = False; _ok[:, :130] = False; _ok[:, -130:] = False
_score = np.where(_ok, _sd, 1e9)
_iy, _ix = np.unravel_index(np.argmin(_score), _score.shape)
LCX, LCY = float(_ix), float(_iy)
print("LAKE_SITE", LCX, LCY, "sd", float(_score[_iy, _ix]), "mean_h", float(_m[_iy, _ix]))
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
dx, dy = xx - LCX, yy - LCY
u = dx * np.cos(LANG) + dy * np.sin(LANG)
v = -dx * np.sin(LANG) + dy * np.cos(LANG)
e = np.sqrt((u / LRX) ** 2 + (v / LRY) ** 2)
lake = e <= 1.0
lake &= ~ndi.binary_dilation(river, iterations=6)

water = river | lake


def level_for(mask, sigma):
    if not mask.any():
        return np.zeros_like(h)
    num = ndi.gaussian_filter(np.where(mask, h, 0.0), sigma)
    den = ndi.gaussian_filter(mask.astype(np.float32), sigma)
    return num / np.maximum(den, 1e-4)


river_level = level_for(river, 30.0) - 0.35
lake_level_val = float(np.median(h[lake])) - 0.6 if lake.any() else 0.0
level = np.where(lake, lake_level_val, river_level).astype(np.float32)

BANK = 9.0
dist, (iy, ix) = ndi.distance_transform_edt(~water, return_indices=True)
lvl_near = level[iy, ix]
depth = np.where(lake[iy, ix], 3.0, 1.6)
bed = lvl_near - depth
prof = np.clip((BANK - dist) / BANK, 0, 1)
prof = prof * prof * (3 - 2 * prof)
prof[dist == 0] = 1.0
h_new = np.where(h > bed, h + (bed - h) * prof, h)

Image.fromarray((ndi.binary_dilation(water, iterations=1) * 255).astype(np.uint8)).save(D / "water_mask.png")

zmin = float(np.floor(h_new.min())) - 1.0
zmax = float(zmax0)


def enc(a):
    return np.clip(np.round((a - zmin) / (zmax - zmin) * 65535.0), 0, 65535).astype("<u2")


enc(h_new).tofile(D / "height.r16")
enc(np.where(water, level, zmin)).tofile(D / "water_level.r16")
meta["z_min_m"] = zmin
meta["z_max_m"] = zmax
(D / "meta.json").write_text(json.dumps(meta, indent=2))
(D / "water.json").write_text(json.dumps({"z_min_m": zmin, "z_max_m": zmax, "size_m": N,
                                          "lake": {"level": lake_level_val}}))
print("WATER_OK river_px", int(river.sum()), "lake_px", int(lake.sum()), "lake_level", round(lake_level_val, 2),
      "river level range", round(float(river_level[river].min()), 1), round(float(river_level[river].max()), 1), "zmin", zmin)
