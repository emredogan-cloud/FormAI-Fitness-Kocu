import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/survey.dart';
import '../domain/survey_definitions.dart';

/// Roadmap Phase 1 (C8 · P4) · survey scheduling + transport.
///
/// Mirrors [FeedbackService]'s design: Supabase first, degrade quietly
/// on failure. Unlike feedback there is no mailto fallback — a survey
/// answer that can't reach the server is analytics data, not a support
/// request, and PostHog already carries it. Losing the row is
/// acceptable; interrupting the user with an error about it is not.
class SurveyService {
  SurveyService(this._ref);

  final Ref _ref;

  static const String _table = 'survey_responses';

  /// Picks the survey to show now, or `null`. Pure delegation to
  /// [selectSurvey] — this method only gathers state.
  SurveyDefinition? pending(SurveyContext context) {
    final prefs = _ref.read(appPreferencesProvider);
    return selectSurvey(
      catalog: kSurveyCatalog,
      context: context,
      answeredIds: prefs.answeredSurveyIds,
      lastShownAt: prefs.lastSurveyShownAt,
      now: DateTime.now(),
      cooldown: AppPreferences.kSurveyCooldown,
    );
  }

  /// Stamps a survey as shown. Called before presentation so a survey
  /// the user backgrounds away from doesn't reappear immediately —
  /// same idempotency contract as the rating moment.
  Future<void> markShown(SurveyDefinition survey) async {
    final prefs = _ref.read(appPreferencesProvider);
    await prefs.recordSurveyShown(DateTime.now());
    AnalyticsService.instance.surveyShown(surveyId: survey.id);
  }

  /// Records a dismissal. The survey is marked answered so we never
  /// ask again — a user who closed it has given their answer.
  Future<void> recordDismissal(SurveyDefinition survey) async {
    final prefs = _ref.read(appPreferencesProvider);
    await prefs.markSurveyAnswered(survey.id);
    AnalyticsService.instance.surveyDismissed(surveyId: survey.id);
  }

  /// Persists an answer locally (always) and to Supabase (best effort),
  /// and fires the analytics event that the dashboards read.
  Future<void> submit(SurveyAnswer answer) async {
    final prefs = _ref.read(appPreferencesProvider);
    await prefs.markSurveyAnswered(answer.surveyId);

    AnalyticsService.instance.surveyAnswered(
      surveyId: answer.surveyId,
      score: answer.score,
      optionToken: answer.optionToken,
      npsBucket: answer.npsBucket,
    );

    await _tryPersist(answer);
  }

  Future<void> _tryPersist(SurveyAnswer answer) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      String version = 'unknown';
      try {
        final info = await PackageInfo.fromPlatform();
        version = '${info.version}+${info.buildNumber}';
      } catch (_) {
        // package_info_plus can fail on test stubs — the row is still
        // worth writing without it.
      }
      await client.from(_table).insert(<String, dynamic>{
        'user_id': user.id,
        'survey_id': answer.surveyId,
        'score': answer.score,
        'option_token': answer.optionToken,
        'app_version': version,
        'platform': Platform.isIOS
            ? 'iOS'
            : (Platform.isAndroid
                ? 'Android' // i18n-ignore — platform tag
                : Platform.operatingSystem),
      });
    } catch (e, st) {
      AppLogger.warning(
        'survey response write failed: $e',
        category: 'feedback',
        data: {'stack': st.toString()},
      );
    }
  }
}

final surveyServiceProvider = Provider<SurveyService>(SurveyService.new);
