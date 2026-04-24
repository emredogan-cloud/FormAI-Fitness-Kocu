import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_preferences.dart';
import '../../nutrition/presentation/nutrition_tab.dart';
import '../../nutrition/presentation/widgets/nutrition_onboarding_sheet.dart';
import 'widgets/antrenman_tab.dart';
import 'widgets/gelisim_tab.dart';
import 'widgets/profile_tab.dart';

const Color _neon = Color(0xFF8E5BFF);
const int _nutritionTabIndex = 1;

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
            AntrenmanTab(),
            NutritionTab(),
            GelisimTab(),
            ProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onChanged: _onTabChanged,
      ),
    );
  }

  void _onTabChanged(int newIndex) {
    final previous = _index;
    setState(() => _index = newIndex);
    // Phase 46 · deferred nutrition onboarding. First time the user
    // lands on the Beslenme tab, present the four nutrition
    // questions that used to live at the tail of primary
    // onboarding. `hasCompletedNutritionPrefs` gates the prompt so
    // it fires exactly once per install.
    if (newIndex == _nutritionTabIndex && previous != _nutritionTabIndex) {
      _maybePromptNutritionSheet();
    }
  }

  void _maybePromptNutritionSheet() {
    final prefs = ref.read(appPreferencesProvider);
    if (prefs.hasCompletedNutritionPrefs) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showNutritionOnboardingSheet(context);
    });
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
            icon: Icon(Icons.fitness_center_outlined),
            activeIcon: Icon(Icons.fitness_center),
            label: 'Antrenman',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_outlined),
            activeIcon: Icon(Icons.restaurant),
            label: 'Beslenme',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights_outlined),
            activeIcon: Icon(Icons.insights),
            label: 'Gelişim',
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
