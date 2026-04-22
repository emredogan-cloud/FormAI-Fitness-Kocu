import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

const Color _danger = Color(0xFFFF4D6D);

/// Dedicated settings surface that hosts destructive account operations
/// inline instead of as modal dialogs. The delete flow here deliberately
/// avoids calling `context.go('/auth')` / `context.pop()` after the RPC —
/// instead we let Supabase's `onAuthStateChange` drive `authRefreshListenable`
/// in the router, which redirects the user to `/auth` without black-screening
/// the transition.
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  static const String _confirmPhrase = 'DELETE';

  final _reasonCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  bool _matches = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _confirmCtl.addListener(_onConfirmChanged);
  }

  void _onConfirmChanged() {
    final next = _confirmCtl.text == _confirmPhrase;
    if (next != _matches) setState(() => _matches = next);
  }

  @override
  void dispose() {
    _confirmCtl.removeListener(_onConfirmChanged);
    _reasonCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  Future<void> _onDeletePressed() async {
    if (_busy || !_matches) return;
    setState(() => _busy = true);
    final outcome = await ref.read(authControllerProvider).deleteAccount();
    if (!mounted) return;
    // On success we do NOT navigate here — Supabase emits a signed-out
    // auth state, which refreshes the router and redirects to /auth. On
    // failure we release the spinner and surface a toast so the user can
    // retry without losing their typed confirmation.
    if (outcome == DeleteAccountOutcome.error) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Hesap silinemedi. Lütfen tekrar dene veya destek ile iletişime geç.',
            ),
            backgroundColor: Color(0xFF2A1B5C),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B12),
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Hesap Ayarları',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _SectionHeader(title: 'TEHLİKELİ BÖLGE', color: _danger),
            const SizedBox(height: 10),
            _DangerCard(
              reasonCtl: _reasonCtl,
              confirmCtl: _confirmCtl,
              confirmPhrase: _confirmPhrase,
              canSubmit: _matches && !_busy,
              busy: _busy,
              onSubmit: _onDeletePressed,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.color});
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 11,
        letterSpacing: 3,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _DangerCard extends StatelessWidget {
  const _DangerCard({
    required this.reasonCtl,
    required this.confirmCtl,
    required this.confirmPhrase,
    required this.canSubmit,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController reasonCtl;
  final TextEditingController confirmCtl;
  final String confirmPhrase;
  final bool canSubmit;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _danger.withValues(alpha: 0.06),
        border: Border.all(color: _danger.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _danger.withValues(alpha: 0.18),
                ),
                child: const Icon(
                  Icons.delete_forever_outlined,
                  color: _danger,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Hesabı Sil',
                  style: TextStyle(
                    color: _danger,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Bu işlem geri alınamaz. Tüm antrenman geçmişiniz, serileriniz '
            've profil bilgileriniz kalıcı olarak silinecektir.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Ayrılma sebebin (opsiyonel)',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: reasonCtl,
            enabled: !busy,
            maxLines: 3,
            minLines: 2,
            style: const TextStyle(color: Colors.white),
            decoration: _decoration(
              hint: 'Örn: Plan fiyatları yüksek geldi',
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Onaylamak için "$confirmPhrase" yazın',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: confirmCtl,
            enabled: !busy,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
            decoration: _decoration(hint: confirmPhrase),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canSubmit ? onSubmit : null,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete_forever, size: 20),
              label: const Text('KALICI OLARAK SİL'),
              style: FilledButton.styleFrom(
                backgroundColor: _danger,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white12,
                disabledForegroundColor: Colors.white38,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _danger.withValues(alpha: 0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _danger, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _danger.withValues(alpha: 0.2)),
      ),
    );
  }
}
