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
for u in data["units"]:
    for anim, default_n in frames.items():
        n = u.get("frames", {}).get(anim, default_n)
        for red in ("", "_red"):
            p = root / f"assets/images/units/stone_{u['sprite']}_{anim}{red}.png"
            if not p.exists():
                errors.append(f"missing {p.relative_to(root)}")
                continue
            w, h = Image.open(p).size
            if (w, h) != (u["frameW"] * n, u["frameH"]):
                errors.append(f"{p.name}: {w}x{h}, expected {u['frameW'] * n}x{u['frameH']}")
    icon = root / f"assets/images/icons/icon_{u['sprite']}.png"
    if not icon.exists():
        errors.append(f"missing {icon.relative_to(root)}")

fixed = [
    "bases/stone_base.png", "bases/stone_base_red.png",
    "bases/stone_turret.png", "bases/stone_turret_red.png",
    "bases/stone_turret_fire.png", "bases/stone_turret_fire_red.png",
    "bg/stone_sky.png", "bg/stone_hills.png", "bg/stone_near.png",
    "fx/stone.png", "fx/rock.png", "fx/meteor.png", "fx/blast.png",
]
for f in fixed:
    if not (root / "assets/images" / f).exists():
        errors.append(f"missing assets/images/{f}")
blast = root / "assets/images/fx/blast.png"
if blast.exists() and Image.open(blast).size != (384, 64):
    errors.append("fx/blast.png must be 6 frames of 64x64")

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
