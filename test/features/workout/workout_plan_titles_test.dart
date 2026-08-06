import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/workout/domain/workout_plan_titles.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';
import 'package:sixpack_ai/l10n/app_localizations_en.dart';
import 'package:sixpack_ai/l10n/app_localizations_tr.dart';

/// The plan catalogue and its title table are two independent lists that
/// have to agree, which is the shape of defect this repository keeps
/// finding: `league_test.dart` reads the leaderboard SQL, the
/// continuation test reads the generator's overload constant, and the AI
/// report test reads the migration's check constraint. Same idea here —
/// the templates are the source of truth for which plans exist, so they
/// are read out of the file rather than restated.
///
/// Without this, adding a 53rd plan renders its raw id as a card title
/// in both languages and nothing fails.
void main() {
  late Set<String> templateIds;

  setUpAll(() {
    final src = File('lib/features/workout/data/workout_repository.dart')
        .readAsStringSync();
    templateIds = RegExp(r"_PlanTemplate\(\s*\n\s*id: '([^']+)'")
        .allMatches(src)
        .map((m) => m.group(1)!)
        .toSet();
  });

  test('the templates parse at all', () {
    // If the file is reshaped so the regex stops matching, every other
    // assertion here passes vacuously. Guard the guard.
    expect(templateIds.length, kWorkoutPlanTitleCount);
  });

  test('every plan has a title in both languages', () {
    final en = AppLocalizationsEn();
    final tr = AppLocalizationsTr();
    for (final id in templateIds) {
      expect(workoutPlanTitle(en, id), isNotNull,
          reason: '$id has no English title — its card would render "$id"');
      expect(workoutPlanTitle(tr, id), isNotNull,
          reason: '$id has no Turkish title');
      expect(workoutPlanTitle(en, id), isNotEmpty);
      expect(workoutPlanTitle(tr, id), isNotEmpty);
    }
  });

  test('no title survived untranslated', () {
    // The whole point of the change: an English reader was seeing
    // "Ekipmanlı Göğüs Gücü". If a key is added to `app_en.arb` by
    // copying the Turkish across, this catches it — no English plan
    // title may carry a letter that only Turkish has.
    final en = AppLocalizationsEn();
    final turkishOnly = RegExp('[çğıöşüÇĞİÖŞÜ]');
    for (final id in templateIds) {
      final title = workoutPlanTitle(en, id)!;
      expect(turkishOnly.hasMatch(title), isFalse,
          reason: '$id\'s English title is "$title"');
    }
  });

  test('an unknown id resolves to null rather than throwing', () {
    expect(workoutPlanTitle(AppLocalizationsEn(), 'not_a_plan'), isNull);
  });

  group('the difficulty token renders a label, never a raw enum', () {
    test('English', () {
      final l10n = AppLocalizationsEn();
      expect(WorkoutLevel.beginner.label(l10n), 'Beginner');
      expect(WorkoutLevel.intermediate.label(l10n), 'Intermediate');
      expect(WorkoutLevel.advanced.label(l10n), 'Advanced');
    });

    test('Turkish keeps the catalogue\'s own wording', () {
      final l10n = AppLocalizationsTr();
      // "Orta düzey", which is what these cards have always said —
      // `difficultyIntermediate` is "Orta Seviye" and belongs elsewhere.
      expect(WorkoutLevel.intermediate.label(l10n), 'Orta düzey');
    });

    test('every level is reachable from the templates', () {
      final src = File('lib/features/workout/data/workout_repository.dart')
          .readAsStringSync();
      for (final level in WorkoutLevel.values) {
        expect(src.contains('WorkoutLevel.${level.name}'), isTrue,
            reason: 'no template uses ${level.name}, so it is dead');
      }
    });
  });

  test('the plan summary carries no hardcoded unit', () {
    // It used to be `'$level · $durationMinutes Dk'` — a Turkish
    // abbreviation concatenated onto a localized label, which is both
    // halves of the house rule broken in one line.
    final model = File('lib/features/workout/models/workout_plan_model.dart')
        .readAsStringSync();
    expect(model.contains('Dk'), isFalse);
    expect(model.contains('minutesLevelLine'), isTrue);
  });

  test('AppLocalizations exposes the count the table claims', () {
    // Cheap cross-check that the generated class really carries the keys.
    final en = AppLocalizationsEn();
    expect(en.planTitleCoreSteelAbs, 'Steel Abs');
    expect(AppLocalizationsTr().planTitleCoreSteelAbs, 'Çelik Gibi Karın');
    expect(AppLocalizations.supportedLocales.length, greaterThanOrEqualTo(2));
  });
}
