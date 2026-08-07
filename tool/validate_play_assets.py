#!/usr/bin/env python3
"""Validate playstore-new-ASO/FINAL against Google Play's asset requirements.

Independent of the pipeline that produced the files: this re-opens every asset
and asserts the published rules, so it also catches a file edited or replaced by
hand after the build.

Rules enforced (Play Console "Add preview assets" + icon/feature-graphic specs):

  app icon          512x512, PNG, <=1 MB, square
  feature graphic   1024x500, PNG/JPEG, <=15 MB, no alpha
  phone screenshot  PNG/JPEG, no alpha, 320-3840 px per side, longest side
                    <= 2x shortest, <=8 MB, 2-8 per locale
  promotable        >=4 screenshots at >=1080 px on the short side, 9:16

Also checked: 8-bit sRGB, no ancillary metadata chunks, no stray files, locale
parity, and filename ordering.

Usage:  python3 tool/validate_play_assets.py [--json]
Exit 0 when every check passes, 1 otherwise.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
FINAL = REPO / "playstore-new-ASO" / "FINAL"
LOCALES = ("en-US", "tr-TR")

MB = 1024 * 1024
CHECKS: list[tuple[str, str, bool, str]] = []      # (scope, rule, ok, detail)


def check(scope: str, rule: str, ok: bool, detail: str = "") -> bool:
    CHECKS.append((scope, rule, bool(ok), detail))
    return bool(ok)


def has_alpha(im: Image.Image) -> bool:
    return im.mode in ("RGBA", "LA", "PA") or "transparency" in im.info


def ancillary_chunks(p: Path) -> list[str]:
    """Ancillary PNG chunks left in the file (lowercase first letter)."""
    out, data = [], p.read_bytes()
    i = 8
    while i + 8 <= len(data):
        ln = int.from_bytes(data[i:i + 4], "big")
        typ = data[i + 4:i + 8].decode("ascii", "replace")
        if typ not in ("IHDR", "IDAT", "IEND", "PLTE") and typ[0].islower():
            out.append(typ)
        if typ == "IEND":
            break
        i += 12 + ln
    return out


def validate_locale(loc: str) -> None:
    d = FINAL / loc
    if not check(loc, "locale directory exists", d.is_dir(), str(d)):
        return

    files = sorted(d.glob("*"))
    check(loc, "no stray non-PNG files", all(f.suffix == ".png" for f in files),
          ", ".join(f.name for f in files if f.suffix != ".png") or "clean")

    shots = sorted(d.glob("phone-*.png"))
    icons = sorted(d.glob("app-icon-*.png"))
    feats = sorted(d.glob("feature-graphic-*.png"))

    # ---- counts -------------------------------------------------------
    check(loc, "2-8 phone screenshots", 2 <= len(shots) <= 8, f"{len(shots)} present")
    check(loc, "exactly one app icon", len(icons) == 1, f"{len(icons)} present")
    check(loc, "exactly one feature graphic", len(feats) == 1, f"{len(feats)} present")
    check(loc, "screenshot slots are contiguous from 01",
          [f.name.split("-")[1] for f in shots] == [f"{i:02d}" for i in range(1, len(shots) + 1)],
          ", ".join(f.name.split("-")[1] for f in shots))

    promotable = 0
    for f in shots:
        im = Image.open(f)
        w, h = im.size
        n = f.name
        sz = f.stat().st_size
        check(n, "no alpha channel", not has_alpha(im), im.mode)
        check(n, "8-bit RGB", im.mode == "RGB" and im.getbands() == ("R", "G", "B"), im.mode)
        check(n, "each side 320-3840 px", 320 <= w <= 3840 and 320 <= h <= 3840, f"{w}x{h}")
        check(n, "longest side <= 2x shortest", max(w, h) <= 2 * min(w, h),
              f"ratio {max(w, h) / min(w, h):.3f}")
        check(n, "file <= 8 MB", sz <= 8 * MB, f"{sz / MB:.2f} MB")
        check(n, "no ancillary metadata chunks", not ancillary_chunks(f),
              ", ".join(ancillary_chunks(f)) or "clean")
        if min(w, h) >= 1080 and abs((w / h) - 9 / 16) < 0.004:
            promotable += 1
    check(loc, ">=4 screenshots at >=1080 px and 9:16 (promotion eligibility)",
          promotable >= 4, f"{promotable} of {len(shots)} qualify")

    for f in icons:
        im = Image.open(f)
        sz = f.stat().st_size
        check(f.name, "512x512", im.size == (512, 512), f"{im.size[0]}x{im.size[1]}")
        check(f.name, "file <= 1 MB", sz <= MB, f"{sz / MB:.3f} MB")
        check(f.name, "8-bit RGB", im.mode == "RGB", im.mode)
        check(f.name, "no ancillary metadata chunks", not ancillary_chunks(f),
              ", ".join(ancillary_chunks(f)) or "clean")
        px = im.convert("RGB").load()
        white = sum(1 for y in range(0, 512, 2) for x in range(0, 512, 2)
                    if px[x, y] == (255, 255, 255))
        check(f.name, "no pure-white export band", white == 0, f"{white} sampled white px")

    for f in feats:
        im = Image.open(f)
        sz = f.stat().st_size
        check(f.name, "1024x500", im.size == (1024, 500), f"{im.size[0]}x{im.size[1]}")
        check(f.name, "no alpha channel", not has_alpha(im), im.mode)
        check(f.name, "file <= 15 MB", sz <= 15 * MB, f"{sz / MB:.2f} MB")
        check(f.name, "no ancillary metadata chunks", not ancillary_chunks(f),
              ", ".join(ancillary_chunks(f)) or "clean")


def validate_parity() -> None:
    a = sorted(p.name.replace("en-US", "") for p in (FINAL / "en-US").glob("*.png"))
    b = sorted(p.name.replace("tr-TR", "") for p in (FINAL / "tr-TR").glob("*.png"))
    check("parity", "both locales carry the same asset slots", a == b,
          f"en-US {len(a)} / tr-TR {len(b)}")
    ia = (FINAL / "en-US/app-icon-512.png").read_bytes()
    ib = (FINAL / "tr-TR/app-icon-512.png").read_bytes()
    check("parity", "identical app icon in both locales (Play stores one globally)",
          ia == ib, "byte-identical" if ia == ib else "DIFFER")
    seen = {}
    for loc in LOCALES:
        for f in (FINAL / loc).glob("phone-*.png"):
            h = f.read_bytes()
            if h in seen and seen[h].parent == f.parent:
                check("parity", "no duplicate screenshots within a locale", False,
                      f"{f.name} == {seen[h].name}")
            seen[h] = f
    check("parity", "no duplicate screenshots within a locale", True, "all unique")


if __name__ == "__main__":
    if not FINAL.is_dir():
        sys.exit(f"{FINAL} not found — run tool/playstore_asset_pipeline.py first")
    for loc in LOCALES:
        validate_locale(loc)
    validate_parity()

    if "--json" in sys.argv:
        print(json.dumps([{"scope": s, "rule": r, "pass": o, "detail": d}
                          for s, r, o, d in CHECKS], indent=2))
    else:
        scope = None
        for s, r, ok, d in CHECKS:
            if s != scope:
                print(f"\n{s}")
                scope = s
            print(f"  [{'PASS' if ok else 'FAIL'}] {r:<62} {d}")
    failed = [c for c in CHECKS if not c[2]]
    print(f"\n{len(CHECKS) - len(failed)}/{len(CHECKS)} checks passed"
          + (f" — {len(failed)} FAILED" if failed else " — all green"))
    sys.exit(1 if failed else 0)
