"""Extract a 1 m real-lidar window and export a stylized heightmap + masks for Terrain3D.

Usage:
  uv run python extract_window.py --project ID --easting E --northing N --name valley_a [--size 2048] [--smooth 1.5]
(easting/northing = top-left corner in the dataset CRS, as printed by scan_windows.py)

Outputs out/<name>/: height.r16 (uint16 little-endian, range in meta.json), height_raw.tif (float32, georeferenced),
canopy.png (8-bit, metres/40), slope.png (8-bit, deg/90), hillshade.png, meta.json.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import rasterio
from rasterio.windows import from_bounds
from scipy import ndimage

from bnc_terrain import dem


def read_1m(item: str, kind: str, left: float, bottom: float, right: float, top: float) -> np.ndarray:
    with dem.gdal_env(), rasterio.open(dem.dem_url(item, kind)) as src:
        win = from_bounds(left, bottom, right, top, transform=src.transform)
        arr = src.read(1, window=win, boundless=True, masked=True)
        return arr.filled(np.nan).astype("float32"), src.crs, src.window_transform(win)


def fill_nodata(z: np.ndarray) -> tuple[np.ndarray, float]:
    bad = np.isnan(z)
    frac = float(bad.mean())
    if frac == 0:
        return z, 0.0
    idx = ndimage.distance_transform_edt(bad, return_distances=False, return_indices=True)
    return z[tuple(idx)], frac


def save_png8(path: Path, a: np.ndarray, lo: float, hi: float) -> None:
    v = np.clip((a - lo) / (hi - lo), 0, 1)
    plt.imsave(path, (v * 255).astype("uint8"), cmap="gray", vmin=0, vmax=255)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", required=True)
    ap.add_argument("--easting", type=float, required=True)
    ap.add_argument("--northing", type=float, required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--size", type=int, default=2048)
    ap.add_argument("--smooth", type=float, default=1.5, help="gaussian sigma (m) for micro-roughness removal")
    a = ap.parse_args()
    out = Path("out") / a.name
    out.mkdir(parents=True, exist_ok=True)

    l, t = a.easting, a.northing
    r, b = l + a.size, t - a.size
    print("reading DTM 1 m ...")
    dtm, crs, tr = read_1m(a.project, "dtm", l, b, r, t)
    print("reading DSM 1 m ...")
    dsm, _, _ = read_1m(a.project, "dsm", l, b, r, t)
    dtm = dtm[: a.size, : a.size]
    dsm = dsm[: a.size, : a.size]
    dtm, nod = fill_nodata(dtm)
    dsm, _ = fill_nodata(dsm)
    print(f"  shape {dtm.shape}, nodata filled {nod:.2%}, z {dtm.min():.1f}..{dtm.max():.1f} m")

    canopy = np.clip(dsm - dtm, 0, 60)
    z = ndimage.gaussian_filter(dtm, a.smooth) if a.smooth > 0 else dtm
    sl = dem.slope_deg(z, 1.0)
    walk = float((sl < 30).mean())
    print(f"  after smooth {a.smooth} m: walkable(<30deg) {walk:.1%}, steep(>45deg) {(sl > 45).mean():.1%}")

    zmin, zmax = float(z.min()), float(z.max())
    u16 = np.round((z - zmin) / (zmax - zmin) * 65535).astype("<u2")
    u16.tofile(out / "height.r16")
    with rasterio.open(out / "height_raw.tif", "w", driver="GTiff", height=dtm.shape[0], width=dtm.shape[1], count=1,
                       dtype="float32", crs=crs, transform=tr, compress="deflate") as dst:
        dst.write(z.astype("float32"), 1)
    save_png8(out / "canopy.png", canopy, 0, 40)
    save_png8(out / "slope.png", sl, 0, 90)
    hs = dem.hillshade(z, 1.0, exag=1.2)
    plt.imsave(out / "hillshade.png", hs, cmap="gray", vmin=0, vmax=1)
    meta = {
        "project": a.project, "easting_topleft": l, "northing_topleft": t, "size_m": a.size, "res_m": 1.0,
        "crs": str(crs), "z_min_m": zmin, "z_max_m": zmax, "smooth_sigma_m": a.smooth,
        "nodata_filled_frac": nod, "walkable_lt30": walk,
        "attribution": "Contains information licensed under the Open Government Licence - Canada (NRCan HRDEM).",
        "r16_note": "height_m = z_min + raw/65535 * (z_max - z_min); import in Terrain3D with that range",
    }
    (out / "meta.json").write_text(json.dumps(meta, indent=2))
    print("wrote", out)


if __name__ == "__main__":
    main()
