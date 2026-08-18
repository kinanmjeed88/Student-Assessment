import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
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
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: SafeArea(top: false, child: NavigationBar(selectedIndex: _index, onDestinationSelected: (value) => setState(() => _index = value), destinations: _destinations)),
    );
  }
}

class AsyncStateView extends StatelessWidget {
  const AsyncStateView({required this.state, required this.child, super.key});
  final AsyncValue<dynamic> state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) {
        final scheme = Theme.of(context).colorScheme;
        return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [Icon(Icons.error_outline, size: 48, color: scheme.error), const SizedBox(height: 12), Text('تعذر تحميل البيانات المحلية.\n$error'), const SizedBox(height: 12), ElevatedButton(onPressed: () => context.findAncestorStateOfType<_AppShellState>()?.ref.refresh(appControllerProvider), child: const Text('إعادة المحاولة'))])));
      },
      data: (_) => child,
    );
  }
}
