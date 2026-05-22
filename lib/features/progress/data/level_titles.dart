/// Progress redesign Phase 3.A · the 9-tier level title ladder.
///
/// Titles read like a fitness identity, not a video-game rank — the
/// user's "premium / disciplined / aspirational" guardrail rules out
/// gamer-toned strings (no "Noob" / "Elite" / "Godlike"). The ladder
/// is sparse on purpose: most levels carry the previous tier's title
/// so the user has earned-then-held moments rather than a relabel
/// every level.
///
/// Tier breakpoints (level → title transitions):
///
///   1  → Acemi          ← cold-start identity
///   5  → Başlangıç
///   10 → Disiplinli
///   15 → Sabit
///   20 → Atlet          ← gold-tier visual register kicks in here
///   25 → Şampiyon
///   30 → Usta
///   40 → Efsane
///   50 → Mit            ← endgame; reachable in ~year of steady use
///
/// Level 50+ caps at "Mit." There's no further title — by then the user
/// is unambiguously a fitness identity, and inventing more tiers would
/// push toward the cartoonish territory we're explicitly avoiding.
library;

class LevelTier {
  const LevelTier({
    required this.minLevel,
    required this.title,
    required this.isAspirational,
  });

  final int minLevel;
  final String title;

  /// True for tiers in the upper half of the ladder (Atlet onward) — the
  /// hero level chip flips to a gold-tinted accent for these so the
  /// user feels the upgrade visually, not just textually.
  final bool isAspirational;
}

const List<LevelTier> kLevelTiers = [
  LevelTier(minLevel: 1, title: 'Acemi', isAspirational: false),
  LevelTier(minLevel: 5, title: 'Başlangıç', isAspirational: false),
  LevelTier(minLevel: 10, title: 'Disiplinli', isAspirational: false),
  LevelTier(minLevel: 15, title: 'Sabit', isAspirational: false),
  LevelTier(minLevel: 20, title: 'Atlet', isAspirational: true),
  LevelTier(minLevel: 25, title: 'Şampiyon', isAspirational: true),
  LevelTier(minLevel: 30, title: 'Usta', isAspirational: true),
  LevelTier(minLevel: 40, title: 'Efsane', isAspirational: true),
  LevelTier(minLevel: 50, title: 'Mit', isAspirational: true),
];

/// Resolves the title for a level by walking the tier table backward —
/// returns the title of the highest tier whose `minLevel` is ≤ [level].
/// Levels below 1 collapse to the cold-start "Acemi" entry rather than
/// throwing; the curve never produces level < 1 in practice but the
/// defensive default avoids a runtime error if a future schema bug
/// produces a negative XP.
LevelTier tierForLevel(int level) {
  for (var i = kLevelTiers.length - 1; i >= 0; i--) {
    if (level >= kLevelTiers[i].minLevel) return kLevelTiers[i];
  }
  return kLevelTiers.first;
}

/// The next tier the user is climbing toward. Returns null when the
/// user is already at "Mit" (no further tier exists). Useful for the
/// hero subtitle's "Atlet'e 12 seviye" fallback when no badge is
/// closer-to-unlock.
LevelTier? nextTierForLevel(int level) {
  for (final tier in kLevelTiers) {
    if (tier.minLevel > level) return tier;
  }
  return null;
}
