# ROOT_CAUSE_ANALYSIS — paywall · auth synchronization bugs

Companion to `AUTH_FLOW_TRACE.md`. Same investigation date 2026-05-17.
**Diagnosis only — no code changed.**

Confidence scale: **HIGH** (code + behavior contradict each other only
under this hypothesis) · **MEDIUM** (consistent with reports but other
explanations remain) · **LOW** (speculative, kept for completeness).

---

## §1 · Primary root cause — running a pre-Phase-139 APK

**Confidence: HIGH for Flow A.**

### Evidence

- `git log --all | grep -i 'phase 139\|reviewer\|hasLinkedEmail'` →
  no matches. Phase 139 exists in the working tree only.
  Last published commit is `dc813eb docs: craft production-grade
  project README` (no functional code change since `e3fb6ab` Phase 99
  on 2026-05-13).
- `git status` lists `auth_provider.dart`, `auth_screen.dart`,
  `paywall_screen.dart`, `monetization_provider.dart` as **modified**.
- Phase 139's logic is the **only** code path that prevents the
  modal from re-firing on the post-signup paywall remount when
  Supabase "Confirm email" is ON (the default for prod projects).
- Memory note `project_paywall_auth_gate_linked_email` documents the
  fix was applied during a previous session; the user's bug report
  describes the exact pre-fix symptom.
- Last release APK timestamp `app-arm64-v8a-release.apk` 2026-05-16
  17:11 — only 24h before this investigation, but **after** Phase 139
  was authored in the working tree. **However:** unless `flutter build`
  was run from the working tree on that machine after the Phase 139
  edits, the APK can still embed the pre-139 logic. If the test device
  has an APK installed BEFORE the working-tree edits, all three Phase
  139 surfaces are missing.

### Pre-139 prediction vs. user report

| Flow | Pre-139 behavior under "Confirm email" ON | User report | Match? |
| --- | --- | --- | --- |
| A — email signup | `updateUser` → user stays `isAnonymous=true` → fresh PaywallScreen → `needsAuth = next.isAnonymous = true` → modal re-fires | "Account modal appears AGAIN" | ✓ exact |
| A — email signup | `aliasRevenueCatWithCurrentUser` returns early because `isAnonymous && !hasLinkedEmail` (pre-139 doesn't have the linked-email branch — original guard was `user.isAnonymous`) → **RC alias never lands**, future purchase attributed to anonymous RC id | (not visible to user yet — would manifest on first real purchase) | (deferred) |
| B — reviewer login | `signInWithPassword` → user is **non-anonymous** → `needsAuth = false` → gate should be skipped | "Login modal appears again" | ✗ — pre-139 logic alone does NOT predict Flow B's bug |

**So §1 fully explains Flow A but NOT Flow B.** Flow B needs an
additional hypothesis (see §2).

### Quick verification step

Without changing code:

```bash
adb shell pm path com.emredogan.formaifit | head -1
# returns: package:/data/app/...
adb shell run-as com.emredogan.formaifit sh -c 'unzip -p base.apk \
   assets/flutter_assets/AssetManifest.json' \
   | grep -ic 'newEmail\|hasLinkedEmail'
```

Or simpler: open About → Build → check the timestamp; if older than
the working-tree mtime on `paywall_screen.dart` (currently
`stat -c %Y lib/.../paywall_screen.dart`), the APK is pre-Phase-139.

---

## §2 · Secondary root cause — Flow B's modal re-appearance

**Confidence: MEDIUM. Two compatible hypotheses; both need on-device
log instrumentation to discriminate.**

The current code path for Flow B (§3 of the trace) does NOT
analytically produce a re-fired modal: every plausible interleaving
of `_submit`'s awaits and `authRefreshListenable`'s redirect leaves
`_onAuthStateChanged` reading the reviewer user, with
`hasLinkedEmail=true` and `needsAuth=false`.

Three hypotheses survive scrutiny:

### §2a · `_PaywallScreenState` mounts twice and the gate fires on the second mount before `currentUserProvider` is re-evaluated

**Confidence: MEDIUM.**

Sequence:

```
1. AuthScreen._submit completes signInWithPassword.
2. notifyAllSubscribers(signedIn) — stream event scheduled (microtask).
3. _submit continues:
     await _persistWizardMetrics  (one microtask boundary)
     await aliasRevenueCatWithCurrentUser   (≥ one platform-channel
        round-trip — 100s of ms)
4. Meanwhile, authRefreshListenable's stream listener fires,
   notifies GoRouter, redirect runs for /auth → /paywall.
5. GoRouter navigates. PaywallScreen[#2a] mounts.
6. PaywallScreen[#2a].build → ref.read(currentUserProvider)
   → returns reviewer user (currentUser is synchronous, set before #2).
   → gate skipped ✓
7. _submit finally resumes: _goToPaywall → pushReplacement('/paywall').
   AuthScreen.mounted is false now → no-op.
```

Or the inverse order:

```
4'. _submit finishes before refresh fires.
5'. _goToPaywall → pushReplacement('/paywall').
    PaywallScreen[#2b] mounts. Gate skipped.
6'. Refresh fires later — redirect for /paywall returns null.
```

So in the **expected** case, exactly one PaywallScreen mounts.

The bug case I cannot rule out: if `_goToPaywall` runs **AND** the
GoRouter redirect runs **AND** the redirect creates a NEW route while
`_goToPaywall`'s `pushReplacement` is also reconciling, the navigator
may briefly stage TWO `/paywall` MaterialPages. The second's State is
constructed before `currentUserProvider`'s notify has propagated.

`auth.currentUser` is synchronous, so reading it returns the new
user regardless. But — and this is the speculative part — if Riverpod
delivers the `currentUserProvider` evaluation to the second mount
*before* the new authStateProvider state lands, the second
`_PaywallScreenState`'s synthetic initial `_onAuthStateChanged(null,
ref.read(currentUserProvider))` is run during a Flutter build where
the watch-graph hasn't yet propagated the dirty mark, and reads from
Riverpod's prior cache.

This is conjectural — I cannot reproduce it from the code alone — but
it's the only mechanism by which the gate could see a stale anonymous
user on a fresh mount.

**Mitigation (no code change yet):** add a logged trace inside
`_onAuthStateChanged`:

```dart
AppLogger.info(
  'paywall._onAuthStateChanged',
  category: 'auth',
  data: {
    'next_id': next?.id, 'next_email': next?.email,
    'next_newEmail': next?.newEmail, 'isAnon': next?.isAnonymous,
    'authStateProviderState':
        ref.read(authStateProvider).when(
          data: (s) => 'data:${s.event.name}',
          loading: () => 'loading',
          error: (e, _) => 'error:$e',
        ),
    'authCurrentUserId':
        Supabase.instance.client.auth.currentUser?.id,
  },
);
```

This would tell us, on a real device, exactly what
`_onAuthStateChanged` sees at the moment of decision. **Recommended
before any code fix is written.**

### §2b · Modal not actually popping after OAuth success in Path 3a

**Confidence: LOW–MEDIUM.**

`auth_modal_bottom_sheet.dart:451`:
```dart
case SocialAuthOutcome.success:
  Navigator.of(context, rootNavigator: true).pop();
```

This pops the modal route off the root navigator. The modal disappears
visually. But there's no fallback: if the `context` is somehow
deactivated (e.g., the OAuth flow took long enough that the modal's
`State` was already disposed by some other path), the `Navigator.of`
call would throw — but the surrounding code doesn't surface it.

The OAuth success branch does NOT also `context.go(somewhere)`. So if
the pop succeeds, the user lands on the still-alive PaywallScreen[#1]
with `_authGateShown=true`. Gate cannot re-fire on the same instance.

If, however, the user-reported "modal appears again" is the
*original* modal still visible (i.e., the pop didn't take effect),
then a second tap of the same button would trigger a second OAuth
attempt, RC alias would short-circuit (already aligned), and the
second pop succeeds. That matches Flow B step 8 ("modal closes
instead of navigating"): the modal closes but no nav fires because
the success branch only pops and relies on the user already being
on `/paywall`.

Caveat: I cannot find a code-level mechanism by which the first pop
silently fails. Possible but unproven.

### §2c · Pre-Phase-139 reviewer Pro display + modal interaction

**Confidence: LOW.**

If the APK is pre-Phase-139, `isReviewerProvider` doesn't exist and
the reviewer is not treated as Pro at the dashboard. But the gate
itself uses `currentUserProvider`, not `isProProvider`, so reviewer
recognition doesn't gate the modal one way or the other. This
hypothesis doesn't explain the modal re-firing for Flow B.

---

## §3 · "Why OAuth behaves differently" question from the user spec

The user's spec asks specifically about OAuth-vs-email divergence.
**There is no diverging behavior in the gate logic itself** — both
paths run through `_onAuthStateChanged` with the same predicate.

Where they differ:

| Aspect | OAuth (Google/Apple) | Email signup | Email signin |
| --- | --- | --- | --- |
| Code path | `auth_modal_bottom_sheet → _runOAuth → AuthController.signInWithGoogle` | `/auth → AuthScreen._submit (signUp branch, isAnon=true → updateUser)` | `/auth → AuthScreen._submit (signIn branch)` |
| Supabase event | `signedIn` (replaces session) | `userUpdated` (same UUID, email+password attached) | `signedIn` (replaces session) |
| Resulting `isAnonymous` | **false** | **true** (until verification, with Confirm email ON) | **false** |
| Resulting `email` | populated | empty (if Confirm email ON) | populated |
| Resulting `newEmail` | null | populated (if Confirm email ON) | null |
| Pre-Phase-139 `needsAuth` | false ✓ | **true** ❌ — bug | false ✓ |
| Post-Phase-139 `needsAuth` | false ✓ | false (via `hasLinkedEmail`) ✓ | false ✓ |
| RC alias before paywall remount | yes (inside controller) | yes (call in AuthScreen) | yes (call in AuthScreen) |
| Modal pop mechanism | `Navigator.pop(rootNavigator)` | `_goToPaywall` → `pushReplacement` causes route teardown | same |
| Stays on same `_PaywallScreenState` | yes (modal sits on top) | no — entirely new mount | no — entirely new mount |

The divergence the user is **really** asking about is "why does email
signup re-trigger the modal but Google doesn't?" — and the answer is:
because pre-Phase-139's `needsAuth` predicate hinges on
`next.isAnonymous`, and only the email-signup `updateUser` path leaves
the user `isAnonymous=true` after a "successful" auth.

---

## §4 · Reproduction recipe (intended — for verification only)

**Do NOT run these on production data until the fix is signed off.**

Use a Supabase project with "Confirm email" enabled (the prod default).

Flow A reproduction:

1. Fresh install of the candidate APK on a real device.
2. Complete onboarding → tap "Misafir Olarak Devam Et" if asked → land on paywall.
3. AuthGate modal opens.
4. Tap "E-posta ile Giriş Sayfasına Git" → AuthScreen.
5. Toggle to "Kayıt Ol", enter `repro+a@anthropic.com` + a password ≥ 6 chars.
6. Tap "KAYIT OL".
7. **Pre-Phase-139:** modal re-appears immediately on the new paywall
   mount (this trace).
   **Post-Phase-139:** paywall shows authenticated, modal absent.

Flow B reproduction (reviewer):

1. Same fresh install.
2. Complete onboarding through to paywall.
3. AuthGate modal.
4. Tap "E-posta ile Giriş Sayfasına Git" → AuthScreen.
5. In sign-in mode (default), enter `emre30283@gmail.com` + password.
6. Tap "GİRİŞ YAP".
7. Expected (any version): paywall mounts, modal absent, reviewer
   recognized as Pro on dashboard.
8. If modal re-appears: capture `adb logcat` for `[Purchases]` and any
   `AppLogger` lines from `auth` / `monetization` categories.

---

## §5 · Confidence-ranked candidates from the user's 20-item list

The user's spec listed 20 candidate root causes. Mapped to this
analysis:

| # | Candidate | Verdict |
| --- | --- | --- |
| 1 | stale Riverpod/provider auth snapshot | **MEDIUM** — possible for §2a |
| 2 | auth listener timing race | **MEDIUM** — §2a + R-B1 |
| 3 | onboarding-local auth cache | unrelated — onboarding finishes well before paywall |
| 4 | paywall mounted before auth hydration completes | **MEDIUM** — §2a (only if currentUserProvider lags) |
| 5 | modal state not invalidated after login | **LOW** — `_authGateShown` is per-State, not stored |
| 6 | duplicate auth-state sources | NOT present — sole source is Supabase, projected through one StreamProvider |
| 7 | async navigation race condition | **MEDIUM** — R-B1 documented |
| 8 | missing provider invalidation | **MEDIUM** — `subscriptionProvider` not invalidated on auth change (S-1) |
| 9 | stale BuildContext after pop/push | **LOW** — see §2b |
| 10 | auth listener not attached during onboarding | not the bug — onboarding doesn't gate auth |
| 11 | Supabase session hydration delay | unrelated — `signInWithPassword` is synchronous-w.r.t.-currentSession |
| 12 | local `isGuest` flag surviving after auth | **HIGH for Flow A pre-139** — `isAnonymous=true` IS the linger; that's exactly §1 |
| 13 | paywall state machine not reacting to auth changes | not the bug — `ref.listen` is wired |
| 14 | navigation stack corruption | **LOW** — see §2b |
| 15 | modal dismissal logic incorrectly coupled to auth status | NOT — modal pop is decoupled from auth state |
| 16 | auth-success callback not propagated upward | **LOW** — see §2b |
| 17 | delayed RevenueCat entitlement refresh | NOT the gate bug; relevant for entitlement display (S-1) |
| 18 | onboarding flow retaining stale anonymous state | **HIGH for Flow A pre-139** — same as #12, framed differently |
| 19 | listener disposal issue during navigation transitions | **LOW** — no leak signature found |
| 20 | paywall opening before auth refresh future resolves | **MEDIUM** — same as #4, §2a |

The single highest-impact fact is **#12 / #18: the linger of
`isAnonymous=true` after `updateUser` is the gate bug for Flow A**,
and the in-tree Phase 139 patch was authored specifically to fix it
but is **not yet on `main`**.

---

## §6 · Recommended fix sequence (NOT YET APPLIED — pending signoff)

Order matters; ship in the smallest unit that closes the regression.

**Step 1 — confirm Phase 139 IS what's on the test device.**
Either rebuild and reinstall, or `adb pull` the running APK and grep
its compiled flutter_assets / .so for the `hasLinkedEmail` symbol.
Without this confirmation, every subsequent code change is guessing
at a problem that may already be fixed.

**Step 2 — IF Phase 139 is on device and Flow A still reproduces:**
add the diagnostic logging in §2a, ship a single instrumented build,
capture one repro session with `adb logcat`. Decide on next step
only after reading the trace.

**Step 3 — IF Phase 139 is NOT on device:**
commit the Phase 139 work AS-IS (verbatim from the working tree —
do not edit it during commit), rebuild, retest. Expect Flow A to
disappear. Flow B remains to be investigated separately.

**Step 4 — Flow B remediation (only if it still reproduces after
Steps 1-3):**
the smallest, surgical fix is to make `_onAuthStateChanged` defer
its `showAuthGate` decision by one frame AND re-read the user from
the synchronous source on that frame:

```dart
// inside _onAuthStateChanged, after the latch check, BEFORE setting
// _authGateShown = true:
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!mounted) return;
  final settled = Supabase.instance.client.auth.currentUser;
  final hasLinkedEmail = (settled?.email ?? '').isNotEmpty
      || (settled?.newEmail ?? '').isNotEmpty;
  final needsAuth = settled == null
      || (settled.isAnonymous && !hasLinkedEmail);
  if (!needsAuth || _authGateShown) return;
  _authGateShown = true;
  showAuthGate(context);
});
```

This eliminates §2a regardless of whether `currentUserProvider` lags
in a fresh mount, because the post-frame callback reads from
Supabase's synchronous source directly. Cost: one frame of delay
before the gate appears (~16 ms), invisible to the user.

**Step 5 — invalidate `subscriptionProvider` on identity transitions
(decoupled correctness improvement):** wire `_AuthRefreshListenable`
to also invalidate `subscriptionProvider` when the user UUID actually
changes (not on every event). This makes the dashboard pick up the
reviewer's RC state quickly instead of relying on `isReviewerProvider`
to mask a stale snapshot. Optional but recommended.

**What NOT to do:**

- Do not add `Future.delayed(…)` calls to "let auth settle". §2a's
  post-frame callback is bounded and deterministic; a delay is not.
- Do not invalidate `currentUserProvider` manually. It is already
  reactive; manual invalidation would just race with the stream.
- Do not move `showAuthGate` to a global service. It's correctly
  scoped to the paywall; the bug is in the *predicate*, not the
  trigger location.
- Do not change `Navigator.pop(rootNavigator: true)` to a different
  pop strategy without first confirming the modal pop is actually
  failing (§2b is unproven).
