import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/theme_extension.dart';
import '../../nutrition/domain/models/macro_target.dart';
import '../../nutrition/providers/nutrition_provider.dart';
import '../../workout/models/workout_day_model.dart';
import '../../workout/providers/workout_provider.dart';

const Color _neon = Color(0xFF8B5CF6);
const Color _neonAccent = Color(0xFF4DA6FF);
const Color _proteinColor = Color(0xFF4DA6FF);
const Color _hydrateColor = Color(0xFF39E0FF);
const Color _workoutColor = Color(0xFFF97316);
const Color _success = Color(0xFF22C55E);
const Color _surface = Color(0xFF0F0F14);
const Color _surfaceBorder = Color(0xFF1E1E26);

/// Phase 47A · AI Coach suggestions.
///
/// Surfaces three actionable tips tailored to the user's current
/// progress state:
///
///   1. **Workout tip** — reacts to the first-incomplete program day
///      (focus muscle group from the day's exercises, or "recovery
///      boost" on rest days, or "30-day victory lap" once the program
///      is complete).
///   2. **Nutrition tip** — reacts to remaining protein grams. A large
///      gap surfaces "yüksek protein" ideas; the low-cal finish fires
///      when the user has little calorie room left in the day.
///   3. **Hydration tip** — the static foundation of any plan, phrased
///      to nudge toward 2.5 L / day.
///
/// Each card carries a primary CTA that routes to the relevant tab /
/// screen so the tip is one tap from action.
class SuggestionsScreen extends ConsumerWidget {
  const SuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionProvider).value;
    final days = session?.days ?? const <WorkoutDay>[];
    final activeDay = _firstIncomplete(days);
    final streak = _streakOf(days);
    final remaining = ref.watch(remainingMacrosProvider);

    final suggestions = <_SuggestionData>[
      _buildWorkoutSuggestion(activeDay: activeDay, streak: streak),
      _buildNutritionSuggestion(remaining: remaining),
      const _SuggestionData(
        accent: _hydrateColor,
        icon: Icons.water_drop_rounded,
        title: 'Su içmeyi unutma',
        description:
            'Günde en az 2.5 litre su, enerji seviyeni ve kas toparlanmasını '
            'doğrudan etkiler. Sonraki saatte bir bardak daha iç.',
        ctaLabel: 'Hedef: 2.5 L',
        ctaRoute: null,
      ),
    ];

    // Phase 53D · scaffold + AppBar pull from the active theme; the
    // dark radial halo only paints in dark mode so light mode reveals
    // the off-white scaffoldBackgroundColor cleanly.
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        title: Text(
          'Öneriler',
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ),
      body: Container(
        decoration: isDark
            ? const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.85),
                  radius: 1.1,
                  colors: [Color(0xFF1E0A40), Color(0xFF0A0612), Colors.black],
                  stops: [0.0, 0.55, 1.0],
                ),
              )
            : null,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const _CoachHero(),
            const SizedBox(height: 22),
            Text(
              'BUGÜNÜN ÖNERİLERİ',
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.70),
                fontSize: 11,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            for (final suggestion in suggestions) ...[
              _SuggestionCard(data: suggestion),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // Rule-based copy selection — kept tight because the calls fan out
  // from `build()` on every rebuild; no string allocations per frame
  // that aren't bound to the current state.
  // ==========================================================================

  _SuggestionData _buildWorkoutSuggestion({
    required WorkoutDay? activeDay,
    required int streak,
  }) {
    if (activeDay == null) {
      return const _SuggestionData(
        accent: _success,
        icon: Icons.emoji_events_rounded,
        title: '30 günü tamamladın!',
        description:
            '30 günlük arc bitti — bugün hafif bir mobility günü planla '
            've kendini ödüllendir. Yeni bir hedef belirlemek için '
            'Gelişim sekmesine göz at.',
        ctaLabel: 'Gelişime git',
        ctaRoute: AppRoutes.dashboard,
      );
    }
    final focus = _focusLabel(activeDay);
    final dayNumber = activeDay.dayNumber;
    final streakHeadline = streak >= 3 ? '$streak günlük serini bozma — ' : '';
    return _SuggestionData(
      accent: _workoutColor,
      icon: Icons.fitness_center_rounded,
      title: 'Bugün $focus çalış',
      description: "${streakHeadline}Gün $dayNumber'ün hedefi: $focus. "
          'Antrenmanı başlatıp serini bugüne taşı.',
      ctaLabel: 'Antrenmana başla',
      ctaRoute: AppRoutes.planDetail,
    );
  }

  _SuggestionData _buildNutritionSuggestion({required MacroTarget remaining}) {
    if (remaining.protein > 30) {
      return _SuggestionData(
        accent: _proteinColor,
        icon: Icons.restaurant_rounded,
        title: 'Yüksek proteinli bir tarif dene',
        description:
            '${remaining.protein}g protein açığın var. Öğlen veya akşam '
            'için hızlıca tavuk, yumurta ya da baklagil bazlı bir tarif '
            'seç — günün hedefine tam oturur.',
        ctaLabel: 'Yüksek Protein filtrele',
        ctaRoute: AppRoutes.nutritionDiscover,
      );
    }
    if (remaining.calories < 400 && remaining.calories > 0) {
      return _SuggestionData(
        accent: _success,
        icon: Icons.spa_rounded,
        title: 'Hafif bir öğünle gününü kapat',
        description:
            'Günün neredeyse tamamlandı — kalan ${remaining.calories} kcal '
            'için salata veya yoğurtlu bir snack ideal. Düşük kalorili '
            'tariflerden seç.',
        ctaLabel: 'Düşük kalorili tarif',
        ctaRoute: AppRoutes.nutritionDiscover,
      );
    }
    if (remaining.calories <= 0) {
      return const _SuggestionData(
        accent: _neon,
        icon: Icons.verified_rounded,
        title: 'Günlük hedefini tamamladın',
        description: 'Makro hedeflerini tutturdun. Kalan zamanda sadece su ve '
            'ılık bitki çayı yeterli — yarın için enerjini topla.',
        ctaLabel: null,
        ctaRoute: null,
      );
    }
    return const _SuggestionData(
      accent: _proteinColor,
      icon: Icons.eco_rounded,
      title: 'Dengeli bir öğün planla',
      description: 'Makro dağılımın bugün dengeli. Bir sonraki öğün için '
          'kompozit bir tarif seç — protein, sebze ve karmaşık '
          'karbonhidrat üçlüsünden.',
      ctaLabel: 'Tarifleri keşfet',
      ctaRoute: AppRoutes.nutritionDiscover,
    );
  }

  WorkoutDay? _firstIncomplete(List<WorkoutDay> days) {
    for (final day in days) {
      if (day.isRestDay) continue;
      if (!day.isCompleted) return day;
    }
    return null;
  }

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

  String _focusLabel(WorkoutDay day) {
    if (day.isRestDay) return 'aktif dinlenme';
    final counts = <String, int>{};
    for (final exercise in day.exercises) {
      counts[exercise.targetMuscle] = (counts[exercise.targetMuscle] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'antrenman';
    final dominant =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    switch (dominant) {
      case 'core':
        return 'karın';
      case 'upper_body':
        return 'üst vücut';
      case 'lower_body':
        return 'bacak';
      case 'cardio':
        return 'kardiyo';
      case 'full_body':
        return 'tüm vücut';
      default:
        return 'antrenman';
    }
  }
}

class _SuggestionData {
  const _SuggestionData({
    required this.accent,
    required this.icon,
    required this.title,
    required this.description,
    required this.ctaLabel,
    required this.ctaRoute,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String description;
  final String? ctaLabel;
  final String? ctaRoute;
}

class _CoachHero extends StatelessWidget {
  const _CoachHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF221145), Color(0xFF0D0622)],
        ),
        border: Border.all(color: _neon.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.25),
            blurRadius: 22,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_neon, _neonAccent],
              ),
              boxShadow: [
                BoxShadow(
                  color: _neon.withValues(alpha: 0.55),
                  blurRadius: 14,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'photos/kişiselyapayzekakoçfoto.webp',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: _neon.withValues(alpha: 0.9),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.smart_toy,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI Koçun diyor ki',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Bugünün durumuna göre hazırladığım üç '
                  'mikro-aksiyonu aşağıda bulacaksın.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.data});
  final _SuggestionData data;

  @override
  Widget build(BuildContext context) {
    // Phase 53D · suggestion card surface + title + description all
    // route through ColorScheme. Accent-tinted icon square keeps its
    // brand colour because it's the suggestion's identity (orange =
    // workout, blue = nutrition, etc.).
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? _surface : scheme.surface,
        border: Border.all(
          color: isDark ? _surfaceBorder : scheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: data.accent.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 16,
            spreadRadius: 0.3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: data.accent.withValues(alpha: 0.18),
                  border: Border.all(color: data.accent.withValues(alpha: 0.5)),
                ),
                child: Icon(data.icon, color: data.accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  data.title,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data.description,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.75),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (data.ctaLabel != null) ...[
            const SizedBox(height: 14),
            _SuggestionCta(data: data),
          ],
        ],
      ),
    );
  }
}

class _SuggestionCta extends StatelessWidget {
  const _SuggestionCta({required this.data});
  final _SuggestionData data;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap:
              data.ctaRoute == null ? null : () => context.push(data.ctaRoute!),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: data.accent.withValues(alpha: 0.14),
              border: Border.all(color: data.accent.withValues(alpha: 0.55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.ctaLabel!,
                  style: TextStyle(
                    color: data.accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                if (data.ctaRoute != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: data.accent,
                    size: 16,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
