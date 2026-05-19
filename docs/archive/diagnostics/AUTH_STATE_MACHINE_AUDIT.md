# AUTH_STATE_MACHINE_AUDIT — paywall · auth · modal · navigation

Companion to `AUTH_FLOW_TRACE.md` and `ROOT_CAUSE_ANALYSIS.md`.
Investigation date 2026-05-17. **Audit only — no code changed.**

---

## 1 · Auth identity states (Supabase + claims)

| State | Predicate | Reached by | Persists across cold-start? |
| --- | --- | --- | --- |
| `signedOut` | `currentSession == null` | fresh install · `signOut()` · `deleteAccount()` · expired refresh with no network | yes (no Hive box) |
| `anon-pure` | `currentSession != null ∧ user.isAnonymous == true ∧ user.email.isEmpty ∧ user.newEmail.isEmpty` | `signInAnonymously` from `_continueAsGuest` | yes |
| `anon-linked-pending` | `isAnonymous == true ∧ (email.isEmpty ∨ null) ∧ newEmail.isNotEmpty` | `updateUser({email, password})` on `anon-pure` when Supabase "Confirm email" is ON | yes (until user clicks link) |
| `anon-linked-confirmed-flip-pending` | `isAnonymous == true ∧ email.isNotEmpty` (very narrow window) | server response between flipping the flag and Flutter rebuild | only as in-memory transient (1 frame) |
| `registered` | `isAnonymous == false ∧ email.isNotEmpty` | `signInWithPassword` · OAuth · email-confirmation callback · `updateUser` with "Confirm email" OFF | yes |
| `registered + admin` | `registered ∧ app_metadata.role == 'admin'` | Supabase Studio service-role write | yes |
| `registered + reviewer` (Phase 139, uncommitted) | `registered ∧ app_metadata.role == 'reviewer'` | Supabase Studio service-role write on `emre30283@gmail.com` | yes |

Notes:
- `anon-linked-confirmed-flip-pending` shouldn't exist in practice;
  Supabase's `updateUser` returns either `isAnonymous=true` (Confirm
  email ON) or `isAnonymous=false` (Confirm email OFF) atomically with
  the new email. Listed only to document that the gate's predicate
  must not assume `isAnonymous` and `email` are independent.

---

## 2 · Paywall modal states (`_PaywallScreenState`)

| State | Predicate | Reached by | Exit |
| --- | --- | --- | --- |
| `M0-fresh-mount` | `_authGateShown == false ∧ not yet built` | construction of `_PaywallScreenState` | first `build()` |
| `M1-pre-gate` | `_authGateShown == false ∧ build running` | `build()` entered, `_onAuthStateChanged` not yet called this frame | first run of `_onAuthStateChanged` |
| `M2-gate-skipped` | `_authGateShown == false ∧ needsAuth was false on the synthetic init call` | `_onAuthStateChanged` ran and returned `!needsAuth` | could be re-entered on `ref.listen` transition; latch never set |
| `M3-gate-scheduled` | `_authGateShown == true ∧ post-frame callback not yet run` | `_onAuthStateChanged` set the latch | post-frame callback runs |
| `M4-gate-visible` | `_authGateShown == true ∧ AuthGate route on root navigator` | post-frame `showAuthGate` returned | user taps Google/Apple success · taps email-link · or app is backgrounded and torn down |
| `M5-post-pop` | `_authGateShown == true ∧ modal popped ∧ _PaywallScreenState still alive` | Google/Apple success popped the modal | route replacement → `M6` |
| `M6-disposed` | `_PaywallScreenState.dispose()` called | route replacement (`pushReplacement`, GoRouter redirect) | terminal |

Allowed transitions:

```
M0 → M1 → M2 ↻         (on the synthetic-init synchronous call)
M0 → M1 → M3 → M4      (synthetic-init triggered the gate)
M2 → M3 → M4           (ref.listen fired with a needsAuth user)
M4 → M5                (modal popped via Google/Apple success)
M5 → M6                (paywall replaced by /auth or /dashboard
                        or by a redirect from refreshListenable)
M0 → M6                (rare: state disposed before first build,
                        e.g. fast re-navigation)
```

Disallowed transitions (would be bugs):

- `M3 → M2`: would require `_authGateShown` to be reset. **Not done
  anywhere in code.** Safe.
- `M4 → M3` (without M5/M6): would require the gate to "un-fire" and
  re-fire on the same State. **Not possible — latch never resets.**
- `M2 → M4` without going through M3: would require `showAuthGate` to
  be called from outside `_onAuthStateChanged`. **No other call site
  exists** (`grep showAuthGate` → only line 205).
- `M6` → anything: terminal.

**Therefore: on any *single* `_PaywallScreenState`, the modal can
appear at most once.** Any "modal re-appearance" implies M6 ran for
the prior State and a NEW `_PaywallScreenState` instance entered M0.

---

## 3 · Paywall purchase-button states

| State | Predicate | Effect |
| --- | --- | --- |
| `P-waiting-sdk` | `!_purchasesConfigured` (RC SDK probe pending) | CTA disabled, spinner |
| `P-waiting-offerings` | `subscription.isLoading` | CTA disabled, spinner; cards show `SkeletonBox` |
| `P-ready-real` | `_purchasesConfigured ∧ offerings.current != null` | CTA enabled, cards show RC price |
| `P-ready-fallback` | `_purchasesConfigured ∧ offerings.current == null ∧ !subscription.isLoading` | CTA disabled with "Satın alma kullanılamıyor" toast on tap; cards show hardcoded `_fallbackPrice` |
| `P-busy-purchase` | `_busy == true` (purchase in flight) | CTA spinner |
| `P-busy-close` | `_busy == true` (set inside `_close`'s alias await) | CTA spinner ~platform-channel duration |

No reported bug touches purchase-button states. Listed for completeness.

---

## 4 · Navigation states (router level)

| Route | Allowed predecessors | Allowed successors | Redirect rule (app_router.dart:96-159) |
| --- | --- | --- | --- |
| `/onboarding` | fresh install (after age-gate + consent) | `/prediction` (via redirect) when session exists | `if (isFirstTime ∧ ageVerified ∧ consentDecisionMade) return /onboarding` |
| `/age-gate` | fresh install before age confirm | `/consent` | `if (isFirstTime ∧ !ageVerified) return /age-gate` |
| `/consent` | after age-gate | `/onboarding` | `if (isFirstTime ∧ !consentDecisionMade) return /consent` |
| `/auth` | reachable post-onboarding when no session, or anon user navigating to "Üye Ol/Giriş Yap" | `/paywall` (via redirect when not-anon) · `/dashboard` (rare) | `if (path == /auth) return user.isAnonymous ? null : /paywall` |
| `/paywall` | post-onboarding · from AuthScreen's `_goToPaywall` · from PremiumGate prompts | `/dashboard` (via `_close` or after purchase success) | no path-specific redirect; passes through |
| `/dashboard` (`/`) | post-paywall · `context.go('/')` from many surfaces | any | `if (session == null) return /auth` |
| `/admin` | when authenticated AND `app_metadata.role == 'admin'` | / | `if (path == /admin ∧ !isAdmin) return /` |

Invalid transitions seen in the bug report:

- "Modal re-appears" — not a *route* transition; it's a M0→M4 cycle
  on a freshly-mounted `_PaywallScreenState`. The route-level
  navigation that drives the remount is **legitimate**: it's either
  `pushReplacement('/paywall')` from `_goToPaywall` or
  refreshListenable-driven redirect `/auth → /paywall`. Both are
  declarative; neither is a bug per se. The bug is the modal's
  predicate firing on a state where it should not.
- "Modal closes instead of navigating" (Flow B step 8) — this is
  consistent with `Navigator.pop(rootNavigator)` running on the
  modal route while the underlying `_PaywallScreenState` stayed in
  M5 (the OAuth-success branch doesn't redirect; it relies on the
  user already being on `/paywall`). If the second login attempt
  pops the modal but doesn't change the route stack, the user is
  stuck on the now-modal-less paywall.

---

## 5 · Race-condition points (catalogued)

| ID | Race | Trigger | Worst-case outcome | Mitigation in current code |
| --- | --- | --- | --- | --- |
| R1 | `signInWithPassword` event vs. `_submit`'s remaining awaits | refreshListenable can navigate `/auth → /paywall` while `_submit` is still awaiting `aliasRevenueCatWithCurrentUser` | `_goToPaywall`'s subsequent `pushReplacement` becomes a no-op (because AuthScreen.mounted=false) | `if (!mounted) return;` guard |
| R2 | `_goToPaywall` + refreshListenable both target `/paywall` | Two near-simultaneous attempts to replace the route | Could briefly stage two paywall pages; second mount runs gate predicate before Riverpod's dirty propagation lands | **No mitigation today** — see RCA §2a |
| R3 | Modal route on root navigator vs. GoRouter declarative pages list | Imperative modal sits outside GoRouter's `pages`; a declarative rebuild reconciles around it | Modal usually persists across rebuilds; could pop unexpectedly under future GoRouter version changes | Documented in code comment but not defensively coded |
| R4 | `currentUserProvider` cache vs. fresh PaywallScreen build | If StreamProvider hasn't propagated the latest event, dirty-mark race could let a fresh mount read a stale value briefly | Same as RCA §2a | None |
| R5 | `pushReplacement` from `_goToPaywall` when already on `/paywall` (refreshListenable already redirected) | `pushReplacement('/paywall')` from `/paywall` causes a second `_PaywallScreenState` mount | Second mount has fresh `_authGateShown=false`; gate re-evaluates on the post-auth user (which is fine, gate skipped — *unless* RCA §2a's read-lag is real) | None |
| R6 | `Purchases.appUserID` getter throws when SDK not configured | `aliasRevenueCatWithCurrentUser`'s short-circuit can't read; falls through to `logIn` which then fails | `aliasRevenueCatWithCurrentUser` returns `false`; logged warning; future purchase still works against anon RC id | Inner `try/catch` swallows it |
| R7 | `subscriptionProvider` cache vs. identity change | After reviewer signs in, `subscription.isPro` reflects the anonymous user (false) until offerings refetch | Dashboard premium gates would deny the reviewer except `isProProvider` OR's in `isReviewer` (Phase 139) — so currently OK | `isReviewerProvider` masks it |
| R8 | Email signup with confirmations OFF | `updateUser` flips `isAnonymous → false` and `email → x` atomically; this is a single `userUpdated` event but two visible fields change | Pre-Phase-139 `needsAuth = next.isAnonymous` happens to evaluate to false → gate skipped accidentally-correctly | n/a |

---

## 6 · The matrix that ties everything together

The gate predicate's correctness across all auth-state × confirm-email
settings × Phase 139 status:

|  | Confirm email ON | Confirm email OFF |
| --- | --- | --- |
| **`anon-pure` (no email yet)** · pre-139 | needsAuth = TRUE (anon) ✓ | needsAuth = TRUE (anon) ✓ |
| **`anon-pure`** · post-139 | needsAuth = TRUE (anon ∧ no email) ✓ | needsAuth = TRUE (same) ✓ |
| **`anon-linked-pending`** (updateUser, confirm pending) · pre-139 | **needsAuth = TRUE — BUG** ❌ | (state doesn't occur) |
| **`anon-linked-pending`** · post-139 | needsAuth = FALSE (newEmail.isNotEmpty) ✓ | (state doesn't occur) |
| **`registered`** (signin / OAuth) · pre-139 | needsAuth = FALSE ✓ | needsAuth = FALSE ✓ |
| **`registered`** · post-139 | needsAuth = FALSE ✓ | needsAuth = FALSE ✓ |
| **`registered + reviewer`** · pre-139 | needsAuth = FALSE ✓ — but `isProProvider` doesn't recognize them; dashboard treats as non-Pro | same |
| **`registered + reviewer`** · post-139 | needsAuth = FALSE ✓ + `isProProvider` = TRUE via `isReviewer` OR-gate ✓ | same |

The **one cell** that's BUG-RED with the committed (`main`) code:
`anon-linked-pending` × `Confirm email ON` × pre-139. This **fully
explains user-reported Flow A**. It does **not** explain user-reported
Flow B; Flow B's modal re-fire requires §2a (Riverpod read lag on a
double-mount) — which is unproven and needs on-device instrumentation
to confirm or refute.

---

## 7 · Recommended invariants (to enforce after the fix, not now)

Once the fix lands, these invariants should be added as light asserts
or analytics breadcrumbs:

- I-1. Within a single `_PaywallScreenState`, `_authGateShown` is
  monotonic: `false → true` only. (Already true today; document with
  an assertion in the setter.)
- I-2. `showAuthGate(context)` is called from exactly one site
  (`paywall_screen.dart:205`). A grep that fails this should fail CI.
- I-3. `aliasRevenueCatWithCurrentUser` is awaited before any
  `pushReplacement('/paywall')` from the auth screen. (Already true
  in `auth_screen.dart:_submit` — three call sites; document.)
- I-4. On every modal mount, the resolved `needsAuth` decision is
  logged with the snapshot of `(email, newEmail, isAnonymous,
  appMetadata.role)` so post-incident debugging doesn't depend on
  reasoning through Riverpod's evaluation order from memory.
- I-5. `subscriptionProvider` is invalidated on every identity
  transition where the Supabase user `id` actually changes (not on
  every `AuthChangeEvent`). This is decoupled from the gate bug but
  prevents the stale-snapshot class entirely.

---

## 8 · Summary — what's reliable vs. what isn't

**Reliable in the current code:**
- Single source of truth for auth: Supabase's `currentSession`.
- Single trigger for the modal: `paywall_screen.dart:205`.
- Single latch: `_authGateShown` (per `_PaywallScreenState`).
- Synchronous read of `auth.currentUser` always returns the latest.
- RC alias is awaited on every successful auth path before any
  paywall navigation (Phase 94 + 139's belt-and-braces).
- Modal pop on OAuth success is correctly scoped to the root navigator.
- Reviewer-Pro recognition is JWT-claim-based, not local-flag-based;
  cannot be self-promoted on a tampered client.

**Not reliable / unverified:**
- The "modal re-appears for the reviewer login" symptom does not
  derive from the current code under any analytic interleaving I can
  construct. The most likely explanation is either:
  (a) the on-device APK pre-dates Phase 139 (HIGH for Flow A, but
       partial for Flow B because Flow B doesn't hinge on Phase 139);
  (b) a Riverpod read-lag race during a double-mount (UNVERIFIED).
- Modal pop-after-OAuth-success doesn't have a redundant nav call;
  if the pop silently fails for any reason, the user is stuck.

**Action:** before any code is touched, the §2a logging instrumentation
in ROOT_CAUSE_ANALYSIS.md should be applied to a single throwaway
build, and a real-device repro should be captured. Without that, any
"fix" to Flow B is speculative.
