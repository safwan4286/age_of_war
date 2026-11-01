#!/usr/bin/env python3
"""Builds a unit's animation strips from individual frame PNGs
(idle_f1.png, walk_f1.png, ...), e.g. frames exported one per file.

Removes the background (real transparency, a solid colour, or a baked
checkerboard), aligns feet on one baseline and the body on one centre
line, scales to a target height, and writes:
  assets/images/units/stone_<sprite>_<anim>[_red].png
  assets/images/icons/icon_<sprite>.png   (unless it already exists)

Prints the "frameW", "frameH" and "frames" values for units.json.

Usage:
  python3 tools/art/assemble_frames.py <frames_dir> <sprite> <project_root> \
      --height 100 \
      --anim idle=idle_f1,idle_f2,idle_f3,idle_f4 \
      --anim walk=walk_f1,...  --anim attack=...  --anim die=...
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

PAD = 3


def cutout(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(int)
    if a[..., 3].min() < 250:  # already transparent
        alpha = a[..., 3] > 110
    else:
        rgb = a[..., :3]
        corners = np.concatenate([rgb[:3, :3].reshape(-1, 3), rgb[:3, -3:].reshape(-1, 3),
                                  rgb[-3:, :3].reshape(-1, 3), rgb[-3:, -3:].reshape(-1, 3)])
        ref = np.median(corners, 0)
        r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        neutral = (abs(r - g) < 8) & (abs(g - b) < 8)
        if ref.mean() > 150:  # baked checkerboard
            cand = neutral & (rgb.min(-1) > 150)
        else:  # solid / dark tile
            cand = np.sqrt(((rgb - ref) ** 2).sum(-1)) < 22
        lab, _ = ndimage.label(cand)
        ids = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
        bg = np.isin(lab, ids[ids > 0])
        alpha = ndimage.binary_opening(~bg, iterations=1)
        # Keep the biggest figure (drops stray labels / specks).
        lab, n = ndimage.label(ndimage.binary_dilation(alpha, iterations=3))
        if n > 1:
            sizes = ndimage.sum(alpha, lab, range(1, n + 1))
            alpha &= lab == (int(np.argmax(sizes)) + 1)
    out = a.copy()
    out[..., 3] = np.where(alpha, 255, 0)
    img = Image.fromarray(out.astype(np.uint8), "RGBA")
    return img.crop(img.getbbox())


def body_cx(img: Image.Image, lying: bool) -> float:
    """Centre on the legs (bottom quarter) so swings don't shift the body."""
    if lying:
        return img.width / 2
    a = np.asarray(img)[..., 3]
    q = a[int(a.shape[0] * 0.75):]
    xs = np.nonzero(q)[1]
    return float(xs.mean()) if len(xs) else img.width / 2


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("frames_dir")
    ap.add_argument("sprite")
    ap.add_argument("root")
    ap.add_argument("--height", type=float, default=100, help="standing height in px")
    ap.add_argument("--anim", action="append", required=True)
    args = ap.parse_args()

    src, root = Path(args.frames_dir), Path(args.root)
    anims = {}
    for spec in args.anim:
        name, files = spec.split("=")
        anims[name] = [cutout(src / f"{f}.png") for f in files.split(",")]

    standing = float(np.median([f.height for f in anims["idle"]]))
    k = args.height / standing
    scaled = {}
    for name, frames in anims.items():
        scaled[name] = []
        for f in frames:
            s = f.resize((max(1, round(f.width * k)), max(1, round(f.height * k))), Image.LANCZOS)
            a = np.asarray(s).copy()
            a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
            s = Image.fromarray(a, "RGBA")
            lying = name == "die" and s.width > s.height * 1.15
            scaled[name].append((s, body_cx(s, lying)))

    half = max(max(cx, f.width - cx) for fr in scaled.values() for f, cx in fr)
    cw = int(np.ceil(2 * half)) + 2 * PAD
    ch = max(f.height for fr in scaled.values() for f, _ in fr) + PAD
    units = root / "assets/images/units"
    units.mkdir(parents=True, exist_ok=True)
    for name, fr in scaled.items():
        strip = Image.new("RGBA", (cw * len(fr), ch), (0, 0, 0, 0))
        for i, (f, cx) in enumerate(fr):
            strip.alpha_composite(f, (int(round(i * cw + cw / 2 - cx)), ch - f.height))
        strip.save(units / f"stone_{args.sprite}_{name}.png")
        red = np.asarray(strip).astype(float)
        red[..., 1] *= 0.80
        red[..., 2] *= 0.74
        red[..., 0] = np.minimum(255, red[..., 0] * 1.06 + 8)
        Image.fromarray(red.astype(np.uint8), "RGBA").save(units / f"stone_{args.sprite}_{name}_red.png")

    icon_path = root / f"assets/images/icons/icon_{args.sprite}.png"
    if not icon_path.exists():
        f = anims["idle"][0]
        side = int(min(f.width, f.height) * 0.75)
        portrait = f.crop((max(0, (f.width - side) // 2), 0, max(0, (f.width - side) // 2) + side, side))
        icon = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        icon.alpha_composite(portrait.resize((116, 116), Image.LANCZOS), (6, 8))
        icon.save(icon_path)

    print(f'"frameW": {cw}, "frameH": {ch}, "frames": ' +
          "{" + ", ".join(f'"{n}": {len(fr)}' for n, fr in scaled.items()) + "}")


if __name__ == "__main__":
    main()
