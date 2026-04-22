import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/audio_feedback.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../workout/models/workout_day_model.dart';
import '../../../workout/providers/workout_provider.dart';
import 'stat_tile.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);

// Target physique enum names live in SharedPreferences as raw strings; these
// are the same values used by the onboarding wizard. Keeping the map local so
// we don't leak UI labels back into the wizard provider.
const Map<String, String> _goalLabels = {
  'tone': 'Sıkılaşmak',
  'bulk': 'Hacim Kazanmak',
  'sixpack': 'Sadece Six-Pack',
};

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
    final streak = _streakOf(session?.days ?? const []);
    final weight = metrics['weightKg'];
    final height = metrics['heightCm'];
    final age = metrics['age'];
    final goalKey = metrics['targetPhysique'] as String?;
    final goalLabel = goalKey == null ? '—' : (_goalLabels[goalKey] ?? goalKey);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _ProfileHeader(email: user?.email, isGuest: user?.isAnonymous ?? false),
        const SizedBox(height: 22),
        const _SettingsHeader(title: 'BİLGİLERİM'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                label: 'YAŞ',
                value: age == null ? '—' : '$age',
                icon: Icons.cake_outlined,
                onTap: () => _openEditSheet(metrics),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoTile(
                label: 'KİLO',
                value: weight == null ? '—' : '$weight kg',
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
                label: 'BOY',
                value: height == null ? '—' : '$height cm',
                icon: Icons.height,
                onTap: () => _openEditSheet(metrics),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoTile(
                label: 'HEDEF',
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
            label: const Text('Düzenle'),
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
        const _SettingsHeader(title: 'İLERLEME'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'SERİ',
                value: '$streak gün',
                icon: Icons.local_fire_department,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'TAMAMLANAN',
                value: '$completed / 30',
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const _SettingsHeader(title: 'AYARLAR'),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.workspace_premium,
          title: 'FormAI Premium',
          subtitle: 'Aboneliğini yönet',
          onTap: () => context.push(AppRoutes.paywall),
        ),
        _SettingsTile(
          icon: Icons.volume_up,
          title: 'Sesli Koç Testi',
          subtitle: 'TTS motorunu hızlıca dene',
          onTap: () => _runTtsTest(context),
        ),
        _SettingsTile(
          icon: Icons.notifications_outlined,
          title: 'Bildirimler',
          subtitle: 'Günlük hatırlatma saati belirle',
          onTap: () => _pickReminderTime(context),
        ),
        _SettingsTile(
          icon: Icons.shield_outlined,
          title: 'Gizlilik',
          subtitle: 'Veri ve izinler',
          onTap: () => _openPrivacySheet(context),
        ),
        if (user?.isAnonymous ?? false)
          _GuestLoginTile(onTap: () => context.push(AppRoutes.auth))
        else ...[
          _SettingsTile(
            icon: Icons.manage_accounts_outlined,
            title: 'Hesap Ayarları',
            subtitle: 'Hesabını yönet ve kaldır',
            onTap: () => context.push(AppRoutes.accountSettings),
          ),
          _SettingsTile(
            icon: Icons.logout,
            title: 'Çıkış Yap',
            onTap: () => _signOut(context),
          ),
        ],
      ],
    );
  }

  int _streakOf(List<WorkoutDay> days) {
    var streak = 0;
    for (final day in days) {
      if (day.isCompleted) {
        streak += 1;
      } else {
        break;
      }
    }
    return streak;
  }

  Future<void> _openEditSheet(Map<String, dynamic> initial) async {
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
    if (!mounted) return;
    setState(
        () {}); // userMetrics reads fresh from SharedPreferences on next build
    _toast(context, 'Bilgiler güncellendi');
  }

  Future<void> _pickReminderTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _neon,
            onPrimary: Colors.white,
            surface: Color(0xFF1A1A22),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !context.mounted) return;

    final granted = await NotificationService.instance.requestPermissions();
    if (!context.mounted) return;
    if (!granted) {
      _toast(context, 'Bildirim izni verilmedi');
      return;
    }
    try {
      await NotificationService.instance.scheduleDailyReminder(picked);
    } catch (e) {
      if (context.mounted) _toast(context, 'Bildirim ayarlanamadı: $e');
      return;
    }
    if (!context.mounted) return;
    final label = picked.format(context);
    _toast(context, 'Bildirim saati $label olarak ayarlandı.');
  }

  Future<void> _openPrivacySheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111118),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _PrivacySheet(),
    );
  }

  Future<void> _runTtsTest(BuildContext context) async {
    final audio = AudioFeedback();
    await audio.init();
    await audio.testAudio();
    if (!context.mounted) return;
    _toast(context, '🔊 TTS test tetiklendi — logları kontrol et');
  }

  Future<void> _signOut(BuildContext context) async {
    // Route through AuthController so the user-scoped providers get
    // invalidated — otherwise the next login inherits this user's cached
    // 30-day plan, pro entitlement, and wizard state.
    try {
      await ref.read(authControllerProvider).signOut();
    } catch (_) {
      if (context.mounted) _toast(context, 'Çıkış başarısız');
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
                'Bilgilerini Güncelle',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              _numberField(
                controller: _ageCtl,
                label: 'Yaş',
                icon: Icons.cake_outlined,
                min: 12,
                max: 100,
              ),
              const SizedBox(height: 12),
              _numberField(
                controller: _heightCtl,
                label: 'Boy (cm)',
                icon: Icons.height,
                min: 120,
                max: 230,
              ),
              const SizedBox(height: 12),
              _numberField(
                controller: _weightCtl,
                label: 'Kilo (kg)',
                icon: Icons.monitor_weight_outlined,
                min: 30,
                max: 250,
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

  Widget _numberField({
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
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(label: label, icon: icon),
      validator: (value) {
        final v = int.tryParse(value?.trim() ?? '');
        if (v == null) return 'Geçerli bir sayı gir';
        if (v < min || v > max) return '$min–$max aralığında olmalı';
        return null;
      },
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.04),
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
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.edit, color: Colors.white38, size: 14),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.email, required this.isGuest});
  final String? email;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final label = isGuest ? 'Misafir Kullanıcı' : (email ?? 'Hoşgeldin');
    return Row(
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
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profil',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
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
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white54,
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
            color: Colors.white.withValues(alpha: 0.03),
            border: Border.all(color: Colors.white12, width: 1),
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
                child: Icon(icon, color: _neon, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white38,
              ),
            ],
          ),
        ),
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Üye Ol / Giriş Yap',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'İlerlemeni bulutta güvene al, cihaz değiştirirken '
                        'kaybetme.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
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
                  color: Colors.white24,
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
                const Expanded(
                  child: Text(
                    'Gizlilik Politikası ve Veri Güvenliği',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _PrivacySection(
              title: '1. Kamera Verisi',
              body:
                  'FormAI, egzersiz formunuzu analiz etmek için Google ML Kit '
                  'kullanır. Görüntüler cihazınızda (çevrimdışı) işlenir, '
                  'kaydedilmez ve hiçbir sunucuya gönderilmez.',
            ),
            const SizedBox(height: 14),
            const _PrivacySection(
              title: '2. İlerleme Verisi',
              body: 'Profil bilgileriniz ve tamamlanan antrenman günleriniz, '
                  'deneyiminizi kişiselleştirmek için güvenli bir şekilde '
                  'saklanır.',
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
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
