import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/behavior/behavior_summary.dart';
import '../../../core/database/app_snapshot.dart';
import '../../../core/database/isar_models.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../behavior/presentation/behavior_page.dart';
import '../../classes/presentation/classes_page.dart';
import '../../grades/presentation/grades_page.dart';
import '../../import/presentation/import_history_page.dart';
import '../../import/presentation/import_students_page.dart';
import '../../notes/presentation/notes_page.dart';
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
      child: AsyncStateView(
        state: state,
        onRetry: () => ref.read(appControllerProvider.notifier).refresh(),
        child: state.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (snapshot) => RefreshIndicator(
            onRefresh: () => ref.read(appControllerProvider.notifier).refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.page,
              child: AppResponsiveContent(
                child: _DashboardContent(
                  snapshot: snapshot,
                  onOpen: (page) => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => page),
                  ),
                ),
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
    final absentToday = snapshot.todayAttendance
        .where((item) => item.status == AttendanceStatus.absent)
        .length;
    final alerts = snapshot.students
        .map(
          (student) => _BehaviorNotification(
            student: student,
            summary: calculateBehaviorSummary(
              records: snapshot.behaviorsFor(student.uuid),
              settings: snapshot.settings,
            ),
          ),
        )
        .where((item) => item.summary.hasAlert)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardHeader(
          settings: snapshot.settings,
          alertCount: alerts.length,
          onNotifications: () => _showBehaviorNotifications(context, alerts),
        ),
        AppSpacing.section,
        _StatsRow(
          totalStudents: totalStudents,
          alerts: alerts.length,
          absentToday: absentToday,
        ),
        AppSpacing.section,
        const AppSectionHeader(title: 'إجراءات سريعة'),
        AppSpacing.compact,
        _QuickActions(onOpen: onOpen),
        AppSpacing.section,
        AppSectionHeader(
          title: 'أحدث ملفات الطلاب',
          subtitle: totalStudents == 0 ? 'لا توجد سجلات بعد.' : 'آخر الطلاب المضافين إلى النظام.',
          action: totalStudents == 0
              ? null
              : TextButton(
                  onPressed: () => onOpen(const StudentsPage()),
                  child: const Text('عرض الكل'),
                ),
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
                    onTap: () => onOpen(
                      StudentDetailsPage(studentUuid: student.uuid),
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.settings, required this.alertCount, required this.onNotifications});

  final AppSettings settings;
  final int alertCount;
  final VoidCallback onNotifications;

  String _institutionText() {
    final teacher = settings.teacherName.trim();
    final school = settings.schoolName.trim();
    if (teacher.isEmpty) return school;
    if (school.isEmpty) return teacher;
    return '$teacher - $school';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final institutionText = _institutionText();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/images/splash_icon.png',
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                semanticLabel: 'شعار سجل الطالب',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'سجل الطالب',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.headlineSmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Badge.count(
              count: alertCount,
              isLabelVisible: alertCount > 0,
              child: IconButton(
                tooltip: 'الإشعارات السلوكية',
                onPressed: onNotifications,
                icon: const Icon(Icons.notifications_none_outlined),
              ),
            ),
          ],
        ),
        if (institutionText.isNotEmpty)
          _InstitutionLine(
            text: institutionText,
            animated: settings.institutionLineAnimated,
            speed: settings.institutionLineSpeed,
          ),
      ],
    );
  }
}

class _InstitutionLine extends StatelessWidget {
  const _InstitutionLine({required this.text, required this.animated, required this.speed});

  final String text;
  final bool animated;
  final double speed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );
    if (!animated) {
      return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          maxLines: 1,
        )..layout();
        if (painter.width <= constraints.maxWidth) {
          return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
        }
        return _ScrollingInstitutionLine(
          text: text,
          style: style,
          width: painter.width,
          viewportWidth: constraints.maxWidth,
          speed: speed,
        );
      },
    );
  }
}

class _ScrollingInstitutionLine extends StatefulWidget {
  const _ScrollingInstitutionLine({required this.text, required this.style, required this.width, required this.viewportWidth, required this.speed});

  final String text;
  final TextStyle? style;
  final double width;
  final double viewportWidth;
  final double speed;

  @override
  State<_ScrollingInstitutionLine> createState() => _ScrollingInstitutionLineState();
}

class _ScrollingInstitutionLineState extends State<_ScrollingInstitutionLine> with SingleTickerProviderStateMixin {
  static const _gap = 32.0;
  late final AnimationController _controller;

  double get _distance => widget.width + _gap;

  Duration get _duration {
    final pixelsPerSecond = widget.speed.clamp(10, 200).toDouble();
    return Duration(milliseconds: (_distance / pixelsPerSecond * 1000).round().clamp(1000, 120000));
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)..repeat();
  }

  @override
  void didUpdateWidget(covariant _ScrollingInstitutionLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.width != widget.width ||
        oldWidget.viewportWidth != widget.viewportWidth ||
        oldWidget.speed != widget.speed) {
      _controller
        ..duration = _duration
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        height: 24,
        width: widget.viewportWidth,
        child: AnimatedBuilder(
          animation: _controller,
          child: Row(
            textDirection: TextDirection.ltr,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.text, style: widget.style, maxLines: 1),
              const SizedBox(width: _gap),
              Text(widget.text, style: widget.style, maxLines: 1),
            ],
          ),
          builder: (context, child) => Transform.translate(
            offset: Offset(-_distance + (_controller.value * _distance), 0),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.totalStudents, required this.alerts, required this.absentToday});

  final int totalStudents;
  final int alerts;
  final int absentToday;

  @override
  Widget build(BuildContext context) {
    final gap = AppTokens.compactGap;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppMetricTile(
            compact: true,
            label: 'إجمالي الطلاب',
            value: '$totalStudents',
            icon: Icons.groups_outlined,
            tone: AppStatusTone.neutral,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: AppMetricTile(
            compact: true,
            label: 'تنبيهات السلوك',
            value: '$alerts',
            icon: Icons.rule_folder_outlined,
            tone: alerts > 0 ? AppStatusTone.warning : AppStatusTone.neutral,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: AppMetricTile(
            compact: true,
            label: 'غياب اليوم',
            value: '$absentToday',
            icon: Icons.event_busy_outlined,
            tone: absentToday > 0 ? AppStatusTone.warning : AppStatusTone.success,
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onOpen});

  final ValueChanged<Widget> onOpen;

  static const actions = [
    _Action(title: 'إدارة الطلاب', icon: Icons.groups_outlined, page: StudentsPage()),
    _Action(title: 'الصفوف والشعب', icon: Icons.class_outlined, page: ClassesPage()),
    _Action(title: 'تسجيل حضور اليوم', icon: Icons.fact_check_outlined, page: AttendancePage()),
    _Action(title: 'الدرجات والتقييمات', icon: Icons.analytics_outlined, page: GradesPage()),
    _Action(title: 'السلوك والمتابعة', icon: Icons.rule_folder_outlined, page: BehaviorPage()),
    _Action(title: 'الملاحظات', icon: Icons.note_alt_outlined, page: NotesPage()),
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
                    title: Text(
                      action.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    trailing: Icon(
                      Icons.arrow_back_ios_new,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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

class _BehaviorNotification {
  const _BehaviorNotification({required this.student, required this.summary});

  final Student student;
  final BehaviorSummary summary;
}

Future<void> _showBehaviorNotifications(
  BuildContext context,
  List<_BehaviorNotification> notifications,
) async {
  final scheme = Theme.of(context).colorScheme;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: scheme.surface,
    builder: (sheetContext) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .78,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 20),
            child: notifications.isEmpty
                ? const AppEmptyState(
                    icon: Icons.notifications_none_outlined,
                    title: 'لا توجد تنبيهات سلوكية',
                    message: 'ستظهر هنا أسماء الطلاب الذين يحتاجون إلى متابعة سلوكية.',
                  )
                : ListView(
                    children: [
                      Text(
                        'الإشعارات السلوكية',
                        style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'طلاب يحتاجون إلى مراجعة سجلهم السلوكي.',
                        style: Theme.of(sheetContext).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      for (final notification in notifications)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            color: scheme.surfaceContainerHighest,
                            child: ListTile(
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => StudentDetailsPage(
                                      studentUuid: notification.student.uuid,
                                    ),
                                  ),
                                );
                              },
                              leading: CircleAvatar(
                                backgroundColor: notification.summary.dismissed
                                    ? scheme.errorContainer
                                    : scheme.tertiaryContainer,
                                foregroundColor: notification.summary.dismissed
                                    ? scheme.onErrorContainer
                                    : scheme.onTertiaryContainer,
                                child: Text(
                                  notification.student.firstName.isEmpty
                                      ? '؟'
                                      : notification.student.firstName.characters.first,
                                ),
                              ),
                              title: Text(
                                notification.student.fullName,
                                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              subtitle: Text(
                                '${notification.summary.label} • الدرجة السلوكية ${notification.summary.totalPoints.toStringAsFixed(0)}',
                              ),
                              trailing: const Icon(Icons.arrow_back_ios_new, size: 16),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      );
    },
  );
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
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Text(
            student.firstName.isEmpty ? '؟' : student.firstName.characters.first,
          ),
        ),
        title: Text(
          student.fullName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        subtitle: Text(
          student.studentNumber.isEmpty ? 'رقم الطالب غير محدد' : student.studentNumber,
        ),
        trailing: Icon(
          Icons.arrow_back_ios_new,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
