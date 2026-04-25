import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/providers/auth_provider.dart';
import '../../onboarding/providers/wizard_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _danger = Color(0xFFFF4D6D);

const Map<String, String> _goalLabels = {
  'tone': 'Sıkılaşmak',
  'bulk': 'Hacim Kazanmak',
  'sixpack': 'Sadece Six-Pack',
};

/// Dedicated settings surface that hosts the four account-level sections
/// added in Phase 48 (Edit Profile, Change Password, Notifications) plus
/// the destructive Delete Account flow that already shipped in Phase 47.
///
/// The delete flow deliberately avoids calling `context.go('/auth')` /
/// `context.pop()` after the RPC — instead we let Supabase's
/// `onAuthStateChange` drive `authRefreshListenable` in the router,
/// which redirects the user to `/auth` without black-screening the
/// transition.
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  static const String _confirmPhrase = 'DELETE';
  static const TimeOfDay _defaultReminderTime = TimeOfDay(hour: 19, minute: 0);

  final _reasonCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  bool _matches = false;
  bool _busy = false;
  bool _reminderBusy = false;

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

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(appPreferencesProvider);
    final metrics = prefs.userMetrics ?? const <String, dynamic>{};
    final user = ref.watch(currentUserProvider);
    final reminderEnabled = prefs.dailyReminderEnabled;

    // Phase 53G · the entire account-settings screen was hardcoded for
    // dark mode. Drop the Scaffold + AppBar `0xFF0B0B12` so the active
    // ThemeData drives the canvas + chrome.
    final scheme = context.colors;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        title: Text(
          'Hesap Ayarları',
          style: TextStyle(
            color: scheme.onSurface,
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
            const _SectionHeader(title: 'HESAP', color: _neon),
            const SizedBox(height: 10),
            _AccountTile(
              icon: Icons.person_outline,
              title: 'Profili Düzenle',
              subtitle: 'İsim, yaş ve hedefini güncelle.',
              onTap: () => _openEditProfile(metrics),
            ),
            const SizedBox(height: 10),
            _AccountTile(
              icon: Icons.lock_outline,
              title: 'Şifreyi Değiştir',
              subtitle: user?.isAnonymous ?? true
                  ? 'Önce bir hesap oluşturman gerekiyor.'
                  : 'Yeni bir Supabase şifresi belirle.',
              onTap: user?.isAnonymous ?? true
                  ? null
                  : () => _openChangePassword(),
            ),
            const SizedBox(height: 10),
            _NotificationToggleTile(
              enabled: reminderEnabled,
              busy: _reminderBusy,
              onChanged: _onReminderToggle,
            ),
            const SizedBox(height: 24),
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

  // ==========================================================================
  // Edit Profile
  // ==========================================================================

  Future<void> _openEditProfile(Map<String, dynamic> initial) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111118),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditProfileSheet(initial: initial),
    );
    if (result == null || !mounted) return;

    final prefs = ref.read(appPreferencesProvider);
    final merged = <String, dynamic>{...initial, ...result};
    await prefs.saveUserMetrics(merged);
    // Push wizard state in lock-step so dashboards reading directly from
    // the wizard provider (rather than userMetrics) see the new values
    // without a restart.
    final wizard = ref.read(wizardProvider.notifier);
    final age = result['age'] as int?;
    if (age != null) wizard.setAge(age);
    final goalKey = result['targetPhysique'] as String?;
    final goal = _goalFromKey(goalKey);
    if (goal != null) wizard.setTargetPhysique(goal);
    if (!mounted) return;
    setState(() {});
    _toast('Profil güncellendi');
  }

  GoalPhysique? _goalFromKey(String? key) {
    switch (key) {
      case 'tone':
        return GoalPhysique.tone;
      case 'bulk':
        return GoalPhysique.bulk;
      case 'sixpack':
        return GoalPhysique.sixpack;
      default:
        return null;
    }
  }

  // ==========================================================================
  // Change Password
  // ==========================================================================

  Future<void> _openChangePassword() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111118),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ChangePasswordSheet(),
    );
    if (result == null || result.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: result),
      );
      if (!mounted) return;
      _toast('Şifre güncellendi');
    } on AuthException catch (e, st) {
      AppLogger.warning(
        'updatePassword AuthException',
        category: 'auth',
        data: {'error': e.message, 'stack': st.toString()},
      );
      if (!mounted) return;
      _toast('Şifre güncellenemedi: ${e.message}');
    } catch (e, st) {
      AppLogger.error(
        'updatePassword failed',
        e,
        stackTrace: st,
        category: 'auth',
      );
      if (!mounted) return;
      _toast('Şifre güncellenemedi. Lütfen tekrar dene.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ==========================================================================
  // Notifications toggle
  // ==========================================================================

  Future<void> _onReminderToggle(bool enabled) async {
    if (_reminderBusy) return;
    setState(() => _reminderBusy = true);
    final prefs = ref.read(appPreferencesProvider);
    try {
      if (enabled) {
        final granted = await NotificationService.instance.requestPermissions();
        if (!mounted) return;
        if (!granted) {
          _toast('Bildirim izni verilmedi');
          return;
        }
        await NotificationService.instance
            .scheduleDailyReminder(_defaultReminderTime);
        await prefs.setDailyReminderEnabled(true);
        if (!mounted) return;
        _toast('Günlük hatırlatma açıldı (19:00)');
      } else {
        await NotificationService.instance.cancelDailyReminder();
        await prefs.setDailyReminderEnabled(false);
        if (!mounted) return;
        _toast('Günlük hatırlatma kapatıldı');
      }
    } catch (e, st) {
      AppLogger.error(
        'reminder toggle failed',
        e,
        stackTrace: st,
        category: 'notifications',
      );
      if (!mounted) return;
      _toast('Bildirim ayarı uygulanamadı');
    } finally {
      if (mounted) setState(() => _reminderBusy = false);
    }
  }

  // ==========================================================================
  // Delete Account (Phase 47 flow, unchanged)
  // ==========================================================================

  Future<void> _onDeletePressed() async {
    if (_busy || !_matches) return;
    final confirmed = await _showFinalConfirmDialog();
    if (!mounted || !confirmed) return;

    setState(() => _busy = true);
    final outcome = await ref.read(authControllerProvider).deleteAccount();
    if (!mounted) return;
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

  Future<bool> _showFinalConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF14141B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _danger, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Emin misin?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Bu işlem geri alınamaz. Tüm antrenman ve beslenme '
          'verileriniz silinecektir.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
            child: const Text('KALICI OLARAK SİL'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _toast(String message) {
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

// ============================================================================
// Account section primitives
// ============================================================================

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

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Phase 53G · same migration recipe as the profile_tab _SettingsTile.
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    final disabled = onTap == null;
    final secondary = scheme.onSurface.withValues(alpha: 0.55);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color:
                isDark ? Colors.white.withValues(alpha: 0.03) : scheme.surface,
            border: Border.all(
              color: disabled
                  ? (isDark ? Colors.white12 : scheme.outlineVariant)
                  : _neon.withValues(alpha: 0.3),
              width: 1,
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
                        color: disabled ? secondary : scheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: secondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: disabled ? secondary.withValues(alpha: 0.5) : secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationToggleTile extends StatelessWidget {
  const _NotificationToggleTile({
    required this.enabled,
    required this.busy,
    required this.onChanged,
  });

  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? Colors.white.withValues(alpha: 0.03) : scheme.surface,
        border: Border.all(color: _neon.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _neon.withValues(alpha: 0.18),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
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
                  'Bildirimler',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Günlük antrenman hatırlatması (19:00).',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: _neon),
            )
          else
            Switch.adaptive(
              value: enabled,
              activeThumbColor: _neon,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// Edit Profile sheet — minimal form: name, age, goal.
// ============================================================================

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.initial});
  final Map<String, dynamic> initial;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtl;
  late final TextEditingController _ageCtl;
  String? _goal;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(
      text: widget.initial['name'] as String? ?? '',
    );
    _ageCtl = TextEditingController(
      text: widget.initial['age']?.toString() ?? '',
    );
    final existingGoal = widget.initial['targetPhysique'] as String?;
    _goal = _goalLabels.containsKey(existingGoal) ? existingGoal : null;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _ageCtl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(<String, dynamic>{
      'name': _nameCtl.text.trim(),
      'age': int.parse(_ageCtl.text),
      if (_goal != null) 'targetPhysique': _goal,
    });
  }

  @override
  Widget build(BuildContext context) {
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
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Profili Düzenle',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameCtl,
                style: const TextStyle(color: Colors.white),
                decoration:
                    _decoration(label: 'İsim', icon: Icons.badge_outlined),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'İsim boş bırakılamaz';
                  if (v.length > 40) return 'En fazla 40 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ageCtl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white),
                decoration:
                    _decoration(label: 'Yaş', icon: Icons.cake_outlined),
                validator: (value) {
                  final v = int.tryParse(value?.trim() ?? '');
                  if (v == null) return 'Geçerli bir yaş gir';
                  if (v < 12 || v > 100) return '12-100 aralığında olmalı';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _goal,
                dropdownColor: const Color(0xFF1A1A22),
                iconEnabledColor: _neon,
                style: const TextStyle(color: Colors.white),
                decoration:
                    _decoration(label: 'Hedef', icon: Icons.flag_outlined),
                items: _goalLabels.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _goal = v),
                validator: (v) => v == null ? 'Hedef seç' : null,
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

  InputDecoration _decoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: _neon),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
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

// ============================================================================
// Change Password sheet — Supabase auth.updateUser(password:).
// ============================================================================

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
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Şifreyi Değiştir',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Yeni şifren en az 8 karakter olmalı.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _passwordCtl,
                obscureText: _obscure,
                style: const TextStyle(color: Colors.white),
                decoration: _decoration(
                  label: 'Yeni şifre',
                  icon: Icons.lock_outline,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white54,
                    ),
                  ),
                ),
                validator: (value) {
                  final v = value ?? '';
                  if (v.length < 8) return 'En az 8 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmCtl,
                obscureText: _obscure,
                style: const TextStyle(color: Colors.white),
                decoration: _decoration(
                  label: 'Şifreyi tekrar gir',
                  icon: Icons.lock_outline,
                ),
                validator: (value) {
                  if ((value ?? '') != _passwordCtl.text) {
                    return 'Şifreler eşleşmiyor';
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
                child: const Text('ŞİFREYİ GÜNCELLE'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: _neon),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
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

// ============================================================================
// Delete Account card (Phase 47, unchanged)
// ============================================================================

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
                  'Hesabımı Sil',
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
          Text(
            'Bu işlem geri alınamaz. Tüm antrenman geçmişiniz, serileriniz '
            've profil bilgileriniz kalıcı olarak silinecektir.',
            style: TextStyle(
              color: context.colors.onSurface.withValues(alpha: 0.75),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Ayrılma sebebin (opsiyonel)',
            style: TextStyle(
              color: context.colors.onSurface.withValues(alpha: 0.60),
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
            style: TextStyle(color: context.colors.onSurface),
            decoration: _decoration(
              hint: 'Örn: Plan fiyatları yüksek geldi',
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Onaylamak için "$confirmPhrase" yazın',
            style: TextStyle(
              color: context.colors.onSurface.withValues(alpha: 0.60),
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
            style: TextStyle(
              color: context.colors.onSurface,
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
