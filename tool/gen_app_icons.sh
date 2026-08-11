#!/usr/bin/env bash
# Regenerates the three launcher-icon source assets from the canonical
# FormAI "F" master, then runs flutter_launcher_icons.
#
# WHY THIS SCRIPT EXISTS
#
# The app shipped for weeks with a launcher icon that was not the store
# icon. The store icon was replaced during the ASO refresh; nobody
# re-pointed the native pipeline at the new artwork, so `tool/app_icon.png`
# still held the old photographic "AI FITNESS COACH" marketing scene while
# Google Play showed the purple F. The pipeline was healthy the whole time
# — it was faithfully rendering the wrong input. This script makes the
# derivation reproducible so the two can't drift again.
#
# WHY THE ADAPTIVE LAYERS ARE SPLIT THE WAY THEY ARE
#
# The previous config put the full-bleed artwork in the adaptive
# BACKGROUND and left the foreground transparent. That is correct for
# photographic art (cropping a photo is harmless) and wrong for a
# logomark. Measured on the master, the F's bounding box sits 42.2 dp
# from centre on the 108 dp adaptive canvas; a circular launcher mask
# clips at 36 dp, so the top-left of the F — where the stem meets the
# top bar — was going to be cut off on Pixel and every other round-mask
# launcher. So: background carries the colour field, foreground carries
# the glyph, sized to land inside the 72 dp safe zone with margin.
#
# Usage:  bash tool/gen_app_icons.sh [path-to-512-master]
set -euo pipefail

MASTER="${1:-playstore-new-ASO/FINAL/en-US/app-icon-512.png}"
OUT=tool
CANVAS=1024
# Fraction of the adaptive canvas the glyph's bounding box may span.
# 45.4% puts its corners at radius 32 dp — inside the 36 dp circular
# mask with 4 dp to spare. See the header note.
GLYPH_FRACTION=0.454

command -v convert >/dev/null || { echo "ImageMagick 'convert' not found"; exit 1; }
[ -f "$MASTER" ] || { echo "master not found: $MASTER"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 1 · Clean the master. The Play Store 512 carries a 1 px light-grey
#     column down its RIGHT edge (mean 38 vs 8.8 inner) — the same class
#     of artifact as the bottom "white stripe" fixed in b216fb9, which
#     was fixed on that edge only. Shaving 2 px from every side removes
#     it without touching the composition.
convert "$MASTER" -shave 2x2 -filter Lanczos -resize ${CANVAS}x${CANVAS}! "$WORK/master.png"

# 2 · Legacy launcher icon + iOS. minSdk is 24, so API 24–25 devices
#     genuinely render this rather than the adaptive pair.
cp "$WORK/master.png" "$OUT/app_icon.png"

# 3 · Adaptive background — the master's own colour field, sampled.
#     A radial gradient rather than a blur of the master: blurring smears
#     the bright glyph into a washed-out purple blob and loses the deep
#     near-black the icon is built on.
convert -size ${CANVAS}x${CANVAS} radial-gradient:'#10012a'-'#060013' "$OUT/app_icon_bg.png"

# 4 · Adaptive foreground — the F on transparency, measured and centred.
#     Alpha comes from a luminance mask: the glyph reads 0.29–0.39 and
#     the field 0.01–0.04, so the two separate cleanly.
convert "$WORK/master.png" -colorspace Gray -level 6%,28% \
        -black-threshold 4% -white-threshold 96% -blur 0x1.2 "$WORK/mask.png"
convert "$WORK/master.png" "$WORK/mask.png" -alpha off \
        -compose CopyOpacity -composite "$WORK/glyph.png"

# The glyph's true extent, ignoring stray edge speckle. A plain -trim
# can't do this: where alpha is 0 the RGB channel still holds the
# master's gradient, so -trim compares unequal pixels and gives up.
read -r GX GY GW GH <<<"$(python3 - "$WORK/glyph.png" <<'PY'
import sys
from PIL import Image
a = Image.open(sys.argv[1]).convert("RGBA").split()[3]
W, H = a.size; px = a.load()
MIN_RUN, T = 8, 96          # a real glyph row/col has >= MIN_RUN solid px
rows = [y for y in range(H) if sum(1 for x in range(W) if px[x, y] > T) >= MIN_RUN]
cols = [x for x in range(W) if sum(1 for y in range(H) if px[x, y] > T) >= MIN_RUN]
print(cols[0], rows[0], cols[-1] - cols[0] + 1, rows[-1] - rows[0] + 1)
PY
)"
echo "glyph bbox: ${GW}x${GH}+${GX}+${GY}"

PAD=6
TARGET_H=$(python3 -c "print(round($CANVAS*$GLYPH_FRACTION*(($GH+2*$PAD)/$GH)))")
convert "$WORK/glyph.png" \
        -crop "$((GW+2*PAD))x$((GH+2*PAD))+$((GX-PAD))+$((GY-PAD))" +repage \
        -filter Lanczos -resize "x${TARGET_H}" \
        -background none -gravity center -extent ${CANVAS}x${CANVAS} "$OUT/app_icon_fg.png"

echo "wrote $OUT/app_icon.png  $OUT/app_icon_bg.png  $OUT/app_icon_fg.png"
echo "now run: dart run flutter_launcher_icons"
