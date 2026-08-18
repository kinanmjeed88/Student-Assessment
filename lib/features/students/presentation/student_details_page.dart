import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/isar_models.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

class StudentDetailsPage extends ConsumerWidget {
  const StudentDetailsPage({required this.studentUuid, super.key});

  final String studentUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('ملف الطالب')),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => const Center(child: Text('تعذر تحميل الملف.')),
          data: (snapshot) {
            final studentMatches = snapshot.students.where((item) => item.uuid == studentUuid).toList(growable: false);
            if (studentMatches.isEmpty) return const Center(child: Text('لم يعد هذا الطالب موجوداً.'));
            final student = studentMatches.first;
            final classMatches = snapshot.classes.where((item) => item.uuid == student.classUuid).toList(growable: false);
            final schoolClass = classMatches.isEmpty ? null : classMatches.first;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: const Color(0xFFDCE8FF),
                          foregroundColor: AppTheme.primary,
                          child: Text(student.firstName.isEmpty ? '?' : student.firstName.characters.first, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(height: 12),
                        Text(student.fullName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.navy)),
                        const SizedBox(height: 4),
                        Text(schoolClass?.name ?? 'الفصل غير محدد'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _InfoTile(label: 'رقم الطالب', value: student.studentNumber.isEmpty ? 'غير محدد' : student.studentNumber, icon: Icons.badge_outlined),
                _InfoTile(label: 'الجنس', value: student.gender == StudentGender.male ? 'ذكر' : 'أنثى', icon: Icons.person_outline),
                _InfoTile(label: 'ولي الأمر', value: student.guardianName.isEmpty ? 'غير محدد' : student.guardianName, icon: Icons.family_restroom),
                _InfoTile(label: 'هاتف ولي الأمر', value: student.guardianPhone.isEmpty ? 'غير محدد' : student.guardianPhone, icon: Icons.phone_outlined),
                const SizedBox(height: 16),
                Text('المتابعة', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Expanded(child: _FeatureButton(icon: Icons.fact_check_outlined, label: 'الحضور')),
                    SizedBox(width: 10),
                    Expanded(child: _FeatureButton(icon: Icons.assessment_outlined, label: 'الدرجات')),
                    SizedBox(width: 10),
                    Expanded(child: _FeatureButton(icon: Icons.note_alt_outlined, label: 'الملاحظات')),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(leading: Icon(icon, color: AppTheme.primary), title: Text(label), subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
    );
  }
}

class _FeatureButton extends StatelessWidget {
  const _FeatureButton({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('سيتم فتح وحدة $label في المرحلة التالية.'))),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(children: [Icon(icon, color: AppTheme.primary), const SizedBox(height: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.w700))]),
        ),
      ),
    );
  }
}
