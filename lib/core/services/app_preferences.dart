import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main() with the initialized SharedPreferences instance so
/// the router can read flags synchronously at startup.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope.',
  );
});

final appPreferencesProvider = Provider<AppPreferences>((ref) {
  return AppPreferences(ref.watch(sharedPreferencesProvider));
});

class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const String _firstTimeKey = 'sixpack.is_first_time';
  static const String _goalKey = 'sixpack.goal';
  static const String _userMetricsKey = 'sixpack.user_metrics';
  // Must match WorkoutRepository._planKey. Duplicated here because
  // saveUserMetrics needs to drop the cached 30-day plan when the goal
  // changes, and a cross-import would create an awkward core → feature
  // dependency just for one string constant.
  static const String _planCacheKey = 'sixpack.user_custom_plan_v3';
  static const String _nutritionStreakKey = 'sixpack.nutrition_streak';
  // Phase 46 · progressive disclosure. The nutrition wizard questions
  // (goal / diet / meal-frequency / prep-time / taste — allergy and
  // water steps were removed in the store-honesty pass) were lifted
  // out of the main onboarding flow so the initial 13-step wizard
  // could shrink to 9. They are asked the first time the user opens
  // the Beslenme tab instead; this flag is set to `true` once that
  // deferred flow completes so the sheet never re-prompts.
  static const String _nutritionPrefsCompletedKey =
      'sixpack.nutrition_prefs_completed';
  // Phase 48 · daily-reminder toggle persisted so the account-settings
  // switch can render its "on" / "off" position across app restarts.
  // The real scheduling still lives in NotificationService; this flag
  // is just the source of truth for the switch and gates whether we
  // actually ask the OS to schedule.
  static const String _dailyReminderEnabledKey =
      'sixpack.daily_reminder_enabled';
  // Phase 52 · monotonic high-water mark of `streak`. Bumped from
  // `WorkoutSessionNotifier` whenever the live streak crosses its
  // previous best. Read by the AI Coach card so a user who lost their
  // streak (live = 0) but used to have one (max > 0) sees the
  // "comeback" greeting instead of the cold-start default.
  static const String _maxStreakKey = 'sixpack.max_streak';
  // Phase 58 · ISO-8601 timestamp of the most recent workout
  // completion. The smart notification scheduler reads this to decide
  // whether the user has already done today's workout, which then
  // picks the appropriate reminder body (Condition A / B / C). Stored
  // as ISO-8601 so the date check is timezone-aware.
  static const String _lastWorkoutAtKey = 'sixpack.last_workout_at';

  // Phase 133 · whether the user has any training equipment. First
  // onboarding field that directly changes the generated 30-day plan
  // — the workout generator reads this via [hasEquipment] and filters
  // its exercise pool when false. Dedicated key (separate from the
  // wizard.toJson() blob) so the repository can read it synchronously
  // at startup without parsing the full metrics map.
  static const String _hasEquipmentKey = 'sixpack.has_equipment';

  // Progress Phase 1.A · streak freeze tokens. The user accumulates up
  // to `_freezeMaxTokens` shields; each one bridges a single missed
  // program-day so the streak doesn't break on the first slip.
  // Refilled to max every Monday 00:00 local. First install seeds 1
  // token immediately so the UX shows "1 kalkanın var" instead of "0".
  static const String _freezeTokensKey = 'sixpack.freeze_tokens_available';
  static const String _freezeRefillIsoKey = 'sixpack.freeze_last_refill_iso';
  static const int _freezeMaxTokens = 2;
  static const int _freezeInitialSeed = 1;

  // Progress Phase 1.F · no-repeat memory of the last N coach lines
  // shown on the AI Coach card, stored as `String.hashCode` ints joined
  // by commas. Cap at 7 entries so the same line can't fire twice in a
  // single week of daily opens.
  static const String _recentCoachHashesKey = 'sixpack.coach_recent_hashes';
  static const int _recentCoachWindow = 7;

  // Progress Phase 3.B · lifetime XP + idempotent ledgers. The ledgers
  // record which signals have already been credited so the awarding
  // listener at `xp_award_listener.dart` can run as often as it likes
  // without double-paying the user. Ledger keys default to empty so
  // existing users naturally backfill their XP on first Phase-3 launch.
  static const String _lifetimeXpKey = 'sixpack.lifetime_xp';
  static const String _xpDaysKey = 'sixpack.xp_awarded_session_days';
  static const String _xpBadgesKey = 'sixpack.xp_awarded_badge_ids';
  static const String _xpStreakKey = 'sixpack.xp_awarded_streak_milestones';

  // Progress Phase 5.D · one-shot flag that tracks whether the user
  // has seen the Day-30 Year-in-Review modal. Stamped to true the
  // first time the modal auto-shows; cleared by `resetProgress` so a
  // user who restarts the program gets the celebration again.
  // Re-entry via the "Yolculuğunu Gör" hero pill does NOT touch this
  // flag — it's a manual recall surface, not a first-impression gate.
  static const String _seenYearInReviewKey = 'sixpack.seen_year_in_review';

  // Phase 126 · first-time AI-presence scene flags. Each of the three
  // cinematic AI scenes (dashboard welcome / nutrition intro / first-
  // workout celebration) fires exactly once per install. The mark-seen
  // happens *before* the route push so a backgrounded scene doesn't
  // replay on app resume — see [FirstTimeAiScenes.showIfNeeded].
  static const String _seenFirstDashboardAiKey =
      'sixpack.seen_first_dashboard_ai';
  static const String _seenFirstNutritionAiKey =
      'sixpack.seen_first_nutrition_ai';
  static const String _seenFirstWorkoutCompleteAiKey =
      'sixpack.seen_first_workout_complete_ai';

  // Phase 135 · one-shot gate for the post-first-workout Pro invitation
  // scene. Fires on the user's first return-to-dashboard after the
  // session-complete overlay has cleared, NOT inline with the
  // celebration scene above — emotional pacing wants a beat of
  // "I did it" before the "ready for more?" frame.
  static const String _seenFirstWorkoutProInvitationKey =
      'sixpack.seen_first_workout_pro_invitation';

  // Phase 136 · one-shot gate for the Pro-user 3rd-workout rating
  // scene. Captures the habit-formation momentum at the moment it
  // becomes self-sustaining (third session done). Pro-only; non-pro
  // users skip the trigger entirely.
  static const String _seenPro3rdWorkoutRatingKey =
      'sixpack.seen_pro_3rd_workout_rating';

  // Phase 138 · H-2 KVKK / GDPR consent. Three keys: `decided` flag
  // tracks whether the user has interacted with the consent dialog;
  // `analytics` + `crash` are the per-channel grants. Defaults are
  // off — KVKK Article 5 (Law 6698) requires explicit opt-in, so any
  // code path that reads these before the consent screen has run
  // must treat absence as denial.
  static const String _consentDecidedKey = 'sixpack.consent.decided';
  static const String _consentAnalyticsKey = 'sixpack.consent.analytics';
  static const String _consentCrashKey = 'sixpack.consent.crash';

  // Phase 138 · H-1 + H-7 onboarding wizard checkpoint. The wizard
  // payload (`WizardState.toJson()`) and the current step index are
  // snapshotted on every mutation so an OS-kill in the middle of the
  // 19-step flow doesn't reset the user back to step 0. Cleared by
  // `completeOnboarding()` once the wizard reaches /paywall.
  static const String _wizardStateKey = 'sixpack.wizard_state_json';
  static const String _wizardStepIndexKey = 'sixpack.wizard_step_index';

  // Phase 138 · B-4 age gate. Persistent flag set the first time the
  // user passes the 18+ verification screen. Read by the router so a
  // fresh install can't reach the PII-collecting onboarding before
  // confirming they meet the Play Console 18+ target audience. Once
  // set the gate is never re-shown — re-installs / cache wipes will
  // re-prompt. The companion `_birthYearKey` is purely diagnostic;
  // we don't ship birthdates server-side, but having it locally lets
  // the user inspect their answer in the account settings later.
  static const String _ageVerifiedKey = 'sixpack.age_verified';
  static const String _birthYearKey = 'sixpack.birth_year';

  bool get isFirstTime => _prefs.getBool(_firstTimeKey) ?? true;

  /// Phase 138 · B-4. Returns `true` once the user has confirmed they
  /// are 18+ via the age-gate screen. The router routes first-time
  /// installs to `/age-gate` until this flips. Legacy users who already
  /// finished onboarding (isFirstTime=false) are grandfathered — the
  /// gate is only enforced before PII collection.
  bool get ageVerified => _prefs.getBool(_ageVerifiedKey) ?? false;

  /// Phase 138 · B-4. Stamps both the verification flag and the
  /// reported birth year so support can investigate spoofing
  /// complaints later. Birth year is stored on-device only; nothing
  /// in the cloud sync writes it back to Supabase.
  Future<void> setAgeVerified({required int birthYear}) async {
    await _prefs.setInt(_birthYearKey, birthYear);
    await _prefs.setBool(_ageVerifiedKey, true);
  }

  int? get birthYear =>
      _prefs.containsKey(_birthYearKey) ? _prefs.getInt(_birthYearKey) : null;

  /// Phase 138 · H-1. Persists the wizard's full JSON payload + the
  /// current step index so an app kill (OS reclaim, crash, user
  /// force-quit) mid-onboarding can resume from where they left off
  /// instead of dropping them back to step 0. Called from the
  /// OnboardingScreen's `ref.listen(wizardProvider)` watcher and from
  /// `_next()` / `_back()`.
  Future<void> saveWizardCheckpoint({
    required String stateJson,
    required int stepIndex,
  }) async {
    await _prefs.setString(_wizardStateKey, stateJson);
    await _prefs.setInt(_wizardStepIndexKey, stepIndex);
  }

  /// Phase 138 · H-1. Returns the persisted checkpoint, or `null` if
  /// no checkpoint exists. Tuple-shaped via a record so callers don't
  /// have to make two SharedPreferences round-trips.
  ({String stateJson, int stepIndex})? loadWizardCheckpoint() {
    final json = _prefs.getString(_wizardStateKey);
    if (json == null) return null;
    final step = _prefs.getInt(_wizardStepIndexKey) ?? 0;
    return (stateJson: json, stepIndex: step);
  }

  /// Phase 138 · H-1. Removes the checkpoint after `completeOnboarding`
  /// so a future re-onboarding (e.g. after `resetProgress`) doesn't
  /// rehydrate stale answers.
  Future<void> clearWizardCheckpoint() async {
    await _prefs.remove(_wizardStateKey);
    await _prefs.remove(_wizardStepIndexKey);
  }

  /// Phase 138 · H-2. True iff the user has interacted with the
  /// consent dialog at least once. The router uses this to decide
  /// whether to route to `/consent` or skip past it.
  bool get consentDecisionMade => _prefs.getBool(_consentDecidedKey) ?? false;

  /// Phase 138 · H-2. Per-channel consent grants. Both default to
  /// `false` — KVKK requires explicit opt-in, so a missing key is
  /// equivalent to denial.
  bool get analyticsConsentGranted =>
      _prefs.getBool(_consentAnalyticsKey) ?? false;
  bool get crashReportingConsentGranted =>
      _prefs.getBool(_consentCrashKey) ?? false;

  /// Phase 138 · H-2. Persists the consent decision atomically.
  /// Always call this with the user's actual answers — do NOT default
  /// a channel to `true` to soften the prompt.
  Future<void> setConsent({
    required bool analytics,
    required bool crash,
  }) async {
    await _prefs.setBool(_consentAnalyticsKey, analytics);
    await _prefs.setBool(_consentCrashKey, crash);
    await _prefs.setBool(_consentDecidedKey, true);
  }

  Future<void> completeOnboarding({String? goal, bool? hasEquipment}) async {
    if (goal != null) await _prefs.setString(_goalKey, goal);
    if (hasEquipment != null) {
      await _prefs.setBool(_hasEquipmentKey, hasEquipment);
    }
    await _prefs.setBool(_firstTimeKey, false);
  }

  /// Phase 133 · whether the user said they have equipment. Returns
  /// `null` on legacy installs that finished onboarding before this
  /// key existed — callers should treat null as "assume yes, preserve
  /// current behaviour" so legacy users aren't suddenly forced into
  /// the bodyweight-only filter. Set by [completeOnboarding].
  bool? get hasEquipment {
    if (!_prefs.containsKey(_hasEquipmentKey)) return null;
    return _prefs.getBool(_hasEquipmentKey);
  }

  String? get goal => _prefs.getString(_goalKey);

  Future<void> saveUserMetrics(Map<String, dynamic> metrics) async {
    final previousGoal = _prefs.getString(_goalKey);
    await _prefs.setString(_userMetricsKey, jsonEncode(metrics));
    final goal = metrics['targetPhysique'] as String?;
    if (goal != null) await _prefs.setString(_goalKey, goal);
    // If the user picked a new goal, the cached 30-day plan was
    // generated against the old one — drop it so the next program load
    // regenerates against what they just picked.
    if (goal != null && goal != previousGoal) {
      await _prefs.remove(_planCacheKey);
    }
  }

  Map<String, dynamic>? get userMetrics {
    final raw = _prefs.getString(_userMetricsKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> resetOnboarding() async {
    await _prefs.remove(_firstTimeKey);
    await _prefs.remove(_goalKey);
    await _prefs.remove(_userMetricsKey);
  }

  /// Current nutrition streak in whole days. Zero-default so a fresh
  /// install just shows "0 Gün" until the cron job backfills real
  /// values. Phase 25.2 ships the UI only — see
  /// [nutritionStreakProvider] for the read-side.
  int get nutritionStreak => _prefs.getInt(_nutritionStreakKey) ?? 0;

  Future<void> setNutritionStreak(int value) async {
    await _prefs.setInt(_nutritionStreakKey, value);
  }

  /// True once the user has answered the four deferred nutrition
  /// questions surfaced on first Beslenme-tab view. False-by-default
  /// so fresh installs trigger the sheet exactly once.
  bool get hasCompletedNutritionPrefs =>
      _prefs.getBool(_nutritionPrefsCompletedKey) ?? false;

  Future<void> completeNutritionOnboarding() async {
    await _prefs.setBool(_nutritionPrefsCompletedKey, true);
  }

  /// Whether the user has the daily training-reminder push enabled.
  /// Defaults to `false` so a fresh install never schedules a notification
  /// without an explicit opt-in (Apple/Google policy).
  bool get dailyReminderEnabled =>
      _prefs.getBool(_dailyReminderEnabledKey) ?? false;

  Future<void> setDailyReminderEnabled(bool value) async {
    await _prefs.setBool(_dailyReminderEnabledKey, value);
  }

  /// Phase 52 · highest streak this user has ever reached. Defaults to
  /// 0 so a fresh install reads "no past streak". Updated through
  /// [bumpMaxStreakIfHigher] so callers can't accidentally regress the
  /// high-water mark when the live streak resets.
  int get maxStreak => _prefs.getInt(_maxStreakKey) ?? 0;

  /// Bumps [maxStreak] to [candidate] when it represents a new
  /// personal best. No-op when the candidate is equal or lower than
  /// the stored max — protects the high-water mark on streak resets,
  /// which is exactly the signal the "comeback" greeting keys off.
  Future<void> bumpMaxStreakIfHigher(int candidate) async {
    if (candidate <= maxStreak) return;
    await _prefs.setInt(_maxStreakKey, candidate);
  }

  /// Phase 58 · the wall-clock moment the user last completed a
  /// workout. Returns null on a fresh install (no prior completion)
  /// so callers can disambiguate "no workouts yet" from "haven't
  /// worked out today".
  DateTime? get lastWorkoutAt {
    final raw = _prefs.getString(_lastWorkoutAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setLastWorkoutAt(DateTime when) async {
    await _prefs.setString(_lastWorkoutAtKey, when.toIso8601String());
  }

  /// Progress Phase 1.A · how many streak-freeze shields the user has.
  /// First read on a fresh install seeds the token count to
  /// [_freezeInitialSeed] so the hero block has something to surface
  /// immediately — without the seed the user would see "0 kalkan" on
  /// day 0, which inverts the loss-aversion reassurance the shields
  /// are meant to provide.
  ///
  /// Tokens act as a passive shield: the streak calculator applies up
  /// to this many to bridge inactivity / sequence gaps on every read.
  /// They are NOT permanently consumed on read — they refill to
  /// [_freezeMaxTokens] every Monday via [refillFreezeTokensIfDue].
  /// Future phases may introduce per-event consumption (e.g. when the
  /// user passes a refill cycle still inactive); this read-only ceiling
  /// is the Phase-1 contract.
  int get freezeTokensAvailable {
    if (_prefs.containsKey(_freezeTokensKey)) {
      return _prefs.getInt(_freezeTokensKey) ?? 0;
    }
    return _freezeInitialSeed;
  }

  /// Maximum number of freeze tokens the system will ever award.
  /// Exposed so callers can render an "X / max" pip strip if needed.
  int get freezeTokensMax => _freezeMaxTokens;

  /// Progress Phase 1.A · Monday 00:00 local refill. Returns `true`
  /// when it actually wrote a new token count, so the caller can trip a
  /// log line / analytics event if it cares. Idempotent — calling it
  /// multiple times the same day is a no-op after the first call.
  Future<bool> refillFreezeTokensIfDue() async {
    final now = DateTime.now();
    final lastRefillRaw = _prefs.getString(_freezeRefillIsoKey);
    final lastRefill =
        lastRefillRaw == null ? null : DateTime.tryParse(lastRefillRaw);
    if (lastRefill != null) {
      // Skip when we already topped up this Monday or later. Compare on
      // the start-of-Monday of each week; any moment after that is the
      // "refilled" state.
      final lastMonday = _mostRecentMondayLocal(now);
      if (!lastRefill.isBefore(lastMonday)) return false;
    }
    await _prefs.setInt(_freezeTokensKey, _freezeMaxTokens);
    await _prefs.setString(_freezeRefillIsoKey, now.toIso8601String());
    return true;
  }

  /// Returns the [DateTime] for Monday 00:00 of [now]'s local week. If
  /// `now` is a Monday morning before midnight has rolled, returns that
  /// Monday's 00:00; otherwise the most recent past Monday.
  DateTime _mostRecentMondayLocal(DateTime now) {
    // DateTime.weekday: Monday = 1, Sunday = 7. Subtract that many
    // days minus 1 to land on Monday.
    final daysSinceMonday = now.weekday - DateTime.monday;
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysSinceMonday));
    return monday;
  }

  /// Progress Phase 1.F · last N coach-line hashes the AI Coach card
  /// has surfaced. Stored as a comma-joined list of hashCode ints. Read
  /// to filter the candidate set so the same phrasing doesn't repeat
  /// inside the rolling window.
  List<int> get recentCoachLineHashes {
    final raw = _prefs.getString(_recentCoachHashesKey);
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((s) => int.tryParse(s))
        .whereType<int>()
        .toList(growable: false);
  }

  /// Pushes [hash] onto the recent-hashes window, evicting the oldest
  /// entry once the window is full.
  Future<void> pushRecentCoachHash(int hash) async {
    final current = recentCoachLineHashes.toList();
    current.add(hash);
    while (current.length > _recentCoachWindow) {
      current.removeAt(0);
    }
    await _prefs.setString(_recentCoachHashesKey, current.join(','));
  }

  /// Phase 58 · derived: did the user already finish a workout today?
  /// "Today" is the device's local calendar day, which matches what
  /// the rest of the app displays. Uses date-only comparison (not
  /// duration) because a user who trained at 23:50 yesterday should
  /// still see the "Antrenman Vakti" prompt at 09:00 today, not
  /// "Yakıt Gerekli".
  bool get isWorkoutDoneToday {
    final last = lastWorkoutAt;
    if (last == null) return false;
    final now = DateTime.now();
    return last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
  }

  // ─── Progress Phase 3.B · XP persistence ──────────────────────────

  /// Single source of truth for the user's lifetime XP. Defaults to 0
  /// — fresh installs OR existing users on first Phase-3 launch start
  /// at 0 and the awarding listener backfills retroactively from the
  /// idempotent ledgers below.
  int get lifetimeXp => _prefs.getInt(_lifetimeXpKey) ?? 0;

  /// Adds [delta] to [lifetimeXp]. Negative deltas are silently ignored
  /// so a buggy caller can't subtract from the user's progress.
  Future<void> addLifetimeXp(int delta) async {
    if (delta <= 0) return;
    await _prefs.setInt(_lifetimeXpKey, lifetimeXp + delta);
  }

  /// Program day numbers we've credited workout XP for. Read by the
  /// awarding listener as a contains-check before crediting.
  Set<int> get awardedSessionDays {
    final raw = _prefs.getStringList(_xpDaysKey) ?? const <String>[];
    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> markSessionDayAwarded(int dayNumber) async {
    final current = awardedSessionDays..add(dayNumber);
    await _prefs.setStringList(
      _xpDaysKey,
      current.map((n) => n.toString()).toList(),
    );
  }

  /// Badge ids we've credited unlock XP for.
  Set<String> get awardedBadgeIds =>
      (_prefs.getStringList(_xpBadgesKey) ?? const <String>[]).toSet();

  Future<void> markBadgeAwarded(String badgeId) async {
    final current = awardedBadgeIds..add(badgeId);
    await _prefs.setStringList(_xpBadgesKey, current.toList());
  }

  /// Streak milestones (3, 7, 14, …) we've credited.
  Set<int> get awardedStreakMilestones {
    final raw = _prefs.getStringList(_xpStreakKey) ?? const <String>[];
    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> markStreakMilestoneAwarded(int milestone) async {
    final current = awardedStreakMilestones..add(milestone);
    await _prefs.setStringList(
      _xpStreakKey,
      current.map((n) => n.toString()).toList(),
    );
  }

  // ─── Phase 126 · first-time AI-presence scene gates ───────────────

  bool get seenFirstDashboardAi =>
      _prefs.getBool(_seenFirstDashboardAiKey) ?? false;

  Future<void> markSeenFirstDashboardAi() async {
    await _prefs.setBool(_seenFirstDashboardAiKey, true);
  }

  bool get seenFirstNutritionAi =>
      _prefs.getBool(_seenFirstNutritionAiKey) ?? false;

  Future<void> markSeenFirstNutritionAi() async {
    await _prefs.setBool(_seenFirstNutritionAiKey, true);
  }

  bool get seenFirstWorkoutCompleteAi =>
      _prefs.getBool(_seenFirstWorkoutCompleteAiKey) ?? false;

  Future<void> markSeenFirstWorkoutCompleteAi() async {
    await _prefs.setBool(_seenFirstWorkoutCompleteAiKey, true);
  }

  /// Phase 135 · post-first-workout Pro invitation scene. Fires once,
  /// the first time the user returns to the dashboard after completing
  /// at least one workout. See [ConversionMomentService].
  bool get seenFirstWorkoutProInvitation =>
      _prefs.getBool(_seenFirstWorkoutProInvitationKey) ?? false;

  Future<void> markSeenFirstWorkoutProInvitation() async {
    await _prefs.setBool(_seenFirstWorkoutProInvitationKey, true);
  }

  /// Phase 136 · Pro-only 3rd-workout cinematic rating moment. Fires
  /// once per install when a Pro user returns to the dashboard after
  /// their third completed workout. See [RatingMomentService].
  bool get seenPro3rdWorkoutRating =>
      _prefs.getBool(_seenPro3rdWorkoutRatingKey) ?? false;

  Future<void> markSeenPro3rdWorkoutRating() async {
    await _prefs.setBool(_seenPro3rdWorkoutRatingKey, true);
  }

  // ─── Progress Phase 5.D · Year-in-Review one-shot flag ────────────

  bool get seenYearInReview => _prefs.getBool(_seenYearInReviewKey) ?? false;

  Future<void> markSeenYearInReview() async {
    await _prefs.setBool(_seenYearInReviewKey, true);
  }

  /// Used by `WorkoutRepository.resetProgress` so a user who restarts
  /// the 30-day arc gets the Year-in-Review celebration again on the
  /// next Day-30 completion.
  Future<void> clearSeenYearInReview() async {
    await _prefs.remove(_seenYearInReviewKey);
  }
}
