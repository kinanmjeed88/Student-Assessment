import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/behavior/behavior_summary.dart';
import '../../../core/database/app_snapshot.dart';
import '../../../core/database/isar_models.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_components.dart';
import '../../behavior/presentation/behavior_page.dart';
import '../../classes/presentation/classes_page.dart';
import '../../grades/presentation/grades_page.dart';
import '../../import/presentation/import_history_page.dart';
import '../../import/presentation/import_students_page.dart';
import '../../presence/presentation/attendance_page.dart';
import '../../reports/presentation/reports_page.dart';
import '../../students/presentation/student_details_page.dart';
import '../../students/presentation/students_page.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _DashboardError(onRetry: () => ref.read(appControllerProvider.notifier).refresh()),
        data: (snapshot) => RefreshIndicator(
          onRefresh: () => ref.read(appControllerProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.page,
            child: AppResponsiveContent(
              child: _DashboardContent(
                snapshot: snapshot,
                onOpen: (page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
              ),
            ),
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
    final totalStudents = snapshot.students.length;
    final presentToday = snapshot.todayAttendance.where((item) => item.status == AttendanceStatus.present || item.status == AttendanceStatus.late).length;
    final attendanceProgress = totalStudents == 0 ? 0.0 : (presentToday / totalStudents).clamp(0.0, 1.0).toDouble();
    final alerts = snapshot.students.where((student) => calculateBehaviorSummary(records: snapshot.behaviorsFor(student.uuid), settings: snapshot.settings).hasAlert).length;
    final schoolName = snapshot.settings.schoolName.trim().isEmpty ? 'سجل الطالب ونظام إشعارات' : snapshot.settings.schoolName.trim();
    final teacherName = snapshot.settings.teacherName.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WelcomeBanner(schoolName: schoolName, teacherName: teacherName),
        AppSpacing.section,
        const AppSectionHeader(title: 'نظرة عامة', subtitle: 'مؤشرات سريعة تساعدك على متابعة المدرسة اليوم.'),
        AppSpacing.compact,
        _StatsGrid(totalStudents: totalStudents, alerts: alerts, presentToday: presentToday),
        AppSpacing.section,
        const AppSectionHeader(title: 'إجراءات سريعة', subtitle: 'انتقل مباشرة إلى أكثر المهام استخداماً.'),
        AppSpacing.compact,
        _QuickActions(onOpen: onOpen),
        AppSpacing.section,
        const AppSectionHeader(title: 'المتابعة اليومية', subtitle: 'حالة الحضور والتنبيهات التي تحتاج إلى مراجعة.'),
        AppSpacing.compact,
        _FollowUpSection(
          progress: attendanceProgress,
          completed: presentToday,
          total: totalStudents,
          alerts: alerts,
          onOpenBehavior: () => onOpen(const BehaviorPage()),
        ),
        AppSpacing.section,
        AppSectionHeader(
          title: 'أحدث ملفات الطلاب',
          subtitle: totalStudents == 0 ? 'لا توجد سجلات بعد.' : 'آخر الطلاب المضافين إلى النظام.',
          action: totalStudents == 0 ? null : TextButton(onPressed: () => onOpen(const StudentsPage()), child: const Text('عرض الكل')),
        ),
        AppSpacing.compact,
        if (snapshot.students.isEmpty)
          const AppEmptyState(
            icon: Icons.groups_outlined,
            title: 'لا يوجد طلاب بعد',
            message: 'أضف أول طالب أو استورد قائمة الطلاب للبدء.',
          )
        else
          ...snapshot.students.take(6).map(
            (student) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StudentListItem(
                student: student,
                onTap: () => onOpen(StudentDetailsPage(studentUuid: student.uuid)),
              ),
            ),
          ),
      ],
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.schoolName, required this.teacherName});

  final String schoolName;
  final String teacherName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final greeting = teacherName.isEmpty ? 'لوحة متابعة موحدة لبيانات الطلاب والإشعارات.' : 'مرحباً $teacherName، إليك ملخص العمل اليومي.';
    return Card(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            final identity = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.onPrimary,
                  foregroundColor: scheme.primary,
                  child: const Icon(Icons.school_outlined, size: 28),
                ),
                const SizedBox(width: 14),
                if (compact)
                  const SizedBox.shrink()
                else
                  Text('لوحة الإدارة', style: textTheme.labelLarge?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w800)),
              ],
            );
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(schoolName, style: textTheme.headlineSmall?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(greeting, style: textTheme.bodyMedium?.copyWith(color: scheme.onPrimary)),
              ],
            );
            return compact ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [identity, const SizedBox(height: 18), copy]) : Row(children: [Expanded(child: copy), const SizedBox(width: 20), identity]);
          },
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.totalStudents, required this.alerts, required this.presentToday});

  final int totalStudents;
  final int alerts;
  final int presentToday;

  @override
  Widget build(BuildContext context) {
    final items = [
      const (label: 'إجمالي الطلاب', icon: Icons.groups_outlined, tone: AppStatusTone.neutral),
      const (label: 'تنبيهات السلوك', icon: Icons.rule_folder_outlined, tone: AppStatusTone.warning),
      const (label: 'حضور اليوم', icon: Icons.fact_check_outlined, tone: AppStatusTone.success),
    ];
    final values = ['$totalStudents', '$alerts', '$presentToday'];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 560 ? 2 : 3;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var index = 0; index < items.length; index++)
              SizedBox(
                width: index == 2 && columns == 2 ? constraints.maxWidth : width,
                child: AppMetricTile(
                  label: items[index].label,
                  value: values[index],
                  icon: items[index].icon,
                  tone: items[index].tone,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onOpen});

  final ValueChanged<Widget> onOpen;

  static const actions = [
    _Action(title: 'إدارة الطلاب', icon: Icons.groups_outlined, page: StudentsPage()),
    _Action(title: 'الفصول والشعب', icon: Icons.class_outlined, page: ClassesPage()),
    _Action(title: 'تسجيل حضور اليوم', icon: Icons.fact_check_outlined, page: AttendancePage()),
    _Action(title: 'الدرجات والتقييمات', icon: Icons.analytics_outlined, page: GradesPage()),
    _Action(title: 'السلوك والمتابعة', icon: Icons.rule_folder_outlined, page: BehaviorPage()),
    _Action(title: 'التقارير والتصدير', icon: Icons.assessment_outlined, page: ReportsPage()),
    _Action(title: 'استيراد الطلاب', icon: Icons.upload_file_outlined, page: ImportStudentsPage()),
    _Action(title: 'سجل الاستيراد', icon: Icons.history_outlined, page: ImportHistoryPage()),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680 ? 2 : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final action in actions)
              SizedBox(
                width: width,
                child: Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: ListTile(
                    onTap: () => onOpen(action.page),
                    contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(action.icon),
                    ),
                    title: Text(action.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    trailing: Icon(Icons.arrow_back_ios_new, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Action {
  const _Action({required this.title, required this.icon, required this.page});

  final String title;
  final IconData icon;
  final Widget page;
}

class _FollowUpSection extends StatelessWidget {
  const _FollowUpSection({required this.progress, required this.completed, required this.total, required this.alerts, required this.onOpenBehavior});

  final double progress;
  final int completed;
  final int total;
  final int alerts;
  final VoidCallback onOpenBehavior;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final progressCard = _AttendanceProgress(progress: progress, completed: completed, total: total);
        final alertCard = _BehaviorAlert(alerts: alerts, onOpen: onOpenBehavior);
        if (compact) return Column(children: [progressCard, AppSpacing.item, alertCard]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: progressCard), const SizedBox(width: 12), Expanded(child: alertCard)]);
      },
    );
  }
}

class _AttendanceProgress extends StatelessWidget {
  const _AttendanceProgress({required this.progress, required this.completed, required this.total});

  final double progress;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppSurfaceCard(
      color: scheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text('حضور اليوم', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))), Text('${(progress * 100).round()}%', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 16),
          ClipRRect(borderRadius: BorderRadius.circular(16), child: LinearProgressIndicator(value: total == 0 ? 0 : progress, minHeight: 10, backgroundColor: scheme.surface, color: scheme.primary)),
          const SizedBox(height: 12),
          Text(total == 0 ? 'أضف طلاباً لتبدأ متابعة حضور اليوم.' : 'تم تسجيل حضور $completed من أصل $total طالب.'),
        ],
      ),
    );
  }
}

class _BehaviorAlert extends StatelessWidget {
  const _BehaviorAlert({required this.alerts, required this.onOpen});

  final int alerts;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasAlerts = alerts > 0;
    return Card(
      color: hasAlerts ? scheme.errorContainer : scheme.surfaceContainerHighest,
      child: ListTile(
        onTap: onOpen,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 10, 12, 10),
        leading: Icon(hasAlerts ? Icons.warning_amber_outlined : Icons.verified_outlined, color: hasAlerts ? scheme.error : scheme.primary),
        title: Text(hasAlerts ? '$alerts طالب يحتاج إلى متابعة' : 'لا توجد تنبيهات سلوكية', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        subtitle: const Text('مراجعة سجل السلوك والتعامل مع الحالات.'),
        trailing: Icon(Icons.arrow_back_ios_new, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _StudentListItem extends StatelessWidget {
  const _StudentListItem({required this.student, required this.onTap});

  final Student student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 6, 12, 6),
        leading: CircleAvatar(backgroundColor: scheme.primaryContainer, foregroundColor: scheme.onPrimaryContainer, child: Text(student.firstName.isEmpty ? '؟' : student.firstName.characters.first)),
        title: Text(student.fullName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        subtitle: Text(student.studentNumber.isEmpty ? 'رقم الطالب غير محدد' : student.studentNumber),
        trailing: Icon(Icons.arrow_back_ios_new, size: 16, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: AppSpacing.page,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: scheme.error),
            const SizedBox(height: 12),
            const Text('تعذر تحميل البيانات المحلية.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}
