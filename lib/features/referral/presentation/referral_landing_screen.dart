import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/theme_extension.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/referral_provider.dart';
import '../services/referral_service.dart';
import '../../../l10n/app_localizations.dart';

/// Phase 54 · landing screen reached via the `formai://r/<code>` deep
/// link. Two roles:
///
///   1. Pre-auth (anonymous user landed from a friend's share) →
///      surface the "1 ay ücretsiz Pro" pitch + a CTA to start
///      onboarding. The code is stashed in SharedPreferences so the
///      auto-redeem step at the end of onboarding can call the
///      Supabase RPC the moment the new user has a real auth.uid().
///
///   2. Post-auth (existing user reopened the link) → either redeem
///      the code right now (if they haven't redeemed one yet) or show
///      a polite "you've already redeemed" state.
class ReferralLandingScreen extends ConsumerStatefulWidget {
  const ReferralLandingScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<ReferralLandingScreen> createState() =>
      _ReferralLandingScreenState();
}

class _ReferralLandingScreenState extends ConsumerState<ReferralLandingScreen> {
  bool _redeeming = false;
  String? _error;
  bool _redeemed = false;

  Future<void> _attemptRedeem() async {
    setState(() {
      _redeeming = true;
      _error = null;
    });
    try {
      await ref.read(referralServiceProvider).redeem(widget.code);
      AnalyticsService.instance
          .referralRedeemed(referrerCode: widget.code.toUpperCase());
      if (!mounted) return;
      setState(() => _redeemed = true);
    } on ReferralException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.localizedMessage(AppLocalizations.of(context)));
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAnonOrSignedOut = user == null || user.isAnonymous;
    final scheme = context.colors;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: Icon(Icons.close, color: scheme.onSurface),
                onPressed: () => context.go(AppRoutes.dashboard),
              ),
              const Spacer(),
              Text(
                AppLocalizations.of(context).referralInvited,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).referralJoinPitch,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.65),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              _CodeCard(code: widget.code),
              const SizedBox(height: 24),
              if (_redeemed)
                _SuccessBanner(
                  message: AppLocalizations.of(context).referralSavedNotice,
                )
              else if (_error != null)
                _ErrorBanner(message: _error!),
              const Spacer(),
              if (_redeemed)
                FilledButton(
                  onPressed: () => context.go(AppRoutes.dashboard),
                  child: const Text('Devam Et'),
                )
              else if (isAnonOrSignedOut)
                FilledButton(
                  onPressed: () => context.go(AppRoutes.auth),
                  child:
                      Text(AppLocalizations.of(context).referralCreateAccount),
                )
              else
                FilledButton(
                  onPressed: _redeeming ? null : _attemptRedeem,
                  child: _redeeming
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(AppLocalizations.of(context).referralAccept),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
      child: Row(
        children: [
          Icon(Icons.card_giftcard, color: scheme.primary, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAVET KODU',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 11,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  code.toUpperCase(),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 26,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy, color: scheme.onSurface),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code.toUpperCase()));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text(AppLocalizations.of(context).referralCodeCopied)),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.green.withValues(alpha: 0.12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: context.colors.onSurface, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.red.withValues(alpha: 0.12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: context.colors.onSurface, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
