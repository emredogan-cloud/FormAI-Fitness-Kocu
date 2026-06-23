import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/routing/app_router.dart';
import 'core/services/analytics_service.dart';
import 'core/services/app_preferences.dart';
import 'core/services/consent_state.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/live_activity_service.dart';
import 'core/services/smart_reminder_scheduler.dart';
import 'core/services/widget_sync_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/audio_feedback.dart';
import 'l10n/app_localizations.dart';

/// Phase 94 · release-build resilience.
///
/// The Phase 92 `.aab` shipped to Internal Testing booted to a permanent
/// black screen on real devices. Root cause was a chain of three
/// vanish-in-release patterns:
///
///   1. No `FlutterError.onError` / `PlatformDispatcher.onError` /
///      `runZonedGuarded` outer handlers, so any uncaught bootstrap
///      error renders a silent black screen in release (debug prints to
///      the console, masking the issue locally).
///   2. `SentryFlutter.init` wrapped `runApp` via `appRunner` with no
///      try/catch around the init call itself — any throw from the
///      options builder, DSN parse, or native channel handshake
///      meant `runApp` was never reached.
///   3. `dotenv.env[k]` throws `NotInitializedError` (verified at
///      `media_url.dart:110`) when `dotenv.load()` failed silently.
///      `?? ''` does not catch a synchronous throw, so a missing /
///      malformed `.env` cascaded straight into Sentry's options
///      builder and killed bootstrap before `_BootGate` ever mounted.
///
/// The body below installs the missing safety net once, at the top of
/// the bootstrap, and guarantees `runApp(_BootGate(...))` is reached
/// exactly once even when every dependency below it is broken.
Future<void> main() async {
  // `runZonedGuarded` catches *async* errors that escape the framework
  // (futures with no awaiter, microtasks, isolate-spawned errors). The
  // FlutterError.onError + PlatformDispatcher.onError handlers cover
  // sync framework + platform errors. Together they surface every
  // class of uncaught error to Sentry instead of a silent black frame.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Hooked BEFORE any other framework call so an early throw
    // (orientation lock, dotenv, SystemChrome) is captured rather
    // than swallowed by a Flutter framework default handler that
    // silently no-ops in release.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _captureSafe(details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _captureSafe(error, stack);
      return true;
    };
    // ErrorWidget.builder defaults to a red box in debug and an
    // opaque grey box in release — the grey box is the symptom users
    // describe as "the screen turned black". Replace with a branded
    // splash so a downstream widget-build crash degrades to a
    // recognisable surface instead.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      _captureSafe(details.exception, details.stack);
      return const _BootSplash();
    };

    // Portrait lock — Redmi Note 11R (and similar low-end Androids)
    // started freezing on landscape rotation during workouts because
    // the ML Kit pose detector re-allocates tensors on every resize.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Phase 94 · `.env` bundling state is now a first-class signal,
    // not a swallowed exception. The flag rides into `_BootGate` so
    // the error screen can distinguish "couldn't reach Supabase"
    // (network) from "ship-time misconfiguration" (asset missing).
    var dotenvLoaded = false;
    try {
      await dotenv.load(fileName: '.env');
      dotenvLoaded = true;
    } catch (e, st) {
      debugPrint('[BOOT] dotenv.load failed: $e');
      debugPrintStack(stackTrace: st);
    }

    // Phase 94 · the previous build wrapped `runApp` inside
    // `SentryFlutter.init`'s `appRunner` with no try/catch around
    // init itself. If init threw — a malformed DSN, a native
    // platform-channel timeout, anything raised inside the options
    // builder via `dotenv.env[]` — `runApp` was never reached and
    // the user saw a permanent black frame. We now ALWAYS call
    // `runApp` even when Sentry init fails, and we never let the
    // options builder throw because every env-var read is wrapped
    // in `_envSafe`.
    var bootedViaSentry = false;
    try {
      await SentryFlutter.init(
        (options) {
          options.dsn = _envSafe('SENTRY_DSN');
          options.tracesSampleRate = 0.2;
          options.environment = kReleaseMode ? 'prod' : 'dev';
          // PII scrubber — Sentry attaches the device IP and a User
          // slot by default; we clear the email / ipAddress / data
          // fields before the event leaves the device.
          options.beforeSend = (event, hint) {
            // Phase 138 · H-2 KVKK consent gate. Until the user
            // explicitly opts into crash reporting on the consent
            // screen, every event is dropped on the device side —
            // nothing leaves the handset. The SDK still initialises
            // so the moment the user opts in, subsequent events
            // start flowing without needing a restart.
            if (!ConsentState.crashReportingGranted) return null;
            final user = event.user;
            if (user != null) {
              user.ipAddress = null;
              user.email = null;
              user.data = null;
            }
            return event;
          };
        },
        appRunner: () {
          bootedViaSentry = true;
          runApp(_BootGate(dotenvLoaded: dotenvLoaded));
        },
      );
    } catch (e, st) {
      debugPrint('[BOOT] SentryFlutter.init failed: $e');
      debugPrintStack(stackTrace: st);
    }
    // If Sentry init threw (or its appRunner was never invoked) we
    // still owe the user a screen. This is the line that turns a
    // black screen into the retry / error UI.
    if (!bootedViaSentry) {
      runApp(_BootGate(dotenvLoaded: dotenvLoaded));
    }
  }, (error, stack) {
    // Last-line defense: any zone-escaping async error lands here.
    debugPrint('[BOOT] uncaught zone error: $error');
    debugPrintStack(stackTrace: stack);
    _captureSafe(error, stack);
  });
}

/// Reads a key from `dotenv.env` without ever throwing, even when
/// `dotenv.load()` was never run successfully (which raises
/// `NotInitializedError` on the first env access). Returns an empty
/// string for missing or malformed values; callers that care about
/// "was this configured at all" should use [_BootGate]'s
/// `dotenvLoaded` signal, not the value of an individual key.
String _envSafe(String key) {
  try {
    return dotenv.env[key] ?? '';
  } catch (_) {
    return '';
  }
}

/// Sentry capture wrapper that never re-throws — the global error
/// handlers must be infallible, otherwise an exception from the
/// handler itself would re-trigger the same handler and we'd loop.
void _captureSafe(Object error, StackTrace? stack) {
  try {
    Sentry.captureException(error, stackTrace: stack);
  } catch (_) {
    // Swallow — we already printed via `debugPrint`. Sentry being
    // down (no DSN, native channel dead) must never escalate into a
    // crash of our own crash handler.
  }
}

const Color _kNeon = Color(0xFF00F0FF);

// Splashes the FormAI wordmark immediately, then hands off to the real app
// once .env + Supabase + SharedPreferences are ready. Running the three
// bootstraps off the first-frame critical path is what kills the 3–5s black
// screen users were seeing at login time. Phase 6 added retry-on-failure
// so offline launches no longer lock users on a splash forever.
class _BootGate extends StatefulWidget {
  const _BootGate({this.dotenvLoaded = true});

  /// Whether `dotenv.load(.env)` succeeded in `main()`. False means the
  /// asset was missing or unparseable; every env read will return empty
  /// and downstream services (Supabase, RevenueCat, Sentry, PostHog)
  /// will run in fallback mode. The gate uses this to short-circuit
  /// straight to a configuration-error screen instead of attempting
  /// Supabase.initialize with empty credentials, which would either
  /// throw or hang.
  final bool dotenvLoaded;

  @override
  State<_BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<_BootGate> {
  // Supabase.initialize throws "already initialized" if called a second time.
  // The gate stays alive across retries, so we track completion locally and
  // skip re-init on subsequent attempts (dotenv + SharedPreferences are both
  // idempotent, so those re-run safely).
  bool _supabaseInitialized = false;
  late Future<SharedPreferences> _bootstrap;

  @override
  void initState() {
    super.initState();
    _bootstrap = _init();
  }

  void _retry() {
    setState(() {
      _bootstrap = _init();
    });
  }

  Future<SharedPreferences> _init() async {
    try {
      // Phase 94 · short-circuit on missing `.env`. Reaching
      // `Supabase.initialize(url: '', anonKey: '')` either throws a
      // synchronous AssertionError ("URL must not be empty") or, on
      // some plugin versions, waits forever for the platform channel
      // to confirm a malformed URL — both look like a black screen
      // to the user. Throwing a clearly-tagged error here lets the
      // FutureBuilder render `_BootErrorScreen` with an actionable
      // message instead.
      if (!widget.dotenvLoaded) {
        throw const _MissingConfigurationError();
      }
      final supabaseUrl = _envSafe('SUPABASE_URL');
      final supabaseKey = _envSafe('SUPABASE_ANON_KEY');
      if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
        throw const _MissingConfigurationError();
      }

      // dotenv already loaded in `main()` before Sentry.init, so we only
      // cross the SharedPreferences platform channel here.
      final prefs = await SharedPreferences.getInstance();

      // Phase 138 · H-2. Mirror persisted consent grants into the
      // top-level `ConsentState` singleton so the Sentry beforeSend
      // hook (which runs outside the Riverpod scope) and the
      // PostHog init below pick up the user's prior decision before
      // any event has a chance to fire. First-launch installs land
      // here with all three flags false — exactly what KVKK demands.
      final appPrefs = AppPreferences(prefs);
      ConsentState.apply(
        decided: appPrefs.consentDecisionMade,
        analytics: appPrefs.analyticsConsentGranted,
        crash: appPrefs.crashReportingConsentGranted,
      );

      // Progress Phase 1.A · weekly Monday refill of streak-freeze
      // shields. Fire-and-forget + try/catch so a bad clock or a wedged
      // disk write can't take down the bootstrap (Phase 94 contract).
      // The check is idempotent — calling it on a non-Monday or
      // multiple times the same Monday is a no-op after the first run.
      try {
        await AppPreferences(prefs).refillFreezeTokensIfDue();
      } catch (_) {
        // Refill is purely additive UX polish; failure is acceptable.
      }

      if (!_supabaseInitialized) {
        // Phase 94 · 8-second timeout. Supabase's auth refresh
        // round-trip can wedge on a captive WiFi (TCP connects but
        // the response never arrives), and without the timeout the
        // splash sat there until the OS killed the app. The timeout
        // surfaces the failure as a TimeoutException → caught below
        // → retry screen rather than a black screen.
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
        ).timeout(const Duration(seconds: 8));
        _supabaseInitialized = true;

        // Phase 88 · defensive guest recovery.
        //
        // The router's auth gate accepts any non-null `currentSession`,
        // but if Supabase has fully discarded an anonymous user's
        // session (e.g. refresh token expired beyond the 30-day default,
        // or the disk cache was wiped) the user would otherwise land
        // on /auth and lose all in-app affordances. We persist a
        // `auth.was_anonymous` flag whenever auth state moves through
        // an anonymous identity; on cold start, if no session exists
        // but the flag was set, we silently re-create an anonymous
        // user so the redirect doesn't evict them.
        //
        // Trade-off: the recovered anonymous user has a NEW user_id —
        // any user_progress / favorites / feedback rows from the prior
        // anon identity are RLS-locked away. That's an acceptable loss
        // for an identity that, by definition, was already disposable;
        // the alternative (forcing /auth) is worse for retention.
        Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
          final user = authState.session?.user;
          // signedOut → preserve the last-known flag so a subsequent
          // cold start can still trigger the recovery path.
          if (user == null) return;
          unawaited(prefs.setBool('auth.was_anonymous', user.isAnonymous));
        });

        if (Supabase.instance.client.auth.currentSession == null &&
            prefs.getBool('auth.was_anonymous') == true) {
          try {
            await Supabase.instance.client.auth.signInAnonymously();
            AppLogger.info(
              'auth: anon recovery succeeded',
              category: 'auth',
            );
          } catch (e, st) {
            AppLogger.warning(
              'auth: anon recovery failed; falling through to /auth',
              category: 'auth',
              data: {'error': e.toString(), 'stack': st.toString()},
            );
          }
        }
      }

      // Phase 42 · PostHog analytics. Awaited so the first analytics
      // event (typically `paywall_viewed` on auto-prompt, or
      // `onboarding_step_completed` on welcome) actually lands — the
      // `setup()` call in posthog_flutter buffers until done.
      //
      // Phase 94 · 5-second timeout + null-safe await. PostHog's
      // native `setup` has been observed to hang on cold-start in
      // release builds when the device has no DNS (airplane mode,
      // captive WiFi pre-auth) — the SDK queues the init request
      // against an internal worker thread that never resolves, the
      // splash never lifts, and the user sees a black screen. The
      // timeout downgrades that hang to a logged warning and lets
      // the rest of bootstrap finish.
      final posthogHost = _envSafe('POSTHOG_HOST');
      await AnalyticsService.instance
          .init(
        apiKey: _envSafe('POSTHOG_API_KEY'),
        host: posthogHost.isEmpty ? 'https://app.posthog.com' : posthogHost,
      )
          .timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          AppLogger.warning(
            'PostHog init timed out — analytics disabled',
            category: 'analytics',
          );
        },
      );

      // Phase 48 · RevenueCat configuration deferred. Was an `await
      // configureRevenueCat()` here on every cold start, blocking the
      // splash for the platform-channel handshake even on users who
      // never reach the paywall. Now it's lazily kicked off from
      // `OnboardingScreen._finish()` (post-wizard) and from
      // `AuthController.signIn{Google,Apple}()` (post-sign-in), so the
      // SDK only spins up for users who are actually heading toward
      // the paywall surface.

      // Phase 55 · widget bridge. Initialises the App Group on iOS so
      // a follow-up `HomeWidget.saveWidgetData` lands in the right
      // suite. Both calls fire-and-forget — a missing entitlement
      // (e.g. the user is running an old build before the widget
      // extension is added in Xcode) just means the widget won't
      // refresh until the configuration is in place.
      unawaited(WidgetSyncService.instance.init());
      unawaited(WorkoutLiveActivityService.instance.init());

      // Coverage-pass closure (audit §8 Tier-A item 9) · eager TTS
      // warm-up. Constructs a throwaway AudioFeedback and fires init()
      // fire-and-forget so the platform-side TTS engine
      // (language enumeration, iOS audio category, etc.) is ready
      // by the time the camera screen mounts its own instance.
      // Without this, the first speak() on a cold launch races
      // against language enumeration and can stutter or be silent.
      unawaited(AudioFeedback().init());
      return prefs;
    } catch (e, st) {
      AppLogger.error(
        'BootGate init failed',
        e,
        stackTrace: st,
        category: 'boot',
      );
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Phase 94 · differentiate "device offline / Supabase down"
          // from "ship-time misconfiguration". The latter cannot be
          // recovered by tapping retry — it needs a new build — so
          // we surface a distinct message instead of leading the
          // user into an infinite "TEKRAR DENE" loop.
          final isConfigError = snapshot.error is _MissingConfigurationError;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _BootErrorScreen(
              onRetry: _retry,
              isConfigError: isConfigError,
            ),
          );
        }
        if (!snapshot.hasData) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _BootSplash(),
          );
        }
        return ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(snapshot.data!),
          ],
          child: const FormAIApp(),
        );
      },
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Text(
          'FormAI',
          style: TextStyle(
            color: _kNeon,
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            shadows: [Shadow(blurRadius: 24, color: _kNeon)],
          ),
        ),
      ),
    );
  }
}

/// Phase 94 · sentinel error type that lets the FutureBuilder
/// distinguish a config / build-time failure from a network /
/// transient failure when picking the error-screen copy.
class _MissingConfigurationError implements Exception {
  const _MissingConfigurationError();
  @override
  String toString() =>
      '_MissingConfigurationError: .env missing or required keys empty.';
}

class _BootErrorScreen extends StatefulWidget {
  const _BootErrorScreen({
    required this.onRetry,
    this.isConfigError = false,
  });
  final VoidCallback onRetry;
  final bool isConfigError;

  @override
  State<_BootErrorScreen> createState() => _BootErrorScreenState();
}

class _BootErrorScreenState extends State<_BootErrorScreen> {
  bool _retrying = false;

  Future<void> _onRetryPressed() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    final isConfig = widget.isConfigError;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kNeon.withValues(alpha: 0.12),
                    border: Border.all(color: _kNeon.withValues(alpha: 0.5)),
                  ),
                  child: Icon(
                    isConfig
                        ? Icons.error_outline_rounded
                        : Icons.wifi_off_rounded,
                    color: _kNeon,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  isConfig
                      ? 'Uygulama yapılandırılamadı.'
                      : 'Bağlantı kurulamadı.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isConfig
                      ? 'Lütfen Play Store üzerinden son sürümü yükleyin '
                          've sorun devam ederse destek ekibiyle iletişime '
                          'geçin.'
                      : 'Lütfen internetinizi kontrol edin.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _retrying ? null : _onRetryPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kNeon,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white24,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _retrying
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text('TEKRAR DENE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FormAIApp extends ConsumerStatefulWidget {
  const FormAIApp({super.key});

  @override
  ConsumerState<FormAIApp> createState() => _FormAIAppState();
}

class _FormAIAppState extends ConsumerState<FormAIApp> {
  @override
  void initState() {
    super.initState();
    // Phase 54 · start the deep-link listener as soon as the router is
    // available. Reading the provider through `ref` ties its lifetime
    // to this widget, so a hot-restart cleanly disposes the prior
    // StreamSubscription before booting a new one. We can't await
    // here (initState is sync) — `start()` resolves any cold-start
    // initial link asynchronously, which is fine because the router
    // is already mounted by the time the link resolves.
    Future<void>.microtask(() {
      ref.read(deepLinkServiceProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Phase 55 · materialise the widget-sync listener so it begins
    // pushing snapshots to the home-screen widget the moment
    // workoutSessionProvider settles. `ref.watch` (vs read) ties the
    // listener's lifetime to this widget — when the app shell
    // dismounts the listener tears down with it.
    ref.watch(widgetSyncListenerProvider);
    // Phase 58 · same lifecycle pattern for the smart-reminder
    // scheduler. Listens to workout + nutrition state changes and
    // re-stamps the daily notification with the right body
    // (Antrenman Vakti / Yakıt Gerekli / Günü fethettin) so the
    // next-fire reflects current progress.
    ref.watch(smartReminderListenerProvider);
    final router = ref.watch(appRouterProvider);
    // Phase 53 · the user's persisted choice flows through
    // `themeModeProvider`. ThemeMode.system (the default for fresh
    // installs) lets the OS dark/light setting drive which of the two
    // builders below wins; explicit Light/Dark overrides force-select.
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'FormAI',
      debugShowCheckedModeBanner: false,
      // Phase 2 (P-Risk) · localization foundation. Delegates + supported
      // locales wired from the generated AppLocalizations; string migration
      // from hard-coded Turkish is incremental from here.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Phase 49 · the dark builder layers floating, neon-bordered
      // SnackBars on top of the seed-based ColorScheme so toasts read
      // as part of the brand. Phase 53 added [AppTheme.light] so
      // selecting "Açık" or following a light-mode system pref renders
      // a matching off-white palette without losing the neon CTAs.
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
