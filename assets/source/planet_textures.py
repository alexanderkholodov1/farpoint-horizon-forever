"""Earth and Moon textures from NASA data, downloaded and processed for the game (issue #12).

Run:  python assets/source/planet_textures.py  [download folder, default ./build/planet_src]
Needs Pillow and numpy. Writes assets/textures/earth_day.jpg, earth_night.jpg, earth_clouds.jpg, earth_relief.jpg,
moon_color.jpg and moon_normal.jpg.

Sources (docs/sources.md):
- [S-gibs] NASA GIBS WMS, one request per layer, whole globe in plate carree (EPSG:4326):
  - BlueMarble_NextGeneration (2004-08): the surface by day, no clouds (NASA Earth Observatory, MODIS).
  - BlueMarble_ShadedRelief (2004-08): the same with hill shading; its ratio to the plain map gives the relief.
  - VIIRS_Black_Marble (2016): the lights at night (NASA Earth Observatory, Suomi NPP VIIRS).
  - VIIRS_SNPP_CorrectedReflectance_TrueColor (2024-08-31, the day of the volcano photos): the real clouds of one day.
- [S-moon-kit] NASA SVS CGI Moon Kit (LRO LROC WAC colour, LOLA elevation).

What is ours (a processing choice, not data): clouds are the white, unsaturated pixels of the VIIRS day, so sun glint
on the sea and bright desert are mostly left out; the polar night of that day (no data) is left cloudless. The Moon's
normal map is the gradient of the LOLA elevation, exaggerated so the relief reads at game size.
"""
import os
import sys
import urllib.request

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "textures")
SRC = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(ROOT, "build", "planet_src")

GIBS = ("https://gibs.earthdata.nasa.gov/wms/epsg4326/best/wms.cgi?SERVICE=WMS&REQUEST=GetMap&VERSION=1.1.1"
        "&SRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=4096&HEIGHT=2048&FORMAT=image/jpeg&LAYERS={layer}&TIME={time}")
## The region under the climb from Ecuador, 24 x 24 degrees around the launch site, at about 1.3 km per pixel (eight
## times the whole-globe maps): the globe's shader blends it in so the Earth stays sharp right after the rocket leaves
## the Andes terrain (look, issue #12). Keep REGION_LONLAT in step with REGION_RECT in scripts/world/space_builder.gd.
REGION_LONLAT = (-92.0, -12.0, -44.0, 12.0)
## 48 x 24 degrees, east along the launch track so the Earth stays sharp where the craft separates (~2,000 km downrange),
## 6144 pixels over 48 degrees: about 870 m a pixel, nearly the pixel count of the old 24-degree square (v0.2.2)
REGION = ("https://gibs.earthdata.nasa.gov/wms/epsg4326/best/wms.cgi?SERVICE=WMS&REQUEST=GetMap&VERSION=1.1.1"
          "&SRS=EPSG:4326&BBOX=-92,-12,-44,12&WIDTH=6144&HEIGHT=3072&FORMAT=image/jpeg&LAYERS={layer}&TIME={time}")
FILES = {
    "bm.jpg": GIBS.format(layer="BlueMarble_NextGeneration", time="2004-08-01"),
    "relief.jpg": GIBS.format(layer="BlueMarble_ShadedRelief", time="2004-08-01"),
    "night.jpg": GIBS.format(layer="VIIRS_Black_Marble", time="2016-01-01"),
    "viirs.jpg": GIBS.format(layer="VIIRS_SNPP_CorrectedReflectance_TrueColor", time="2024-08-31"),
    "reg_bm.jpg": REGION.format(layer="BlueMarble_NextGeneration", time="2004-08-01"),
    "reg_relief.jpg": REGION.format(layer="BlueMarble_ShadedRelief", time="2004-08-01"),
    "reg_viirs.jpg": REGION.format(layer="VIIRS_SNPP_CorrectedReflectance_TrueColor", time="2024-08-31"),
    # the Moon at twice the detail (4096 x 2048): the kit's 4k colour map and its 16 pixels per degree elevation
    "moon_4k.tif": "https://svs.gsfc.nasa.gov/vis/a000000/a004700/a004720/lroc_color_poles_4k.tif",
    "ldem_16.tif": "https://svs.gsfc.nasa.gov/vis/a000000/a004700/a004720/ldem_16.tif",
}


def fetch():
    os.makedirs(SRC, exist_ok=True)
    for name, url in FILES.items():
        path = os.path.join(SRC, name)
        if not os.path.exists(path):
            print("download", name)
            urllib.request.urlretrieve(url, path)


def rgb(name):
    return np.asarray(Image.open(os.path.join(SRC, name)).convert("RGB"), dtype=np.float32) / 255.0


def save(arr, name, size=None, quality=88):
    img = Image.fromarray(np.clip(arr * 255.0 + 0.5, 0, 255).astype(np.uint8))
    if size:
        img = img.resize(size, Image.LANCZOS)
    path = os.path.join(OUT, name)
    if name.endswith(".png"):
        img.save(path, optimize=True)
    else:
        img.save(path, quality=quality, optimize=True)
    print("wrote", name, img.size, os.path.getsize(path) // 1024, "KB")


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def earth():
    day = rgb("bm.jpg")
    save(day, "earth_day.jpg", quality=84)
    # relief: shaded / plain, centred on 0.5 (grey = flat)
    shaded = rgb("relief.jpg").mean(axis=2)
    # the relief map is half the day map's size: compare it with the day map brought to its size
    plain = np.asarray(Image.fromarray((day * 255).astype(np.uint8)).resize(shaded.shape[::-1], Image.LANCZOS), dtype=np.float32).mean(axis=2) / 255.0
    rel = np.clip(shaded / np.maximum(plain, 0.03), 0.0, 2.0) * 0.5
    rel = np.where(plain < 0.03, 0.5, rel)
    save(rel, "earth_relief.jpg", size=(2048, 1024), quality=85)
    # lights: keep the bright cities, drop the moonlit ground the Black Marble shows
    n = rgb("night.jpg")
    lum = n.max(axis=2)
    lights = smooth(0.32, 0.9, lum)
    save(lights, "earth_night.jpg", size=(2048, 1024), quality=85)
    # clouds: white and unsaturated in the VIIRS day
    v = rgb("viirs.jpg")
    mn = v.min(axis=2)
    mx = v.max(axis=2)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    a = smooth(0.3, 0.95, mn) ** 1.4 * (1.0 - smooth(0.1, 0.3, sat))
    a = np.where(mx < 0.02, 0.0, a)   # no data (polar night)
    # the day's mosaic jumps at the date line (passes made a day apart meet there); near the edges, fade into the same
    # map turned half a world, which joins without a jump, so the globe shows no seam
    w = a.shape[1]
    edge = np.minimum(np.arange(w), w - 1 - np.arange(w)) / (w * 0.06)
    t = smooth(0.0, 1.0, np.clip(edge, 0.0, 1.0))[None, :]
    a = a * t + np.roll(a, w // 2, axis=1) * (1.0 - t)
    save(a, "earth_clouds.jpg", size=(2048, 1024), quality=85)


def clouds_from(v):
    mn = v.min(axis=2)
    mx = v.max(axis=2)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    a = smooth(0.3, 0.95, mn) ** 1.4 * (1.0 - smooth(0.1, 0.3, sat))
    return np.where(mx < 0.02, 0.0, a)


def region():
    day = rgb("reg_bm.jpg")
    shaded = rgb("reg_relief.jpg").mean(axis=2)
    plain = day.mean(axis=2)
    rel = np.where(plain < 0.03, 0.5, np.clip(shaded / np.maximum(plain, 0.03), 0.0, 2.0) * 0.5)
    save(day, "earth_region_day.jpg", quality=82)
    save(rel, "earth_region_relief.jpg", size=(3072, 1536), quality=85)
    save(clouds_from(rgb("reg_viirs.jpg")), "earth_region_clouds.jpg", size=(3072, 1536), quality=80)


def moon():
    save(rgb("moon_4k.tif"), "moon_color.jpg", quality=86)
    h = np.asarray(Image.open(os.path.join(SRC, "ldem_16.tif")), dtype=np.float32)   # km, 16 px per degree
    # metres per pixel along a parallel shrink with latitude; the radius is 1737.4 km
    rows, cols = h.shape
    lat = (0.5 - (np.arange(rows) + 0.5) / rows) * np.pi
    px_km = 2.0 * np.pi * 1737.4 / cols
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) / (2.0 * px_km * np.maximum(np.cos(lat), 0.05)[:, None])
    dy = (np.roll(h, 1, axis=0) - np.roll(h, -1, axis=0)) / (2.0 * px_km)
    dy[0, :] = dy[-1, :] = 0.0
    k = 6.0   # exaggeration
    nx, ny, nz = -dx * k, -dy * k, np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    nrm = np.stack([nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5], axis=2)
    save(nrm, "moon_normal.jpg", size=(4096, 2048), quality=80)


if __name__ == "__main__":
    fetch()
    earth()
    region()
    moon()
