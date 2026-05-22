/// Progress redesign Phase 3.A · the level ⇄ XP curve.
///
/// Closed-form math so the level providers don't loop. The curve is a
/// shallow exponential calibrated so that the user's identity formation
/// pace feels right: a steady-but-not-obsessive user reaches each tier
/// roughly when the masterplan §6.2.3 says it should land.
///
/// Calibration target (assuming ~50 XP / workout + occasional badge /
/// streak bonuses, ~5 sessions/week):
///
///   • Lv 5  ("Başlangıç")  → ~Day 7 of consistent training
///   • Lv 10 ("Disiplinli") → ~Day 30 of consistent training
///   • Lv 15 ("Sabit")      → ~Day 60
///   • Lv 20 ("Atlet")      → ~Month 4
///   • Lv 30 ("Usta")       → ~Year 1
///   • Lv 50 ("Mit")        → multi-year endgame
///
/// Formula: cumulative XP needed to reach level L is
///   `_baseXp * L^2`
/// — a quadratic curve that feels softer than pure exponential at low
/// levels (so cold-start users feel progress) but stretches out at
/// high levels (so identity tiers stay rare and meaningful).
library;

import 'dart:math' as math;

/// Anchors the curve. With baseXp = 50 (one workout's worth) the
/// thresholds are: Lv 2 = 200 XP (4 workouts), Lv 5 = 1250 (~25
/// workouts including badge / streak bonuses, lands around day 7),
/// Lv 10 = 5000 (~100 workouts/badges, lands ~day 30), Lv 30 = 45000.
const int _baseXp = 50;

/// Returns the user's current level from cumulative XP. Level 1 is the
/// cold-start floor; the user can never drop below it (XP is monotone).
int levelForXp(int xp) {
  if (xp <= 0) return 1;
  // Solve `_baseXp * L^2 ≤ xp` for the largest integer L. `floor(sqrt)`
  // does the job at O(1) and avoids the iterative integer-search the
  // naïve implementation would need.
  final l = math.sqrt(xp / _baseXp).floor();
  return l < 1 ? 1 : l;
}

/// XP threshold required to reach level [level] (i.e. the cumulative
/// total at level entry). Caller subtracts current xp to compute "X XP
/// to next level" copy.
int xpRequiredForLevel(int level) {
  if (level <= 1) return 0;
  return _baseXp * level * level;
}

/// Bundle the hero pip needs in one allocation.
class LevelProgress {
  const LevelProgress({
    required this.level,
    required this.xp,
    required this.currentLevelXp,
    required this.nextLevelXp,
  });

  final int level;
  final int xp;

  /// Cumulative XP required to enter [level].
  final int currentLevelXp;

  /// Cumulative XP required to enter [level] + 1.
  final int nextLevelXp;

  /// XP earned within the current level, 0 ≤ value < (next - current).
  int get xpInLevel => xp - currentLevelXp;

  /// XP still needed to reach the next level.
  int get xpToNext => nextLevelXp - xp;

  /// 0–1 fill of the current-level progress bar.
  double get pct {
    final span = nextLevelXp - currentLevelXp;
    if (span <= 0) return 0;
    return (xpInLevel / span).clamp(0, 1);
  }
}

LevelProgress progressForXp(int xp) {
  final level = levelForXp(xp);
  return LevelProgress(
    level: level,
    xp: xp < 0 ? 0 : xp,
    currentLevelXp: xpRequiredForLevel(level),
    nextLevelXp: xpRequiredForLevel(level + 1),
  );
}
