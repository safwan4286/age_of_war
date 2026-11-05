#!/usr/bin/env python3
"""Builds a unit from transparent sprite-sheet grids (one sheet per
animation, as exported by sprite tools like SpriteCook or AutoSprite).

Spec (tools/art/source/<era>/sheets/<unit>.json):
  {
    "sprite": "swordsman", "era": "medieval",
    "worldHeight": 108,          # how tall it stands in the game
    "targetHeight": 200,         # optional: idle figure height in px
    "width": 40,                 # footprint on the lane
    "sheets": {
      "walk": {"file": "x_walk.png", "cols": 4, "count": 16, "anchor": "median"},
      "attack": {"file": "x_attack.png", "cols": 5, "count": 25, "anchor": "first",
                 "drop": [8]}    # 0-based frames to skip (broken or repeated)
    },
    "fromStrip": {"die": {"file": "old_die.png", "figureHeight": 210}},  # old equal-cell strip
    "sequence": {"attack": [["walk", 0], ["attack", 9], ...]},  # frames picked
                                 # across sheets (0-based, before "drop");
                                 # a 1-frame idle breathes and a 1-frame die
                                 # falls over in code
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

"fitExisting": true replaces only the listed animations of a unit that
already has art: frames are scaled to its current figure size
("referenceHeight" = the new tool's idle figure height in px) and drawn
into its current cell, so its other strips stay as they are.

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


def cells(path: Path, cols: int, count: int, drop=(), scale=1.0):
    im = Image.open(path).convert("RGBA")
    c = im.width // cols
    rows = math.ceil(count / cols)
    ch = im.height // rows
    out = []
    for i in range(count):
        if i in drop:
            continue
        x, y = (i % cols) * c, (i // cols) * ch
        f = despill(im.crop((x, y, x + c, y + ch)))
        if abs(scale - 1) > 1e-3:
            f = f.resize((round(c * scale), round(ch * scale)), Image.LANCZOS)
        out.append(f)
    return out


def despill(frame: Image.Image) -> Image.Image:
    """Edges and thin lines (bow strings) that kept a magenta tint from the
    source background become a neutral warm colour of the same lightness."""
    a = np.asarray(frame).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = (a[..., 3] > 0) & (r - g > 60) & (b - g > 50)
    if m.any():
        lum = (r + b) / 2
        a[..., 0] = np.where(m, lum, r)
        a[..., 1] = np.where(m, lum * 0.82, g)
        a[..., 2] = np.where(m, lum * 0.62, b)
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


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


def fit_existing(spec, src, root):
    data_path = root / "assets/data/units.json"
    data = json.loads(data_path.read_text())
    era = next(e for e in data["eras"] if e["id"] == spec["era"])
    u = next(u for u in era["units"] if u["sprite"] == spec["sprite"])
    cw, ch = u["frameW"], u["frameH"]
    figure = u["headY"] / u["drawScale"]  # current figure height in px
    k = figure / spec["referenceHeight"]
    half, base = cw / 2, ch - 2
    out = root / "assets/images/units"
    for name, s in spec["sheets"].items():
        frames = cells(src / s["file"], s["cols"], s["count"], set(s.get("drop", [])), k * s.get("scale", 1.0))
        info = [body(f) for f in frames]
        ax = float(np.median([i[0] for i in info])) if s.get("anchor") == "median" else info[0][0]
        ay = int(np.median([i[1] for i in info]))
        per_row = max(1, min(len(frames), MAX_TEX // cw))
        rows = math.ceil(len(frames) / per_row)
        sheet = Image.new("RGBA", (per_row * cw, rows * ch), (0, 0, 0, 0))
        for i, f in enumerate(frames):
            a = np.asarray(f)[..., 3] > 20
            ys, xs = np.nonzero(a)
            if xs.min() - ax < -half or xs.max() - ax > half or ay - ys.min() > base:
                print(f"warning: {name} frame {i} pokes out of the {cw}x{ch} cell")
            cell = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
            cell.alpha_composite(f, (int(round(half - ax)), int(base - ay)))
            sheet.alpha_composite(cell, ((i % per_row) * cw, (i // per_row) * ch))
        stem = f"{spec['era']}_{spec['sprite']}_{name}"
        sheet.save(out / f"{stem}.png")
        red_variant(sheet).save(out / f"{stem}_red.png")
        u.setdefault("frames", {})[name] = len(frames)
        if name in spec.get("frameTimes", {}):
            u.setdefault("frameTimes", {})[name] = spec["frameTimes"][name]
        print(f"{name}: {len(frames)} frames into the existing {cw}x{ch} cell (x{k * s.get('scale', 1.0):.3f})")
    data_path.write_text(json.dumps(data, indent=2) + "\n")


def main():
    spec_path = Path(sys.argv[1])
    root = Path(sys.argv[2])
    spec = json.loads(spec_path.read_text())
    src = spec_path.parent
    if spec.get("fitExisting"):
        fit_existing(spec, src, root)
        return

    # Optional: shrink everything so the idle figure is targetHeight px
    # tall (tools export 500+ px figures; ~200 is plenty in game). A sheet
    # drawn at another size than the idle gets its own "scale".
    k = 1.0
    if "targetHeight" in spec and "idle" in spec["sheets"]:
        s = spec["sheets"]["idle"]
        k = spec["targetHeight"] / body(cells(src / s["file"], s["cols"], s["count"])[0])[2]

    def scale_of(s):
        return k * s.get("scale", 1.0)

    # (frames, anchor x, anchor y, scale) per animation.
    anims = {}
    for name, s in spec["sheets"].items():
        frames = cells(src / s["file"], s["cols"], s["count"], set(s.get("drop", [])), scale_of(s))
        info = [body(f) for f in frames]
        if s.get("anchor", "first") == "median":
            ax = float(np.median([i[0] for i in info]))
        else:
            ax = info[0][0]
        ay = int(np.median([i[1] for i in info]))
        anims[name] = (frames, ax, ay, 1.0)
    ref_h = body(anims["idle"][0][0])[2] if "idle" in anims else body(next(iter(anims.values()))[0][0])[2]

    # Animations assembled from frames of several sheets, each frame kept
    # on its own sheet's anchor (so a walk pose can lead into a lunge).
    # Indices count every frame of the sheet ("drop" doesn't apply).
    raw = {}
    for name, s in spec["sheets"].items():
        frames = cells(src / s["file"], s["cols"], s["count"], scale=scale_of(s))
        a = anims[name]
        raw[name] = [(f, a[1], a[2]) for f in frames]
    for name, seq in spec.get("sequence", {}).items():
        picked = [raw[sheet][i] for sheet, i in seq]
        anims[name] = ([p[0] for p in picked], None, None, [(p[1], p[2]) for p in picked])

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
    def anchors(entry):
        frames, ax, ay, per = entry
        return per if isinstance(per, list) else [(ax, ay)] * len(frames)

    left = right = up = down = 0
    for entry in anims.values():
        for f, (ax, ay) in zip(entry[0], anchors(entry)):
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
    for name, entry in anims.items():
        frames = entry[0]
        per_row = max(1, min(len(frames), MAX_TEX // cw))
        rows = math.ceil(len(frames) / per_row)
        sheet = Image.new("RGBA", (per_row * cw, rows * ch), (0, 0, 0, 0))
        for i, (f, (ax, ay)) in enumerate(zip(frames, anchors(entry))):
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
