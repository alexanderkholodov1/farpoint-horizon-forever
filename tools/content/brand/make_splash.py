"""The loading screen (boot splash) of Farpoint HORIZON: the brand's horizon arc, the name and the team, drawn here so
it is reproducible and nothing in it is AI-made. Writes assets/brand/splash.png (1280 x 720).
Run: python tools/content/brand/make_splash.py"""
import math
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[3]
W, H = 1280, 720
BG = (2, 5, 11)
WARM, PALE, DEEP = (255, 148, 56), (255, 219, 158), (20, 71, 168)
BLUE = (120, 184, 255)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


img = Image.new("RGB", (W, H), BG)
# the arc: the Earth's limb at sunrise, bright in the middle, deep blue at its ends, with a soft glow
glow = Image.new("RGB", (W, H), (0, 0, 0))
g = ImageDraw.Draw(glow)
line = Image.new("RGB", (W, H), (0, 0, 0))
d = ImageDraw.Draw(line)
x0, x1, y_mid, bulge = 250, 1030, 300, 34
pts = []
for i in range(201):
    t = i / 200
    x = x0 + (x1 - x0) * t
    y = y_mid - bulge * math.sin(math.pi * t)
    pts.append((x, y, t))
for (xa, ya, ta), (xb, yb, tb) in zip(pts, pts[1:]):
    k = 1 - abs(ta - 0.5) * 2               # 1 at the middle, 0 at the ends
    col = mix(DEEP, WARM, k ** 1.5)
    if k > 0.85:
        col = mix(col, PALE, (k - 0.85) / 0.15)
    d.line([(xa, ya), (xb, yb)], fill=col, width=3)
    g.line([(xa, ya), (xb, yb)], fill=mix((0, 0, 0), col, 0.9 * k + 0.1), width=16)
glow = glow.filter(ImageFilter.GaussianBlur(14))
img = ImageChops.add(img, glow)
img = ImageChops.lighter(img, line)

fonts = ROOT / "assets" / "fonts"
f_title = ImageFont.truetype(str(fonts / "InterDisplay-Bold.otf"), 76)
f_small = ImageFont.truetype(str(fonts / "Inter-Regular.otf"), 22)
t = ImageDraw.Draw(img)
a, b = "Farpoint ", "HORIZON"
wa = t.textlength(a, font=f_title)
# HORIZON spaced, as on the menu
spacing = 10
wb = sum(t.textlength(c, font=f_title) for c in b) + spacing * (len(b) - 1)
x = (W - wa - wb) / 2
y = 330
t.text((x, y), a, font=f_title, fill=(244, 247, 255))
x += wa
for c in b:
    t.text((x, y), c, font=f_title, fill=BLUE)
    x += t.textlength(c, font=f_title) + spacing
sub = "Design, launch and fly your own space mission"
t.text(((W - t.textlength(sub, font=f_small)) / 2, 440), sub, font=f_small, fill=(170, 184, 208))
foot = "NASA Space Apps Challenge 2026  ·  Team SK-Horizons  ·  Quito, Ecuador"
f_foot = ImageFont.truetype(str(fonts / "Inter-Regular.otf"), 16)
t.text(((W - t.textlength(foot, font=f_foot)) / 2, 650), foot, font=f_foot, fill=(110, 124, 150))
out = ROOT / "assets" / "brand" / "splash.png"
out.parent.mkdir(parents=True, exist_ok=True)
img.save(out)
print("wrote", out)
