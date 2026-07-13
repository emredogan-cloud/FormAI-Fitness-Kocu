#!/usr/bin/env python3
"""Format Google Play Store graphical assets to upload requirements.

Outputs:
  photos/APP_ICON_512.png                              512x512 PNG
  asosystem/play_store_ready/feature_graphic_1024x500.png   1024x500 PNG
  asosystem/play_store_ready/<screenshot>.png          1080x1920 PNG each

Strategy:
  - Resize/crop via Lanczos + center-cover crop only when source size != target.
  - Always save as PNG, stripping metadata via optimize=True.
  - If a lossless save would exceed 1 MB, progressively quantize the palette
    (256 → 192 → 128 → 96 → 64 colors with Floyd-Steinberg dither) until the
    file fits. This mirrors what pngquant does and preserves gradients far
    better than a flat color reduction.
"""
from __future__ import annotations

import io
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent

SRC_ICON = REPO / "photos" / "APP_ICON.png"
DST_ICON = REPO / "photos" / "APP_ICON_512.png"

SRC_BANNER = REPO / "asosystem" / "exports" / "verify" / "feature-graphic.png"
SRC_SHOTS_DIR = REPO / "asosystem" / "exports" / "verify" / "playstore"
OUT_DIR = REPO / "asosystem" / "play_store_ready"

ICON_SIZE = (512, 512)
BANNER_SIZE = (1024, 500)
SHOT_SIZE = (1080, 1920)
MAX_BYTES = 1024 * 1024


def fit_and_crop(im: Image.Image, target_w: int, target_h: int) -> Image.Image:
    src_w, src_h = im.size
    if (src_w, src_h) == (target_w, target_h):
        return im
    scale = max(target_w / src_w, target_h / src_h)
    new_w, new_h = round(src_w * scale), round(src_h * scale)
    im = im.resize((new_w, new_h), Image.LANCZOS)
    left = (new_w - target_w) // 2
    top = (new_h - target_h) // 2
    return im.crop((left, top, left + target_w, top + target_h))


def save_png_under_cap(im: Image.Image, dst: Path) -> tuple[str, int]:
    if im.mode not in ("RGB", "RGBA"):
        im = im.convert("RGB")

    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    if buf.tell() <= MAX_BYTES:
        dst.write_bytes(buf.getvalue())
        return ("lossless RGB", buf.tell())

    rgb = im.convert("RGB") if im.mode != "RGB" else im
    for colors in (256, 192, 128, 96, 64):
        quant = rgb.quantize(
            colors=colors,
            method=Image.MEDIANCUT,
            dither=Image.FLOYDSTEINBERG,
        )
        buf = io.BytesIO()
        quant.save(buf, "PNG", optimize=True)
        if buf.tell() <= MAX_BYTES:
            dst.write_bytes(buf.getvalue())
            return (f"quantized {colors}-color", buf.tell())

    dst.write_bytes(buf.getvalue())
    return ("quantized 64-color (still > 1 MB)", buf.tell())


def process_icon() -> None:
    im = Image.open(SRC_ICON)
    src_size = im.size
    if im.size != ICON_SIZE:
        im = im.resize(ICON_SIZE, Image.LANCZOS)
    if im.mode != "RGB":
        im = im.convert("RGB")
    im.save(DST_ICON, "PNG", optimize=True)
    out_kb = DST_ICON.stat().st_size / 1024
    print(f"[icon] {DST_ICON.relative_to(REPO)}: {src_size} -> {ICON_SIZE}, {out_kb:.1f} KB")


def process_banner() -> None:
    im = Image.open(SRC_BANNER)
    src_size = im.size
    im = fit_and_crop(im, *BANNER_SIZE)
    dst = OUT_DIR / "feature_graphic_1024x500.png"
    mode, size = save_png_under_cap(im, dst)
    print(f"[banner] {dst.relative_to(REPO)}: {src_size} -> {BANNER_SIZE}, {size/1024:.1f} KB ({mode})")


def process_screenshots() -> None:
    shots = sorted(SRC_SHOTS_DIR.glob("*.png"))
    if not shots:
        print(f"[screenshots] no PNGs found in {SRC_SHOTS_DIR.relative_to(REPO)}")
        return
    for src in shots:
        im = Image.open(src)
        src_size = im.size
        im = fit_and_crop(im, *SHOT_SIZE)
        dst = OUT_DIR / src.name
        mode, size = save_png_under_cap(im, dst)
        print(f"[screenshot] {dst.relative_to(REPO)}: {src_size} -> {SHOT_SIZE}, {size/1024:.1f} KB ({mode})")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    process_icon()
    process_banner()
    process_screenshots()


if __name__ == "__main__":
    main()
