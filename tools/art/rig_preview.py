#!/usr/bin/env python3
"""Cutout rig: parts + bones + procedural animation, previewed as a GIF.

The same rig JSON (tools/art/source/<unit>_rig/rig.json) and the same
motion formulas drive the game (lib/features/battle/game/rig/). This file
is the quick way to look at them without a phone.

Usage: python3 tools/art/rig_preview.py <rig_dir> <out.gif> [--speed 40] [--attack 1.0]
"""
import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image


def load_parts(rig_dir: Path, rig: dict):
    out = {}
    for name, p in rig["parts"].items():
        out[name] = Image.open(rig_dir / p["file"]).convert("RGBA")
    return out


def mat(tx=0.0, ty=0.0, rot=0.0, sx=1.0, sy=1.0):
    c, s = math.cos(rot), math.sin(rot)
    return np.array([[c * sx, -s * sy, tx], [s * sx, c * sy, ty], [0, 0, 1]], float)


def pose(rig: dict, t: float, anim: str, speed: float, attack: float, lift: float):
    """Bone angles (radians) + root offset for a moment of an animation.
    Mirrors lib/features/battle/game/rig/rig_motion.dart."""
    a = {b: 0.0 for b in rig["bones"]}
    root_y = 0.0
    root_rot = 0.0
    sq = 1.0
    leg = rig["legLength"]
    if anim == "idle":
        ph = 2 * math.pi * t / 1.6
        root_y = -2 * (0.5 - 0.5 * math.cos(ph))
        a["torso"] = math.radians(1.5) * math.sin(ph)
        a["head"] = math.radians(2) * math.sin(ph - 0.6)
        a["arm_f"] = math.radians(2) * math.sin(ph)
        a["arm_b"] = math.radians(-3) * math.sin(ph)
        sq = 1 + 0.012 * math.sin(ph)
    elif anim == "walk":
        T = 0.8
        ph = 2 * math.pi * t / T
        # Stride matched to ground speed so feet don't slide:
        # step = speed * T/2 (world) -> rig px via worldPerPx.
        step = speed * (T / 2) / rig["worldPerPx"]
        amp = math.asin(min(0.9, step / (2 * leg)))
        a["leg_f"] = amp * math.sin(ph)
        a["leg_b"] = -amp * math.sin(ph)
        root_y = -lift * abs(math.sin(ph)) + lift * 0.5
        a["torso"] = math.radians(3) + math.radians(1.5) * math.sin(2 * ph)
        a["head"] = math.radians(-1.5) * math.sin(2 * ph)
        a["arm_b"] = -amp * 0.9 * math.sin(ph)
        a["arm_f"] = amp * 0.35 * math.sin(ph)
    elif anim == "attack":
        u = (t % attack) / attack
        # 0-.40 raise club back, .40-.50 smash (impact at .50), then recover.
        def ease(x):
            return x * x * (3 - 2 * x)
        if u < 0.4:
            k = ease(u / 0.4)
            arm, lean = -2.4 * k, -0.10 * k
        elif u < 0.5:
            k = ease((u - 0.4) / 0.1)
            arm, lean = -2.4 + 2.25 * k, -0.10 + 0.26 * k
        elif u < 0.6:
            k = ease((u - 0.5) / 0.1)
            arm, lean = -0.15 + 0.40 * k, 0.16
        elif u < 0.7:
            arm, lean = 0.25, 0.16
        else:
            k = ease((u - 0.7) / 0.3)
            arm, lean = 0.25 - 0.25 * k, 0.16 - 0.16 * k
        a["arm_f"] = arm
        a["torso"] = lean
        a["head"] = -lean * 0.5
        a["arm_b"] = -lean * 1.5
        a["leg_f"] = 0.12
        a["leg_b"] = -0.12
    elif anim == "die":
        u = min(1.0, t / 1.0)
        k = u * u * (3 - 2 * u)
        root_rot = -math.radians(85) * k
        root_y = 0
        a["arm_f"] = -1.2 * k
        a["arm_b"] = -0.8 * k
        a["head"] = -0.3 * k
        a["leg_f"] = 0.3 * k
    return a, root_y, root_rot, sq


def render(rig, parts, t, anim, speed, attack, size=(560, 420), origin=(360, 390), scale=0.5):
    a, ry, rr, sq = pose(rig, t, anim, speed, attack, rig.get("bobPx", 8))
    canvas = Image.new("RGBA", size, (111, 183, 224, 255))
    world = {}
    root = mat(origin[0], origin[1]) @ mat(0, 0, rr, scale, scale) @ mat(0, ry)
    def bone_m(b):
        if b in world:
            return world[b]
        bd = rig["bones"][b]
        parent = root if bd["parent"] is None else bone_m(bd["parent"])
        jx, jy = bd["joint"]
        m = parent @ mat(jx, jy, bd.get("rest", 0.0) + a.get(b, 0.0))
        if b == "torso":
            m = m @ mat(0, 0, 0, 1, sq)
        world[b] = m
        return m

    for name in rig["order"]:
        p = rig["parts"][name]
        img = parts[name]
        m = bone_m(p["bone"]) @ mat(p["at"][0], p["at"][1], p.get("rot", 0.0)) @ mat(-p["pivot"][0], -p["pivot"][1])
        inv = np.linalg.inv(m)
        tr = img.transform(size, Image.AFFINE, tuple(inv[:2].flatten()), Image.BICUBIC)
        canvas.alpha_composite(tr)
    return canvas


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("rig_dir")
    ap.add_argument("out")
    ap.add_argument("--speed", type=float, default=40)
    ap.add_argument("--attack", type=float, default=1.0)
    args = ap.parse_args()
    rig_dir = Path(args.rig_dir)
    rig = json.loads((rig_dir / "rig.json").read_text())
    parts = load_parts(rig_dir, rig)
    frames = []
    fps = 20
    for anim, length in [("idle", 1.6), ("walk", 1.6), ("attack", args.attack * 2), ("die", 1.4)]:
        for i in range(int(length * fps)):
            frames.append(render(rig, parts, i / fps, anim, args.speed, args.attack).convert("P", palette=Image.ADAPTIVE))
    frames[0].save(args.out, save_all=True, append_images=frames[1:], duration=1000 // fps, loop=0, disposal=2)


if __name__ == "__main__":
    main()
