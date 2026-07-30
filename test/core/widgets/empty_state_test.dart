import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/widgets/empty_state.dart';

/// Roadmap Phase 2 (C37) · the consolidated empty state.
///
/// Replaces four private `_EmptyState` classes that had different
/// anatomy and, crucially, no CTA. The tests pin the anatomy contract so
/// a future call site can't silently produce a dead-end state again.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders icon + title only when that is all it is given',
      (tester) async {
    await _pump(
      tester,
      const EmptyState(icon: Icons.inbox_rounded, title: 'Boş'),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Boş'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_rounded), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('renders the body when supplied', (tester) async {
    await _pump(
      tester,
      const EmptyState(
        icon: Icons.inbox_rounded,
        title: 'Boş',
        body: 'Buraya bir şey eklediğinde burada görünür.',
      ),
    );
    expect(
      find.text('Buraya bir şey eklediğinde burada görünür.'),
      findsOneWidget,
    );
  });

  testWidgets('renders a CTA only when BOTH label and handler are given',
      (tester) async {
    // Label without handler → no button (would be dead).
    await _pump(
      tester,
      const EmptyState(
        icon: Icons.inbox_rounded,
        title: 'Boş',
        ctaLabel: 'Ekle',
      ),
    );
    expect(find.byType(FilledButton), findsNothing);

    // Both → button.
    await _pump(
      tester,
      EmptyState(
        icon: Icons.inbox_rounded,
        title: 'Boş',
        ctaLabel: 'Ekle',
        onCta: () {},
      ),
    );
    expect(find.text('Ekle'), findsOneWidget);
  });

  testWidgets('the CTA fires and meets the 48dp minimum target',
      (tester) async {
    var tapped = false;
    await _pump(
      tester,
      EmptyState(
        icon: Icons.inbox_rounded,
        title: 'Boş',
        ctaLabel: 'Ekle',
        onCta: () => tapped = true,
      ),
    );
    final size = tester.getSize(find.byType(FilledButton));
    expect(size.height, greaterThanOrEqualTo(48));

    await tester.tap(find.text('Ekle'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('compact mode shrinks the halo but keeps the anatomy',
      (tester) async {
    await _pump(
      tester,
      const EmptyState(
        icon: Icons.inbox_rounded,
        title: 'Boş',
        body: 'Açıklama',
        compact: true,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Boş'), findsOneWidget);
    expect(find.text('Açıklama'), findsOneWidget);
  });

  testWidgets('title and body are announced together to a screen reader',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const EmptyState(
        icon: Icons.inbox_rounded,
        title: 'Boş',
        body: 'Açıklama',
      ),
    );
    expect(find.bySemanticsLabel(RegExp('Boş')), findsAtLeastNWidgets(1));
    expect(find.bySemanticsLabel(RegExp('Açıklama')), findsAtLeastNWidgets(1));
    handle.dispose();
  });

  testWidgets('survives a 1.3 text scale on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await _pump(
      tester,
      EmptyState(
        icon: Icons.inbox_rounded,
        title: 'Oldukça uzun bir başlık satırı buraya geliyor',
        body: 'Ve altında yeterince uzun bir açıklama metni yer alıyor '
            'ki sarma davranışı test edilebilsin.',
        ctaLabel: 'Bir Şeyler Yap',
        onCta: () {},
      ),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });
}
