import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Streams Supabase auth state changes (login, logout, refresh).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Currently signed-in user, or `null` if no session. Rebuilds whenever the
/// auth state stream emits.
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentUser;
});

/// `Listenable` that notifies on every auth state change. Wired into
/// `GoRouter.refreshListenable` so navigation re-evaluates on login/logout
/// without tearing down the router.
final authRefreshListenableProvider = Provider<Listenable>((ref) {
  final notifier = _AuthRefreshListenable();
  final sub = Supabase.instance.client.auth.onAuthStateChange
      .listen((_) => notifier.refresh());
  ref.onDispose(() {
    sub.cancel();
    notifier.dispose();
  });
  return notifier;
});

class _AuthRefreshListenable extends ChangeNotifier {
  void refresh() => notifyListeners();
}
