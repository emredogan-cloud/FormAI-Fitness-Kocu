import 'models/meal_entry.dart';

/// A nutrition-data source, behind an interface.
///
/// Open Food Facts is the MVP provider (founder decision, 2026-08-11) and
/// deliberately not the only one this code can ever talk to. The seam is
/// here rather than at the call sites because the two swaps we can
/// already foresee pull in different directions:
///
///   * **Replace** — a commercial provider (FatSecret, Edamam) with
///     better coverage of a market, which wants one implementation
///     substituted for another.
///   * **Combine** — Open Food Facts for packaged goods *plus* a
///     Turkish composition database for home cooking, which wants two
///     sources consulted in order.
///
/// [FoodDatabaseChain] covers the second case without any caller
/// learning that more than one source exists.
abstract class FoodDatabase {
  /// Human-readable id, used in logs and to attribute a result.
  String get providerId;

  /// Exact lookup by barcode. Returns null when the product is unknown —
  /// which is a normal outcome, not an error: Open Food Facts is
  /// community-contributed and its coverage is uneven by market.
  Future<FoodProduct?> lookupBarcode(String barcode);

  /// Free-text search, for manual entry.
  Future<List<FoodProduct>> search(String query, {int limit = 20});
}

/// A product as a nutrition source describes it.
///
/// Values are per 100 g/ml, because that is the one basis every provider
/// agrees on. Serving size is carried separately and is often absent —
/// which is why [toMealItem] takes the grams the *user* says they ate
/// rather than trusting a serving field that may not exist.
class FoodProduct {
  const FoodProduct({
    required this.name,
    required this.kcalPer100,
    required this.proteinPer100,
    required this.carbsPer100,
    required this.fatPer100,
    this.brand,
    this.barcode,
    this.servingGrams,
    this.providerId,
  });

  final String name;
  final String? brand;
  final String? barcode;

  final double kcalPer100;
  final double proteinPer100;
  final double carbsPer100;
  final double fatPer100;

  /// Grams in one serving, when the provider knows. Frequently null.
  final double? servingGrams;

  final String? providerId;

  String get displayName =>
      (brand == null || brand!.isEmpty) ? name : '$brand $name';

  /// Scale to an actual amount and produce a loggable item.
  ///
  /// Confidence is [ItemConfidence.high] and that is not a shortcut: a
  /// barcode is an exact identification and the nutrition panel is the
  /// manufacturer's own declaration. This is the one path in the feature
  /// where the numbers are read rather than estimated, which is exactly
  /// why the research doc routes packaged food here instead of through
  /// the vision model.
  MealItem toMealItem({required double grams, required String portionLabel}) {
    final factor = grams / 100.0;
    return MealItem(
      name: displayName,
      portionLabel: portionLabel,
      kcal: (kcalPer100 * factor).round(),
      proteinG: (proteinPer100 * factor).round(),
      carbsG: (carbsPer100 * factor).round(),
      fatG: (fatPer100 * factor).round(),
      confidence: ItemConfidence.high,
      barcode: barcode,
    );
  }
}

/// Consults several sources in order and takes the first answer.
///
/// This is the "combine" half of the seam. Order is priority: put the
/// source with the best coverage for the current market first, and a
/// broader fallback behind it.
///
/// A provider that throws is skipped rather than allowed to fail the
/// lookup — one source being down must not make a barcode unreadable
/// when another source knows it.
class FoodDatabaseChain implements FoodDatabase {
  const FoodDatabaseChain(this.sources);

  final List<FoodDatabase> sources;

  @override
  String get providerId => sources.map((s) => s.providerId).join('+');

  @override
  Future<FoodProduct?> lookupBarcode(String barcode) async {
    for (final source in sources) {
      try {
        final hit = await source.lookupBarcode(barcode);
        if (hit != null) return hit;
      } catch (_) {
        // Try the next source. See the class note.
      }
    }
    return null;
  }

  @override
  Future<List<FoodProduct>> search(String query, {int limit = 20}) async {
    final seen = <String>{};
    final out = <FoodProduct>[];
    for (final source in sources) {
      if (out.length >= limit) break;
      try {
        for (final p in await source.search(query, limit: limit - out.length)) {
          // De-duplicate across sources on name, so a product both
          // providers know does not appear twice in one list.
          final key = p.displayName.toLowerCase();
          if (seen.add(key)) out.add(p);
        }
      } catch (_) {
        // Skip this source.
      }
    }
    return out;
  }
}
