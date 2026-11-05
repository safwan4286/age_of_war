"""Frames exported from AI video clips (Veo) on a magenta background:
keying, clean-up and absolute positions.

Each clip folder holds PNG frames cropped from the video at 800 px wide,
plus box.txt with the crop's x0 y0 x1 y1 in the 800-wide frame, so every
frame of every clip of a unit shares one coordinate system (the camera is
locked and all clips start from the same master image).
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


def magenta_bg(rgb):
    """Veo's magenta drifts pinker and darker between clips; it also adds
    a soft purple floor shadow and sparkle specks. All of it counts as
    background."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (r - g > 60) & (b - g > 60) & (np.abs(r - b) < 110)


def key_frame(path: Path, ground_y=None, keep_ground=False):
    """RGBA of the character (and, with keep_ground, props lying near the
    ground line such as a dropped weapon). Floating pieces (a flying arrow,
    motion streaks, sparkles) are dropped."""
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(int)
    fg = ndimage.binary_opening(~magenta_bg(rgb), iterations=1)
    lab, n = ndimage.label(fg)
    if n == 0:
        return None
    sizes = ndimage.sum(fg, lab, range(1, n + 1))
    main = int(sizes.argmax()) + 1
    objs = ndimage.find_objects(lab)
    msl = objs[main - 1]
    mh = msl[0].stop - msl[0].start
    keep = [main]
    for i, sl in enumerate(objs, 1):
        if i == main or sizes[i - 1] < max(60, 0.004 * sizes.max()):
            continue
        # Pieces touching or inside the main figure's box (a sword tip, a
        # bow string gap) belong to it.
        inside = (sl[0].start >= msl[0].start - 0.05 * mh and sl[0].stop <= msl[0].stop + 4
                  and sl[1].start >= msl[1].start - 0.05 * mh and sl[1].stop <= msl[1].stop + 0.05 * mh)
        grounded = keep_ground and ground_y is not None and sl[0].stop >= ground_y - 0.08 * mh
        if inside or grounded:
            keep.append(i)
    m = np.isin(lab, keep)
    # Partial-alpha edge: magenta-tinted rim pixels lose their tint.
    a = np.where(m, 255, 0).astype(np.uint8)
    out = rgb.copy()
    rim = m & ~ndimage.binary_erosion(m, iterations=1)
    pink = rim & (out[..., 0] - out[..., 1] > 30) & (out[..., 2] - out[..., 1] > 30)
    out[pink] = (out[pink] * [0.55, 0.55, 0.55]).astype(int)
    return Image.fromarray(np.dstack([out, a]).astype(np.uint8), "RGBA")


class Clip:
    def __init__(self, folder: Path):
        self.folder = folder
        self.frames = sorted(folder.glob("*.png"))
        self.x0, self.y0, *_ = map(int, (folder / "box.txt").read_text().split())

    def __len__(self):
        return len(self.frames)

    def keyed(self, i, ground_y=None, keep_ground=False):
        """Frame i keyed, and its top-left in the shared 800-wide frame."""
        img = key_frame(self.frames[i], None if ground_y is None else ground_y - self.y0, keep_ground)
        return img, (self.x0, self.y0)
