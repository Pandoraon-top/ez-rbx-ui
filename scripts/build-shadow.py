#!/usr/bin/env python3
"""Generate the 9-slice drop-shadow sprite EzUI paints under floating surfaces.

The sprite is a black square whose alpha falls off toward every edge. Roblox
stretches only the middle band of a Slice image, so the falloff has to live
entirely inside the border that SliceCenter cuts off: with SliceCenter
(49, 49, 450, 450) on a 512px sprite the outer 49px carry the whole gradient and
the inner 413px are flat, which is what lets one sprite wrap a window and a
tooltip alike without the blur thickening.

The alpha ramp is a smoothstep rather than a straight line: a linear ramp shows
a visible seam where it meets the flat centre, because the eye picks up the
sudden change in slope. Peak alpha stays under 1.0 since the layer is tinted
black and composited at a per-mode transparency on top (Theme.MODE_EFFECTS).

Usage:  python3 scripts/build-shadow.py [out.png]
        default out = assets/shadow-9slice.png
Then upload the PNG to Roblox, take the resulting asset id, and set
Theme.Effect.shadowId = "rbxassetid://<id>" in core/theme.lua.
"""
import sys
import os
import numpy as np
from PIL import Image

# SIZE and BORDER are derived from Theme.Effect.slice, not the other way round: the token was
# written as (49, 49, 450, 450), so a symmetric sprite has to be 450 + 49 = 499 square. Roblox
# keeps an uploaded image at its native size (up to 1024) and SliceCenter is in those same pixels,
# so a non power-of-two sprite costs nothing here and saves editing a token every component reads.
SIZE = 499
BORDER = 49         # equals Theme.Effect.slice x0/y0, and SIZE - BORDER equals x1/y1
PEAK_ALPHA = 0.55   # alpha at the flat centre, before the per-mode transparency


def smoothstep(t: np.ndarray) -> np.ndarray:
    """3t^2 - 2t^3: zero slope at both ends, so the ramp meets the flat centre seamlessly."""
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def build(size: int = SIZE, border: int = BORDER, peak: float = PEAK_ALPHA) -> Image.Image:
    # Distance from each edge, in pixels, for every column (rows are the same by symmetry).
    idx = np.arange(size)
    edge_distance = np.minimum(idx, size - 1 - idx).astype(np.float64)
    # 0 at the outermost pixel, 1 once we reach the slice border.
    ramp = smoothstep(edge_distance / float(border))

    # A separable 2D falloff: multiplying the two axes keeps the corners darker than
    # either edge alone, which is how a real shadow behaves under a rounded panel.
    alpha = np.outer(ramp, ramp) * peak

    rgba = np.zeros((size, size, 4), dtype=np.uint8)
    rgba[..., 3] = np.rint(alpha * 255).astype(np.uint8)  # RGB stays 0: the layer is tinted in-engine
    return Image.fromarray(rgba, mode="RGBA")


def main() -> int:
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/shadow-9slice.png"
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    img = build()
    img.save(out, optimize=True)

    a = np.asarray(img)[..., 3]
    print(f"wrote {out}  {img.width}x{img.height}")
    print(f"  centre alpha {a[SIZE // 2, SIZE // 2]}/255, edge alpha {a[0, SIZE // 2]}/255")
    print(f"  SliceCenter must stay ({BORDER}, {BORDER}, {SIZE - BORDER}, {SIZE - BORDER})"
          f" -- matches Theme.Effect.slice")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
