#!/usr/bin/env python3
"""Builds the Modern Age world art from the sheets in
tools/art/source/modern/world/ (all 1376x768, on solid magenta except
the sky):

  modern_base.png      concrete bunker complex, blast door on the right,
                       command tower + radar dish
  rocket_loaded.png    camo rocket launcher pod on its pedestal
  rocket_fired.png     same pod firing (flash ahead, back-blast behind)
  modern_sky_v3.png    smoky war sky, drawn to repeat (in use; the first
                       modern_sky.png showed mirrored clouds at the joins)
  modern_hills.png     ruined city skyline (magenta above)
  modern_ground.png    cracked asphalt road + barriers (magenta above)
  modern_effects.png   bullet, tank shell, rocket, falling bomb /
                       4 explosion frames
  modern_icons.png     4x2 icon sheet

Writes assets/images/{bases,bg,fx,icons}/modern_* (+ icons). The age isn't
in units.json yet, so the base's gate, turret spots, turret width, muzzle
and wall repeat go to tools/art/source/modern/world/modern_era.json, to
merge when the age is switched on.

The gun pads (the sandbag tops of the three stepped blocks) are measured
by hand on the source picture (SLOTS_PX, GATE_PX).

Usage: python3 tools/art/build_world_modern.py <project_root>
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

from build_world import PX_PER_WORLD, fit_h, grey_smoke, key, key_soft, red, side_crop, trim
from build_world_gunpowder import LAYERS, icons, load
from build_world_medieval import blobs

# Measured on modern_base.png (1376x768): each gun pad's centre x and the
# sandbag top it stands on, lowest first (slot 0 is built first).
SLOTS_PX = [(1150, 447), (925, 345), (650, 243)]
# Centre of the blast door: units come out here.
GATE_PX = 1200
# Plain concrete-panel wall on the left, repeated (mirrored) behind the base.
WALL_PX = (10, 330)
# Drawn base height in world units (the radar dish and mast make the
# picture taller than the blocks, so a little more than the castle) and
# the turret cell's width.
CASTLE_H = 400
ROCKET_W = 190


def bunker(src, bases, art):
    base = key(load(src, "modern_base"), open_iter=1, min_area=5000)
    x0, y0, x1, y1 = base.getchannel("A").getbbox()
    base = base.crop((x0, y0, x1, y1))
    w, h = base.size
    art["height"] = CASTLE_H
    art["gate"] = round((GATE_PX - x0) / w, 3)
    art["slots"] = [[round((x - x0) / w, 3), round((y - y0) / h, 3)] for x, y in SLOTS_PX]
    art["turretW"] = round(ROCKET_W / (CASTLE_H * w / h), 3)
    art["ledgeW"] = art["turretW"]
    wf0, wf1 = (WALL_PX[0] - x0) / w, (WALL_PX[1] - x0) / w
    art["cliff"] = [round(wf0, 3), round(wf1, 3)]
    out = fit_h(base, CASTLE_H * PX_PER_WORLD)
    a = np.asarray(out).copy()
    a[:, :round(wf0 * out.width), 3] = 0
    out = Image.fromarray(a, "RGBA")
    out.save(bases / "modern_base.png")
    red(out).save(bases / "modern_base_red.png")
    wall = out.crop((round(wf0 * out.width), 0, round(wf1 * out.width), out.height))
    wall.save(bases / "modern_cliff.png")
    red(wall).save(bases / "modern_cliff_red.png")
    print("bunker", base.size, "gate", art["gate"], "slots", art["slots"], "turretW", art["turretW"])


def drop_ground_line(img: Image.Image, rows=16) -> Image.Image:
    """Gemini drew a thin ground line under the base plate (wider than the
    plate). Thin horizontal strokes in the bottom rows are removed: a pixel
    stays only if a 5-pixel-tall column fits there."""
    a = np.asarray(img).copy()
    m = a[..., 3] > 0
    ys = np.nonzero(m.any(1))[0]
    y1 = ys.max() + 1
    y0 = max(0, y1 - rows)
    band = m[y0 - 4:y1]
    keep = ndimage.binary_opening(band, structure=np.ones((5, 1)))
    a[y0:y1, :, 3] = np.where(keep[4:], a[y0:y1, :, 3], 0)
    return Image.fromarray(a, "RGBA")


def rocket(src, bases, art):
    poses = []
    for name in ["rocket_loaded", "rocket_fired"]:
        im = load(src, name)
        p = grey_smoke(key_soft(im)) if name == "rocket_fired" else key(im, open_iter=1, min_area=3000)
        p = drop_ground_line(p)
        a = np.asarray(p)[..., 3] > 0
        ys, _ = np.nonzero(a)
        bot = ys.max()
        plate = np.nonzero(a[bot - 6])[0]
        poses.append((p, (plate.min() + plate.max()) / 2, bot))
    left = max(cx - np.nonzero(np.asarray(p)[..., 3].any(0))[0].min() for p, cx, _ in poses)
    right = max(np.nonzero(np.asarray(p)[..., 3].any(0))[0].max() - cx for p, cx, _ in poses)
    top = max(bot - np.nonzero(np.asarray(p)[..., 3].any(1))[0].min() for p, _, bot in poses)
    half_w = int(max(left, right)) + 2
    cw, ch = 2 * half_w, int(top) + 2
    px_w = ROCKET_W * PX_PER_WORLD
    for (p, cx, bot), name in zip(poses, ["modern_turret", "modern_turret_fire"]):
        c = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        c.alpha_composite(p, (int(round(half_w - cx)), int(ch - 1 - bot)))
        o = c.resize((px_w, round(ch * px_w / cw)), Image.LANCZOS)
        o.save(bases / f"{name}.png")
        red(o).save(bases / f"{name}_red.png")
    # The rocket leaves the pod's front face: its rightmost column in the
    # top half of the loaded pose, at the middle of the tube grid.
    loaded = np.asarray(Image.open(bases / "modern_turret.png"))[..., 3] > 40
    lh, lw = loaded.shape
    upper = loaded[: lh // 2]
    xr = np.nonzero(upper.any(0))[0].max()
    yy = np.nonzero(upper[:, xr - 8:xr + 1].any(1))[0]
    art["turretMuzzle"] = [round((xr - lw / 2) / lw, 3), round((lh - 1 - (yy.min() + yy.max()) / 2) / lh, 3)]
    print("rocket cell", cw, ch, "muzzle", art["turretMuzzle"])


def wisps(img: Image.Image) -> Image.Image:
    """The thin smoke wisps over the skyline blend into the magenta more
    faintly than grey_smoke expects and stay purple: any pixel still
    leaning purple becomes soft grey smoke (the buildings lean blue, the
    fires orange, so neither is touched)."""
    a = np.asarray(img).astype(float).copy()
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    purple = (al > 0) & (r - g > 10) & (b - g > 10)
    grey = (r + g + b) / 3
    for i, k in enumerate((0.95, 0.96, 1.0)):
        a[..., i] = np.where(purple, grey * k, a[..., i])
    a[..., 3] = np.where(purple, np.minimum(al, 140), al)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def sky_v3(src) -> Image.Image:
    """The sky in use: modern_sky_v3.png, redrawn so it repeats side by
    side (plain sky at both edges, rounded cloud ends, straight smoke), so
    the game tiles it without mirroring ("mirror": false). Its Gemini star
    sits off the usual spot: found against a blurred copy and inpainted."""
    import cv2
    a = np.asarray(Image.open(src / "modern_sky_v3.png").convert("RGB"))
    y0, y1, x0, x1 = 560, 740, 1150, 1376
    reg = a[y0:y1, x0:x1].astype(int)
    blur = cv2.GaussianBlur(a, (0, 0), 25)[y0:y1, x0:x1].astype(int)
    m = cv2.morphologyEx(((reg - blur).sum(2) > 6).astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    full = np.zeros(a.shape[:2], np.uint8)
    full[y0:y1, x0:x1] = cv2.dilate(m, np.ones((13, 13), np.uint8))
    return Image.fromarray(cv2.inpaint(a, full, 13, cv2.INPAINT_TELEA))


def layers(src, bg):
    sky = side_crop(sky_v3(src))
    hills = side_crop(wisps(grey_smoke(key_soft(load(src, "modern_hills")))))
    near = side_crop(key(load(src, "modern_ground"), open_iter=0))
    for img, name in [(sky, "sky"), (hills, "hills"), (near, "near")]:
        fit_h(img, LAYERS[name]["height"] * PX_PER_WORLD).save(bg / f"modern_{name}.png")


def effects(src, fx):
    soft = grey_smoke(key_soft(load(src, "modern_effects")))
    h = soft.height
    bullet, shell, rkt, bomb = blobs(soft, 0, h // 2, 4)
    fit_h(bullet, 8).save(fx / "modern_bullet.png")
    fit_h(shell, 20).save(fx / "modern_shell.png")
    fit_h(rkt, 18).save(fx / "modern_rocket.png")
    # The game wants the falling shot heading down-left (like the meteor).
    bomb = bomb.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    bomb.resize((150, round(bomb.height * 150 / bomb.width)), Image.LANCZOS).save(fx / "modern_bomb.png")
    # Bottom row: the smoke cloud (frame 3) and the loose puffs (frame 4)
    # overlap in x, so split by pieces: the cloud is the piece under
    # (900, 560); the puffs are everything right of it.
    band = np.asarray(soft.crop((0, h // 2, soft.width, h)))
    m = band[..., 3] > 0
    lab, _ = ndimage.label(ndimage.binary_dilation(m, iterations=6))
    cloud = lab[560 - h // 2, 900]

    def piece(sel):
        b = band.copy()
        b[..., 3] = np.where(sel & m, b[..., 3], 0)
        return trim(Image.fromarray(b, "RGBA"))

    xs = np.arange(band.shape[1])[None, :]
    frames = [piece(xs < 300), piece((xs >= 300) & (xs < 670) & (lab != cloud)), piece(lab == cloud),
              piece((xs >= 1100) & (lab != cloud))]
    side = max(max(f.width, f.height) for f in frames)
    S = 192
    strip = Image.new("RGBA", (S * len(frames), S), (0, 0, 0, 0))
    for k, f in enumerate(frames):
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.alpha_composite(f, ((side - f.width) // 2, side - f.height))
        strip.alpha_composite(sq.resize((S, S), Image.LANCZOS), (k * S, 0))
    strip.save(fx / "modern_blast.png")
    print("fx sizes", bullet.size, shell.size, rkt.size, bomb.size, [f.size for f in frames])


def main():
    root = Path(sys.argv[1])
    src = root / "tools/art/source/modern/world"
    out = {k: root / "assets/images" / k for k in ("bases", "bg", "fx", "icons")}
    for d in out.values():
        d.mkdir(parents=True, exist_ok=True)
    art = {}
    bunker(src, out["bases"], art)
    rocket(src, out["bases"], art)
    layers(src, out["bg"])
    effects(src, out["fx"])
    icons(src / "modern_icons.png", root, {
        (0, 1): "icon_airstrike",
        (1, 0): ("icon_rocketpod", (370, 40, 720, 345)),
        (2, 1): ("icon_evolve_modern", (700, 370, 1062, 720)),
        (3, 1): ("icon_modern", (1062, 390, 1376, 720))})
    lay = json.loads(json.dumps(LAYERS))
    lay["sky"]["mirror"] = False
    era = {"base": {"art": art}, "world": {"layers": lay},
           "icons": {"special": "icon_airstrike", "evolve": "icon_evolve_modern", "turret": "icon_rocketpod"}}
    (src / "modern_era.json").write_text(json.dumps(era, indent=2) + "\n")
    print("age not in the game yet: world data -> modern_era.json")


if __name__ == "__main__":
    main()
