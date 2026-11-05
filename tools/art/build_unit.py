#!/usr/bin/env python3
"""Builds a unit's game strips from Gemini sprite sheets on solid magenta.

Two layouts:

1. Three sheets per unit (current method). Each row of a sheet holds one
   animation; rows of the same animation join up left to right:

  {
    "sprite": "slinger",
    "height": 180,
    "sheets": [
      {"file": "slinger_walk.png",       "rows": ["walk", "walk"]},
      {"file": "slinger_attack.png",     "rows": ["attack", "attack"]},
      {"file": "slinger_death_idle.png", "rows": ["die", "idle"]}
    ],
    "match": {"attack": [1, 6]},   # poses scaled to idle height (walk: all;
                                   # false = keep the sheet's own scale)
    "scale": {"walk": 1.14},       # extra per-animation size correction
    "flip": {"die": [4]},          # mirror poses Gemini drew the wrong way round
    "synth": [{"anim": "idle", "from": 2, "stretchY": 1.02}],  # extra poses,
                                   # appended after the drawn ones (breathing)
    "play": {...}, "frameTimes": {...}
  }

   In each row the big figures are the poses; small pieces resting on the
   ground under a pose (a dropped weapon) are kept with it, anything else
   (floating extras, dust, a flying stone, the sparkle) is dropped.

2. One all-states sheet: 4 rows (idle / walk / attack / death), one pose per
   cell, the bottom-right cell empty. Spec:

  {
    "sprite": "clubman",
    "sheet": "clubman_all_state_new.png",
    "height": 220,                       # standing height in the strips, px
    "rows": {"idle": 4, "walk": 4, "attack": 4, "die": 3},
    "play": {                            # 1-based pose numbers per row
      "idle":   [1, 1, 2, 3, 3, 2, 1, 1, 4],
      "walk":   [1, 2, 3, 4],
      "attack": [1, 1, 2, 3, 4, 4, 4, 4],   # impact pose starts at 50%
      "die":    [1, 2, 3, 3, 3]
    },
    "frameTimes": {"idle": 0.16, "walk": 0.25}
  }

Writes assets/images/units/stone_<sprite>_<anim>[_red].png and
assets/images/icons/icon_<sprite>.png, and patches the unit's frameW,
frameH and frames in assets/data/units.json.

Usage: python3 tools/art/build_unit.py <spec.json> <project_root>
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROWS = ["idle", "walk", "attack", "die"]
PAD = 4


def magenta_mask(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    # Pure magenta, its anti-aliased edge and Gemini's darker purple shadow.
    return (r - g > 70) & (b - g > 70) & (np.abs(r - b) < 90)


def cut_poses(sheet: Path, rows: dict):
    rgb = np.asarray(Image.open(sheet).convert("RGB")).astype(int)
    fg = ndimage.binary_opening(~magenta_mask(rgb), iterations=2)
    lab, _ = ndimage.label(ndimage.binary_dilation(fg, iterations=3))
    blobs = []
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        area = int((fg[sl] & (lab[sl] == i)).sum())
        if area > 3000:
            blobs.append((sl, i))
    # Group into rows by their bottom edge, then left to right.
    h = rgb.shape[0]
    bands = len(rows)
    out = {}
    by_row = {k: [] for k in range(bands)}
    for sl, i in blobs:
        by_row[min(bands - 1, int(sl[0].stop / h * bands - 0.15))].append((sl, i))
    for k, name in enumerate(rows):
        row = sorted(by_row[k], key=lambda t: t[0][1].start)
        if len(row) < rows[name]:
            raise SystemExit(f"row {name}: found {len(row)} poses, expected {rows[name]}")
        # Biggest N, kept in left-to-right order (drops a stray sparkle).
        row = sorted(sorted(row, key=lambda t: -(t[0][0].stop - t[0][0].start) * (t[0][1].stop - t[0][1].start))[: rows[name]],
                     key=lambda t: t[0][1].start)
        poses = []
        for sl, i in row:
            m = (lab[sl] == i) & fg[sl]
            rgba = np.dstack([rgb[sl], np.where(m, 255, 0)]).astype(np.uint8)
            poses.append(Image.fromarray(rgba, "RGBA"))
        out[name] = poses
    return out


def cut_rows(sheet: Path, names: list):
    """Poses per row of a multi-row sheet: [(name, [(pose, body), ...])].
    `pose` includes ground pieces kept with the figure; `body` is the figure
    alone in the same frame (used for anchoring)."""
    rgb = np.asarray(Image.open(sheet).convert("RGB")).astype(int)
    H = rgb.shape[0]
    fg = ndimage.binary_opening(~magenta_mask(rgb), iterations=2)
    lab, _ = ndimage.label(ndimage.binary_dilation(fg, iterations=3))
    blobs = []
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        area = int((fg[sl] & (lab[sl] == i)).sum())
        if area > 500:
            blobs.append(dict(i=i, sl=sl, area=area, x0=sl[1].start, x1=sl[1].stop,
                              y0=sl[0].start, y1=sl[0].stop))
    bands = len(names)
    out = []
    for k, name in enumerate(names):
        row = [b for b in blobs if min(bands - 1, int((b["y0"] + b["y1"]) / 2 / H * bands)) == k]
        if not row:
            raise SystemExit(f"{sheet.name} row {k + 1}: no poses found")
        big = max(b["area"] for b in row)
        mains = sorted([b for b in row if b["area"] >= 0.35 * big], key=lambda b: b["x0"])
        base = float(np.median([b["y1"] for b in mains]))
        keep = {id(m): [m] for m in mains}
        for b in row:
            if b in mains:
                continue
            cx = (b["x0"] + b["x1"]) / 2
            if b["y1"] >= base - 0.06 * H and b["area"] >= 2000:
                owner = min(mains, key=lambda m: abs((m["x0"] + m["x1"]) / 2 - cx))
                keep[id(owner)].append(b)
            else:
                print(f"  {sheet.name} row {k + 1}: dropped a piece at x {b['x0']}-{b['x1']}, y {b['y0']}-{b['y1']}")
        poses = []
        for m in mains:
            parts = keep[id(m)]
            x0, x1 = min(p["x0"] for p in parts), max(p["x1"] for p in parts)
            y0, y1 = min(p["y0"] for p in parts), max(p["y1"] for p in parts)
            ids = [p["i"] for p in parts]
            sub_lab, sub_fg = lab[y0:y1, x0:x1], fg[y0:y1, x0:x1]
            def rgba(mask):
                return Image.fromarray(np.dstack([rgb[y0:y1, x0:x1], np.where(mask, 255, 0)]).astype(np.uint8), "RGBA")
            poses.append((rgba(np.isin(sub_lab, ids) & sub_fg), rgba((sub_lab == m["i"]) & sub_fg)))
        out.append((name, poses))
    return out


# Left edge of each pose inside its frame, for poses cut from fixed-size
# frames (video exports): {anim: [x0 or None, ...]}. Those frames share one
# camera, so they keep their own positions instead of being re-anchored.
CELL_X0 = {}


def cut_cells(path: Path, cell: int):
    """Equal-width frames on transparency (e.g. frames exported from an AI
    video tool). Magenta fringe and specks are removed."""
    im = Image.open(path).convert("RGBA")
    out = []
    for i in range(im.width // cell):
        a = np.asarray(im.crop((i * cell, 0, (i + 1) * cell, im.height))).copy()
        m = (a[..., 3] > 0) & ~magenta_mask(a[..., :3].astype(int))
        lab, n = ndimage.label(m)
        if n:
            sizes = ndimage.sum(m, lab, range(1, n + 1))
            m &= np.isin(lab, [j + 1 for j, sz in enumerate(sizes) if sz >= 0.01 * sizes.max()])
        a[..., 3] = np.where(m, 255, 0)
        ys, xs = np.nonzero(m)
        crop = Image.fromarray(a[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "RGBA")
        out.append((crop, int(xs.min())))
    return out


def load_poses(spec_path: Path, spec: dict):
    """{anim: [(pose, body), ...]} from either layout."""
    CELL_X0.clear()
    if "sheets" in spec:
        poses = {}
        first_h = {}
        for sh in spec["sheets"]:
            if "cell" in sh:
                cells = cut_cells(spec_path.parent / sh["file"], sh["cell"])
                poses.setdefault(sh["anim"], []).extend((c, c) for c, _ in cells)
                CELL_X0.setdefault(sh["anim"], []).extend(x for _, x in cells)
                continue
            for name, ps in cut_rows(spec_path.parent / sh["file"], sh["rows"]):
                if name.startswith("_"):  # a row this unit doesn't use
                    continue
                # Gemini draws each row at a slightly different size; with
                # "rowMatch" every row of that animation is scaled to the
                # first row's height so the figure doesn't pump.
                h = float(np.median([b.height for _, b in ps]))
                if name in spec.get("rowMatch", []) and name in first_h:
                    f = first_h[name] / h
                    ps = [tuple(i.resize((round(i.width * f), round(i.height * f)), Image.LANCZOS) for i in pb)
                          for pb in ps]
                first_h.setdefault(name, h)
                poses.setdefault(name, []).extend(ps)
                CELL_X0.setdefault(name, []).extend([None] * len(ps))
        return poses
    cut = cut_poses(spec_path.parent / spec["sheet"], spec["rows"])
    return {n: [(p, p) for p in ps] for n, ps in cut.items()}


def apply_edits(poses: dict, spec: dict):
    """Mirror listed poses, then add synthetic ones (a slight vertical
    stretch of a drawn pose reads as breathing)."""
    flip = Image.Transpose.FLIP_LEFT_RIGHT
    for name, idx in spec.get("flip", {}).items():
        for i in idx:
            p, b = poses[name][i - 1]
            poses[name][i - 1] = (p.transpose(flip), b.transpose(flip))
    for syn in spec.get("synth", []):
        p, b = poses[syn["anim"]][syn["from"] - 1]
        f = syn.get("stretchY", 1.0)
        poses[syn["anim"]].append(tuple(i.resize((i.width, round(i.height * f)), Image.LANCZOS) for i in (p, b)))
        x0 = CELL_X0.get(syn["anim"], [])
        if x0:
            x0.append(x0[syn["from"] - 1])


def front_foot_x(img):
    """Rightmost point of the lowest quarter of the figure: the planted
    front foot while standing, the feet once fallen backwards."""
    a = np.asarray(img)[..., 3] > 0
    ys, _ = np.nonzero(a)
    top, bot = ys.min(), ys.max()
    band = a[int(bot - (bot - top) * 0.25):bot + 1]
    return float(np.nonzero(band)[1].max())


def upper_body_anchors(bodies, ref_ax):
    """Anchor x per pose so the head and shoulders line up with pose 1
    (a walk turns around the hips; Gemini's legs are too loose to anchor on)."""
    def top_mask(img):
        a = np.asarray(img)[..., 3] > 0
        h = a.shape[0]
        return a[: int(h * 0.42)]
    ref = top_mask(bodies[0])
    out = [ref_ax]
    for b in bodies[1:]:
        m = top_mask(b)
        hh = min(ref.shape[0], m.shape[0])
        r, q = ref[ref.shape[0] - hh:], m[m.shape[0] - hh:]  # rows above the hips, aligned at the bottom of the band
        best, best_dx = -1, 0
        W = max(r.shape[1], q.shape[1])
        R = np.zeros((hh, W * 3), bool); R[:, W:W + r.shape[1]] = r
        for dx in range(-W // 3, W // 3 + 1):
            Q = np.zeros_like(R); Q[:, W + dx:W + dx + q.shape[1]] = q
            score = (R & Q).sum()
            if score > best:
                best, best_dx = score, dx
        out.append(ref_ax - best_dx)
    return out


def legs_x(img):
    a = np.asarray(img)[..., 3] > 0
    ys, xs = np.nonzero(a)
    bot = ys.max()
    low = a[int(bot * 0.9):bot + 1]
    lx = np.nonzero(low)[1]
    return float(lx.mean()), float(lx.min())


def red_variant(img):
    """Enemy colours: blue paint and headband -> red. Skin, hair, fur untouched."""
    a = np.asarray(img).astype(float).copy()
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    blue = (b > r + 25) & (b > g + 10)
    a[..., 0] = np.where(blue, np.minimum(255, b * 1.05 + 20), r)
    a[..., 1] = np.where(blue, g * 0.45, g)
    a[..., 2] = np.where(blue, r * 0.5, b)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def card(pose: Image.Image, size=160):
    """Square head-and-shoulders portrait for the shop card (no ring)."""
    a = np.asarray(pose)[..., 3] > 0
    ys, xs = np.nonzero(a)
    top, bot = ys.min(), ys.max()
    h = bot - top
    side = int(h * (0.42 if pose.width > pose.height * 1.3 else 0.5))
    cols = np.nonzero(a[top: top + side // 2].any(0))[0]
    cx = int(cols.mean())
    x0 = max(0, cx - side // 2)
    y0 = max(0, top - int(side * 0.06))
    return pose.crop((x0, y0, x0 + side, y0 + side)).resize((size, size), Image.LANCZOS)


def full_pose(pose: Image.Image, height=300):
    """Whole figure, trimmed, for menus (difficulty cards)."""
    p = pose.crop(pose.getchannel("A").getbbox())
    return p.resize((max(1, round(p.width * height / p.height)), height), Image.LANCZOS)


def medallion(pose: Image.Image, size=128):
    """Head-and-shoulders portrait in a stone ring."""
    w, h = pose.size
    side = int(min(w, h) * 0.62)
    a = np.asarray(pose)[..., 3] > 0
    cols = np.nonzero(a[: int(h * 0.35)].any(0))[0]
    cx = int(cols.mean()) if len(cols) else w // 2
    crop = pose.crop((max(0, cx - side // 2), 0, max(0, cx - side // 2) + side, side))
    k = 4
    S = size * k
    disc = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(disc)
    d.ellipse([0, 0, S - 1, S - 1], fill=(38, 58, 74, 255))
    inner = crop.resize((int(S * 0.86), int(S * 0.86)), Image.LANCZOS)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    layer.alpha_composite(inner, ((S - inner.width) // 2, int(S * 0.12)))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse([10 * k // 4, 10 * k // 4, S - 10 * k // 4, S - 10 * k // 4], fill=255)
    disc.paste(layer, (0, 0), Image.composite(layer.getchannel("A"), Image.new("L", (S, S), 0), mask))
    d = ImageDraw.Draw(disc)
    d.ellipse([3 * k, 3 * k, S - 3 * k, S - 3 * k], outline=(110, 104, 98, 255), width=7 * k)
    d.ellipse([3 * k, 3 * k, S - 3 * k, S - 3 * k], outline=(42, 29, 20, 255), width=2 * k)
    return disc.resize((size, size), Image.LANCZOS)


def main():
    spec_path, root = Path(sys.argv[1]), Path(sys.argv[2])
    spec = json.loads(spec_path.read_text())
    poses = load_poses(spec_path, spec)
    apply_edits(poses, spec)
    for name, ps in poses.items():
        print(f"  {name}: {len(ps)} poses")
    for name, order in spec["play"].items():
        if max(order) > len(poses.get(name, [])):
            raise SystemExit(f"play {name} uses pose {max(order)}, only {len(poses.get(name, []))} found")

    # One scale for the whole unit, from the idle figures. Walk (and any
    # poses listed in "match") are matched to idle height, so the unit
    # doesn't change size between sheets or when it starts walking.
    def med_h(ps):
        return float(np.median([b.height for _, b in ps]))
    idle_h = med_h(poses["idle"])
    k = spec["height"] / idle_h
    match = {"walk": None, **spec.get("match", {})}
    row_k = {}
    for name, ps in poses.items():
        if name in match and name != "idle" and match[name] is not False:
            ref = ps if match[name] is None else [ps[i - 1] for i in match[name]]
            row_k[name] = k * idle_h / med_h(ref)
        else:
            row_k[name] = k
        # Hand correction when a sheet's framing differs (e.g. a video clip
        # zoomed out to fit a long running pose): measured on the rider's head.
        row_k[name] *= spec.get("scale", {}).get(name, 1.0)

    def shrink(img, f):
        q = img.resize((max(1, round(img.width * f)), max(1, round(img.height * f))), Image.LANCZOS)
        arr = np.asarray(q).copy()
        arr[..., 3] = np.where(arr[..., 3] > 100, 255, 0)
        return Image.fromarray(arr, "RGBA")

    scaled = {n: [(shrink(p, row_k[n]), shrink(b, row_k[n])) for p, b in ps] for n, ps in poses.items()}

    # Anchors from the figure alone: standing poses on the legs. Death poses
    # keep a foot where the first death pose has it, so the fall doesn't
    # jump: the back foot (falls forward) or, with "dieAnchor": "front",
    # the front foot (falls backwards).
    anchors = {}
    front = spec.get("dieAnchor") == "front"
    for name, ps in scaled.items():
        xs = []
        cx0, lx0 = legs_x(ps[0][1])
        fx0 = front_foot_x(ps[0][1])
        for i, (_, b) in enumerate(ps):
            cx, lx = legs_x(b)
            if name == "die" and i > 0:
                xs.append(front_foot_x(b) - (fx0 - cx0) if front else lx + (cx0 - lx0))
            else:
                xs.append(cx)
        if spec.get("anchor", {}).get(name) == "body":
            xs = upper_body_anchors([b for _, b in ps], xs[0])
        x0 = CELL_X0.get(name, [])
        if x0 and all(v is not None for v in x0):
            # Same camera for every frame: anchor frame 1 on its legs and
            # keep the others where the video put them.
            f = row_k[name]
            xs = [xs[0] + (x0[0] - v) * f for v in x0]
        anchors[name] = xs

    used = {n: sorted(set(o)) for n, o in spec["play"].items()}
    half = max(max(ax, p.width - ax)
               for n in used for j in used[n]
               for p, ax in [(scaled[n][j - 1][0], anchors[n][j - 1])])
    cw = int(np.ceil(2 * half)) + 2 * PAD
    ch = max(scaled[n][j - 1][0].height for n in used for j in used[n]) + PAD

    units = root / "assets/images/units"
    units.mkdir(parents=True, exist_ok=True)
    counts = {}
    for name, order in spec["play"].items():
        strip = Image.new("RGBA", (cw * len(order), ch), (0, 0, 0, 0))
        for j, n in enumerate(order):
            p, ax = scaled[name][n - 1][0], anchors[name][n - 1]
            strip.alpha_composite(p, (int(round(j * cw + cw / 2 - ax)), ch - p.height))
        if strip.width > 4096:
            raise SystemExit(f"{name} strip is {strip.width}px wide (max 4096): lower height or frames")
        strip.save(units / f"stone_{spec['sprite']}_{name}.png")
        red_variant(strip).save(units / f"stone_{spec['sprite']}_{name}_red.png")
        counts[name] = len(order)

    icons = root / "assets/images/icons"
    icons.mkdir(parents=True, exist_ok=True)
    medallion(poses["idle"][0][1]).save(icons / f"icon_{spec['sprite']}.png")
    card(poses["idle"][0][1]).save(icons / f"card_{spec['sprite']}.png")
    full = full_pose(poses["idle"][0][1])
    full.save(icons / f"pose_{spec['sprite']}.png")
    red_variant(full).save(icons / f"pose_{spec['sprite']}_red.png")

    data_path = root / "assets/data/units.json"
    data = json.loads(data_path.read_text())
    for u in (u for e in data["eras"] for u in e["units"]):
        if u["sprite"] == spec["sprite"]:
            u["frameW"], u["frameH"] = cw, ch
            u["frames"] = counts
            if "frameTimes" in spec:
                u["frameTimes"] = spec["frameTimes"]
            for key in ("drawScale", "width"):
                if key in spec:
                    u[key] = spec[key]
            # Top of the standing figure in world units (health bar sits above).
            u["headY"] = round(spec["height"] * u.get("drawScale", 1))
    data_path.write_text(json.dumps(data, indent=2) + "\n")
    print(f"{spec['sprite']}: cell {cw}x{ch}, frames {counts}")


if __name__ == "__main__":
    main()
