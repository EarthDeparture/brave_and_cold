"""Original printed faces for the shift-work props (azimuth ring, instrument dials).
Run with the terrain venv python (PIL):  tools/terrain/.venv/Scripts/python.exe tools/blender/gen_shift_textures.py
"""
from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageFont
OUT = Path(__file__).parent / 'generated/shift_props/textures'
OUT.mkdir(parents=True, exist_ok=True)
PAPER = (214, 204, 172); INK = (34, 34, 30); RED = (150, 38, 30)
def font(px):
    for name in ['arialbd.ttf', 'DejaVuSans-Bold.ttf', 'arial.ttf']:
        try: return ImageFont.truetype(name, px)
        except OSError: pass
    return ImageFont.load_default()

# Azimuth ring: 0-360 deg, clockwise, north (0) at the top of the texture (= -Z in Godot).
N = 1024; img = Image.new('RGB', (N, N), (60, 64, 58)); d = ImageDraw.Draw(img); c = N / 2
d.ellipse((8, 8, N - 8, N - 8), fill=PAPER, outline=INK, width=6)
d.ellipse((c - 300, c - 300, c + 300, c + 300), fill=(196, 188, 160), outline=INK, width=4)
for deg in range(360):
    a = math.radians(deg); r0 = 500 - (60 if deg % 10 == 0 else (38 if deg % 5 == 0 else 22)); r1 = 500
    d.line((c + math.sin(a) * r0, c - math.cos(a) * r0, c + math.sin(a) * r1, c - math.cos(a) * r1), fill=RED if deg % 90 == 0 else INK, width=5 if deg % 10 == 0 else 3)
f = font(40)
for deg in range(0, 360, 30):
    a = math.radians(deg); r = 395
    t = str(deg); w = d.textlength(t, font=f)
    d.text((c + math.sin(a) * r - w / 2, c - math.cos(a) * r - 22), t, fill=RED if deg % 90 == 0 else INK, font=f)
# Simple contour-map impression in the centre plate (original, not a real map).
for k in range(7):
    rr = 60 + k * 32
    pts = [(c + math.sin(t / 40 * math.tau) * rr * (1 + .12 * math.sin(t / 40 * math.tau * 3 + k)), c - math.cos(t / 40 * math.tau) * rr * (1 + .1 * math.cos(t / 40 * math.tau * 2 + k))) for t in range(41)]
    d.line(pts, fill=(120, 112, 88), width=3)
d.ellipse((c - 14, c - 14, c + 14, c + 14), fill=INK)
img.save(OUT / 'azimuth.png')

# Thermometer / wind dial plate for the instrument screen door.
img = Image.new('RGB', (512, 256), PAPER); d = ImageDraw.Draw(img)
d.rectangle((4, 4, 507, 251), outline=INK, width=6)
f2 = font(30); f3 = font(22)
d.text((24, 18), 'KESTREL 07  WEATHER', fill=INK, font=f2)
for i, v in enumerate(range(-40, 21, 10)):
    x = 40 + i * 66; d.line((x, 120, x, 150), fill=INK, width=4); d.text((x - 18, 158), str(v), fill=INK, font=f3)
d.line((40, 135, 436, 135), fill=INK, width=3); d.rectangle((40, 128, 250, 142), fill=RED)
d.text((24, 200), 'READ 07-11 / 15-19  LOG AT DESK', fill=INK, font=f3)
img.save(OUT / 'weather_plate.png')
print('SHIFT_TEXTURES 2')
