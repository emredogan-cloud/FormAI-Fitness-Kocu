# Play listing asset toolchain

Two scripts turn the reviewed ASO artwork into an upload-ready Play asset set and
then prove the result meets Google's published requirements.

```
playstore-new-ASO/{US,TUR}/NEW/     source artwork — never modified
        │
        ├─ tool/playstore_asset_pipeline.py    repair → canvas → encode
        ▼
playstore-new-ASO/FINAL/{en-US,tr-TR}/         upload this
        │
        └─ tool/validate_play_assets.py        131 assertions, exit 1 on any failure
```

`playstore-new-ASO/` is gitignored — the artwork is ~30 MB of PNG and this is a
public repository. The scripts are versioned; the binaries are not. Re-run the
pipeline to regenerate `FINAL/` on any machine.

## Setup (no sudo required)

The build host had ImageMagick and ffmpeg but not the PNG toolchain, and no
passwordless sudo. Debian packages extract fine into a private prefix, and
`pip` needs a venv because of PEP 668:

```bash
T=~/.cache/formai-play-tools
mkdir -p $T/pkg && cd $T/pkg
for p in pngquant optipng pngcrush libimagequant0 \
         libimage-exiftool-perl zopfli fonts-inter; do
  apt-get download $p            # no root needed — just fetches the .deb
done
for d in *.deb; do dpkg-deb -x "$d" $T/prefix; done

python3 -m venv $T/venv
$T/venv/bin/pip install pyoxipng numpy pillow

cat > $T/env.sh <<'EOF'
T=~/.cache/formai-play-tools
export PATH="$T/prefix/usr/bin:$PATH"
export LD_LIBRARY_PATH="$T/prefix/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
export PERL5LIB="$T/prefix/usr/share/perl5:$PERL5LIB"
export FONTDIR="$T/prefix/usr/share/fonts/opentype/inter"
export PY="$T/venv/bin/python"
EOF
```

## Run

```bash
. ~/.cache/formai-play-tools/env.sh
$PY tool/playstore_asset_pipeline.py     # rebuilds FINAL/, then self-checks
$PY tool/validate_play_assets.py         # independent conformance pass
$PY tool/validate_play_assets.py --json  # machine-readable, for CI
```

Both exit non-zero on failure, so they chain with `&&`.

## What each tool is for

| tool | why this one |
| --- | --- |
| **oxipng** (via `pyoxipng`) | primary lossless recompressor; multi-threaded, strips safely |
| **optipng** | fallback when the Python binding is unavailable |
| **exiftool** | removes EXIF/XMP that Pillow leaves behind; run before *and* after optimisation because optimisers can reintroduce chunks |
| **pngquant / pngcrush / zopflipng** | available for size emergencies. **Not used in the pipeline** — pngquant is lossy (palette quantisation) and these screenshots are gradient-heavy dark UI where banding would show. The set fits Play's 8 MB/file limit with ~4x headroom, so lossless is the right trade. |
| **Inter** (`fonts-inter`) | closest metric match to the UI type in the artwork; used only for the handful of replaced glyph runs |
| **ImageMagick** | inspection crops and contact sheets during review |

## Why the stage order matters

Repairs happen at the artwork's **native** resolution, before the resample to
1080×1920. A patch applied after upscaling would be pixel-sharp against
surroundings that the resample had softened, and the difference reads as an
obvious paste. Repairing first means the patch and its surroundings go through
the same Lanczos pass and land at the same sharpness.

## Adding a repair

Write a `fix_*(a)` that takes and returns a float64 `H×W×3` array in native
coordinates, register it in `REPAIRS`, and add an assertion to `selfcheck()` so a
silently-missed fix fails the build. The healing helpers:

- `inpaint(box, mode="vh")` — bilinear blend from the four margins. Use
  `mode="v"` when the left/right margins fall on neighbouring glyphs, or the
  horizontal blend drags them across the box as streaks.
- `extrapolate_up(box)` — least-squares fit on the clean band *below*, for
  regions boxed in on three sides by other text.
- `render_fit(text, font, target, colour, angle=)` — rasterise, rotate to match
  the mockup's tilt, and scale onto a measured target box so the replacement
  keeps the original baseline and advance width.

Measure coordinates; do not guess them. Every constant in the pipeline came from
a luminance-threshold bounding-box pass over the source, and the phone mockups
are tilted (TUR/004 is −5.93°), so rendered glyphs need the matching rotation.
