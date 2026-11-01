#!/usr/bin/env python3
"""Placeholder art for everything the character sheets don't cover:
caves, turret, parallax layers, FX, HUD icons, stars, launcher icons.

Everything is drawn small on a pixel grid and scaled up with nearest-
neighbour so it matches the units' chunky look. Replace any file with
real art of the same name and size; the game picks it up unchanged.

Only writes files that don't exist yet, so real art is never replaced
(pass --force to regenerate everything). Launcher icons are always rebuilt.

Usage: python3 tools/art/gen_placeholders.py <project_root> [--force]
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(next((a for a in sys.argv[1:] if not a.startswith("--")), "."))
IMG = ROOT / "assets/images"
rng = random.Random(7)

INK = (15, 23, 32, 255)
NIGHT = (27, 42, 58, 255)
AMBER = (242, 179, 61, 255)
EMBER = (217, 85, 59, 255)
LEAF = (123, 200, 108, 255)
CREAM = (244, 233, 208, 255)
BLUE = (70, 130, 200, 255)
RED = (200, 60, 50, 255)
XP = (185, 140, 240, 255)


def up(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


FORCE = "--force" in sys.argv


def save(im, rel):
    """Writes a placeholder only where no real art exists yet (--force
    overwrites)."""
    p = IMG / rel
    if p.exists() and not FORCE:
        return
    p.parent.mkdir(parents=True, exist_ok=True)
    im.save(p)


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (c[3] if len(c) > 3 else 255,)


def boulder(d, cx, cy, rx, ry, base):
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=base, outline=INK)
    d.ellipse([cx - rx + 2, cy - ry + 1, cx + rx // 3, cy - ry // 4], fill=shade(base, 1.25))
    d.point([(cx + rx // 2, cy + ry // 3), (cx - rx // 3, cy + ry // 2)], fill=shade(base, 0.7))


# ------------------------------------------------------------------ bases
def cave(team):
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rock = (128, 116, 104, 255)
    d.polygon([(4, 63), (10, 34), (22, 20), (38, 16), (52, 24), (60, 40), (62, 63)], fill=rock, outline=INK)
    for (x, y, rx, ry) in [(14, 44, 9, 8), (30, 28, 10, 8), (46, 32, 9, 9), (52, 50, 9, 9), (20, 56, 9, 6), (40, 50, 8, 7)]:
        boulder(d, x, y, rx, ry, shade(rock, rng.uniform(0.85, 1.1)))
    d.ellipse([22, 40, 46, 70], fill=(30, 22, 18, 255), outline=INK)  # entrance
    d.rectangle([22, 56, 46, 63], fill=(30, 22, 18, 255))
    d.ellipse([30, 50, 38, 58], fill=(255, 150, 60, 140))  # fire glow
    # Flag on a pole, in team colour.
    d.line([(52, 24), (52, 4)], fill=(90, 60, 30, 255), width=2)
    col = BLUE if team == "player" else RED
    d.polygon([(53, 4), (63, 7), (53, 11)], fill=col, outline=INK)
    # Bone decorations.
    d.line([(16, 26), (22, 22)], fill=CREAM, width=2)
    d.line([(44, 18), (48, 22)], fill=CREAM, width=2)
    return up(im, 4)


def turret(team):
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    wood = (120, 80, 45, 255)
    d.rectangle([6, 22, 26, 27], fill=wood, outline=INK)
    d.ellipse([4, 25, 11, 31], fill=(80, 70, 60, 255), outline=INK)
    d.ellipse([21, 25, 28, 31], fill=(80, 70, 60, 255), outline=INK)
    d.line([(10, 22), (22, 6)], fill=shade(wood, 1.2), width=3)
    d.ellipse([19, 2, 27, 9], fill=(130, 120, 110, 255), outline=INK)
    d.rectangle([14, 16, 18, 22], fill=BLUE if team == "player" else RED, outline=INK)
    return up(im, 2)


# ------------------------------------------------------------ backgrounds
def sky():
    w, h = 320, 90
    im = Image.new("RGBA", (w, h))
    top, bot = (32, 52, 88), (240, 160, 110)
    for y in range(h):
        t = (y / (h - 1)) ** 1.3
        band = round(t * 10) / 10  # banded gradient = pixel-art sky
        c = tuple(int(top[i] + (bot[i] - top[i]) * band) for i in range(3))
        ImageDraw.Draw(im).line([(0, y), (w, y)], fill=c + (255,))
    d = ImageDraw.Draw(im)
    d.ellipse([228, 40, 252, 64], fill=(255, 214, 140, 255))
    d.ellipse([232, 44, 248, 60], fill=(255, 236, 190, 255))
    for _ in range(9):
        x, y = rng.randint(0, w), rng.randint(6, 40)
        for k in range(4):
            d.ellipse([x + k * 6, y - (k % 2) * 3, x + k * 6 + 12, y + 6], fill=(250, 220, 200, 120))
    for _ in range(30):
        d.point((rng.randint(0, w), rng.randint(0, 20)), fill=(255, 255, 255, 200))
    return up(im, 8)


def hills():
    w, h = 320, 90
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Volcano far away.
    d.polygon([(40, 72), (70, 34), (78, 34), (110, 72)], fill=(96, 70, 92, 255))
    d.polygon([(68, 34), (80, 34), (74, 26)], fill=(120, 80, 90, 255))
    d.ellipse([66, 14, 84, 30], fill=(120, 110, 120, 140))
    for layer, (col, base, amp) in enumerate([((92, 96, 130, 255), 58, 10), ((66, 104, 98, 255), 68, 8)]):
        pts = [(0, h)]
        for x in range(0, w + 8, 8):
            y = base - amp * (0.5 + 0.5 * math.sin(x / (23 + layer * 9) + layer)) - rng.randint(0, 3)
            pts.append((x, y))
        pts.append((w, h))
        d.polygon(pts, fill=col)
    return up(im, 8)


def near():
    w, h = 640, 180
    ground = 135  # = world y 405 of 540
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Trees and ferns behind the ground line.
    for x in range(10, w, 46):
        x += rng.randint(-10, 10)
        th = rng.randint(30, 52)
        d.rectangle([x, ground - th, x + 3, ground], fill=(80, 56, 36, 255))
        for k in range(5):
            ang = -math.pi / 2 + (k - 2) * 0.55
            ex, ey = x + 2 + math.cos(ang) * 18, ground - th + math.sin(ang) * 12 + 6
            d.line([(x + 2, ground - th), (ex, ey)], fill=(54, 120, 70, 255), width=3)
    d.rectangle([0, ground, w, h], fill=(112, 82, 56, 255))
    d.rectangle([0, ground, w, ground + 4], fill=(86, 150, 72, 255))
    d.rectangle([0, ground + 4, w, ground + 5], fill=(60, 110, 52, 255))
    for _ in range(260):
        x, y = rng.randint(0, w), rng.randint(ground + 7, h - 1)
        d.point((x, y), fill=(92, 66, 44, 255) if rng.random() < 0.7 else (140, 110, 80, 255))
    for _ in range(40):
        x, y = rng.randint(0, w), rng.randint(ground + 10, h - 6)
        boulder(d, x, y, rng.randint(2, 5), rng.randint(2, 3), (120, 112, 104, 255))
    for x in range(0, w, 3):
        if rng.random() < 0.5:
            d.line([(x, ground), (x, ground - rng.randint(1, 3))], fill=(96, 168, 80, 255))
    return up(im, 4)


# -------------------------------------------------------------------- fx
def stone():
    im = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([1, 1, 6, 6], fill=(150, 145, 140, 255), outline=INK)
    d.point((3, 2), fill=(210, 205, 200, 255))
    return up(im, 2)


def rock():
    im = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(2, 4), (5, 1), (9, 2), (11, 6), (8, 10), (3, 10), (1, 7)], fill=(130, 120, 110, 255), outline=INK)
    d.point([(5, 3), (6, 3)], fill=(190, 180, 170, 255))
    return up(im, 2)


def meteor():
    """Fireball pointing down, tail up (the game rotates it to its path)."""
    im = Image.new("RGBA", (16, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i, col in enumerate([(255, 90, 40, 120), (255, 140, 50, 170), (255, 200, 90, 220)]):
        d.polygon([(8, 0 + i * 4), (2 + i, 22), (14 - i, 22)], fill=col)
    d.ellipse([2, 18, 14, 30], fill=(110, 80, 70, 255), outline=INK)
    d.ellipse([4, 20, 9, 24], fill=(255, 170, 80, 255))
    return up(im, 2).resize((32, 64), Image.NEAREST).crop((0, 0, 32, 64)).resize((32, 32), Image.NEAREST)


def blast():
    frames = []
    for i in range(6):
        im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        r = 4 + i * 2.4
        fade = 1 - i / 6
        d.ellipse([16 - r, 28 - r * 1.3, 16 + r, 30], fill=(255, 120, 40, int(230 * fade)))
        d.ellipse([16 - r * 0.6, 28 - r, 16 + r * 0.6, 30], fill=(255, 210, 110, int(240 * fade)))
        for _ in range(4 + i):
            a = rng.uniform(math.pi, 2 * math.pi)
            dist = r + rng.uniform(0, 4)
            d.point((16 + math.cos(a) * dist, 28 + math.sin(a) * dist), fill=(120, 100, 90, int(255 * fade)))
        frames.append(up(im, 2))
    strip = Image.new("RGBA", (64 * 6, 64), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.alpha_composite(f, (i * 64, 0))
    return strip


# ----------------------------------------------------------------- icons
def tile(fn):
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    fn(ImageDraw.Draw(im), im)
    return up(im, 4)


def icon_gold(d, im):
    d.ellipse([6, 6, 26, 26], fill=AMBER, outline=INK, width=2)
    d.ellipse([10, 10, 22, 22], outline=shade(AMBER, 0.7), width=2)
    d.point([(11, 9), (12, 9)], fill=CREAM)


def icon_xp(d, im):
    pts = []
    for k in range(10):
        r = 13 if k % 2 == 0 else 6
        a = -math.pi / 2 + k * math.pi / 5
        pts.append((16 + r * math.cos(a), 17 + r * math.sin(a)))
    d.polygon(pts, fill=XP, outline=INK)


def icon_meteor(d, im):
    d.polygon([(24, 2), (12, 18), (20, 18)], fill=(255, 140, 50, 255))
    d.polygon([(28, 6), (16, 20), (22, 20)], fill=(255, 200, 90, 255))
    d.ellipse([6, 14, 22, 30], fill=(110, 80, 70, 255), outline=INK, width=2)
    d.ellipse([9, 17, 14, 22], fill=(255, 170, 80, 255))


def icon_turret(d, im):
    t = turret("player").resize((28, 28), Image.NEAREST)
    im.alpha_composite(t, (2, 2))


def icon_evolve(d, im):
    d.polygon([(16, 3), (27, 15), (21, 15), (21, 28), (11, 28), (11, 15), (5, 15)], fill=XP, outline=INK)
    d.line([(14, 18), (14, 25)], fill=CREAM)


def star(filled):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pts = []
    for k in range(10):
        r = 7 if k % 2 == 0 else 3
        a = -math.pi / 2 + k * math.pi / 5
        pts.append((8 + r * math.cos(a), 8.5 + r * math.sin(a)))
    d.polygon(pts, fill=AMBER if filled else (60, 72, 90, 255), outline=INK)
    if filled:
        d.point([(7, 5), (6, 7)], fill=CREAM)
    return up(im, 4)


# -------------------------------------------------------------- launcher
def launcher_art(size, units_dir, inset=0.0, bg=True):
    """Clubman on a warm glow. inset shrinks the art (adaptive icon safe zone)."""
    im = Image.new("RGBA", (size, size), NIGHT if bg else (0, 0, 0, 0))
    if bg:
        glow = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        for r, a in [(30, 60), (24, 90), (18, 130)]:
            gd.ellipse([32 - r, 36 - r, 32 + r, 36 + r], fill=(242, 140, 61, a))
        im.alpha_composite(glow.resize((size, size), Image.NEAREST))
    strip = Image.open(units_dir / "stone_clubman_idle.png")
    fw = strip.width // 4
    frame = strip.crop((0, 0, fw, strip.height))
    frame = frame.crop(frame.getbbox())
    box = size * (1 - 2 * inset) * 0.86
    k = box / max(frame.width, frame.height)
    fr = frame.resize((max(1, int(frame.width * k)), max(1, int(frame.height * k))), Image.NEAREST)
    im.alpha_composite(fr, ((size - fr.width) // 2, int(size - size * inset - fr.height - size * 0.04)))
    return im


def main():
    for team, red in [("player", False), ("enemy", True)]:
        save(cave(team), f"bases/stone_base{'_red' if red else ''}.png")
        save(turret(team), f"bases/stone_turret{'_red' if red else ''}.png")
        save(turret(team), f"bases/stone_turret_fire{'_red' if red else ''}.png")
    save(sky(), "bg/stone_sky.png")
    save(hills(), "bg/stone_hills.png")
    save(near(), "bg/stone_near.png")
    save(stone(), "fx/stone.png")
    save(rock(), "fx/rock.png")
    save(meteor(), "fx/meteor.png")
    save(blast(), "fx/blast.png")
    save(tile(icon_gold), "icons/icon_gold.png")
    save(tile(icon_xp), "icons/icon_xp.png")
    save(tile(icon_meteor), "icons/icon_meteor.png")
    save(tile(icon_turret), "icons/icon_turret.png")
    save(tile(icon_evolve), "icons/icon_evolve.png")
    save(star(True), "ui/star.png")
    save(star(False), "ui/star_empty.png")

    units = IMG / "units"
    if not (units / "stone_clubman_idle.png").exists():
        print("run slice_sheets.py first for launcher icons")
        return
    res = ROOT / "android/app/src/main/res"
    for dens, k in [("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2), ("xxhdpi", 3), ("xxxhdpi", 4)]:
        legacy = int(48 * k)
        full = int(108 * k)
        d = res / f"mipmap-{dens}"
        d.mkdir(parents=True, exist_ok=True)
        icon = launcher_art(legacy, units)
        icon.save(d / "ic_launcher.webp")
        round_ = Image.new("RGBA", icon.size, (0, 0, 0, 0))
        mask = Image.new("L", icon.size, 0)
        ImageDraw.Draw(mask).ellipse([0, 0, legacy - 1, legacy - 1], fill=255)
        round_.paste(icon, (0, 0), mask)
        round_.save(d / "ic_launcher_round.webp")
        launcher_art(full, units, inset=0.2, bg=False).save(d / "ic_launcher_foreground.webp")
        Image.new("RGB", (full, full), NIGHT[:3]).save(d / "ic_launcher_background.webp")
        dd = res / f"drawable-{dens}"
        dd.mkdir(parents=True, exist_ok=True)
        launcher_art(int(120 * k), units, bg=False).save(dd / "splash_mark.png")
        launcher_art(int(288 * k), units, inset=0.22, bg=False).save(dd / "splash_icon_a12.png")
    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    if ios.exists():
        for f in ios.glob("*.png"):
            n = int(f.stem)
            launcher_art(n, units).convert("RGB").save(f)  # iOS icons: no alpha
    print("placeholders written")


if __name__ == "__main__":
    main()
