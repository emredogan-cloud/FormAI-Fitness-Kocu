import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../l10n/app_localizations.dart';

/// Phase 138 · B-4 · 18+ verification gate.
///
/// Sits between a fresh install and the PII-collecting onboarding
/// wizard. The user picks their birth year on a Cupertino-style
/// wheel; on submit we compute age against the device's current
/// year. Age ≥ 18 stamps [AppPreferences.setAgeVerified] and routes
/// on to `/onboarding`. Anyone under 18 is shown a non-dismissible
/// block screen with a single "Uygulamayı Kapat" action wired to
/// `SystemNavigator.pop()` — they leave the experience entirely.
///
/// The screen is intentionally framed BEFORE name capture / coach
/// chat / body-feelings so no personal data is collected until the
/// user has self-attested to the Play Console "Target audience: 18+"
/// declaration the listing carries.
class AgeGateScreen extends ConsumerStatefulWidget {
  const AgeGateScreen({super.key});

  @override
  ConsumerState<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends ConsumerState<AgeGateScreen> {
  // The minimum age the gate accepts. Aligned with the existing
  // PhysicalDataStep wheel's lower bound (18) and the Play Console
  // "Target audience: 18+" recommendation in the launch master plan.
  static const int _minAge = 18;

  // Wheel bounds. 1940 is far enough back that a 85-year-old can
  // still pick their year; 2026 is the device "now" for first
  // ship — DateTime.now() is consulted for the actual age math so
  // the cutoff naturally rolls forward each January.
  static const int _minYear = 1940;
  // Default the wheel to year-2000 (26 years old in 2026). Chosen
  // because it's the most common adult cohort and keeps the wheel
  // anchored in the middle of the range so the user can scroll
  // either direction without first having to flick through 60+
  // years of empty options.
  static const int _defaultYear = 2000;

  late final FixedExtentScrollController _yearCtrl;
  late int _selectedYear;
  bool _underAge = false;

  @override
  void initState() {
    super.initState();
    _selectedYear = _defaultYear;
    _yearCtrl = FixedExtentScrollController(
      initialItem: _defaultYear - _minYear,
    );
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    super.dispose();
  }

  int get _currentYear => DateTime.now().year;
  int get _maxYear => _currentYear;
  int get _computedAge => _currentYear - _selectedYear;

  Future<void> _onContinue() async {
    AppHaptics.primaryCta();
    if (_computedAge < _minAge) {
      // Reveal the block screen instead of routing forward. The
      // PopScope below makes sure the system-back gesture can't
      // bounce them back to the wheel and quietly retry — the only
      // exit is the explicit "Uygulamayı Kapat" button.
      setState(() => _underAge = true);
      return;
    }
    final prefs = ref.read(appPreferencesProvider);
    await prefs.setAgeVerified(birthYear: _selectedYear);
    if (!mounted) return;
    context.go(AppRoutes.onboarding);
  }

  void _exit() {
    AppHaptics.secondaryTap();
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: _underAge ? _BlockedView(onExit: _exit) : _buildPicker(),
        ),
      ),
    );
  }

  Widget _buildPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).ageGatePickYear,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).ageGateExplain,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: _YearWheel(
              controller: _yearCtrl,
              minYear: _minYear,
              maxYear: _maxYear,
              current: _selectedYear,
              onChanged: (y) => setState(() => _selectedYear = y),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8E5BFF),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              AppLocalizations.of(context).ageGateContinue,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).ageGatePrivacyNote,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _YearWheel extends StatelessWidget {
  const _YearWheel({
    required this.controller,
    required this.minYear,
    required this.maxYear,
    required this.current,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int minYear;
  final int maxYear;
  final int current;
  final ValueChanged<int> onChanged;

  static const Color _neon = Color(0xFF8E5BFF);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 64,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: _neon.withValues(alpha: 0.6),
                width: 1.2,
              ),
              bottom: BorderSide(
                color: _neon.withValues(alpha: 0.6),
                width: 1.2,
              ),
            ),
          ),
        ),
        ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 64,
          perspective: 0.003,
          diameterRatio: 1.6,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (i) => onChanged(minYear + i),
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: maxYear - minYear + 1,
            builder: (context, i) {
              final value = minYear + i;
              final selected = value == current;
              return Center(
                child: Text(
                  '$value',
                  style: TextStyle(
                    color: selected ? _neon : Colors.white54,
                    fontSize: selected ? 40 : 26,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w500,
                    shadows: selected
                        ? const [Shadow(blurRadius: 14, color: _neon)]
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BlockedView extends StatelessWidget {
  const _BlockedView({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_outline,
            color: Colors.white54,
            size: 64,
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context).ageGateSorryTitle,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            AppLocalizations.of(context).ageGateSorryBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          FilledButton(
            onPressed: onExit,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white10,
              foregroundColor: Colors.white,
              minimumSize: const Size(220, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.white24),
              ),
            ),
            child: Text(
              AppLocalizations.of(context).ageGateCloseApp,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
