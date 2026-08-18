import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../students/presentation/student_details_page.dart';
import 'app_shell.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AsyncStateView(
      state: state,
      child: state.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (snapshot) => RefreshIndicator(
          onRefresh: () => ref.read(appControllerProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              Text('حليف القرآن', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.navy)),
              const SizedBox(height: 4),
              Text('نظرة سريعة على سجل الطلاب اليوم', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: [
                  _StatCard(label: 'إجمالي الطلاب', value: '${snapshot.students.length}', icon: Icons.groups, color: AppTheme.primary),
                  _StatCard(label: 'الفصول', value: '${snapshot.classes.length}', icon: Icons.class_, color: const Color(0xFF0F766E)),
                  _StatCard(label: 'حقول الدرجات', value: '${snapshot.gradeFields.length}', icon: Icons.assessment, color: const Color(0xFF7C3AED)),
                  _StatCard(label: 'الحالة', value: 'محلي', icon: Icons.cloud_off, color: AppTheme.positive),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text('أحدث الطلاب', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('${snapshot.students.length} سجل', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 12),
              if (snapshot.students.isEmpty)
                const _EmptyState(icon: Icons.person_add_alt_1, message: 'لم تتم إضافة طلاب بعد.')
              else
                ...snapshot.students.take(6).map(
                  (student) => Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentDetailsPage(studentUuid: student.uuid))),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(backgroundColor: const Color(0xFFDCE8FF), foregroundColor: AppTheme.primary, child: Text(student.firstName.characters.first)),
                        title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(student.studentNumber.isEmpty ? 'رقم غير محدد' : student.studentNumber),
                        trailing: const Icon(Icons.chevron_left),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: color)),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 42, color: AppTheme.primary),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
