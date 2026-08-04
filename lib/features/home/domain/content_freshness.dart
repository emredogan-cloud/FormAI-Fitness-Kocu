/// Roadmap Phase 14 (C5, C6, R5) · what a release note and a content
/// drop look like in Dart.
///
/// Both are rows in `024_content_versioning.sql` rather than Dart, for
/// the reason Phase 13 made challenges rows: the whole point of this
/// phase is that content ships without an app release, and anything
/// authored in ARB ships on the release train.
///
/// The consequence is that **the server can be newer than the client**,
/// and every parser here answers that the same way Phase 13's does —
/// by dropping what it cannot render honestly. An unknown drop kind, a
/// release with no readable copy, an item with a body and no title: all
/// of them return null rather than guessing, because a screen showing a
/// slug looks broken and a screen showing nothing looks finished.
library;

import '../../../core/utils/localized_copy.dart';

/// One line of a What's New document.
class ReleaseItem {
  const ReleaseItem({required this.title, this.body});

  final String title;

  /// Optional. The roadmap wants "each one line" — a title alone is a
  /// complete item, and forcing a body would make content ops write
  /// filler.
  final String? body;
}

/// The changelog shown once after an update.
class ContentRelease {
  const ContentRelease({
    required this.id,
    required this.version,
    required this.buildNumber,
    required this.copy,
  });

  final String id;
  final String version;

  /// The build this note describes. A client shows the newest release at
  /// or below its own — see [newestFor].
  final int buildNumber;

  /// Locale tag → `{headline: String, items: [{title, body}]}`.
  ///
  /// Held as the decoded jsonb rather than as parsed [ReleaseItem]s
  /// because the item list is per-locale: a document may carry three
  /// English items and two Turkish ones, and parsing at construction
  /// would have to pick a locale before the widget knows one.
  final Map<String, dynamic> copy;

  /// The roadmap's cap: "3 items maximum, each one line, never a wall of
  /// release notes."
  ///
  /// Enforced here rather than by a check constraint in `024` because it
  /// is a rule about what a person will read, and a constraint would
  /// have to guess which locales to count. A fourth item is dropped
  /// silently — content ops sees three on the screen and learns the rule
  /// faster than an error would teach it.
  static const int maxItems = 3;

  String? headline(String locale) =>
      pickLocalized(_stringsFor(locale), locale, 'headline');

  /// Up to [maxItems] items in [locale], falling back language → `en`.
  ///
  /// Falls back as a WHOLE LIST, never item by item. A Turkish headline
  /// over English bullets is the state a half-finished translation pass
  /// leaves things in, and Phase 7 already decided that question for
  /// recipes: one row, one language.
  List<ReleaseItem> items(String locale) {
    for (final key in _lookupOrder(locale)) {
      final raw = (copy[key] as Map?)?['items'];
      if (raw is! List || raw.isEmpty) continue;
      final out = <ReleaseItem>[];
      for (final entry in raw) {
        if (entry is! Map) continue;
        final title = entry['title'];
        if (title is! String || title.isEmpty) continue;
        final body = entry['body'];
        out.add(ReleaseItem(
          title: title,
          body: (body is String && body.isNotEmpty) ? body : null,
        ));
        if (out.length == maxItems) break;
      }
      if (out.isNotEmpty) return out;
    }
    return const [];
  }

  /// True when there is something worth opening a screen for.
  ///
  /// A release row whose copy did not survive parsing is not an error —
  /// it is a note for a locale this user does not read — and the caller
  /// skips it rather than showing an empty celebration.
  bool hasContentFor(String locale) => items(locale).isNotEmpty;

  static List<String> _lookupOrder(String locale) =>
      <String>[locale, locale.split('-').first, 'en'];

  /// The headline lives beside `items` in the same per-locale object, so
  /// it cannot be read with [pickLocalized] directly — that helper wants
  /// a string-to-string map and this one holds a list too.
  Map<String, Map<String, String>> _stringsFor(String locale) {
    final out = <String, Map<String, String>>{};
    for (final key in _lookupOrder(locale)) {
      final value = copy[key];
      if (value is! Map) continue;
      final headline = value['headline'];
      if (headline is String && headline.isNotEmpty) {
        out[key] = {'headline': headline};
      }
    }
    return out;
  }

  static ContentRelease? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final version = json['version'] as String?;
    final build = (json['build_number'] as num?)?.toInt();
    if (id == null || version == null || build == null) return null;
    final copy = json['copy'];
    return ContentRelease(
      id: id,
      version: version,
      buildNumber: build,
      copy: copy is Map ? Map<String, dynamic>.from(copy) : const {},
    );
  }

  /// The note to show a client on [build], or null.
  ///
  /// **At or below the running build, never above it.** Play rolls a
  /// release out over days, so on the day of a release both populations
  /// exist at once and a note published for the new one would describe,
  /// to half the users, an app they do not have.
  ///
  /// [lastSeenBuild] is the highest build whose note this device has
  /// already shown. A fresh install passes the current build so somebody
  /// installing today does not get a changelog for a version they never
  /// ran — their whole app is new.
  static ContentRelease? newestFor(
    Iterable<ContentRelease> releases, {
    required int build,
    required int lastSeenBuild,
    required String locale,
  }) {
    ContentRelease? best;
    for (final release in releases) {
      if (release.buildNumber > build) continue;
      if (release.buildNumber <= lastSeenBuild) continue;
      if (!release.hasContentFor(locale)) continue;
      if (best == null || release.buildNumber > best.buildNumber) {
        best = release;
      }
    }
    return best;
  }
}

/// What kind of content landed. Unknown kinds are dropped rather than
/// guessed — the client would not know which screen the drop belongs to.
enum ContentDropKind {
  recipes,
  workoutPlan,
  challenge,
  seasonal;

  static ContentDropKind? fromToken(String? token) => switch (token) {
        'recipes' => recipes,
        'workout_plan' => workoutPlan,
        'challenge' => challenge,
        'seasonal' => seasonal,
        _ => null,
      };
}

/// Who a drop is for. Null or empty on every field means everybody.
class ContentAudience {
  const ContentAudience({
    this.goal,
    this.level,
    this.locale,
    this.hasEquipment,
  });

  final String? goal;
  final String? level;
  final String? locale;
  final bool? hasEquipment;
}

/// An announcement that new content landed.
class ContentDrop {
  const ContentDrop({
    required this.id,
    required this.slug,
    required this.kind,
    required this.copy,
    required this.publishedAt,
    this.route,
    this.expiresAt,
    this.targetGoals = const [],
    this.targetLevels = const [],
    this.targetLocales = const [],
    this.requiresEquipment,
  });

  final String id;
  final String slug;
  final ContentDropKind kind;
  final Map<String, Map<String, String>> copy;
  final DateTime publishedAt;

  /// In-app route. Null renders the card without a tap target rather
  /// than sending somebody nowhere.
  final String? route;

  final DateTime? expiresAt;
  final List<String> targetGoals;
  final List<String> targetLevels;
  final List<String> targetLocales;
  final bool? requiresEquipment;

  String? title(String locale) => pickLocalized(copy, locale, 'title');
  String? body(String locale) => pickLocalized(copy, locale, 'body');

  bool isLive(DateTime now) {
    if (publishedAt.isAfter(now)) return false;
    final expires = expiresAt;
    return expires == null || expires.isAfter(now);
  }

  /// Whether this drop is meant for [audience].
  ///
  /// Every unset dimension matches. That direction is deliberate: a drop
  /// with no targeting reaches everybody, and the failure a content
  /// table can least afford is an announcement that silently reaches
  /// nobody because a field was left blank.
  bool matches(ContentAudience audience) {
    if (!_matchesList(targetGoals, audience.goal)) return false;
    if (!_matchesList(targetLevels, audience.level)) return false;
    if (!_matchesLocale(audience.locale)) return false;
    final needs = requiresEquipment;
    if (needs != null && audience.hasEquipment != null) {
      if (needs != audience.hasEquipment) return false;
    }
    return true;
  }

  /// An unknown value fails a targeted drop and passes an untargeted
  /// one. Null means the app does not know this about the user — and
  /// guessing them into a targeted audience is how somebody with no
  /// equipment is sent a barbell program.
  static bool _matchesList(List<String> targets, String? value) {
    if (targets.isEmpty) return true;
    return value != null && targets.contains(value);
  }

  bool _matchesLocale(String? locale) {
    if (targetLocales.isEmpty) return true;
    if (locale == null) return false;
    if (targetLocales.contains(locale)) return true;
    // A drop targeted at `tr` reaches `tr-TR`, the same widening the
    // copy fallback makes. Targeting a region is possible by naming it.
    return targetLocales.contains(locale.split('-').first);
  }

  static ContentDrop? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final slug = json['slug'] as String?;
    final kind = ContentDropKind.fromToken(json['kind'] as String?);
    final publishedAt =
        DateTime.tryParse(json['published_at'] as String? ?? '');
    if (id == null || slug == null || kind == null || publishedAt == null) {
      return null;
    }
    final expires = json['expires_at'] as String?;
    return ContentDrop(
      id: id,
      slug: slug,
      kind: kind,
      copy: parseLocalizedCopy(json['copy']),
      publishedAt: publishedAt,
      route: json['route'] as String?,
      expiresAt: expires == null ? null : DateTime.tryParse(expires),
      targetGoals: _stringList(json['target_goals']),
      targetLevels: _stringList(json['target_levels']),
      targetLocales: _stringList(json['target_locales']),
      requiresEquipment: json['requires_equipment'] as bool?,
    );
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is String && entry.isNotEmpty) entry,
    ];
  }
}
