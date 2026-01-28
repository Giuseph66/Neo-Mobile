import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'automations_home_screen.dart';
import '../../inspector_accessibility/presentation/screens/inspector_home_screen.dart';
import 'runs_history_screen.dart';
import 'permissions_hub_screen.dart';

class ScheduledAutomationRoot extends StatefulWidget {
  const ScheduledAutomationRoot({super.key});

  @override
  State<ScheduledAutomationRoot> createState() => _ScheduledAutomationRootState();
}

class _ScheduledAutomationRootState extends State<ScheduledAutomationRoot> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const AutomationsHomeScreen(),
    const InspectorHomeScreen(),
    const RunsHistoryScreen(),
    const PermissionsHubScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.bg0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.text2.withOpacity(0.5),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bolt),
            label: 'Rotinas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Inspector',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Logs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
