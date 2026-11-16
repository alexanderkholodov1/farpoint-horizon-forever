"""Cuts the 30-second video from the game's own recording (issue #38).

1. Record:  tools/dev/godot.sh --path . --write-movie build/video/raw.ogv --fixed-fps 30 res://tests/look/trailer.tscn > build/video/record.log
   (the window size of the project, 1600x900; the cut is scaled to 1920x1080). Do not close the window: it ends itself.
2. Cut:     python tools/content/video/make_trailer.py
Writes build/video/farpoint_horizon_30s.mp4 (H.264 + AAC, under 30 s), from the "[cut] <moment> <seconds>" marks the
recording printed. Needs ffmpeg on the PATH.

The edit (seconds from each moment's mark, and how long to keep): the sunrise and the title, the craft assembled, the
rocket stacked, liftoff from the Andes, the edge of space, the burn toward the Moon, the landing at the pole, the report
with the photos home, the Earthrise and the title. Each clip crossfades into the next.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
VID = os.path.join(ROOT, "build", "video")
RAW = os.path.join(VID, "raw.ogv")    # Theora: an AVI (MJPEG) of the whole run takes gigabytes
LOG = os.path.join(VID, "record.log")
OUT = os.path.join(VID, "farpoint-horizon-30s.mp4")
XF = 0.4            # crossfade, seconds
LIMIT = 30.0

# moment, offset after its mark, length kept
EDIT = [
    ("open", 6.4, 4.6),     # the film's title arriving (cue at 7.0 s)
    ("design", 0.2, 3.6),
    ("builder", 0.1, 3.2),
    ("liftoff", 0.4, 4.8),
    ("space", 0.0, 2.6),
    ("burn", 0.0, 2.8),
    ("landing", 0.0, 3.6),
    ("report", 0.0, 2.6),
    ("end", 0.6, 4.6),      # the same title over the Earthrise
]


def marks():
    out = {}
    for line in open(LOG, encoding="utf-8", errors="replace"):
        m = re.match(r"\[cut\] (\w+) ([0-9.]+)", line.strip())
        if m:
            out[m.group(1)] = float(m.group(2))
    return out


def main():
    mk = marks()
    missing = [n for n, _, _ in EDIT if n not in mk]
    if missing:
        sys.exit("missing marks in %s: %s" % (LOG, missing))
    total = sum(d for _, _, d in EDIT) - XF * (len(EDIT) - 1)
    print("edit length %.2f s" % total)
    if total > LIMIT:
        sys.exit("too long: %.2f s" % total)
    args = ["ffmpeg", "-y"]
    for name, off, dur in EDIT:
        args += ["-ss", "%.3f" % (mk[name] + off), "-t", "%.3f" % dur, "-i", RAW]
    parts = []
    for i in range(len(EDIT)):
        parts.append("[%d:v]settb=AVTB,fps=30,scale=1920:1080:flags=lanczos,format=yuv420p,setpts=PTS-STARTPTS[v%d]" % (i, i))
        parts.append("[%d:a]aresample=48000,asetpts=PTS-STARTPTS[a%d]" % (i, i))
    vlast, alast, t = "v0", "a0", EDIT[0][2]
    for i in range(1, len(EDIT)):
        off = t - XF
        parts.append("[%s][v%d]xfade=transition=fade:duration=%.2f:offset=%.3f[vx%d]" % (vlast, i, XF, off, i))
        parts.append("[%s][a%d]acrossfade=d=%.2f[ax%d]" % (alast, i, XF, i))
        vlast, alast = "vx%d" % i, "ax%d" % i
        t = off + EDIT[i][2]
    # fade in from black and out to black
    parts.append("[%s]fade=t=in:st=0:d=0.6,fade=t=out:st=%.3f:d=0.8[vout]" % (vlast, t - 0.8))
    parts.append("[%s]afade=t=in:st=0:d=0.6,afade=t=out:st=%.3f:d=0.8[aout]" % (alast, t - 0.8))
    args += ["-filter_complex", ";".join(parts), "-map", "[vout]", "-map", "[aout]",
             "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p",
             "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", OUT]
    subprocess.run(args, check=True)
    probe = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", OUT],
                           capture_output=True, text=True)
    print("wrote", OUT, "duration", probe.stdout.strip(), "s,", os.path.getsize(OUT) // 1024, "KB")


if __name__ == "__main__":
    main()
