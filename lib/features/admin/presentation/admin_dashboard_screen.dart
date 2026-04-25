import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import 'widgets/admin_recipe_form.dart';

/// Phase 50B · internal admin shell. Desktop-first layout (the panel is
/// only useful on a wide screen anyway — picking image files in a 360 px
/// mobile column is awkward) with a [NavigationRail] sidebar and a
/// switcher that swaps between three views: a placeholder home, the
/// recipe authoring form (built out in this phase), and a coming-soon
/// exercise screen (Phase 50C).
///
/// Access is gated by the router: anyone without `app_metadata.role =
/// 'admin'` is bounced back to `/` before this screen mounts. We still
/// `ref.watch(isAdminProvider)` defensively so a session that loses its
/// claim mid-flight (admin demoted from Studio) hits the same fallback
/// instead of continuing to render the panel.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

enum _AdminSection { dashboard, recipes, exercises }

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  _AdminSection _selected = _AdminSection.dashboard;

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      // Defensive fallback for the rare race where the JWT lost its
      // admin claim after the route guard ran. Pushes the user to the
      // dashboard on the next frame so the panel never flashes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.dashboard);
      });
      return const Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Center(child: CircularProgressIndicator(color: AppColors.neon)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Row(
          children: [
            _AdminSidebar(
              selected: _selected,
              onSelect: (s) => setState(() => _selected = s),
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.surfaceBorder,
            ),
            Expanded(
              child: _AdminContent(section: _selected),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({required this.selected, required this.onSelect});

  final _AdminSection selected;
  final ValueChanged<_AdminSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Icon(Icons.shield_moon, color: AppColors.neon, size: 24),
                SizedBox(width: 10),
                Text(
                  'FormAI Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.surfaceBorder, height: 1),
          const SizedBox(height: 12),
          _SidebarItem(
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            selected: selected == _AdminSection.dashboard,
            onTap: () => onSelect(_AdminSection.dashboard),
          ),
          _SidebarItem(
            label: 'Tarif Yönetimi',
            icon: Icons.restaurant_menu,
            selected: selected == _AdminSection.recipes,
            onTap: () => onSelect(_AdminSection.recipes),
          ),
          _SidebarItem(
            label: 'Egzersiz Yönetimi',
            icon: Icons.fitness_center,
            selected: selected == _AdminSection.exercises,
            onTap: () => onSelect(_AdminSection.exercises),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextButton.icon(
              onPressed: () => context.go(AppRoutes.dashboard),
              icon: const Icon(
                Icons.exit_to_app,
                color: Colors.white60,
                size: 18,
              ),
              label: const Text(
                'Uygulamaya Dön',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected
            ? AppColors.neon.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? AppColors.neon : Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminContent extends StatelessWidget {
  const _AdminContent({required this.section});

  final _AdminSection section;

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case _AdminSection.dashboard:
        return const _AdminHome();
      case _AdminSection.recipes:
        return const AdminRecipeForm();
      case _AdminSection.exercises:
        return const _AdminComingSoon(
          title: 'Egzersiz Yönetimi',
          message: 'Egzersiz yönetim ekranı Phase 50C ile birlikte gelecek. '
              'Şu anda egzersizler `supabase_exercises_migration.sql` '
              'üzerinden yönetilmektedir.',
        );
    }
  }
}

class _AdminHome extends StatelessWidget {
  const _AdminHome();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hoş geldin, Admin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sol menüden bir bölüm seç. İçerik üretim akışı için '
            'docs/CONTENT_OPS.md dökümanına bakabilirsin.',
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: const [
              _AdminStatCard(
                title: 'Aktif tablolar',
                value: '2',
                hint: 'recipes · exercises',
                icon: Icons.table_view,
              ),
              _AdminStatCard(
                title: 'RLS politikaları',
                value: 'Aktif',
                hint: 'admin claim ile yazma',
                icon: Icons.lock,
              ),
              _AdminStatCard(
                title: 'Storage bucket',
                value: 'recipes_images',
                hint: 'public read',
                icon: Icons.cloud_upload,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({
    required this.title,
    required this.value,
    required this.hint,
    required this.icon,
  });

  final String title;
  final String value;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.neon, size: 22),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminComingSoon extends StatelessWidget {
  const _AdminComingSoon({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.hourglass_empty,
                  color: AppColors.amber,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
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
