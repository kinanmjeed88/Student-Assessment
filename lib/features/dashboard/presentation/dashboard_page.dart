import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/database/isar_models.dart';
import '../../classes/presentation/classes_page.dart';
import '../../presence/presentation/attendance_page.dart';
import '../../students/presentation/student_details_page.dart';
import '../../students/presentation/students_page.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(appControllerProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: state.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
        error: (_, __) => _DashboardError(
          colorScheme: colorScheme,
          onRetry: () => ref.read(appControllerProvider.notifier).refresh(),
        ),
        data: (snapshot) => RefreshIndicator(
          color: colorScheme.primary,
          onRefresh: () => ref.read(appControllerProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: _DashboardContent(
              snapshot: snapshot,
              colorScheme: colorScheme,
              onOpenStudents: () => _openPage(context, const StudentsPage()),
              onOpenClasses: () => _openPage(context, const ClassesPage()),
              onOpenAttendance: () =>
                  _openPage(context, const AttendancePage()),
            ),
          ),
        ),
      ),
    );
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.snapshot,
    required this.colorScheme,
    required this.onOpenStudents,
    required this.onOpenClasses,
    required this.onOpenAttendance,
  });

  final AppSnapshot snapshot;
  final ColorScheme colorScheme;
  final VoidCallback onOpenStudents;
  final VoidCallback onOpenClasses;
  final VoidCallback onOpenAttendance;

  @override
  Widget build(BuildContext context) {
    final schoolName = snapshot.settings.schoolName.trim().isEmpty
        ? 'حليف القرآن'
        : snapshot.settings.schoolName.trim();
    final presentToday = snapshot.todayAttendance
        .where(
          (record) =>
              record.status == AttendanceStatus.present ||
              record.status == AttendanceStatus.late,
        )
        .length;
    final totalStudents = snapshot.students.length;
    final attendanceProgress = totalStudents == 0
        ? 0.0
        : (presentToday / totalStudents).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WelcomeHeader(
          schoolName: schoolName,
          teacherName: snapshot.settings.teacherName,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 24),
        _SectionTitle(title: 'نظرة عامة', colorScheme: colorScheme),
        const SizedBox(height: 12),
        _StatsSection(
          totalStudents: totalStudents,
          classesCount: snapshot.classes.length,
          presentToday: presentToday,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 24),
        _SectionTitle(title: 'إجراءات سريعة', colorScheme: colorScheme),
        const SizedBox(height: 12),
        _QuickActions(
          colorScheme: colorScheme,
          onOpenStudents: onOpenStudents,
          onOpenClasses: onOpenClasses,
          onOpenAttendance: onOpenAttendance,
        ),
        const SizedBox(height: 24),
        _SectionTitle(title: 'المتابعة', colorScheme: colorScheme),
        const SizedBox(height: 12),
        _ProgressCard(
          progress: attendanceProgress,
          completed: presentToday,
          total: totalStudents,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _SectionTitle(
                title: 'أحدث الطلاب',
                colorScheme: colorScheme,
              ),
            ),
            Text(
              '$totalStudents سجل',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (snapshot.students.isEmpty)
          _EmptyState(
            colorScheme: colorScheme,
            icon: Icons.person_add_alt_1_rounded,
            message: 'لم تتم إضافة طلاب بعد.',
          )
        else
          ...snapshot.students.take(6).map(
                (student) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StudentTile(
                    student: student,
                    colorScheme: colorScheme,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            StudentDetailsPage(studentUuid: student.uuid),
                      ),
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({
    required this.schoolName,
    required this.teacherName,
    required this.colorScheme,
  });

  final String schoolName;
  final String teacherName;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final greeting = teacherName.trim().isEmpty
        ? 'نظرة سريعة على سجل الطلاب اليوم'
        : 'مرحباً أستاذ $teacherName، إليك ملخص اليوم';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schoolName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: colorScheme.surface,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  greeting,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.surface,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: colorScheme.primary,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.colorScheme,
  });

  final String title;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.totalStudents,
    required this.classesCount,
    required this.presentToday,
    required this.colorScheme,
  });

  final int totalStudents;
  final int classesCount;
  final int presentToday;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCard(
        value: '$totalStudents',
        label: 'إجمالي الطلاب',
        icon: Icons.groups_rounded,
        colorScheme: colorScheme,
      ),
      _StatCard(
        value: '$classesCount',
        label: 'الفصول',
        icon: Icons.class_rounded,
        colorScheme: colorScheme,
      ),
      _StatCard(
        value: '$presentToday',
        label: 'حضور اليوم',
        icon: Icons.fact_check_rounded,
        colorScheme: colorScheme,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 380) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 10),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: cards[2]),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 10),
            Expanded(child: cards[1]),
            const SizedBox(width: 10),
            Expanded(child: cards[2]),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.colorScheme,
  });

  final String value;
  final String label;
  final IconData icon;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shadowColor: colorScheme.onSurface.withOpacity(0.14),
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 178),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: colorScheme.primary, size: 23),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                softWrap: true,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.colorScheme,
    required this.onOpenStudents,
    required this.onOpenClasses,
    required this.onOpenAttendance,
  });

  final ColorScheme colorScheme;
  final VoidCallback onOpenStudents;
  final VoidCallback onOpenClasses;
  final VoidCallback onOpenAttendance;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickActionData(
        title: 'إدارة الطلاب',
        icon: Icons.groups_rounded,
        onTap: onOpenStudents,
      ),
      _QuickActionData(
        title: 'إدارة الفصول',
        icon: Icons.class_rounded,
        onTap: onOpenClasses,
      ),
      _QuickActionData(
        title: 'تسجيل حضور اليوم',
        icon: Icons.fact_check_rounded,
        onTap: onOpenAttendance,
      ),
    ];

    return Column(
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          _QuickActionTile(
            data: actions[index],
            colorScheme: colorScheme,
          ),
          if (index != actions.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.data,
    required this.colorScheme,
  });

  final _QuickActionData data;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surfaceVariant,
      surfaceTintColor: colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: data.onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 0,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(data.icon, color: colorScheme.primary, size: 22),
        ),
        title: Text(
          data.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
        ),
        trailing: Icon(
          Icons.arrow_back_ios_new,
          color: colorScheme.onSurface,
          size: 16,
        ),
      ),
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.progress,
    required this.completed,
    required this.total,
    required this.colorScheme,
  });

  final double progress;
  final int completed;
  final int total;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).round();
    final summary = total == 0
        ? 'أضف طلاباً لتبدأ متابعة حضور اليوم.'
        : 'تم تسجيل حضور $completed من أصل $total طالب.';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surfaceVariant,
      surfaceTintColor: colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'حضور اليوم',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  '$percentage%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : progress,
                minHeight: 10,
                backgroundColor: colorScheme.surface,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              summary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.student,
    required this.colorScheme,
    required this.onTap,
  });

  final Student student;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = student.firstName.trim().isEmpty
        ? '؟'
        : student.firstName.characters.first;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surfaceVariant,
      surfaceTintColor: colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        title: Text(
          student.fullName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
        ),
        subtitle: Text(
          student.studentNumber.trim().isEmpty
              ? 'رقم غير محدد'
              : student.studentNumber,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
        ),
        trailing: Icon(
          Icons.arrow_back_ios_new,
          color: colorScheme.onSurface,
          size: 16,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.colorScheme,
    required this.icon,
    required this.message,
  });

  final ColorScheme colorScheme;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surfaceVariant,
      surfaceTintColor: colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 42, color: colorScheme.primary),
            const SizedBox(height: 10),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({
    required this.colorScheme,
    required this.onRetry,
  });

  final ColorScheme colorScheme;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'تعذر تحميل البيانات المحلية.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
