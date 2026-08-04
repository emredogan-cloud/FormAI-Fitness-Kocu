import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/core/services/lifecycle_campaigns.dart';

/// Roadmap Phase 14 (C50) · the record the frequency cap reads.
///
/// `lifecycle_campaigns_test.dart` proves the RULES. This proves the
/// storage those rules run against survives a round trip, a corrupt
/// row, and a client that does not know a token — because a ledger that
/// silently loses an entry is a cap that silently lets a second
/// notification through.
void main() {
  final now = DateTime(2026, 8, 4, 18);

  Future<AppPreferences> prefs([Map<String, Object> seed = const {}]) async {
    SharedPreferences.setMockInitialValues(seed);
    return AppPreferences(await SharedPreferences.getInstance());
  }

  test('an empty ledger is empty, not an error', () async {
    expect((await prefs()).campaignLedger, isEmpty);
  });

  test('a send survives the round trip', () async {
    final p = await prefs();
    await p.recordCampaignSent(LifecycleCampaign.winBack7, now);
    final ledger = p.campaignLedger;
    expect(ledger, hasLength(1));
    expect(ledger.single.campaign, LifecycleCampaign.winBack7);
    expect(ledger.single.at, now);
  });

  test('the cap can read what the ledger wrote', () async {
    // The join between the two halves of the feature. If the storage
    // and the rules disagree about anything, this is where it shows.
    final p = await prefs();
    await p.recordCampaignSent(LifecycleCampaign.milestone, now);
    expect(
      canSend(
        campaign: LifecycleCampaign.winBack7,
        history: p.campaignLedger,
        now: now.add(const Duration(hours: 2)),
      ),
      isFalse,
      reason: 'two notifications two hours apart is the thing the cap '
          'exists to prevent',
    );
    expect(
      canSend(
        campaign: LifecycleCampaign.winBack7,
        history: p.campaignLedger,
        now: now.add(const Duration(hours: 60)),
      ),
      isTrue,
    );
  });

  test('entries beyond the widest cooldown are pruned on write', () async {
    final p = await prefs();
    await p.recordCampaignSent(
        LifecycleCampaign.winBack7, now.subtract(const Duration(days: 200)));
    await p.recordCampaignSent(LifecycleCampaign.milestone, now);
    expect(p.campaignLedger, hasLength(1));
    expect(p.campaignLedger.single.campaign, LifecycleCampaign.milestone);
  });

  test('an entry inside the window is kept', () async {
    final p = await prefs();
    await p.recordCampaignSent(
        LifecycleCampaign.winBack7, now.subtract(const Duration(days: 20)));
    await p.recordCampaignSent(LifecycleCampaign.milestone, now);
    expect(p.campaignLedger, hasLength(2));
  });

  test('a corrupt row is skipped without losing the rest', () async {
    final p = await prefs({
      'sixpack.campaign_ledger_v1': <String>[
        'garbage',
        '|2026-08-01T00:00:00.000',
        'win_back_7|not-a-date',
        'milestone|2026-08-03T10:00:00.000',
      ],
    });
    final ledger = p.campaignLedger;
    expect(ledger, hasLength(1));
    expect(ledger.single.campaign, LifecycleCampaign.milestone);
  });

  test('a token this build does not know is dropped, not guessed', () async {
    // An entry written by a newer client. Guessing it into some other
    // campaign would attribute a notification to the wrong one; dropping
    // it under-counts the cap, which errs toward sending less.
    final p = await prefs({
      'sixpack.campaign_ledger_v1': <String>[
        'seasonal_thing_from_the_future|2026-08-03T10:00:00.000',
      ],
    });
    expect(p.campaignLedger, isEmpty);
  });

  test('every campaign token round-trips', () async {
    // The ledger encodes with `|`. A token containing one would split
    // wrong, and this is the only place that would ever be noticed.
    for (final campaign in LifecycleCampaign.values) {
      expect(campaign.token, isNot(contains('|')));
      final p = await prefs();
      await p.recordCampaignSent(campaign, now);
      expect(p.campaignLedger.single.campaign, campaign);
    }
  });

  group('conversion attribution', () {
    test('nothing pending means nothing to convert', () async {
      expect((await prefs()).pendingCampaignConversion, isNull);
    });

    test('a pending token round-trips and clears', () async {
      final p = await prefs();
      await p.setPendingCampaignConversion('win_back_14');
      expect(p.pendingCampaignConversion, 'win_back_14');
      await p.setPendingCampaignConversion(null);
      expect(p.pendingCampaignConversion, isNull);
    });
  });
}
