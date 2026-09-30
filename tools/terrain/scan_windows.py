"""Scan a real-lidar region for 2x2 km windows that suit the Brave and Cold map.

Usage: uv run python scan_windows.py --project <STAC item id> --bbox W S E N [--stride 250] [--top 8]
"""
from __future__ import annotations

import argparse
import csv
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from bnc_terrain import dem

WIN_M = 2000.0


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", required=True)
    ap.add_argument("--bbox", nargs=4, type=float, required=True, metavar=("W", "S", "E", "N"))
    ap.add_argument("--res", type=float, default=16.0)
    ap.add_argument("--stride", type=float, default=250.0)
    ap.add_argument("--top", type=int, default=8)
    ap.add_argument("--out", default="out")
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(exist_ok=True)

    print("reading coarse DTM ...")
    c = dem.read_coarse(a.project, tuple(a.bbox), a.res)
    print(f"  {c.data.shape} px @ {c.res} m, crs {c.crs}, nodata {np.isnan(c.data).mean():.1%}")
    np.save(out / "coarse.npy", c.data)

    n = int(WIN_M / c.res)
    step = max(1, int(a.stride / c.res))
    rows = []
    for y in range(0, c.data.shape[0] - n + 1, step):
        for x in range(0, c.data.shape[1] - n + 1, step):
            m = dem.window_metrics(c.data[y : y + n, x : x + n], c.res)
            m.update(x=x, y=y, easting=c.origin_x + x * c.res, northing=c.origin_y - y * c.res, score=dem.score(m))
            rows.append(m)
    rows.sort(key=lambda r: r["score"], reverse=True)
    keys = sorted({k for r in rows for k in r})
    with open(out / "scan.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        w.writerows(rows)
    print(f"  {len(rows)} windows scored; wrote {out/'scan.csv'}")

    # pick top windows that do not overlap much
    picks = []
    for r in rows:
        if r["score"] <= 0:
            break
        if all(abs(r["x"] - p["x"]) >= n * 0.6 or abs(r["y"] - p["y"]) >= n * 0.6 for p in picks):
            picks.append(r)
        if len(picks) >= a.top:
            break
    cols = 4
    rws = int(np.ceil(len(picks) / cols)) or 1
    fig, axes = plt.subplots(rws, cols, figsize=(4.2 * cols, 4.4 * rws), squeeze=False)
    for ax in axes.ravel():
        ax.axis("off")
    for ax, r in zip(axes.ravel(), picks):
        win = c.data[r["y"] : r["y"] + n, r["x"] : r["x"] + n]
        hs = dem.hillshade(win, c.res)
        ax.imshow(hs, cmap="gray", vmin=0, vmax=1)
        ax.imshow(np.nan_to_num(win, nan=np.nanmin(win)), cmap="terrain", alpha=0.35)
        ax.set_title(
            f"score {r['score']}  relief {r['relief_m']:.0f} m\n"
            f"walk {r['walkable']:.0%}  bench {r['bench_low_km2']:.2f} km2\n"
            f"E{r['easting']:.0f} N{r['northing']:.0f}",
            fontsize=8,
        )
    fig.tight_layout()
    fig.savefig(out / "contact_sheet.png", dpi=110)
    print(f"  wrote {out/'contact_sheet.png'}")
    for i, r in enumerate(picks, 1):
        print(f"  #{i}: score {r['score']} relief {r['relief_m']:.0f} walk {r['walkable']:.0%} bench {r['bench_low_km2']:.2f} km2 "
              f"E{r['easting']:.0f} N{r['northing']:.0f}")


if __name__ == "__main__":
    main()
