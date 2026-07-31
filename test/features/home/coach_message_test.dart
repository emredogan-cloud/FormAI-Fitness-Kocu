import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/home/domain/coach_message.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// The dashboard coach line must reflect the user's actual weekly state +
/// time of day (it used to be one hardcoded string). This pins each branch
/// so the "aware coach" behaviour can't silently regress — and documents
/// the exact contract a future LLM implementation must preserve.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  test('goal reached → celebration', () {
    expect(weeklyCoachLine(l10n: l10n, completed: 3, target: 3, hour: 10),
        contains('tamamladın'));
    expect(weeklyCoachLine(l10n: l10n, completed: 4, target: 3, hour: 10),
        contains('tamamladın'));
  });

  test('one workout left → push', () {
    expect(weeklyCoachLine(l10n: l10n, completed: 2, target: 3, hour: 14),
        contains('Bir antrenman kaldı'));
  });

  test('nothing done yet is time-of-day aware', () {
    expect(weeklyCoachLine(l10n: l10n, completed: 0, target: 3, hour: 8),
        contains('Güne güçlü başla'));
    expect(weeklyCoachLine(l10n: l10n, completed: 0, target: 3, hour: 20),
        contains('Gün bitmeden'));
    expect(weeklyCoachLine(l10n: l10n, completed: 0, target: 3, hour: 14),
        contains('ilk hareketi'));
  });

  test('mid-week progress shows the count', () {
    final line = weeklyCoachLine(l10n: l10n, completed: 1, target: 5, hour: 12);
    expect(line, contains('1/5'));
  });

  test('never empty for any plausible input', () {
    for (final c in [0, 1, 2, 5]) {
      for (final t in [0, 3, 5]) {
        for (final h in [0, 9, 13, 19, 23]) {
          expect(
              weeklyCoachLine(l10n: l10n, completed: c, target: t, hour: h)
                  .trim(),
              isNotEmpty);
        }
      }
    }
  });
}
