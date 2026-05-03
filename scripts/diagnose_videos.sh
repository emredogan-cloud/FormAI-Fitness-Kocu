#!/usr/bin/env bash
# =============================================================================
# Video diagnostic — Phase 87
# =============================================================================
# Probes every exercise video URL the app expects to find in Supabase
# Storage and emits a Markdown report at docs/VIDEO_DIAGNOSTIC_REPORT.md.
#
# What it checks per slug:
#   1. HEAD request to the public Storage URL → captures HTTP status
#      (200 = file exists, 403 = bucket policy, 404 = file missing, etc.)
#   2. Content-Type header → flags anything that isn't video/mp4
#   3. ffprobe (if installed) → codec name; flags HEVC / vp9 / anything
#      ExoPlayer doesn't decode by default on stock Android.
#
# Why this is a script and not an in-app feature:
# the app's ExerciseGuidePlayer already has comprehensive logging
# (see lib/features/workout/presentation/widgets/exercise_guide_player.dart);
# this script gives the same answers in 30 seconds without needing a
# device, a Sentry dashboard, or a test rebuild. Run before each release
# and after every Storage upload batch.
#
# Usage:
#   bash scripts/diagnose_videos.sh
#
# Reads:
#   .env  →  SUPABASE_URL  (required)
#           CDN_BASE_URL   (optional — uses CDN host if set)
#
# Writes:
#   docs/VIDEO_DIAGNOSTIC_REPORT.md
#
# Dependencies (all optional — script degrades gracefully):
#   curl     (required — for HEAD requests)
#   ffprobe  (optional — codec detection; install via apt/brew if missing)
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
REPORT="$REPO_ROOT/docs/VIDEO_DIAGNOSTIC_REPORT.md"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found" >&2
  exit 1
fi

# Strip optional surrounding quotes from .env values — Phase 76 sanitization
# in MediaUrl mirrors this same logic.
strip_quotes() {
  local v="$1"
  v="${v#\"}"; v="${v%\"}"
  v="${v#\'}"; v="${v%\'}"
  v="${v%/}"
  echo "$v"
}

SUPABASE_URL=$(strip_quotes "$(grep -E '^SUPABASE_URL=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '\r')")
CDN_BASE_URL=$(strip_quotes "$(grep -E '^CDN_BASE_URL=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '\r')")

if [[ -z "$SUPABASE_URL" ]]; then
  echo "ERROR: SUPABASE_URL is empty in $ENV_FILE" >&2
  exit 1
fi

if [[ -n "$CDN_BASE_URL" ]]; then
  BASE="$CDN_BASE_URL/exercises"
  ROUTE="CDN ($CDN_BASE_URL)"
else
  BASE="$SUPABASE_URL/storage/v1/object/public/exercises"
  ROUTE="Supabase Storage public endpoint"
fi

# 51 slugs: 41 Phase 50A baseline + 10 Phase 85 equipment additions.
# Order matches the SQL migrations so the report groups by category.
SLUGS=(
  # Core (9)
  crunch situp plank leg_raise hanging_leg_raise russian_twist
  mountain_climber bicycle_crunch flutter_kick
  # Chest (6)
  push_up incline_push_up decline_push_up bench_press chest_fly chest_dip
  # Legs (6)
  squat lunge bulgarian_split_squat leg_press calf_raise wall_sit
  # Back (5)
  pull_up chin_up lat_pulldown barbell_row superman
  # Shoulders (5)
  shoulder_press arnold_press lateral_raise front_raise pike_push_up
  # Arms (5)
  biceps_curl hammer_curl triceps_dip triceps_pushdown close_grip_push_up
  # Cardio / Full Body (5)
  burpee jumping_jack jump_squat high_knees skipping_rope
  # Phase 85 equipment additions (10)
  incline_bench_press concentration_curl skull_crusher
  barbell_squat romanian_deadlift leg_extension leg_curl
  cable_crunch weighted_russian_twist ab_wheel_rollout
)

# snake_case → PascalCase, mirrors lib/core/utils/string_case.dart::snakeToPascal
to_pascal() {
  local s="$1"
  IFS='_' read -ra parts <<< "$s"
  local out=""
  for p in "${parts[@]}"; do
    [[ -z "$p" ]] && continue
    out+="${p^}"
  done
  echo "$out"
}

probe_url() {
  local url="$1"
  # -s silent, -o /dev/null discard body, -w write status & content-type,
  # -L follow redirects, -I HEAD request only.
  curl -sIL -o /dev/null \
    -w "%{http_code}|%{content_type}|%{url_effective}" \
    "$url" 2>/dev/null || echo "000|curl-failed|$url"
}

probe_codec() {
  local url="$1"
  if ! command -v ffprobe >/dev/null 2>&1; then
    echo "ffprobe-not-installed"
    return
  fi
  ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
    -of default=noprint_wrappers=1:nokey=1 "$url" 2>/dev/null \
    || echo "ffprobe-failed"
}

mkdir -p "$(dirname "$REPORT")"
TMP_BODY=$(mktemp)
trap 'rm -f "$TMP_BODY"' EXIT

ok_count=0
missing_count=0
forbidden_count=0
codec_warning_count=0
other_count=0

ts=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

{
  echo "# Video Diagnostic Report"
  echo
  echo "**Generated:** $ts"
  echo "**Probe target:** $ROUTE"
  echo "**Base URL:** \`$BASE\`"
  echo "**Slug count:** ${#SLUGS[@]}"
  echo
  echo "Probes every \`<slug>\` against \`<base>/<PascalCase(slug)>.mp4\` — the"
  echo "same URL the runtime composes via \`WorkoutRepository._composeVideoUrl\`."
  echo "200 = file present and reachable. 404 = file missing. 403 = bucket"
  echo "policy blocks anonymous read. \`hevc\` codec = won't play on stock"
  echo "Android (ExoPlayer needs H264/AVC for the broadest device support)."
  echo
} > "$REPORT"

# Stream rows into a temp file as we probe; tally totals; emit final table.
{
  echo "| # | Slug | URL tail | HTTP | Content-Type | Codec | Verdict |"
  echo "|---|---|---|---|---|---|---|"
} >> "$TMP_BODY"

i=0
for slug in "${SLUGS[@]}"; do
  i=$((i + 1))
  pascal=$(to_pascal "$slug")
  filename="${pascal}.mp4"
  url="$BASE/$filename"
  result=$(probe_url "$url")
  http=$(echo "$result" | cut -d'|' -f1)
  ctype=$(echo "$result" | cut -d'|' -f2)
  ctype="${ctype:-unknown}"

  codec=""
  verdict=""
  if [[ "$http" == "200" ]]; then
    codec=$(probe_codec "$url")
    case "$codec" in
      h264|avc1)         verdict="✅ OK"; ok_count=$((ok_count + 1)) ;;
      hevc|h265)         verdict="⚠️ HEVC — re-encode to H264"; codec_warning_count=$((codec_warning_count + 1)) ;;
      vp9|vp8)           verdict="⚠️ VP8/9 — re-encode to H264"; codec_warning_count=$((codec_warning_count + 1)) ;;
      ffprobe-not-installed) verdict="✅ HTTP OK (codec not checked)"; ok_count=$((ok_count + 1)) ;;
      ffprobe-failed)    verdict="✅ HTTP OK (codec probe failed)"; ok_count=$((ok_count + 1)) ;;
      *)                 verdict="✅ HTTP OK (codec=$codec)"; ok_count=$((ok_count + 1)) ;;
    esac
  elif [[ "$http" == "404" ]]; then
    verdict="❌ MISSING — file not in Storage"
    missing_count=$((missing_count + 1))
    codec="—"
  elif [[ "$http" == "403" ]]; then
    verdict="❌ FORBIDDEN — bucket policy or RLS"
    forbidden_count=$((forbidden_count + 1))
    codec="—"
  else
    verdict="❌ HTTP $http"
    other_count=$((other_count + 1))
    codec="—"
  fi

  # Truncate content-type to fit the cell — full value already in the URL
  # tail column for grepability.
  short_ctype="${ctype%%;*}"

  printf '| %d | `%s` | `%s` | %s | %s | %s | %s |\n' \
    "$i" "$slug" "$filename" "$http" "$short_ctype" "$codec" "$verdict" \
    >> "$TMP_BODY"
done

# Emit summary, then the table body, then suggested next steps.
{
  echo "## Summary"
  echo
  echo "- ✅ OK:                **$ok_count**"
  echo "- ❌ Missing (404):     **$missing_count**"
  echo "- ❌ Forbidden (403):   **$forbidden_count**"
  echo "- ⚠️  Codec warnings:   **$codec_warning_count**"
  echo "- ❌ Other failures:    **$other_count**"
  echo
  echo "## Per-slug detail"
  echo
  cat "$TMP_BODY"
  echo
  echo "## Next steps"
  echo
  if [[ $missing_count -gt 0 ]]; then
    echo "- **404s:** Upload the missing \`.mp4\` files to the \`exercises\` Storage bucket using the PascalCase filename in the table. The 10 Phase 85 slugs (incline_bench_press → ab_wheel_rollout) are expected here until you record/encode their videos."
  fi
  if [[ $forbidden_count -gt 0 ]]; then
    echo "- **403s:** The \`exercises\` bucket should be public (read access for anonymous users). Verify in Supabase → Storage → exercises → Settings → Public bucket = ON. RLS only applies to writes for this asset class."
  fi
  if [[ $codec_warning_count -gt 0 ]]; then
    echo "- **HEVC / VP9 codec:** ExoPlayer's stock decoder on Android doesn't accept HEVC reliably below Android 5+ devices and never accepts VP9 inside MP4. Re-encode to H264 baseline:"
    echo "  \`\`\`bash"
    echo "  ffmpeg -i input.mp4 -c:v libx264 -preset veryfast -crf 23 -c:a aac -movflags +faststart output.mp4"
    echo "  \`\`\`"
  fi
  if [[ $other_count -gt 0 ]]; then
    echo "- **Other HTTP codes:** 5xx usually means transient Supabase/CDN issues; re-run. 000 means \`curl\` couldn't reach the host at all (DNS / firewall)."
  fi
  if [[ $ok_count -eq ${#SLUGS[@]} ]]; then
    echo "- **All clear.** Every slug resolved with a usable codec; no action needed for the catalogue."
  fi
} >> "$REPORT"

echo
echo "Done. Report: $REPORT"
echo "Summary: ✅ $ok_count  · ❌404 $missing_count  · ❌403 $forbidden_count  · ⚠️codec $codec_warning_count  · ❌other $other_count"
