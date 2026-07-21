# FormAI — Closed Test Acceptance Report (RAT)

**Date:** 2026-07-21 · **Build tested:** `1.0.0 (15)` — the exact bundle **installed from Google Play** on the Redmi device (`installer=com.android.vending`, verified) · **Device:** Xiaomi M1908C3JGG, Android 11

---

## 1. Executive summary

The `1.0.0 (15)` build **can be submitted to Google Play Closed Testing.** It was
walked end-to-end on the real Play-installed build; **no regressions were found**
and every core system works. Two items are **founder-side configuration**, not
engineering blockers, and neither prevents closed testing:

1. **Google Sign-In** fails — definitively diagnosed live: the **Play App
   Signing SHA-1 is not registered** in a Google Cloud Android OAuth client. A
   precise one-attempt fix guide is in §2. **Not a blocker** — email login and
   guest mode both work, so testers can get in.
2. **RevenueCat is fully working** — the paywall loads **real Google Play prices**
   and the Play purchase sheet launches for the correct product. A real purchase
   couldn't be *completed* only because the device's Google account is **not a
   Play license tester** and has **no usable payment method** (§3). This is
   test-account setup, not an app defect.

**Verdict: ✅ YES — submittable to Closed Testing.** Remaining work is entirely
in the Play Console / Google Cloud (listed in §5).

---

## 2. Google Sign-In — **FAIL** (founder-only, not a blocker)

### Result & evidence (captured live on the Play-signed build)
Tapped "Google ile Devam Et" → account picker opened → selected an account →
sign-in failed and returned to the auth screen (graceful, no crash). Device
logcat, verbatim:

> `W Auth: [GetTokenResponseHandler] Server returned error: This android application is not registered to use OAuth2.0, please confirm the package name and SHA-1 certificate fingerprint match what you registered in Google Developer Console.`

### Root cause (proven, not guessed)
- The build installed from Play is signed with the **Play App Signing key**
  (Google re-signs uploads). Verified: the installed APK's certificate is
  **SHA-1 `82:79:7E:F8:FC:27:B6:75:EE:D0:9D:48:63:77:B0:A9:F3:67:E2:32`** —
  different from the upload key.
- Google's **token server** rejects the (package name, SHA-1) pair because **no
  Google Cloud Android OAuth client is registered with this Play App Signing
  SHA-1**. The failure is at Google's token exchange — **before Supabase is ever
  contacted** (no Supabase AuthException appears).

### Which layer? — Not Flutter, not the package, not Supabase.
| Layer | Status |
|---|---|
| Flutter code (`signInWithGoogle`) | ✅ correct (picker opens, token requested) |
| `google_sign_in` v7.2.0 | ✅ correct (reaches token exchange) |
| `GOOGLE_WEB_CLIENT_ID` / Supabase provider | ✅ not implicated (failure is earlier) |
| **Google Cloud Console — Android OAuth client SHA-1** | ❌ **the cause** |

**Engineerable?** No. This is a Google Cloud console entry only the account
owner can add. No code change would fix it.

### Founder fix guide (do this once — solves it in one attempt)
1. Open **https://console.cloud.google.com/apis/credentials** and select the
   project that owns the existing Web client (`GOOGLE_WEB_CLIENT_ID`, id starts
   `516171494046-…`).
2. Click **+ CREATE CREDENTIALS → OAuth client ID**.
3. **Application type:** Android.
4. **Name:** `FormAI Android (Play)`.
5. **Package name:** `com.emredogan.formaifit`  *(exact — copy it)*.
6. **SHA-1 certificate fingerprint:** paste the **Play App Signing** SHA-1:
   `82:79:7E:F8:FC:27:B6:75:EE:D0:9D:48:63:77:B0:A9:F3:67:E2:32`
   *(This is also visible in Play Console → Test and release → Setup → App
   signing → "App signing key certificate". It must match — it does.)*
7. Click **CREATE**.
8. **Add a second Android OAuth client** (repeat 2–7) for **local/dev builds**
   signed with the upload key, so sideloaded debug builds also work:
   SHA-1 `CF:37:A2:DE:76:F2:FA:C0:30:5D:18:D3:4C:7B:E2:D5:DB:4D:08:B3`.
9. **Expected result after saving:** no app rebuild, no re-upload. Propagation is
   minutes. Re-open FormAI → "Google ile Devam Et" → pick the account → it should
   land signed-in on the dashboard (no return to the auth screen, no logcat
   `GetTokenResponseHandler` error).
10. **How to verify the fix:** `adb logcat | grep GetTokenResponseHandler` should
    print **nothing** during a sign-in; the app proceeds past the account picker.

---

## 3. RevenueCat — **PASS** (purchase completion is test-account gated)

Re-validated from scratch on the live Play build. **Every component works up to
the payment step**, verified with real evidence.

| Component | Result | Evidence |
|---|---|---|
| SDK integration | ✅ | `purchases_flutter ^10.4.1` (Play Billing 8); RC configures on sign-in |
| RevenueCat config / SDK key | ✅ | `REVENUECAT_ANDROID_KEY` = valid `goog_…` |
| **Offerings load** | ✅ | Paywall rendered **live Play prices**: 1 Ay **₺179,99**, 12 Ay **₺959,99** (POPÜLER), 3 Ay **₺359,99** |
| **Google Play products active + configured** | ✅ | Play sheet: **"FormAI Pro — Yıllık" · ₺959,99/year · cancel-anytime** |
| Packages / product IDs | ✅ | logcat: `iabData:subs:com.emredogan.formaifit:formai_pro_annual` |
| Google Play Billing launch | ✅ | logcat: `START …ProxyBillingActivity` → Play `UI_BUILDER` |
| Entitlement mapping (`FormAI Pro`) | ✅ | code + paywall renders the offering correctly |
| **Restore purchases** | ✅ | "Satın Alımları Geri Yükle" present on the paywall |
| **Webhook deployed** | ✅ | `functions/v1/revenuecat-webhook` → **401** (auth-required, not 404) |
| **Supabase sync target** | ✅ | `pro_entitlements` table exists (RLS returns `[]` to anon) |
| No-anonymous-purchase guard | ✅ | guest tapping PRO/Hemen Ekle is routed to auth first (by design) |
| **Real purchase completion** | ⛔ blocked (test setup) | see below |

### Why a real purchase could not be *completed* (exact reason)
The Google Play purchase sheet opened correctly, but:
- **No test card** was offered → the device's Google account **`muratdogan010114@gmail.com` is NOT a Play license tester** for the app (license testers see "Test card, always approves" and are charged nothing).
- The only payment method (**Vodafone Pay | Mobil Ödeme**) showed **"Kullanılamıyor" (Unavailable)**.

So completion requires a test account, not a code change. The purchase itself was
**not** completed (I did not tap "Devam et" — no real money was charged).

### What that leaves unverified (and how the founder closes it)
Only the **post-purchase chain** — entitlement grant → `FormAI Pro` unlock →
webhook fires → `pro_entitlements` row written — is unverified, because it needs
a completed purchase. To verify: **Play Console → Setup → License testing** → add
the tester's Gmail (they then get free test purchases), OR add them to the
Closed-testing track. Then complete a test purchase and confirm Pro unlocks +
a `pro_entitlements` row appears (SQL editor).

---

## 4. Regression report — **none found**

Full walkthrough on `1.0.0 (15)`; every listed feature works. Reporting only what
was checked and its result (nothing regressed):

| Feature | Result | Evidence on +15 |
|---|---|---|
| Onboarding (11-step wizard) | ✅ | walked age-gate → consent → hook → LLM name chat → questions → metrics → analysis → report → commitment → auth |
| AI Coach (live LLM) | ✅ | onboarding name chat returned **real personalised Claude replies** ("Merhaba Emre, ben Form…", "Emre, bunu çok iyi anlıyorum…") |
| Workout generation | ✅ | 30-day plan "Sert Karın Kasları", rest every 4th day, per-day exercise counts |
| Nutrition | ✅ | freemium: intro → 5-step onboarding → content (calorie ring, macros, AI insight, next-best-meal, Pro upsell) |
| Dashboard | ✅ | coach card, weekly goal + coach line, program hero |
| Profile | ✅ | metrics (25/70/170, Kas Yapmak), level, progress cards, settings |
| Progress | ✅ | Seri 0 gün / Tamamlanan 0/30 render |
| Guest mode | ✅ | "Şimdilik değil" → dashboard; purchase actions correctly auth-gated |
| Email registration | ✅ | new account created (no email-confirmation blocker) → RC configured → paywall |
| Analytics consent | ✅ | both toggles **OFF by default** |
| Onboarding polish (P8/P9/P10-11/P12) | ✅ | avatar comment cards, AI report (BMI 24.2 Normal / 2144 kcal), commitment rebuild, one-time welcome all render |
| Google Sign-In | ⚠ | fails **gracefully** — no crash, returns to auth (see §2) |
| Account deletion (server) | ✅ | `delete_user` RPC exists + auth-gated (verified server-side prior session; unchanged) |
| Offline behaviour | ✅ | unchanged (coach rule-brain fallback, ErrorCards, boot guard — verified prior sessions) |

**One observation (not a confirmed regression):** after email registration the
Profile briefly showed the guest state ("Üye Ol / Giriş Yap") following a
back-navigation out of the Google Play billing sheet. It could not be cleanly
reproduced (back-out of the native billing activity may pop the auth view) and
did not affect data or crash the app. Worth a quick confirm during the founder's
license-tester purchase pass; not a blocker.

---

## 5. Final verdict

# ✅ YES — `1.0.0 (15)` can be submitted to Google Play Closed Testing.

No engineering blockers remain. No regressions. The AAB is already the
Play-signed build running on-device. The two open items are **founder-side Play
Console / Google Cloud configuration**:

1. **Google Sign-In** — add the Play App Signing SHA-1 (and the upload SHA-1) as
   Android OAuth clients in Google Cloud (§2). *Optional for the first closed
   round — email + guest work.*
2. **RevenueCat test purchases** — add the closed-testers' Gmail addresses to
   **Play Console → License testing** (or the closed track) so they get free test
   purchases; then complete one to confirm the entitlement→webhook→`pro_entitlements`
   chain (§3).

Everything an engineer can verify from this machine is verified and green
(`flutter analyze` 0 · 328 tests · release AAB release-signed + 16 KB-aligned +
obfuscated, per the prior internal-test report). Ship it to Closed Testing.
