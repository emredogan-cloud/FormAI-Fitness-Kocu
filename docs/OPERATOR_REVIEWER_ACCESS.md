# Operator Runbook — Google Play / App Store Reviewer Access

**Account:** `emre30283@gmail.com`
**Purpose:** Grant the store reviewer account full Pro/Premium access during
review without exposing premium to normal users or shipping insecure client
bypasses.

---

## 1. Design — what the code does

The reviewer flow is **defense in depth**, two independent layers:

| Layer | What it is | Where it lives | Why it's safe |
|---|---|---|---|
| **JWT claim** (primary, immediate) | `app_metadata.role = 'reviewer'` set on the reviewer's `auth.users` row | Supabase Studio (or SQL) | `app_metadata` is **service-role writable only**. A client cannot self-promote — Supabase verifies the JWT signature on every request, so a tampered token is rejected before the provider ever reads it. |
| **RevenueCat promotional entitlement** (parallel, mirror) | A "FormAI Pro" Promotional Entitlement granted to the reviewer's RC App User ID | RevenueCat dashboard | RC dashboard requires team auth. Reviewer accounts have to sign in once before they appear in RC, so this layer trails the JWT layer by one cold start. |

**Single source of truth in code:** `isProProvider` in `lib/features/monetization/providers/monetization_provider.dart:193`. It now resolves to:

```
isDeveloperOverride || isPro || isReviewer
```

- `isDeveloperOverride` — local SharedPreferences flag flipped by the debug Sandbox button (gated to `kDebugMode`, so **not active in release builds**).
- `isPro` — RevenueCat's reported entitlement.
- `isReviewer` — JWT claim, defined in `isReviewerProvider` (`auth_provider.dart:69`).

Every feature gate already watches `isProProvider`, so no per-feature change is needed.

---

## 2. Apply — Supabase Studio (primary layer)

### Prerequisite: reviewer signs in once

The reviewer account must exist in `auth.users` before you can stamp the role.
Have the reviewer (or you, on a test device) complete a Google sign-in with
`emre30283@gmail.com` against the production Supabase project. This creates
the row.

### Option A — Supabase Studio UI (recommended)

1. Open **Supabase Studio → Authentication → Users**.
2. Find `emre30283@gmail.com`.
3. Click the user row → scroll to **User App Metadata** (the section labelled
   `app_metadata`, NOT `user_metadata`).
4. Set the JSON to:
   ```json
   { "role": "reviewer" }
   ```
   If `app_metadata` already has keys (e.g. `provider: google`), merge:
   ```json
   { "provider": "google", "providers": ["google"], "role": "reviewer" }
   ```
5. Save. The reviewer must **sign out and back in** (or wait for their access
   token to refresh — default ~1 h) for the new claim to land in the JWT.

### Option B — SQL fallback

Run in **Supabase SQL Editor** (service-role context) — preserves any existing
keys in `raw_app_meta_data`:

```sql
update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
                      || jsonb_build_object('role', 'reviewer')
where email = 'emre30283@gmail.com';
```

Verify:

```sql
select email, raw_app_meta_data
from auth.users
where email = 'emre30283@gmail.com';
```

Expect `raw_app_meta_data` to include `"role": "reviewer"`.

> **Why `raw_app_meta_data` and not `raw_user_meta_data`:** the user-facing
> client can write to `user_metadata`, so a malicious user could self-promote
> if we keyed off that. `app_metadata` is server-only.

---

## 3. Apply — RevenueCat (parallel mirror layer)

This step is optional but recommended so RC dashboards, webhooks, and the
`pro_entitlements` Supabase table also reflect Pro for the reviewer.

1. The reviewer must have completed a sign-in (step 2 prerequisite). On that
   first sign-in `AuthController.aliasRevenueCatWithCurrentUser` (`auth_provider.dart:383`) calls
   `Purchases.logIn(supabase_user_id)`, which creates the reviewer's RC
   Customer entry keyed by their Supabase UUID.
2. Open **RevenueCat dashboard → Customers**.
3. Search by the reviewer's Supabase UUID. To find it:
   ```sql
   select id from auth.users where email = 'emre30283@gmail.com';
   ```
4. Open the customer → **Promotional Entitlement → Grant**.
5. Pick entitlement **`FormAI Pro`** (case-sensitive — see `kProEntitlementId` in code).
6. Duration: **Lifetime** (or a fixed duration past your expected review
   window — typically 90 days is plenty).
7. Reason / note: `Google Play / App Store review account`.
8. Save.

The next time the app calls `Purchases.getCustomerInfo()` (cold start, paywall
open, refresh), the entitlement appears in `customer.entitlements.active`
and `isPro` flips to true via the regular path.

---

## 4. Verify — QA checklist

Run these against a release-mode build (or at minimum a profile build) so the
debug Sandbox button is hidden — that way you're testing the production gate.

| # | Step | Pass condition |
|---|---|---|
| 1 | Fresh install, sign in as `emre30283@gmail.com` via Google | Sign-in succeeds; no error toast |
| 2 | Open the workout list (any feature that uses `isProProvider`) | No paywall / locked overlay; full content visible |
| 3 | Open Profile → Subscription state | Should reflect Pro (via either layer) |
| 4 | Force-close, reopen | Pro persists across cold start (JWT cached) |
| 5 | Sign out, sign back in with `emre30283@gmail.com` | Pro re-appears within the post-sign-in render |
| 6 | Sign in with a **different** test account that has **no** `role` claim | Paywall is shown; locked overlays appear; Pro features denied |
| 7 | Check Sentry / PostHog for the reviewer session | No errors logged from `monetization` category |
| 8 | (Optional) Check Supabase `pro_entitlements` row for the reviewer | After RC promotional grant + first customerInfo refresh, the webhook should have written `is_active = true` |

**Failure on #6 is critical.** If a non-reviewer account also unlocks Pro,
stop and audit — that means the claim was placed on the wrong row or the
provider has a bug.

---

## 5. Revoke — when review is done

Both layers must be revoked.

### JWT claim

```sql
update auth.users
set raw_app_meta_data = raw_app_meta_data - 'role'
where email = 'emre30283@gmail.com';
```

The reviewer's next token refresh (≤1 h) drops `isReviewer` to false. To force
an immediate effect, also invalidate their refresh tokens:

```sql
delete from auth.refresh_tokens where user_id = (
  select id from auth.users where email = 'emre30283@gmail.com'
);
```

(They'll be signed out on next app open.)

### RevenueCat promotional entitlement

RC dashboard → Customer (reviewer's UUID) → Promotional Entitlements → **Revoke**.

### Verify revocation

Re-run QA step #2 (workout list) signed in as the reviewer — paywall must
re-appear.

---

## 6. Security considerations

| Concern | Mitigation |
|---|---|
| Can a normal user grant themselves `role = 'reviewer'`? | No. `app_metadata` is service-role only. Supabase verifies the JWT signature on every request — a tampered client token is rejected at the API layer, well before this app's code reads it. |
| Can someone register a new Google account with the same email? | No. Google won't issue a JWT for an email that doesn't belong to the user. Supabase's Google OAuth provider trusts Google's verified email claim. |
| Could the reviewer share their account and leak Pro? | The grant is scoped to **one specific `auth.users.id`** (the reviewer's Supabase UUID). Sharing the email + Google password would share Pro, but that's true for any genuinely purchased Pro account. Acceptable risk — same surface as a legitimate paying user sharing credentials. |
| Could the JWT claim leak into a public build artefact? | No. The reviewer email is **not** in the binary. The check is `role == 'reviewer'`, which only matches users whose `app_metadata` is server-side stamped. Anyone reverse-engineering the APK learns "there is a reviewer-role check" but cannot mint such a token. |
| Could the RC promotional entitlement leak via offerings? | Promotional entitlements are per-customer — they do not appear in offerings or paywall product lists. Other users see the regular paywall. |
| What if Supabase Studio is compromised? | A Studio compromise lets an attacker stamp `role = admin` (which already has access to admin tools) or `role = reviewer`. Reviewer access is strictly less sensitive than the admin role that already exists, so this adds no new attack surface. |

---

## 7. Why we did NOT do other approaches

| Rejected approach | Reason |
|---|---|
| Hardcode `emre30283@gmail.com` in Dart | Bakes the email into the shipped binary; revocation requires a rebuild + force-update; bypasses Supabase's signature verification. |
| `reviewer_allowlist` SQL table | Extra schema, extra RLS, extra round-trip. Strictly worse than a JWT claim that's already verified on every request. |
| Disable the paywall globally for any flag | Violates the security rule "don't expose admin logic in Flutter UI" and risks the flag flipping on for everyone. |
| Use only RC Promotional Entitlement | The reviewer's App User ID doesn't exist in RC until they sign in once, so you cannot pre-grant. Also subject to ~RC-sync latency — paywall could briefly flash on the first cold start. The JWT layer is immediate; the RC grant is the parallel mirror, not the primary lever. |
| Reuse `isAdminProvider` for the reviewer | Conflates two unrelated grants — admin gets access to admin tools (`/admin` routes); reviewer should only get Pro. Keeping them separate means revoking reviewer doesn't accidentally remove admin or vice versa. |

---

## 8. Code references

| File | Line | Purpose |
|---|---|---|
| `lib/features/auth/providers/auth_provider.dart` | 69 | `isReviewerProvider` — reads JWT claim |
| `lib/features/monetization/providers/monetization_provider.dart` | 193 | `isProProvider` — single Pro gate, ORs in reviewer |
| `lib/features/monetization/providers/monetization_provider.dart` | 16 | `kProEntitlementId` — must match RC dashboard exactly |
| `supabase/migrations/003_create_pro_entitlements.sql` | — | Server-side entitlement table (RC webhook target) |

---

## 9. Quick reference — full grant + revoke

**Grant (one-time, after reviewer first signs in):**

```sql
-- 1. Stamp the JWT claim
update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
                      || jsonb_build_object('role', 'reviewer')
where email = 'emre30283@gmail.com';
```

Then in RC dashboard: grant `FormAI Pro` promotional entitlement to the
reviewer's Supabase UUID, Lifetime.

**Revoke (after review approval):**

```sql
-- 1. Drop the JWT claim
update auth.users
set raw_app_meta_data = raw_app_meta_data - 'role'
where email = 'emre30283@gmail.com';

-- 2. Force immediate effect by clearing refresh tokens (optional)
delete from auth.refresh_tokens where user_id = (
  select id from auth.users where email = 'emre30283@gmail.com'
);
```

Then in RC dashboard: revoke the promotional entitlement on the reviewer's
customer record.
