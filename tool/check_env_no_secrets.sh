#!/usr/bin/env bash
# Phase 0 (P-Risk) · build-time secret guard.
#
# Fails the build if a .env file destined for the client bundle contains a
# TRUE secret — a value that must never ship inside a mobile binary.
#
# Client-PUBLIC keys are allowed and expected (they are extractable from any
# mobile app by design and are protected server-side):
#   SUPABASE_ANON_KEY     · gated by Postgres RLS
#   REVENUECAT_*_KEY      · public SDK key, entitlements verified server-side
#   SENTRY_DSN            · ingest-only DSN
#   POSTHOG_API_KEY       · project (write-only) key
#   GOOGLE_WEB_CLIENT_ID  · public OAuth client id
#
# FORBIDDEN (must live in .env.local / CI secrets only, never an asset):
#   *_DB_PASSWORD · *SERVICE_ROLE* · *_SECRET · *PRIVATE_KEY* · raw PEM blocks
#
# Usage:  bash tool/check_env_no_secrets.sh [path-to-.env]   (default: .env)
set -euo pipefail

ENV_FILE="${1:-.env}"
if [ ! -f "$ENV_FILE" ]; then
  echo "guard: '$ENV_FILE' yok — atlanıyor (CI'da boş .env normaldir)."
  exit 0
fi

FORBIDDEN='SUPABASE_DB_PASSWORD|.*SERVICE_ROLE.*|.*_SECRET|.*PRIVATE_KEY.*|.*DB_PASSWORD.*'

# Match forbidden KEY names that carry a non-empty value, redact the value.
bad="$(grep -iE "^(${FORBIDDEN})=.+" "$ENV_FILE" | sed -E 's/=.*/=<redacted>/' || true)"
# Only a real PEM block counts — not the words "PRIVATE KEY" in a comment.
pem="$(grep -cE '^-{3,}BEGIN[A-Z ]*PRIVATE KEY' "$ENV_FILE" || true)"

if [ -n "$bad" ] || [ "${pem:-0}" -gt 0 ]; then
  echo "❌ GÜVENLİK İHLALİ — '$ENV_FILE' içinde gönderilemez sır(lar) var:"
  [ -n "$bad" ] && echo "$bad"
  [ "${pem:-0}" -gt 0 ] && echo "  (PRIVATE KEY bloğu tespit edildi)"
  echo
  echo "Bu anahtarları '$ENV_FILE'den kaldır. Ops için '.env.local' (asset DEĞİL) veya CI secret kullan."
  exit 1
fi

echo "✅ guard: '$ENV_FILE' temiz — yalnız client-public anahtarlar bundle ediliyor."
