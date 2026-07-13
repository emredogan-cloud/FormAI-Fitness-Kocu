// Phase 2 (P-Risk) F09 · unit tests for the pure decision logic extracted
// from DashboardScreen. These lock the behaviour the screen now delegates to.

import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/home/presentation/dashboard_logic.dart';

void main() {
  group('DashboardLogic.prefetchUrls', () {
    test('empty input → empty', () {
      expect(DashboardLogic.prefetchUrls(const []), isEmpty);
    });

    test('keeps only non-null http(s) urls, preserving order', () {
      final out = DashboardLogic.prefetchUrls([
        'https://cdn/a.webp',
        null,
        'asset://local/b.webp',
        '',
        'http://cdn/c.webp',
      ]);
      expect(out, ['https://cdn/a.webp', 'http://cdn/c.webp']);
    });

    test('caps at the first `limit` candidates (default 6)', () {
      final many = List.generate(10, (i) => 'https://cdn/$i.webp');
      final out = DashboardLogic.prefetchUrls(many);
      expect(out.length, 6);
      expect(out.first, 'https://cdn/0.webp');
      expect(out.last, 'https://cdn/5.webp');
    });

    test('limit is applied before filtering (mirrors plan.take(6))', () {
      // First 6 candidates include 2 non-http → only the http ones survive.
      final out = DashboardLogic.prefetchUrls([
        'https://0',
        null,
        'https://2',
        'asset://3',
        'https://4',
        'https://5',
        'https://6', // beyond the limit, must be ignored
      ]);
      expect(out, ['https://0', 'https://2', 'https://4', 'https://5']);
    });
  });

  group('DashboardLogic.pendingBadgeCelebrations', () {
    test('null celebrated set → nothing pending (caller seeds)', () {
      expect(
        DashboardLogic.pendingBadgeCelebrations({'a', 'b'}, null),
        isEmpty,
      );
    });

    test('returns unlocked minus celebrated', () {
      expect(
        DashboardLogic.pendingBadgeCelebrations({'a', 'b', 'c'}, {'a'}),
        unorderedEquals(['b', 'c']),
      );
    });

    test('all celebrated → nothing pending', () {
      expect(
        DashboardLogic.pendingBadgeCelebrations({'a', 'b'}, {'a', 'b'}),
        isEmpty,
      );
    });
  });
}
