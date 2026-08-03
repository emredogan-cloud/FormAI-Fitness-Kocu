/// Roadmap Phase 13 (C23 · C25 · R6) · what a leaderboard row, a league
/// standing and a challenge look like in Dart.
///
/// Kept out of `community_models.dart` because that file is Phase 12's
/// identity layer and this is a different subject; the split is
/// organisational, not architectural. Everything here follows the same
/// rules as Phase 12's models: parse defensively, and prefer null over a
/// wrong default whenever the server could be newer than the client.
library;

import '../league.dart';

/// One person's week, as the leaderboard sees it.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.weeklyXp,
    required this.sessions,
    required this.streakDays,
    required this.consistency,
    this.displayName,
  });

  final String userId;
  final int weeklyXp;
  final int sessions;
  final int streakDays;
  final int consistency;

  /// Null when the profile behind this row is private — which is the
  /// whole of the roadmap's "appear pseudonymously" requirement, and
  /// needs no field of its own. The screen renders it the way the feed
  /// renders an unresolvable actor.
  final String? displayName;

  /// The number this row is ranked by, for [metric].
  int valueFor(LeaderboardMetric metric) => switch (metric) {
        LeaderboardMetric.xp => weeklyXp,
        LeaderboardMetric.sessions => sessions,
        LeaderboardMetric.streak => streakDays,
        LeaderboardMetric.consistency => consistency,
      };

  static LeaderboardEntry? fromJson(Map<String, dynamic> json) {
    final userId = json['user_id'] as String?;
    if (userId == null) return null;
    int intOf(String key) => (json[key] as num?)?.toInt() ?? 0;
    return LeaderboardEntry(
      userId: userId,
      weeklyXp: intOf('weekly_xp'),
      sessions: intOf('sessions'),
      streakDays: intOf('streak_days'),
      consistency: intOf('consistency'),
    );
  }
}

/// What a board is sorted by.
///
/// The roadmap names all four, and **consistency is the one a beginner
/// can win** — it is a ratio, so somebody training three days out of
/// three beats somebody training five out of seven. That is the entire
/// reason it is in the list, and it is why it is not last.
enum LeaderboardMetric {
  consistency('consistency'),
  xp('weekly_xp'),
  sessions('sessions'),
  streak('streak_days');

  const LeaderboardMetric(this.column);

  /// The `leaderboard_stats` column, used for ordering server-side and
  /// as the stable analytics token.
  final String column;
}

/// A user's place in their league this season.
class LeagueStanding {
  const LeagueStanding({
    required this.tier,
    this.previousTier,
    this.rank,
    this.size,
  });

  final LeagueTier tier;

  /// Where they were last season, so the client can say "up from
  /// silver" without a second query. Null in a first season.
  final LeagueTier? previousTier;

  /// 1-based, null until the board has been read.
  final int? rank;
  final int? size;

  /// What would happen if the week ended now. Null when there is not
  /// enough information to say — and saying nothing is correct then,
  /// because a predicted promotion that does not arrive is worse than
  /// no prediction.
  LeagueOutcome? get projectedOutcome {
    final r = rank;
    final n = size;
    if (r == null || n == null) return null;
    return outcomeFor(tier: tier, rank: r, size: n);
  }

  static LeagueStanding? fromJson(Map<String, dynamic> json) {
    final tier = LeagueTier.fromToken(json['tier'] as String?);
    // A tier this client does not know is a newer server's. Returning
    // null drops the card rather than showing somebody a tier they are
    // not in.
    if (tier == null) return null;
    return LeagueStanding(
      tier: tier,
      previousTier: LeagueTier.fromToken(json['prev_tier'] as String?),
    );
  }

  LeagueStanding withRank({required int rank, required int size}) =>
      LeagueStanding(
        tier: tier,
        previousTier: previousTier,
        rank: rank,
        size: size,
      );
}

/// A time-boxed event somebody can join.
class Challenge {
  const Challenge({
    required this.id,
    required this.slug,
    required this.kind,
    required this.target,
    required this.startsAt,
    required this.endsAt,
    required this.copy,
    this.badgeId,
    this.squadScope = false,
  });

  final String id;
  final String slug;
  final ChallengeKind kind;
  final int target;
  final DateTime startsAt;
  final DateTime endsAt;

  /// Locale tag → {title, body}. Authored as data so content ops ships a
  /// challenge without a release, which is what the roadmap asks for.
  final Map<String, Map<String, String>> copy;

  final String? badgeId;
  final bool squadScope;

  /// Title in [locale], falling back to English, then to null.
  ///
  /// Null rather than the slug: a slug is an identifier and showing one
  /// to a user is the same mistake as rendering a badge token.
  String? title(String locale) => _pick(locale, 'title');
  String? body(String locale) => _pick(locale, 'body');

  String? _pick(String locale, String field) {
    final exact = copy[locale]?[field];
    if (exact != null && exact.isNotEmpty) return exact;
    // The language without its region — 'tr' for 'tr-TR'.
    final short = locale.split('-').first;
    final byLanguage = copy[short]?[field];
    if (byLanguage != null && byLanguage.isNotEmpty) return byLanguage;
    final english = copy['en']?[field];
    return (english != null && english.isNotEmpty) ? english : null;
  }

  bool isOpen(DateTime now) =>
      challengeIsOpen(startsAt: startsAt, endsAt: endsAt, now: now);

  static Challenge? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final slug = json['slug'] as String?;
    final kind = ChallengeKind.fromToken(json['kind'] as String?);
    final target = (json['target'] as num?)?.toInt();
    final startsAt = DateTime.tryParse(json['starts_at'] as String? ?? '');
    final endsAt = DateTime.tryParse(json['ends_at'] as String? ?? '');
    // Any missing piece drops the row. A challenge with no end date or
    // an unknown kind cannot be tracked honestly, and half a challenge
    // on screen is worse than none.
    if (id == null ||
        slug == null ||
        kind == null ||
        target == null ||
        startsAt == null ||
        endsAt == null) {
      return null;
    }
    return Challenge(
      id: id,
      slug: slug,
      kind: kind,
      target: target,
      startsAt: startsAt,
      endsAt: endsAt,
      copy: _parseCopy(json['copy']),
      badgeId: json['badge_id'] as String?,
      squadScope: json['squad_scope'] as bool? ?? false,
    );
  }

  static Map<String, Map<String, String>> _parseCopy(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, Map<String, String>>{};
    raw.forEach((locale, fields) {
      if (locale is! String || fields is! Map) return;
      final entry = <String, String>{};
      fields.forEach((key, value) {
        if (key is String && value is String) entry[key] = value;
      });
      if (entry.isNotEmpty) out[locale] = entry;
    });
    return out;
  }
}

/// Somebody's progress through a challenge.
class ChallengeEntry {
  const ChallengeEntry({
    required this.challengeId,
    required this.userId,
    required this.progress,
    this.completedAt,
    this.displayName,
  });

  final String challengeId;
  final String userId;
  final int progress;
  final DateTime? completedAt;
  final String? displayName;

  bool get isComplete => completedAt != null;

  static ChallengeEntry? fromJson(Map<String, dynamic> json) {
    final challengeId = json['challenge_id'] as String?;
    final userId = json['user_id'] as String?;
    if (challengeId == null || userId == null) return null;
    final completed = json['completed_at'] as String?;
    return ChallengeEntry(
      challengeId: challengeId,
      userId: userId,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      completedAt: completed == null ? null : DateTime.tryParse(completed),
    );
  }
}
