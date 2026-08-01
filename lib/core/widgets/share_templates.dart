import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Phase 54 · off-screen rendering templates for the viral loop.
///
/// These widgets are NEVER mounted in the visible tree; `ShareService`
/// inserts them into a positioned-off-screen overlay, captures the
/// `RepaintBoundary` to a PNG, then disposes the overlay. Because they
/// only ever render off-screen at a fixed pixel size, every dimension
/// is intentionally absolute (px) and every colour is hardcoded — we
/// don't want the active light/dark theme bleeding into the exported
/// asset, the brand template should look identical regardless of the
/// in-app theme the user has selected.
///
/// Two output sizes are supported:
///   • [storySize]  — 1080×1920, Instagram / TikTok / Snap Stories.
///   • [squareSize] — 1080×1080, Instagram feed / WhatsApp Status.
///
/// Each template accepts a `format` and lays itself out for the target
/// frame; story uses a tall vertical hero, square uses a centred badge
/// composition.

const Size storySize = Size(1080, 1920);
const Size squareSize = Size(1080, 1080);

enum ShareFormat { story, square }

const Color _brandPurple = Color(0xFF8E5BFF);
const Color _brandPurpleDeep = Color(0xFF5A2BCC);
const Color _brandAccent = Color(0xFF4DA6FF);
const Color _brandGreen = Color(0xFF39FF14);
const Color _brandText = Color(0xFFFFFFFF);
const Color _brandSubtext = Color(0xFFB0A8D9);
const Color _bgTop = Color(0xFF1E0A40);
const Color _bgBottom = Color(0xFF0A0612);

/// "Progress" template — used by the Gelişim tab share CTA.
///
/// "FormAI ile programımın %X'ini tamamladım!"
class ShareProgressTemplate extends StatelessWidget {
  const ShareProgressTemplate({
    super.key,
    required this.percent,
    required this.completedDays,
    required this.totalDays,
    required this.streak,
    this.format = ShareFormat.story,
  });

  /// 0–100 (integer percentage).
  final int percent;
  final int completedDays;
  final int totalDays;
  final int streak;
  final ShareFormat format;

  @override
  Widget build(BuildContext context) {
    final size = format == ShareFormat.story ? storySize : squareSize;
    return _BrandFrame(
      size: size,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _BrandHeader(),
            const Spacer(),
            Text(
              AppLocalizations.of(context).shareProgramOf,
              style: TextStyle(
                color: _brandSubtext,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 24),
            _PercentRing(percent: percent, size: size),
            const SizedBox(height: 36),
            Text(
              AppLocalizations.of(context).shareCompleted,
              style: TextStyle(
                color: _brandText,
                fontSize: 56,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 48),
            _StatRow(
              left: (
                AppLocalizations.of(context).shareDayUnit,
                '$completedDays / $totalDays'
              ),
              right: (
                AppLocalizations.of(context).shareStreakUnit,
                '$streak 🔥'
              ),
            ),
            const Spacer(),
            const _BrandFooter(),
          ],
        ),
      ),
    );
  }
}

/// "Badge" template — fired from the badge unlock dialog share CTA.
///
/// "FormAI'da [Badge Name] rozetini kazandım!"
class ShareBadgeTemplate extends StatelessWidget {
  const ShareBadgeTemplate({
    super.key,
    required this.badgeName,
    required this.badgeSubtitle,
    required this.badgeEmoji,
    this.format = ShareFormat.story,
  });

  final String badgeName;
  final String badgeSubtitle;
  final String badgeEmoji;
  final ShareFormat format;

  @override
  Widget build(BuildContext context) {
    final size = format == ShareFormat.story ? storySize : squareSize;
    return _BrandFrame(
      size: size,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _BrandHeader(),
            const Spacer(),
            _BadgeCircle(emoji: badgeEmoji),
            const SizedBox(height: 56),
            Text(
              AppLocalizations.of(context).shareNewBadge,
              style: TextStyle(
                color: _brandAccent,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 10,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              badgeName.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _brandText,
                fontSize: 72,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              badgeSubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _brandSubtext,
                fontSize: 32,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const Spacer(),
            const _BrandFooter(),
          ],
        ),
      ),
    );
  }
}

class _BrandFrame extends StatelessWidget {
  const _BrandFrame({required this.size, required this.child});
  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -200,
              right: -200,
              child: _GlowOrb(diameter: 720, color: _brandPurple),
            ),
            const Positioned(
              bottom: -300,
              left: -200,
              child: _GlowOrb(diameter: 800, color: _brandPurpleDeep),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.diameter, required this.color});
  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.45), Colors.transparent],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [_brandPurple, _brandAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _brandPurple.withValues(alpha: 0.55),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'F',
            style: TextStyle(
              color: _brandText,
              fontSize: 38,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 18),
        const Text(
          'FormAI', // i18n-ignore — brand wordmark
          style: TextStyle(
            color: _brandText,
            fontSize: 56,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _BrandFooter extends StatelessWidget {
  const _BrandFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: _brandText.withValues(alpha: 0.08),
        border: Border.all(color: _brandText.withValues(alpha: 0.30), width: 2),
      ),
      child: Text(
        AppLocalizations.of(context).shareFooter,
        style: TextStyle(
          color: _brandText,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PercentRing extends StatelessWidget {
  const _PercentRing({required this.percent, required this.size});
  final int percent;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final diameter = size.height < 1200 ? 460.0 : 560.0;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              strokeWidth: 28,
              strokeCap: StrokeCap.round,
              backgroundColor: _brandText.withValues(alpha: 0.10),
              valueColor: const AlwaysStoppedAnimation(_brandGreen),
            ),
          ),
          Text(
            '%$percent',
            style: const TextStyle(
              color: _brandText,
              fontSize: 180,
              fontWeight: FontWeight.w900,
              height: 1.0,
              letterSpacing: -2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.left, required this.right});
  final (String label, String value) left;
  final (String label, String value) right;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatBlock(label: left.$1, value: left.$2),
        Container(
          width: 2,
          height: 96,
          color: _brandText.withValues(alpha: 0.18),
        ),
        _StatBlock(label: right.$1, value: right.$2),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _brandSubtext,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 6,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          value,
          style: const TextStyle(
            color: _brandText,
            fontSize: 64,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _BadgeCircle extends StatelessWidget {
  const _BadgeCircle({required this.emoji});
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 480,
      height: 480,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [_brandPurple, _brandAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _brandPurple.withValues(alpha: 0.55),
            blurRadius: 80,
            spreadRadius: 10,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 240),
      ),
    );
  }
}
