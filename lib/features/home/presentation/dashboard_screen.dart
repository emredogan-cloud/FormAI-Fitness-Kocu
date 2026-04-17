import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/utils/audio_feedback.dart';
import '../../auth/providers/auth_provider.dart';
import '../../workout/models/workout_day_model.dart';
import '../../workout/providers/workout_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);
const Color _done = Color(0xFF39FF14);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: const [
            _PlanTab(),
            _ExploreTab(),
            _ProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: index,
        onTap: onChanged,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: _neon,
        unselectedItemColor: Colors.white54,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Planım',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Keşfet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _PlanTab extends ConsumerWidget {
  const _PlanTab();

  static const int _totalDays = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(workoutSessionProvider);

    return sessionAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _neon)),
      error: (err, _) => Center(
        child: Text(
          'Program yüklenemedi: $err',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
      data: (session) => _buildContent(context, ref, session),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    WorkoutSessionState session,
  ) {
    final completed = session.days.where((d) => d.isCompleted).length;
    final nextDay = _firstIncomplete(session.days);

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
      children: [
        const _PlanHeader(),
        const SizedBox(height: 18),
        _PlanHeroCard(
          completed: completed,
          total: _totalDays,
          nextDay: nextDay,
          onStart: nextDay == null
              ? null
              : () => _startDay(context, ref, nextDay.dayNumber),
        ),
        const SizedBox(height: 28),
        const _SectionTitle(
          title: '30 GÜNLÜK PROGRAM',
          subtitle: 'Yapay zeka tarafından sıralandı',
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _totalDays,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final dayNumber = index + 1;
              final day = _findDay(session.days, dayNumber);
              return _DayCard(
                dayNumber: dayNumber,
                day: day,
                isNext: nextDay?.dayNumber == dayNumber,
                onTap: () => _startDay(context, ref, dayNumber),
              );
            },
          ),
        ),
      ],
    );
  }

  void _startDay(BuildContext context, WidgetRef ref, int dayNumber) async {
    final day = _findDay(
      ref.read(workoutSessionProvider).value?.days ?? const [],
      dayNumber,
    );
    if (day == null) return;
    await ref.read(workoutSessionProvider.notifier).startDay(dayNumber);
    if (!context.mounted) return;
    context.push(AppRoutes.workout);
  }

  WorkoutDay? _findDay(List<WorkoutDay> days, int dayNumber) {
    for (final day in days) {
      if (day.dayNumber == dayNumber) return day;
    }
    return null;
  }

  WorkoutDay? _firstIncomplete(List<WorkoutDay> days) {
    for (final day in days) {
      if (!day.isCompleted) return day;
    }
    return null;
  }
}

class _PlanHeader extends StatelessWidget {
  const _PlanHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'FormAI',
              style: TextStyle(
                color: _neon,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                shadows: [Shadow(blurRadius: 14, color: _neon)],
              ),
            ),
          ),
          const _TtsTestButton(),
          const SizedBox(width: 8),
          _ProButton(),
        ],
      ),
    );
  }
}

class _TtsTestButton extends StatelessWidget {
  const _TtsTestButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _run(context),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _neonAccent.withValues(alpha: 0.15),
            border: Border.all(
              color: _neonAccent.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.volume_up,
            color: _neonAccent,
            size: 18,
          ),
        ),
      ),
    );
  }

  Future<void> _run(BuildContext context) async {
    final audio = AudioFeedback();
    try {
      await audio.init();
      await audio.testAudio();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('🔊 TTS test tetiklendi — logları kontrol et'),
            backgroundColor: Color(0xFF2A1B5C),
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 1800),
          ),
        );
    } finally {
      // Don't dispose immediately — stop() would cut off playback. The engine
      // releases naturally when the widget tree rebuilds.
    }
  }
}

class _ProButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.push(AppRoutes.paywall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _neon, width: 1),
            gradient: LinearGradient(
              colors: [
                _neon.withValues(alpha: 0.25),
                _neon.withValues(alpha: 0.05),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _neon.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium, color: Colors.white, size: 14),
              SizedBox(width: 6),
              Text(
                'PRO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  letterSpacing: 2,
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

class _PlanHeroCard extends StatelessWidget {
  const _PlanHeroCard({
    required this.completed,
    required this.total,
    required this.nextDay,
    required this.onStart,
  });

  final int completed;
  final int total;
  final WorkoutDay? nextDay;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    final day = nextDay;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A0B3D), Color(0xFF0A0418)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: _neon.withValues(alpha: 0.5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _neon.withValues(alpha: 0.3),
              blurRadius: 24,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _neon.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _neon.withValues(alpha: 0.5),
                      width: 0.6,
                    ),
                  ),
                  child: const Text(
                    'AI HAZIRLADI',
                    style: TextStyle(
                      color: _neon,
                      fontSize: 10,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'FormAI Kişisel Planın Hazır',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              day == null
                  ? 'Tebrikler — 30 günü tamamladın!'
                  : 'Sıradaki: Gün ${day.dayNumber} · '
                      '${day.exercises.length} egzersiz',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 18),
            _ProgressRow(
                completed: completed, total: total, progress: progress),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  day == null ? 'PROGRAMI GÖZDEN GEÇİR' : 'BUGÜNKÜ ANTRENMAN',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _neon,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white12,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.completed,
    required this.total,
    required this.progress,
  });

  final int completed;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'İLERLEME',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
            Text(
              '$completed / $total gün',
              style: const TextStyle(
                color: _neon,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation(_neon),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              letterSpacing: 3,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.dayNumber,
    required this.day,
    required this.isNext,
    required this.onTap,
  });

  final int dayNumber;
  final WorkoutDay? day;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isInProgram = day != null;
    final isCompleted = day?.isCompleted ?? false;
    final isLocked = !isInProgram;

    Color borderColor;
    Color titleColor;
    Color bgColor = Colors.white.withValues(alpha: 0.03);
    Widget? badge;

    if (isCompleted) {
      borderColor = _done;
      titleColor = Colors.white;
      bgColor = _done.withValues(alpha: 0.10);
      badge = const Icon(Icons.check_circle, color: _done, size: 18);
    } else if (isNext) {
      borderColor = _neon;
      titleColor = Colors.white;
      bgColor = _neon.withValues(alpha: 0.10);
      badge = const Icon(Icons.play_circle_fill, color: _neon, size: 18);
    } else if (isLocked) {
      borderColor = Colors.white12;
      titleColor = Colors.white38;
      badge = const Icon(Icons.lock_outline, color: Colors.white24, size: 14);
    } else {
      borderColor = Colors.white24;
      titleColor = Colors.white;
    }

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 130,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isNext ? 2 : 1),
          boxShadow: isNext
              ? [
                  BoxShadow(
                    color: _neon.withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GÜN $dayNumber',
                  style: TextStyle(
                    color: borderColor == Colors.white12
                        ? Colors.white38
                        : Colors.white60,
                    fontSize: 10,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (badge != null) badge,
              ],
            ),
            const Spacer(),
            Text(
              isLocked ? '—' : '15 dk',
              style: TextStyle(
                color: titleColor,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isLocked ? 'Yakında' : (isCompleted ? 'Tamamlandı' : 'Tüm Vücut'),
              style: TextStyle(
                color: isLocked ? Colors.white24 : Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreTab extends StatelessWidget {
  const _ExploreTab();

  static const List<({String title, String sub, IconData icon, Color tint})>
      _categories = [
    (
      title: 'Göğüs & Kol',
      sub: '12 antrenman · Üst gövde gücü',
      icon: Icons.fitness_center,
      tint: Color(0xFF8E5BFF),
    ),
    (
      title: 'Karın (Six-Pack)',
      sub: '18 antrenman · Belirgin karın',
      icon: Icons.bolt,
      tint: Color(0xFF4DA6FF),
    ),
    (
      title: 'Bacak & Kalça',
      sub: '14 antrenman · Alt gövde formu',
      icon: Icons.directions_run,
      tint: Color(0xFFFF6FB5),
    ),
    (
      title: 'Kardiyo (HIIT)',
      sub: '10 antrenman · Yağ yakımı',
      icon: Icons.local_fire_department,
      tint: Color(0xFFFFB04D),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text(
            'Bölgesel Antrenmanlar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 22),
          child: Text(
            'Hedeflediğin bölgeyi seç, AI sana özel programı başlatsın.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
        for (final cat in _categories) ...[
          _ExploreCard(
            title: cat.title,
            subtitle: cat.sub,
            icon: cat.icon,
            tint: cat.tint,
            onTap: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text('${cat.title} yakında geliyor'),
                    backgroundColor: const Color(0xFF2A1B5C),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
            },
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                tint.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: tint.withValues(alpha: 0.45),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: 0.18),
                blurRadius: 16,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: tint.withValues(alpha: 0.2),
                  border: Border.all(
                    color: tint.withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: Icon(icon, color: tint, size: 28),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white54,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

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
              child: _StatTile(
                label: 'KİLO',
                value: weight == null ? '—' : '$weight kg',
                icon: Icons.monitor_weight_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
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
              child: _StatTile(
                label: 'BOY',
                value: height == null ? '—' : '$height cm',
                icon: Icons.height,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
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

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: _neon.withValues(alpha: 0.3),
          width: 1,
        ),
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
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
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
