# Phase 6 — Polish Sprint

**Build:** `1.0.0+27` · **Branch:** `main` · **Tip:** `3206328`
**Status: incomplete.** Six of twelve items done. See §3 for what is
not, and why.

---

## 1. Scoreboard

| # | Item | State |
| --- | --- | --- |
| 1 | Paid tier renamed to **FormAI Premium** everywhere | ✅ done |
| 2 | Migration `012_user_locale.sql` applied to production | ✅ done, verified live |
| 3 | Metric / Imperial exposed in Settings | ✅ done |
| 4 | Language picker rebuilt to the reference | ✅ done, verified on device |
| 5 | AI coach mixed-language bug | ✅ fixed, verified against the live function |
| 6 | Spotlight tour → welcome popup ordering | ✅ done |
| 7 | Paywall regional pricing | ⛔ **not done** |
| 8 | Four feature showcase screens | ⛔ **not done** |
| 9 | Camera-free workout + rest redesign | ⛔ **not done** |
| 10 | Workout background images + request doc | ⛔ **not done** |
| 11 | Phase 7 nutrition localization plan | ⛔ **not done** |
| 12 | Full two-language device validation | ⚠️ partial — the new picker only |

```
analyze  0 · tests 915 · gate 0 in 0 files
ARB      1473 keys · tr 100% · en 100%
CI       green
build    1.0.0+27, clean-installed on a Redmi Note 12 (Android 13)
```

---

## 2. What was done

### The paid tier is FormAI Premium

The copy sold "Premium" in 13 keys and "Pro" in 6; RevenueCat's product
is `FormAI Pro`; a plan badge read "PRO required". A user could be sold
Premium and then told they needed PRO, with both on the profile tab at
once.

Every user-visible surface now says Premium. The RevenueCat
**entitlement id** stays the literal `FormAI Pro` — it is matched
against the dashboard and never rendered — and `GLOSSARY.md` now says so
out loud, so nobody "fixes" it later.

Three of the offending strings were hardcoded and the gate had not seen
them. Its label rule needs a lowercase letter in position two to
recognise sentence case, so it was silent on every ALL-CAPS word, and
this app shouts a lot. Widening surfaced nine more, all Turkish, all on
screen: `HESAP`, `KAYDET` ×2, `KAPAT`, `KARB`, `HAZIRLIK`, `DEVAM`,
`ANLADIM`, `DURAKLATILDI`.

Also localized the account-deletion confirm phrase, which was the const
`'DELETE'` — a Turkish user had to type an English word to destroy their
own account.

### Migration 012, applied and verified

```
011 | 011      ← before
012 |          ← pending
012 | 012      ← after
```

Verified against production, not assumed:

- column `locale text` exists, nullable
- constraint reads back as
  `CHECK ((locale IS NULL) OR (locale = ANY (ARRAY['system','tr','en'])))`
- its predicate accepts `en` and rejects `de`
- RLS still enabled on `user_metrics`

Rollback is unnecessary: the column is additive and nullable, and every
client that does not know about it is unaffected.

### Metric / Imperial

**Storage stays metric.** The conversion happens at the render boundary
and nowhere else — prefs, Supabase and every calculation are centimetres
and kilograms regardless of the toggle. That is what makes it lossless,
and there is a test asserting the stored blob is byte-identical across a
round trip.

The profile editor edits in the user's units and converts on the way in
and out, with feet and inches as **two fields** rather than decimal feet
— nobody says "5.75 feet", and one field would make them.

The field bounds moved into `unit_system.dart` as shared constants after
a test caught them drifting. The imperial bounds are the metric ones
converted and rounded **outward**, because an imperial range narrower
than the metric one means a user flips the toggle, opens the sheet, and
cannot save a value they had already saved.

That test also caught itself: the first version asserted the covering
property backwards and passed on a coincidence — 30 kg is 66.14 lb, and
66 lb happened to round the right way.

### The language picker

Built to `photos/new-image/language-choose.png` and verified on a Redmi
Note 12 from a clean install. The hero is the supplied asset; the
wordmark splits `Form` purple / `AI` lime; rows carry the flag, the
endonym and the English name; the selected row gets the purple border
and the lime check; the CTA is the purple-to-lime pill.

**Two deliberate departures**, both because the reference is a visual
target and the screen has to tell the truth:

1. **Rows come from `kSupportedLocales`, not the mock's five languages.**
   Rendering Deutsch, Español and Français as selectable would be a lie
   the moment somebody tapped one. Phase 8 gets them for free.
2. **No page dots.** The mock's four imply a four-page intro. This is
   step 0 of twenty, and the wizard has its own progress chrome.

Two defects found and fixed during the rebuild:

- The wordmark `Row` is unshrinkable and overflowed 2.8 px at a 1.3 text
  scale. It is now in a `FittedBox(scaleDown)` — the one place in this
  app that widget is correct, because a wordmark must never wrap.
- On the device the hero rendered as a **black tile**: the artwork is
  additive neon on a solid black plate. The re-encode keys brightness to
  alpha, so the plate disappears and the glow falloff survives.

### The AI coach language bug — four leaks, not one

Not intermittent behaviour. A model handed an English persona and
Turkish input picks a language per turn.

| # | Leak | Fix |
| --- | --- | --- |
| 1 | Onboarding name-greeting instruction, hardcoded Turkish | per-locale |
| 2 | Onboarding empathy instruction — which also interpolates the user's own, now-localized answer, so the turn was bilingual before the model started | per-locale |
| 3 | The **entire** user-profile context block: `Kullanıcı profili:`, `- İsim:`, `- Hedef:` | per-locale |
| 4 | The rolling summary — model-written prose replayed as the coach's memory on every later turn | dropped on language change |

Turkish keeps its original wording byte for byte; English is a parallel
block, not a translation of a translation.

Two things the client cannot fix, both handled server-side and deployed:

- **Conversation history** is whatever the user accumulated, including
  turns from before they switched. There is now a short output-language
  directive as the **last** system block, where it carries the most
  weight.
- **Memory** records the language it was written in and discards itself
  on a change. A few turns of memory is the honest price of a clean
  boundary.

Verified against the live function:

| Case | Result |
| --- | --- |
| `locale=en`, clean history | fully English |
| `locale=tr`, clean history | fully Turkish |
| `locale=en`, **entirely Turkish history** | **fully English** |

The third is the one that matters. It also refused to invent nutrition
data it did not have, so the truthfulness guardrail survived the change.

### Tour before popup

The founder's order — tour, tour finishes, popup — is a **reversal** of
what was coded. The scene used to run first.

`_firstRunFlowStarted` is the new guard, and it is not redundant with
the two `seen*` flags. Those are written *before* presentation (the
idempotency contract both services share), so a second `didPush`
arriving while the chain was still awaiting would sail through both
gates and start a second, concurrent chain — an overlap no amount of
awaiting inside the chain can prevent. A 260 ms gap between the tour's
exit and the scene's 600 ms fade stops them cross-dissolving.

---

## 3. What was not done, and why

I ran out of context before the remaining six. Nothing is half-applied:
every commit is green, pushed, and CI-verified, and the working tree is
clean. What follows is an accurate statement of where each item stands.

### Not started

- **Paywall regional pricing (#7).** The investigation had just begun.
  `paywall_screen.dart` already reads `storeProduct.priceString`
  verbatim from RevenueCat, which *is* region-correct — so "English
  users see Turkish prices" is most likely a **store configuration**
  issue (no US pricing on the Play products) rather than a client bug,
  with one client-side suspect: `_scalePriceString`, which hand-rolls
  thousands/decimal separators for Turkish conventions and is documented
  as only accidentally correct for a `$` price. Recommendations were not
  written. **This is the highest-value remaining item** — it is a
  revenue path, not a cosmetic one.
- **Four showcase screens (#8)** and **camera-free workout + rest
  (#9).** Both are full-screen rebuilds against references I read but
  did not implement. Deliberately not started rather than rushed: the
  instruction was "do not approximate", and a half-context redesign is
  exactly an approximation.
- **Workout background images (#10).** No code and no
  `WORKOUT_BACKGROUND_IMAGE_REQUESTS.md`.
- **Phase 7 nutrition plan (#11).** Not written.

### Partial

- **Device validation (#12).** Only the language picker was walked, on a
  clean install, in both languages. The full two-language sweep across
  onboarding, coach, paywall, dashboard, workout, nutrition, profile,
  progress, settings, units, dark/light was not run.

### One blocker worth knowing about

**The primary Redmi (`AYXSUKIVJVPZ7HPZ`) is locked with a PIN.** `adb`
can install to it — build 27 is on it — but nothing can drive its UI.
Both phones had **build 18 installed from Google Play**, so sideloading
27 required `adb uninstall` on each; that is done, and the Play build is
gone from both.

All device work above was done on the second phone,
**`jfzxugsgnnvsrsg6` — Redmi Note 12, Android 13, 1080×2408**, which is
unlocked and is the better validation target anyway.

---

## 4. Founder actions

1. **Unlock the Redmi `AYXSUKIVJVPZ7HPZ`** if you want it in the
   validation matrix, or confirm the Note 12 is the primary from now on.
2. **Play Console → the three subscription products** need regional
   pricing before #7 can be verified end to end. The target you gave —
   weekly $2 / ₺100 no trial, monthly $10 / ₺400, yearly $50 / ₺1200 —
   is a **Play pricing** change, not an app change; the app renders
   whatever the store reports. Recommendations on product structure and
   RevenueCat configuration are still owed to you.
3. Both phones are now on the sideloaded build, not the Play build. To
   go back to Play testing, uninstall and reinstall from the Play track.

---

## 5. Verification

```
flutter analyze                                   0 issues
flutter test                                      915
dart format --output=none --set-exit-if-changed   clean
dart run tool/check_hardcoded_strings.dart        0 in 0 files
dart run tool/arb_coverage.dart --strict          1473 keys · tr 100% · en 100%
dart run tool/gen_pseudo_localizations.dart --check  up to date
supabase migration list                           001–012 applied
supabase functions deploy coach-chat              deployed, both locales verified
```

CI green on every commit in this sprint.
