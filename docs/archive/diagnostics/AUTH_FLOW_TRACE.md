# AUTH_FLOW_TRACE — paywall · auth · entitlement state propagation

Status: **diagnostic artifact only — no code changed**. Investigation date
2026-05-17. APK most recently rebuilt 2026-05-16 17:11. Phase 139 reviewer
+ linked-email work is in the working tree but **uncommitted** at this
date (no `feat(...): phase 139` commit exists). See
ROOT_CAUSE_ANALYSIS §1.

This trace describes the code as it exists in the working tree. The
installed APK on the test device may diverge if the build pre-dates a
working-tree edit. **Verify which APK is on-device before reproducing.**

---

## 0 · State sources (every source of "is the user logged in / Pro")

| Source | File · line | Surface | Caching |
| --- | --- | --- | --- |
| `Supabase.instance.client.auth.currentSession` | gotrue 2.20 `currentSession` | Synchronous truth · persisted in Hive | In-memory until Supabase mutates |
| `Supabase.instance.client.auth.currentUser` | gotrue 2.20 — derived from `currentSession.user` | Synchronous truth | In-memory |
| `authStateProvider` (Riverpod StreamProvider) | `lib/features/auth/providers/auth_provider.dart:26` | `AsyncValue<AuthState>` — wraps `onAuthStateChange` | Riverpod default |
| `currentUserProvider` (Riverpod Provider) | `auth_provider.dart:32` | `User?` — `ref.watch(authStateProvider)` then `auth.currentUser` | Re-evaluates on stream emit |
| `isAdminProvider` | `auth_provider.dart:48` | `bool` from `app_metadata.role == 'admin'` | Derived |
| `isReviewerProvider` (Phase 139, **uncommitted**) | `auth_provider.dart:69` | `bool` from `app_metadata.role == 'reviewer'` | Derived |
| `authRefreshListenableProvider` | `auth_provider.dart:79` | `Listenable` fed to `GoRouter.refreshListenable` | Listens stream |
| `subscriptionProvider` (AsyncNotifier) | `lib/features/monetization/providers/monetization_provider.dart:182` | `AsyncValue<SubscriptionState>` (RC entitlement + offerings) | **Not invalidated on sign-in** — see RCA §6 |
| `isProProvider` | `monetization_provider.dart:193` | `bool` — `subscription.isPro \|\| devOverride \|\| isReviewer` | Derived |
| `prefs.isFirstTime`, `prefs.ageVerified`, `prefs.consentDecisionMade` | `app_preferences.dart` | Onboarding gating in router redirect | SharedPreferences |
| `_PaywallScreenState._authGateShown` | `paywall_screen.dart:46` | Per-instance latch | **Resets on every fresh PaywallScreen** |
| Modal route on root navigator | imperative push in `showAuthGate` | Not in GoRouter's declarative `pages` list | Lives until `Navigator.pop` |

---

## 1 · Trigger surface — who opens the AuthGate modal?

`showAuthGate(context)` is called from exactly one place:

```
paywall_screen.dart:205   showAuthGate(context);
```

invoked from `_onAuthStateChanged` (paywall_screen.dart:183-207) via:

1. `ref.listen<User?>(currentUserProvider, _onAuthStateChanged)` — fires
   on every transition where the previous `User?` ≠ next `User?`
   (Riverpod uses `User.operator==`).
2. A synthetic synchronous first-pass call `_onAuthStateChanged(null,
   ref.read(currentUserProvider))` on every paywall `build()` to
   compensate for Riverpod 3.x removing `fireImmediately` from
   `ref.listen`.

The `_authGateShown` boolean is the only deduplication mechanism. It is
**never reset** — once `true`, stays `true` until the `_PaywallScreenState`
is disposed.

**Therefore: the gate fires ≤ 1 time per PaywallScreen lifetime. Any
"modal re-appearance" implies a new PaywallScreen instance was mounted.**

---

## 2 · Flow A — email signup from paywall (current code in tree)

Pre-condition: `signInAnonymously` session live, paywall is the next
route after onboarding.

```
T0   PaywallScreen[#1] mounted
        initState → _refreshSdkReady (RC isConfigured probe)
        build runs
          ref.listen<User?>(currentUserProvider, _onAuthStateChanged)
          _onAuthStateChanged(null, ref.read(currentUserProvider))
            next = anon user (email=null, newEmail=null, isAnonymous=true)
            hasLinkedEmail = false ∧ isAnonymous → needsAuth=true
            _authGateShown = true
            addPostFrameCallback → showAuthGate(context)
T1   PostFrame
        Navigator.of(context, rootNavigator:true).push(modalRoute)
        AuthGate visible on top of PaywallScreen[#1]

T2   User taps "E-posta ile Giriş Sayfasına Git"
        _onEmailLoginPressed:
          Navigator.of(context, rootNavigator:true).pop()
          context.go(AppRoutes.auth)                           ← (a)
T3   GoRouter rebuilds — declarative pages list becomes [/auth]
        Navigator reconciles: pops the (already-popping) modal,
        replaces /paywall with /auth.
        PaywallScreen[#1] disposed.
        AuthScreen mounts.

T4   User toggles _Mode.signIn → _Mode.signUp, types email+password,
        taps "KAYIT OL".
        _submit runs:
          currentUser = anon, isAnon=true
          await _client.auth.updateUser(
            UserAttributes(email, password))
            → server PUT /auth/v1/user
            → response.user has:
                  with confirm-email ON:  email=null, new_email=x,
                                          is_anonymous=true
                  with confirm-email OFF: email=x,    new_email=null,
                                          is_anonymous=false
            → gotrue._saveSession sets _currentSession.user = response.user
            → gotrue.notifyAllSubscribers(AuthChangeEvent.userUpdated)
          await _persistWizardMetrics()
          await aliasRevenueCatWithCurrentUser()
            • configureRevenueCat (idempotent)
            • user = auth.currentUser  (now linked-email-anon OR non-anon)
            • hasLinkedEmail = true → not skipped
            • Purchases.logIn(user.id) → RC aliased ✓
          _toast("E-posta adresine doğrulama bağlantısı gönderildi…")
          _goToPaywall() → context.pushReplacement(AppRoutes.paywall)  ← (b)

T5   GoRouter reconciles to [/paywall].
        AuthScreen disposed.
        PaywallScreen[#2] mounts — **fresh State** — _authGateShown=false.
        build runs.
        _onAuthStateChanged(null, ref.read(currentUserProvider))
          next = post-updateUser user.

   Confirm-email ON branch (Supabase default):
          next.email='' or null, next.newEmail='x@…', isAnonymous=true
          hasLinkedEmail = '' || 'x' = TRUE        ← Phase 139 catches this
          needsAuth = false. Gate skipped. ✓

   Confirm-email OFF branch:
          next.email='x@…', next.newEmail=null, isAnonymous=false
          hasLinkedEmail = TRUE
          needsAuth = false. Gate skipped. ✓
```

### The pre-Phase-139 trace (committed code on `main`)

If the on-device APK was built from `main` rather than the working
tree, `_onAuthStateChanged` is:

```dart
final needsAuth = next == null || next.isAnonymous;   // no email check
```

Confirm-email ON path then fails:
```
T5'  next.isAnonymous=true → needsAuth=TRUE → gate fires AGAIN
```

This is the exact symptom in user-report Flow A step 7 ("modal appears
AGAIN"). Confidence **HIGH** that the user is on a pre-Phase-139 build.

### Race conditions noted (current code)

R-A1 — `authRefreshListenableProvider` fires GoRouter `redirect` for
`/auth` during `updateUser`'s `userUpdated` stream emit:

```
redirect rule (app_router.dart:145):
  if (path == '/auth') return user.isAnonymous ? null : AppRoutes.paywall;
```

For confirm-email ON: `isAnonymous` stays true → no redirect.
For confirm-email OFF: `isAnonymous` flips to false → redirect to
`/paywall` fires *while `_submit` is mid-`await`*. AuthScreen unmounts.
`_goToPaywall`'s `if (!mounted) return;` no-ops. Result is still
PaywallScreen[#2] mounted with the post-updateUser user. **Single
mount, gate skipped.** Not the bug.

R-A2 — The toast `_toast(…)` is fired-and-forgotten via
`ScaffoldMessenger`. AuthScreen unmounts a frame later when
`pushReplacement` reconciles. `ScaffoldMessenger.maybeOf` on the
**dashboard scaffold** receives the SnackBar; the user sees the
"doğrulama bağlantısı gönderildi" toast briefly on the paywall — UX
nit, not the reported bug.

---

## 3 · Flow B — reviewer (existing Pro) login from paywall

Pre-condition: `signInAnonymously` session live, paywall is the next
route after onboarding.

Path 3a · Google or Apple from the modal:

```
T0   PaywallScreen[#1] mounted, anon user → gate fires, modal opens.
T1   User taps "Continue with Google".
        _onGooglePressed → _runOAuth(google, …)
          signInWithGoogle:
            GoogleSignIn.authenticate → idToken
            Supabase.auth.signInWithIdToken(provider: google, idToken,…)
              → Supabase REPLACES the anonymous session with the reviewer
                 session. _currentSession.user becomes:
                    id='bf874641-…', email='emre30283@gmail.com',
                    isAnonymous=false, app_metadata={'role':'reviewer',…}
              → notifyAllSubscribers(signedIn) ← single event, no
                 intermediate signedOut.
            aliasRevenueCatWithCurrentUser:
              • Purchases.logIn(reviewer.id)
              • RC LOGS show: 👤 Logging in from $RCAnonymousID:c2b9a8e2…
                → bf874641-… ✓     (logs.txt:396)
          result.outcome = success
        Modal handler: Navigator.pop(rootNavigator).
T2   PaywallScreen[#1] still alive — gate-modal route is the ONLY thing
        that popped. _authGateShown stays true.
        ref.listen<User?>(…) fires with (anon → reviewer).
        _onAuthStateChanged short-circuits at `if (_authGateShown) return;`.
        ✓ No re-fire.

T3   authRefreshListenableProvider notifies GoRouter.
        Redirect runs for current path `/paywall`:
          – path != /referral, /auth, /onboarding, /admin
          – session != null
          – returns null
        ✓ No redirect, no rebuild.
```

This path should land the user on `/paywall`, authenticated, with the
modal gone. **The user's report says modal re-appears.** Under the
current code I cannot derive that outcome. See RCA §2 for what *can*
remount PaywallScreen.

Path 3b · "E-posta ile Giriş Sayfasına Git" → /auth → signInWithPassword:

```
T0-1  same as Path 3a up to "user taps email-login link"
T2    _onEmailLoginPressed:
        Navigator.pop(rootNavigator)
        context.go('/auth')
T3    GoRouter pages: [/auth].  PaywallScreen[#1] disposed.
T4    AuthScreen mounts in _Mode.signIn (default).
T5    User types reviewer creds, taps "GİRİŞ YAP".
        _submit:
          await signInWithPassword(email, password)
            → server POST /token  →  reviewer session
            → _saveSession + notifyAllSubscribers(signedIn)
          await _persistWizardMetrics
          await aliasRevenueCatWithCurrentUser    (RC alias to reviewer)
          _goToPaywall → context.pushReplacement('/paywall')

T6    PaywallScreen[#2] mounts (fresh _authGateShown=false).
        _onAuthStateChanged(null, ref.read(currentUserProvider))
          next = reviewer:
              email='emre30283@gmail.com', isAnonymous=false
          hasLinkedEmail = true → needsAuth=false → gate SKIPPED. ✓
```

Race conditions noted:

R-B1 — GoRouter redirect race. After signInWithPassword's `signedIn`
event, the refresh listenable fires. Redirect for `/auth`:
```
if (path == '/auth') return user.isAnonymous ? null : AppRoutes.paywall;
```
The reviewer is **non-anonymous** → router navigates `/auth` → `/paywall`
*while `_submit` is still awaiting `aliasRevenueCatWithCurrentUser`*.

Two interleaving orders are possible:

| Order | Outcome |
| --- | --- |
| Router-redirect first → PaywallScreen[#2] mounts (gate skipped). Then `_submit` resumes, `_goToPaywall`'s `if (!mounted) return;` no-ops (AuthScreen was disposed). | Clean single mount. ✓ |
| `_submit` finishes first → `pushReplacement('/paywall')` from /auth → PaywallScreen[#2]. Refresh fires later, redirect for `/paywall` returns null. | Clean single mount. ✓ |

In **both orderings the gate sees the reviewer user and is skipped**.

R-B2 — Provider re-evaluation. `signInWithPassword` emits ONLY
`AuthChangeEvent.signedIn`, never an intermediate `signedOut` (gotrue
2.20 `signInWithPassword` body, line 318-322). So `currentUser` never
goes null in the transition. `currentUserProvider` recomputes once and
the new paywall reads the reviewer user.

R-B3 — `subscriptionProvider` NOT invalidated on auth change. After
reviewer sign-in, `subscriptionProvider` still holds the anonymous
RC snapshot (no entitlement). However `isProProvider` ORs in
`isReviewerProvider`, so reviewer = Pro on the dashboard regardless.
This **does not** affect the modal gate logic — but it explains the
user-reported step 11 ("user is ACTUALLY authenticated + Pro") at the
dashboard despite the paywall having looked broken.

---

## 4 · Flow C — purchase / close transitions (for completeness)

`_close` (paywall_screen.dart:690-712) on `_CloseButton.onTap`,
`PurchaseOutcome.success`, `_restored`, `_unlockAsDeveloper`:

```
read currentUser
if user != null:
  setState busy=true
  aliasRevenueCatWithCurrentUser  (no-op if already aliased)
  setState busy=false
context.go('/')                  ← dashboard
```

Router redirect for `/`:
- session non-null → user.isAnonymous OK, fall through
- returns null → dashboard mounts.

No code path on the close button reopens the modal. The "user manually
closes paywall with X → dashboard opens correctly" sequence in user-
report Flow B step 9 is consistent with this code.

---

## 5 · Stale-state locations (where caches outlive identity changes)

S-1 — `subscriptionProvider`: holds the anonymous user's RC state after
a real sign-in. Mitigated by `isProProvider` OR-ing in `isReviewer`.
**Not** the gate bug, but worth invalidating on identity change for
correctness (and so a real customer's entitlement reloads instantly
on sign-in).

S-2 — `_authGateShown` on a stale `_PaywallScreenState`: cannot be hit
in normal flows because `_PaywallScreenState` is disposed when the
route is replaced. Worth noting only as a structural risk if the
paywall is ever swapped from `builder:` to `pageBuilder:` with a
preserved key.

S-3 — `_revenueCatConfigured` (monetization_provider.dart:222) — global
guard, persists across sign-ins. Intentional: RC SDK is configured
once per process lifetime. The `Purchases.logIn` call inside
`aliasRevenueCatWithCurrentUser` retargets the app-user-ID without
reconfiguring. No bug here.

S-4 — `prefs.isFirstTime`: locked to false after the wizard completes;
the redirect rule then permits the user to reach `/paywall` regardless
of auth state. This is what allows the anonymous → paywall pathway
that the AuthGate exists to protect.

---

## 6 · Provider/widget relationship diagram (text)

```
                onAuthStateChange (Supabase)
                          │
                ┌─────────┴─────────┐
                ▼                   ▼
   authStateProvider          authRefreshListenableProvider
   (StreamProvider)           (Listenable → notifyListeners on event)
        │                            │
        ▼                            ▼
   currentUserProvider        GoRouter.refreshListenable
   (Provider<User?>)               → re-evaluates redirect
        │                            │
        ├─→ isAdminProvider          ▼
        ├─→ isReviewerProvider   /auth ↔ /paywall ↔ /dashboard
        │   (Phase 139, uncommitted)
        │
        └─→ PaywallScreen.build()
              · ref.listen → _onAuthStateChanged   (transitions)
              · _onAuthStateChanged(null, ref.read(…))   (synthetic init)

   subscriptionProvider (AsyncNotifier) — not wired to auth changes
        │
        └─→ isProProvider
              = subscription.isPro ∨ devOverride ∨ isReviewer
```

---

## 7 · Open questions to resolve before any fix

Q-1. **Which APK is on the test device?** Build timestamp and a grep
   for `'hasLinkedEmail'` in the installed binary's Flutter assets, or a
   fresh build from the working tree, would confirm. (Hypothesis:
   user is on a pre-Phase-139 build → §2's pre-139 trace is the bug.)

Q-2. **Is Supabase "Confirm email" enabled in the project?** Toggles
   which branch of §2 / T5 fires.

Q-3. **For Flow B, did the user use the Google modal button or the
   email-login-link path?** Step 3 of the user report says "user taps
   login" — ambiguous. Path 3a (Google/Apple) is a different code path
   than 3b (email page).

Q-4. **For Flow B step 8 ("modal closes instead of navigating"):** Is
   the user describing the second login attempt where the email path
   pops the modal but the underlying paywall stays? This is consistent
   with the modal-popped-but-paywall-untouched behavior of Path 3a
   when `_authGateShown` was set from the FIRST gate fire and the
   second attempt is the same `_PaywallScreenState`.

Q-5. **Is there an instrumented log that captures the exact sequence
   on the test device?** The captured `logs.txt` only shows RC events
   (alias completed, line 396) — there are no Supabase auth events or
   Riverpod state transitions logged.
