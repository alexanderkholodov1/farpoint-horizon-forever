#!/usr/bin/env python3
"""Farpoint HORIZON NASA data pipeline: download, process, write game files plus a manifest.

Usage:  python tools/content/data/fetch_nasa_data.py [photos|numbers|all]
Needs Python 3.9+ and Pillow (pip install pillow). Everything else is the standard library.
Outputs: assets/photos/<mission_id>/*.jpg, data/nasa/*.json, data/nasa/manifest.json.
See tools/content/data/README.md for what each step does. Source IDs refer to docs/sources.md.
"""
import io, json, math, re, sys, time, datetime, urllib.request, urllib.parse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[3]
PHOTOS = ROOT / "assets" / "photos"
NUMBERS = ROOT / "data" / "nasa"
CHECKED = datetime.date.today().isoformat()
MAXSIDE = 1024
manifest = []


def http(url, tries=4):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "FarpointHorizon-data-pipeline/1.0 (student game project)"})
            return urllib.request.urlopen(req, timeout=90).read()
        except Exception:
            if i == tries - 1:
                raise
            time.sleep(2 * (i + 1))


def save_jpeg(img, path, source, query, note, mission=None, quality=85):
    img = img.convert("RGB")
    if max(img.size) > MAXSIDE:
        s = MAXSIDE / max(img.size)
        img = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "JPEG", quality=quality, optimize=True)
    manifest.append({"file": str(path.relative_to(ROOT)).replace("\\", "/"), "mission": mission, "source_id": source,
                     "query": query, "date_checked": CHECKED, "processing": note, "bytes": path.stat().st_size})
    print("wrote", path.relative_to(ROOT), path.stat().st_size, "bytes")


# ------------------------------------------------ 1. Volcano watch (Landsat 8, ASTER, EO-1 pictures published by NASA)
EO = "https://assets.science.nasa.gov/content/dam/science/esd/eo/images/imagerecords/"
IMG = "https://images-assets.nasa.gov/image/"
Image.MAX_IMAGE_PIXELS = None  # the Landsat scene is 6009 x 4751 pixels; it comes from NASA, so it is safe
# (file name, url, crop box in source pixels or None, source id, what it is, credit line printed by the publisher)
VOLCANO_PHOTOS = [
    ("sangay_landsat8_2022-11-05_truecolor.jpg", EO + "150000/150650/sangay_oli_2022309_lrg.jpg", (2300, 1950, 4500, 3250),
     "S-eo", "Sangay ash plume, Landsat 8 OLI natural colour, 5 Nov 2022 (30 m pixels), page: https://science.nasa.gov/earth/earth-observatory/a-line-of-ash-from-sangay-150650/",
     "NASA Earth Observatory images by Lauren Dauphin, using Landsat data from the U.S. Geological Survey"),
    ("cotopaxi_landsat8_2015-09-15_truecolor.jpg", EO + "86000/86618/cotopaxi_oli_2015258_lrg.jpg", (1600, 1600, 4000, 4000),
     "S-eo", "Cotopaxi after its first eruption in 70 years, Landsat 8 OLI natural colour, 15 Sep 2015, page: https://science.nasa.gov/earth/earth-observatory/cotopaxi-volcano-ecuador-86618/",
     "NASA Earth Observatory image by Jesse Allen, using Landsat data from the U.S. Geological Survey"),
    ("tungurahua_eo1_2011-01-01_truecolor.jpg", EO + "48000/48337/tungurahua_ali_2011001_lrg.jpg", (215, 1100, 1215, 2100),
     "S-eo", "Tungurahua summit plume, EO-1 ALI natural colour, 1 Jan 2011 (30 m), page: https://science.nasa.gov/earth/earth-observatory/ongoing-eruption-of-tungurahua-ecuador-48337/",
     "NASA Earth Observatory image created by Jesse Allen, using EO-1 ALI data provided courtesy of the NASA EO-1 team and the U.S. Geological Survey"),
    ("tungurahua_eo1_2011-01-01_swir.jpg", EO + "48000/48337/tungurahua_ali_2011001_swir_lrg.jpg", (215, 1100, 1215, 2100),
     "S-eo", "Tungurahua, EO-1 ALI short-wave infrared false colour: the hot crater glows red, 1 Jan 2011 (30 m); same page as above",
     "NASA Earth Observatory image created by Jesse Allen, using EO-1 ALI data provided courtesy of the NASA EO-1 team and the U.S. Geological Survey"),
    ("sangay_aster_2020-06-11_thermal.jpg", IMG + "PIA23914/PIA23914~orig.jpg", None,
     "S-nasa-images", "Sangay night thermal infrared (ASTER on Terra), 11 Jun 2020: lava flows white, ash plume dark red-brown; library record PIA23914",
     "NASA/METI/AIST/Japan Space Systems, and U.S./Japan ASTER Science Team"),
    ("cotopaxi_aster_2015-08-22_falsecolor.jpg", IMG + "PIA15151/PIA15151~orig.jpg", None,
     "S-nasa-images", "Cotopaxi ash columns, ASTER on Terra false colour, 22 Aug 2015 (15 m); library record PIA15151",
     "NASA/GSFC/METI/ERSDAC/JAROS, and U.S./Japan ASTER Science Team"),
]


def photo(mission, name, url, crop, source, desc, credit):
    img = Image.open(io.BytesIO(http(url)))
    note = ("cropped to the volcano" if crop else "no crop") + f", resized to at most {MAXSIDE} px; {desc}; credit: {credit}"
    if crop:
        img = img.crop(crop)
    save_jpeg(img, PHOTOS / mission / name, source, url, note, mission)


def volcanoes():
    for name, url, crop, source, desc, credit in VOLCANO_PHOTOS:
        photo("volcano_watch", name, url, crop, source, desc, credit)


# ------------------------------------------------ 2. Moon south pole (NASA Moon Trek, LROC WAC mosaic)
TREK = "https://trek.nasa.gov/tiles/Moon/EQ/LRO_WAC_Mosaic_Global_303ppd_v02/1.0.0//default/default028mm/{z}/{r}/{c}.jpg"


def moon_polar(zoom, half_deg, name):
    cols, rows_total = 2 ** (zoom + 1), 2 ** zoom
    nrows = max(1, math.ceil(half_deg / (180 / rows_total)))
    rows = list(range(rows_total - nrows, rows_total))
    strip = Image.new("L", (cols * 256, nrows * 256))
    jobs = [(r, c) for r in rows for c in range(cols)]
    with ThreadPoolExecutor(8) as ex:
        tiles = list(ex.map(lambda rc: http(TREK.format(z=zoom, r=rc[0], c=rc[1])), jobs))
    for (r, c), t in zip(jobs, tiles):
        strip.paste(Image.open(io.BytesIO(t)).convert("L"), (c * 256, (r - rows[0]) * 256))
    deg_per_px = 360 / (cols * 256)
    top_lat = -90 + nrows * 180 / rows_total
    size = 1000
    out = Image.new("L", (size, size), 0)
    px, src = out.load(), strip.load()
    c0 = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            dx, dy = x - c0, y - c0
            rr = math.hypot(dx, dy)
            if rr > size / 2:
                continue
            colat = rr / (size / 2) * half_deg           # azimuthal equidistant, south pole at the centre
            lon = math.degrees(math.atan2(dx, -dy))       # 0 deg up, east clockwise (seen from outside, over the pole)
            sx = min(strip.width - 1, int((lon + 180) / deg_per_px))
            sy = min(strip.height - 1, int((top_lat - (-90 + colat)) / deg_per_px))
            px[x, y] = src[sx, sy]
    q = f"{TREK.format(z=zoom, r='{row}', c='{col}')} for row {rows[0]}..{rows[-1]}, column 0..{cols-1}"
    save_jpeg(out, PHOTOS / "moon_south_pole" / name, "S-lroc-wac", q,
              f"tiles joined, re-projected to a view from above the south pole (azimuthal equidistant, {half_deg} deg radius)",
              "moon_south_pole")


SH = "https://assets.science.nasa.gov/content/dam/science/"
MOON_PHOTOS = [
    ("shackleton_rim_lroc.jpg", SH + "psd/lunar-science/2023/08/shackleton-1.png", "S-nasa-science",
     "Shackleton crater rim in sunlight, its floor in permanent shadow; page: https://science.nasa.gov/resource/shackleton-craters-illuminated-rim-shadowed-interior/",
     "NASA/GSFC/Arizona State University"),
    ("shackleton_floor_shadowcam.jpg", SH + "cds/apod/apod/2023/may/shackleton_arrow.png", "S-nasa-science",
     "Inside Shackleton, seen by ShadowCam (NASA instrument on the Korean KPLO orbiter); the arrow marks a boulder track; page: https://science.nasa.gov/image-article/apod-2023-may-5-shackleton-from-shadowcam/",
     "NASA, ShadowCam, Korea Aerospace Research Institute, Arizona State University"),
]


def moon():
    moon_polar(5, 11.0, "south_pole_wide_lroc_wac.jpg")
    for name, url, source, desc, credit in MOON_PHOTOS:
        photo("moon_south_pole", name, url, None, source, desc, credit)


# ------------------------------------------------ 3. Eye on the Universe's card (NASA Image and Video Library, Voyager)
# The Grand Tour mission was dropped (team decision 2026-11-15, issue #10); Neptune stays as the telescope's picture.
VOYAGER = [("PIA00049", "neptune_voyager2_1989.jpg", "Neptune and its Great Dark Spot, Voyager 2, 1989")]


def voyager():
    for pia, fname, desc in VOYAGER:
        meta = json.loads(http("https://images-api.nasa.gov/search?nasa_id=" + pia))["collection"]["items"][0]["data"][0]
        # the library lists which sizes exist for each record; take the biggest of large/medium, else the original
        hrefs = [i["href"].replace("http://", "https://") for i in json.loads(http("https://images-api.nasa.gov/asset/" + pia))["collection"]["items"]]
        url = next(h for suf in ("~large.jpg", "~medium.jpg", "~orig.jpg") for h in hrefs if h.endswith(suf))
        img = Image.open(io.BytesIO(http(url)))
        save_jpeg(img, PHOTOS / "telescope" / fname, "S-nasa-images", url,
                  f"resized to at most {MAXSIDE} px; {desc}; library record {pia}, credit {meta.get('secondary_creator')}", "telescopio")


# ------------------------------------------------ 4. Numbers: JPL Horizons and NSSDC fact sheets
HORIZONS = "https://ssd.jpl.nasa.gov/api/horizons.api"
BODIES = {"mercury": 199, "venus": 299, "earth": 399, "mars": 499, "jupiter": 599, "saturn": 699, "uranus": 799, "neptune": 899}
EPOCH = "2026-11-15"


def horizons(command, center, kind, start, stop, step):
    p = {"format": "json", "COMMAND": f"'{command}'", "OBJ_DATA": "'NO'", "MAKE_EPHEM": "'YES'", "EPHEM_TYPE": f"'{kind}'",
         "CENTER": f"'{center}'", "START_TIME": f"'{start}'", "STOP_TIME": f"'{stop}'", "STEP_SIZE": f"'{step}'",
         "REF_SYSTEM": "'ICRF'", "REF_PLANE": "'ECLIPTIC'", "OUT_UNITS": "'KM-S'", "CSV_FORMAT": "'YES'"}
    url = HORIZONS + "?" + urllib.parse.urlencode(p, safe="',@")
    res = json.loads(http(url))["result"]
    body = res.split("$$SOE")[1].split("$$EOE")[0].strip().splitlines()
    return url, [[v.strip() for v in line.split(",")] for line in body]


WANTED = {"mass_1e24_kg": r"^Mass", "equatorial_radius_km": r"^Equatorial radius", "mean_radius_km": r"^Volumetric mean radius",
          "gravity_m_s2": r"^(Surface g|G)ravity", "escape_velocity_km_s": r"^Escape [Vv]elocity", "gm_1e6_km3_s2": r"^GM",
          "semi_major_axis_1e6_km": r"^Semimajor axis", "sidereal_rotation_h": r"^Sidereal rotation period",
          "length_of_day_h": r"^Length of day"}


def take(store, cells):
    """If cells = [label, value, ...] matches a wanted field, store its first number."""
    if len(cells) < 2:
        return
    for key, pat in WANTED.items():
        if key in store or not re.match(pat, cells[0]):
            continue
        m = re.search(r"-?[\d,]*\.?\d+", cells[1])
        if m:
            store[key] = {"label": cells[0], "value": float(m.group().replace(",", ""))}


def numbers():
    NUMBERS.mkdir(parents=True, exist_ok=True)
    # b) the Moon around the Earth: one lunar month of position vectors, one a day
    murl, rows = horizons(301, "500@399", "VECTORS", "2026-11-15", "2026-12-15", "1d")
    moon = [{"date": r[1].replace("A.D. ", ""), "x_km": float(r[2]), "y_km": float(r[3]), "z_km": float(r[4]),
             "vx_km_s": float(r[5]), "vy_km_s": float(r[6]), "vz_km_s": float(r[7])} for r in rows]
    meta = {"source_id": "S-horizons", "date_checked": CHECKED, "frame": "ICRF axes, ecliptic plane J2000",
            "epoch": EPOCH + " 00:00 TDB", "units": "km, km/s, degrees, seconds"}
    (NUMBERS / "horizons_moon.json").write_text(json.dumps({"meta": {**meta, "centre": "Earth (500@399)", "query": murl}, "moon": moon}, indent=1))
    for f, q in (("horizons_moon.json", murl),):
        manifest.append({"file": f"data/nasa/{f}", "mission": "moon_south_pole", "source_id": "S-horizons", "query": q,
                         "date_checked": CHECKED, "processing": "CSV rows parsed to JSON", "bytes": (NUMBERS / f).stat().st_size})
    # c) NSSDC planetary fact sheets
    facts, furls = {}, {}
    for n in list(BODIES) + ["moon"]:
        url = f"https://nssdc.gsfc.nasa.gov/planetary/factsheet/{n}fact.html"
        html = http(url).decode("latin-1")
        facts[n] = {}
        for tr in re.findall(r"<tr[^>]*>(.*?)</tr>", html, re.S | re.I):
            cells = [re.sub(r"\s+", " ", re.sub(r"<[^>]*>|&nbsp;", " ", c)).strip() for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", tr, re.S | re.I)]
            take(facts[n], cells)
        if not facts[n]:  # the Earth sheet is plain text lines, not a table: "label    value"
            for line in re.sub(r"<[^>]*>|&nbsp;", " ", html).splitlines():
                ch = [c.strip() for c in re.split(r"	|\s{2,}", line.strip())]
                take(facts[n], [ch[0], ch[-1]])
        furls[n] = url
    (NUMBERS / "nssdc_factsheets.json").write_text(json.dumps({"meta": {"source_id": "S-nssdc-planets", "date_checked": CHECKED,
        "note": "values as printed on the fact sheets, each with its row label; the first column after the label is the body itself",
        "urls": furls}, "bodies": facts}, indent=1))
    manifest.append({"file": "data/nasa/nssdc_factsheets.json", "mission": None, "source_id": "S-nssdc-planets",
                     "query": "; ".join(furls.values()), "date_checked": CHECKED, "processing": "HTML table rows parsed to JSON",
                     "bytes": (NUMBERS / "nssdc_factsheets.json").stat().st_size})


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("photos", "all"):
        volcanoes(); moon(); voyager()
    if what in ("numbers", "all"):
        numbers()
    NUMBERS.mkdir(parents=True, exist_ok=True)
    mf = NUMBERS / "manifest.json"
    old = json.loads(mf.read_text()) if mf.exists() else []
    new_files = {x["file"] for x in manifest}
    mf.write_text(json.dumps([m for m in old if m["file"] not in new_files] + manifest, indent=1))
    print("manifest entries:", len(old) + len(manifest))
