import 'package:flutter/material.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../profile_screen.dart';
import 'history_tab.dart';
import 'home_map_screen.dart';
import 'request_form_screen.dart';

class MotoristShell extends StatelessWidget {
  const MotoristShell({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ValueListenableBuilder<int>(
      valueListenable: motoristTab,
      builder: (_, i, __) => Scaffold(
        body: IndexedStack(index: i, children: const [HomeMapScreen(), RequestsTab(), HistoryTab(), ProfileScreen()]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i, backgroundColor: p.navBg, indicatorColor: AppColors.orange.withValues(alpha: 0.16),
          onDestinationSelected: (v) => motoristTab.value = v,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: AppColors.orange), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment, color: AppColors.orange), label: 'Requests'),
            NavigationDestination(icon: Icon(Icons.history), selectedIcon: Icon(Icons.history, color: AppColors.orange), label: 'History'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: AppColors.orange), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
