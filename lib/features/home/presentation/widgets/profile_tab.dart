import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../../core/services/feature_flags.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/services/tour_service.dart';
import '../../../../core/theme/theme_extension.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/audio_feedback.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../feedback/presentation/feedback_sheet.dart';
import '../../../feedback/services/feedback_service.dart';
import '../../../monetization/presentation/churn_survey_sheet.dart';
import '../../../monetization/providers/monetization_provider.dart';
import '../../../monetization/services/rating_moment_service.dart';
import '../../../referral/providers/referral_provider.dart';
import '../../../progress/providers/streak_provider.dart';
import '../../../progress/providers/xp_provider.dart';
import '../../../referral/services/referral_service.dart';
import '../../../workout/providers/workout_provider.dart';
import '../dashboard_screen.dart';
import 'stat_tile.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);
const Color _danger = Color(0xFFFF4D6D);

// Target physique enum names live in SharedPreferences as raw strings; these
// are the same values used by the onboarding wizard. Keeping the map local so
// we don't leak UI labels back into the wizard provider.
/// Keys are the values stored in SharedPreferences and written by the
/// onboarding wizard — DATA, never localized. Only the labels are copy,
/// which is why they are lookups: the map is `const`.
const Map<String, String Function(AppLocalizations)> _goalLabels = {
  'tone': _goalTone,
  'bulk': _goalBulk,
  'sixpack': _goalSixpack,
};

String _goalTone(AppLocalizations l) => l.goalToneLabel;
String _goalBulk(AppLocalizations l) => l.goalBulkLabel;
String _goalSixpack(AppLocalizations l) => l.goalSixpackLabel;

/// The onboarding Goal step writes `goal` (a distinct taxonomy from the
/// account-settings `targetPhysique` enum). Without this fallback map,
/// every onboarding-completed user saw "HEDEF —" because the profile
/// only read `targetPhysique`, which onboarding never sets.
const Map<String, String Function(AppLocalizations)> _onboardingGoalLabels = {
  'belly_burn': _goalBellyBurn,
  'muscle_gain': _goalMuscleGain,
  'fitness_look': _goalFitnessLook,
  'strength': _goalStrength,
};

String _goalBellyBurn(AppLocalizations l) => l.goalBellyBurnLabel;
String _goalMuscleGain(AppLocalizations l) => l.goalMuscleGainLabel;
String _goalFitnessLook(AppLocalizations l) => l.goalFitnessLookLabel;
String _goalStrength(AppLocalizations l) => l.goalStrengthLabel;

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(workoutSessionProvider).value;
    final prefs = ref.watch(appPreferencesProvider);
    final metrics = prefs.userMetrics ?? const {};
    final user = ref.watch(currentUserProvider);

    final completed = session?.days.where((d) => d.isCompleted).length ?? 0;
    final streak = ref.watch(currentStreakProvider);
    final weight = metrics['weightKg'];
    final height = metrics['heightCm'];
    final age = metrics['age'];
    // Prefer the account-settings enum; fall back to the onboarding goal
    // so a user who only completed onboarding still sees their target
    // (previously always "—" for that path).
    final goalKey = metrics['targetPhysique'] as String?;
    final onboardingGoal = metrics['goal'] as String?;
    final l10n = AppLocalizations.of(context);
    final goalLabel = goalKey != null
        ? (_goalLabels[goalKey]?.call(l10n) ?? goalKey)
        : (onboardingGoal != null
            ? (_onboardingGoalLabels[onboardingGoal]?.call(l10n) ?? '—')
            : '—');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _ProfileHeader(email: user?.email, isGuest: user?.isAnonymous ?? false),
        const SizedBox(height: 22),
        _SettingsHeader(title: l10n.profileSectionMyInfo),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                label: l10n.profileFieldAge,
                value: age == null ? '—' : '$age',
                icon: Icons.cake_outlined,
                onTap: () => _openEditSheet(metrics),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoTile(
                label: l10n.profileFieldWeight,
                value: weight == null ? '—' : l10n.profileWeightKg(weight),
                icon: Icons.monitor_weight_outlined,
                onTap: () => _openEditSheet(metrics),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                label: l10n.profileFieldHeight,
                value: height == null ? '—' : l10n.profileHeightCm(height),
                icon: Icons.height,
                onTap: () => _openEditSheet(metrics),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoTile(
                label: l10n.profileFieldGoal,
                value: goalLabel,
                icon: Icons.flag_outlined,
                onTap: () => _openEditSheet(metrics),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _openEditSheet(metrics),
            icon: const Icon(Icons.edit, size: 18),
            label: Text(l10n.profileEdit),
            style: FilledButton.styleFrom(
              backgroundColor: _neon,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _SettingsHeader(title: l10n.profileSectionProgress),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: l10n.profileStatStreak,
                value: l10n.profileStreakDays(streak),
                icon: Icons.local_fire_department,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: l10n.profileStatCompleted,
                value: l10n.profileCompletedOfTotal(completed, 30),
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        // Phase 48.1 · `HESAP AYARLARI` block surfaces the four
        // mandated account actions (Profili Düzenle, Şifreyi Değiştir,
        // Bildirimler, Hesabı Sil) as discrete, always-visible tiles
        // rather than burying them behind a single "Hesap Ayarları"
        // shortcut. The PM specifically flagged this section as
        // missing in the Phase 48 review; rebuilding it here keeps the
        // discovery cost to a single tap from the Profile tab.
        _SettingsHeader(title: l10n.profileSectionAccount),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.person_outline,
          title: l10n.profileEditProfileTitle,
          subtitle: l10n.profileEditProfileSubtitle,
          onTap: () => _openEditSheet(metrics),
        ),
        _SettingsTile(
          icon: Icons.lock_outline,
          title: l10n.profileChangePasswordTitle,
          subtitle: user?.isAnonymous ?? true
              ? l10n.profileChangePasswordGuestSubtitle
              : l10n.profileChangePasswordSubtitle,
          onTap: user?.isAnonymous ?? true
              ? null
              : () => _openChangePasswordSheet(context),
        ),
        _SettingsTile(
          icon: Icons.notifications_outlined,
          title: l10n.profileNotificationsTitle,
          subtitle: l10n.profileNotificationsSubtitle,
          onTap: () => _pickReminderTime(context),
        ),
        if (!(user?.isAnonymous ?? true))
          _DangerSettingsTile(
            icon: Icons.delete_forever_outlined,
            title: l10n.profileDeleteAccountTitle,
            subtitle: l10n.profileDeleteAccountSubtitle,
            onTap: () => context.push(AppRoutes.accountSettings),
          ),
        // Phase 50D · admin entry point. Conditionally rendered based on
        // the JWT `app_metadata.role = 'admin'` claim — non-admins never
        // see this section, so the path stays invisible to regular
        // users. The router re-checks the claim in its redirect rule
        // anyway, so even a manually-typed `/admin` URL bounces back
        // to the dashboard for non-admins; this tile is purely the
        // discoverability fix for the legitimate admin flow.
        if (ref.watch(isAdminProvider)) ...[
          const SizedBox(height: 28),
          _SettingsHeader(title: l10n.profileSectionAdmin),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.admin_panel_settings,
            title: l10n.profileAdminPanelTitle,
            subtitle: l10n.profileAdminPanelSubtitle,
            onTap: () => context.push(AppRoutes.admin),
          ),
        ],
        // Phase 54 · referral block. Drop-in section showing the
        // user's stable 6-char code with copy + native-share affordances.
        // Sits above AYARLAR so it's the first thing users see after
        // their HESAP AYARLARI block — high-conversion zone for the
        // viral CAC offset.
        const SizedBox(height: 28),
        _SettingsHeader(title: l10n.profileSectionInviteFriend),
        const SizedBox(height: 10),
        const _ReferralCard(),
        // Phase 54B · manual fallback. Even with deep links wired
        // through Android intent-filters + iOS CFBundleURLTypes, a
        // share that lands as plain text in WhatsApp / Instagram DM
        // doesn't always auto-linkify (older clients, copied
        // screenshots, etc.) — so a typed "Bir Davet Kodu Kullan" tile
        // is the safety net the PM asked for. Sits directly under the
        // user's own card so the relationship between "your code" and
        // "redeem someone else's" reads as one cohesive block.
        const SizedBox(height: 8),
        _SettingsTile(
          icon: Icons.qr_code_2_rounded,
          title: l10n.profileRedeemCodeTitle,
          subtitle: l10n.profileRedeemCodeSubtitle,
          onTap: () => _openManualReferralDialog(context),
        ),
        // Phase 56 Lite · BESLENMEM block. Single-tile entry point for
        // now (Favorilerim); structured as its own section so future
        // nutrition-personal surfaces (history, AI suggestions
        // archive) drop in next to it without re-cutting the profile
        // layout.
        const SizedBox(height: 28),
        _SettingsHeader(title: l10n.profileSectionNutrition),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.favorite,
          title: l10n.profileFavouritesTitle,
          subtitle: l10n.profileFavouritesSubtitle,
          onTap: () => context.push(AppRoutes.nutritionFavorites),
        ),
        const SizedBox(height: 28),
        _SettingsHeader(title: l10n.profileSectionSettings),
        const SizedBox(height: 10),
        // Phase 53 · theme picker. Sits at the top of AYARLAR (above
        // Premium / Sesli Koç / Gizlilik) because dark/light is the
        // setting users hunt for first when the OS-level pref doesn't
        // match what they want for FormAI specifically.
        const _ThemeModeTile(),
        // Roadmap Phase 6 (R3.2) · the language row. Next to the theme
        // picker because they are the same kind of setting — "render the
        // app the way I want it", not "change what the app does". The
        // subtitle is the active language written in itself, so a user
        // who set the wrong one can find their way back without being
        // able to read the label above it.
        _SettingsTile(
          icon: Icons.language,
          title: l10n.languageSettingsTitle,
          subtitle: localeEndonym(Localizations.localeOf(context)),
          onTap: () => _openLanguageSheet(context),
        ),
        _SettingsTile(
          icon: Icons.workspace_premium,
          title: l10n.profilePremiumTitle,
          subtitle: l10n.profilePremiumSubtitle,
          onTap: () => context.push(AppRoutes.paywall),
        ),
        // Phase 56 Lite · cancel-subscription tile, only rendered when
        // the user has an active Pro entitlement. Tapping pops the
        // churn survey first; the survey's analytics breadcrumb is
        // captured before the user is handed off to the platform's
        // subscription-management URL where the actual cancellation
        // happens.
        if (ref.watch(isProProvider))
          _SettingsTile(
            icon: Icons.cancel_outlined,
            title: l10n.profileCancelSubTitle,
            subtitle: l10n.profileCancelSubSubtitle,
            onTap: () => _runChurnFlow(context),
          ),
        _SettingsTile(
          icon: Icons.volume_up,
          title: l10n.profileTtsTestTitle,
          subtitle: l10n.profileTtsTestSubtitle,
          onTap: () => _runTtsTest(context),
        ),
        _SettingsTile(
          icon: Icons.shield_outlined,
          title: l10n.profilePrivacyTitle,
          subtitle: l10n.profilePrivacySubtitle,
          onTap: () => _openPrivacySheet(context),
        ),
        // Roadmap Phase 1 (R2.1) · the Testers Community observation
        // verbatim: a user who wants to rate the app had no path. Always
        // present — never gated by Pro, never one-shot, never on a
        // cooldown. The prompted rating moment (RatingMomentService) is
        // a separate, rate-limited surface; this one is the user's own.
        _SettingsTile(
          icon: Icons.star_rounded,
          title: l10n.profileRateAppTitle,
          subtitle: l10n.profileRateAppSubtitle,
          onTap: () => _openRateApp(context),
        ),
        // Roadmap Phase 2 (R1.1) · replayable tour. The first-run tour is
        // one-shot, which means a user who skipped it — or was
        // interrupted — would otherwise lose it permanently. This row is
        // that recovery path, and it's also the answer to the Testers
        // Community observation for *returning* users, not just new ones.
        _SettingsTile(
          icon: Icons.explore_outlined,
          title: l10n.profileAppTourTitle,
          subtitle: l10n.profileAppTourSubtitle,
          onTap: () => _replayTour(context),
        ),
        // Roadmap Phase 4 (C28) · the capability map. Sits beside the
        // tour because the two answer the same question at different
        // depths: the tour shows where things are, the hub shows what
        // exists — including what hasn't been introduced yet, which is
        // the part staged disclosure owes the user.
        if (ref.watch(featureFlagProvider(FeatureFlag.discoveryHub)))
          _SettingsTile(
            icon: Icons.auto_awesome_mosaic_outlined,
            title: l10n.profileDiscoverTitle,
            subtitle: l10n.profileDiscoverSubtitle,
            onTap: () => context.push(AppRoutes.discoveryHub),
          ),
        // Roadmap Phase 1 (C30) · sits directly above the feedback row
        // so a user with a question finds the answer before writing a
        // ticket.
        _SettingsTile(
          icon: Icons.help_outline_rounded,
          title: l10n.profileHelpCentreTitle,
          subtitle: l10n.profileHelpCentreSubtitle,
          onTap: () => context.push(AppRoutes.helpCenter),
        ),
        // Phase 56 Lite · "Destek" → "Destek & Geri Bildirim". The
        // tile now opens the in-app feedback sheet (subject dropdown +
        // message), and FeedbackService falls through to the same
        // mailto path the Phase 47 tile used when Supabase isn't
        // reachable. Net result: the user always has a path forward,
        // and we capture structured data when conditions allow it.
        _SettingsTile(
          icon: Icons.support_agent,
          title: l10n.profileSupportTitle,
          subtitle: l10n.profileSupportSubtitle,
          onTap: () => _openFeedback(context),
        ),
        if (user?.isAnonymous ?? false)
          _GuestLoginTile(onTap: () => context.push(AppRoutes.auth))
        else
          _SettingsTile(
            icon: Icons.logout,
            title: l10n.profileSignOut,
            onTap: () => _signOut(context),
          ),
      ],
    );
  }

  Future<void> _openEditSheet(Map<String, dynamic> initial) async {
    // Phase 53H · drop the hardcoded `0xFF111118` so the sheet picks
    // up the active theme's surface tone — white in light mode, dark
    // in dark mode. Keeps the radius treatment the user expects.
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditProfileSheet(initial: initial),
    );
    if (result == null || !mounted) return;

    final prefs = ref.read(appPreferencesProvider);
    final merged = <String, dynamic>{...initial, ...result};
    await prefs.saveUserMetrics(merged);
    if (!mounted) return;
    setState(
        () {}); // userMetrics reads fresh from SharedPreferences on next build
    _toast(context, AppLocalizations.of(context).profileDetailsUpdated);
  }

  Future<void> _openChangePasswordSheet(BuildContext context) async {
    final password = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ChangePasswordSheet(),
    );
    if (password == null || password.isEmpty || !context.mounted) return;
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      if (!context.mounted) return;
      _toast(context, AppLocalizations.of(context).profilePasswordUpdated);
    } on AuthException catch (e, st) {
      AppLogger.warning(
        'updatePassword AuthException',
        category: 'auth',
        data: {'error': e.message, 'stack': st.toString()},
      );
      if (!context.mounted) return;
      // AuthException.message is raw English from Supabase ("Password
      // should be at least 6 characters") — keep it out of the TR UI.
      _toast(
          context, AppLocalizations.of(context).profilePasswordUpdateRejected);
    } catch (e, st) {
      AppLogger.error(
        'updatePassword failed',
        e,
        stackTrace: st,
        category: 'auth',
      );
      if (!context.mounted) return;
      _toast(context, AppLocalizations.of(context).profilePasswordUpdateFailed);
    }
  }

  Future<void> _pickReminderTime(BuildContext context) async {
    // Phase 53H · drop the forced dark colorScheme override so the
    // TimePicker dialog inherits the active app theme. The previous
    // builder pinned the picker to a dark `0xFF1A1A22` surface and
    // white text, which left the dial illegible after the user
    // toggled to Açık. We still tint the active selection to brand
    // `_neon` via a primary override so the picker looks like FormAI
    // chrome in either palette.
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: _neon,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !context.mounted) return;

    final granted = await NotificationService.instance.requestPermissions();
    if (!context.mounted) return;
    if (!granted) {
      _toast(
          context, AppLocalizations.of(context).notificationPermissionDenied);
      return;
    }
    try {
      await NotificationService.instance.scheduleDailyReminder(picked);
    } catch (e) {
      if (context.mounted) {
        _toast(
            context, AppLocalizations.of(context).notificationSetFailed('$e'));
      }
      return;
    }
    if (!context.mounted) return;
    final label = picked.format(context);
    _toast(context, AppLocalizations.of(context).notificationTimeSet(label));
  }

  /// Roadmap Phase 6 (R3.2) · language selection, applied on tap.
  ///
  /// The sheet stays open after a selection so the user sees the change
  /// land underneath it — every label in the sheet, including the one
  /// they just tapped, re-renders in the new language. Closing on tap
  /// would hide the only immediate confirmation the change worked.
  Future<void> _openLanguageSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _LanguageSheet(),
    );
  }

  Future<void> _openPrivacySheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _PrivacySheet(),
    );
  }

  /// Phase 54B · manual referral redemption dialog. Belt-and-braces for
  /// the deep-link flow — a 6-char TextField that hands the entered
  /// code to `ReferralService.redeem` and surfaces the typed
  /// [ReferralException] message verbatim on error.
  Future<void> _openManualReferralDialog(BuildContext context) async {
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => const _RedeemReferralDialog(),
    );
    if (code == null || !mounted) return;
    final service = ref.read(referralServiceProvider);
    try {
      await service.redeem(code);
      if (!context.mounted) return;
      _toast(
        context,
        AppLocalizations.of(context).profileReferralSaved,
      );
    } on ReferralException catch (e) {
      if (!context.mounted) return;
      _toast(context, e.localizedMessage(AppLocalizations.of(context)));
    } catch (e, st) {
      AppLogger.error(
        'manual referral redeem failed',
        e,
        stackTrace: st,
        category: 'referral',
      );
      if (!context.mounted) return;
      _toast(context, AppLocalizations.of(context).referralErrorUnknown);
    }
  }

  /// Phase 56 Lite · in-app feedback. The sheet handles the form and
  /// hands a [FeedbackResult] back when the user submits successfully.
  /// We toast a transport-aware message so the user knows whether the
  /// message landed in Supabase (silent on the server) or whether
  /// their mail client opened (because Supabase was unreachable / RLS
  /// rejected the row / the user is fully signed-out).
  /// Roadmap Phase 1 (R2.3) · the toast now also confirms the
  /// participation reward when one was granted. The reward is attached
  /// to *submitting feedback*, never to leaving a rating or review —
  /// see [FeedbackRewardService] for the policy rationale.
  Future<void> _openFeedback(BuildContext context) async {
    final result = await showFeedbackSheet(context);
    if (result == null || !context.mounted) return;
    final base = result.transport == FeedbackTransport.supabase
        ? AppLocalizations.of(context).profileFeedbackSent
        : AppLocalizations.of(context).profileFeedbackMailOpened;
    final reward = result.reward;
    _toast(
      context,
      reward == null
          ? base
          : AppLocalizations.of(context).xpEarnedSuffix(base, reward.xp),
    );
  }

  /// Roadmap Phase 1 (R2.1) · user-initiated store rating. Delegates to
  /// [RatingMomentService.openStoreListing], which tries the platform
  /// store intent, then `market://`, then the https listing — so the tap
  /// does something useful even without Play Services.
  Future<void> _openRateApp(BuildContext context) async {
    await ref.read(ratingMomentProvider).openStoreListing();
  }

  /// Roadmap Phase 2 (R1.1) · replay the dashboard tour.
  ///
  /// The tour spotlights widgets that live on the Antrenman tab and the
  /// bottom nav, so it has to run with the dashboard visible. From the
  /// Profil tab the nav is present but the Antrenman-tab targets are
  /// inside a non-visible `IndexedStack` branch — their RenderBoxes exist
  /// but resolve to stale rects. Switching to Antrenman first is what
  /// makes the replay show the same thing a first-run user saw.
  Future<void> _replayTour(BuildContext context) async {
    DashboardScreen.requestTab(ref, 0);
    // One frame for the IndexedStack to swap branches and lay out.
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!context.mounted) return;
    await ref.read(tourServiceProvider).replayDashboardTour(context);
  }

  /// Phase 56 Lite · churn flow. Pops the survey sheet first
  /// (analytics fires inside the sheet on selection), then deep-links
  /// the user to the platform-specific subscription-management URL.
  /// The actual cancel happens on the App Store / Play Store side —
  /// our job is to capture the *intent* before they leave the app so
  /// the dashboard sees both the reason and the eventual outcome
  /// (RevenueCat → entitlement flip).
  Future<void> _runChurnFlow(BuildContext context) async {
    final reason = await showChurnSurveySheet(context);
    if (reason == null || !context.mounted) return;
    final manageUri = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/account/subscriptions')
        : Uri.parse(
            'https://play.google.com/store/account/subscriptions',
          );
    try {
      await launchUrl(manageUri, mode: LaunchMode.externalApplication);
    } catch (e, st) {
      AppLogger.warning(
        'manage subscriptions launchUrl failed: $e',
        category: 'monetization',
        data: {'stack': st.toString()},
      );
      if (!context.mounted) return;
      _toast(
        context,
        AppLocalizations.of(context).profileCancelPageFailed,
      );
    }
  }

  Future<void> _runTtsTest(BuildContext context) async {
    final audio = AudioFeedback();
    await audio.init();
    await audio.testAudio();
    if (!context.mounted) return;
    _toast(context, AppLocalizations.of(context).profileTtsTestFired);
  }

  Future<void> _signOut(BuildContext context) async {
    // Route through AuthController so the user-scoped providers get
    // invalidated — otherwise the next login inherits this user's cached
    // 30-day plan, pro entitlement, and wizard state.
    try {
      await ref.read(authControllerProvider).signOut();
    } catch (_) {
      if (context.mounted) {
        _toast(context, AppLocalizations.of(context).profileSignOutFailed);
      }
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF2A1B5C),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.initial});
  final Map<String, dynamic> initial;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ageCtl;
  late final TextEditingController _heightCtl;
  late final TextEditingController _weightCtl;
  String? _goal;

  @override
  void initState() {
    super.initState();
    _ageCtl = TextEditingController(
      text: widget.initial['age']?.toString() ?? '',
    );
    _heightCtl = TextEditingController(
      text: widget.initial['heightCm']?.toString() ?? '',
    );
    _weightCtl = TextEditingController(
      text: widget.initial['weightKg']?.toString() ?? '',
    );
    final existingGoal = widget.initial['targetPhysique'] as String?;
    _goal = _goalLabels.containsKey(existingGoal) ? existingGoal : null;
  }

  @override
  void dispose() {
    _ageCtl.dispose();
    _heightCtl.dispose();
    _weightCtl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(<String, dynamic>{
      'age': int.parse(_ageCtl.text),
      'heightCm': int.parse(_heightCtl.text),
      'weightKg': int.parse(_weightCtl.text),
      if (_goal != null) 'targetPhysique': _goal,
    });
  }

  @override
  Widget build(BuildContext context) {
    // Phase 53H · sheet handle, sheet title, and every form field flip
    // through the active ColorScheme. The brand-coloured KAYDET CTA
    // keeps its neon background because that's the primary action.
    final scheme = context.colors;
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + insets),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).profileEditSheetTitle,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              _numberField(
                context: context,
                controller: _ageCtl,
                label: AppLocalizations.of(context).profileEditAge,
                icon: Icons.cake_outlined,
                min: 12,
                max: 100,
              ),
              const SizedBox(height: 12),
              _numberField(
                context: context,
                controller: _heightCtl,
                label: AppLocalizations.of(context).profileHeightFieldLabel,
                icon: Icons.height,
                min: 120,
                max: 230,
              ),
              const SizedBox(height: 12),
              _numberField(
                context: context,
                controller: _weightCtl,
                label: AppLocalizations.of(context).profileWeightFieldLabel,
                icon: Icons.monitor_weight_outlined,
                min: 30,
                max: 250,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _goal,
                dropdownColor: scheme.surface,
                iconEnabledColor: _neon,
                style: TextStyle(color: scheme.onSurface),
                decoration: _decoration(
                  context: context,
                  label: AppLocalizations.of(context).profileEditGoal,
                  icon: Icons.flag_outlined,
                ),
                items: _goalLabels.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value(AppLocalizations.of(context))),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _goal = v),
                validator: (v) => v == null
                    ? AppLocalizations.of(context).profileEditGoalHint
                    : null,
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _neon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('KAYDET'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required int min,
    required int max,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(color: context.colors.onSurface),
      decoration: _decoration(context: context, label: label, icon: icon),
      validator: (value) {
        final v = int.tryParse(value?.trim() ?? '');
        if (v == null) {
          return AppLocalizations.of(context).profileEditInvalidNumber;
        }
        if (v < min || v > max) {
          return AppLocalizations.of(context).profileEditOutOfRange(min, max);
        }
        return null;
      },
    );
  }

  InputDecoration _decoration({
    required BuildContext context,
    required String label,
    required IconData icon,
  }) {
    final scheme = context.colors;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.55)),
      prefixIcon: Icon(icon, color: _neon),
      filled: true,
      fillColor: scheme.onSurface.withValues(alpha: 0.04),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _neon, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Phase 53B · the BİLGİLERİM grid was hardcoded to white text on a
    // 4 % alpha white surface — illegible in light mode. Theme tokens
    // restore the contrast in both palettes.
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color:
                isDark ? Colors.white.withValues(alpha: 0.04) : scheme.surface,
            border: Border.all(color: _neon.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: _neon, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.55),
                      fontSize: 11,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.edit,
                    color: scheme.onSurface.withValues(alpha: 0.38),
                    size: 14,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.email, required this.isGuest});
  final String? email;
  final bool isGuest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = isGuest
        ? AppLocalizations.of(context).profileGuestUser
        : (email ?? AppLocalizations.of(context).profileWelcome);
    // P1-3 · the level/title/XP identity system was computed and
    // persisted with zero UI consumers — the profile now carries it:
    // level badge on the avatar, title + XP line, and a thin
    // progress bar toward the next level.
    final lp = ref.watch(levelProgressProvider);
    final tier = ref.watch(currentTitleProvider);
    final span = lp.nextLevelXp - lp.currentLevelXp;
    final levelPct =
        span <= 0 ? 1.0 : ((lp.xp - lp.currentLevelXp) / span).clamp(0.0, 1.0);
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_neon, _neonAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _neon.withValues(alpha: 0.5),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 32),
            ),
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _neon, width: 1.2),
                ),
                child: Text(
                  AppLocalizations.of(context).levelShort(lp.level),
                  style: TextStyle(
                    color: context.colors.onSurface,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Phase 53 hotfix · "Profil" headline used hardcoded
              // `Colors.white`, leaving white-on-white in light mode.
              // Pull from `onSurface` so it lands as charcoal on the
              // light scaffold and pure white on the dark one.
              Text(
                AppLocalizations.of(context).navProfile,
                style: TextStyle(
                  color: context.colors.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.colors.onSurface.withValues(alpha: 0.65),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).tierXpLine(
                    tier.title(AppLocalizations.of(context)), lp.xp),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _neon.withValues(alpha: 0.95),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: levelPct,
                  minHeight: 5,
                  backgroundColor:
                      context.colors.onSurface.withValues(alpha: 0.10),
                  valueColor: const AlwaysStoppedAnimation<Color>(_neon),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    // Phase 53B · section labels read in both palettes by pulling
    // onSurface at 0.55 alpha — the same secondary-text recipe the
    // tile chrome uses below.
    return Text(
      title,
      style: TextStyle(
        color: context.colors.onSurface.withValues(alpha: 0.55),
        fontSize: 11,
        letterSpacing: 3,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  // Nullable so a "disabled" state (e.g. Şifreyi Değiştir for anonymous
  // users) can render a greyed-out tile that still tells the user *why*
  // it's not actionable instead of disappearing entirely.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Phase 53B · all the hardcoded `Colors.white*` references on this
    // tile produced white-on-white text in light mode. Pull the
    // primary / secondary tones from the active ColorScheme so the
    // tile reads correctly under both palettes. Brand neon stays.
    final disabled = onTap == null;
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    final primary =
        disabled ? scheme.onSurface.withValues(alpha: 0.45) : scheme.onSurface;
    final secondary = scheme.onSurface.withValues(alpha: 0.55);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color:
                isDark ? Colors.white.withValues(alpha: 0.03) : scheme.surface,
            border: Border.all(
              color: isDark ? Colors.white12 : scheme.outlineVariant,
              width: isDark ? 1 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _neon.withValues(alpha: disabled ? 0.06 : 0.18),
                ),
                child: Icon(
                  icon,
                  color: disabled ? secondary : _neon,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: secondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: disabled ? secondary.withValues(alpha: 0.4) : secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phase 53 · theme picker tile. Renders the same chrome as
/// [_SettingsTile] (icon + title block) but slots a 3-segment selector
/// in place of the trailing chevron because the action is a multi-state
/// pick, not a single-tap drill-in.
///
/// Wired to [themeModeProvider] which persists the selection through
/// SharedPreferences. Default is `ThemeMode.system` so a fresh install
/// honours whatever the OS is set to before the user ever visits this
/// tile.
class _ThemeModeTile extends ConsumerWidget {
  const _ThemeModeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    // Phase 53B · same chrome recipe as `_SettingsTile` so the theme
    // picker reads correctly in both palettes.
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? Colors.white.withValues(alpha: 0.03) : scheme.surface,
        border: Border.all(
          color: isDark ? Colors.white12 : scheme.outlineVariant,
          width: isDark ? 1 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _neon.withValues(alpha: 0.18),
                ),
                child: const Icon(
                  Icons.brightness_6_rounded,
                  color: _neon,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).themeTileTitle,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context).themeModeCurrent(
                        themeModeLabel(AppLocalizations.of(context), mode),
                      ),
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // SegmentedButton sizes itself to its content; wrap in a
          // SizedBox to stretch full-width so the three segments balance
          // visually with the tile's title row above.
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(AppLocalizations.of(context).themeModeSystem),
                  icon: Icon(Icons.settings_suggest, size: 16),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(AppLocalizations.of(context).themeModeLight),
                  icon: Icon(Icons.light_mode_outlined, size: 16),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(AppLocalizations.of(context).themeModeDark),
                  icon: Icon(Icons.dark_mode_outlined, size: 16),
                ),
              ],
              selected: {mode},
              showSelectedIcon: false,
              // Phase 53 hotfix · resolve the notifier inside the
              // callback (NOT at build time) so the closure can't
              // capture a stale instance after a hot reload / provider
              // refresh. The Phase 53 build cached `final notifier =
              // ref.read(...)` outside the closure; that pattern was
              // working correctly in isolation, but during the Light
              // mode rebuild storm Riverpod 3.3 ended up walking back
              // through the same widget chain and re-firing the
              // capture, which the framework surfaced as a stack
              // overflow. Inline `ref.read` per the Riverpod docs is
              // the safe pattern.
              onSelectionChanged: (Set<ThemeMode> newSelection) {
                if (newSelection.isEmpty) return;
                ref.read(themeModeProvider.notifier).set(newSelection.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStateProperty.all(
                  const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Roadmap Phase 6 (R3.2) · the language selector.
///
/// A sheet rather than a segmented button: three options fit in
/// segments, but the fourth language would not, and a control that has
/// to be rebuilt the first time the list grows is the wrong control.
///
/// "Device language" is a separate option from picking the language the
/// device happens to use. They look identical the day you choose them
/// and diverge the day the phone's language changes — which is the
/// whole reason the preference distinguishes them.
class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final stored = ref.watch(localeProvider);
    final active = Localizations.localeOf(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.languageSettingsSheetTitle,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _LanguageOption(
              title: l10n.languageFollowDevice,
              detail: l10n.languageFollowDeviceDetail(localeEndonym(active)),
              selected: stored == null,
              onTap: () => ref.read(localeProvider.notifier).set(null),
            ),
            for (final locale in kSupportedLocales)
              _LanguageOption(
                title: localeEndonym(locale),
                selected: stored?.languageCode == locale.languageCode,
                onTap: () => ref.read(localeProvider.notifier).set(locale),
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.title,
    required this.selected,
    required this.onTap,
    this.detail,
  });

  final String title;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text(
        title,
        style: TextStyle(
          color: scheme.onSurface,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      subtitle: detail == null
          ? null
          : Text(
              detail!,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.55),
                fontSize: 12,
              ),
            ),
      trailing: selected ? const Icon(Icons.check, color: _neon) : null,
    );
  }
}

/// Phase 48.1 · destructive variant of `_SettingsTile`. Same chrome,
/// red accent. Used for the "Hesabı Sil" entry inside the HESAP
/// AYARLARI block so the user instantly recognises it as a permanent
/// action without having to navigate into the dedicated screen first.
class _DangerSettingsTile extends StatelessWidget {
  const _DangerSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _danger.withValues(alpha: 0.06),
            border: Border.all(color: _danger.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _danger.withValues(alpha: 0.18),
                ),
                child: Icon(icon, color: _danger, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _danger,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _danger,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phase 48.1 · inline change-password sheet surfaced from the Profile
/// tab's HESAP AYARLARI block. Identical contract to the sheet inside
/// `account_settings_screen.dart`: returns the new password as a String
/// (or null on cancel) so the caller can issue the Supabase
/// `updateUser(password:)` RPC.
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_passwordCtl.text);
  }

  @override
  Widget build(BuildContext context) {
    // Phase 53H · password sheet flips its handle, headings,
    // explainer, both inputs, and the visibility-toggle icon through
    // the active ColorScheme.
    final scheme = context.colors;
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + insets),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).changePasswordTitle,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).changePasswordTooShort,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _passwordCtl,
                obscureText: _obscure,
                style: TextStyle(color: scheme.onSurface),
                decoration: _decoration(
                  context: context,
                  label: AppLocalizations.of(context).changePasswordNewLabel,
                  icon: Icons.lock_outline,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                validator: (value) {
                  final v = value ?? '';
                  if (v.length < 8) {
                    return AppLocalizations.of(context).passwordMinLengthHint;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmCtl,
                obscureText: _obscure,
                style: TextStyle(color: scheme.onSurface),
                decoration: _decoration(
                  context: context,
                  label: AppLocalizations.of(context).changePasswordRepeatLabel,
                  icon: Icons.lock_outline,
                ),
                validator: (value) {
                  if ((value ?? '') != _passwordCtl.text) {
                    return AppLocalizations.of(context).changePasswordMismatch;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _neon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(AppLocalizations.of(context).changePasswordSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({
    required BuildContext context,
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    final scheme = context.colors;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.55)),
      prefixIcon: Icon(icon, color: _neon),
      suffixIcon: suffix,
      filled: true,
      fillColor: scheme.onSurface.withValues(alpha: 0.04),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _neon, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}

/// CTA shown in place of "Çıkış Yap" when the current user is anonymous.
/// Bigger and louder than a regular settings tile so the conversion is
/// obvious from a glance — this is the whole reason the tab exists for
/// guest users.
class _GuestLoginTile extends StatelessWidget {
  const _GuestLoginTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [_neon, _neonAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.45),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).profileGuestSignUpTitle,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        AppLocalizations.of(context).profileGuestSignUpSubtitle,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacySheet extends StatelessWidget {
  const _PrivacySheet();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: _neon.withValues(alpha: 0.18),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: _neon,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).privacySheetTitle,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _PrivacySection(
              title: AppLocalizations.of(context).privacySheetCameraHeading,
              body: AppLocalizations.of(context).privacySheetCameraBody,
            ),
            const SizedBox(height: 14),
            _PrivacySection(
              title: AppLocalizations.of(context).privacySheetProgressHeading,
              body: AppLocalizations.of(context).privacySheetProgressBody,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: _neon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('KAPAT'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _neon,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          // Phase 53H · privacy section body now reads through onSurface
          // so the explainer paragraphs surface in light mode.
          style: TextStyle(
            color: context.colors.onSurface.withValues(alpha: 0.75),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Phase 54 · referral card on the Profile tab. Shows the user's stable
/// 6-char code with copy + native-share affordances. Reads the code
/// through Riverpod so a fresh install renders a shimmer until the
/// first generation roundtrip completes.
class _ReferralCard extends ConsumerWidget {
  const _ReferralCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeAsync = ref.watch(referralCodeProvider);
    final scheme = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.18),
            scheme.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.card_giftcard, color: scheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).referralCardTitle,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).referralCardBody,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.65),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          codeAsync.when(
            loading: () => const _ReferralCodeSkeleton(),
            error: (_, __) => const _ReferralCodeError(),
            data: (code) => _ReferralCodeRow(code: code),
          ),
        ],
      ),
    );
  }
}

class _ReferralCodeRow extends StatelessWidget {
  const _ReferralCodeRow({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: scheme.surface,
              border: Border.all(
                color: scheme.onSurface.withValues(alpha: 0.10),
              ),
            ),
            child: Text(
              code,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.copy_rounded, color: scheme.onSurface),
          tooltip: AppLocalizations.of(context).commonCopy,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                    content:
                        Text(AppLocalizations.of(context).referralCodeCopied)),
              );
          },
        ),
        const SizedBox(width: 4),
        FilledButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            ShareService.instance.shareReferralCode(
              l10n: AppLocalizations.of(context),
              code: code,
            );
          },
          icon: const Icon(Icons.ios_share_rounded, size: 16),
          label: Text(AppLocalizations.of(context).referralShare),
          style: FilledButton.styleFrom(
            backgroundColor: _neon,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReferralCodeSkeleton extends StatelessWidget {
  const _ReferralCodeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: context.colors.onSurface.withValues(alpha: 0.06),
      ),
    );
  }
}

class _ReferralCodeError extends StatelessWidget {
  const _ReferralCodeError();

  @override
  Widget build(BuildContext context) {
    return Text(
      AppLocalizations.of(context).referralCodeLoadFailed,
      style: TextStyle(
        color: context.colors.error,
        fontSize: 12,
      ),
    );
  }
}

/// Phase 54B · manual fallback dialog for redeeming a friend's invite
/// code. Pops a 6-character uppercase `TextField` that filters input
/// to `[A-Z0-9]` so a user can't paste a lowercase code that the
/// server-side regex would reject. Returns the entered code via
/// `Navigator.pop(context, value)`; the caller wires that to
/// `ReferralService.redeem`.
class _RedeemReferralDialog extends StatefulWidget {
  const _RedeemReferralDialog();

  @override
  State<_RedeemReferralDialog> createState() => _RedeemReferralDialogState();
}

class _RedeemReferralDialogState extends State<_RedeemReferralDialog> {
  final _controller = TextEditingController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final next = _controller.text.length == 6;
      if (next != _ready) setState(() => _ready = next);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim().toUpperCase();
    if (code.length != 6) return;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return AlertDialog(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        AppLocalizations.of(context).referralCodeLabel,
        style: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).referralEnterCodePrompt,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.65),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            maxLength: 6,
            autofocus: true,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              // Force-uppercase as the user types so the live readback
              // matches what the server-side regex expects.
              TextInputFormatter.withFunction((old, next) => next.copyWith(
                    text: next.text.toUpperCase(),
                    selection: next.selection,
                  )),
            ],
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'ABC123',
              hintStyle: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.30),
                letterSpacing: 8,
                fontWeight: FontWeight.w700,
              ),
              filled: true,
              fillColor: scheme.onSurface.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: scheme.onSurface.withValues(alpha: 0.10),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _neon, width: 1.4),
              ),
            ),
            onSubmitted: (_) => _ready ? _submit() : null,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            AppLocalizations.of(context).commonCancel,
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.65)),
          ),
        ),
        FilledButton(
          onPressed: _ready ? _submit : null,
          style: FilledButton.styleFrom(
            backgroundColor: _neon,
            foregroundColor: Colors.white,
            disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.15),
          ),
          child: Text(AppLocalizations.of(context).commonUse),
        ),
      ],
    );
  }
}
