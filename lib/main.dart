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
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait lock — Redmi Note 11R (and similar low-end Androids) started
  // freezing on landscape rotation during workouts because the ML Kit pose
  // detector re-allocates tensors on every resize and the camera preview
  // briefly ran out of memory. Locking orientation sidesteps both that and
  // the scattered layout overflows the landscape composition surfaced.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Phase 42: dotenv must load BEFORE SentryFlutter.init so the DSN is
  // available. Fails silently if `.env` is missing (dev builds without
  // keys) — Sentry will init with an empty DSN and no-op, which is the
  // desired behaviour in that case.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Swallow; _BootGate re-checks and surfaces the retry screen for
    // cases that actually break initialisation (Supabase URL missing).
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = dotenv.env['SENTRY_DSN'] ?? '';
      options.tracesSampleRate = 0.2;
      options.environment = kReleaseMode ? 'prod' : 'dev';
      // PII scrubber — Sentry attaches the device IP and a User slot by
      // default; we clear the email / ipAddress / data fields before
      // the event leaves the device. Supabase user_id stays on `id` so
      // funnels can still group events per user; nothing sensitive
      // (weight, height, goals) ever reaches the User slot in the
      // first place because `AppLogger.error` never sets it.
      options.beforeSend = (event, hint) {
        final user = event.user;
        if (user != null) {
          user.ipAddress = null;
          user.email = null;
          user.data = null;
        }
        return event;
      };
    },
    appRunner: () => runApp(const _BootGate()),
  );
}

const Color _kNeon = Color(0xFF00F0FF);

// Splashes the FormAI wordmark immediately, then hands off to the real app
// once .env + Supabase + SharedPreferences are ready. Running the three
// bootstraps off the first-frame critical path is what kills the 3–5s black
// screen users were seeing at login time. Phase 6 added retry-on-failure
// so offline launches no longer lock users on a splash forever.
class _BootGate extends StatefulWidget {
  const _BootGate();

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
      // dotenv already loaded in `main()` before Sentry.init, so we only
      // cross the SharedPreferences platform channel here.
      final prefs = await SharedPreferences.getInstance();

      if (!_supabaseInitialized) {
        await Supabase.initialize(
          url: dotenv.env['SUPABASE_URL'] ?? '',
          anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
        );
        _supabaseInitialized = true;
      }

      // Phase 42: PostHog analytics. Await it so the first analytics
      // event (typically `paywall_viewed` on auto-prompt, or
      // `onboarding_step_completed` on welcome) actually lands — the
      // setup() call in posthog_flutter buffers until done.
      await AnalyticsService.instance.init(
        apiKey: dotenv.env['POSTHOG_API_KEY'] ?? '',
        host: dotenv.env['POSTHOG_HOST'] ?? 'https://app.posthog.com',
      );

      // Phase 48 · RevenueCat configuration deferred. Was an `await
      // configureRevenueCat()` here on every cold start, blocking the
      // splash for the platform-channel handshake even on users who
      // never reach the paywall. Now it's lazily kicked off from
      // `OnboardingScreen._finish()` (post-wizard) and from
      // `AuthController.signIn{Google,Apple}()` (post-sign-in), so the
      // SDK only spins up for users who are actually heading toward
      // the paywall surface.
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
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _BootErrorScreen(onRetry: _retry),
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

class _BootErrorScreen extends StatefulWidget {
  const _BootErrorScreen({required this.onRetry});
  final VoidCallback onRetry;

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
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    color: _kNeon,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Bağlantı kurulamadı.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Lütfen internetinizi kontrol edin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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

class FormAIApp extends ConsumerWidget {
  const FormAIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'FormAI',
      debugShowCheckedModeBanner: false,
      // Phase 49 · `AppTheme.dark()` adds the floating, neon-bordered
      // SnackBar defaults on top of the existing seed-based scheme so
      // every toast across the app reads as part of the brand.
      theme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
