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
    "red": "cloth"               # enemy colours: "cloth" (also dark navy),
                                 # "clear" (clear blue only), default = swap
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

Usage: python3 tools/art/build_sheet_unit.py <spec.json> <project_root> [--portraits]
       (--portraits: only the shop card, medallion and menu pose)
"""
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).parent))
from build_unit import card, full_pose, medallion, red_variant  # noqa: E402

MAX_TEX = 4096


def cells(path: Path, cols: int, count: int, drop=(), scale=1.0, holes=None):
    im = Image.open(path).convert("RGBA")
    c = im.width // cols
    rows = math.ceil(count / cols)
    ch = im.height // rows
    out = []
    for i in range(count):
        if i in drop:
            continue
        x, y = (i % cols) * c, (i // cols) * ch
        f = im.crop((x, y, x + c, y + ch))
        out.append(_finish(f, scale, (holes or {}).get(str(i))))
    return out


def _finish(f: Image.Image, scale: float, holes=None, smear=False) -> Image.Image:
    if smear:
        f = drop_smears(f)
    f = despill(f)
    if holes:
        f = fill_holes(f, holes)
    if abs(scale - 1) > 1e-3:
        f = f.resize((round(f.width * scale), round(f.height * scale)), Image.LANCZOS)
    return f


def frames_of(src: Path, s: dict, scale: float, use_pick=True):
    """A sheet's frames: a grid ("file", "cols", "count") or loose images
    ("files", e.g. frames cut from a video). "pick" chooses and orders
    frames (0-based); "drop" skips some; "holes" repairs cut-out holes."""
    if "files" in s:
        frames = [_finish(Image.open(src / f).convert("RGBA"), scale, (s.get("holes") or {}).get(str(i)),
                          s.get("smear", False))
                  for i, f in enumerate(s["files"])]
        frames = [f for i, f in enumerate(frames) if i not in set(s.get("drop", []))]
    else:
        frames = cells(src / s["file"], s["cols"], s["count"], set(s.get("drop", [])), scale, s.get("holes"))
    if use_pick and "pick" in s:
        allf = frames if "files" in s else cells(src / s["file"], s["cols"], s["count"], (), scale, s.get("holes"))
        frames = [allf[i] for i in s["pick"]]
    if s.get("detint"):
        frames = [detint(f) for f in frames]
    return frames


def detint(frame: Image.Image) -> Image.Image:
    """SpriteCook sometimes paints a green or purple oil-slick sheen on
    dark parts (boots, hoses). Dark pixels leaning green or purple become
    neutral dark grey at the same brightness ("detint": true on a sheet);
    navy blue cloth is left alone."""
    a = np.asarray(frame).copy()
    r, g, b = (a[..., i].astype(int) for i in range(3))
    dark = np.maximum(np.maximum(r, g), b) < 150
    green = (g > r + 10) & (g > b + 4)
    purple = (r > g + 14) & (b > g + 14)
    m = dark & (green | purple) & (a[..., 3] > 0)
    lum = (0.3 * r + 0.55 * g + 0.15 * b) * 0.9
    for i, k in enumerate((0.96, 0.98, 1.06)):
        a[..., i] = np.where(m, np.clip(lum * k, 0, 255), a[..., i])
    return Image.fromarray(a, "RGBA")


def drop_smears(frame: Image.Image) -> Image.Image:
    """Video motion smears and dust drawn as pale pink over the magenta
    background (white blended into it) become transparent."""
    a = np.asarray(frame).copy()
    r, g, b = (a[..., i].astype(int) for i in range(3))
    pale = (r > 190) & (b > 190) & (np.abs(r - b) < 45) & (r - g > 35)
    a[..., 3] = np.where(pale, 0, a[..., 3])
    return Image.fromarray(a, "RGBA")


def fill_holes(frame: Image.Image, regions) -> Image.Image:
    """Fills holes a tool cut through the figure (inside the given
    [y0, y1, x0, x1] regions) with the colour of the nearest solid pixel."""
    a = np.asarray(frame).copy()
    solid = a[..., 3] > 40
    closed = ndimage.binary_fill_holes(ndimage.binary_closing(solid, iterations=6))
    hole = closed & ~solid
    mask = np.zeros_like(hole)
    for y0, y1, x0, x1 in regions:
        mask[y0:y1, x0:x1] = True
    hole &= mask
    if hole.any():
        _, (iy, ix) = ndimage.distance_transform_edt(~solid, return_indices=True)
        a[hole, :3] = a[iy[hole], ix[hole], :3]
        a[hole, 3] = 255
    return Image.fromarray(a, "RGBA")


def red_cloth(img: Image.Image, vmax=100) -> Image.Image:
    """Enemy colours for art whose blue came out dark and greyish (navy
    cloth): besides clearly blue paint, dark cool pixels (cloth, not the
    lighter steel) turn red."""
    a = np.asarray(img).astype(float).copy()
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx = np.maximum(np.maximum(r, g), b)
    blue = ((b > r + 25) & (b > g + 10)) | ((b >= r + 8) & (mx < vmax))
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    a[..., 0] = np.where(blue, np.minimum(255, lum * 1.9 + 22), r)
    a[..., 1] = np.where(blue, lum * 0.42, g)
    a[..., 2] = np.where(blue, lum * 0.40, b)
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def despill(frame: Image.Image) -> Image.Image:
    """Cleans a tool's export: background magenta it failed to remove
    becomes transparent, stray specks are dropped, and edges or thin lines
    (bow strings) that kept a magenta tint become a neutral warm colour of
    the same lightness."""
    a = np.asarray(frame).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    bright = (r > 170) & (b > 170) & (g < 120) & (np.abs(r - b) < 110)
    a[..., 3] = np.where(bright, 0, a[..., 3])
    solid = a[..., 3] > 40
    lab, n = ndimage.label(ndimage.binary_dilation(solid, iterations=3))
    if n > 1:
        sizes = ndimage.sum(solid, lab, range(1, n + 1))
        keep = np.isin(lab, [i + 1 for i, v in enumerate(sizes) if v >= max(60, 0.003 * sizes.max())])
        a[..., 3] = np.where(keep, a[..., 3], 0)
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


def mirror_text(spec, out, anims, cw, ch):
    """The game mirrors enemy units, so lettering on them ("07" on the
    tank) would read backwards. "mirrorText": {"box": [x0, y0, x1, y1]}
    marks the lettering in the first idle frame, in pixels from the
    cell's centre (x) and bottom (y), so it survives the cell resizing; in every
    enemy frame the same patch is found by template matching and flipped
    in place, so the game's mirror turns it back. Frames where the match
    is weak (the turret tumbling in the death) are left as they are."""
    import cv2
    bx0, by0, bx1, by1 = spec["mirrorText"]["box"]
    x0, x1, y0, y1 = cw // 2 + bx0, cw // 2 + bx1, ch + by0, ch + by1
    idle = np.asarray(Image.open(out / f"{spec['era']}_{spec['sprite']}_idle_red.png"))
    tpl = cv2.cvtColor(np.ascontiguousarray(idle[y0:y1, x0:x1, :3]), cv2.COLOR_RGB2GRAY)
    th, tw = tpl.shape
    pad = 40
    for name in anims:
        path = out / f"{spec['era']}_{spec['sprite']}_{name}_red.png"
        a = np.asarray(Image.open(path)).copy()
        per = a.shape[1] // cw
        flipped = 0
        # Video clips draw the lettering a little differently: find it in
        # the clip's first frame with a looser match, then track that.
        here, need = tpl, 0.35
        for i in range(len(anims[name][0])):
            ox, oy = (i % per) * cw, (i // per) * ch
            sx0, sy0 = max(0, x0 - pad), max(0, y0 - pad)
            sx1, sy1 = min(cw, x1 + pad), min(ch, y1 + pad)
            win = cv2.cvtColor(np.ascontiguousarray(a[oy + sy0:oy + sy1, ox + sx0:ox + sx1, :3]), cv2.COLOR_RGB2GRAY)
            res = cv2.matchTemplate(win, here, cv2.TM_CCOEFF_NORMED)
            _, score, _, (mx, my) = cv2.minMaxLoc(res)
            if score < need:
                continue
            fx, fy = ox + sx0 + mx, oy + sy0 + my
            if i == 0:
                here, need = win[my:my + th, mx:mx + tw].copy(), 0.6
            a[fy:fy + th, fx:fx + tw] = a[fy:fy + th, fx:fx + tw][:, ::-1]
            flipped += 1
        Image.fromarray(a, "RGBA").save(path)
        print(f"mirrorText {name}: flipped in {flipped}/{len(anims[name][0])} frames")


def portraits(spec, src, root):
    """Shop card, HUD medallion and menu pose from the first idle frame at
    full resolution ("portraits": true in the spec)."""
    first = frames_of(src, spec["sheets"]["idle"], 1.0)[0]
    first = first.crop(first.getchannel("A").getbbox())
    icons = root / "assets/images/icons"
    sprite = spec["sprite"]
    # The medallion comes from the card's head-and-shoulders crop: a long
    # musket or a cannon would pull a whole-figure crop off the face.
    medallion(card(first, size=512)).save(icons / f"icon_{sprite}.png")
    card(first).save(icons / f"card_{sprite}.png")
    full = full_pose(first)
    full.save(icons / f"pose_{sprite}.png")
    mode = spec.get("red")
    red = red_cloth(full) if mode == "cloth" else red_cloth(full, vmax=0) if mode == "clear" else red_variant(full)
    red.save(icons / f"pose_{sprite}_red.png")
    print(f"portraits: icon_{sprite}, card_{sprite}, pose_{sprite}(_red)")


def fit_existing(spec, src, root):
    data_path = root / "assets/data/units.json"
    data = json.loads(data_path.read_text())
    era = next(e for e in data["eras"] if e["id"] == spec["era"])
    u = next(u for u in era["units"] if u["sprite"] == spec["sprite"])
    cw, ch = u["frameW"], u["frameH"]
    figure = u["headY"] / u["drawScale"]  # current figure height in px
    ref = spec.get("referenceHeight")
    if ref is None:  # the new idle's own height
        s = spec["sheets"]["idle"]
        ref = body(frames_of(src, s, 1.0)[0])[2]
    k = figure / ref
    out = root / "assets/images/units"
    # Line the new frames up with the unit's current idle (torso and feet),
    # so switching between old and new strips doesn't jump.
    half, base = cw / 2, ch - 2
    idle = out / f"{spec['era']}_{spec['sprite']}_idle.png"
    if idle.exists():
        tx, feet, _ = body(Image.open(idle).convert("RGBA").crop((0, 0, cw, ch)))
        half, base = tx, feet
    elif "alignTo" in spec:
        half, base = spec["alignTo"]
    for name, s in spec["sheets"].items():
        frames = frames_of(src, s, k * s.get("scale", 1.0))
        info = [body(f) for f in frames]
        ax = float(np.median([i[0] for i in info])) if s.get("anchor") == "median" else info[0][0]
        ay = int(np.median([i[1] for i in info]))
        per_row = max(1, min(len(frames), MAX_TEX // cw))
        rows = math.ceil(len(frames) / per_row)
        sheet = Image.new("RGBA", (per_row * cw, rows * ch), (0, 0, 0, 0))
        for i, f in enumerate(frames):
            a = np.asarray(f)[..., 3] > 20
            ys, xs = np.nonzero(a)
            if xs.min() - ax < -half or xs.max() - ax > cw - half or ay - ys.min() > base:
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
    if "--portraits" in sys.argv[3:]:
        portraits(spec, src, root)
        return

    # Optional: shrink everything so the idle figure is targetHeight px
    # tall (tools export 500+ px figures; ~200 is plenty in game). A sheet
    # drawn at another size than the idle gets its own "scale".
    k = 1.0
    if "targetHeight" in spec and "idle" in spec["sheets"]:
        s = spec["sheets"]["idle"]
        k = spec["targetHeight"] / body(frames_of(src, s, 1.0)[0])[2]

    def scale_of(s):
        return k * s.get("scale", 1.0)

    # (frames, anchor x, anchor y, scale) per animation.
    anims = {}
    for name, s in spec["sheets"].items():
        frames = frames_of(src, s, scale_of(s))
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
        frames = frames_of(src, {**s, "drop": []}, scale_of(s), use_pick=False)
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
        mode = spec.get("red")
        if mode == "cloth":
            red_sheet = red_cloth(sheet)
        elif mode == "clear":
            # Clear blue only, painted the same deep red as "cloth" (the
            # plain swap turned some blues pink), dark hats/boots untouched.
            red_sheet = red_cloth(sheet, vmax=0)
        else:
            red_sheet = red_variant(sheet)
        red_sheet.save(out / f"{stem}_red.png")
        counts[name] = len(frames)
        print(f"{name}: {len(frames)} frames, {per_row}/row, sheet {sheet.size}")
    if spec.get("mirrorText"):
        mirror_text(spec, out, anims, cw, ch)

    data_path = root / "assets/data/units.json"
    data = json.loads(data_path.read_text())
    era = next((e for e in data["eras"] if e["id"] == spec["era"]), None)
    u = next((u for u in era["units"] if u["sprite"] == spec["sprite"]), None) if era else None
    pending = u is None
    if pending:
        # The age isn't in the game yet: keep the unit's art data next to
        # the spec until all four units are built.
        u = dict(spec.get("stats", {}), sprite=spec["sprite"], era=spec["era"])
    u["frameW"], u["frameH"] = cw, ch
    u["frames"] = counts
    u["frameTimes"] = spec.get("frameTimes", u.get("frameTimes", {}))
    if "impactFrame" in spec:
        u["impactFrame"] = spec["impactFrame"]
    u["drawScale"] = round(spec["worldHeight"] / ref_h, 4)
    u["headY"] = spec["worldHeight"]
    u["width"] = spec.get("width", u.get("width"))
    if pending:
        out = spec_path.with_name(spec_path.stem + ".unit.json")
        out.write_text(json.dumps(u, indent=2) + "\n")
        print(f"age '{spec['era']}' not in the game yet: unit data -> {out.name}")
    else:
        data_path.write_text(json.dumps(data, indent=2) + "\n")
    print(f"{spec['sprite']}: cell {cw}x{ch}, feet at {base}, drawScale {u['drawScale']}")


if __name__ == "__main__":
    main()
