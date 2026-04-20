import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/routing/app_router.dart';
import 'core/services/app_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootGate());
}

// Splashes the FormAI wordmark immediately, then hands off to the real app
// once .env + Supabase + SharedPreferences are ready. Running the three
// bootstraps off the first-frame critical path is what kills the 3–5s black
// screen users were seeing at login time.
class _BootGate extends StatefulWidget {
  const _BootGate();

  @override
  State<_BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<_BootGate> {
  late final Future<SharedPreferences> _bootstrap = _init();

  Future<SharedPreferences> _init() async {
    // dotenv reads an asset bundle; SharedPreferences crosses a platform
    // channel. They don't depend on each other, so awaiting them in parallel
    // pays the max latency instead of the sum.
    final envFuture = dotenv.load(fileName: '.env');
    final prefsFuture = SharedPreferences.getInstance();
    await envFuture;
    final prefs = await prefsFuture;

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
    return prefs;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: _bootstrap,
      builder: (context, snapshot) {
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
            color: Color(0xFF00F0FF),
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            shadows: [Shadow(blurRadius: 24, color: Color(0xFF00F0FF))],
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00F0FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
