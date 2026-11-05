#!/usr/bin/env python3
"""Builds the Medieval Age world art from the sheets in
tools/art/source/medieval/world/ (all 1376x768, on solid magenta except
the sky):

  medieval_base.png     side-on castle, gate on the right
  ballista_loaded.png   ballista, string drawn back, bolt ready
  ballista_fired.png    same ballista after the shot
  medieval_sky.png      dusk sky
  medieval_hills.png    cliffs, ruined tower, dead trees (magenta above)
  medieval_ground.png   broken fence + packed dirt (magenta above)
  medieval_effects.png  bolt, arrow, fire arrow / 4 dust-burst frames
  medieval_icons.png    4x2 icon sheet

Writes assets/images/{bases,bg,fx,icons}/medieval_* and the castle's gate,
turret spots, turret width and wall repeat into the medieval era of
assets/data/units.json.

The castle's turret spots can't be found automatically (stone battlements,
no plank ledges), so they are measured by hand on the source picture
below (SLOTS_PX, GATE_PX). Change them if the castle art changes.

Usage: python3 tools/art/build_world_medieval.py <project_root>
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

from build_world import (PX_PER_WORLD, fit_h, grey_smoke, key, key_soft, magenta, red,
                         remove_sparkle, rgba_from, side_crop, trim)

# Measured on medieval_base.png (1376x768): where each ballista stands
# (centre x, floor y), lowest first because slot 0 is built first.
SLOTS_PX = [(1185, 418), (948, 305), (842, 172)]
# Centre of the gate arch: units come out here.
GATE_PX = 1235
# A plain stretch of wall + roofs, repeated (mirrored) behind the castle.
WALL_PX = (104, 515)
# Drawn castle height in world units, and the ballista's width.
CASTLE_H = 380
BALLISTA_W = 150


def castle(src, bases, art):
    raw = remove_sparkle(Image.open(src / "medieval_base.png").convert("RGB"))
    base = key(raw, open_iter=1, min_area=5000)
    x0, y0, x1, y1 = base.getchannel("A").getbbox()
    base = base.crop((x0, y0, x1, y1))
    w, h = base.size
    art["height"] = CASTLE_H
    art["gate"] = round((GATE_PX - x0) / w, 3)
    art["slots"] = [[round((x - x0) / w, 3), round((y - y0) / h, 3)] for x, y in SLOTS_PX]
    draw_w = CASTLE_H * w / h
    art["turretW"] = round(BALLISTA_W / draw_w, 3)
    art["ledgeW"] = art["turretW"]
    wf0, wf1 = (WALL_PX[0] - x0) / w, (WALL_PX[1] - x0) / w
    art["cliff"] = [round(wf0, 3), round(wf1, 3)]
    out = fit_h(base, CASTLE_H * PX_PER_WORLD)
    # Left of the wall strip the source is cut mid-tower; the repeated
    # wall covers that part in game, so drop it (towers there would poke
    # out above the wall).
    a = np.asarray(out).copy()
    a[:, :round(wf0 * out.width), 3] = 0
    out = Image.fromarray(a, "RGBA")
    out.save(bases / "medieval_base.png")
    red(out).save(bases / "medieval_base_red.png")
    wall = out.crop((round(wf0 * out.width), 0, round(wf1 * out.width), out.height))
    wall.save(bases / "medieval_cliff.png")
    red(wall).save(bases / "medieval_cliff_red.png")
    print("castle", base.size, "gate", art["gate"], "slots", art["slots"], "turretW", art["turretW"])


def erase_rest_string(img: Image.Image) -> Image.Image:
    """The loaded ballista also shows the string's resting line (a straight
    vertical cord inside the bow) besides the drawn-back string. Remove it:
    over magenta it becomes magenta, across the beam each row is blended
    from the wood on either side."""
    a = np.asarray(img.convert("RGB")).astype(int).copy()
    h, w = a.shape[:2]
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    tan = (r > 150) & (g > 120) & (b < 150) & (r - b > 50)
    # The cord: the tan column inside the bow on the right, long and thin.
    cols = tan[int(h * 0.2):int(h * 0.75), w // 2:].sum(0)
    cx = w // 2 + int(cols.argmax())
    xa, xb = cx - 9, cx + 10
    mag = magenta(a)
    rows = np.arange(int(h * 0.16), int(h * 0.78))
    for y in rows:
        left, right = a[y, xa - 1], a[y, xb]
        if mag[y, xa - 1] and mag[y, xb]:
            a[y, xa:xb] = (255, 0, 255)
        elif not mag[y, xa - 1] and not mag[y, xb]:
            t = np.linspace(0, 1, xb - xa)[:, None]
            a[y, xa:xb] = (left * (1 - t) + right * t).astype(int)
    print("rest string at x", cx)
    return Image.fromarray(a.astype(np.uint8), "RGB")


def ballista(src, bases):
    poses = []
    for name in ["ballista_loaded", "ballista_fired"]:
        im = remove_sparkle(Image.open(src / f"{name}.png").convert("RGB"))
        if name == "ballista_loaded":
            im = erase_rest_string(im)
        p = key(im, open_iter=1, min_area=3000)
        a = np.asarray(p)[..., 3] > 0
        ys, xs = np.nonzero(a)
        bot = ys.max()
        plank = np.nonzero(a[bot - 6])[0]
        poses.append((p, (plank.min() + plank.max()) / 2, bot))
    # One cell for both poses, the base plank centred and on the bottom.
    left = max(cx - np.nonzero(np.asarray(p)[..., 3].any(0))[0].min() for p, cx, _ in poses)
    right = max(np.nonzero(np.asarray(p)[..., 3].any(0))[0].max() - cx for p, cx, _ in poses)
    top = max(bot - np.nonzero(np.asarray(p)[..., 3].any(1))[0].min() for p, _, bot in poses)
    half_w = int(max(left, right)) + 2
    cw, ch = 2 * half_w, int(top) + 2
    px_w = BALLISTA_W * PX_PER_WORLD
    for (p, cx, bot), name in zip(poses, ["medieval_turret", "medieval_turret_fire"]):
        c = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        c.alpha_composite(p, (int(round(half_w - cx)), int(ch - 1 - bot)))
        o = c.resize((px_w, round(ch * px_w / cw)), Image.LANCZOS)
        o.save(bases / f"{name}.png")
        red(o).save(bases / f"{name}_red.png")
    print("ballista cell", cw, ch)


def layers(src, bg):
    sky = side_crop(remove_sparkle(Image.open(src / "medieval_sky.png").convert("RGB")))
    hills = side_crop(grey_smoke(key_soft(remove_sparkle(Image.open(src / "medieval_hills.png").convert("RGB")))))
    near = side_crop(key(remove_sparkle(Image.open(src / "medieval_ground.png").convert("RGB")), open_iter=0))
    return sky, hills, near


def write_layers(src, bg, places):
    sky, hills, near = layers(src, bg)
    for img, name in [(sky, "sky"), (hills, "hills"), (near, "near")]:
        fit_h(img, places[name]["height"] * PX_PER_WORLD).save(bg / f"medieval_{name}.png")


def blobs(img: Image.Image, y0, y1, n, join=14):
    """The n biggest separate drawings between rows y0 and y1, left to
    right (nearby specks such as splinters join their drawing)."""
    band = img.crop((0, y0, img.width, y1))
    a = np.asarray(band)[..., 3] > 0
    lab, k = ndimage.label(ndimage.binary_dilation(a, iterations=join))
    sizes = ndimage.sum(a, lab, range(1, k + 1))
    ids = sorted(range(1, k + 1), key=lambda i: -sizes[i - 1])[:n]
    out = []
    for i in ids:
        m = (lab == i) & a
        piece = np.asarray(band).copy()
        piece[..., 3] = np.where(m, piece[..., 3], 0)
        p = Image.fromarray(piece, "RGBA")
        sl = ndimage.find_objects((lab == i).astype(int))[0]
        out.append((sl[1].start, trim(p)))
    return [p for _, p in sorted(out, key=lambda t: t[0])]


def effects(src, fx):
    raw = remove_sparkle(Image.open(src / "medieval_effects.png").convert("RGB"))
    soft = grey_smoke(key_soft(raw))
    h = soft.height
    bolt, arrow, fire = blobs(soft, 0, h // 2, 3)
    fit_h(bolt, 40).save(fx / "medieval_bolt.png")
    fit_h(arrow, 24).save(fx / "medieval_arrow.png")
    # The game wants the falling shot heading down-left (like the meteor).
    fire = fire.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    fire.resize((192, round(fire.height * 192 / fire.width)), Image.LANCZOS).save(fx / "medieval_firearrow.png")
    frames = blobs(soft, h // 2, h, 4)
    # Square frames side by side, all standing on one ground line.
    side = max(max(f.width, f.height) for f in frames)
    S = 192
    strip = Image.new("RGBA", (S * len(frames), S), (0, 0, 0, 0))
    for k, f in enumerate(frames):
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.alpha_composite(f, ((side - f.width) // 2, side - f.height))
        strip.alpha_composite(sq.resize((S, S), Image.LANCZOS), (k * S, 0))
    strip.save(fx / "medieval_blast.png")
    print("fx sizes", bolt.size, arrow.size, fire.size, [f.size for f in frames])


def icons(src, root):
    """Picks from the 4x2 sheet: (col, row) -> file. The evolve tower's
    yellow glow blends into the magenta; that pink haze is dropped and the
    HUD draws its own glow."""
    f = Image.open(src / "medieval_icons.png").convert("RGB")
    gw, gh = f.width // 4, f.height // 2
    picks = {(0, 0): "icon_arrowrain", (1, 1): "icon_ballista", (2, 0): "icon_evolve_medieval",
             (3, 0): "icon_medieval"}
    for (c, r), name in picks.items():
        rgb = np.asarray(f.crop((c * gw, r * gh, (c + 1) * gw, (r + 1) * gh))).astype(int)
        rr, gg, bb = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        tint = (rr - gg > 40) & (bb - gg > 15)
        lab, _ = ndimage.label(tint)
        edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
        pure = magenta(rgb)
        bg = np.isin(lab, list(edge)) | pure
        fg = ndimage.binary_opening(~bg, iterations=1)
        lab2, n = ndimage.label(fg)
        sizes = ndimage.sum(fg, lab2, range(1, n + 1))
        keep = np.isin(lab2, [i + 1 for i, s in enumerate(sizes) if s >= 0.01 * sizes.max()])
        icon = trim(rgba_from(rgb, keep))
        side = max(icon.size)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.alpha_composite(icon, ((side - icon.width) // 2, (side - icon.height) // 2))
        sq.resize((256, 256), Image.LANCZOS).save(root / "assets/images/icons" / f"{name}.png")


def main():
    root = Path(sys.argv[1])
    src = root / "tools/art/source/medieval/world"
    out = {k: root / "assets/images" / k for k in ("bases", "bg", "fx", "icons")}
    for d in out.values():
        d.mkdir(parents=True, exist_ok=True)
    data_path = root / "assets/data/units.json"
    data = json.loads(data_path.read_text())
    era = next(e for e in data["eras"] if e["id"] == "medieval")
    art = era.setdefault("base", {}).setdefault("art", {})
    castle(src, out["bases"], art)
    ballista(src, out["bases"])
    write_layers(src, out["bg"], era["world"]["layers"])
    effects(src, out["fx"])
    icons(src, root)
    data_path.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    main()
