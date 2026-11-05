#!/usr/bin/env python3
"""Builds the Stone Age world art from the Gemini sheets in
tools/art/source/stone_world/ (all on solid magenta, except the sky):

  stone_sky_v2.png   cleaned sky (edge clouds removed, outlines softened)
  stone_hills.png    middle layer, 21:9
  stone_ground.png   ground layer, 21:9
  stone_base.png     cave fortress with 3 plank ledges, 1:1
  stone_turret.png   rock thrower: ready | fired, 16:9
  stone_fx.png       4x2 grid: boulder, sling stone, meteor, - / (dust frames unused)

Writes assets/images/bg, bases and fx, and the base's gate and ledge
positions into assets/data/units.json (base.art). The old art is kept in
tools/art/source/old_world/.

Usage: python3 tools/art/build_world.py <project_root>
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

PX_PER_WORLD = 2  # art resolution: 2 px per world unit (sharp on phones)


def magenta(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (r - g > 70) & (b - g > 70) & (np.abs(r - b) < 90)


def key(img: Image.Image, open_iter=1, min_area=0):
    """Magenta -> transparent. Colour under transparent pixels is copied
    from the nearest opaque pixel so resizing never bleeds pink."""
    rgb = np.asarray(img.convert("RGB")).astype(int)
    fg = ~magenta(rgb)
    if open_iter:
        fg = ndimage.binary_opening(fg, iterations=open_iter)
    if min_area:
        lab, n = ndimage.label(fg)
        sizes = ndimage.sum(fg, lab, range(1, n + 1))
        fg &= np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= min_area])
    return rgba_from(rgb, fg)


def key_soft(img: Image.Image):
    """Like key(), but keeps half-transparent purple (smoke over magenta)
    as opaque pixels so grey_smoke() can turn it into grey smoke."""
    rgb = np.asarray(img.convert("RGB")).astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    pure = (r - g > 150) & (b - g > 150) & (np.abs(r - b) < 60)
    return rgba_from(rgb, ~pure)


def rgba_from(rgb, mask):
    idx = ndimage.distance_transform_edt(~mask, return_distances=False, return_indices=True)
    filled = rgb[idx[0], idx[1]]
    # Edge pixels that were blended with magenta: pull them to their
    # inner neighbour's colour.
    edge = mask & ~ndimage.binary_erosion(mask, iterations=2)
    pink = edge & (rgb[..., 0] - rgb[..., 1] > 40) & (rgb[..., 2] - rgb[..., 1] > 40)
    inner = ndimage.binary_erosion(mask, iterations=3)
    idx2 = ndimage.distance_transform_edt(~inner, return_distances=False, return_indices=True)
    filled[pink] = rgb[idx2[0], idx2[1]][pink]
    alpha = np.where(mask, 255, 0)
    return Image.fromarray(np.dstack([filled, alpha]).astype(np.uint8), "RGBA")


def remove_sparkle(img: Image.Image):
    """Gemini's star watermark in the bottom-right corner: a light,
    low-saturation, roughly square blob. Painted over from its surroundings."""
    import cv2
    a = np.asarray(img).copy()
    h, w = a.shape[:2]
    y0, x0 = int(h * 0.8), int(w * 0.88)
    sub = a[y0:, x0:, :3].astype(int)
    light = (sub.min(-1) > 150) & (sub.max(-1) - sub.min(-1) < 60)
    lab, n = ndimage.label(ndimage.binary_dilation(light, iterations=3))
    best = None
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        hh, ww = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
        if 25 <= hh <= 160 and 25 <= ww <= 160 and abs(hh - ww) < 0.4 * max(hh, ww):
            area = (lab[sl] == i).sum()
            if best is None or area > best[0]:
                best = (area, i)
    if best is None:
        return img
    m = np.zeros((h, w), np.uint8)
    m[y0:, x0:] = ndimage.binary_dilation(lab == best[1], iterations=6)
    a[..., :3] = cv2.inpaint(np.ascontiguousarray(a[..., :3]), m, 9, cv2.INPAINT_TELEA)
    return Image.fromarray(a, img.mode)


def grey_smoke(img: Image.Image):
    """Smoke drawn half-transparent over magenta comes out purple: turn it
    into soft grey smoke."""
    a = np.asarray(img).astype(float).copy()
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    purple = (al > 0) & (r - g > 25) & (b - g > 25)
    grey = (r + g + b) / 3
    a[..., 0] = np.where(purple, grey * 0.95, r)
    a[..., 1] = np.where(purple, grey * 0.93, g)
    a[..., 2] = np.where(purple, grey * 0.92, b)
    a[..., 3] = np.where(purple, 150, al)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def side_crop(img: Image.Image, px=6):
    """Drop a few columns at both ends: Gemini often leaves an edge line
    there, which would show at every mirror join."""
    return img.crop((px, 0, img.width - px, img.height))


def match_colours(img: Image.Image, ref: Image.Image, strength=0.8):
    """Shifts img's colours toward ref's (per-channel mean and spread over
    opaque pixels), so a separately drawn piece matches the base's rock."""
    a = np.asarray(img).astype(float).copy()
    r = np.asarray(ref).astype(float)
    ma, mr = a[..., 3] > 0, r[..., 3] > 0
    for c in range(3):
        sa, sr = a[..., c][ma], r[..., c][mr]
        target = (a[..., c] - sa.mean()) / (sa.std() + 1e-6) * sr.std() + sr.mean()
        a[..., c] = np.where(ma, a[..., c] * (1 - strength) + target * strength, a[..., c])
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def trim(img: Image.Image):
    return img.crop(img.getchannel("A").getbbox())


def fit_h(img: Image.Image, h: int):
    return img.resize((max(1, round(img.width * h / img.height)), h), Image.LANCZOS)


def red(img: Image.Image):
    a = np.asarray(img).astype(float).copy()
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    blue = (b > r + 25) & (b > g + 10)
    a[..., 0] = np.where(blue, np.minimum(255, b * 1.05 + 20), r)
    a[..., 1] = np.where(blue, g * 0.45, g)
    a[..., 2] = np.where(blue, r * 0.5, b)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def bottom_cut(img: Image.Image, h_frac=0.5):
    """Drops the thin ground line Gemini draws under a building: the
    lowest rows that are much wider than the rows just above."""
    a = np.asarray(img)[..., 3] > 0
    widths = a.sum(1)
    h = a.shape[0]
    for y in range(h - 1, int(h * h_frac), -1):
        if widths[y] == 0:
            continue
        above = np.median(widths[max(0, y - 40):y - 8])
        if widths[y] > above * 1.04 + 20:
            continue
        return img.crop((0, 0, img.width, y + 1))
    return img


def planks(rgb, min_run=300):
    """Rows of long horizontal wood runs: (top_y, x0, x1) per plank."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    wood = (r > 100) & (r - g > 30) & (r - g < 90) & (g - b > 15) & (g - b < 70) & (r < 230)
    rows = []
    for y in range(rgb.shape[0]):
        d = np.diff(np.concatenate([[0], wood[y].astype(int), [0]]))
        st, en = np.nonzero(d == 1)[0], np.nonzero(d == -1)[0]
        if len(st):
            i = (en - st).argmax()
            if en[i] - st[i] > min_run:
                rows.append((y, int(st[i]), int(en[i])))
    groups = []
    for row in rows:
        if groups and row[0] - groups[-1][-1][0] <= 8:
            groups[-1].append(row)
        else:
            groups.append([row])
    out = []
    for g in groups:
        # Rock next to a plank can join the group; keep the rows whose run
        # is close to the longest one (the plank itself).
        longest = max(r[2] - r[1] for r in g)
        core = [r for r in g if r[2] - r[1] >= 0.85 * longest]
        x0, x1 = int(np.median([r[1] for r in core])), int(np.median([r[2] for r in core]))
        # Top edge: first row of the group that lies over the plank.
        top = next(r[0] for r in g if r[1] >= x0 - 40 and r[2] <= x1 + 40)
        out.append((top, x0, x1, len(g)))
    return out


def main():
    root = Path(sys.argv[1])
    src = root / "tools/art/source/stone_world"
    bg = root / "assets/images/bg"
    bases = root / "assets/images/bases"
    fx = root / "assets/images/fx"
    for d in (bg, bases, fx):
        d.mkdir(parents=True, exist_ok=True)
    data_path = root / "assets/data/units.json"
    data = json.loads(data_path.read_text())
    # Stone Age is era 0; the Medieval world has its own builder.
    era = data["eras"][0]
    world = era.setdefault("world", {})
    layers = world.setdefault("layers", {
        "sky": {"top": 0, "height": 540},
        "hills": {"top": 60, "height": 480},
        "near": {"top": 144, "height": 396},
    })

    # --- Background layers -------------------------------------------
    # Only when units.json world.bgFromSheets is true; otherwise the
    # current bg/ art stays (the previous layers are in use for now).
    if world.get("bgFromSheets", False):
        build_bg(src, bg, layers)
    if (src / "stone_icons.png").exists():
        build_icons(src, root)

    # --- Base ---------------------------------------------------------
    build_rest(src, bases, fx, era)
    data_path.write_text(json.dumps(data, indent=2) + "\n")
    print("world layers", layers)


def build_bg(src, bg, layers):
    """The previous layout redrawn in the unit style: sky, meadow hills,
    hedge + open sand plain. Placement comes from world.layers."""
    sky = side_crop(remove_sparkle(Image.open(src / "stone_sky.png").convert("RGB")))
    fit_h(sky, layers["sky"]["height"] * PX_PER_WORLD).save(bg / "stone_sky.png")
    hills_src = remove_sparkle(Image.open(src / "stone_hills.png").convert("RGB"))
    hills = side_crop(grey_smoke(key_soft(hills_src)))
    fit_h(hills, layers["hills"]["height"] * PX_PER_WORLD).save(bg / "stone_hills.png")
    ground_src = remove_sparkle(Image.open(src / "stone_ground.png").convert("RGB"))
    ground = side_crop(key(ground_src, open_iter=0))
    fit_h(ground, layers["near"]["height"] * PX_PER_WORLD).save(bg / "stone_near.png")


def build_icons(src, root):
    """stone_icons.png: 4x2 grid of HUD icons on magenta. The background is
    removed by flood fill from the cell edges (so purple inside the crystal
    survives), the corner watermark is dropped, and each icon is saved
    square, 256 px."""
    f = Image.open(src / "stone_icons.png").convert("RGB")
    gw, gh = f.width // 4, f.height // 2
    names = ["icons/icon_gold", "icons/icon_xp", "icons/icon_meteor", "icons/icon_evolve",
             "icons/icon_turret", "ui/star", "ui/star_empty", "ui/lock"]
    for i, name in enumerate(names):
        c, r = i % 4, i // 4
        rgb = np.asarray(f.crop((c * gw, r * gh, (c + 1) * gw, (r + 1) * gh))).astype(int)
        h, w = rgb.shape[:2]
        rr, gg, bb = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        # Background: magenta (and glow blended into it) reached from the
        # cell edges, plus near-pure magenta anywhere (holes in the
        # catapult and the padlock). Lavender inside the crystal stays.
        pinkish = magenta(rgb)
        lab, _ = ndimage.label(pinkish)
        edge_ids = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
        pure = (rr > 190) & (bb > 190) & (gg < 90)
        plab, pn = ndimage.label(pure)
        psize = ndimage.sum(pure, plab, range(1, pn + 1))
        # The crystal has small magenta-like highlights: only big holes
        # there. Everywhere else every enclosed magenta gap goes.
        min_hole = 0.003 * h * w if name.endswith("icon_xp") else 20
        holes = np.isin(plab, [k + 1 for k, a in enumerate(psize) if a >= min_hole])
        bg = np.isin(lab, list(edge_ids)) | holes
        fg = ndimage.binary_opening(~bg, iterations=1)
        lab2, n = ndimage.label(fg)
        keep = np.zeros_like(fg)
        sizes = ndimage.sum(fg, lab2, range(1, n + 1))
        for j, sl in enumerate(ndimage.find_objects(lab2), 1):
            in_corner = sl[1].start > 0.85 * w and sl[0].start > 0.78 * h
            if sizes[j - 1] >= 0.002 * sizes.max() and not in_corner:
                keep |= lab2 == j
        icon = trim(rgba_from(rgb, keep))
        side = max(icon.size)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.alpha_composite(icon, ((side - icon.width) // 2, (side - icon.height) // 2))
        out = root / "assets/images" / f"{name}.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        sq.resize((256, 256), Image.LANCZOS).save(out)


def build_blast(src, fx):
    """Meteor impact: 6 frames in a 3x2 grid, all on one ground line.
    Written as square frames side by side, bottoms aligned."""
    f = Image.open(src / "stone_blast.png")
    gw, gh = f.width // 3, f.height // 2
    cells = [key(f.crop((c * gw, r * gh, (c + 1) * gw, (r + 1) * gh)), min_area=30)
             for r in range(2) for c in range(3)]
    boxes = [c.getchannel("A").getbbox() for c in cells]
    x0 = min(b[0] for b in boxes); x1 = max(b[2] for b in boxes)
    y0 = min(b[1] for b in boxes); y1 = max(b[3] for b in boxes)
    side = max(x1 - x0, y1 - y0)
    S = 256
    strip = Image.new("RGBA", (S * len(cells), S), (0, 0, 0, 0))
    for k, c in enumerate(cells):
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.alpha_composite(c.crop((x0, y0, x1, y1)), ((side - (x1 - x0)) // 2, side - (y1 - y0)))
        strip.alpha_composite(sq.resize((S, S), Image.LANCZOS), (k * S, 0))
    strip.save(fx / "blast.png")


def build_rest(src, bases, fx, era):
    raw = Image.open(src / "stone_base.png")
    base = key(raw, min_area=5000)
    x0, y0, x1, _ = base.getchannel("A").getbbox()
    base = bottom_cut(base.crop((x0, y0, x1, base.height)))
    tx0, ty0, _, _ = base.getchannel("A").getbbox()
    base = trim(base)
    bx0, by0 = x0 + tx0, y0 + ty0
    w, h = base.size
    rgb = np.asarray(raw.convert("RGB")).astype(int)
    found = [p for p in planks(rgb) if p[3] >= 6 and p[2] - p[1] > 0.12 * w]
    # Ledges: the three widest wood runs that are not the gate's lintel
    # (the lowest run, directly over the door).
    found.sort(key=lambda p: p[0])
    print("wood runs", found)
    lintel = found[-1]
    ledges = sorted(found[:-1], key=lambda p: -(p[2] - p[1]))[:3]
    ledges.sort(key=lambda p: -p[0])  # lowest first: slot 0 builds first
    art = era.setdefault("base", {}).setdefault("art", {})
    art["slots"] = [[round(((p[1] + p[2]) / 2 - bx0) / w, 3), round((p[0] - by0) / h, 3)] for p in ledges]
    art["gate"] = round(((lintel[1] + lintel[2]) / 2 - bx0) / w, 3)
    art["ledgeW"] = round(float(np.mean([(p[2] - p[1]) / w for p in ledges])), 3)
    art["turretW"] = round(art["ledgeW"] * 0.8, 3)
    draw_h = art.get("height", 330)
    out = fit_h(base, round(draw_h * PX_PER_WORLD))
    out.save(bases / "stone_base.png")
    red(out).save(bases / "stone_base_red.png")
    # Rock that continues the base past the screen edge: a dedicated
    # tileable cliff sheet if there is one, else a strip of the base's own
    # cliff face (repeated mirrored by the game).
    if (src / "stone_cliff.png").exists():
        c = trim(key(Image.open(src / "stone_cliff.png"), min_area=5000))
        c = c.crop((8, 0, c.width - 8, c.height))
        # The wall stands as tall as the base's cliff shoulder (its top at
        # ~26% of the base picture), padded to the base's height.
        wall = match_colours(fit_h(c, round(out.height * 0.74)),
                             out.crop((round(0.07 * out.width), round(0.3 * out.height),
                                       round(0.22 * out.width), out.height)))
        cliff = Image.new("RGBA", (wall.width, out.height), (0, 0, 0, 0))
        cliff.alpha_composite(wall, (0, out.height - wall.height))
        # Repeats start where the base's own cliff reaches full height.
        art["cliff"] = [0.07, 0.07]
    else:
        x0f, x1f = 0.07, 0.22
        cliff = out.crop((round(x0f * out.width), 0, round(x1f * out.width), out.height))
        art["cliff"] = [x0f, x1f]
    cliff.save(bases / "stone_cliff.png")
    red(cliff).save(bases / "stone_cliff_red.png")
    print("base", base.size, "ledges", art["slots"], "gate", art["gate"], "ledgeW", art["ledgeW"])

    # --- Turret: two poses, aligned on the bottom plank -----------------
    t = Image.open(src / "stone_turret.png")
    half = t.width // 2
    poses = []
    for i in range(2):
        p = key(t.crop((i * half, 0, (i + 1) * half, t.height)), min_area=3000)
        a = np.asarray(p)[..., 3] > 0
        ys, xs = np.nonzero(a)
        bot = ys.max()
        plank = np.nonzero(a[bot - 6])[0]
        poses.append((p, (plank.min() + plank.max()) / 2, bot))
    left = max(cx - min(np.nonzero(np.asarray(p)[..., 3].any(0))[0]) for p, cx, _ in poses)
    right = max(max(np.nonzero(np.asarray(p)[..., 3].any(0))[0]) - cx for p, cx, _ in poses)
    top = max(bot - min(np.nonzero(np.asarray(p)[..., 3].any(1))[0]) for p, _, bot in poses)
    half_w = int(max(left, right)) + 2
    cw, ch = 2 * half_w, int(top) + 2
    cells = []
    for p, cx, bot in poses:
        c = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        c.alpha_composite(p, (int(round(half_w - cx)), int(ch - 1 - bot)))
        cells.append(c)
    turret_px = 200
    for name, c in zip(["stone_turret", "stone_turret_fire"], cells):
        o = c.resize((turret_px, round(ch * turret_px / cw)), Image.LANCZOS)
        o.save(bases / f"{name}.png")
        red(o).save(bases / f"{name}_red.png")
    print("turret cell", cw, ch)

    # --- Effects: 4x2 grid with drawn borders -------------------------
    f = Image.open(src / "stone_fx.png")
    gw, gh = f.width // 4, f.height // 2
    inset = 16

    def cell(i):
        c, r = i % 4, i // 4
        return trim(key(f.crop((c * gw + inset, r * gh + inset, (c + 1) * gw - inset, (r + 1) * gh - inset)),
                        min_area=40))

    fit_h(cell(0), 64).save(fx / "rock.png")
    fit_h(cell(1), 32).save(fx / "stone.png")
    # The game expects the meteor falling down-left (tail up-right);
    # Gemini drew it the other way round.
    m = cell(2).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    m.resize((256, round(m.height * 256 / m.width)), Image.LANCZOS).save(fx / "meteor.png")
    # fx/blast.png (the meteor impact) is not rebuilt from this sheet: its
    # dust cloud reads as smoke, not fire; the fire-blast sheet is used.
    if (src / "stone_blast.png").exists():
        build_blast(src, fx)


if __name__ == "__main__":
    main()
