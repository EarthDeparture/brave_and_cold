# Original winter cloud fields

Run `generate_cloud_fields.py` with Python, NumPy, SciPy and Pillow. It writes the packed 1024 x 1024 RGB field used by the winter sky and ice surface. The script locates the project from its own path.

Seed 1337 and cubic `grid-wrap` interpolation make periodic fields without a cropped interpolation seam. R carries coarse cloud density, G detail, and B warp. The PNG is data, not a colour image; shader samplers omit `source_color`. No external or generated-provider art is used.

The provenance receipt beside the PNG records its SHA256. Repeated generation on the project runtime produced identical bytes. Import settings preserve lossless data; the shaders use explicit LOD 0.

Local production and validation were used because the optional game-dev CLI is unavailable. This is an ordinary project asset receipt, not a sealed CLI asset package.
