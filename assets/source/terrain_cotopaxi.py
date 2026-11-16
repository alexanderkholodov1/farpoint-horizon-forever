"""The real relief around Cotopaxi for the launch site (issue #12): a heightmap the game turns into terrain.

Run:  python assets/source/terrain_cotopaxi.py  [download folder, default ./build/terrain_src]
Needs Pillow and numpy. Writes assets/textures/terrain_cotopaxi.png (256 x 256, height in metres coded as R * 256 + G).

Source [S-terrain-tiles]: the Terrain Tiles of the AWS Open Data registry (Mapzen/Tilezen "terrarium" encoding),
which in the Andes are NASA SRTM elevation. Sixteen tiles of zoom 11 (4 x 4, about 78 km a side) centred on Cotopaxi
(0.684 S, 78.438 W), cropped to 49 km around the game's launch pad and resampled to 191 m per sample.

What is ours: the launch pad's place (a fictional pad on the high plain 15 km south-west of the summit, near where the
Limpiopungo plain meets the Latacunga valley). The game levels a small disc for the pad; everything else is the data.
"""
import os
import sys
import urllib.request

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(ROOT, "build", "terrain_src")
OUT = os.path.join(ROOT, "assets", "textures", "terrain_cotopaxi.png")
URL = "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/11/{x}/{y}.png"
XS, YS = range(576, 580), range(1026, 1030)
CROP = (40, 200, 680, 840)   # pixels of the 1024 x 1024 mosaic: x0, y0, x1, y1 (the pad is at 330, 640 of the mosaic)
N = 256


def main():
    os.makedirs(SRC, exist_ok=True)
    rows = []
    for y in YS:
        row = []
        for x in XS:
            path = os.path.join(SRC, "t_11_%d_%d.png" % (x, y))
            if not os.path.exists(path):
                urllib.request.urlretrieve(URL.format(x=x, y=y), path)
            a = np.asarray(Image.open(path).convert("RGB"), dtype=np.float64)
            row.append(a[..., 0] * 256 + a[..., 1] + a[..., 2] / 256 - 32768)
        rows.append(np.hstack(row))
    h = np.vstack(rows)
    x0, y0, x1, y1 = CROP
    h = h[y0:y1, x0:x1]
    h = np.asarray(Image.fromarray(h.astype(np.float32), mode="F").resize((N, N), Image.BILINEAR))
    print("crop", h.shape, "min %.0f max %.0f m" % (h.min(), h.max()))
    v = np.clip(np.round(h), 0, 65535).astype(np.uint16)
    rgb = np.stack([(v >> 8).astype(np.uint8), (v & 255).astype(np.uint8), np.zeros_like(v, dtype=np.uint8)], axis=2)
    Image.fromarray(rgb, "RGB").save(OUT, optimize=True)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")


if __name__ == "__main__":
    main()
