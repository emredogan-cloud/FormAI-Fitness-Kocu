import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sixpack_ai/features/calories/data/open_food_facts_database.dart';
import 'package:sixpack_ai/features/calories/domain/food_database.dart';
import 'package:sixpack_ai/features/calories/domain/models/meal_entry.dart';
import 'package:sixpack_ai/features/calories/domain/models/scan_result.dart';

/// The calorie tracker's honesty and correctness invariants.
///
/// These are chosen for what breaks *silently*. A broken dashboard is
/// obvious the moment anyone opens it; a confidence value that quietly
/// rounds upward, or a European product whose calories read as zero, ship
/// looking fine and are wrong for months.
void main() {
  group('confidence never rounds up', () {
    test('an unrecognised confidence degrades to low, not high', () {
      // The whole feature rests on a documented 15-25% error rate being
      // visible to the user. A value we do not recognise is by
      // definition something we are unsure of, so the safe default is
      // the *least* confident one. Defaulting to high — or to medium —
      // would launder an unknown into a claim.
      expect(ItemConfidence.fromWire('wildly-unexpected'), ItemConfidence.low);
      expect(ItemConfidence.fromWire(null), ItemConfidence.low);
      expect(ItemConfidence.fromWire(''), ItemConfidence.low);
    });

    test('known values still round-trip', () {
      for (final c in ItemConfidence.values) {
        expect(ItemConfidence.fromWire(c.wire), c);
      }
    });

    test('a meal is uncertain when any single item is', () {
      MealItem item(ItemConfidence c) => MealItem(
            name: 'x',
            portionLabel: '1',
            kcal: 10,
            proteinG: 1,
            carbsG: 1,
            fatG: 1,
            confidence: c,
          );

      MealEntry meal(List<ItemConfidence> confidences) => MealEntry(
            id: 'm',
            loggedFor: DateTime(2026, 8, 11),
            slot: MealSlot.lunch,
            source: MealSource.aiScan,
            items: confidences.map(item).toList(),
          );

      expect(
        meal([ItemConfidence.high, ItemConfidence.high]).hasLowConfidenceItem,
        isFalse,
      );
      // One uncertain item makes the total uncertain — a sum cannot be
      // more precise than its least precise term.
      expect(
        meal([ItemConfidence.high, ItemConfidence.low]).hasLowConfidenceItem,
        isTrue,
      );
    });
  });

  group('wire enums are database values, not display strings', () {
    test('slot and source wire values match migration 028 CHECK values', () {
      // Translating any of these makes Postgres reject the insert. The
      // constraint lives in the database, so the test names the exact
      // strings rather than deriving them from the enum.
      expect(MealSlot.values.map((s) => s.wire).toSet(),
          {'breakfast', 'lunch', 'dinner', 'snack'});
      expect(MealSource.values.map((s) => s.wire).toSet(),
          {'ai_scan', 'barcode', 'manual'});
      expect(ItemConfidence.values.map((c) => c.wire).toSet(),
          {'high', 'medium', 'low'});
    });

    test('an unknown slot degrades rather than throwing', () {
      expect(MealSlot.fromWire('brunch'), MealSlot.snack);
      expect(MealSource.fromWire('telepathy'), MealSource.manual);
    });
  });

  group('numeric parsing survives what PostgREST actually returns', () {
    test('numeric columns arrive as String, num or int and all work', () {
      // `numeric(7,1)` comes back as a String over PostgREST while
      // `integer` comes back as an int. Reading either one with a plain
      // cast throws on real data.
      final item = MealItem.fromJson({
        'name': 'Yulaf',
        'portion_label': '1 kase',
        'kcal': 150,
        'protein_g': '5.4',
        'carbs_g': 27.6,
        'fat_g': 3,
        'confidence': 'high',
      });
      expect(item.kcal, 150);
      expect(item.proteinG, 5);
      expect(item.carbsG, 28);
      expect(item.fatG, 3);
    });

    test('a missing numeric is zero, not a crash', () {
      final item = MealItem.fromJson({'name': 'x'});
      expect(item.kcal, 0);
      expect(item.proteinG, 0);
      expect(item.confidence, ItemConfidence.low);
    });
  });

  group('DailyTotals', () {
    MealEntry meal(MealSlot slot, int kcal) => MealEntry(
          id: '$slot-$kcal',
          loggedFor: DateTime(2026, 8, 11),
          slot: slot,
          source: MealSource.manual,
          kcal: kcal,
          proteinG: 10,
          carbsG: 20,
          fatG: 5,
          items: const [],
        );

    test('sums across meals and splits by slot', () {
      final totals = DailyTotals.from([
        meal(MealSlot.breakfast, 300),
        meal(MealSlot.lunch, 600),
        meal(MealSlot.lunch, 150),
      ]);

      expect(totals.kcal, 1050);
      expect(totals.proteinG, 30);
      expect(totals.kcalForSlot(MealSlot.lunch), 750);
      expect(totals.kcalForSlot(MealSlot.dinner), 0);
    });

    test('an empty day is zero, not null', () {
      expect(DailyTotals.from(const []).kcal, 0);
      expect(DailyTotals.empty.meals, isEmpty);
    });
  });

  group('scan failures map to distinct, actionable outcomes', () {
    test('each server error code maps to its own kind', () {
      expect(ScanFailure.fromCode('scan_limit_reached').kind,
          ScanFailureKind.quotaExhausted);
      expect(ScanFailure.fromCode('unauthenticated').kind,
          ScanFailureKind.unauthenticated);
      expect(ScanFailure.fromCode('image_too_large').kind,
          ScanFailureKind.imageTooLarge);
      expect(ScanFailure.fromCode('refused').kind, ScanFailureKind.refused);
      expect(ScanFailure.fromCode('scanner_unconfigured').kind,
          ScanFailureKind.unconfigured);
      expect(
          ScanFailure.fromCode('model_error').kind, ScanFailureKind.upstream);
    });

    test('a bodyless 429 is still recognised as the quota', () {
      // A gateway that rejects before reaching our function sends no
      // error code. Falling through to "something went wrong" there
      // would offer a retry that is guaranteed to fail.
      expect(ScanFailure.fromCode(null, status: 429).kind,
          ScanFailureKind.quotaExhausted);
      expect(ScanFailure.fromCode(null, status: 401).kind,
          ScanFailureKind.unauthenticated);
    });

    test('only failures a retry could fix are retryable', () {
      // A retry button that cannot work is worse than no button.
      expect(const ScanFailure(kind: ScanFailureKind.upstream).isRetryable,
          isTrue);
      expect(
          const ScanFailure(kind: ScanFailureKind.network).isRetryable, isTrue);
      expect(
          const ScanFailure(kind: ScanFailureKind.quotaExhausted).isRetryable,
          isFalse);
      expect(const ScanFailure(kind: ScanFailureKind.refused).isRetryable,
          isFalse);
    });
  });

  group('ScanQuota', () {
    test('unknown is distinguishable from exhausted', () {
      // Telling a user they have no scans left because we could not
      // reach the server is a worse failure than saying nothing.
      expect(ScanQuota.unknown.isKnown, isFalse);
      expect(ScanQuota.unknown.isExhausted, isFalse);
      expect(
          const ScanQuota(limit: 2, used: 2, remaining: 0).isExhausted, isTrue);
    });

    test('the free tier is recognised for the upgrade prompt', () {
      expect(
          const ScanQuota(limit: 2, used: 0, remaining: 2).looksFree, isTrue);
      expect(const ScanQuota(limit: 20, used: 0, remaining: 20).looksFree,
          isFalse);
    });
  });

  group('FoodProduct scaling', () {
    const product = FoodProduct(
      name: 'Yoğurt',
      brand: 'Sütaş',
      kcalPer100: 61,
      proteinPer100: 3.5,
      carbsPer100: 4.7,
      fatPer100: 3.3,
    );

    test('scales per-100g values to the amount actually eaten', () {
      final item = product.toMealItem(grams: 200, portionLabel: '1 kase');
      expect(item.kcal, 122);
      expect(item.proteinG, 7);
      expect(item.name, 'Sütaş Yoğurt');
    });

    test('a barcode result is high confidence, and that is earned', () {
      // This is the one path where numbers are read rather than
      // estimated: an exact product plus the manufacturer's own panel.
      final item = product.toMealItem(grams: 100, portionLabel: '100 g');
      expect(item.confidence, ItemConfidence.high);
    });
  });

  group('Open Food Facts parsing', () {
    OpenFoodFactsDatabase dbReturning(String body, {int status = 200}) =>
        OpenFoodFactsDatabase(
          client: MockClient(
            (_) async => http.Response(body, status,
                headers: {'content-type': 'application/json'}),
          ),
        );

    test('converts a kJ-only product rather than reading it as zero', () async {
      // EU nutrition labels are legally kJ-first, so a large share of
      // European entries have no `energy-kcal_100g` at all. Reading only
      // the kcal field would silently log those products as free.
      final db = dbReturning('''
        {"status":1,"product":{"code":"1","product_name":"Biscuit",
         "nutriments":{"energy-kj_100g":2000,"proteins_100g":6,
                       "carbohydrates_100g":60,"fat_100g":20}}}
      ''');
      final p = await db.lookupBarcode('1');
      expect(p, isNotNull);
      expect(p!.kcalPer100, closeTo(478, 1)); // 2000 / 4.184
    });

    test('prefers the Turkish name when a contributor supplied one', () async {
      final db = dbReturning('''
        {"status":1,"product":{"code":"2","product_name":"Ayran",
         "product_name_tr":"Ayran (yerli)",
         "nutriments":{"energy-kcal_100g":37}}}
      ''');
      final p = await db.lookupBarcode('2');
      expect(p!.name, 'Ayran (yerli)');
    });

    test('a product with no energy value at all is rejected', () async {
      // Every other macro can default to zero; calories cannot, because
      // a zero there logs the meal as free rather than as unknown.
      final db = dbReturning('''
        {"status":1,"product":{"code":"3","product_name":"Mystery",
         "nutriments":{"proteins_100g":5}}}
      ''');
      expect(await db.lookupBarcode('3'), isNull);
    });

    test('an unknown barcode is null, not an exception', () async {
      // Coverage is uneven by market — a miss is an ordinary outcome the
      // caller handles by offering manual entry.
      final db = dbReturning('{"status":0}', status: 404);
      expect(await db.lookupBarcode('404'), isNull);
    });

    test('non-numeric barcodes are rejected before any request', () async {
      final db = OpenFoodFactsDatabase(
        client: MockClient((_) async => throw StateError('no request')),
      );
      expect(await db.lookupBarcode('not-a-barcode'), isNull);
    });
  });

  group('FoodDatabaseChain', () {
    test('falls through to the next source on a miss', () async {
      final chain = FoodDatabaseChain([
        _StubDatabase('empty', null),
        _StubDatabase(
            'hit',
            const FoodProduct(
              name: 'Found',
              kcalPer100: 100,
              proteinPer100: 0,
              carbsPer100: 0,
              fatPer100: 0,
            )),
      ]);
      expect((await chain.lookupBarcode('1'))!.name, 'Found');
    });

    test('a throwing source is skipped, not fatal', () async {
      // One provider being down must not make a barcode unreadable when
      // another provider knows it.
      final chain = FoodDatabaseChain([
        _ThrowingDatabase(),
        _StubDatabase(
            'hit',
            const FoodProduct(
              name: 'Survivor',
              kcalPer100: 100,
              proteinPer100: 0,
              carbsPer100: 0,
              fatPer100: 0,
            )),
      ]);
      expect((await chain.lookupBarcode('1'))!.name, 'Survivor');
    });

    test('search de-duplicates across sources by display name', () async {
      const shared = FoodProduct(
        name: 'Ayran',
        kcalPer100: 37,
        proteinPer100: 0,
        carbsPer100: 0,
        fatPer100: 0,
      );
      final chain = FoodDatabaseChain([
        _StubDatabase('a', null, searchResults: const [shared]),
        _StubDatabase('b', null, searchResults: const [shared]),
      ]);
      expect((await chain.search('ayran')).length, 1);
    });
  });
}

class _StubDatabase implements FoodDatabase {
  const _StubDatabase(
    this.providerId,
    this._hit, {
    this.searchResults = const [],
  });

  @override
  final String providerId;
  final FoodProduct? _hit;
  final List<FoodProduct> searchResults;

  @override
  Future<FoodProduct?> lookupBarcode(String barcode) async => _hit;

  @override
  Future<List<FoodProduct>> search(String query, {int limit = 20}) async =>
      searchResults;
}

class _ThrowingDatabase implements FoodDatabase {
  @override
  String get providerId => 'throws';

  @override
  Future<FoodProduct?> lookupBarcode(String barcode) async =>
      throw StateError('provider down');

  @override
  Future<List<FoodProduct>> search(String query, {int limit = 20}) async =>
      throw StateError('provider down');
}
