#!/usr/bin/env python3
"""Generates the PulseFit app icon (1024x1024 PNG) with no image dependencies.

Design: dark green diagonal gradient background with a glowing volt-lime
heartbeat line. Uses numpy for speed; writes a standards-compliant PNG via
zlib (color type 6, RGBA).

Usage: python3 generate_icon.py [output_path]
"""

import struct
import sys
import zlib

import numpy as np

SIZE = 1024
SS = 2  # supersampling factor
N = SIZE * SS

# Heartbeat polyline (design coordinates in a 1024 space)
POINTS = [
    (140, 512),
    (320, 512),
    (400, 320),
    (500, 700),
    (580, 430),
    (640, 512),
    (884, 512),
]
HALF_WIDTH = 22.0  # half stroke width in design px
GLOW_SIGMA = 42.0

BG_TOP_LEFT = np.array([0.043, 0.090, 0.066], dtype=np.float32)   # #0B1711
BG_BOTTOM_RIGHT = np.array([0.118, 0.239, 0.165], dtype=np.float32)  # #1E3D2A
LINE_COLOR = np.array([0.722, 0.945, 0.298], dtype=np.float32)    # #B8F14C


def smoothstep_core(dist):
    """1 inside the stroke, smooth 1px-ish falloff at the edge (supersampled)."""
    edge = HALF_WIDTH * SS
    return np.clip((edge + 1.0 - dist) / 2.0, 0.0, 1.0)


def segment_distance(px, py, ax, ay, bx, by):
    """Distance from every grid point to segment ab, all in supersampled px."""
    abx, aby = bx - ax, by - ay
    ab_len_sq = max(abx * abx + aby * aby, 1e-9)
    t = ((px - ax) * abx + (py - ay) * aby) / ab_len_sq
    t = np.clip(t, 0.0, 1.0)
    cx, cy = ax + t * abx, ay + t * aby
    return np.sqrt((px - cx) ** 2 + (py - cy) ** 2)


def build():
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float32)
    px = xs
    py = ys

    # Distance to the whole polyline.
    dist = np.full((N, N), np.inf, dtype=np.float32)
    for (ax, ay), (bx, by) in zip(POINTS[:-1], POINTS[1:]):
        ax, ay, bx, by = ax * SS, ay * SS, bx * SS, by * SS
        d = segment_distance(px, py, ax, ay, bx, by)
        np.minimum(dist, d, out=dist)

    # Background: diagonal gradient + soft radial lime glow near center.
    t = (xs + ys) / (2.0 * N)
    t = np.stack([t, t, t], axis=-1)
    img = BG_TOP_LEFT[None, None, :] * (1.0 - t) + BG_BOTTOM_RIGHT[None, None, :] * t
    cx = cy = N / 2.0
    r2 = (xs - cx) ** 2 + (ys - cy) ** 2
    radial = np.exp(-r2 / (2.0 * (0.42 * N) ** 2)).astype(np.float32)
    img[..., 1] += 0.10 * radial
    img[..., 0] += 0.03 * radial

    # Line coverage: hard core with AA edge + soft glow around it.
    core = smoothstep_core(dist)
    edge = HALF_WIDTH * SS
    glow = np.exp(-np.square(dist - edge) / (2.0 * (GLOW_SIGMA * SS) ** 2)) * 0.45
    alpha = np.maximum(core, glow)[..., None]

    img = img * (1.0 - alpha) + LINE_COLOR[None, None, :] * alpha
    img = np.clip(img, 0.0, 1.0)

    # Downsample (box filter) to final size, add opaque alpha.
    img = img.reshape(SIZE, SS, SIZE, SS, 3).mean(axis=(1, 3))
    rgba = np.dstack([
        (img * 255.0 + 0.5).astype(np.uint8),
        np.full((SIZE, SIZE), 255, dtype=np.uint8),
    ])
    return rgba


def write_png(path, rgba):
    h, w = rgba.shape[:2]
    raw = b"".join(b"\x00" + rgba[y].tobytes() for y in range(h))

    def chunk(tag, payload):
        return (
            struct.pack(">I", len(payload))
            + tag
            + payload
            + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", ihdr)
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "AppIcon.png"
    rgba = build()
    write_png(out, rgba)
    print(f"wrote {out} ({SIZE}x{SIZE}, RGBA)")


if __name__ == "__main__":
    main()
