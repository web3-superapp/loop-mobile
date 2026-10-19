#!/usr/bin/env python3
"""Regenerate the launcher / store icons from the official square artwork
(decision 0207).

    arch -x86_64 /usr/bin/python3 tool/brand/make_official_icons.py \
        ../docs/assets/app-icon-2026-10-19/LOOP-CROWN-square-1024.png

Needs Pillow only (this Mac only has an x86_64 Pillow, hence `arch -x86_64`).
Optional `LOOP_LOGO_PREVIEW_DIR=<dir>` exports review previews.

The artwork is a full-bleed 1024 square without alpha: black texture, yellow
neon "LOOP" and crown running corner to corner. This script owns:

* iOS AppIcon, every slot in Contents.json (direct downscale, RGB, no inset:
  iOS rounds the corners itself);
* Android `ic_launcher` (direct downscale) and `ic_launcher_round` (the
  adaptive composite inside a disc, so no stroke is cut);
* Android adaptive layers: `ic_launcher_background` = the artwork's own
  text-free texture (top and bottom bands, mirror-tiled, softened) and
  `ic_launcher_foreground` = the whole artwork scaled so the farthest yellow
  stroke sits inside the 66 dp safe circle, with a feathered edge onto
  transparency;
* Web favicon, Icon-192/512 (direct) and Icon-maskable-192/512 (composite,
  strokes inside the 40 % safe circle);
* `assets/brand/loop-app-icon-official.webp` for the login mark.

The small in-app marks (wallet ring 54, sidebar 32, square badge 18), the
wordmark, the launch frames and the notification crown stay on the S244
vector pipeline, `tool/brand/make_crown_icons.py` (decision 0205), which no
longer writes any surface listed above.
"""
from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parent.parent.parent
BRAND = ROOT / "assets/brand"
IOS_ICON_SET = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
ANDROID_RES = ROOT / "android/app/src/main/res"
WEB = ROOT / "web"
PREVIEW = Path(os.environ.get("LOOP_LOGO_PREVIEW_DIR", ""))

ANDROID_DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
ADAPTIVE_DP = 108
SAFE_RADIUS_DP = 32.0  # 66 dp safe circle (r 33) minus 1 dp
VISIBLE_DP = 72  # what a launcher mask shows of the 108 dp canvas
MASKABLE_RADIUS = 0.38  # web maskable safe zone is r 40 %
FEATHER = 0.07  # feathered edge of the foreground, share of its side
STROKE_LEVEL = 120  # a pixel is "stroke" when min(r, g) - b and r exceed this
# Text-free texture bands of the 2026-10-19 artwork (rows, 1024 scale).
TEXTURE_BANDS = ((0, 90), (905, 1024))
LOGIN_WEBP = 512


def load(source: Path) -> Image.Image:
    image = Image.open(source)
    if image.size[0] != image.size[1]:
        raise SystemExit(f"{source} must be square, got {image.size}")
    return image.convert("RGB").resize((1024, 1024), Image.LANCZOS)


def stroke_radius(art: Image.Image) -> float:
    """Farthest yellow stroke pixel from the centre, as a share of the side."""
    px = art.load()
    size = art.size[0]
    c = size / 2
    r2 = 0.0
    for y in range(size):
        for x in range(size):
            r, g, b = px[x, y]
            if r > STROKE_LEVEL and g > STROKE_LEVEL * 0.8 and b < r * 0.6:
                r2 = max(r2, (x + 0.5 - c) ** 2 + (y + 0.5 - c) ** 2)
    return math.sqrt(r2) / size


def texture(art: Image.Image, size: int) -> Image.Image:
    """A text-free plate from the artwork's own texture: the clean top and
    bottom bands stacked, mirror-tiled to `size`, softened and dimmed a touch
    so it reads as the ground behind the foreground."""
    bands = [art.crop((0, y0, 1024, y1)) for y0, y1 in TEXTURE_BANDS]
    strip_h = sum(b.size[1] for b in bands)
    strip = Image.new("RGB", (1024, strip_h))
    y = 0
    for band in bands:
        strip.paste(band, (0, y))
        y += band.size[1]
    tile = Image.new("RGB", (2048, strip_h * 2))
    tile.paste(strip, (0, 0))
    tile.paste(strip.transpose(Image.FLIP_LEFT_RIGHT), (1024, 0))
    flipped = strip.transpose(Image.FLIP_TOP_BOTTOM)
    tile.paste(flipped, (0, strip_h))
    tile.paste(flipped.transpose(Image.FLIP_LEFT_RIGHT), (1024, strip_h))
    plate = Image.new("RGB", (size, size))
    for ty in range(0, size, tile.size[1]):
        for tx in range(0, size, tile.size[0]):
            plate.paste(tile, (tx, ty))
    plate = plate.filter(ImageFilter.GaussianBlur(1.2))
    return ImageEnhance.Brightness(plate).enhance(0.85)


def feather_mask(side: int) -> Image.Image:
    ramp = max(1, round(side * FEATHER))
    line = []
    for i in range(side):
        d = min(i + 0.5, side - i - 0.5) / ramp
        t = max(0.0, min(1.0, d))
        line.append(round(255 * t * t * (3 - 2 * t)))
    horizontal = Image.new("L", (side, 1))
    horizontal.putdata(line)
    horizontal = horizontal.resize((side, side), Image.NEAREST)
    return ImageChops.multiply(horizontal, horizontal.transpose(Image.TRANSPOSE))


def foreground(art: Image.Image, canvas: int, side: int) -> Image.Image:
    """The artwork at `side` px, feathered onto a transparent `canvas`."""
    scaled = art.resize((side, side), Image.LANCZOS).convert("RGBA")
    scaled.putalpha(feather_mask(side))
    layer = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    offset = (canvas - side) // 2
    layer.paste(scaled, (offset, offset))
    return layer


def composite(art: Image.Image, canvas: int, side: int) -> Image.Image:
    plate = texture(art, max(canvas, 1024)).resize((canvas, canvas), Image.LANCZOS).convert("RGBA")
    return Image.alpha_composite(plate, foreground(art, canvas, side))


def disc(image: Image.Image) -> Image.Image:
    size = image.size[0]
    big = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(big).ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
    out = image.convert("RGBA")
    out.putalpha(ImageChops.multiply(out.getchannel("A"), big.resize((size, size), Image.LANCZOS)))
    return out


def save_rgb(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(path, optimize=True)


def save_rgba(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGBA").save(path, optimize=True)


def main(source: Path) -> None:
    art = load(source)
    radius = stroke_radius(art)
    fg_side_dp = SAFE_RADIUS_DP / radius
    mask_side = MASKABLE_RADIUS / radius
    print(
        f"stroke radius {radius:.3f} of side; adaptive foreground {fg_side_dp:.1f} dp "
        f"({fg_side_dp / ADAPTIVE_DP:.1%} of 108 dp), farthest stroke {SAFE_RADIUS_DP:.1f} dp; "
        f"maskable side {mask_side:.1%}"
    )

    # iOS AppIcon: every slot, direct downscale, opaque.
    manifest = json.loads((IOS_ICON_SET / "Contents.json").read_text())
    done: set[str] = set()
    for entry in manifest["images"]:
        name = entry.get("filename")
        if not name or name in done:
            continue
        points = float(entry["size"].split("x")[0])
        pixels = round(points * float(entry["scale"].rstrip("x")))
        save_rgb(art.resize((pixels, pixels), Image.LANCZOS), IOS_ICON_SET / name)
        done.add(name)
    print(f"iOS AppIcon: {len(done)} files")

    # Android.
    for bucket, density in ANDROID_DENSITIES.items():
        mipmap = ANDROID_RES / f"mipmap-{bucket}"
        canvas = round(ADAPTIVE_DP * density)
        side = round(fg_side_dp * density)
        save_rgba(foreground(art, canvas, side), mipmap / "ic_launcher_foreground.png")
        save_rgb(
            texture(art, 1024).resize((canvas, canvas), Image.LANCZOS),
            mipmap / "ic_launcher_background.png",
        )
        legacy = round(48 * density)
        save_rgb(art.resize((legacy, legacy), Image.LANCZOS), mipmap / "ic_launcher.png")
        # Legacy round: the 72 dp a launcher shows of the adaptive composite, in a disc.
        visible = composite(art, canvas * 4, side * 4)
        inset = (canvas * 4 - round(VISIBLE_DP * density) * 4) // 2
        visible = visible.crop((inset, inset, canvas * 4 - inset, canvas * 4 - inset))
        save_rgba(disc(visible.resize((legacy, legacy), Image.LANCZOS)), mipmap / "ic_launcher_round.png")

    # Web.
    save_rgb(art.resize((32, 32), Image.LANCZOS), WEB / "favicon.png")
    for size in (192, 512):
        save_rgb(art.resize((size, size), Image.LANCZOS), WEB / f"icons/Icon-{size}.png")
        save_rgb(composite(art, size, round(size * mask_side)), WEB / f"icons/Icon-maskable-{size}.png")

    # In-app login mark.
    art.resize((LOGIN_WEBP, LOGIN_WEBP), Image.LANCZOS).save(
        BRAND / "loop-app-icon-official.webp", quality=90, method=6
    )

    if PREVIEW.parts:
        PREVIEW.mkdir(parents=True, exist_ok=True)
        save_rgb(art.resize((180, 180), Image.LANCZOS), PREVIEW / "ios-icon-180.png")
        # What a circular launcher mask shows: the 72 dp middle of 108 dp, 432 px.
        full = composite(art, 648, round(fg_side_dp * 6))
        inset = (648 - VISIBLE_DP * 6) // 2
        shown = full.crop((inset, inset, 648 - inset, 648 - inset)).resize((432, 432), Image.LANCZOS)
        ground = Image.new("RGBA", (432, 432), (0xF3, 0xF5, 0xEF, 255))
        save_rgb(Image.alpha_composite(ground, disc(shown)), PREVIEW / "android-adaptive-circle-preview-432.png")
        # Login mark at 104 pt @3x, with the rounded clip LoopBrandMark applies.
        login = art.resize((312, 312), Image.LANCZOS).convert("RGBA")
        big = Image.new("L", (1248, 1248), 0)
        ImageDraw.Draw(big).rounded_rectangle((0, 0, 1247, 1247), radius=round(1248 * 0.225), fill=255)
        login.putalpha(big.resize((312, 312), Image.LANCZOS))
        page = Image.new("RGBA", (312 + 96, 312 + 96), (0x05, 0x06, 0x04, 255))
        page.alpha_composite(login, (48, 48))
        save_rgb(page, PREVIEW / "login-104@3x.png")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    main(Path(sys.argv[1]).resolve())
