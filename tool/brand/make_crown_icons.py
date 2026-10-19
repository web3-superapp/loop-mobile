#!/usr/bin/env python3
"""Regenerate every LOOP brand bitmap from the crown logo (decision 0205).

    arch -x86_64 /usr/bin/python3 tool/brand/make_crown_icons.py \
        ../docs/assets/logo-loop-crown-2026-10-19.png

Needs: `potrace` on PATH (brew install potrace), Pillow (this Mac only has an
x86_64 Pillow, hence `arch -x86_64`), and node with `@resvg/resvg-js` on
NODE_PATH (see tool/brand/resvg_render.js).

Pipeline, in order:
1. Split the two-colour source PNG into a crown (yellow) and a text (white)
   coverage mask, upscale x8, threshold, trace each with potrace.
2. Write `assets/brand/loop-logo-crown.svg` (480x310 viewBox, transparent).
   Every bitmap below is rendered from SVGs built on these paths; nothing is
   resampled from the source PNG.
3. Compose the square small mark (Ink #050604 ground, logo 72 % wide) and
   render launch images and the in-app brand assets. Since decision 0207 the
   iOS AppIcon, Android launcher mipmaps and web icons are cut from the
   official square artwork by tool/brand/make_official_icons.py instead; the
   vector mark stays for the small in-app sizes (54 / 32 / 18) where the
   artwork would blur.
4. Write the white crown silhouette as the Android notification vector.

When a larger source arrives, run this again with it; step 1 is the only
place the source is read.
"""
from __future__ import annotations

import math
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent.parent
RENDER_JS = ROOT / "tool/brand/resvg_render.js"
BRAND = ROOT / "assets/brand"
IOS_LAUNCH_SET = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
ANDROID_RES = ROOT / "android/app/src/main/res"
PREVIEW = Path(os.environ.get("LOOP_LOGO_PREVIEW_DIR", ""))

INK = "#050604"
# Measured from the source PNG (opaque yellow pixels: rgb(253,235,0)).
CROWN = "#FDEB00"
TEXT = "#FFFFFF"

UPSCALE = 8  # trace at 8x the source so curves follow the anti-aliased edge
THRESHOLD = 110  # coverage (0-255) that counts as ink; keeps the dry-brush gaps
TURD = 60  # potrace: drop specks under 60 px² at 8x (~1 px² in the source)

ICON_LOGO_WIDTH = 0.72  # square icon: logo bbox width / canvas
ANDROID_DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
LAUNCH_WORDMARK_DP = 160  # launch frame wordmark width, iOS pt and Android dp


# --------------------------------------------------------------------- trace


def split_and_trace(source: Path, work: Path) -> tuple[int, int, dict[str, str]]:
    image = Image.open(source).convert("RGBA")
    width, height = image.size
    crown, text = [], []
    for r, _g, b, a in image.getdata():
        # Yellow has r-b ≈ 253, white ≈ 0; anti-aliased pixels split by hue.
        share = max(0.0, min(1.0, (r - b - 40) / 160.0))
        crown.append(int(a * share + 0.5))
        text.append(int(a * (1 - share) + 0.5))
    traced: dict[str, str] = {}
    for name, data in (("crown", crown), ("text", text)):
        layer = Image.new("L", image.size)
        layer.putdata(data)
        big = layer.resize((width * UPSCALE, height * UPSCALE), Image.LANCZOS)
        big = big.filter(ImageFilter.GaussianBlur(UPSCALE * 0.35))
        bitmap = big.point(lambda v: 0 if v >= THRESHOLD else 255).convert("1")
        pbm = work / f"{name}.pbm"
        svg = work / f"{name}.svg"
        bitmap.save(pbm)
        subprocess.run(
            ["potrace", str(pbm), "-s", "-t", str(TURD), "-a", "1.0", "-O", "0.4", "-o", str(svg)],
            check=True,
        )
        traced[name] = potrace_to_absolute(svg.read_text(), height)
    return width, height, traced


_TOKEN = re.compile(r"[MmCcLlZz]|-?\d+(?:\.\d+)?")


def potrace_to_absolute(svg: str, height: int) -> str:
    """Potrace writes relative paths under translate(0,H*k) scale(.1,-.1);
    rewrite them as absolute commands in the source's own pixel space."""
    out: list[str] = []
    for d in re.findall(r'<path d="([^"]+)"', svg):
        tokens = _TOKEN.findall(d)
        i, cmd = 0, ""
        x = y = sx = sy = 0.0

        def num() -> float:
            nonlocal i
            value = float(tokens[i])
            i += 1
            return value

        def pt(px: float, py: float) -> str:
            ux = px * 0.1 / UPSCALE
            uy = height - py * 0.1 / UPSCALE
            return f"{ux:.2f} {uy:.2f}"

        while i < len(tokens):
            if tokens[i].isalpha():
                cmd = tokens[i]
                i += 1
                if cmd in "Zz":
                    out.append("Z")
                    x, y = sx, sy
                    continue
            if cmd in "Mm":
                nx, ny = num(), num()
                if cmd == "m":
                    nx, ny = x + nx, y + ny
                x, y, sx, sy = nx, ny, nx, ny
                out.append("M" + pt(x, y))
                cmd = "l" if cmd == "m" else "L"
            elif cmd in "Ll":
                nx, ny = num(), num()
                if cmd == "l":
                    nx, ny = x + nx, y + ny
                x, y = nx, ny
                out.append("L" + pt(x, y))
            elif cmd in "Cc":
                coords = [num() for _ in range(6)]
                if cmd == "c":
                    coords = [c + (x if k % 2 == 0 else y) for k, c in enumerate(coords)]
                out.append(
                    "C" + pt(coords[0], coords[1]) + " " + pt(coords[2], coords[3]) + " " + pt(coords[4], coords[5])
                )
                x, y = coords[4], coords[5]
            else:
                raise ValueError(f"unexpected potrace command {cmd!r}")
    return "".join(out)


def transform_path(d: str, scale: float, tx: float, ty: float, digits: int = 2) -> str:
    def repl(match: re.Match[str]) -> str:
        a, b = float(match.group(1)), float(match.group(2))
        return f"{a * scale + tx:.{digits}f} {b * scale + ty:.{digits}f}"

    return re.sub(r"(-?\d+\.\d+) (-?\d+\.\d+)", repl, d)


# -------------------------------------------------------------------- render


def render(svg: str, out: Path, width: int, work: Path) -> Path:
    src = work / f"render-{abs(hash(svg))}.svg"
    src.write_text(svg)
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["node", str(RENDER_JS), str(src), str(out), str(width)], check=True)
    return out


def opaque(path: Path) -> None:
    """iOS and App Store icons must carry no alpha channel."""
    Image.open(path).convert("RGB").save(path, optimize=True)


def measure(svg: str, view_w: int, view_h: int, work: Path) -> tuple[float, float, float, float, float]:
    """Content bbox and the farthest painted pixel from the bbox centre, in
    viewBox units (rendered at 4x, alpha > 16)."""
    k = 4
    png = render(svg, work / "measure.png", view_w * k, work)
    alpha = Image.open(png).getchannel("A").point(lambda v: 255 if v > 16 else 0)
    x0, y0, x1, y1 = alpha.getbbox()
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    width = alpha.size[0]
    r2 = 0.0
    for index, value in enumerate(alpha.getdata()):
        if value:
            px, py = index % width + 0.5, index // width + 0.5
            r2 = max(r2, (px - cx) ** 2 + (py - cy) ** 2)
    return x0 / k, y0 / k, x1 / k, y1 / k, math.sqrt(r2) / k


# ------------------------------------------------------------------- compose


def logo_paths(traced: dict[str, str], scale: float = 1, tx: float = 0, ty: float = 0) -> str:
    text = transform_path(traced["text"], scale, tx, ty)
    crown = transform_path(traced["crown"], scale, tx, ty)
    return (
        f'<path fill="{TEXT}" fill-rule="evenodd" d="{text}"/>'
        f'<path fill="{CROWN}" fill-rule="evenodd" d="{crown}"/>'
    )


def svg_doc(view: tuple[float, float], body: str, comment: str) -> str:
    w, h = view
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:g} {h:g}" width="{w:g}" height="{h:g}">\n'
        f"<!-- {comment} -->\n{body}\n</svg>\n"
    )


def square(traced, box, size: float, scale: float, ground: str | None, round_ground: bool = False) -> str:
    x0, y0, x1, y1, _ = box
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    tx, ty = size / 2 - cx * scale, size / 2 - cy * scale
    plate = ""
    if ground and round_ground:
        plate = f'<circle cx="{size / 2:g}" cy="{size / 2:g}" r="{size / 2:g}" fill="{ground}"/>'
    elif ground:
        plate = f'<rect width="{size:g}" height="{size:g}" fill="{ground}"/>'
    return plate + logo_paths(traced, scale, tx, ty)


# ---------------------------------------------------------------------- main


def main(source: Path) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        src_w, src_h, traced = split_and_trace(source, work)
        provenance = (
            "LOOP crown logo (decision 0205): potrace 1.16 trace of "
            f"docs/assets/{source.name} ({src_w}x{src_h}, two colours); crown {CROWN}, text {TEXT}"
        )
        logo_svg = svg_doc((src_w, src_h), logo_paths(traced), provenance + "; transparent ground")
        (BRAND / "loop-logo-crown.svg").write_text(logo_svg)
        box = measure(logo_svg, src_w, src_h, work)
        x0, y0, x1, y1, radius = box
        print(f"logo bbox {x0:.1f},{y0:.1f}-{x1:.1f},{y1:.1f} radius {radius:.1f}")

        icon_scale = ICON_LOGO_WIDTH * 1024 / (x1 - x0)
        icon_dark = svg_doc((1024, 1024), square(traced, box, 1024, icon_scale, INK), provenance + "; Ink ground")
        icon_clear = svg_doc(
            (1024, 1024), square(traced, box, 1024, icon_scale, None), provenance + "; square, transparent ground"
        )
        print(f"icon logo width {(x1 - x0) * icon_scale / 1024:.0%}")

        # In-app brand assets.
        (BRAND / "loop-app-icon-crown.svg").write_text(icon_clear)
        webp = render(icon_dark, work / "icon-512.png", 512, work)
        Image.open(webp).convert("RGB").save(BRAND / "loop-app-icon-crown.webp", lossless=True, method=6)
        for folder, width in (("", 240), ("2.0x/", 480), ("3.0x/", 720)):
            render(logo_svg, BRAND / f"{folder}loop-wordmark-crown.png", width, work)

        # iOS launch image: transparent wordmark on the storyboard's Ink.
        for suffix, factor in (("", 1), ("@2x", 2), ("@3x", 3)):
            render(logo_svg, IOS_LAUNCH_SET / f"LaunchImage{suffix}.png", LAUNCH_WORDMARK_DP * factor, work)

        # Android launch bitmap. Launcher mipmaps, iOS AppIcon and web icons
        # come from the official artwork since decision 0207
        # (tool/brand/make_official_icons.py).
        for bucket, density in ANDROID_DENSITIES.items():
            render(
                logo_svg,
                ANDROID_RES / f"drawable-{bucket}/launch_wordmark.png",
                round(LAUNCH_WORDMARK_DP * density),
                work,
            )

        write_notification_icon(traced, work)

        if PREVIEW.parts:
            PREVIEW.mkdir(parents=True, exist_ok=True)
            opaque(render(icon_dark, PREVIEW / "loop-app-icon-crown-1024.png", 1024, work))


def write_notification_icon(traced: dict[str, str], work: Path) -> None:
    """Android status-bar icon: the crown alone, white, as an alpha mask."""
    crown_only = svg_doc((480, 310), f'<path fill="#FFFFFF" d="{traced["crown"]}"/>', "crown")
    x0, y0, x1, y1, _ = measure(crown_only, 480, 310, work)
    scale = 22.0 / max(x1 - x0, y1 - y0)
    tx = 12 - (x0 + x1) / 2 * scale
    ty = 12 - (y0 + y1) / 2 * scale
    path = transform_path(traced["crown"], scale, tx, ty, digits=3)
    xml = f"""<?xml version="1.0" encoding="utf-8"?>
<!-- The status-bar icon Android draws for a LOOP notification (decision 0205).

     Android 5+ renders this as a single-colour alpha mask: every opaque pixel
     becomes white and the tint from `default_notification_color` is applied
     around it. The launcher plate and the LOOP lettering stay out of it — a
     filled square here is exactly how an app ends up with a white blob in the
     status bar. This is the crown of the LOOP logo as one white silhouette,
     traced by tool/brand/make_crown_icons.py. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:fillType="evenOdd"
        android:pathData="{path}" />
</vector>
"""
    (ANDROID_RES / "drawable/ic_loop_notification.xml").write_text(xml)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    main(Path(sys.argv[1]).resolve())
