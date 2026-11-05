#!/usr/bin/env python3
"""Builds a unit's game strips from Veo clips (see video_frames.py).

Spec (tools/art/source/<era>/<unit>.json):
  {
    "sprite": "swordsman", "era": "medieval",
    "frames": "<folder with <unit>_<anim>/ frame folders>",
    "height": 210,                  # idle figure height in the strips, px
    "worldHeight": 108,             # how tall it stands in the game
    "width": 40,                    # footprint on the lane
    "pick": {"attack": [0, 10, ...], "die": [...], "idle": [...]},
    "walk": "loop",                 # or a list of frame indices
    "frameTimes": {"idle": 0.15, "walk": 0.11}
  }
The attack's 5th picked frame (index 4) must be the impact: the sim hits
half-way through the swing. Frames keep their positions from the video
(one locked camera), anchored on the idle figure's feet.

Usage: python3 tools/art/build_video_unit.py <spec.json> <project_root>
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from build_unit import card, full_pose, medallion, red_variant  # noqa: E402
from video_frames import Clip  # noqa: E402

ANIMS = {"idle": "idle", "walk": "walk", "attack": "attack", "die": "death"}
MAX_STRIP = 4096


def whiten_streaks(img):
    """Motion arcs and sparks Veo draws in light pink: make them white."""
    a = np.asarray(img).copy()
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    pinkish = (a[..., 3] > 0) & (r - g > 20) & (b - g > 20) & (r + g + b > 480)
    a[pinkish, :3] = 245
    return Image.fromarray(a, "RGBA")


def loop_frames(clip: Clip, want=8):
    """Indices for one walk cycle: finds where the legs return to frame
    0's pose, then spreads `want` frames over that cycle."""
    masks = []
    for i in range(len(clip)):
        im, (x0, y0) = clip.keyed(i)
        a = np.zeros((460, 820), bool)
        al = np.asarray(im)[..., 3] > 0
        h, w = al.shape
        a[y0:y0 + h, x0:x0 + w] = al
        ys = np.nonzero(a.any(1))[0]
        cut = int(ys.min() + (ys.max() - ys.min()) * 0.6)
        a[:cut] = False
        masks.append(a)
    n = len(masks)
    best, period = -1.0, n
    for j in range(6, n):
        inter = (masks[0] & masks[j]).sum()
        iou = inter / max(1, (masks[0] | masks[j]).sum())
        if iou > best + 0.02:
            best, period = iou, j
    return [round(k * period / want) for k in range(want)]


def main():
    spec_path, root = Path(sys.argv[1]), Path(sys.argv[2])
    spec = json.loads(spec_path.read_text())
    sprite, era = spec["sprite"], spec["era"]
    base = (spec_path.parent / spec["frames"]).resolve()
    clips = {k: Clip(base / f"{sprite}_{v}") for k, v in ANIMS.items()}

    picks = dict(spec["pick"])
    if spec.get("walk", "loop") == "loop":
        picks["walk"] = loop_frames(clips["walk"])
    else:
        picks["walk"] = spec["walk"]
    for k, v in picks.items():
        print(f"  {k}: {v}")

    # Ground line and anchor from the idle frames.
    idle_imgs = [clips["idle"].keyed(i) for i in picks["idle"]]
    bottoms, tops, centers = [], [], []
    for im, (x0, y0) in idle_imgs:
        al = np.asarray(im)[..., 3] > 0
        ys, xs = np.nonzero(al)
        bottoms.append(y0 + ys.max())
        tops.append(y0 + ys.min())
        low = al[int(ys.max() * 0.85):]
        centers.append(x0 + np.nonzero(low)[1].mean())
    ground = float(np.median(bottoms))
    ax = float(np.median(centers))
    idle_h = ground - float(np.median(tops))

    frames = {}
    for anim, idx in picks.items():
        out = []
        for i in idx:
            im, (x0, y0) = clips[anim].keyed(i, ground_y=ground, keep_ground=(anim == "die"))
            out.append((whiten_streaks(im), x0, y0))
        frames[anim] = out

    # Extents around the anchor, then the scale (shrunk if a strip would
    # pass the 4096 px texture limit).
    half, up = 0.0, 0.0
    for anim, fs in frames.items():
        for im, x0, y0 in fs:
            al = np.asarray(im)[..., 3] > 0
            ys, xs = np.nonzero(al)
            half = max(half, ax - (x0 + xs.min()), (x0 + xs.max()) - ax)
            up = max(up, ground - (y0 + ys.min()))
    k = spec["height"] / idle_h
    most = max(len(v) for v in picks.values())
    if (2 * half * k + 8) * most > MAX_STRIP:
        k = (MAX_STRIP / most - 8) / (2 * half)
    cw = int(np.ceil(2 * half * k)) + 8
    ch = int(np.ceil(up * k)) + 6

    units = root / "assets/images/units"
    units.mkdir(parents=True, exist_ok=True)
    counts = {}
    for anim, fs in frames.items():
        strip = Image.new("RGBA", (cw * len(fs), ch), (0, 0, 0, 0))
        for j, (im, x0, y0) in enumerate(fs):
            q = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
            arr = np.asarray(q).copy()
            arr[..., 3] = np.where(arr[..., 3] > 110, 255, 0)
            q = Image.fromarray(arr, "RGBA")
            px = j * cw + cw / 2 + (x0 - ax) * k
            py = ch - 3 - (ground - y0) * k
            strip.alpha_composite(q, (int(round(px)), int(round(py))))
        strip.save(units / f"{era}_{sprite}_{anim}.png")
        red_variant(strip).save(units / f"{era}_{sprite}_{anim}_red.png")
        counts[anim] = len(fs)

    icons = root / "assets/images/icons"
    first = frames["idle"][0][0]
    first = first.crop(first.getchannel("A").getbbox())
    medallion(first).save(icons / f"icon_{sprite}.png")
    card(first).save(icons / f"card_{sprite}.png")
    full = full_pose(first)
    full.save(icons / f"pose_{sprite}.png")
    red_variant(full).save(icons / f"pose_{sprite}_red.png")

    data_path = root / "assets/data/units.json"
    data = json.loads(data_path.read_text())
    world_h = spec["worldHeight"]
    for e in data.get("eras", []):
        for u in e["units"]:
            if u["sprite"] == sprite:
                u["frameW"], u["frameH"] = cw, ch
                u["frames"] = counts
                u["frameTimes"] = spec.get("frameTimes", {})
                u["drawScale"] = round(world_h / (idle_h * k), 4)
                u["width"] = spec.get("width", u.get("width", 40))
                u["headY"] = world_h
    data_path.write_text(json.dumps(data, indent=2) + "\n")
    print(f"{sprite}: cell {cw}x{ch}, scale {k:.3f}, frames {counts}")


if __name__ == "__main__":
    main()
