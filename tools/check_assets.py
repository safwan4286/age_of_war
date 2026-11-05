#!/usr/bin/env python3
"""Checks that every image, font and data file the game loads exists, and
that unit strips match the frame sizes in units.json.

Usage: python3 tools/check_assets.py   (from the project root)
"""
import json
import re
import sys
from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parents[1]
errors = []

data = json.loads((root / "assets/data/units.json").read_text())
frames = {"idle": 4, "walk": 6, "attack": 6, "die": 6}
img = root / "assets/images"


def need(rel):
    if not (img / rel).exists():
        errors.append(f"missing assets/images/{rel}")
        return False
    return True


for era in data["eras"]:
    e = era["id"]
    for u in era["units"]:
        for anim, default_n in frames.items():
            n = u.get("frames", {}).get(anim, default_n)
            for red in ("", "_red"):
                rel = f"units/{e}_{u['sprite']}_{anim}{red}.png"
                if not need(rel):
                    continue
                w, h = Image.open(img / rel).size
                # One row, or a grid when the strip would pass 4096 px.
                fw, fh = u["frameW"], u["frameH"]
                per_row = w // fw if fw else 0
                rows = -(-n // per_row) if per_row else 0
                if w % fw or per_row < 1 or h != rows * fh or (rows == 1 and per_row != n):
                    errors.append(f"{rel}: {w}x{h} doesn't hold {n} frames of {fw}x{fh}")
        for kind in ("icon", "card", "pose"):
            need(f"icons/{kind}_{u['sprite']}.png")
        need(f"icons/pose_{u['sprite']}_red.png")
        if u.get("role") == "ranged":
            need(f"fx/{u.get('projectile', 'stone')}.png")
    for part in ("base", "cliff", "turret", "turret_fire"):
        for red in ("", "_red"):
            need(f"bases/{e}_{part}{red}.png")
    for layer in ("sky", "hills", "near"):
        need(f"bg/{e}_{layer}.png")
    special = era.get("special", era.get("meteor", {}))
    need(f"fx/{era['turret'].get('projectile', 'rock')}.png")
    need(f"fx/{special.get('sprite', 'meteor')}.png")
    blast = special.get("blast", "blast")
    if need(f"fx/{blast}.png"):
        bw, bh = Image.open(img / f"fx/{blast}.png").size
        if bw % bh:
            errors.append(f"fx/{blast}.png must be square frames side by side")
    for name in era.get("icons", {}).values():
        need(f"icons/{name}.png")

# Every literal 'assets/...' path in lib/ must exist.
for dart in (root / "lib").rglob("*.dart"):
    for m in re.finditer(r"'(assets/[^'$]+)'", dart.read_text()):
        p = m.group(1)
        if p.endswith("/"):
            continue
        if not (root / p).exists():
            errors.append(f"{dart.relative_to(root)} -> missing {p}")

pub = (root / "pubspec.yaml").read_text()
for m in re.finditer(r"- asset: (\S+)", pub):
    if not (root / m.group(1)).exists():
        errors.append(f"pubspec font missing: {m.group(1)}")
for m in re.finditer(r"^    - (assets/\S+/)$", pub, re.M):
    if not (root / m.group(1)).is_dir():
        errors.append(f"pubspec asset dir missing: {m.group(1)}")

if errors:
    print("\n".join(errors))
    sys.exit(1)
print("assets ok")
