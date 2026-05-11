import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../../core/services/first_time_ai_scenes.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/widgets/cached_image.dart';
import '../../../nutrition/domain/models/recipe.dart';
import '../../../nutrition/providers/nutrition_provider.dart';
import '../../../referral/providers/referral_provider.dart';
import '../../models/workout_day_model.dart';
import '../../providers/workout_provider.dart';

const Color _neon = Color(0xFF00F0FF);
const Color _neonPurple = Color(0xFF8E5BFF);

/// Post-workout celebration overlay. Renders the "Gün N Tamam!" trophy
/// block and — when the recipe catalogue is loaded — a "Toparlanma
/// Önerisi" card with a high-protein recipe the user can tap to open.
///
/// Phase 22: was a [ConsumerWidget] so it could read the recipe catalogue
/// + user nutrition preferences (to honour a `hizli` prep choice).
///
/// Phase 126: upgraded to [ConsumerStatefulWidget] so it can fire the
/// first-time cinematic workout-complete AI scene on mount (after the
/// first frame, so the trophy renders before the scene cross-fades on
/// top). The scene self-pops; gating lives inside [FirstTimeAiScenes].
class SessionCompleteOverlay extends ConsumerStatefulWidget {
  const SessionCompleteOverlay({
    super.key,
    required this.day,
    required this.onAcknowledge,
  });

  final WorkoutDay? day;
  final VoidCallback onAcknowledge;

  @override
  ConsumerState<SessionCompleteOverlay> createState() =>
      _SessionCompleteOverlayState();
}

class _SessionCompleteOverlayState
    extends ConsumerState<SessionCompleteOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FirstTimeAiScenes.showIfNeeded(
        context,
        ref,
        FirstTimeAiScene.workoutCompleteCelebration,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesProvider);
    final prefs = ref.watch(appPreferencesProvider).userMetrics ??
        const <String, dynamic>{};
    final prepPref = (prefs['prepTime'] as String?) ?? 'hizli';

    final suggestion = recipesAsync.maybeWhen(
      data: (recipes) => _pickRecoveryRecipe(recipes, prepPref),
      orElse: () => null,
    );

    // Phase 54B · the celebration overlay now closes the loop with a
    // share CTA. We pull the live program-completion stats off the
    // workout session so the rendered Story PNG carries the user's
    // *current* stats — not a stale snapshot from when the workout
    // started.
    final session = ref.watch(workoutSessionProvider).value;
    final completedDays = session?.days.where((d) => d.isCompleted).length ?? 0;
    final streak = _streakOf(session?.days ?? const []);
    final percent =
        ((completedDays / AppConstants.programLength) * 100).round();
    final referralCode = ref.watch(referralCodeProvider).value;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.80),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Icon(Icons.military_tech, size: 96, color: _neon),
                const SizedBox(height: 16),
                Text(
                  widget.day == null
                      ? 'Program Tamam!'
                      : 'Gün ${widget.day!.dayNumber} Tamam!',
                  style: const TextStyle(
                    color: _neon,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    shadows: [Shadow(blurRadius: 30, color: _neon)],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Harika iş çıkardın, yarın görüşürüz.',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                if (suggestion != null) ...[
                  const SizedBox(height: 24),
                  _RecoverySuggestionCard(recipe: suggestion),
                ],
                const SizedBox(height: 24),
                // Phase 54B · two-button row. "Paylaş" hands the live
                // progress (% complete + streak) to ShareService for an
                // off-screen Story render; "Tamam" remains the primary
                // dismiss. Sized 1:1 so neither overshadows the other —
                // share is opt-in chrome, dismiss is the default flow.
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          AppHaptics.secondaryTap();
                          ShareService.instance.shareProgress(
                            context: context,
                            percent: percent,
                            completedDays: completedDays,
                            totalDays: AppConstants.programLength,
                            streak: streak,
                            referralCode: referralCode,
                          );
                        },
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: const Text('Paylaş'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _neon,
                          side: const BorderSide(color: _neon, width: 1.4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: widget.onAcknowledge,
                        style: FilledButton.styleFrom(
                          backgroundColor: _neon,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Tamam'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Phase 54B · streak helper. Counts contiguous completed days
  /// from the head of the schedule, mirroring the same definition
  /// used in `gelisim_tab.dart`. Inlined here rather than imported
  /// from a single source because the helper is two lines and
  /// extracting a util just for two callers would over-abstract.
  int _streakOf(List<WorkoutDay> days) {
    var streak = 0;
    for (final day in days) {
      if (day.isCompleted) {
        streak += 1;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Picks a recovery recipe prioritised by:
  ///   1. mealType in {`snack`, `main`, `lunch`, `dinner`} — these make
  ///      sense immediately after a workout;
  ///   2. if the user prefers `hizli` prep, prepTime ≤ 15 min;
  ///   3. highest protein in grams.
  ///
  /// Returns null if no recipe survives the filter — the overlay then
  /// simply omits the card.
  Recipe? _pickRecoveryRecipe(List<Recipe> recipes, String prepPref) {
    if (recipes.isEmpty) return null;

    Iterable<Recipe> pool = recipes.where((r) {
      final t = r.mealType.toLowerCase();
      return t == 'snack' || t == 'main' || t == 'lunch' || t == 'dinner';
    });
    if (pool.isEmpty) pool = recipes;

    if (prepPref == 'hizli') {
      final fast = pool.where((r) => r.prepTimeMinutes <= 15);
      if (fast.isNotEmpty) pool = fast;
    }

    final sorted = pool.toList()
      ..sort((a, b) => b.protein.compareTo(a.protein));
    return sorted.isEmpty ? null : sorted.first;
  }
}

class _RecoverySuggestionCard extends StatelessWidget {
  const _RecoverySuggestionCard({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: _neonPurple.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: _neonPurple.withValues(alpha: 0.35),
            blurRadius: 22,
            spreadRadius: 0.5,
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.restaurant, color: _neonPurple, size: 16),
              SizedBox(width: 6),
              Text(
                'TOPARLANMA ÖNERİSİ',
                style: TextStyle(
                  color: _neonPurple,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: _Thumbnail(imageUrl: recipe.imageUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${recipe.protein}g protein · '
                      '${recipe.calories} kcal · '
                      '${recipe.prepTimeMinutes} dk',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/recipe', extra: recipe),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text('Tarifi Gör'),
              style: FilledButton.styleFrom(
                backgroundColor: _neonPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Colors.white10,
      alignment: Alignment.center,
      child: const Icon(Icons.restaurant, color: Colors.white54, size: 22),
    );
    final url = imageUrl;
    if (url == null || url.isEmpty) return fallback;
    return CachedImage(
      url: url,
      fit: BoxFit.cover,
      memCacheHeight: 300,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
