#!/usr/bin/env python3
"""Phase 2-A.2 · Generate Low-Quality Image Placeholders for `photos/meals/`.

LQIPs are 64x64 WebP thumbnails (quality 50) shipped inside the APK so the
recipe-image grid never paints a grey hole on first frame. The full image
streams in over the top from Supabase Storage via CachedNetworkImage.

Modes:
    --sample           Generate only a curated sample set (default ~8 files).
                       Writes to assets/lqip/meals/ but limits the file list.
                       Use during Phase 2-A.2 (LQIP preview / approval).
    --all              Generate the full corpus (~298 files). Use only after
                       sample previews are approved.
    --sample-list FILE Text file with one filename per line to sample. Allows
                       targeted previews of specific meals (variety check).

Defaults:
    Source : photos/meals/
    Dest   : assets/lqip/meals/
    Size   : 64 x 64 (longest edge; aspect ratio preserved)
    Format : WEBP, quality=50, method=6 (max compression effort)

Output is a deterministic report printed to stdout:
    Generated N LQIPs, total X KB (min A bytes / max B bytes / avg C bytes)
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import Iterable

try:
    from PIL import Image
except ImportError:
    sys.stderr.write("ERROR: Pillow not installed. Run: pip install Pillow\n")
    sys.exit(2)


REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SRC = REPO_ROOT / "photos" / "meals"
DEFAULT_DST = REPO_ROOT / "assets" / "lqip" / "meals"
TARGET_PX = 64
WEBP_QUALITY = 50
WEBP_METHOD = 6


# Curated sample set for Phase 2-A.2 preview. Chosen for visual variety:
# - high-saturation reds (soups, tomato-based)
# - greens (salads)
# - browns / golden (baked, fried)
# - dairy / pale (yogurts, puddings)
# - composed plates (meat + veg layouts)
SAMPLE_SET: tuple[str, ...] = (
    "acili_domates_corbasi.webp",       # red soup — saturation stress test
    "akdeniz_kinoa_salatasi.webp",      # green salad — fine detail
    "bal_cevizli_suzme_yogurt.webp",    # pale dairy — low contrast
    "firin_tarcinli_elma.webp",         # browns — texture
    "izgara_somon_tatli_patates.webp",  # composed plate — orange + brown
    "izgara_karides_roka_salatasi.webp",  # mixed greens + pink — complex
    "bal_cevizli_lor_peyniri.webp",     # dessert — soft creamy tones
    "yumurta_peynirli_sandvic.webp",    # yellow / white contrast
)


def _resolve_inputs(src: Path, sample_files: Iterable[str] | None) -> list[Path]:
    if sample_files is None:
        return sorted(p for p in src.iterdir() if p.suffix.lower() == ".webp")
    selected: list[Path] = []
    missing: list[str] = []
    for name in sample_files:
        candidate = src / name.strip()
        if not candidate.exists():
            missing.append(name)
            continue
        selected.append(candidate)
    if missing:
        sys.stderr.write(
            f"WARN: {len(missing)} sample file(s) not found in {src}: {missing}\n"
        )
    return selected


def generate(
    src: Path = DEFAULT_SRC,
    dst: Path = DEFAULT_DST,
    sample: bool = False,
    sample_list: Path | None = None,
) -> tuple[int, int, int, int]:
    """Generate LQIPs. Returns (count, total_bytes, min_bytes, max_bytes)."""
    if not src.is_dir():
        raise FileNotFoundError(f"Source dir not found: {src}")
    dst.mkdir(parents=True, exist_ok=True)

    sample_files: tuple[str, ...] | list[str] | None
    if sample_list is not None:
        sample_files = [
            ln.strip()
            for ln in sample_list.read_text(encoding="utf-8").splitlines()
            if ln.strip() and not ln.strip().startswith("#")
        ]
    elif sample:
        sample_files = SAMPLE_SET
    else:
        sample_files = None

    inputs = _resolve_inputs(src, sample_files)
    if not inputs:
        sys.stderr.write("No input files matched. Exiting.\n")
        return (0, 0, 0, 0)

    sizes: list[int] = []
    for p in inputs:
        with Image.open(p) as img:
            img = img.convert("RGB")
            img.thumbnail((TARGET_PX, TARGET_PX), Image.Resampling.LANCZOS)
            out = dst / p.name
            img.save(out, "WEBP", quality=WEBP_QUALITY, method=WEBP_METHOD)
        sizes.append(out.stat().st_size)

    total = sum(sizes)
    print(
        f"Generated {len(sizes)} LQIPs at {dst} | "
        f"total {total / 1024:.1f} KB "
        f"(min {min(sizes)} B / max {max(sizes)} B / avg {total // len(sizes)} B)"
    )
    return (len(sizes), total, min(sizes), max(sizes))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--src", type=Path, default=DEFAULT_SRC)
    parser.add_argument("--dst", type=Path, default=DEFAULT_DST)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--sample",
        action="store_true",
        help="Generate only the curated sample set (default 8 meals).",
    )
    mode.add_argument(
        "--all",
        action="store_true",
        help="Generate the full corpus (~298 files). Use after sample approval.",
    )
    mode.add_argument(
        "--sample-list",
        type=Path,
        help="Text file listing filenames (one per line) to sample.",
    )
    args = parser.parse_args()

    if not (args.sample or args.all or args.sample_list):
        sys.stderr.write(
            "ERROR: pass exactly one of --sample / --all / --sample-list FILE.\n"
            "       Phase 2-A.2 expects --sample. Bulk run is Phase 2-A.2-followup.\n"
        )
        return 2

    generate(
        src=args.src,
        dst=args.dst,
        sample=args.sample,
        sample_list=args.sample_list,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
