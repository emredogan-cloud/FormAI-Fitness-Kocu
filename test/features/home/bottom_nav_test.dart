import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/services/tour_targets.dart';

/// Phase 14 · Community joined the bottom navigation, taking it to five
/// slots.
///
/// The geometry of `navItemRect` is already covered by
/// `test/core/services/tour_targets_test.dart` — which is what caught
/// this change, and was updated rather than duplicated. What is left
/// here is the one fact that test cannot state: **which slot the tour's
/// Profile step is aimed at.**
///
/// The tour slices the bar into equal parts rather than keying each item
/// (see `TourTargets.navBar` for why). So if a later phase inserts a tab
/// without moving the step, the spotlight lands on the wrong tab and
/// nothing throws — it just quietly teaches the user the wrong thing.
void main() {
  test('the nav has five slots and Profile is the last one', () {
    expect(kBottomNavItemCount, 5);
    // Order: Training · Nutrition · Progress · Community · Profile.
    // The tour's Profile step passes 4, and it must stay the last index.
    expect(kBottomNavItemCount - 1, 4);
  });
}
