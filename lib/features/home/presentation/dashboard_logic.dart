/// Phase 2 (P-Risk) F09 · pure decision helpers extracted from the
/// DashboardScreen God-object so its inline logic is unit-testable and the
/// screen shrinks toward pure orchestration. These functions hold no Flutter
/// or provider dependencies — behaviour is identical to the inline code they
/// replaced (see dashboard_screen.dart).
///
/// (The larger structural decomposition — moving the celebration / prefetch
/// state into a dedicated provider facade — remains ongoing; it needs a
/// widget-test regression net before the stateful surface is reshaped.)
class DashboardLogic {
  const DashboardLogic._();

  /// The image URLs to warm into the disk cache on dashboard entry: the
  /// first [limit] candidate URLs that are non-null and http(s). Preserves
  /// order. Decoupled from PlannedMeal so it is trivially testable — the
  /// caller maps `plan.map((pm) => pm.recipe.imageUrl)`.
  static List<String> prefetchUrls(
    Iterable<String?> candidateUrls, {
    int limit = 6,
  }) {
    final out = <String>[];
    for (final url in candidateUrls.take(limit)) {
      if (url != null && url.startsWith('http')) out.add(url);
    }
    return out;
  }

  /// Badge ids that are unlocked but not yet celebrated.
  ///
  /// When [celebrated] is null (the first provider emission, before the
  /// celebrated set is seeded) nothing is pending — the caller seeds the
  /// set instead of replaying every existing unlock on cold start. This
  /// mirrors the original `unlocked.difference(celebrated ?? unlocked)`.
  static List<String> pendingBadgeCelebrations(
    Set<String> unlocked,
    Set<String>? celebrated,
  ) {
    if (celebrated == null) return const [];
    return unlocked.difference(celebrated).toList();
  }
}
