import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/motion/motion_tokens.dart';
import '../../../core/motion/scene_transition.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/app_logger.dart';
import '../../monetization/providers/monetization_provider.dart';
import '../providers/wizard_provider.dart';
import 'onboarding_chrome.dart';
import 'steps/act_1_hook_step.dart';
import 'steps/act_2_bonding_step.dart';
import 'steps/act_3_buildup_steps.dart';
import 'steps/act_4_revelation_steps.dart';
import 'steps/act_5_commitment_step.dart';
import 'steps/interlude_after_goal_step.dart';
import 'steps/interlude_before_pain_point_step.dart';
import 'steps/name_capture_step.dart';

/// Cinematic rebuild · the wizard orchestrator. Owns the step index,
/// the navigation transitions, and the exit-to-paywall finisher.
///
/// Transitions are powered by [SceneTransition] (the motion primitive
/// at lib/core/motion/scene_transition.dart) — outgoing scenes recede
/// and fade while incoming scenes rise and settle in the same 480 ms
/// window. The wizard reads as scene progression, not page snapping.
///
/// The 15-step act mapping:
///   • Act 1 (welcome) — emotional hook, immersive hero.
///   • Act 2 (coach_intro → name_capture) — Form introduces itself
///     and asks "Bu yolculukta sana nasıl sesleneyim?" The bonding
///     zone is three contiguous header-less screens so it reads as
///     one conversation.
///   • Act 3 (gender → goal → INTERLUDE → experience → daily_minutes
///     → activity → physical_data → INTERLUDE → pain_point) —
///     transformation buildup. The two interludes (post-goal +
///     pre-pain-point) are Form-speaking moments that turn the
///     middle from a questionnaire tunnel into a relationship arc:
///     predictive empathy after the goal declaration, vulnerability
///     setup before the hardest answer.
///   • Act 4 (analysis_illusion → dynamic_report) — labor-illusion +
///     personalised AI report reveal.
///   • Act 5 (pre_paywall_summary) — commitment moment.
///
/// `_hookSteps = 3` keeps the chrome header hidden through the
/// bonding zone. Interludes (any step name with the `interlude_`
/// prefix) also hide the header — the data-step counter skips them
/// so progress reads cleanly when chrome reappears.
///
/// New screens (habit anchor, push opt-in, identity declaration,
/// microcommitment, first-workout prompt) get added inside the
/// appropriate act file as they ship — the orchestrator only
/// extends [_stepNames] and the [_buildStep] switch.
const int _totalSteps = 15;
const int _hookSteps = 3;

const List<String> _stepNames = [
  'welcome',
  'coach_intro',
  'name_capture',
  'gender',
  'goal',
  'interlude_after_goal',
  'experience_level',
  'daily_minutes',
  'activity',
  'physical_data',
  'interlude_before_pain_point',
  'pain_point',
  'analysis_illusion',
  'dynamic_report',
  'pre_paywall_summary',
];

/// Number of non-hook, non-interlude steps. Hardcoded to 10 (gender,
/// goal, experience, daily_minutes, activity, physical_data,
/// pain_point, analysis_illusion, dynamic_report, pre_paywall_summary)
/// so the header's "x / 10" math doesn't drift when interludes get
/// added or moved. Verified against [_stepNames] in [initState].
const int _totalDataSteps = 10;

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _index = 0;
  bool _didPrecacheAssets = false;

  /// Photos rendered by gender / goal / activity tiles + the pre-paywall
  /// plan card. Pushed through [precacheImage] once at mount so the user
  /// never sees a placeholder flash on a swipe — and so a future asset
  /// swap doesn't trigger a decode hitch.
  static const List<String> _precacheImagePaths = [
    'photos/cinsiyetseçimikadın.webp',
    'photos/cinsiyetseçimierkek.webp',
    'photos/hedefinneSıkılaşmak.webp',
    'photos/hedefinneHacimKazanmak.webp',
    'photos/hedefinneSadeceSix-Pack.webp',
    'photos/hedef_guclenmek.webp',
    'photos/günlükaktivitenmasabaşı.webp',
    'photos/günlükaktivitenhafifhareketli.webp',
    'photos/günlükaktivitenneÇokAktif.webp',
    'photos/kişiselyapayzekakoçfoto.webp',
  ];

  @override
  void initState() {
    super.initState();
    // Capture step_index=0 so the funnel has an "entered onboarding"
    // event. The wizard's _next() / _back() emit subsequent steps.
    AnalyticsService.instance.onboardingStepCompleted(
      stepIndex: 0,
      stepName: _stepNames.first,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheAssets) return;
    _didPrecacheAssets = true;
    for (final path in _precacheImagePaths) {
      unawaited(
        precacheImage(AssetImage(path), context).catchError((Object _) {}),
      );
    }
  }

  void _next() {
    if (_index >= _totalSteps - 1) return;
    // UX rule §4: every forward step transition fires a medium impact so
    // the user feels the wizard *progressing*. Light impact on the tap
    // that initiated the transition is fired by the calling widget.
    AppHaptics.primaryCta();
    setState(() => _index += 1);
    AnalyticsService.instance.onboardingStepCompleted(
      stepIndex: _index,
      stepName: _index < _stepNames.length
          ? _stepNames[_index]
          : 'unknown_$_index',
    );
  }

  void _back() {
    if (_index == 0) return;
    AppHaptics.secondaryTap();
    setState(() => _index -= 1);
    AnalyticsService.instance.onboardingStepCompleted(
      stepIndex: _index,
      stepName: _index < _stepNames.length
          ? _stepNames[_index]
          : 'unknown_$_index',
    );
  }

  Future<void> _finish() async {
    AppHaptics.primaryCta();
    final wizard = ref.read(wizardProvider);
    final prefs = ref.read(appPreferencesProvider);
    // Persist the full wizard payload BEFORE flipping the firstTime flag
    // so the workout generator (which reads `userMetrics['targetPhysique']`
    // and `userMetrics['activityLevel']`) has everything it needs on the
    // very first /prediction render — without this save, guests complete
    // onboarding with an empty `user_metrics` and the generator silently
    // falls back to sixpack + beginner.
    await prefs.saveUserMetrics(wizard.toJson());
    await prefs.completeOnboarding(goal: wizard.targetPhysique?.name);
    // The user just committed to the program; the paywall is the next
    // major surface they may see. Kick off RevenueCat configuration now
    // so the platform-channel handshake overlaps the prediction render
    // instead of stalling the paywall open. configureRevenueCat is
    // idempotent — calling it again from sign-in is a no-op.
    unawaited(configureRevenueCat());
    if (!mounted) return;

    // Frictionless auth: silently create an anonymous Supabase session so
    // the user can preview their personalised prediction without being
    // shoved into a sign-up form. If anon auth is disabled in the project
    // (or the network is offline), fall back to the explicit /auth screen.
    try {
      await Supabase.instance.client.auth.signInAnonymously();
    } catch (e, st) {
      AppLogger.error(
        'Anonymous sign-in failed, falling back to /auth',
        e,
        stackTrace: st,
        category: 'onboarding',
      );
      if (!mounted) return;
      context.go(AppRoutes.auth);
      return;
    }
    // Now that the user has a session, raise the iOS ATT prompt BEFORE
    // navigating. The ~400 ms internal debounce keeps the prompt from
    // getting eaten by the next route's push.
    await AnalyticsService.instance.requestAttIfNeeded();
    if (!mounted) return;
    context.go(AppRoutes.paywall);
  }

  Widget _buildStep(int i) {
    switch (i) {
      case 0:
        return WelcomeStep(onStart: _next);
      case 1:
        return CoachIntroStep(onContinue: _next);
      case 2:
        return NameCaptureStep(onContinue: _next);
      case 3:
        return GenderStep(onCommitted: _next);
      case 4:
        return GoalStep(onCommitted: _next);
      case 5:
        return InterludeAfterGoalStep(onContinue: _next);
      case 6:
        return ExperienceStep(onCommitted: _next);
      case 7:
        return DailyMinutesStep(onCommitted: _next);
      case 8:
        return ActivityStep(onCommitted: _next);
      case 9:
        return PhysicalDataStep(onContinue: _next);
      case 10:
        return InterludeBeforePainPointStep(onContinue: _next);
      case 11:
        return PainPointStep(onCommitted: _next);
      case 12:
        return AnalysisIllusionStep(onComplete: _next);
      case 13:
        return DynamicReportStep(onComplete: _next);
      case 14:
        return PrePaywallSummaryStep(onComplete: _finish);
      default:
        return const SizedBox.shrink();
    }
  }

  /// Position of [i] in the data-step counter. Returns null for hook
  /// or interlude steps — the header is hidden in those cases. For
  /// data steps, returns 1-indexed position skipping interludes so
  /// the user sees a monotonic "n / 10" progression even as
  /// interludes interrupt the flow.
  int? _dataStepNumber(int i) {
    if (i < _hookSteps) return null;
    if (_stepNames[i].startsWith('interlude_')) return null;
    var count = 0;
    for (var j = _hookSteps; j <= i; j++) {
      if (!_stepNames[j].startsWith('interlude_')) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final dataStepNum = _dataStepNumber(_index);
    final showHeader = dataStepNum != null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header cross-fades + sizes in/out at the same cadence as
            // the scene transition so the boundary between full-bleed
            // moments (hook + interludes) and chrome moments (data
            // collection + reveal + commitment) reads as one
            // coordinated transition instead of a snap. Counter math
            // skips interludes so the user sees a monotonic "x / 10"
            // progression even when Form interrupts the flow.
            AnimatedCrossFade(
              firstChild: WizardHeader(
                step: dataStepNum ?? 1,
                total: _totalDataSteps,
                onBack: _index == 0 ? null : _back,
              ),
              secondChild: const SizedBox(width: double.infinity),
              crossFadeState: showHeader
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: MotionTokens.sceneCrossfade,
              firstCurve: MotionTokens.enterEase,
              secondCurve: MotionTokens.enterEase,
              sizeCurve: MotionTokens.enterEase,
            ),
            Expanded(
              child: SceneTransition(
                sceneKey: ValueKey<int>(_index),
                scene: _buildStep(_index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
