import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/progress/data/level_titles.dart';
import 'package:sixpack_ai/features/progress/presentation/widgets/level_up_screen.dart';

/// The level-up celebration overlay. It's a pure presentation widget
/// (level + tier in, choreographed reveal out), so the tests assert the
/// tier label and sigil render for both an aspirational and a
/// cold-start tier. The `_breathing` controller repeats forever, so the
/// tests pump fixed durations rather than `pumpAndSettle`.

Widget _host({required int level, required LevelTier tier}) {
  return MaterialApp(
    home: LevelUpScreen(level: level, tier: tier),
    debugShowCheckedModeBanner: false,
  );
}

void main() {
  testWidgets('renders the aspirational tier label and medal sigil',
      (tester) async {
    await tester.pumpWidget(_host(level: 20, tier: tierForLevel(20)));
    await tester.pump(); // schedules the timeline via postFrameCallback
    await tester.pump(const Duration(seconds: 2)); // reveal completes

    expect(find.text('YENİ SEVİYE'), findsOneWidget);
    expect(find.text('Lv 20 · Atlet'), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/illustrations/milestone_medal.webp')),
      findsOneWidget,
    );
  });

  testWidgets('renders the cold-start tier label', (tester) async {
    await tester.pumpWidget(_host(level: 1, tier: tierForLevel(1)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Lv 1 · Acemi'), findsOneWidget);
  });
}
