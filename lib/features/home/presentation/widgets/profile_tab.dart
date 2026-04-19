import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../../core/utils/audio_feedback.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../workout/models/workout_day_model.dart';
import '../../../workout/providers/workout_provider.dart';
import 'stat_tile.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionProvider).value;
    final metrics = ref.watch(appPreferencesProvider).userMetrics ?? const {};
    final user = ref.watch(currentUserProvider);

    final completed = session?.days.where((d) => d.isCompleted).length ?? 0;
    final streak = _streakOf(session?.days ?? const []);
    final weight = metrics['weightKg'];
    final height = metrics['heightCm'];
    final age = metrics['age'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _ProfileHeader(email: user?.email, isGuest: user?.isAnonymous ?? false),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'KİLO',
                value: weight == null ? '—' : '$weight kg',
                icon: Icons.monitor_weight_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'SERİ',
                value: '$streak gün',
                icon: Icons.local_fire_department,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'BOY',
                value: height == null ? '—' : '$height cm',
                icon: Icons.height,
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
          subtitle: 'Yakında',
          onTap: () => _toast(context, 'Yakında'),
        ),
        _SettingsTile(
          icon: Icons.shield_outlined,
          title: 'Gizlilik',
          subtitle: 'Veri ve izinler',
          onTap: () => _toast(context, 'Yakında'),
        ),
        _SettingsTile(
          icon: Icons.logout,
          title: 'Çıkış Yap',
          subtitle: age == null ? null : 'Yaş: $age',
          onTap: () => _signOut(context),
        ),
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

  Future<void> _runTtsTest(BuildContext context) async {
    final audio = AudioFeedback();
    await audio.init();
    await audio.testAudio();
    if (!context.mounted) return;
    _toast(context, '🔊 TTS test tetiklendi — logları kontrol et');
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
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
