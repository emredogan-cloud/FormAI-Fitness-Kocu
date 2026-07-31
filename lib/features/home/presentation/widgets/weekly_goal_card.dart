import 'package:flutter/material.dart';

import '../../../../core/theme/theme_extension.dart';
import '../../domain/coach_message.dart';
import '../../../../l10n/app_localizations.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);
const Color _surfaceDark = Color(0xFF111118);

List<String> _dayLabels(AppLocalizations l10n) => [
      l10n.weekdayShortMon,
      l10n.weekdayShortTue,
      l10n.weekdayShortWed,
      l10n.weekdayShortThu,
      l10n.weekdayShortFri,
      l10n.weekdayShortSat,
      l10n.weekdayShortSun,
    ];

class WeeklyGoalCard extends StatelessWidget {
  const WeeklyGoalCard({
    super.key,
    required this.weekDates,
    required this.today,
    required this.weeklyCompleted,
    required this.weeklyTarget,
  });

  final List<DateTime> weekDates;
  final DateTime today;
  final int weeklyCompleted;
  final int weeklyTarget;

  @override
  Widget build(BuildContext context) {
    // Phase 53F · the entire card was painted from a hardcoded
    // `_surface = #111118` plus white text/borders. Both flip via the
    // active ColorScheme: light mode uses `surface` for the card and
    // `outlineVariant` for the hairline; dark mode preserves the
    // existing chrome.
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? _surfaceDark : scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      AppLocalizations.of(context).weeklyGoalTitle,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.edit,
                      color: scheme.onSurface.withValues(alpha: 0.38),
                      size: 14,
                    ),
                  ],
                ),
              ),
              Text(
                AppLocalizations.of(context)
                    .weeklyWorkoutsOf(weeklyCompleted, weeklyTarget),
                style: const TextStyle(
                  color: _neonAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < weekDates.length; i++)
                _DateBubble(
                  date: weekDates[i],
                  label: _dayLabels(AppLocalizations.of(context))[i],
                  isToday: _isSameDay(weekDates[i], today),
                  isPast: weekDates[i]
                      .isBefore(DateTime(today.year, today.month, today.day)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _CoachSpeechBubble(
            // Contextual now (was a fixed string): reflects real weekly
            // progress + time of day. Pure fn = future LLM swap-in point.
            text: weeklyCoachLine(
              l10n: AppLocalizations.of(context),
              completed: weeklyCompleted,
              target: weeklyTarget,
              hour: DateTime.now().hour,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateBubble extends StatelessWidget {
  const _DateBubble({
    required this.date,
    required this.label,
    required this.isToday,
    required this.isPast,
  });

  final DateTime date;
  final String label;
  final bool isToday;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    // Phase 53F · weekday labels + date bubbles were all hardcoded
    // white tones. Pull the neutral surfaces + text via onSurface so
    // the bubble row reads on light. Today's neon-filled bubble keeps
    // its purple emphasis (it's brand identity).
    final scheme = context.colors;
    final bg = isToday
        ? _neon
        : (isPast
            ? scheme.onSurface.withValues(alpha: 0.05)
            : Colors.transparent);
    final border = isToday ? _neon : scheme.onSurface.withValues(alpha: 0.20);
    final numberColor = isToday
        ? Colors.white
        : (isPast
            ? scheme.onSurface.withValues(alpha: 0.55)
            : scheme.onSurface);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.45),
            fontSize: 10,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: Border.all(color: border, width: 1),
            boxShadow: isToday
                ? [
                    BoxShadow(
                      color: _neon.withValues(alpha: 0.55),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '${date.day}',
            style: TextStyle(
              color: numberColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _CoachSpeechBubble extends StatelessWidget {
  const _CoachSpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    // Phase 53F · the speech bubble was an opaque-white-on-translucent
    // tile in dark mode. Light mode reuses surfaceContainer and pulls
    // the body text from onSurface so the AI Coach copy is legible.
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : scheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_neon, _neonAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _neon.withValues(alpha: 0.5),
                  blurRadius: 12,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'photos/PT_FORM.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.black26,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.smart_toy,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.75),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
