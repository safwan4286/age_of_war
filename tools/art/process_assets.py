#!/usr/bin/env python3
"""Turns the Gemini asset sheets in tools/art/source/assets/ into game files.

  background_sky.png        -> bg/stone_sky.png          (watermark patched)
  background_hills.png      -> bg/stone_hills.png        (checkerboard removed)
  background_near.png       -> bg/stone_near.png         (bush hedge + painted dirt lane)
  cave_base.png             -> bases/stone_base[_red].png
  rock_thrower_turret.png   -> bases/stone_turret[_fire][_red].png, fx/rock.png, icons/icon_turret.png
  meteor.png                -> fx/meteor.png, icons/icon_meteor.png
  unit_icons.png            -> icons/icon_<unit>.png

Run after slice_sheets.py (this overwrites its fallback unit icons).
Usage: python3 tools/art/process_assets.py <assets_dir> <project_root>
"""
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("tools/art/source/assets")
ROOT = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(".")
IMG = ROOT / "assets/images"
rng = random.Random(3)

GROUND_Y = 418   # world y where feet touch, must match Layout.groundY
HORIZON_Y = 335  # back edge of the plain, must match Layout.horizonY
WORLD_W, WORLD_H = 1920, 540


def load(name):
    return np.asarray(Image.open(SRC / name).convert("RGB")).astype(np.int16)


def out(arr, rel):
    p = IMG / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr.astype(np.uint8), "RGBA" if arr.shape[-1] == 4 else "RGB").save(p)


def checker_bg(rgb, from_edges="tblr"):
    """Baked white/grey checkerboard reachable from the given edges."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    cand = (abs(r - g) < 8) & (abs(g - b) < 8) & (rgb.min(-1) > 175)
    lab, _ = ndimage.label(cand)
    seeds = []
    if "t" in from_edges: seeds.append(lab[0])
    if "b" in from_edges: seeds.append(lab[-1])
    if "l" in from_edges: seeds.append(lab[:, 0])
    if "r" in from_edges: seeds.append(lab[:, -1])
    ids = np.unique(np.concatenate(seeds))
    return np.isin(lab, ids[ids > 0])


def solid_bg(rgb, tol=26):
    """Solid background reachable from the border (dark stones inside an
    object that happen to match the background colour are kept)."""
    corner = np.median(np.concatenate([rgb[:6, :6].reshape(-1, 3), rgb[-6:, -6:].reshape(-1, 3)]), 0)
    cand = np.sqrt(((rgb - corner) ** 2).sum(-1)) < tol
    lab, _ = ndimage.label(cand)
    ids = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    return np.isin(lab, ids[ids > 0])


def enclosed_checker(rgb, min_area=40):
    """Checkerboard seen through holes (windows, gaps between fence posts):
    neutral light-grey/white patches not connected to the border."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    cand = (abs(r - g) < 5) & (abs(g - b) < 5) & (rgb.min(-1) > 185)
    lab, n = ndimage.label(cand)
    sizes = ndimage.sum(cand, lab, range(1, n + 1))
    big = np.isin(lab, np.nonzero(sizes >= min_area)[0] + 1)
    return big


def rgba(rgb, bg):
    """Opaque where not background; drops specks and soft halo pixels."""
    fg = ndimage.binary_opening(~bg, iterations=1)
    a = np.where(fg, 255, 0)
    return np.dstack([rgb, a]).astype(np.int16)


def clean_edges(arr, min_area=300, passes=3):
    """Removes checkerboard leftovers: isolated specks and the pale
    fringe along cut-out edges."""
    arr = arr.copy()
    a = arr[..., 3] > 0
    lab, n = ndimage.label(a)
    if n:
        sizes = ndimage.sum(a, lab, range(1, n + 1))
        a &= np.isin(lab, np.nonzero(sizes >= min_area)[0] + 1)
    rgb = arr[..., :3]
    pale = (rgb.min(-1) > 150) & (rgb.max(-1) - rgb.min(-1) < 34)
    for _ in range(passes):
        edge = a & ~ndimage.binary_erosion(a, iterations=1, border_value=1)
        a &= ~(edge & pale)
    arr[..., 3] = np.where(a, 255, 0)
    return arr


def crop_alpha(arr, pad=2):
    ys, xs = np.nonzero(arr[..., 3])
    return arr[max(0, ys.min() - pad):ys.max() + 1 + pad, max(0, xs.min() - pad):xs.max() + 1 + pad]


def keep_component(arr, x, y, grow=3):
    """Keep only the opaque blob around (x, y) (plus anything within `grow` px)."""
    a = arr[..., 3] > 0
    lab, _ = ndimage.label(ndimage.binary_dilation(a, iterations=grow))
    keep = (lab == lab[y, x]) & a
    res = arr.copy()
    res[..., 3] = np.where(keep, 255, 0)
    return res


def patch(rgb, box, dx):
    """Clone-stamp `box` from the same rows `dx` px to the left (removes the
    corner sparkle without leaving a hole)."""
    x0, y0, x1, y1 = box
    x1, y1 = min(x1, rgb.shape[1]), min(y1, rgb.shape[0])
    rgb = rgb.copy()
    rgb[y0:y1, x0:x1] = rgb[y0:y1, x0 - dx:x1 - dx]
    return rgb


def sparkle_box(rgb, region):
    """Find the light, grey, star-shaped watermark inside region (x0,y0,x1,y1)."""
    x0, y0, x1, y1 = region
    sub = rgb[y0:y1, x0:x1]
    r, g, b = sub[..., 0], sub[..., 1], sub[..., 2]
    light = (sub.min(-1) > 150) & (sub.max(-1) - sub.min(-1) < 40)
    lab, n = ndimage.label(ndimage.binary_dilation(light, iterations=2))
    best = None
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        h, w = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
        if 14 <= h <= 90 and 14 <= w <= 90 and abs(h - w) < 18:
            area = (lab[sl] == i).sum()
            if best is None or area > best[0]:
                best = (area, sl)
    if best is None:
        return None
    sl = best[1]
    m = 6
    return (x0 + sl[1].start - m, y0 + sl[0].start - m, x0 + sl[1].stop + m, y0 + sl[0].stop + m)


def red_variant(arr):
    """Enemy colours: blue war paint -> red, everything slightly warmer."""
    a = arr.astype(float).copy()
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    blue = (b > r + 25) & (b > g + 10)
    nr, ng, nb = b * 1.05 + 20, g * 0.45, r * 0.5
    a[..., 0] = np.where(blue, nr, r)
    a[..., 1] = np.where(blue, ng, g)
    a[..., 2] = np.where(blue, nb, b)
    return np.clip(a, 0, 255)


def flipx(arr):
    return arr[:, ::-1]


# ---------------------------------------------------------------- layers
def sky():
    rgb = load("background_sky.png")
    box = sparkle_box(rgb, (1600, 300, rgb.shape[1], rgb.shape[0]))
    if box:
        rgb = patch(rgb, box, box[2] - box[0] + 12)
    out(np.dstack([rgb, np.full(rgb.shape[:2], 255)]), "bg/stone_sky.png")


def hills():
    rgb = load("background_hills.png")
    box = sparkle_box(rgb, (1600, 300, rgb.shape[1], rgb.shape[0]))
    if box:
        rgb = patch(rgb, box, box[2] - box[0] + 12)
    arr = clean_edges(rgba(rgb, checker_bg(rgb, "t")))
    out(arr, "bg/stone_hills.png")
    return rgb


def near(hills_rgb):
    """Bush hedge (from background_near) behind a painted dirt lane."""
    src = load("background_near.png")
    h, w = src.shape[:2]
    bg = checker_bg(src, "lr") | enclosed_checker(src, min_area=6)
    masked = np.where(bg[..., None], 0, src)  # don't mistake checker squares for the sparkle
    box = sparkle_box(masked, (1600, 300, w, h))
    if box:
        src = patch(src, box, box[2] - box[0] + 12)
    # Leaves blended into the white checker leave pale, washed-out pixels;
    # real foliage here is never that light, so treat them as background.
    pale = (src.min(-1) > 140) & (src.max(-1) - src.min(-1) < 80)
    full = clean_edges(rgba(src, bg | pale), min_area=60)
    # Bottom bushes only (the hanging canopy at the top is dropped).
    mid = h // 2
    bushes = full[mid:].copy()
    # Remove anything still connected to the canopy above.
    bushes = crop_alpha(bushes, 0)

    canvas = np.zeros((WORLD_H, w, 4), np.int16)
    # Hedge: its foot sits just below the horizon line.
    bh = min(bushes.shape[0], HORIZON_Y + 30)
    bsrc = bushes[-bh:, :w]
    top = HORIZON_Y + 24 - bh
    region = canvas[top:top + bh, :bsrc.shape[1]]
    canvas[top:top + bh, :bsrc.shape[1]] = np.where(bsrc[..., 3:4] > 0, bsrc, region)

    # The plain: calm light sand from the horizon to the bottom edge, so
    # units read clearly (placeholder until the ground layer art arrives).
    plain = Image.new("RGBA", (w, WORLD_H - HORIZON_Y), (0, 0, 0, 0))
    d = ImageDraw.Draw(plain)
    ph = plain.height
    for y in range(ph):
        t = y / ph
        c = (int(222 - 22 * t), int(198 - 26 * t), int(140 - 26 * t), 255)
        d.line([(0, y), (w, y)], fill=c)
    patches = Image.new("RGBA", plain.size, (0, 0, 0, 0))  # soft darker sand
    pd = ImageDraw.Draw(patches)
    for _ in range(26):
        cx, cy = rng.randrange(w), rng.randrange(10, ph)
        rx, ry = rng.randint(60, 180), rng.randint(6, 16)
        pd.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(186, 158, 100, 70))
    plain.alpha_composite(patches)
    d = ImageDraw.Draw(plain)
    for _ in range(140):  # pebbles with an outline, cartoon style
        cx, cy = rng.randrange(w), rng.randrange(6, ph)
        r = rng.choice([2, 2, 3, 3, 4, 5])
        d.ellipse([cx - r, cy - r * 0.7, cx + r, cy + r * 0.7], fill=(150, 140, 128, 255), outline=(92, 78, 62, 255))
    # Back edge: a strip of grass tufts where the plain meets the hedge.
    d.rectangle([0, 0, w, 3], fill=(116, 150, 70, 255))
    for x in range(0, w, 5):
        h = rng.randint(3, 9)
        d.line([(x, 3), (x + rng.randint(-2, 2), 3 + h)], fill=(104, 140, 62, 255), width=2)
    arr = np.asarray(plain).astype(np.int16)
    region = canvas[HORIZON_Y:]
    canvas[HORIZON_Y:] = np.where(arr[..., 3:4] > 0, arr, region)
    out(canvas, "bg/stone_near.png")


# ------------------------------------------------------------ cave/turret
def cave():
    rgb = load("cave_base.png")
    arr = rgba(rgb, checker_bg(rgb) | enclosed_checker(rgb))
    arr = keep_component(arr, 400, 600, grow=4)  # drops the corner sparkle
    arr = crop_alpha(arr)
    out(arr, "bases/stone_base.png")
    out(red_variant(arr), "bases/stone_base_red.png")


def sheet_cell(rgb, bg, cx, cy, half=95):
    """Cut the blob nearest (cx, cy) on a solid-background sheet."""
    arr = rgba(rgb, bg)
    x0, y0 = max(0, cx - half), max(0, cy - half)
    sub = arr[y0:cy + half, x0:cx + half].copy()
    ys, xs = np.nonzero(sub[..., 3])
    # Blob closest to the cell centre.
    a = sub[..., 3] > 0
    lab, _ = ndimage.label(ndimage.binary_dilation(a, iterations=2))
    cid = lab[min(sub.shape[0] - 1, half), min(sub.shape[1] - 1, half)]
    if cid == 0:
        d = ndimage.distance_transform_edt(lab == 0, return_indices=True)[1]
        cid = lab[d[0][half, half], d[1][half, half]]
    sub[..., 3] = np.where((lab == cid) & a, 255, 0)
    return crop_alpha(sub)


def turret():
    rgb = load("rock_thrower_turret.png")
    bg = solid_bg(rgb, 24)
    loaded = sheet_cell(rgb, bg, 118, 120)
    fired = sheet_cell(rgb, bg, 305, 495)
    icon_src = loaded
    # Same canvas for both frames, aligned on the stone base (bottom centre).
    W = max(loaded.shape[1], fired.shape[1])
    H = max(loaded.shape[0], fired.shape[0])
    def place(a):
        c = np.zeros((H, W, 4), np.int16)
        x = (W - a.shape[1]) // 2
        c[H - a.shape[0]:, x:x + a.shape[1]] = a
        return c
    loaded, fired = place(loaded), place(fired)
    for name, a in [("stone_turret", loaded), ("stone_turret_fire", fired)]:
        out(a, f"bases/{name}.png")
        out(red_variant(a), f"bases/{name}_red.png")
    rock = sheet_cell(rgb, bg, 770, 450, half=40)
    rock = crop_alpha(rock[:, -rock.shape[0]:], 0)  # the stone, not its motion streak
    out(rock, "fx/rock.png")
    k = 120 / max(icon_src.shape[:2])
    small = np.asarray(Image.fromarray(icon_src.astype(np.uint8), "RGBA").resize(
        (round(icon_src.shape[1] * k), round(icon_src.shape[0] * k)), Image.BOX)).astype(np.int16)
    icon = np.zeros((128, 128, 4), np.int16)
    y, x = 128 - small.shape[0] - 4, (128 - small.shape[1]) // 2
    icon[y:y + small.shape[0], x:x + small.shape[1]] = small
    out(icon, "icons/icon_turret.png")


# ----------------------------------------------------------- meteor/icons
def ring_icon(rgb, cx, cy, r, size=128):
    """Circular medallion (ring included), outside of it transparent."""
    sub = rgb[cy - r:cy + r, cx - r:cx + r]
    yy, xx = np.mgrid[:2 * r, :2 * r]
    inside = (yy - r) ** 2 + (xx - r) ** 2 <= (r - 1) ** 2
    arr = np.dstack([sub, np.where(inside, 255, 0)])
    return np.asarray(Image.fromarray(arr.astype(np.uint8), "RGBA").resize((size, size), Image.BOX)).astype(np.int16)


def meteor():
    rgb = load("meteor.png")
    out(ring_icon(rgb, 296, 318, 252), "icons/icon_meteor.png")
    # Small meteor (top right) sits well inside its ring: cut it out.
    cx, cy, r = 1183, 203, 120
    sub = rgb[cy - r:cy + r, cx - r:cx + r]
    bg = solid_bg(sub, 30)
    yy, xx = np.mgrid[:2 * r, :2 * r]
    bg |= (yy - r) ** 2 + (xx - r) ** 2 > (r - 22) ** 2
    arr = crop_alpha(rgba(sub, bg))
    out(arr, "fx/meteor.png")


def unit_icons():
    rgb = load("unit_icons.png")
    for sprite, (cx, cy, r) in {
        "clubman": (296, 318, 252),
        "slinger": (778, 203, 168),
        "dinorider": (783, 558, 168),
        "chief": (1188, 558, 168),
    }.items():
        out(ring_icon(rgb, cx, cy, r), f"icons/icon_{sprite}.png")


if __name__ == "__main__":
    sky()
    near(hills())
    cave()
    turret()
    meteor()
    unit_icons()
    print("assets processed")
