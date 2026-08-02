import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/unit_system.dart';

/// Roadmap Phase 9 (C1) · the weight the USER says they are aiming for.
///
/// **The app never predicts this number, and must not.** The roadmap
/// asks for "the onboarding goal weight drawn as a target line"; no such
/// value exists. Onboarding captures a current weight and nothing else,
/// and `ai_personalization_engine.dart` carries an explicit rule against
/// emitting quantified outcome promises — Apple 1.4.1 and Play
/// health-misrepresentation both reject guaranteed numeric results,
/// which is exactly why the 12-week projection there is qualitative.
///
/// So the user states it and this holds it. The chart draws the line the
/// user asked for. Beyond compliance, it is the honest arrangement: a
/// target the user chose is a commitment, and a target the app invented
/// is a promise it has no way to keep.
///
/// **Null is a permanent, valid state.** Someone who wants to log their
/// weight without naming a destination — which is the healthier pattern
/// for a recomposition user, and the safer one for anybody with a
/// history around the number — gets the whole feature with no target
/// line and no nagging.
///
/// Stored in kilograms like everything else; the entry field converts at
/// the render boundary. Device copy is authoritative for the running
/// app, mirrored to `user_metrics.target_weight_kg` so it survives a
/// reinstall.
final targetWeightProvider =
    NotifierProvider<TargetWeightNotifier, double?>(TargetWeightNotifier.new);

class TargetWeightNotifier extends Notifier<double?> {
  static const String storageKey = 'sixpack.target_weight_kg';

  @override
  double? build() {
    final raw = ref.watch(sharedPreferencesProvider).getDouble(storageKey);
    return _sanitize(raw);
  }

  /// Sets the target, or clears it when [kg] is null.
  ///
  /// Out-of-range values are rejected rather than clamped. Clamping 700
  /// to 250 would store a number the user never typed and then draw it
  /// on their chart as though they had.
  Future<void> set(double? kg) async {
    final next = _sanitize(kg);
    if (kg != null && next == null) return;
    if (state == next) return;
    state = next;

    final prefs = ref.read(sharedPreferencesProvider);
    if (next == null) {
      await prefs.remove(storageKey);
    } else {
      await prefs.setDouble(storageKey, next);
    }
    await _pushToAccount(next);
  }

  /// Best-effort carry across a reinstall, exactly like the locale
  /// mirror. Every failure is swallowed: the device copy is what the
  /// running app reads, so offline, signed-out and never-initialised
  /// are all normal conditions here.
  Future<void> _pushToAccount(double? kg) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await Supabase.instance.client.from('user_metrics').upsert(
        {'user_id': userId, 'target_weight_kg': kg},
        onConflict: 'user_id',
      );
    } catch (e) {
      AppLogger.warning(
        'Target weight sync to account skipped: $e',
        category: 'progress',
      );
    }
  }

  /// Drops anything outside the range the editor and the migration's
  /// check constraint both enforce, so a corrupted preference cannot
  /// draw a target line at 4 kg.
  static double? _sanitize(double? kg) {
    if (kg == null) return null;
    if (kg < kMinWeightKg || kg > kMaxWeightKg) return null;
    return roundTo(kg, 1);
  }
}
