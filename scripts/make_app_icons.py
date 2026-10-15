#!/usr/bin/env python3
"""Regenerate the iOS AppIcon set and the Android launcher mipmaps from one
brand render (decision 0179: the metallic app icon replaces the flat one).

    python3 scripts/make_app_icons.py assets/brand/loop-app-icon-u3d.webp

The render has a dark rounded plate on a black ground; the plate is cropped
out (non-black bounding box, with a small bleed) so the OS mask rounds the
plate itself instead of leaving black corners.  Every slot ≤ the crop size is a
downscale; larger slots (the 1024 App Store icon) are upscaled and look soft
until a ≥1024 source is supplied — re-run with it and nothing else changes.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
IOS_SET = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
ANDROID_RES = ROOT / "android/app/src/main/res"
ANDROID_DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
BLACK_THRESHOLD = 28  # per-channel; the ground is #000-#050604
BLEED = 2  # px kept around the plate so anti-aliased edges survive
FOREGROUND_FILL = 0.78  # adaptive icon: plate size as a fraction of the 108 dp canvas


def crop_plate(image: Image.Image) -> Image.Image:
    rgb = image.convert("RGB")
    width, height = rgb.size
    pixels = rgb.load()
    left, top, right, bottom = width, height, -1, -1
    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            if max(r, g, b) > BLACK_THRESHOLD:
                left, top = min(left, x), min(top, y)
                right, bottom = max(right, x), max(bottom, y)
    if right < 0:
        raise SystemExit("no plate found: the image is all black")
    left, top = max(0, left - BLEED), max(0, top - BLEED)
    right, bottom = min(width - 1, right + BLEED), min(height - 1, bottom + BLEED)
    side = max(right - left, bottom - top) + 1
    cx, cy = (left + right) // 2, (top + bottom) // 2
    box = (cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side)
    return rgb.crop(box)


def resized(plate: Image.Image, size: int) -> Image.Image:
    return plate.resize((size, size), Image.Resampling.LANCZOS)


def write_ios(plate: Image.Image) -> list[str]:
    manifest = json.loads((IOS_SET / "Contents.json").read_text())
    written: list[str] = []
    for entry in manifest["images"]:
        filename = entry.get("filename")
        if not filename:
            continue
        points = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        size = round(points * scale)
        resized(plate, size).save(IOS_SET / filename, format="PNG", optimize=True)
        written.append(f"{filename} {size}px")
    return written


def write_android(plate: Image.Image) -> list[str]:
    written: list[str] = []
    for density, factor in ANDROID_DENSITIES.items():
        folder = ANDROID_RES / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        legacy = round(48 * factor)
        resized(plate, legacy).save(folder / "ic_launcher.png", format="PNG", optimize=True)
        canvas = round(108 * factor)
        inner = round(canvas * FOREGROUND_FILL)
        foreground = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        offset = (canvas - inner) // 2
        foreground.paste(resized(plate, inner), (offset, offset))
        foreground.save(folder / "ic_launcher_foreground.png", format="PNG", optimize=True)
        written.append(f"mipmap-{density}: launcher {legacy}px, foreground {canvas}px (plate {inner}px)")
    return written


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__)
        return 2
    source = Path(argv[1])
    with Image.open(source) as image:
        plate = crop_plate(image)
    print(f"source {source} {image.size[0]}x{image.size[1]} → plate {plate.size[0]}px")
    for line in write_ios(plate):
        print("  ios", line)
    for line in write_android(plate):
        print("  android", line)
    largest = max(1024, plate.size[0])
    if plate.size[0] < 1024:
        print(f"note: 1024 App Store icon is an upscale from {plate.size[0]}px; supply a ≥{largest}px source to sharpen it")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
