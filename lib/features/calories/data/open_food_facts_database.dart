import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/food_database.dart';

/// [FoodDatabase] backed by Open Food Facts.
///
/// Chosen for the MVP (founder decision, 2026-08-11) over TürKomp, whose
/// licence is unconfirmed, and over commercial providers, which would add
/// a billing relationship to a feature that already has one. Open Food
/// Facts is free, open-licensed, and its coverage is strongest exactly
/// where the vision model is weakest: packaged retail goods with a
/// printed nutrition panel.
///
/// Its coverage is also uneven and community-contributed, which is why a
/// miss returns null rather than throwing — see [FoodDatabase].
class OpenFoodFactsDatabase implements FoodDatabase {
  OpenFoodFactsDatabase({http.Client? client, Duration? timeout})
      : _client = client ?? http.Client(),
        _timeout = timeout ?? const Duration(seconds: 8);

  final http.Client _client;
  final Duration _timeout;

  static const _host = 'world.openfoodfacts.org'; // i18n-ignore — API host

  /// Open Food Facts asks every API consumer to identify itself, and
  /// answers anonymous traffic with rate limits. This is that
  /// identification — it is a courtesy their terms request, not a
  /// credential, so it is safe in the binary.
  static const _userAgent =
      'FormAI/1.0 (Android; contact via Play listing)'; // i18n-ignore — HTTP header

  /// Only the fields we actually read. Open Food Facts returns a very
  /// large document by default; asking for five fields keeps the response
  /// small on the mobile connections this runs over.
  static const _fields =
      // i18n-ignore — API field list
      'code,product_name,product_name_tr,brands,serving_quantity,nutriments';

  @override
  String get providerId => 'open_food_facts';

  @override
  Future<FoodProduct?> lookupBarcode(String barcode) async {
    final clean = barcode.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty || clean.length > 32) return null;

    final uri = Uri.https(_host, '/api/v2/product/$clean.json', {
      'fields': _fields,
    });

    final res = await _client.get(uri, headers: {
      'User-Agent': _userAgent, // i18n-ignore — HTTP header name
    }).timeout(_timeout);

    // 404 is the documented "we don't have this barcode" answer, and it
    // is an ordinary outcome — the caller falls back to manual entry.
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) return null;

    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) return null;
    if (body['status'] != 1) return null;

    final product = body['product'];
    if (product is! Map<String, dynamic>) return null;

    return _parse(product);
  }

  @override
  Future<List<FoodProduct>> search(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final uri = Uri.https(_host, '/api/v2/search', {
      'search_terms': trimmed,
      'fields': _fields,
      'page_size': limit.clamp(1, 50).toString(),
      'sort_by': 'popularity_key',
    });

    final res = await _client.get(uri, headers: {
      'User-Agent': _userAgent, // i18n-ignore — HTTP header name
    }).timeout(_timeout);
    if (res.statusCode != 200) return const [];

    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) return const [];

    final products = body['products'];
    if (products is! List) return const [];

    return products
        .whereType<Map<String, dynamic>>()
        .map(_parse)
        .whereType<FoodProduct>()
        .toList(growable: false);
  }

  FoodProduct? _parse(Map<String, dynamic> product) {
    // Turkish name first when the contributor supplied one — Open Food
    // Facts stores per-language names and the generic `product_name` is
    // whatever language the entry was created in.
    final name = _firstNonEmpty([
      product['product_name_tr'],
      product['product_name'],
    ]);
    if (name == null) return null;

    final nutriments = product['nutriments'];
    if (nutriments is! Map<String, dynamic>) return null;

    // A product with no energy value is not loggable. Everything else can
    // sensibly default to zero, but calories cannot: a zero there would
    // silently log a meal as free.
    final kcal = _energyKcal(nutriments);
    if (kcal == null) return null;

    return FoodProduct(
      name: name,
      brand: _firstNonEmpty([product['brands']]),
      barcode: _firstNonEmpty([product['code']]),
      kcalPer100: kcal,
      proteinPer100: _num(nutriments['proteins_100g']) ?? 0,
      carbsPer100: _num(nutriments['carbohydrates_100g']) ?? 0,
      fatPer100: _num(nutriments['fat_100g']) ?? 0,
      servingGrams: _num(product['serving_quantity']),
      providerId: providerId,
    );
  }

  /// Open Food Facts records energy in kcal *or* kJ depending on the
  /// contributor and the market — EU labels are legally kJ-first. Reading
  /// only `energy-kcal_100g` silently loses every EU-sourced entry, so
  /// fall back to converting the kJ value.
  double? _energyKcal(Map<String, dynamic> n) {
    final kcal = _num(n['energy-kcal_100g']);
    if (kcal != null && kcal > 0) return kcal;
    final kj = _num(n['energy-kj_100g']) ?? _num(n['energy_100g']);
    if (kj != null && kj > 0) return kj / 4.184;
    return null;
  }

  static double? _num(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  static String? _firstNonEmpty(List<Object?> candidates) {
    for (final c in candidates) {
      if (c is String && c.trim().isNotEmpty) return c.trim();
    }
    return null;
  }
}
