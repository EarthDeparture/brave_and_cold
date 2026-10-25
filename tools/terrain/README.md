# tools/terrain

Pipeline from real lidar DEM to a playable, stylized Terrain3D map. Design: docs/design/MAP_GENERATION_DECISION.md.

Setup (Windows, PowerShell): `cd tools/terrain; uv sync`
Scan candidate 2x2 km windows: `uv run python scan_windows.py --project QC-600018_27_RisquesNaturels_Gaspesie_A_MTM6_2019-1m --bbox -66.6 48.85 -66.0 49.15`
Outputs in out/ (gitignored): scan.csv, hillshade PNGs, contact sheet.

Data: NRCan HRDEM lidar (Open Government Licence - Canada 2.0; credit NRCan in game credits). Raw data is never committed; record STAC item ids in configs.
