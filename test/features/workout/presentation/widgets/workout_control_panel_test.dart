import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/workout/presentation/widgets/workout_control_panel.dart';
import 'package:sixpack_ai/features/workout/services/crunch_analyzer.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// The live workout HUD. Two strings sit beside the rep counter and
/// both used to be built from something that was never copy:
///
///   • the detector chip rendered `CrunchState.name.toUpperCase()`, so
///     a Turkish user watched "UNKNOWN" until the analyser locked on —
///     found on a device, because an enum name is invisible to the
///     hardcoded-string gate;
///   • the set indicator interpolated 'SET $current / $total'.

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('tr')],
      home: Scaffold(body: child),
    );

Widget _panel(CrunchState state) => WorkoutControlPanel(
      currentSet: 1,
      totalSets: 3,
      metric: 'x0 / 15',
      exerciseName: 'Squat Thrust',
      detectorState: state,
      isPaused: false,
      onTogglePlay: () {},
      onNext: () {},
    );

void main() {
  testWidgets('the detector chip reads in Turkish, never as an enum name',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(_panel(CrunchState.unknown)));
    expect(find.text('UNKNOWN'), findsNothing);
    expect(find.text('BEKLİYOR'), findsOneWidget);

    await tester.pumpWidget(_host(_panel(CrunchState.down)));
    expect(find.text('AŞAĞI'), findsOneWidget);

    await tester.pumpWidget(_host(_panel(CrunchState.up)));
    expect(find.text('YUKARI'), findsOneWidget);
  });

  testWidgets('the set indicator keeps its uppercase styling', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(_panel(CrunchState.unknown)));
    expect(find.text('SET 1 / 3'), findsOneWidget);
  });
}
