import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Cinematic rebuild · the wizard orchestrator. Owns the [PageController],
/// the index state, the navigation transitions, and the exit-to-paywall
/// finisher. Every step widget lives in its own act file under `steps/`.
///
/// The 12-step act mapping:
///   • Act 1 (welcome) — emotional hook, immersive hero.
///   • Act 2 (coach_intro) — the named coach Form introduces itself.
///   • Act 3 (gender → goal → experience → daily_minutes → activity →
///     physical_data → pain_point) — transformation buildup, data
///     collection wrapped in coach voice.
///   • Act 4 (analysis_illusion → dynamic_report) — labor-illusion +
///     personalised AI report reveal.
///   • Act 5 (pre_paywall_summary) — commitment moment, plan card +
///     trust booster + paywall handoff.
///
/// New screens (name capture, habit anchor, push opt-in, identity
/// declaration, microcommitment, first-workout prompt) get added inside
/// the appropriate act file as they ship — the orchestrator only extends
/// [_stepNames] and the PageView children list.
const int _totalSteps = 12;
const int _hookSteps = 2;

const List<String> _stepNames = [
  'welcome',
  'coach_intro',
  'gender',
  'goal',
  'experience_level',
  'daily_minutes',
  'activity',
  'physical_data',
  'pain_point',
  'analysis_illusion',
  'dynamic_report',
  'pre_paywall_summary',
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
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
    // event. PageView.onPageChanged never emits for the initial page.
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= _totalSteps - 1) return;
    // UX rule §4: every forward step transition fires a medium impact so
    // the user feels the wizard *progressing* rather than just sliding
    // silently. Light impact on the tap that initiated the transition is
    // fired by the calling widget.
    AppHaptics.primaryCta();
    _controller.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_index == 0) return;
    AppHaptics.secondaryTap();
    _controller.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
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

  @override
  Widget build(BuildContext context) {
    final showHeader = _index >= _hookSteps;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            if (showHeader)
              WizardHeader(
                step: _index - _hookSteps + 1,
                total: _totalSteps - _hookSteps,
                onBack: _index == 0 ? null : _back,
              ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) {
                  setState(() => _index = i);
                  AnalyticsService.instance.onboardingStepCompleted(
                    stepIndex: i,
                    stepName:
                        i < _stepNames.length ? _stepNames[i] : 'unknown_$i',
                  );
                },
                children: [
                  WelcomeStep(onStart: _next),
                  CoachIntroStep(onContinue: _next),
                  GenderStep(onCommitted: _next),
                  GoalStep(onCommitted: _next),
                  ExperienceStep(onCommitted: _next),
                  DailyMinutesStep(onCommitted: _next),
                  ActivityStep(onCommitted: _next),
                  PhysicalDataStep(onContinue: _next),
                  PainPointStep(onCommitted: _next),
                  AnalysisIllusionStep(onComplete: _next),
                  DynamicReportStep(onComplete: _next),
                  PrePaywallSummaryStep(onComplete: _finish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
