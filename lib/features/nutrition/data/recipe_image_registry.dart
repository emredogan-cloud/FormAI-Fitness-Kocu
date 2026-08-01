import 'package:flutter/services.dart'
    show AssetBundle, AssetManifest, rootBundle;

import '../../../core/utils/app_logger.dart';

/// Roadmap Phase 7 · which photograph a recipe tile falls back to.
///
/// Phase 7 adds 100 recipes and no photography. `image_url` is non-null
/// on all 292 existing rows, so a tile with nothing in it would be the
/// most visible regression of the whole phase — and the daily menu puts
/// four or five of these on the home screen every morning.
///
/// Same shape as `WorkoutBackgroundRegistry`, and for the same reason:
///
///   1. **The recipe's own bundled photograph**, if one has been dropped
///      at `photos/meals/<slug>.webp`.
///   2. **Its meal type's cover**, which already ships — the five
///      `budget_cover_*.webp` files the quick-meals strip uses. Real
///      food photography, so the catalogue looks finished before a
///      single new file exists.
///   3. Nothing, and the caller paints its branded gradient.
///
/// **Step 1 is a lookup against the bundle's own asset manifest, not a
/// list in this file.** Dropping `overnight-protein-oats.webp` into
/// `photos/meals/` and building is the entire procedure — no slug to
/// register, no code review, and no chance of a file that ships in the
/// APK and is never drawn.
///
/// The network image still wins when it resolves: these are fallbacks
/// painted underneath, not replacements. A recipe whose photograph has
/// been uploaded to Supabase Storage shows that photograph; one whose
/// has not shows its meal type's, which is a picture of food rather than
/// a gradient with a logo on it.
///
/// `docs/nutrition/MEAL_IMAGE_REQUESTS.md` lists every recipe currently
/// resolving to step 2, with the prompt to generate it.
class RecipeImageRegistry {
  const RecipeImageRegistry._();

  static const String mealDir = 'photos/meals/';

  /// One cover per `meal_type`, already bundled and already shipping on
  /// the quick-meals dashboard strip. The map is total over the five
  /// tokens, so [fallbackFor] can only return null for a meal type the
  /// server invented.
  static const Map<String, String> mealTypeCover = {
    'breakfast': '${mealDir}budget_cover_breakfast.webp',
    'lunch': '${mealDir}budget_cover_lunch.webp',
    'dinner': '${mealDir}budget_cover_dinner.webp',
    'snack': '${mealDir}budget_cover_snack.webp',
    'dessert': '${mealDir}budget_cover_dessert.webp',
  };

  static Set<String> _bundled = const {};
  static bool _loaded = false;

  /// True once [warmUp] has resolved. Before that, [fallbackFor] answers
  /// with the meal-type cover — a real photograph, so nothing flashes
  /// through empty.
  static bool get isWarm => _loaded;

  /// Reads the asset manifest once. Safe to call repeatedly, and safe
  /// never to call: every failure degrades to the meal-type cover.
  static Future<void> warmUp({AssetBundle? bundle}) async {
    if (_loaded) return;
    try {
      final manifest =
          await AssetManifest.loadFromAssetBundle(bundle ?? rootBundle);
      _bundled =
          manifest.listAssets().where((a) => a.startsWith(mealDir)).toSet();
      _loaded = true;
      AppLogger.info(
        'meal images: ${_bundled.length} bundled',
        category: 'nutrition',
      );
    } catch (e) {
      AppLogger.warning(
        'meal image manifest unreadable — using meal-type covers',
        category: 'nutrition',
        data: {'error': e.toString()},
      );
    }
  }

  /// The best local asset for a recipe, or null when even the meal type
  /// is unrecognised.
  static String? fallbackFor({String? slug, String? mealType}) =>
      ownImageFor(slug) ?? mealTypeCover[mealType];

  /// The recipe's *own* bundled photograph, or null when none exists.
  ///
  /// Split out from [fallbackFor] so the request document can be
  /// generated from the gap, and so a test can assert the gap without
  /// asserting the fallback.
  static String? ownImageFor(String? slug) {
    if (slug == null || slug.isEmpty) return null;
    final path = '$mealDir$slug.webp';
    return _bundled.contains(path) ? path : null;
  }

  /// Test seam. Production reads the manifest; tests state the contents.
  static void debugSeed(Set<String> assets) {
    _bundled = assets;
    _loaded = true;
  }

  static void debugReset() {
    _bundled = const {};
    _loaded = false;
  }
}
