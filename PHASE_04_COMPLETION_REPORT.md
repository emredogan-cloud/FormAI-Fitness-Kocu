# PHASE 4 COMPLETION REPORT — Progressive Disclosure & Feature-Flag Infrastructure

| | |
|---|---|
| **Roadmap** | `TESTERS_COMMUNITY_PRODUCT_ROADMAP.md` → Wave 1, Phase 4 |
| **Covers** | R1.3 · C7 · C28 · C36 · P3 |
| **Commit** | `e2c1b90` |
| **Baseline** | `b9dc830` / build 1.0.0+22 → **`e2c1b90` / build 1.0.0+23** |
| **Quality** | analyze **0** · **732 tests** (was 629, **+103**) · `dart format` clean · **CI GREEN** |
| **Artifact** | release APK **126.6 MB** (obfuscated, split-debug-info) |
| **Device** | Redmi M1908C3JGG (Android 11) |
| **Status** | ✅ **COMPLETE** (engineerable scope; §7 lists what is founder- or traffic-gated) |

---

## 1. What this phase is really for

The roadmap says it plainly: *"This is permanent infrastructure and the
real deliverable of the phase."* Staged disclosure is the headline
feature, but the thing every later wave depends on is the flag layer —
the ability to ship to a slice, kill a misbehaving feature without an app
update, and run an experiment.

So the phase was built in that order: flags first, then disclosure as
their first real consumer.

---

## 2. Feature flags (C7)

`FeatureFlags.isEnabled(flag)` is **synchronous, total, and cannot
throw**. Call sites read it like a constant, because from their point of
view it is one.

Ten flags ship, each with a **default compiled into the binary**. A flag
is a *deviation* from shipped behaviour, never a prerequisite for it.

The design is shaped entirely by the phase's hardest success criterion —
*the app must be 100% functional with the flags service unreachable* —
because a remote-config layer that can brick the app has made reliability
worse, and it fails in exactly the conditions users are least forgiving:
a basement gym, a train, a hotel captive portal.

| Guarantee | How |
|---|---|
| No network, ever | Compiled defaults; `refresh()` swallows every failure |
| Second launch is still right | Last good payload cached to disk |
| A corrupt payload can't half-apply | `parsePayload` returns null on structural damage; previous values stand |
| A typo can't flip a feature | Non-bool values are dropped, not coerced — `"true"` is not `true` |
| Server may run ahead of the client | Unknown keys ignored, so a flag row can exist before the release that reads it |
| A flip lands in ≤ 5 min | 5-minute TTL, pinned by test |

**This is verified live rather than only in tests.** Migration 009 is
authored but *not applied to production*, so the `feature_flags` table
does not exist — every fetch on the device fails. The entire app was then
walked end-to-end in that state. That is the criterion satisfied under
the most realistic conditions available.

---

## 3. Progressive disclosure (R1.3)

Six capabilities on a day 2 → 14 schedule. Three rules keep it an
introduction rather than a restriction — which is the difference between
this and every disclosure system that has annoyed you:

**1. Navigation is never blocked.** Locked tabs render at reduced opacity
and stay fully tappable. The roadmap is explicit that the hard-block
pattern is reserved for Pro. A dimmed-but-working tab says "there's
something here you haven't met"; a disabled one says "you may not", and
only one of those is true. *Verified on device: the dimmed Beslenme tab
opened normally.*

**2. Effort beats waiting.** A capability opens on days-since-install
**or** completed-sessions, whichever comes first. Someone who trains
three times on day one has earned the progress surfaces; making them wait
would punish the exact behaviour the app wants. This also shapes the
copy — on day 0 every hint reads *"1 antrenman sonra açılıyor"*, turning
each lock into a nudge toward training.

**3. Nobody is ever re-locked.** The kill switch, grandfathering and
manual unlocks all only ever *open*. A test asserts unlocked capabilities
grow monotonically across 30 simulated days, and the grandfathering path
has its own suite: a user mid-journey when this ships keeps everything,
and is told nothing "just unlocked".

---

## 4. Discovery hub (C28)

Everything FormAI can do, listed from day one, grouped by pillar, with
each row's state and an immediate **"Şimdi aç"** on every locked one.

This screen is what keeps the schedule honest. A schedule that only
withholds is a restriction dressed up as onboarding; one the user can see
in full and opt out of in a tap is an introduction.

It is also the phase's own measuring instrument: the manual-unlock rate
is the honest read on whether the pacing is right. If lots of people
unlock early, the pacing is wrong — not the users.

---

## 5. The unlock moment

*"Each unlock is a small coach-delivered celebration, not a silent
appearance."* A capability that quietly shows up is a UI change; one the
coach hands you is a reward.

Two decisions worth naming:

**One per visit, not all pending.** A user returning after a week could
cross three thresholds at once, and three cinematics back-to-back is a
cutscene nobody asked for. The rest arrive on later visits — which also
spreads the reward out, which is the mechanic's whole purpose.

**It goes before the asks.** In the dashboard return flow the celebration
now precedes the Pro invitation, the rating prompt and the survey, and
suppresses them for that visit. Handing someone a new capability and
immediately asking them to pay or rate would spend the goodwill the
moment just created.

It carries the same watchdog as the Phase 3b first-run scenes, for the
same reason: it is a full-screen route with no visible exit.

---

## 6. Experiments (C36 · P3), tips (C28), migrations

**Bucketing** is `sha256(experimentId:userId) % buckets`. The same user
always lands in the same bucket — not usually, always, with no stored
assignment to drift and no network round-trip, so client and server
compute the same answer independently. Anonymous users get **control,
never a variant**, because their behaviour cannot be attributed. Hashing
rather than using the id directly also removes the accidental correlation
you'd get from bucketing on a time-ordered uuid.

**Tips** gained a 20-hour frequency cap — dismissal already stops one tip
repeating; the cap stops the catalogue behaving like a queue where
dismissing one produces the next. Plus three context rules: paused-session
reassurance (ranked above every discovery tip, because someone who walked
away mid-session is likeliest to churn and likeliest to read a feature
suggestion as the app missing the point), a nutrition-wizard nudge, and
camera-framing advice suppressed for camera-free users — for whom it is
advice about a feature they turned off on purpose.

**Migrations 009 + 010** are authored, **not applied to production
(founder)**. 009 seeds every flag to values that *match the compiled
defaults*, so applying it is a behavioural no-op — a migration that
silently changes what users see the moment it runs is indistinguishable
from an outage. 010 deliberately has **no UPDATE policy**: re-bucketing a
user mid-experiment silently invalidates their data, and making it
impossible through the API is cheaper than detecting it later.

---

## 7. Success criteria — status

| Criterion | Status |
|---|---|
| Flag layer live with ≥ 8 flags controlling real behaviour | ✅ **10**, all wired to real call sites |
| App 100% functional with the flags service unreachable | ✅ Test + **verified live** (table absent in prod) |
| Kill switch: a flip disables a feature within 5 min, no app update | ✅ Client side complete + TTL pinned by test. End-to-end flip **requires migration 009 applied — founder** |
| Tests: +22 minimum · analyze 0 | ✅ **+103**, analyze 0 |
| D7 retention +8pp vs. pre-disclosure cohort | ⏳ Post-launch measurement |
| Discovery hub opened by ≥ 30% in month 1 | ⏳ Post-launch measurement (`discoveryHubOpened` instrumented) |
| Manual-unlock rate ≤ 15% | ⏳ Post-launch measurement (`manualUnlock` instrumented) |
| Onboarding A/B reaches significance with a documented decision | ⏳ Needs live traffic; experiment ships **off** by design |

The four ⏳ rows are measurements, not engineering. Every one of them has
its instrumentation shipped in this phase.

---

## 8. Device verification

Redmi M1908C3JGG · Android 11 · fresh state.

| # | Verified | Result |
|---|---|---|
| 1 | Locked tabs render at reduced emphasis | ✅ Beslenme + Gelişim dimmed at day 0 |
| 2 | **Locked ≠ blocked** | ✅ Dimmed Beslenme opened normally |
| 3 | Discovery hub entry in Profil | ✅ "Keşfet", beside Uygulama Turu |
| 4 | Hub renders the capability map | ✅ Pillars, blurbs, lock icons, 0/6 progress |
| 5 | Unlock hints point at the shorter road | ✅ "1 antrenman sonra açılıyor" |
| 6 | Manual unlock | ✅ Row flipped to ✓ + "Aç"; progress 0/6 → 1/6 instantly |
| 7 | Nav reflects the unlock | ✅ Beslenme bright, Gelişim still dimmed |
| 8 | New Phase 4 tip fires correctly | ✅ `nutrition_wizard_incomplete` after opening the tab without finishing |
| 9 | App fully functional with no flag table | ✅ Whole session ran on compiled defaults |

The unlock **celebration** was not seen on device: it needs a threshold
crossed while the app is installed (day 2, or a completed session), which
this pass did not reach. Its copy, gating and ordering are covered by
tests; the cinematic itself reuses the Phase 3b scene system, verified on
device there.

---

## 9. Testing

**732 tests pass (was 629, +103). analyze 0. format clean. CI green.**

| Concern | Tests | Notable assertions |
|---|---|---|
| Feature flags | 22 | Keys unique + snake_case; **defaults on a fresh install**; cached payload survives a cold start; garbage → defaults; **`"true"` is not coerced to true**; unknown keys ignored; a corrupt cache degrades to compiled defaults; unparseable timestamp is stale not fresh; **`refresh()` with Supabase uninitialised completes quietly and every flag still resolves** |
| Disclosure schedule | 24 | Every capability opens on its day AND its session count; **unlocked set grows monotonically over 30 days**; kill switch and grandfathering unlock everything; a manual unlock doesn't leak to neighbours; unknown ledger keys harmless; every capability is reachable (route or tab) |
| Grandfathering | 14 | Fresh install is **not** grandfathered; day-1 and same-day-with-a-session are; **the flag is a one-way door**; announcement copy personalises name + streak and stays grammatical without them |
| Experiments | 12 | Same user → same bucket over 200 calls; different experiments bucket independently; **anonymous → control, never a variant**; 2-way and 3-way splits both even within 6pp; sequential ids don't produce sequential buckets |
| Discovery hub | 14 | Every capability listed; every locked row has an override; manual unlock persists, counts as announced, and **flips the row without leaving the screen**; small-phone layout; semantics state lock status |
| Tips cap + rules | 17 | New tips suppressed inside the window, allowed at the boundary; **the on-screen tip is exempt so it can't flicker away**; the cap can't resurrect a dismissed tip; paused-session outranks discovery; camera-free users never get framing advice |

### A bug the tests caught

The hub's manual unlock didn't refresh the row: `AppPreferences` mutates
in place, so the provider reading it had no way to know its inputs
changed. The button would have appeared to do nothing. Fixed with an
explicit invalidation, and then watched working on the device.

---

## 10. Files changed

**New — production (5)**: `core/services/feature_flags.dart` ·
`experiments.dart` · `progressive_disclosure.dart` ·
`disclosure_providers.dart` · `unlock_announcer.dart` ·
`features/home/presentation/discovery_hub_screen.dart`

**New — migrations (2)**: `009_feature_flags.sql` ·
`010_user_experiments.sql` *(not applied — founder)*

**Modified (6)**: `app_preferences` (manual/announced unlock ledgers,
grandfathering, tip timestamp) · `dashboard_screen` (locked-tab emphasis,
unlock moment in the return flow, tip cap + new signals) · `profile_tab`
(Keşfet entry, flag-gated) · `app_router` (hub route) ·
`analytics_service` (5 events) · `discovery_tips` (cap + 3 rules) ·
`main.dart` (start-of-session flag refresh, grandfathering, bucketing)

**New — tests (6)**

---

## 11. Next phase

**Wave 2 · Phase 5 — Internationalization Infrastructure.** The largest
investment in the roadmap and the one that unlocks the 10k–100k install
ambition (P7). The ~70 Turkish string literals accumulated across Phases
3–4 join that extraction.

---

*Phase 4 complete. `e2c1b90` on `main`, CI green, build 1.0.0+23.*
