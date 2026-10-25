"""Derive ice to the physical bank without recarving terrain or moving map props.

The original mask is one pixel wider than its level data; zero values at that
border must never become ice heights. Terrain3D imports two 7-pixel box passes.
Find the connected below-water basin on that same terrain, then overlap the
bank by 3 m so the closed slab edge is buried. Original planning data stays put.
"""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[2]
D = ROOT / 'brave-and-cold/data/maps/valley_b'
meta = json.loads((D / 'water.json').read_text())
n = meta['size_m']
span = meta['z_max_m'] - meta['z_min_m']
mask = np.asarray(Image.open(D / 'water_mask.png').convert('L')) > 127
raw = np.fromfile(D / 'water_level.r16', '<u2').reshape(n, n)
valid = mask & (raw > 0)
_, nearest = ndi.distance_transform_edt(~valid, return_indices=True)
level = raw[tuple(nearest)].astype(np.float64) / 65535 * span
# A small continuous filter also removes nearest-seed ridges at concave banks.
level = ndi.gaussian_filter(level, 1.5, mode='nearest')
height = np.fromfile(D / 'height.r16', '<u2').reshape(n, n) / 65535 * span
height = ndi.uniform_filter(ndi.uniform_filter(height, 7, mode='nearest'), 7, mode='nearest')
wet = height < level + .025
labels, _ = ndi.label(wet)
seeds = np.unique(labels[valid & wet])
basin = np.isin(labels, seeds[seeds > 0])
shore_distance = ndi.distance_transform_edt(~(basin | mask))
# A one-pixel support overlap covers the continuous terrain inside a boundary
# grid cell. Cutting support exactly at pixel centres makes the last metre step.
ice_mask = shore_distance <= 1.0
render_mask = shore_distance <= 3.0
encoded = np.round(level / span * 65535).astype('<u2')
assert np.all(encoded[ice_mask] > 0)
assert np.all(ice_mask[mask]) and np.all(ice_mask[basin])
Image.fromarray((ice_mask * 255).astype('uint8')).save(D / 'ice_mask.png')
Image.fromarray((render_mask * 255).astype('uint8')).save(D / 'ice_render_mask.png')
encoded.tofile(D / 'ice_level.r16')
receipt = {
    'source': 'tools/terrain/repair_ice_surface.py',
    'source_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    'inputs': {f: hashlib.sha256((D / f).read_bytes()).hexdigest()
               for f in ['height.r16', 'water_mask.png', 'water_level.r16', 'water.json']},
    'original_mask_pixels': int(mask.sum()), 'invalid_original_levels': int((mask & ~valid).sum()),
    'connected_basin_pixels': int(basin.sum()), 'ice_mask_pixels': int(ice_mask.sum()),
    'render_mask_pixels': int(render_mask.sum()),
    'bank_overlap_m': 3.0, 'support_overlap_m': 1.0, 'level_smoothing_sigma_m': 1.5,
    'terrain_changed': False,
}
(D / 'ice_surface.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt, indent=2))
