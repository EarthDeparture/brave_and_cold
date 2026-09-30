"""Authored hydrology pass for valley_b: carve a river channel and a lake basin into the lidar DTM.

Lidar has no water surfaces, so water is designed: river polyline + lake ellipse, bed carved with soft banks.
Outputs into brave-and-cold/data/maps/<name>/: height.r16 (re-encoded, original kept as height_orig.r16),
meta.json (z_min updated, water block added), water.json (river centreline with world coords + level, lake), water_mask.png.
World coords: x = px - size/2, z = py - size/2 (metres). water level y in metres ASL (add -z_min for Godot y).
Run: uv run python carve_water.py valley_b
"""
import json
import sys
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from scipy.interpolate import CubicSpline

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

# --- river centreline (pixel coords, x,y) through the floodplain, flowing north-west to south-east
pts = np.array([(330, 0), (345, 300), (430, 620), (570, 900), (770, 1150), (1000, 1440), (1240, 1740), (1430, 2047)], np.float64)
t = np.r_[0, np.cumsum(np.hypot(*np.diff(pts, axis=0).T))]
cs = CubicSpline(t, pts, bc_type="natural")
ts = np.linspace(0, t[-1], int(t[-1] / 2))
line = cs(ts)
line[:, 0] = np.clip(line[:, 0], 0, N - 1)
line[:, 1] = np.clip(line[:, 1], 0, N - 1)

RIVER_W = 16.0     # water width (m)
BANK = 10.0        # bank blend distance (m)
lx = np.clip(line[:, 0].round().astype(int), 0, N - 1)
ly = np.clip(line[:, 1].round().astype(int), 0, N - 1)
ground = ndi.uniform_filter1d(h[ly, lx], size=40)
level = ground - 1.0
level = np.minimum.accumulate(level)  # never flows uphill
level = ndi.uniform_filter1d(level, size=25)
level = np.minimum.accumulate(level)

canvas = np.ones((N, N), bool)
canvas[ly, lx] = False
dist, (iy, ix) = ndi.distance_transform_edt(canvas, return_indices=True)
# nearest centreline sample index for level lookup
idx_map = -np.ones((N, N), np.int32)
idx_map[ly, lx] = np.arange(len(ly))
nearest_idx = idx_map[iy, ix]
lvl = level[np.clip(nearest_idx, 0, len(level) - 1)]
half = RIVER_W / 2
bed = lvl - 1.8
prof = np.clip((half + BANK - dist) / BANK, 0, 1)
prof = prof * prof * (3 - 2 * prof)
prof[dist <= half] = 1.0
h_new = np.where(h > bed, h + (bed - h) * prof, h)
river_mask = dist <= half

# --- lake (ellipse) in the floodplain west of the river
LCX, LCY, LRX, LRY, LANG = 560.0, 1010.0, 120.0, 72.0, np.radians(35)
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
dx, dy = xx - LCX, yy - LCY
u = dx * np.cos(LANG) + dy * np.sin(LANG)
v = -dx * np.sin(LANG) + dy * np.cos(LANG)
e = np.sqrt((u / LRX) ** 2 + (v / LRY) ** 2)  # 1.0 at shoreline
lake_ground = float(np.median(h[e < 1.0])) if (e < 1.0).any() else float(h[int(LCY), int(LCX)])
lake_level = lake_ground - 0.8
depth = 5.0
lp = np.clip((1.35 - e) / 0.35, 0, 1)
lp = lp * lp * (3 - 2 * lp)
lake_bed = lake_level - depth * np.clip(1.0 - (e / 1.0) ** 2, 0, 1) - 0.6
target = np.where(e < 1.0, lake_bed, lake_level - 0.6)
h_new = np.where((lp > 0) & (h_new > target), h_new + (target - h_new) * lp, h_new)
lake_mask = e <= 1.0

water = river_mask | lake_mask
Image.fromarray((water * 255).astype(np.uint8)).save(D / "water_mask.png")

# --- re-encode
zmin = float(np.floor(h_new.min())) - 1.0
zmax = float(zmax0)
enc = np.clip(np.round((h_new - zmin) / (zmax - zmin) * 65535.0), 0, 65535).astype("<u2")
enc.tofile(D / "height.r16")
meta["z_min_m"] = zmin
meta["z_max_m"] = zmax
meta["water"] = {"river_width_m": RIVER_W, "lake_level_asl": lake_level}
(D / "meta.json").write_text(json.dumps(meta, indent=2))

step = 4
wj = {
    "z_min_m": zmin,
    "river": {"width_m": RIVER_W, "points": [[float(line[i, 0] - N / 2), float(line[i, 1] - N / 2), float(level[i])] for i in range(0, len(line), step)]},
    "lake": {"cx": LCX - N / 2, "cz": LCY - N / 2, "rx": LRX, "rz": LRY, "angle_rad": float(LANG), "level": float(lake_level)},
}
(D / "water.json").write_text(json.dumps(wj))
print("WATER_OK river_px", int(river_mask.sum()), "lake_px", int(lake_mask.sum()), "lake_level", round(lake_level, 2), "zmin", zmin,
      "river level start/end", round(float(level[0]), 1), round(float(level[-1]), 1))
