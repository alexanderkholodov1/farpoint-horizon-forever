#!/usr/bin/env python3
"""The landing terrain of the Moon south pole mission, cut from NASA's LOLA elevation map [S-lola].

Run from the repository root (needs only Python 3.9+ and internet, about 10 MB of download):

    python tools/content/data/fetch_lola_terrain.py

What it does, step by step:
1. Reads the label of LDEM_875S_20M, the Lunar Orbiter Laser Altimeter (LOLA) elevation map of the area within 2.5
   degrees of the south pole, 20 m per pixel, in a polar stereographic projection centred on the pole, from NASA's
   Planetary Data System (Geosciences Node). The label gives the size of the grid and how to turn a number into metres.
2. Downloads only the 600 rows it needs (an HTTP range request; the whole file is 115 MB).
3. Cuts a 12 km square that holds the geographic south pole, the sunlit rim of Shackleton crater and part of the
   crater's permanently shadowed inside, and averages every 3 x 3 pixels into one, so the game gets 200 x 200 heights
   60 m apart.
4. Writes data/nasa/lola_south_pole.json (heights in whole metres above the 1737.4 km reference sphere, row by row)
   and adds its entry to data/nasa/manifest.json.

Orientation of the grid (from the product's map projection, checked against Shackleton's centre at 89.67 S 129.78 E):
x = rho sin(lon), y = rho cos(lon), sample = x / 20 m + 3791.5, line = 3791.5 - y / 20 m. So row 0 of the output lies
toward longitude 0, the side the Earth hangs above when seen from the pole.
"""

import json
import os
import re
import struct
import sys
import urllib.request
from datetime import date

BASE = "https://pds-geosciences.wustl.edu/lro/lro-l-lola-3-rdr-v1/lrolol_1xxx/data/lola_gdr/polar/img/"
PRODUCT = "ldem_875s_20m"
CENTER_LINE = 3892      # 0-based line and sample of the crop centre: about 2.8 km from the pole, toward Shackleton
CENTER_SAMPLE = 3892
CROP_PX = 600           # 12 km at 20 m per pixel
FACTOR = 3              # 3 x 3 pixels averaged into one: 60 m between heights
OUT = "data/nasa/lola_south_pole.json"
MANIFEST = "data/nasa/manifest.json"
UA = {"User-Agent": "farpoint-horizon-data-pipeline"}


def fetch(url, byte_range=None):
    headers = dict(UA)
    if byte_range:
        headers["Range"] = "bytes=%d-%d" % byte_range
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=600) as r:
        return r.read()


def label_value(text, key):
    m = re.search(r"^\s*%s\s*=\s*([-\d.]+)" % key, text, re.M)
    if not m:
        sys.exit("label has no " + key)
    return float(m.group(1))


def main():
    label = fetch(BASE + PRODUCT + ".lbl").decode("latin-1")
    lines = int(label_value(label, "LINES"))
    samples = int(label_value(label, "LINE_SAMPLES"))
    scale = label_value(label, "SCALING_FACTOR")
    map_scale = label_value(label, "MAP_SCALE")
    offset = label_value(label, "LINE_PROJECTION_OFFSET")
    record = samples * 2
    r0 = CENTER_LINE - CROP_PX // 2
    c0 = CENTER_SAMPLE - CROP_PX // 2
    raw = fetch(BASE + PRODUCT + ".img", (r0 * record, (r0 + CROP_PX) * record - 1))
    if len(raw) != CROP_PX * record:
        sys.exit("expected %d bytes, got %d" % (CROP_PX * record, len(raw)))
    print("downloaded %d rows of %d (%d bytes)" % (CROP_PX, lines, len(raw)))
    n = CROP_PX // FACTOR
    heights = []
    for i in range(n):
        row = []
        for j in range(n):
            s = 0
            for di in range(FACTOR):
                base = (i * FACTOR + di) * record + (c0 + j * FACTOR) * 2
                s += sum(struct.unpack_from("<%dh" % FACTOR, raw, base))
            row.append(round(s * scale / (FACTOR * FACTOR)))
        heights.append(row)
    # where the pole falls in the output grid (cell centres at 3 i + 1 of the crop)
    pole_row = ((offset - r0) - (FACTOR - 1) / 2) / FACTOR
    pole_col = ((offset - c0) - (FACTOR - 1) / 2) / FACTOR
    flat = [h for row in heights for h in row]
    out = {
        "meta": {
            "source_id": "S-lola",
            "product": PRODUCT.upper() + " (LRO-L-LOLA-4-GDR-V1.0, version 2.0, 2017)",
            "url": BASE + PRODUCT + ".img",
            "date_checked": date.today().isoformat(),
            "what": "Heights of the Moon's surface around the south pole and the rim of Shackleton crater, measured by the Lunar Orbiter Laser Altimeter on NASA's Lunar Reconnaissance Orbiter",
            "units": "metres above the 1737.4 km reference sphere, whole metres",
            "rows": n,
            "cols": n,
            "spacing_m": map_scale * FACTOR,
            "crop": "lines %d-%d, samples %d-%d of the 7584 x 7584 product, 3 x 3 pixels averaged" % (r0, r0 + CROP_PX - 1, c0, c0 + CROP_PX - 1),
            "pole_row": round(pole_row, 2),
            "pole_col": round(pole_col, 2),
            "orientation": "row 0 lies toward longitude 0 (the Earth's side seen from the pole); columns grow toward longitude 90 E",
            "min_m": min(flat),
            "max_m": max(flat),
        },
        "heights": heights,
    }
    text = json.dumps(out, separators=(",", ":"))
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote %s (%d bytes), heights %d to %d m" % (OUT, len(text), min(flat), max(flat)))
    with open(MANIFEST, encoding="utf-8") as f:
        manifest = json.load(f)
    manifest = [e for e in manifest if e.get("file") != OUT]
    manifest.append({
        "file": OUT,
        "mission": "moon_south_pole",
        "source_id": "S-lola",
        "query": BASE + PRODUCT + ".img (HTTP range of lines %d-%d); label %s.lbl" % (r0, r0 + CROP_PX - 1, BASE + PRODUCT),
        "date_checked": date.today().isoformat(),
        "processing": "12 km square around the south pole and the rim of Shackleton cut from the 20 m LOLA polar map, 3 x 3 pixels averaged to 60 m, numbers turned into metres with the label's scaling factor (0.5) and rounded to whole metres",
        "bytes": len(text),
    })
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(manifest, indent=1))


if __name__ == "__main__":
    if not os.path.isdir("data/nasa"):
        sys.exit("run from the repository root")
    main()
