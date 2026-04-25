import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import 'widgets/admin_exercise_form.dart';
import 'widgets/admin_recipe_form.dart';

/// Internal admin shell. Phase 50B shipped a desktop-only layout; Phase
/// 50D makes it responsive so the same screen works as a permanent
/// sidebar on a laptop and as a hamburger-driven Drawer on a phone —
/// which matters because the entry point now lives inside the mobile
/// Profile tab and admins are testing it from their phones.
///
/// Layout switch:
///   • `width >= 600` (tablet/desktop): permanent left sidebar +
///     content, identical to the Phase 50B chrome.
///   • `width <  600` (mobile): a regular `AppBar` + hamburger
///     `Drawer`, with the same sidebar items inside the drawer.
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

/// Width below which the admin shell collapses the permanent sidebar
/// into a drawer. 600 px is the standard Material breakpoint used by
/// the rest of the app for the same kind of switch (`isMobile` checks
/// in onboarding / dashboard already share this number).
const double _kAdminMobileBreakpoint = 600;

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  _AdminSection _selected = _AdminSection.dashboard;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < _kAdminMobileBreakpoint;
        return isMobile ? _buildMobile() : _buildDesktop();
      },
    );
  }

  Widget _buildDesktop() {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Row(
          children: [
            _AdminSidebar(
              selected: _selected,
              onSelect: (s) => setState(() => _selected = s),
              onExit: () => context.go(AppRoutes.dashboard),
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

  Widget _buildMobile() {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _titleFor(_selected),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        // Letting the sidebar fill the drawer's body keeps the chrome
        // (header + items + exit button) identical to the desktop
        // sidebar — admins see the same surface in both modes.
        child: SafeArea(
          child: _AdminSidebar(
            selected: _selected,
            onSelect: (s) {
              setState(() => _selected = s);
              Navigator.of(context).pop();
            },
            onExit: () {
              Navigator.of(context).pop();
              context.go(AppRoutes.dashboard);
            },
          ),
        ),
      ),
      body: _AdminContent(section: _selected),
    );
  }

  String _titleFor(_AdminSection section) {
    switch (section) {
      case _AdminSection.dashboard:
        return 'FormAI Admin';
      case _AdminSection.recipes:
        return 'Tarif Yönetimi';
      case _AdminSection.exercises:
        return 'Egzersiz Yönetimi';
    }
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.selected,
    required this.onSelect,
    required this.onExit,
  });

  final _AdminSection selected;
  final ValueChanged<_AdminSection> onSelect;

  /// Phase 50D · injected so the mobile drawer variant can close the
  /// drawer before routing back to `/`. The desktop variant just hands
  /// in `() => context.go(AppRoutes.dashboard)`.
  final VoidCallback onExit;

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
              onPressed: onExit,
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
        return const AdminExerciseForm();
    }
  }
}

class _AdminHome extends StatelessWidget {
  const _AdminHome();

  @override
  Widget build(BuildContext context) {
    // Phase 50D · same mobile breakpoint as the form scaffolds. On a
    // phone the welcome copy also switches to "menüden" wording — the
    // sidebar collapses into the hamburger drawer at this width.
    final isMobile = MediaQuery.of(context).size.width < 600;
    return SingleChildScrollView(
      padding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 20, vertical: 24)
          : const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hoş geldin, Admin',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 22 : 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isMobile
                ? 'Üst soldaki menüden bir bölüm seç. İçerik üretim akışı '
                    'için docs/CONTENT_OPS.md dökümanına bakabilirsin.'
                : 'Sol menüden bir bölüm seç. İçerik üretim akışı için '
                    'docs/CONTENT_OPS.md dökümanına bakabilirsin.',
            style: const TextStyle(color: Colors.white60, fontSize: 14),
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
