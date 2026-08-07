#!/usr/bin/env python3
"""Build the upload-ready Google Play asset set from the reviewed ASO artwork.

Reads   playstore-new-ASO/{US,TUR}/NEW/*.png      (never modified)
Writes  playstore-new-ASO/FINAL/{en-US,tr-TR}/    (regenerated every run)

Three stages, in this order and for a reason:

  1. repair   pixel-level content fixes at the artwork's native resolution, so a
              patched region carries exactly the same sharpness as its
              surroundings once the whole frame is resampled in stage 2.
  2. canvas   Lanczos resample to the 1080x1920 Play recommends, with a light
              unsharp pass calibrated to give back what the resample costs.
  3. encode   flatten alpha onto the brand canvas, force 8-bit sRGB, drop every
              ancillary chunk, then lossless-optimise.

Every fix below traces to a finding in FINAL_PLAY_STORE_REVIEW.html. Coordinates
are in native source pixels and were measured, not guessed; the self-check at the
end re-measures the result and fails loudly if a fix did not land.

Usage:  python3 tool/playstore_asset_pipeline.py [--check-only]
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "playstore-new-ASO"
OUT = SRC / "FINAL"
LOCALE = {"US": "en-US", "TUR": "tr-TR"}

CANVAS = (6, 0, 18)          # #060012 — the artwork's own black, used for flatten
PHONE_W, PHONE_H = 1080, 1920
FEATURE = (1024, 500)
ICON = (512, 512)

FONTDIR = Path(os.environ.get(
    "FONTDIR", Path.home() / ".cache/formai-play-tools/prefix/usr/share/fonts/opentype/inter"))


# ─────────────────────────── raster helpers ────────────────────────────
def load(p: Path) -> np.ndarray:
    return np.asarray(Image.open(p).convert("RGB")).astype(np.float64)


def save(a: np.ndarray, p: Path) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(np.round(a), 0, 255).astype("uint8")).save(p)


def inpaint(a, box, pad=5, mode="vh"):
    """Heal `box` by blending its clean margins.

    Every background this touches is a smooth gradient, so a bilinear blend
    between the margins reconstructs it below the visible threshold.

    `mode="v"` uses only the top/bottom margins. Use it whenever the left or
    right margin would fall on neighbouring glyphs — a horizontal blend then
    drags those glyphs across the box as streaks.
    """
    x0, y0, x1, y1 = box
    h, w = y1 - y0, x1 - x0
    ty = ((np.arange(h) + 1) / (h + 1))[:, None, None]
    top = a[y0 - pad:y0, x0:x1].mean(axis=0)
    bot = a[y1:y1 + pad, x0:x1].mean(axis=0)
    vert = top * (1 - ty) + bot * ty
    if mode == "v":
        a[y0:y1, x0:x1] = vert
        return a
    tx = ((np.arange(w) + 1) / (w + 1))[None, :, None]
    lef = a[y0:y1, x0 - pad:x0].mean(axis=1)
    rig = a[y0:y1, x1:x1 + pad].mean(axis=1)
    a[y0:y1, x0:x1] = 0.5 * vert + 0.5 * (lef[:, None, :] * (1 - tx) + rig[:, None, :] * tx)
    return a


def extrapolate_up(a, box, fit=30):
    """Rebuild `box` from the clean band *below* it, per column.

    For a region whose top, left and right neighbours are all occupied by other
    text, a least-squares fit on the rows underneath is the only margin that can
    be trusted. Same technique the icon's white band needs.
    """
    x0, y0, x1, y1 = box
    ys = np.arange(y1, y1 + fit)
    A = np.vstack([ys, np.ones_like(ys)]).T
    ty = np.arange(y0, y1)
    for c in range(3):
        coef, *_ = np.linalg.lstsq(A, a[y1:y1 + fit, x0:x1, c], rcond=None)
        a[y0:y1, x0:x1, c] = np.outer(ty, coef[0]) + coef[1]
    return a


def move_text(a, box, dx=0, dy=0, lo=45, hi=120, pad=5):
    """Lift bright glyphs out of `box`, heal the hole, restamp at the offset."""
    x0, y0, x1, y1 = box
    patch = a[y0:y1, x0:x1].copy()
    al = np.clip((patch.max(axis=2) - lo) / float(hi - lo), 0, 1)[..., None]
    inpaint(a, box, pad)
    ys, xs = slice(y0 + dy, y1 + dy), slice(x0 + dx, x1 + dx)
    a[ys, xs] = a[ys, xs] * (1 - al) + patch * al
    return a


def stamp(a, src_box, dst_xy):
    x0, y0, x1, y1 = src_box
    dx, dy = dst_xy
    a[dy:dy + (y1 - y0), dx:dx + (x1 - x0)] = a[y0:y1, x0:x1]
    return a


def render_fit(a, text, font, target, colour, angle=0.0, ss=8, boost=0.0):
    """Rasterise `text`, rotate `angle`° CCW, scale its tight bbox onto `target`.

    Fitting to a measured target box is what keeps a replacement glyph run on
    the same baseline and advance width as the run it replaces.
    """
    tx0, ty0, tx1, ty1 = target
    tw, th = tx1 - tx0, ty1 - ty0
    px = int(max(tw, th) * ss * 3)
    lay = Image.new("L", (px, px), 0)
    ImageDraw.Draw(lay).text((px // 2, px // 2), text,
                             font=ImageFont.truetype(str(font), int(th * ss * 1.6)),
                             fill=255, anchor="mm")
    if angle:
        lay = lay.rotate(angle, resample=Image.BICUBIC, expand=True)
    m = np.asarray(lay)
    ys, xs = np.where(m > 6)
    m = m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    g = np.asarray(Image.fromarray(m).resize((tw, th), Image.LANCZOS)) / 255.0
    if boost:
        g = np.clip(g * (1 + boost), 0, 1)
    sub = a[ty0:ty1, tx0:tx1]
    a[ty0:ty1, tx0:tx1] = sub * (1 - g[..., None]) + np.array(colour, float) * g[..., None]
    return a


def aspect(text, font, size=200):
    im = Image.new("L", (size * (len(text) + 2), size * 3), 0)
    ImageDraw.Draw(im).text((size, size), text,
                            font=ImageFont.truetype(str(font), size), fill=255, anchor="lt")
    m = np.asarray(im)
    ys, xs = np.where(m > 6)
    return (xs.max() - xs.min() + 1) / (ys.max() - ys.min() + 1)


def bbox(a, box, thr=100):
    x0, y0, x1, y1 = box
    m = a[y0:y1, x0:x1].max(axis=2) > thr
    ys, xs = np.where(m)
    if len(xs) == 0:
        return None
    return (int(xs.min() + x0), int(ys.min() + y0), int(xs.max() + x0 + 1), int(ys.max() + y0 + 1))


# ───────────────────────────── stage 1 · repair ─────────────────────────────
def fix_icon(a):
    """The exported icon carries a 12-row pure-white band across its bottom.

    Rows 500-511 are a flat #FFFFFF export artefact; the F mark ends far above
    them, so the fix is to continue the background gradient over the band rather
    than to touch any artwork.
    """
    BAD, H, F0, F1 = 500, 512, 476, 500
    ys = np.arange(F0, F1)
    A = np.vstack([ys, np.ones_like(ys)]).T
    for c in range(3):
        coef, *_ = np.linalg.lstsq(A, a[F0:F1, :, c], rcond=None)
        a[BAD:H, :, c] = np.outer(np.arange(BAD, H), coef[0]) + coef[1]
    a = np.clip(a, 0, 255)
    for c in range(3):                                   # soften the seam
        blk = a[BAD - 3:BAD + 4, :, c]
        a[BAD - 3:BAD + 4, :, c] = np.apply_along_axis(
            lambda v: np.convolve(v, [.25, .5, .25], "same"), 0, blk)
    return a


def fix_us_002(a):
    """Roll the in-app date's stale "2025" forward to "2026".

    A past year reads as a stale screenshot. Only the year is replaced, so the
    comma and "May 17" keep their original pixels; the four digits carry the
    same advance width, so nothing re-flows. The heal has to come from the band
    *below* — "Today" sits directly above and "17," directly to the left.
    """
    extrapolate_up(a, (601, 243, 645, 261), fit=30)
    return render_fit(a, "2026", FONTDIR / "Inter-Regular.otf",
                      (605, 245, 635, 259), (231, 231, 233), boost=0.10)


def fix_us_004(a):
    """Three defects on the 30-day plan frame.

    The reward card overlaps the Day 21 row, which is why both countdowns were
    stacked beside Day 30. There is no legitimate place to align "9 days left",
    so it goes; Day 30 keeps the count that belongs to it.
    """
    inpaint(a, (730, 1029, 848, 1056), pad=5)                       # orphan "9 days left"
    move_text(a, (730, 1056, 848, 1083), dy=-27, lo=45, hi=115)     # align to Day 30
    stamp(a, (295, 983, 324, 1013), (265, 983))                     # 7th dot -> outline
    return a


def fix_us_005(a):
    """"naximum." -> "maximum." — a plain misspelling in the Small Squads column.

    The heal starts at y=506: the "p" descenders of the line above reach y=500,
    and sampling them as a top margin smears them down as vertical streaks.
    """
    src_w, cx = 70, 102                                             # measured tight run
    w = int(round(src_w * aspect("maximum.", FONTDIR / "Inter-Regular.otf")
                        / aspect("naximum.", FONTDIR / "Inter-Regular.otf")))
    x0 = int(round(cx - w / 2))
    inpaint(a, (62, 506, 143, 526), pad=4)
    return render_fit(a, "maximum.", FONTDIR / "Inter-Regular.otf",
                      (x0, 509, x0 + w, 522), (222, 229, 244), boost=0.10)


def fix_us_008(a):
    """"Two weeks of data" contradicts a chart spanning May 1 - May 29 with the
    30d range active.

    Only the first word is wrong, so the tail keeps its original pixels: the
    whole line is healed, the tail is stamped back one word-width to the right
    as an opaque block (an alpha lift would carry card background with it and
    leave a visible band), and only "Four" is re-rendered.
    """
    f = FONTDIR / "Inter-Regular.otf"
    old_w = 34                                                      # "Two"  x378..411
    new_w = int(round(old_w * aspect("Four", f) / aspect("Two", f)))
    d = new_w - old_w
    tail = a[1248:1278, 414:664].copy()                             # "weeks of data. …"
    inpaint(a, (374, 1248, 664, 1277), pad=5)
    a[1248:1278, 414 + d:664 + d] = tail
    return render_fit(a, "Four", f, (378, 1254, 378 + new_w, 1270),
                      (231, 230, 231), boost=0.10)


def fix_tur_004(a):
    """The plan pill rendered "30" as a beta-like glyph; the streak shows seven
    filled dots against a stated six-day streak."""
    inpaint(a, (755, 308, 779, 331), pad=4)
    render_fit(a, "30", FONTDIR / "Inter-Medium.otf", (758, 314, 776, 328),
               (190, 132, 252), angle=5.93, boost=0.18)             # phone tilt is -5.93°
    stamp(a, (305, 916, 333, 944), (277, 916))
    return a


def fix_tur_006(a):
    """The Form-detection frame carries the Squad frame's three feature columns
    (KÜÇÜK TAKIMLAR / SIRALAMA DEĞİL, KATILIM / VARSAYILAN GİZLİ) — wrong content
    pasted into the wrong asset. The English twin has no such row, so removing it
    both repairs the frame and matches the locales."""
    return inpaint(a, (258, 410, 866, 572), pad=8)


REPAIRS = {
    ("US", "002.png"): fix_us_002,
    ("US", "004.png"): fix_us_004,
    ("US", "005.png"): fix_us_005,
    ("US", "008.png"): fix_us_008,
    ("TUR", "004.png"): fix_tur_004,
    ("TUR", "006.png"): fix_tur_006,
    ("US", "app-logo.png"): fix_icon,
    ("TUR", "app-logo.png"): fix_icon,
}

# 009 is a tablet frame depicting a large-screen layout the app does not render;
# it is excluded from the upload set rather than shipped. See the production report.
EXCLUDE = ("009", "backup")

# Carousel slot per source frame. The two locales were authored with different
# frames in slots 7 and 8 (English shipped Body Metrics, Turkish shipped
# Challenges), so the same slot advertised a different feature depending on the
# storefront. Remapping puts the seven shared features in identical slots and
# leaves the locale-specific extra last. Both extras are real shipped features.
SLOT = {
    "US":  {"001": 1, "002": 2, "003": 3, "004": 4, "005": 5, "006": 6, "007": 7, "008": 8},
    "TUR": {"001": 1, "002": 2, "003": 3, "004": 4, "005": 5, "006": 6, "008": 7, "007": 8},
}


# ───────────────────────────── stage 2 · canvas ─────────────────────────────
def to_canvas(im: Image.Image, target) -> Image.Image:
    """Cover-fit to `target` and centre-crop, so the true aspect is preserved
    and the correction is sub-pixel rather than an anisotropic stretch."""
    tw, th = target
    w, h = im.size
    if (w, h) == (tw, th):
        return im
    s = max(tw / w, th / h)
    im = im.resize((max(tw, int(round(w * s))), max(th, int(round(h * s)))), Image.LANCZOS)
    w, h = im.size
    return im.crop(((w - tw) // 2, (h - th) // 2, (w - tw) // 2 + tw, (h - th) // 2 + th))


def unsharp(im: Image.Image, amount=0.42, radius=1.1) -> Image.Image:
    from PIL import ImageFilter
    return im.filter(ImageFilter.UnsharpMask(radius=radius, percent=int(amount * 100), threshold=2))


# ───────────────────────────── stage 3 · encode ─────────────────────────────
def encode(im: Image.Image, dest: Path) -> None:
    """24-bit sRGB PNG, no alpha, no ancillary chunks, losslessly optimised."""
    if im.mode in ("RGBA", "LA", "P"):
        bg = Image.new("RGB", im.size, CANVAS)
        im = im.convert("RGBA")
        bg.paste(im, mask=im.split()[-1])
        im = bg
    im = im.convert("RGB")
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest, "PNG", optimize=False)

    run = lambda c: subprocess.run(c, capture_output=True, text=True)
    run(["exiftool", "-all=", "-overwrite_original", "-q", "-q", str(dest)])
    try:
        import oxipng
        oxipng.optimize(str(dest), level=6, strip=oxipng.StripChunks.safe())
    except Exception:
        run(["optipng", "-quiet", "-o5", "-strip", "all", str(dest)])
    run(["exiftool", "-all=", "-overwrite_original", "-q", "-q", str(dest)])


# ─────────────────────────────── driver ────────────────────────────────
def build() -> list[tuple[str, str, str]]:
    if OUT.exists():
        shutil.rmtree(OUT)
    rows = []
    for loc in ("US", "TUR"):
        for p in sorted((SRC / loc / "NEW").glob("*.png")):
            if any(k in p.name for k in EXCLUDE):
                rows.append((f"{loc}/{p.name}", "-", "EXCLUDED"))
                continue
            a = load(p)
            before = f"{Image.open(p).size[0]}x{Image.open(p).size[1]}"
            fn = REPAIRS.get((loc, p.name))
            if fn:
                a = fn(a)
            im = Image.fromarray(np.clip(np.round(a), 0, 255).astype("uint8"))

            if p.name == "app-logo.png":
                im, name = to_canvas(im, ICON), "app-icon-512.png"
            elif p.name == "feature-graphic.png":
                im, name = to_canvas(im, FEATURE), "feature-graphic-1024x500.png"
            else:
                im = unsharp(to_canvas(im, (PHONE_W, PHONE_H)))
                name = f"phone-{SLOT[loc][p.stem]:02d}-{LOCALE[loc]}.png"

            dest = OUT / LOCALE[loc] / name
            encode(im, dest)
            rows.append((f"{loc}/{p.name}", before,
                         f"{LOCALE[loc]}/{name}  {im.size[0]}x{im.size[1]}"
                         f"{'  [repaired]' if fn else ''}"))
    return rows


def selfcheck() -> list[str]:
    """Re-measure the repaired frames; a fix that silently missed is a failure.

    Boxes are in FINAL (1080x1920) space — native coordinates scaled by 1080/941.
    """
    errs = []
    # (locale, frame, box, thr) — each region must be free of bright content
    for loc, name, box, thr in [
        ("US",  "phone-04", (849, 1218, 950, 1245), 120),   # vacated "18 days left" row
        ("US",  "phone-02", (740, 300, 780, 320), 130),     # nothing beyond the year box
        ("TUR", "phone-06", (310, 480, 980, 645), 110),     # leaked squad row gone
    ]:
        f = OUT / LOCALE[loc] / f"{name}-{LOCALE[loc]}.png"
        b = bbox(load(f), box, thr)
        if b is not None:
            errs.append(f"{f.name}: expected clear region {box}, found content at {b}")
    # positive checks — the replacement text must actually be present
    for loc, name, box, thr, label in [
        ("US", "phone-05", (60, 578, 170, 602), 150, "'maximum.'"),
        ("US", "phone-08", (430, 1438, 500, 1460), 150, "'Four'"),
        ("US", "phone-02", (694, 282, 728, 297), 140, "date year '2026'"),
        ("TUR", "phone-04", (865, 358, 895, 378), 120, "pill '30'"),
    ]:
        f = OUT / LOCALE[loc] / f"{name}-{LOCALE[loc]}.png"
        if bbox(load(f), box, thr) is None:
            errs.append(f"{f.name}: {label} missing from {box}")
    for f in sorted(OUT.rglob("*.png")):
        im = Image.open(f)
        if im.mode != "RGB":
            errs.append(f"{f.name}: mode {im.mode}, expected RGB")
    ic = load(OUT / "en-US/app-icon-512.png")
    if int((ic == 255).all(axis=2).sum()) > 0:
        errs.append("app-icon-512.png: pure-white pixels remain")
    return errs


if __name__ == "__main__":
    if not FONTDIR.exists():
        sys.exit(f"font dir not found: {FONTDIR}\n"
                 "see tool/README_play_assets.md for the sudo-free toolchain setup")
    if "--check-only" not in sys.argv:
        print("building Play asset set…\n")
        for a, b, c in build():
            print(f"  {a:26} {b:>10}  ->  {c}")
    print("\nself-check:")
    errs = selfcheck()
    for e in errs:
        print(f"  FAIL  {e}")
    print("  all repairs verified" if not errs else f"\n{len(errs)} failure(s)")
    sys.exit(1 if errs else 0)
