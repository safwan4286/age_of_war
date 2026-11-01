#!/usr/bin/env python3
"""Turn AI-generated character sheets into game-ready animation strips.

Input: one PNG per unit with 4 rows (idle 4, walk 6, attack 6, die 6) on a
solid or baked-checkerboard background (what Gemini produces).

Output (assets/images/units/):
  stone_<sprite>_<anim>.png       horizontal strip, transparent, feet on the
  stone_<sprite>_<anim>_red.png   bottom edge, body centred in each cell
and assets/images/icons/icon_<sprite>.png (128x128 portrait).

Prints the frame size and the drawScale to put in assets/data/units.json.

Usage:
  python3 tools/art/slice_sheets.py <sheets_dir> <project_root> [--preview out.png]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROWS = [("idle", 4), ("walk", 6), ("attack", 6), ("die", 6)]

# sheet file -> (sprite id, target standing height in world units,
#                frame picks per anim when the sheet's own order is wrong)
UNITS = {
    "clubman.png": ("clubman", 88, {}),
    "Slinger.png": ("slinger", 88, {}),
    "chief.png": ("chief", 94, {}),
    # Attack frame 6 shows the rider on foot without the dino, and die
    # frame 1 shows the dino without the rider: reuse neighbours instead.
    "dino_rider.png": ("dinorider", 104, {"attack": [0, 1, 2, 3, 4, 4], "die": [1, 1, 2, 3, 4, 5]}),
}

DOWNSCALE = 0.5      # sheets are ~3 px per art pixel; halve, then let the game scale
PAD = 4


def background_mask(rgb: np.ndarray) -> np.ndarray:
    """True where the pixel is background, found by flood fill from the
    border so dark outlines inside the character are never eaten."""
    h, w, _ = rgb.shape
    r, g, b = rgb[..., 0].astype(int), rgb[..., 1].astype(int), rgb[..., 2].astype(int)
    mx, mn = np.maximum(np.maximum(r, g), b), np.minimum(np.minimum(r, g), b)
    corner = np.median(np.concatenate([rgb[:8, :8].reshape(-1, 3), rgb[:8, -8:].reshape(-1, 3)]), axis=0)
    if corner.mean() > 150:
        # Baked checkerboard (white / light grey) plus faint grey streaks.
        candidate = (mx - mn < 26) & (mn > 150)
    else:
        dist = np.sqrt(((rgb.astype(int) - corner) ** 2).sum(-1))
        candidate = dist < 24
    labels, _ = ndimage.label(candidate)
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    border = border[border > 0]
    return np.isin(labels, border)


def row_bands(fg: np.ndarray, n: int):
    """Split the sheet into n horizontal bands at the emptiest rows."""
    prof = fg.sum(1).astype(float)
    h = len(prof)
    cuts = []
    for i in range(1, n):
        centre = h * i // n
        lo, hi = centre - h // (2 * n), centre + h // (2 * n)
        cuts.append(lo + int(np.argmin(ndimage.uniform_filter1d(prof[lo:hi], 9))))
    edges = [0] + cuts + [h]
    return list(zip(edges[:-1], edges[1:]))


def frames_in_band(fg: np.ndarray, y0: int, y1: int, want: int):
    """Bounding boxes of the `want` biggest figures in a band. Swing arcs,
    dust and thrown stones within reach of a figure are merged into it;
    stray marks (watermarks) far from any figure are dropped."""
    band = fg[y0:y1]
    merged = ndimage.binary_dilation(band, iterations=3)
    labels, n = ndimage.label(merged)
    blobs = []
    for i, sl in enumerate(ndimage.find_objects(labels), start=1):
        area = int((band[sl] & (labels[sl] == i)).sum())
        blobs.append((area, sl, i))
    blobs.sort(key=lambda t: -t[0])
    big = [b for b in blobs if b[0] > 2500]
    if len(big) < want:
        raise SystemExit(f"band {y0}-{y1}: found {len(big)} figures, expected {want}")
    keep = sorted(big[:want], key=lambda t: t[1][1].start)
    out = []
    for area, sl, i in keep:
        mask = np.zeros_like(band)
        mask[sl] = labels[sl] == i
        mask &= band
        ys, xs = np.nonzero(mask)
        out.append((mask, xs.min(), ys.min() + y0, xs.max() + 1, ys.max() + 1 + y0))
    return out


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    src, root = Path(sys.argv[1]), Path(sys.argv[2])
    preview = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    units_dir = root / "assets/images/units"
    icons_dir = root / "assets/images/icons"
    units_dir.mkdir(parents=True, exist_ok=True)
    icons_dir.mkdir(parents=True, exist_ok=True)
    previews = []

    for fname, (sprite, target_h, picks) in UNITS.items():
        path = src / fname
        if not path.exists():
            print(f"skip {fname}: not found")
            continue
        im = Image.open(path).convert("RGB")
        rgb = np.asarray(im)
        bg = background_mask(rgb)
        fg = ~bg
        fg = ndimage.binary_opening(fg, iterations=1)
        rgba = np.dstack([rgb, np.where(fg, 255, 0).astype(np.uint8)])

        anims = {}
        for (anim, count), (y0, y1) in zip(ROWS, row_bands(fg, len(ROWS))):
            boxes = frames_in_band(fg, y0, y1, count)
            frames = []
            for mask, x0, fy0, x1, fy1 in boxes:
                lying = anim == "die" and (x1 - x0) > (fy1 - fy0) * 1.15
                if lying:
                    cx = (x0 + x1) / 2
                else:
                    # Centre on the lowest quarter (legs/feet).
                    q = fy1 - (fy1 - fy0) // 4
                    ys, xs = np.nonzero(mask[q - y0:fy1 - y0, x0:x1])
                    cx = x0 + (xs.mean() if len(xs) else (x1 - x0) / 2)
                full = np.zeros((rgb.shape[0], rgb.shape[1]), bool)
                full[y0:y1] = mask
                cut = rgba[fy0:fy1, x0:x1].copy()
                cut[..., 3] = np.where(full[fy0:fy1, x0:x1], 255, 0)
                frames.append((Image.fromarray(cut, "RGBA"), cx - x0, fy1 - fy0))
            order = picks.get(anim, list(range(count)))
            anims[anim] = [frames[i] for i in order]

        # One cell size for every animation of this unit.
        half_w = max(max(cx, f.width - cx) for fr in anims.values() for f, cx, _ in fr)
        cell_w = int(np.ceil(2 * half_w)) + 2 * PAD
        cell_h = max(f.height for fr in anims.values() for f, _, _ in fr) + PAD
        standing_h = float(np.median([h for _, _, h in anims["idle"]]))

        out_w, out_h = int(round(cell_w * DOWNSCALE)), int(round(cell_h * DOWNSCALE))
        for anim, fr in anims.items():
            strip = Image.new("RGBA", (cell_w * len(fr), cell_h), (0, 0, 0, 0))
            for i, (f, cx, _) in enumerate(fr):
                x = int(round(i * cell_w + cell_w / 2 - cx))
                strip.alpha_composite(f, (x, cell_h - f.height))
            small = strip.resize((out_w * len(fr), out_h), Image.BOX)
            a = np.asarray(small).copy()
            a[..., 3] = np.where(a[..., 3] > 110, 255, 0)  # crisp edges, no halo
            small = Image.fromarray(a, "RGBA")
            small.save(units_dir / f"stone_{sprite}_{anim}.png")
            red = np.asarray(small).astype(float)
            red[..., 1] *= 0.80
            red[..., 2] *= 0.74
            red[..., 0] = np.minimum(255, red[..., 0] * 1.06 + 8)
            Image.fromarray(red.astype(np.uint8), "RGBA").save(units_dir / f"stone_{sprite}_{anim}_red.png")
            if anim == "idle":
                previews.append(small)

        # Portrait icon: top of the first idle frame on a dark tile.
        f, cx, _ = anims["idle"][0]
        side = int(min(f.width, f.height) * 0.78)
        left = int(max(0, min(f.width - side, cx - side / 2)))
        portrait = f.crop((left, 0, left + side, side)).resize((112, 112), Image.BOX)
        icon = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        icon.alpha_composite(portrait, (8, 12))
        icon.save(icons_dir / f"icon_{sprite}.png")

        draw_scale = target_h / (standing_h * DOWNSCALE)
        print(f'{sprite:10s} frame {out_w}x{out_h}  drawScale {draw_scale:.3f}')

    if preview and previews:
        w = max(p.width for p in previews)
        sheet = Image.new("RGBA", (w, sum(p.height for p in previews)), (40, 60, 80, 255))
        y = 0
        for p in previews:
            sheet.alpha_composite(p, (0, y))
            y += p.height
        sheet.save(preview)


if __name__ == "__main__":
    main()
