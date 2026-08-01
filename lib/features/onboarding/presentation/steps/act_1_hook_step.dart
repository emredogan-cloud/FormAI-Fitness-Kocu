import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/motion/glow_pulse.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/legal_urls.dart';
import '../../../../core/utils/text_span_split.dart';
import '../../../../l10n/app_localizations.dart';

/// Act 1 · Emotional hook — the "Başla" entry screen.
///
/// Closed-test UI hotfix (Task 1 + 3): the old full-bleed neon-robot artwork
/// ("old AI coach", photos/onboarding_hero_start.webp) is gone. The screen is
/// rebuilt natively around the current official Form coach
/// (photos/PT_FORM.png) per photos/new-image/giriş-page-redesign.png:
///   • a perfectly centered, safe-area-aware FormAI wordmark up top (Task 3),
///   • a two-column hero (AI-destekli badge + gradient title + coach cutout),
///   • the "AI KOÇ · KİŞİSEL PLAN · GERÇEK SONUÇ" capability card,
///   • a compact AI-analysis preview card,
///   • a trust row, and the BAŞLA CTA.
/// Everything scrolls, so it never overflows on a 6.1" phone. RevenueCat and
/// the onboarding flow are untouched — only `onStart` fires the wizard.
class WelcomeStep extends StatefulWidget {
  const WelcomeStep({super.key, required this.onStart});
  final VoidCallback onStart;

  @override
  State<WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends State<WelcomeStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;

  /// Gates the CTA glow so it doesn't compete with the entrance fade.
  bool _entranceDone = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _intro.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _entranceDone = true);
      }
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.75),
          radius: 1.35,
          colors: [Color(0xFF1B0C40), Color(0xFF0A0612)],
        ),
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _intro,
          child: Column(
            children: [
              // Task 3 · the wordmark is horizontally centered, sits inside
              // the safe area, and carries its own intentional padding.
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 2),
                child: Center(child: _FormAiWordmark()),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _Hero(),
                      SizedBox(height: 12),
                      _CapabilityCard(),
                      SizedBox(height: 10),
                      _AnalysisCard(),
                      SizedBox(height: 10),
                      _TrustCard(),
                    ],
                  ),
                ),
              ),
              // Task 1 (RC-18) · the BAŞLA CTA + legal line are PINNED below
              // the scroll area so the primary CTA is visible immediately —
              // no scrolling is needed to start. The value-prop cards above
              // only scroll on unusually short screens / very large text scales.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Column(
                  children: [
                    _cta(),
                    const SizedBox(height: 10),
                    const _WelcomeLegalLine(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cta() {
    return GlowPulse(
      enabled: _entranceDone,
      color: AppColors.neon,
      minAlpha: 0.45,
      maxAlpha: 0.70,
      minBlur: 24,
      maxBlur: 36,
      spread: 1,
      shape: BoxShape.rectangle,
      borderRadius: BorderRadius.circular(20),
      duration: const Duration(milliseconds: 3000),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () {
            AppHaptics.secondaryTap();
            widget.onStart();
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.neon,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              fontSize: 18,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  AppLocalizations.of(context).act1Cta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_rounded, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered neon "FormAI" wordmark (Task 3).
class _FormAiWordmark extends StatelessWidget {
  const _FormAiWordmark();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [AppColors.neon, AppColors.neonAccent],
      ).createShader(rect),
      child: const Text(
        'FormAI', // i18n-ignore
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
          shadows: [Shadow(blurRadius: 20, color: Color(0x998E5BFF))],
        ),
      ),
    );
  }
}

/// Two-column hero: AI-destekli badge + gradient title + subtitle on the left,
/// the official Form coach cutout on the right.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    // Task 2 (RC-18) · IntrinsicHeight makes the hero size to its copy column
    // (adaptive, overflow-safe at any width / text scale); the coach fills
    // that height. Replaces the previous fixed 300 px.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 51,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _AiDestekliBadge(),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.12,
                      letterSpacing: 0.3,
                      color: Colors.white,
                    ),
                    children: splitHighlighted(
                      AppLocalizations.of(context).act1HeroTitle(
                        AppLocalizations.of(context).act1HeroTitleHighlight,
                      ),
                      AppLocalizations.of(context).act1HeroTitleHighlight,
                      const TextStyle(color: AppColors.neon),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(context).act1HeroBlurb,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 49,
            // Positioned.fill keeps the photo from driving the IntrinsicHeight
            // (the copy column does); the coach then cover-fills that height.
            child: Stack(
              children: [
                Positioned.fill(
                  child: ShaderMask(
                    // Fade the coach's left/bottom edges into the dark backdrop
                    // so the photo reads as a cutout, not a boxed image.
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [Colors.transparent, Colors.white, Colors.white],
                      stops: [0.0, 0.32, 1.0],
                    ).createShader(rect),
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'photos/PT_FORM.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "✦ AI DESTEKLİ" pill.
class _AiDestekliBadge extends StatelessWidget {
  const _AiDestekliBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppColors.neon.withValues(alpha: 0.14),
        border: Border.all(color: AppColors.neon.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.neonAccent, size: 13),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              AppLocalizations.of(context).act1AiBadge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The three-capability card (AI KOÇ · KİŞİSEL PLAN · GERÇEK SONUÇ).
class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Capability(
              icon: Icons.psychology_rounded,
              title: l10n.act1CapCoachTitle,
              body: l10n.act1CapCoachBody,
            ),
          ),
          _CapDivider(),
          Expanded(
            child: _Capability(
              icon: Icons.track_changes_rounded,
              title: l10n.act1CapPlanTitle,
              body: l10n.act1CapPlanBody,
            ),
          ),
          _CapDivider(),
          Expanded(
            child: _Capability(
              icon: Icons.show_chart_rounded,
              title: l10n.act1CapResultTitle,
              body: l10n.act1CapResultBody,
            ),
          ),
        ],
      ),
    );
  }
}

class _CapDivider extends StatelessWidget {
  const _CapDivider();
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 56,
        color: Colors.white.withValues(alpha: 0.08),
      );
}

class _Capability extends StatelessWidget {
  const _Capability({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Icon(icon, color: AppColors.neonAccent, size: 26),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact AI form-analysis preview: an 82% readiness ring + target stats.
/// Illustrative (same preview the old baked artwork showed) — no user data.
class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.neon.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        border: Border.all(color: AppColors.neon.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: 0.82,
                    strokeWidth: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF39FF14)),
                  ),
                ),
                const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '%82',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'HAZIRLIK',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.liveFormAnalysisEyebrow,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        l10n.act1AnalysisTargetLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        l10n.act1AnalysisTargetValue(94),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF39FF14),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.94,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                    valueColor: const AlwaysStoppedAnimation(AppColors.neon),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Four trust tiles (güvenli · zaman · verim · hedef).
class _TrustCard extends StatelessWidget {
  const _TrustCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Trust(
              icon: Icons.verified_user_rounded,
              title: l10n.act1TrustSafeTitle,
              body: l10n.act1TrustSafeBody,
            ),
          ),
          Expanded(
            child: _Trust(
              icon: Icons.timer_rounded,
              title: l10n.act1TrustFastTitle,
              body: l10n.act1TrustFastBody,
            ),
          ),
          Expanded(
            child: _Trust(
              icon: Icons.local_fire_department_rounded,
              title: l10n.act1TrustEfficientTitle,
              body: l10n.act1TrustEfficientBody,
            ),
          ),
          Expanded(
            child: _Trust(
              icon: Icons.emoji_events_rounded,
              title: l10n.act1TrustGoalTitle,
              body: l10n.act1TrustGoalBody,
            ),
          ),
        ],
      ),
    );
  }
}

class _Trust extends StatelessWidget {
  const _Trust({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Icon(icon, color: AppColors.neon, size: 22),
          const SizedBox(height: 7),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9.5,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeLegalLine extends StatefulWidget {
  const _WelcomeLegalLine();

  @override
  State<_WelcomeLegalLine> createState() => _WelcomeLegalLineState();
}

class _WelcomeLegalLineState extends State<_WelcomeLegalLine> {
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => openLegalUrl(LegalUrls.terms);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => openLegalUrl(LegalUrls.privacy);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(color: Colors.white54, fontSize: 11);
    final linkStyle = baseStyle.copyWith(
      color: const Color(0xFF00F0FF),
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xFF00F0FF).withValues(alpha: 0.8),
    );
    final l10n = AppLocalizations.of(context);
    final terms = l10n.legalTermsLabel;
    final privacy = l10n.legalPrivacyLabel;
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: splitLinked(
          l10n.act1LegalNotice(terms, privacy),
          {terms: _termsTap, privacy: _privacyTap},
          linkStyle,
        ),
      ),
      textAlign: TextAlign.center,
    );
  }
}
