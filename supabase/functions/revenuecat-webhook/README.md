# revenuecat-webhook · phase 138 B-5

Edge function that mirrors RevenueCat subscription events into the
`public.pro_entitlements` table. Required for Play Console subscription
compliance ("Establish entitlement on a secure server") and KVKK
auditability of paid-state changes.

## What it does

1. Verifies the `Authorization: Bearer <secret>` header from RevenueCat.
2. Parses the event payload.
3. Maps the event type to an `is_active` flag (`INITIAL_PURCHASE`,
   `RENEWAL`, `PRODUCT_CHANGE`, `UNCANCELLATION`, `TRANSFER` → true;
   `EXPIRATION`, `SUBSCRIPTION_PAUSED` → false; `CANCELLATION` and
   anything else → leaves existing flag alone).
4. Idempotency-checks `last_event_id` against the incoming event.
5. Upserts `pro_entitlements` keyed on `user_id` (= RevenueCat
   `app_user_id`, which the app sets to the Supabase `auth.uid()` via
   `Purchases.logIn` after sign-in).

## Prerequisites

- Supabase project ref + access token (you've already run
  `supabase login` once locally).
- The `pro_entitlements` table exists. Apply the migration first:
  ```bash
  supabase db push
  # or, against a remote project:
  supabase db push --linked
  ```

## Deployment (founder-run, NOT auto-executed)

> ⚠️ These commands write to production Supabase. Run them yourself.
> Claude has been instructed not to execute deployment commands
> automatically because they touch live secrets and credentials.

```bash
# 1. From the repo root, generate a long random webhook secret.
openssl rand -base64 48

# 2. Save it as a Supabase secret. Replace <SECRET> with the output
#    above. Supabase persists this — you won't see it in plaintext
#    again; copy it to 1Password / Bitwarden as the source of truth.
supabase secrets set REVENUECAT_WEBHOOK_SECRET=<SECRET>

# 3. Deploy the function. JWT verification is NOT required for this
#    endpoint because the request comes from RevenueCat, not from
#    an authenticated user — they don't carry a Supabase JWT.
supabase functions deploy revenuecat-webhook --no-verify-jwt

# 4. Grab the public URL Supabase echoes back. It looks like:
#    https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook
```

## RevenueCat dashboard configuration

1. Log in to https://app.revenuecat.com
2. Select project FormAI → **Integrations** → **Webhooks** → **+ Add**.
3. Fill the form:
   - **URL:** the function URL from step 4 above.
   - **Authorization header:** paste the same `<SECRET>` you generated
     in step 1. RevenueCat will send it as `Bearer <SECRET>`.
   - **Event types:** enable everything (INITIAL_PURCHASE, RENEWAL,
     CANCELLATION, EXPIRATION, BILLING_ISSUE, SUBSCRIBER_ALIAS,
     PRODUCT_CHANGE, UNCANCELLATION, NON_RENEWING_PURCHASE,
     SUBSCRIPTION_PAUSED, TRANSFER, EXPIRATION).
4. **Send test event** (sandbox) — you should see a 200 OK in the
   delivery log and a row appear in `pro_entitlements`.

## Validation

After deployment + RC setup, walk through this checklist:

- [ ] Sandbox subscribe → `pro_entitlements.is_active = true`, row
      stamped with `last_event_type = INITIAL_PURCHASE`.
- [ ] Sandbox cancel (but trial still in date) → row's `is_active`
      stays `true`, `last_event_type = CANCELLATION`. (RC pushes
      CANCELLATION when the user taps "cancel"; access lasts until
      `expires_at`.)
- [ ] Wait for sandbox expiration / fast-forward via RC dashboard
      → `EXPIRATION` event flips `is_active = false`.
- [ ] Replay the same `EXPIRATION` event from RC dashboard → second
      call returns `{ ok: true, idempotent: true }`, row unchanged.
- [ ] Tamper with the `Authorization` header → 401.

## Local development

```bash
# Run the function locally against a Supabase shadow DB.
supabase functions serve revenuecat-webhook

# In a second shell, simulate an INITIAL_PURCHASE.
curl -X POST http://localhost:54321/functions/v1/revenuecat-webhook \
  -H "Authorization: Bearer local-test-secret" \
  -H "Content-Type: application/json" \
  -d '{"api_version":"1.0","event":{"id":"evt_local_1","type":"INITIAL_PURCHASE","app_user_id":"<some-supabase-uuid>","product_id":"formai_pro_monthly","period_type":"NORMAL","expiration_at_ms":'$(date -d "+30 days" +%s)'000,"event_timestamp_ms":'$(date +%s)'000}}'
```

The `REVENUECAT_WEBHOOK_SECRET` for `serve` is read from
`supabase/.env.local`. Add:
```
REVENUECAT_WEBHOOK_SECRET=local-test-secret
```

## Operational notes

- The Flutter client (`lib/features/monetization/providers/monetization_provider.dart`)
  still reads `Purchases.getCustomerInfo()` as the primary signal —
  this table is the secondary source-of-truth. Server-protected
  endpoints (future) should consult `pro_entitlements` directly via
  RLS; client UX should keep trusting RC because it's faster and
  reflects the active-purchase moment.
- The `app_user_id` mapping depends on `Purchases.logIn(user.id)`
  being called after Supabase sign-in (see
  `lib/features/auth/providers/auth_provider.dart:404`). Don't break
  that link — if RC's `app_user_id` ever drifts away from
  `auth.uid()`, this table can't find the right row to update.
- If you ever rotate `REVENUECAT_WEBHOOK_SECRET`, set the new secret
  in Supabase **first**, then update the RC dashboard. The window
  between the two writes will reject events as 401 — RC retries up
  to ~3 days so you usually don't lose any, but rotate during a
  quiet hour anyway.

## Rollback

```bash
# Take the function offline (returns 404 for new traffic):
supabase functions delete revenuecat-webhook

# Then drop the table if you want a clean slate:
# (Supabase SQL Editor)
# DROP TABLE public.pro_entitlements CASCADE;
```

The Flutter client tolerates an empty / missing `pro_entitlements`
table because it reads RC directly; removing the webhook simply
returns the app to its pre-B-5 client-side-only entitlement model.
