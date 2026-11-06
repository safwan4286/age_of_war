#!/usr/bin/env python3
"""Builds the Gunpowder Age world art from the sheets in
tools/art/source/gunpowder/world/ (all 1376x768, on solid magenta except
the sky):

  gunpowder_base.png     coastal star fort, red brick, gate on the right
  cannon_loaded.png      bronze fortress cannon on its carriage
  cannon_fired.png       same cannon firing (flash runs off the edge)
  gunpowder_sky.png      sunny sky
  gunpowder_hills.png    chalk cliffs, sea, lighthouse (magenta above)
  gunpowder_ground.png   sandy road + rope fence (magenta above)
  gunpowder_effects.png  musket ball, cannonball, flaming cannonball /
                         4 explosion frames
  gunpowder_icons.png    4x2 icon sheet

Writes assets/images/{bases,bg,fx,icons}/gunpowder_* (+ icons). The age
isn't in units.json yet, so the fort's gate, turret spots, turret width
and wall repeat go to tools/art/source/gunpowder/world/gunpowder_era.json,
to merge when the age is switched on.

The gun decks are measured by hand on the source picture (SLOTS_PX,
GATE_PX); change them if the fort art changes.

Usage: python3 tools/art/build_world_gunpowder.py <project_root>
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

from build_world import PX_PER_WORLD, fit_h, grey_smoke, key, key_soft, red, side_crop, trim
from build_world_medieval import blobs

# Measured on gunpowder_base.png (1376x768): each gun deck's centre x and
# floor y, lowest first (slot 0 is built first).
SLOTS_PX = [(1070, 445), (846, 350), (578, 245)]
# Centre of the gate doors: units come out here.
GATE_PX = 1098
# Plain brick wall left of the top gun mound, repeated (mirrored) behind the fort.
WALL_PX = (8, 300)
# Drawn fort height in world units (same as the medieval castle) and the
# turret cell's width (the fired pose's flash makes the cell wider than
# the cannon itself).
CASTLE_H = 380
CANNON_W = 150
# Gemini's star watermark: a fixed half-transparent white star at this
# spot of every 1376x768 picture (alpha measured once, on plain magenta).
MARK = Path(__file__).parent / "source/gemini_mark_1376x768.png"
MARK_AT = (612, 1210)  # top, left
# Same layer placement as the medieval world.
LAYERS = {"sky": {"top": -140, "height": 690}, "hills": {"top": 10, "height": 460},
          "near": {"top": 177, "height": 420}}


def unmark(img: Image.Image) -> Image.Image:
    """Removes the watermark exactly: the star was blended white over the
    picture, so the original is (seen - a*255) / (1 - a)."""
    a = np.asarray(img.convert("RGB")).astype(float).copy()
    al = np.asarray(Image.open(MARK)).astype(float)[..., None] / 255
    y, x = MARK_AT
    h, w = al.shape[:2]
    reg = a[y:y + h, x:x + w]
    a[y:y + h, x:x + w] = (reg - al * 255) / (1 - al)
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGB")


def load(src, name) -> Image.Image:
    return unmark(Image.open(src / f"{name}.png"))


def fort(src, bases, art):
    raw = load(src, "gunpowder_base")
    base = key(raw, open_iter=1, min_area=5000)
    x0, y0, x1, y1 = base.getchannel("A").getbbox()
    base = base.crop((x0, y0, x1, y1))
    w, h = base.size
    art["height"] = CASTLE_H
    art["gate"] = round((GATE_PX - x0) / w, 3)
    art["slots"] = [[round((x - x0) / w, 3), round((y - y0) / h, 3)] for x, y in SLOTS_PX]
    draw_w = CASTLE_H * w / h
    art["turretW"] = round(CANNON_W / draw_w, 3)
    art["ledgeW"] = art["turretW"]
    wf0, wf1 = (WALL_PX[0] - x0) / w, (WALL_PX[1] - x0) / w
    art["cliff"] = [round(wf0, 3), round(wf1, 3)]
    out = fit_h(base, CASTLE_H * PX_PER_WORLD)
    a = np.asarray(out).copy()
    a[:, :round(wf0 * out.width), 3] = 0
    out = Image.fromarray(a, "RGBA")
    out.save(bases / "gunpowder_base.png")
    red(out).save(bases / "gunpowder_base_red.png")
    wall = out.crop((round(wf0 * out.width), 0, round(wf1 * out.width), out.height))
    wall.save(bases / "gunpowder_cliff.png")
    red(wall).save(bases / "gunpowder_cliff_red.png")
    print("fort", base.size, "gate", art["gate"], "slots", art["slots"], "turretW", art["turretW"])


def fade_right(img: Image.Image, px=28) -> Image.Image:
    """The fired cannon's flash and smoke run off the picture's right edge:
    fade them out over the last px columns so no straight cut shows."""
    a = np.asarray(img).copy()
    w = a.shape[1]
    ramp = np.clip((w - 1 - np.arange(w)) / px, 0, 1)
    a[..., 3] = (a[..., 3] * ramp[None, :]).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def cannon(src, bases):
    poses = []
    for name in ["cannon_loaded", "cannon_fired"]:
        im = load(src, name)
        p = grey_smoke(key_soft(im)) if name == "cannon_fired" else key(im, open_iter=1, min_area=3000)
        if name == "cannon_fired":
            p = fade_right(p)
        a = np.asarray(p)[..., 3] > 0
        ys, xs = np.nonzero(a)
        bot = ys.max()
        plank = np.nonzero(a[bot - 6])[0]
        poses.append((p, (plank.min() + plank.max()) / 2, bot))
    left = max(cx - np.nonzero(np.asarray(p)[..., 3].any(0))[0].min() for p, cx, _ in poses)
    right = max(np.nonzero(np.asarray(p)[..., 3].any(0))[0].max() - cx for p, cx, _ in poses)
    top = max(bot - np.nonzero(np.asarray(p)[..., 3].any(1))[0].min() for p, _, bot in poses)
    half_w = int(max(left, right)) + 2
    cw, ch = 2 * half_w, int(top) + 2
    px_w = CANNON_W * PX_PER_WORLD
    for (p, cx, bot), name in zip(poses, ["gunpowder_turret", "gunpowder_turret_fire"]):
        c = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        c.alpha_composite(p, (int(round(half_w - cx)), int(ch - 1 - bot)))
        o = c.resize((px_w, round(ch * px_w / cw)), Image.LANCZOS)
        o.save(bases / f"{name}.png")
        red(o).save(bases / f"{name}_red.png")
    print("cannon cell", cw, ch)


def layers(src, bg):
    sky = side_crop(load(src, "gunpowder_sky"))
    hills = side_crop(key(load(src, "gunpowder_hills"), open_iter=0))
    near = side_crop(key(load(src, "gunpowder_ground"), open_iter=0))
    for img, name in [(sky, "sky"), (hills, "hills"), (near, "near")]:
        fit_h(img, LAYERS[name]["height"] * PX_PER_WORLD).save(bg / f"gunpowder_{name}.png")


def effects(src, fx):
    raw = load(src, "gunpowder_effects")
    soft = grey_smoke(key_soft(raw))
    h = soft.height
    ball, cball, fire = blobs(soft, 0, h // 2, 3)
    fit_h(ball, 14).save(fx / "gunpowder_ball.png")
    fit_h(cball, 36).save(fx / "gunpowder_cannonball.png")
    # The game wants the falling shot heading down-left (like the meteor).
    fire = fire.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    fire.resize((192, round(fire.height * 192 / fire.width)), Image.LANCZOS).save(fx / "gunpowder_fireball.png")
    # The last frame is loose puffs, so cut the bottom row by columns.
    cols = [(0, 300), (300, 680), (680, 1070), (1070, soft.width)]
    frames = [trim(soft.crop((x0, h // 2, x1, h))) for x0, x1 in cols]
    side = max(max(f.width, f.height) for f in frames)
    S = 192
    strip = Image.new("RGBA", (S * len(frames), S), (0, 0, 0, 0))
    for k, f in enumerate(frames):
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.alpha_composite(f, ((side - f.width) // 2, side - f.height))
        strip.alpha_composite(sq.resize((S, S), Image.LANCZOS), (k * S, 0))
    strip.save(fx / "gunpowder_blast.png")
    print("fx sizes", ball.size, cball.size, fire.size, [f.size for f in frames])


def icons(sheet, root, picks):
    """Same cleanup as the medieval icon sheet, own picks: (col, row) -> file."""
    from scipy import ndimage
    from build_world import magenta, rgba_from
    f = unmark(Image.open(sheet))
    gw, gh = f.width // 4, f.height // 2
    for (c, r), name in picks.items():
        # A pick is a grid cell, or (name, box) when the drawing pokes out
        # of its cell (the long cannon barrel).
        box = (c * gw, r * gh, (c + 1) * gw, (r + 1) * gh)
        if isinstance(name, tuple):
            name, box = name
        rgb = np.asarray(f.crop(box)).astype(int)
        rr, gg, bb = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        tint = (rr - gg > 40) & (bb - gg > 15)
        lab, _ = ndimage.label(tint)
        edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
        bg = np.isin(lab, list(edge)) | magenta(rgb)
        fg = ndimage.binary_opening(~bg, iterations=1)
        lab2, n = ndimage.label(fg)
        sizes = ndimage.sum(fg, lab2, range(1, n + 1))
        # Pieces cut off at the cell's edge belong to the neighbour icon.
        touch = set(np.unique(np.concatenate([lab2[0], lab2[-1], lab2[:, 0], lab2[:, -1]]))) - {0}
        big = int(np.argmax(sizes)) + 1
        keep = np.isin(lab2, [i + 1 for i, s in enumerate(sizes)
                              if s >= 0.01 * sizes.max() and (i + 1 not in touch or i + 1 == big)])
        icon = trim(rgba_from(rgb, keep))
        side = max(icon.size)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.alpha_composite(icon, ((side - icon.width) // 2, (side - icon.height) // 2))
        sq.resize((256, 256), Image.LANCZOS).save(root / "assets/images/icons" / f"{name}.png")


def main():
    root = Path(sys.argv[1])
    src = root / "tools/art/source/gunpowder/world"
    out = {k: root / "assets/images" / k for k in ("bases", "bg", "fx", "icons")}
    for d in out.values():
        d.mkdir(parents=True, exist_ok=True)
    art = {}
    fort(src, out["bases"], art)
    cannon(src, out["bases"])
    layers(src, out["bg"])
    effects(src, out["fx"])
    icons(src / "gunpowder_icons.png", root, {(0, 1): "icon_cannonbarrage", (1, 0): ("icon_fortcannon", (330, 60, 778, 340)),
                                              (2, 1): "icon_evolve_gunpowder", (3, 1): "icon_gunpowder"})
    era = {"base": {"art": art}, "world": {"layers": LAYERS},
           "icons": {"special": "icon_cannonbarrage", "evolve": "icon_evolve_gunpowder",
                     "turret": "icon_fortcannon"}}
    (src / "gunpowder_era.json").write_text(json.dumps(era, indent=2) + "\n")
    print("age not in the game yet: world data -> gunpowder_era.json")


if __name__ == "__main__":
    main()
