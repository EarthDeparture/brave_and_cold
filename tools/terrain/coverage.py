"""Render lidar coverage + shaded relief for HRDEM projects over a bbox (coarse), to see where real data exists.

Usage: uv run python coverage.py --bbox W S E N --res 120 --projects ID1 ID2 ...
"""
from __future__ import annotations

import argparse
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from bnc_terrain import dem


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--bbox", nargs=4, type=float, required=True)
    ap.add_argument("--res", type=float, default=120.0)
    ap.add_argument("--projects", nargs="+", required=True)
    ap.add_argument("--out", default="out")
    a = ap.parse_args()
    Path(a.out).mkdir(exist_ok=True)
    fig, axes = plt.subplots(1, len(a.projects), figsize=(6 * len(a.projects), 6), squeeze=False)
    for ax, p in zip(axes[0], a.projects):
        try:
            c = dem.read_coarse(p, tuple(a.bbox), a.res)
        except Exception as e:  # noqa: BLE001
            ax.set_title(f"{p[:38]}\nERR {type(e).__name__}", fontsize=7)
            ax.axis("off")
            continue
        valid = ~np.isnan(c.data)
        print(f"{p}: shape {c.data.shape} valid {valid.mean():.1%} zmin {np.nanmin(c.data) if valid.any() else None} zmax {np.nanmax(c.data) if valid.any() else None}")
        if valid.any():
            hs = dem.hillshade(c.data, c.res, exag=2.0)
            ax.imshow(np.where(valid, hs, np.nan), cmap="gray", vmin=0, vmax=1)
            ax.imshow(np.where(valid, c.data, np.nan), cmap="terrain", alpha=0.35)
        ax.set_facecolor("#301030")
        ax.set_title(f"{p[:38]}\nvalid {valid.mean():.0%}", fontsize=7)
        ax.axis("off")
    fig.tight_layout()
    fig.savefig(Path(a.out) / "coverage.png", dpi=90)
    print("wrote out/coverage.png")


if __name__ == "__main__":
    main()
