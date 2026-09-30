"""Coarse DEM reading and window metrics for candidate scanning."""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import rasterio
from rasterio.enums import Resampling
from rasterio.warp import transform_bounds
from rasterio.windows import from_bounds
from scipy import ndimage

S3 = "https://canelevation-dem.s3.ca-central-1.amazonaws.com/hrdem-lidar/{item}-{kind}.tif"


def dem_url(item: str, kind: str = "dtm") -> str:
    return S3.format(item=item, kind=kind)


def gdal_env() -> rasterio.Env:
    return rasterio.Env(
        GDAL_DISABLE_READDIR_ON_OPEN="EMPTY_DIR",
        CPL_VSIL_CURL_ALLOWED_EXTENSIONS=".tif",
        GDAL_HTTP_MAX_RETRY="4",
        GDAL_HTTP_RETRY_DELAY="1",
    )


@dataclass
class Coarse:
    data: np.ndarray  # metres, NaN = nodata
    res: float  # metres per pixel
    origin_x: float  # dataset CRS coordinates of the top-left corner
    origin_y: float
    crs: str


def read_coarse(item: str, bbox_lonlat: tuple[float, float, float, float], res: float = 16.0) -> Coarse:
    """Read the DTM for a lon/lat bbox decimated to ~res metres per pixel (uses COG overviews)."""
    with gdal_env(), rasterio.open(dem_url(item)) as src:
        left, bottom, right, top = transform_bounds("EPSG:4326", src.crs, *bbox_lonlat)
        win = from_bounds(left, bottom, right, top, transform=src.transform)
        win = win.intersection(rasterio.windows.Window(0, 0, src.width, src.height))
        px = abs(src.transform.a)
        scale = res / px
        out_h = max(1, int(win.height / scale))
        out_w = max(1, int(win.width / scale))
        arr = src.read(1, window=win, out_shape=(out_h, out_w), resampling=Resampling.average, masked=True)
        data = arr.filled(np.nan).astype("float32")
        t = src.window_transform(win)
        return Coarse(data, res, t.c, t.f, str(src.crs))


def slope_deg(z: np.ndarray, res: float) -> np.ndarray:
    gy, gx = np.gradient(z, res)
    return np.degrees(np.arctan(np.hypot(gx, gy)))


def hillshade(z: np.ndarray, res: float, azimuth: float = 315.0, altitude: float = 40.0, exag: float = 1.5) -> np.ndarray:
    zz = np.nan_to_num(z, nan=float(np.nanmin(z)))
    gy, gx = np.gradient(zz * exag, res)
    slope = np.arctan(np.hypot(gx, gy))
    aspect = np.arctan2(-gx, gy)
    az = np.radians(360.0 - azimuth + 90.0)
    alt = np.radians(altitude)
    hs = np.sin(alt) * np.cos(slope) + np.cos(alt) * np.sin(slope) * np.cos(az - aspect)
    return np.clip(hs, 0, 1)


def window_metrics(win: np.ndarray, res: float) -> dict:
    n = win.size
    nod = float(np.isnan(win).sum()) / n
    if nod > 0.02:
        return {"nodata": nod}
    z = np.where(np.isnan(win), np.nanmedian(win), win)
    sl = slope_deg(z, res)
    relief = float(np.percentile(z, 99) - np.percentile(z, 1))
    walk = float((sl < 30).mean())
    steep = float((sl > 45).mean())
    sea = z < 3.0  # sea / tidal flat / river mouths: not buildable ground
    flat_mask = (sl < 4.0) & ~sea
    lab, k = ndimage.label(flat_mask)
    largest = float(np.bincount(lab.ravel())[1:].max()) if k else 0.0
    bench_km2 = largest * res * res / 1e6
    lo = z < np.percentile(z, 40)
    lab2, k2 = ndimage.label(flat_mask & lo)
    bench_low_km2 = (float(np.bincount(lab2.ravel())[1:].max()) * res * res / 1e6) if k2 else 0.0
    return {
        "nodata": nod,
        "relief_m": relief,
        "zmin": float(z.min()),
        "zmax": float(z.max()),
        "walkable": walk,
        "steep45": steep,
        "bench_km2": bench_km2,
        "bench_low_km2": bench_low_km2,
        "sea": float(sea.mean()),
    }


def tri(x: float, lo: float, ideal_lo: float, ideal_hi: float, hi: float) -> float:
    """Trapezoid membership 0..1."""
    if x <= lo or x >= hi:
        return 0.0
    if ideal_lo <= x <= ideal_hi:
        return 1.0
    if x < ideal_lo:
        return (x - lo) / (ideal_lo - lo)
    return (hi - x) / (hi - ideal_hi)


def score(m: dict) -> float:
    if "relief_m" not in m:
        return 0.0
    relief = tri(m["relief_m"], 120, 280, 460, 700)
    walk = tri(m["walkable"], 0.35, 0.60, 0.90, 1.01)
    steep = 1.0 - min(1.0, m["steep45"] / 0.12)
    bench = min(1.0, m["bench_low_km2"] / 0.30)
    sea_pen = 1.0 - min(1.0, max(0.0, m["sea"] - 0.10) / 0.25)
    return round(100 * sea_pen * (0.30 * relief + 0.25 * walk + 0.15 * steep + 0.30 * bench), 1)
