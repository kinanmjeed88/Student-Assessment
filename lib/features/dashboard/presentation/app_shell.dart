import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/async_state_view.dart';

export '../../../core/widgets/async_state_view.dart';
import '../../classes/presentation/classes_page.dart';
import '../../presence/presentation/attendance_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../../students/presentation/students_page.dart';
import 'dashboard_page.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
    NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'الطلاب'),
    NavigationDestination(icon: Icon(Icons.class_outlined), selectedIcon: Icon(Icons.class_), label: 'الفصول'),
    NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'الحضور'),
    NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
  ];

  @override
  Widget build(BuildContext context) {
    const pages = [DashboardPage(), StudentsPage(), ClassesPage(), AttendancePage(), SettingsPage()];
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          backgroundColor: scheme.surface,
          indicatorColor: scheme.secondaryContainer,
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: _destinations,
        ),
      ),
    );
  }
}
