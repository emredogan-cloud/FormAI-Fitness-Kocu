import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/coach/data/ai_report_repository.dart';
import 'package:sixpack_ai/features/coach/presentation/ai_report_sheet.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Google Play's AI-Generated Content policy requires an in-app way to
/// report offensive AI output. These tests pin the two halves that can
/// silently drift: the tokens the client writes against the constraint
/// the database enforces, and the sheet actually returning a reason.
///
/// The first group is the cross-check pattern this repository already
/// uses for the leaderboard caps (`league_test.dart` reads `020`) and for
/// the continuation overload (a test reads it out of the generator). Two
/// copies of a mapping are only safe when something proves they agree —
/// and a `check` constraint that disagrees with the enum fails at
/// runtime, on a user who is trying to report something, which is the
/// worst possible moment to discover it.
void main() {
  late String migration;

  setUpAll(() {
    migration = File('supabase/migrations/027_ai_content_reports.sql')
        .readAsStringSync();
  });

  /// The tokens inside one `check (col in ( ... ))` list.
  Set<String> checkTokens(String column) {
    final m = RegExp(
      '$column\\s+text[^,]*?check\\s*\\(\\s*$column\\s+in\\s*\\(([^)]*)\\)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(migration);
    expect(m, isNotNull, reason: 'no check constraint found for $column');
    return RegExp("'([a-z_]+)'")
        .allMatches(m!.group(1)!)
        .map((t) => t.group(1)!)
        .toSet();
  }

  group('the client and the database agree on the tokens', () {
    test('every report reason is accepted by the check constraint', () {
      expect(
        AiReportReason.values.map((r) => r.token).toSet(),
        checkTokens('reason'),
      );
    });

    test('every surface is accepted by the check constraint', () {
      expect(
        AiReportSurface.values.map((s) => s.token).toSet(),
        checkTokens('surface'),
      );
    });

    test('the message cap the client clamps to is the column cap', () {
      expect(
        migration.contains(
            'char_length(message_text) between 1 and ${AiReportRepository.maxMessageLength}'),
        isTrue,
        reason: 'the client truncates to maxMessageLength so the insert '
            'never fails a constraint instead of filing a report; if the '
            'column changes and the constant does not, it will',
      );
    });
  });

  group('the reasons are the ones the policy needs', () {
    test('harmful advice is offered, and it is offered first', () {
      // Not cosmetic. This app talks to people about training and eating,
      // so "the model told me to train through chest pain" is the report
      // that can matter most, and burying it under `other` loses it.
      expect(AiReportReason.values.first, AiReportReason.harmfulAdvice);
    });

    test('offensive content has its own reason', () {
      // The literal subject of the Play policy clause.
      expect(AiReportReason.values, contains(AiReportReason.offensive));
    });
  });

  group('the sheet', () {
    Widget host() => MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showAiReportSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

    testWidgets('offers every reason', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      for (final label in [
        l10n.coachReportHarmfulAdvice,
        l10n.coachReportOffensive,
        l10n.coachReportInaccurate,
        l10n.coachReportOther,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('returns the reason that was tapped', (tester) async {
      AiReportReason? picked;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async =>
                    picked = await showAiReportSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.coachReportOffensive));
      await tester.pumpAndSettle();

      expect(picked, AiReportReason.offensive);
    });

    testWidgets('dismissing returns null, so nothing is filed', (tester) async {
      AiReportReason? picked = AiReportReason.other;
      var returned = false;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await showAiReportSheet(context);
                  returned = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(returned, isTrue);
      expect(picked, isNull);
    });
  });

  group('the row is write-only from the client', () {
    test('there is an insert policy and a select policy, and no more', () {
      final policies = RegExp(r'create policy\s+(\w+)')
          .allMatches(migration)
          .map((m) => m.group(1)!)
          .toSet();
      expect(policies, {
        'ai_content_reports_insert_own',
        'ai_content_reports_select_own',
      });
      // No update and no delete: a report a reporter can retract or edit
      // after the fact is not evidence of anything.
      expect(migration.contains('for update'), isFalse);
      expect(migration.contains('for delete'), isFalse);
    });

    test('deleting the account takes the reports with it', () {
      expect(
        migration.contains('references auth.users (id) on delete cascade'),
        isTrue,
      );
    });
  });
}
