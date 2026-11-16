# NASA data pipeline

One script, `fetch_nasa_data.py`, turns open NASA data into the files the game uses. Run it from the repository root:

    pip install pillow
    python tools/content/data/fetch_nasa_data.py all        # or: photos | numbers

It needs Python 3.9 or newer, the standard library, and Pillow (image cropping and conversion). It needs internet and
takes about a minute. The files it writes are committed, so the game never needs the internet; the script is there so
anyone can check, repeat or update them. Every source ID (`S-...`) is described in `docs/sources.md`.

## What it does, step by step

### 1. Volcano Watch photos (`assets/photos/volcano_watch/`, sources S-eo and S-nasa-images)
The mission's real twin is Landsat 9, so we want pictures of the same kind: 15 to 30 m pixels, natural colour and infrared.
We first tried NASA's GIBS image service (VIIRS, 250 m), but the Ecuadorian Andes were under cloud and the pictures were soft,
so we dropped them. Now:
1. NASA Earth Observatory publishes full-size Landsat 8 and EO-1 scenes of Ecuador's eruptions. The script downloads the
   big files (the Sangay scene is 6009 x 4751 pixels), cuts out the part around the volcano and shrinks it to at
   most 1024 px. Sangay (ash plume, 5 Nov 2022) and Cotopaxi (first eruption in 70 years, 15 Sep 2015) are Landsat 8; Tungurahua
   (1 Jan 2011) is EO-1 ALI, in natural colour and in short-wave infrared, where the hot crater glows red.
2. Two pictures from the ASTER camera on Terra come from the NASA Image and Video Library: Sangay at night in thermal
   infrared (lava flows white, ash plume dark), and Cotopaxi in false colour with its ash columns. These are the
   "special instrument" photos.
3. The credit line each page prints is saved in the manifest next to the file.

### 2. Moon south pole photos (`assets/photos/moon_south_pole/`, sources S-lroc-wac and S-nasa-science)
1. NASA Moon Trek serves the LROC Wide Angle Camera mosaic of the whole Moon as small square tiles on a flat map. Near
   the pole a flat map is stretched sideways, so the tiles are useless as they are.
2. Download the 128 tiles that touch the pole, join them, then redraw the picture as seen from above the pole: for each
   pixel of the new picture we compute its distance and direction from the pole (a polar, "azimuthal equidistant"
   projection) and copy the matching pixel from the flat map. It covers 11 degrees (about 330 km) around the pole. The
   faint straight seams are the edges of the mosaic's own strips.
3. Two close views of Shackleton crater come straight from NASA Science pages: its sunlit rim (LRO) and its floor, which
   never sees the Sun, taken by ShadowCam (shows a track left by a rolling boulder).

### 3. Eye on the Universe's picture (`assets/photos/telescope/`, source S-nasa-images)
1. Neptune by Voyager 2 (record PIA00049) from the NASA Image and Video Library. (The Grand Tour mission, which also
   had Jupiter, Saturn and Uranus, was dropped on 15 November 2026, issue #10.)
2. Ask the library which sizes exist and download the biggest; shrink to at most 1024 px; save as JPEG.

### 4. Numbers (`data/nasa/`, sources S-horizons and S-nssdc-planets)
1. Ask JPL Horizons, NASA's own solar-system position service, for the Moon's position and speed around the Earth, one
   per day for a month from 2026-11-15 (the trip to the Moon meets it there). Horizons answers a table of text; the
   script reads the table into JSON. (The planets' orbits, fetched for the dropped Grand Tour, are no longer asked.)
2. Read NASA's planetary fact sheets (web tables) for mass, radius, surface gravity, escape velocity, distance from the Sun
   and length of day of each planet and the Moon, keeping the name of the fact sheet row next to every value.

### 5. Manifest (`data/nasa/manifest.json`)
Every file written is listed with the source ID, the exact request that produced it, the day we checked it, what we did
to it, and its size.

## Limits we know
- Pictures are what the services serve (VIIRS pixels are 250 m), so they are soft; they are real, not drawn.
- The Voyager pictures are scans of the 1979-1989 encounters; Saturn's is a small crop.
- The tools do not use any image of people, any NASA logo or mission patch.
