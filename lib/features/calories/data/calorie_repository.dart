import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_copy.dart';
import '../domain/models/meal_entry.dart';
import '../domain/models/scan_result.dart';

/// Data access for the AI calorie tracker.
///
/// Two very different surfaces behind one class, on purpose: the meal
/// CRUD talks to PostgREST, and the scan talks to the `food-scan` edge
/// function. Callers should not have to know which is which — from the
/// UI's side both are "ask the server about food".
class CalorieRepository {
  CalorieRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // ── Meals ───────────────────────────────────────────────────────────

  /// Every meal logged for [day], newest first, with items attached.
  ///
  /// `logged_for` is a plain date, so it is compared as one. Passing a
  /// timestamp here would silently match nothing for users east of UTC.
  Future<List<MealEntry>> mealsForDay(DateTime day) async {
    final rows = await _client
        .from('meal_entries')
        .select('*, meal_items(*)')
        .eq('logged_for', _dateOnly(day))
        .order('created_at', ascending: true);

    return (rows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(MealEntry.fromJson)
        .toList(growable: false);
  }

  /// Insert a meal and its items.
  ///
  /// Not a transaction, and it does not need to be: the items carry an
  /// `on delete cascade` to the meal, so the failure mode of a partial
  /// write is an empty meal the user can delete — not an orphan. Wrapping
  /// this in an RPC to gain atomicity would buy very little and cost a
  /// second place where the insert shape is written down.
  Future<String> logMeal({
    required DateTime day,
    required MealSlot slot,
    required MealSource source,
    required List<MealItem> items,
    String? note,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('logMeal requires a signed-in user');
    }

    final inserted = await _client
        .from('meal_entries')
        .insert({
          'user_id': userId,
          'logged_for': _dateOnly(day),
          'meal_slot': slot.wire,
          'source': source.wire,
          if (note != null && note.isNotEmpty) 'note': note,
        })
        .select('id')
        .single();

    final mealId = inserted['id'] as String;

    if (items.isNotEmpty) {
      await _client.from('meal_items').insert([
        for (var i = 0; i < items.length; i++) items[i].toInsertJson(mealId, i),
      ]);
    }

    return mealId;
  }

  Future<void> deleteMeal(String mealId) =>
      _client.from('meal_entries').delete().eq('id', mealId);

  /// Replace one item's numbers after the user corrects them.
  ///
  /// Always sets `was_edited`, which is the point: an edit is the single
  /// most useful signal the feature produces. A food with a high edit
  /// rate is one the prompt or the nutrition source is wrong about, and
  /// without this flag that is invisible.
  Future<void> updateItem(String itemId, MealItem item) =>
      _client.from('meal_items').update({
        'name': item.name,
        'portion_label': item.portionLabel,
        'kcal': item.kcal,
        'protein_g': item.proteinG,
        'carbs_g': item.carbsG,
        'fat_g': item.fatG,
        'confidence': item.confidence.wire,
        'was_edited': true,
      }).eq('id', itemId);

  Future<void> deleteItem(String itemId) =>
      _client.from('meal_items').delete().eq('id', itemId);

  // ── Scanning ────────────────────────────────────────────────────────

  /// Today's scan allowance, without consuming one.
  ///
  /// Read from the server rather than counted locally. The number the UI
  /// shows and the number the limit enforces have to be the same number,
  /// and only one of them can be authoritative.
  Future<ScanQuota> quota() async {
    final rows = await _client.rpc('food_scan_quota');
    final row = (rows is List && rows.isNotEmpty) ? rows.first : rows;
    if (row is! Map<String, dynamic>) return ScanQuota.unknown;
    return ScanQuota(
      limit: (row['scan_limit'] as num?)?.toInt() ?? 0,
      used: (row['used'] as num?)?.toInt() ?? 0,
      remaining: (row['remaining'] as num?)?.toInt() ?? 0,
    );
  }

  /// Send a prepared image to the scanner.
  ///
  /// [jpegBytes] must already be downscaled and re-encoded by the caller —
  /// see `CalorieImagePrep`. Doing it here would be too late: the point of
  /// preparing on-device is that the full-resolution original, with its
  /// EXIF, never leaves the handset.
  ///
  /// Every failure comes back as a typed [ScanFailure] rather than an
  /// exception, because every one of them has a different thing for the
  /// UI to say — and "the AI timed out" and "you are out of scans today"
  /// must not collapse into the same message.
  Future<ScanOutcome> scan(List<int> jpegBytes) async {
    try {
      final res = await _client.functions.invoke(
        'food-scan',
        body: {
          'image': base64Encode(jpegBytes),
          'media_type': 'image/jpeg',
          'locale': AppCopy.locale.languageCode,
        },
      );

      final data = res.data;
      final map = data is String
          ? jsonDecode(data) as Map<String, dynamic>
          : (data as Map).cast<String, dynamic>();

      if (res.status == 200 && map['error'] == null) {
        return ScanOutcome.success(FoodScanResult.fromJson(map));
      }
      return ScanOutcome.failure(
        ScanFailure.fromCode(
          map['error'] as String?,
          status: res.status,
          scanLimit: (map['scan_limit'] as num?)?.toInt(),
        ),
      );
    } on FunctionException catch (e) {
      // `functions.invoke` throws on non-2xx, so the interesting cases —
      // 429 over quota, 401, 502 — arrive here rather than above.
      final details = e.details;
      final map = details is Map ? details.cast<String, dynamic>() : null;
      return ScanOutcome.failure(
        ScanFailure.fromCode(
          map?['error'] as String?,
          status: e.status,
          scanLimit: (map?['scan_limit'] as num?)?.toInt(),
        ),
      );
    } catch (_) {
      return const ScanOutcome.failure(
          ScanFailure(kind: ScanFailureKind.network));
    }
  }

  /// Postgres `date` wants `YYYY-MM-DD` and nothing else.
  static String _dateOnly(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
