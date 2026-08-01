import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/utils/app_copy.dart';
import 'package:sixpack_ai/features/coach/domain/coach_context.dart';
import 'package:sixpack_ai/features/coach/providers/coach_providers.dart';

/// Phase 6 polish · the coach must never answer in the wrong language.
///
/// The bug was not one leak, it was four, and every one of them was a
/// Turkish string being handed to an English persona:
///
///   1. the onboarding name-greeting instruction,
///   2. the onboarding empathy instruction,
///   3. the entire user-profile context block,
///   4. the rolling summary, replayed as the coach's memory.
///
/// A model given an English system prompt and Turkish input picks a
/// language per turn, which is exactly what "sometimes Turkish,
/// sometimes English" looks like from outside. These tests pin each
/// input to the app's language so no single one can drift back.
final _turkish = RegExp(r'[ğışĞİŞ]|\b(kullanıcı|adını|hedef|seri|gün)\b',
    caseSensitive: false);
final _english =
    RegExp(r'\b(the|user|name|goal|streak|days)\b', caseSensitive: false);

CoachContext _ctx() => const CoachContext(
      hour: 9,
      name: 'Alex',
      goalLabel: 'get leaner',
      age: 30,
      heightCm: 178,
      weightKg: 74,
      streakDays: 3,
      completedDays: 5,
      todayDayNumber: 5,
      todayExerciseCount: 6,
      todayExerciseNames: ['Push-ups', 'Plank'],
      workoutMode: 'manual',
      firstCameraSession: true,
    );

void main() {
  tearDown(() => AppCopy.locale = const Locale('tr'));

  group('the profile context block', () {
    test('is Turkish for a Turkish app', () {
      final block = _ctx().toPromptContext(locale: 'tr');
      expect(_turkish.hasMatch(block), isTrue);
      expect(block, contains('Kullanıcı profili'));
    });

    test('is English for an English app', () {
      final block = _ctx().toPromptContext(locale: 'en');
      expect(block, contains('User profile'));
      expect(_english.hasMatch(block), isTrue);
      // The whole point: not one Turkish word reaches the model.
      expect(_turkish.hasMatch(block), isFalse,
          reason: 'the English context block still carries Turkish:\n$block');
    });

    test('an unknown locale falls back to Turkish, not to a mixture', () {
      expect(_ctx().toPromptContext(locale: 'de'), contains('Kullanıcı'));
    });

    test('every branch of the block is covered in both languages', () {
      // The context is built with conditionals — equipment, today's
      // exercises, manual mode, first camera session. A branch that only
      // exists in one language is a leak that appears for some users.
      final tr = _ctx().toPromptContext(locale: 'tr');
      final en = _ctx().toPromptContext(locale: 'en');
      expect(tr.split('\n').length, en.split('\n').length,
          reason: 'the two blocks emit a different number of lines, so one '
              'branch is missing a translation:\nTR:\n$tr\n\nEN:\n$en');
    });
  });

  group('the onboarding instructions', () {
    test('follow the app language, not the device', () {
      AppCopy.locale = const Locale('en');
      expect(onboardingNamePrompt('Alex'), contains('gave their name'));
      expect(_turkish.hasMatch(onboardingNamePrompt('Alex')), isFalse);

      AppCopy.locale = const Locale('tr');
      expect(onboardingNamePrompt('Deniz'), contains('adını söyledi'));
    });

    test('the empathy turn carries the user\'s own words in their language',
        () {
      AppCopy.locale = const Locale('en');
      final prompt = onboardingReframePrompt('Alex', 'I feel tired');
      expect(prompt, contains('I feel tired'));
      expect(_turkish.hasMatch(prompt), isFalse,
          reason: 'an English answer inside a Turkish instruction makes the '
              'turn bilingual before the model starts:\n$prompt');
    });
  });

  group('the rolling memory', () {
    test('is discarded when the language changes', () async {
      // The summary is model-generated prose replayed as the coach's
      // memory on every later turn. Turkish memory under an English
      // persona is a block of Turkish sitting in the system prompt
      // forever — the model reads it as permission.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = CoachMemoryStore(prefs);

      AppCopy.locale = const Locale('tr');
      await store.write('- Kullanıcı sabahları antrenman yapmayı seviyor');
      expect(store.read(), isNotEmpty);

      AppCopy.locale = const Locale('en');
      expect(store.read(), isEmpty,
          reason: 'Turkish memory survived into an English session');

      AppCopy.locale = const Locale('tr');
      expect(store.read(), isNotEmpty,
          reason: 'switching back should not have destroyed it');
    });
  });

  test('the coach locale follows the app', () {
    AppCopy.locale = const Locale('en');
    expect(coachLocale, 'en');
    AppCopy.locale = const Locale('tr');
    expect(coachLocale, 'tr');
  });
}
