#!/usr/bin/env python3
"""Builds a unit from transparent sprite-sheet grids (one sheet per
animation, as exported by sprite tools like SpriteCook or AutoSprite).

Spec (tools/art/source/<era>/sheets/<unit>.json):
  {
    "sprite": "swordsman", "era": "medieval",
    "worldHeight": 108,          # how tall it stands in the game
    "width": 40,                 # footprint on the lane
    "sheets": {
      "walk": {"file": "x_walk.png", "cols": 4, "count": 16, "anchor": "median"},
      "attack": {"file": "x_attack.png", "cols": 5, "count": 25, "anchor": "first",
                 "drop": [8]}    # 0-based frames to skip (broken or repeated)
    },
    "fromStrip": {"die": {"file": "old_die.png", "figureHeight": 210}},  # old equal-cell strip
    "frameTimes": {"idle": 0.125, "walk": 0.125, "attack": 0.08},
    "impactFrame": 8             # attack frame where the blow lands
  }

Every frame keeps its position inside its sheet (one camera per sheet).
Each sheet is anchored on its body: the torso's x (first frame, or the
median over the frames for a walk) and the feet's line. All sheets must
be drawn at the same scale (checked: idle height is the reference).

Strips are written as grids (as many frames per row as fit in 4096 px),
so long animations need no cutting. Writes units/<era>_<sprite>_<anim>
[_red].png and patches the unit in assets/data/units.json.

Usage: python3 tools/art/build_sheet_unit.py <spec.json> <project_root>
"""
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from build_unit import red_variant  # noqa: E402

MAX_TEX = 4096


def cells(path: Path, cols: int, count: int, drop=()):
    im = Image.open(path).convert("RGBA")
    c = im.width // cols
    rows = math.ceil(count / cols)
    ch = im.height // rows
    out = []
    for i in range(count):
        if i in drop:
            continue
        x, y = (i % cols) * c, (i // cols) * ch
        out.append(im.crop((x, y, x + c, y + ch)))
    return out


def body(frame: Image.Image):
    """(torso x, feet y, figure height) of one frame."""
    a = np.asarray(frame)[..., 3] > 40
    ys = np.nonzero(a.any(1))[0]
    top, feet = ys.min(), ys.max()
    # Torso: the band between 35% and 65% of the figure, below any
    # raised weapon; its centre of mass.
    band = a[top + int((feet - top) * 0.35):top + int((feet - top) * 0.65)]
    xs = np.nonzero(band)[1]
    return float(np.median(xs)), int(feet), int(feet - top)


def main():
    spec_path = Path(sys.argv[1])
    root = Path(sys.argv[2])
    spec = json.loads(spec_path.read_text())
    src = spec_path.parent

    # (frames, anchor x, anchor y, scale) per animation.
    anims = {}
    for name, s in spec["sheets"].items():
        frames = cells(src / s["file"], s["cols"], s["count"], set(s.get("drop", [])))
        info = [body(f) for f in frames]
        if s.get("anchor", "first") == "median":
            ax = float(np.median([i[0] for i in info]))
        else:
            ax = info[0][0]
        ay = int(np.median([i[1] for i in info]))
        anims[name] = (frames, ax, ay, 1.0)
    ref_h = body(anims["idle"][0][0])[2] if "idle" in anims else body(next(iter(anims.values()))[0][0])[2]

    for name, s in spec.get("fromStrip", {}).items():
        strip = Image.open(src / s["file"]).convert("RGBA")
        h = strip.height
        # Old strips: equal cells, anchor = cell bottom centre.
        n = s.get("count", 8)
        w = strip.width // n
        k = ref_h / s["figureHeight"]
        frames = [strip.crop((i * w, 0, (i + 1) * w, h)).resize((round(w * k), round(h * k)), Image.LANCZOS)
                  for i in range(n)]
        anims[name] = (frames, round(w * k) / 2, round(h * k) - 1, 1.0)

    # One cell size for every animation, centred on the anchor.
    left = right = up = down = 0
    for frames, ax, ay, _ in anims.values():
        for f in frames:
            a = np.asarray(f)[..., 3] > 20
            ys, xs = np.nonzero(a)
            if not len(xs):
                continue
            left = max(left, ax - xs.min())
            right = max(right, xs.max() - ax)
            up = max(up, ay - ys.min())
            down = max(down, ys.max() - ay)
    half = int(math.ceil(max(left, right))) + 2
    # The game stands the cell's bottom edge on the ground, so the feet
    # line is the cell bottom (a pixel or two of boot below it is cut).
    base = int(up) + 2
    cw, ch = 2 * half, base + 2
    print(f"below the feet line: {down:.0f} px (cut)")

    out = root / "assets/images/units"
    counts = {}
    for name, (frames, ax, ay, _) in anims.items():
        per_row = max(1, min(len(frames), MAX_TEX // cw))
        rows = math.ceil(len(frames) / per_row)
        sheet = Image.new("RGBA", (per_row * cw, rows * ch), (0, 0, 0, 0))
        for i, f in enumerate(frames):
            cell = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
            cell.alpha_composite(f, (int(round(half - ax)), int(base - ay)))
            sheet.alpha_composite(cell, ((i % per_row) * cw, (i // per_row) * ch))
        stem = f"{spec['era']}_{spec['sprite']}_{name}"
        sheet.save(out / f"{stem}.png")
        red_variant(sheet).save(out / f"{stem}_red.png")
        counts[name] = len(frames)
        print(f"{name}: {len(frames)} frames, {per_row}/row, sheet {sheet.size}")

    data_path = root / "assets/data/units.json"
    data = json.loads(data_path.read_text())
    era = next(e for e in data["eras"] if e["id"] == spec["era"])
    u = next(u for u in era["units"] if u["sprite"] == spec["sprite"])
    u["frameW"], u["frameH"] = cw, ch
    u["frames"] = counts
    u["frameTimes"] = spec.get("frameTimes", u.get("frameTimes", {}))
    if "impactFrame" in spec:
        u["impactFrame"] = spec["impactFrame"]
    u["drawScale"] = round(spec["worldHeight"] / ref_h, 4)
    u["headY"] = spec["worldHeight"]
    u["width"] = spec.get("width", u.get("width"))
    data_path.write_text(json.dumps(data, indent=2) + "\n")
    print(f"{spec['sprite']}: cell {cw}x{ch}, feet at {base}, drawScale {u['drawScale']}")


if __name__ == "__main__":
    main()
