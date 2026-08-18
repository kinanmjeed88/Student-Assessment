import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/behavior/behavior_summary.dart';
import '../../../core/database/app_snapshot.dart';
import '../../../core/database/isar_models.dart';
import '../../../core/providers.dart';
import '../../classes/presentation/classes_page.dart';
import '../../grades/presentation/grades_page.dart';
import '../../import/presentation/import_history_page.dart';
import '../../import/presentation/import_students_page.dart';
import '../../presence/presentation/attendance_page.dart';
import '../../reports/presentation/reports_page.dart';
import '../../students/presentation/student_details_page.dart';
import '../../students/presentation/students_page.dart';
import '../../behavior/presentation/behavior_page.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(appControllerProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: state.when(
        loading: () => Center(child: CircularProgressIndicator(color: scheme.primary)),
        error: (_, __) => _ErrorState(onRetry: () => ref.read(appControllerProvider.notifier).refresh()),
        data: (snapshot) => RefreshIndicator(
          color: scheme.primary,
          onRefresh: () => ref.read(appControllerProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: _DashboardContent(snapshot: snapshot, onOpen: (page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page))),
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.snapshot, required this.onOpen});
  final AppSnapshot snapshot;
  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalStudents = snapshot.students.length;
    final presentToday = snapshot.todayAttendance.where((item) => item.status == AttendanceStatus.present || item.status == AttendanceStatus.late).length;
    final attendanceProgress = totalStudents == 0 ? 0.0 : (presentToday / totalStudents).clamp(0.0, 1.0).toDouble();
    final alerts = snapshot.students.where((student) => calculateBehaviorSummary(records: snapshot.behaviorsFor(student.uuid), settings: snapshot.settings).hasAlert).length;
    final schoolName = snapshot.settings.schoolName.trim().isEmpty ? 'حليف القرآن' : snapshot.settings.schoolName.trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _WelcomeHeader(schoolName: schoolName, teacherName: snapshot.settings.teacherName),
      const SizedBox(height: 24),
      _Title('نظرة عامة'),
      const SizedBox(height: 12),
      _StatsSection(totalStudents: totalStudents, alerts: alerts, presentToday: presentToday),
      const SizedBox(height: 24),
      _Title('إجراءات سريعة'),
      const SizedBox(height: 12),
      _QuickActions(onOpen: onOpen),
      const SizedBox(height: 24),
      _Title('المتابعة'),
      const SizedBox(height: 12),
      _ProgressCard(progress: attendanceProgress, completed: presentToday, total: totalStudents),
      const SizedBox(height: 12),
      _AlertCard(alerts: alerts, onOpen: () => onOpen(const BehaviorPage())),
      const SizedBox(height: 24),
      Row(children: [Expanded(child: _Title('أحدث الطلاب')), Text('$totalStudents سجل', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface))]),
      const SizedBox(height: 12),
      if (snapshot.students.isEmpty)
        _EmptyState(message: 'لم تتم إضافة طلاب بعد.')
      else
        ...snapshot.students.take(6).map((student) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _StudentTile(student: student, onTap: () => onOpen(StudentDetailsPage(studentUuid: student.uuid))))),
    ]);
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.schoolName, required this.teacherName});
  final String schoolName;
  final String teacherName;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final greeting = teacherName.trim().isEmpty ? 'نظرة سريعة على سجل الطلاب اليوم' : 'مرحباً أستاذ $teacherName، إليك ملخص اليوم';
    return Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(24)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(schoolName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(greeting, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onPrimary))])), const SizedBox(width: 12), CircleAvatar(radius: 27, backgroundColor: scheme.onPrimary, foregroundColor: scheme.primary, child: const Icon(Icons.auto_awesome_rounded, size: 28))]));
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w800));
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.totalStudents, required this.alerts, required this.presentToday});
  final int totalStudents;
  final int alerts;
  final int presentToday;
  @override
  Widget build(BuildContext context) {
    final cards = [_StatCard(value: '$totalStudents', label: 'إجمالي الطلاب', icon: Icons.groups_rounded), _StatCard(value: '$alerts', label: 'تنبيهات السلوك', icon: Icons.warning_amber_rounded), _StatCard(value: '$presentToday', label: 'حضور اليوم', icon: Icons.fact_check_rounded)];
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 380) return Column(children: [Row(children: [Expanded(child: cards[0]), const SizedBox(width: 10), Expanded(child: cards[1])]), const SizedBox(height: 10), SizedBox(width: double.infinity, child: cards[2])]);
      return Row(children: [Expanded(child: cards[0]), const SizedBox(width: 10), Expanded(child: cards[1]), const SizedBox(width: 10), Expanded(child: cards[2])]);
    });
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, required this.icon});
  final String value;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(margin: EdgeInsets.zero, elevation: 2, shadowColor: scheme.onSurface.withOpacity(.14), child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 178), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [CircleAvatar(backgroundColor: scheme.primaryContainer, foregroundColor: scheme.primary, child: Icon(icon)), const SizedBox(height: 12), Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w700))])));
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onOpen});
  final ValueChanged<Widget> onOpen;
  @override
  Widget build(BuildContext context) {
    final actions = [
      _Action('إدارة الطلاب', Icons.groups_rounded, const StudentsPage()),
      _Action('إدارة الفصول والشعب', Icons.class_rounded, const ClassesPage()),
      _Action('تسجيل حضور اليوم', Icons.fact_check_rounded, const AttendancePage()),
      _Action('الدرجات والتقييمات', Icons.grade_outlined, const GradesPage()),
      _Action('السلوك والمتابعة', Icons.psychology_outlined, const BehaviorPage()),
      _Action('التقارير والتصدير', Icons.assessment_outlined, const ReportsPage()),
      _Action('استيراد الطلاب', Icons.upload_file_outlined, const ImportStudentsPage()),
      _Action('سجل الاستيراد', Icons.history_outlined, const ImportHistoryPage()),
    ];
    return Column(children: [for (var index = 0; index < actions.length; index++) ...[Card(margin: EdgeInsets.zero, elevation: 0, color: Theme.of(context).colorScheme.surfaceVariant, child: ListTile(onTap: () => onOpen(actions[index].page), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.surface, foregroundColor: Theme.of(context).colorScheme.primary, child: Icon(actions[index].icon)), title: Text(actions[index].title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), trailing: Icon(Icons.arrow_back_ios_new, size: 16, color: Theme.of(context).colorScheme.onSurface))), if (index != actions.length - 1) const SizedBox(height: 10)]]);
  }
}

class _Action {
  const _Action(this.title, this.icon, this.page);
  final String title;
  final IconData icon;
  final Widget page;
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress, required this.completed, required this.total});
  final double progress;
  final int completed;
  final int total;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(margin: EdgeInsets.zero, elevation: 0, color: scheme.surfaceVariant, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text('حضور اليوم', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))), Text('${(progress * 100).round()}%', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w900))]), const SizedBox(height: 14), ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: total == 0 ? 0 : progress, minHeight: 10, backgroundColor: scheme.surface, color: scheme.primary)), const SizedBox(height: 12), Text(total == 0 ? 'أضف طلاباً لتبدأ متابعة حضور اليوم.' : 'تم تسجيل حضور $completed من أصل $total طالب.')])));
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alerts, required this.onOpen});
  final int alerts;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) { final scheme = Theme.of(context).colorScheme; return Card(margin: EdgeInsets.zero, color: alerts == 0 ? scheme.surfaceVariant : scheme.errorContainer, child: ListTile(onTap: onOpen, leading: Icon(alerts == 0 ? Icons.check_circle_outline : Icons.warning_amber_outlined, color: alerts == 0 ? scheme.primary : scheme.error), title: Text(alerts == 0 ? 'لا توجد تنبيهات سلوكية' : '$alerts طالب يحتاج إلى متابعة', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('افتح سجل السلوك لمراجعة التفاصيل'), trailing: const Icon(Icons.arrow_back_ios_new, size: 16))); }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student, required this.onTap});
  final Student student;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) { final scheme = Theme.of(context).colorScheme; return Card(margin: EdgeInsets.zero, elevation: 0, color: scheme.surfaceVariant, child: ListTile(onTap: onTap, leading: CircleAvatar(backgroundColor: scheme.surface, foregroundColor: scheme.primary, child: Text(student.firstName.isEmpty ? '؟' : student.firstName.characters.first)), title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(student.studentNumber.isEmpty ? 'رقم غير محدد' : student.studentNumber), trailing: const Icon(Icons.arrow_back_ios_new, size: 16))); }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(message))));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) { final scheme = Theme.of(context).colorScheme; return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.error_outline_rounded, size: 48, color: scheme.error), const SizedBox(height: 12), const Text('تعذر تحميل البيانات المحلية.'), const SizedBox(height: 12), FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة'))])); }
}
