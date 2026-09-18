import 'package:flutter/material.dart';

import '../../../core/notifications/student_alert.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';

/// يعرض لوحة الإشعارات الموحدة التي يجمعها زر الإشعارات في الصفحة الرئيسية.
///
/// تحتوي اللوحة على إشعارات السلوك وإشعارات الغياب مع مرشح لكل نوع، ويُفتح ملف
/// الطالب من السطر نفسه لتسهيل المتابعة.
Future<void> showStudentAlertsSheet(
  BuildContext context, {
  required List<StudentAlert> alerts,
  required ValueChanged<StudentAlert> onOpenStudent,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: scheme.surface,
    builder: (sheetContext) => _StudentAlertsSheet(
      alerts: alerts,
      onOpenStudent: onOpenStudent,
    ),
  );
}

class _StudentAlertsSheet extends StatefulWidget {
  const _StudentAlertsSheet({required this.alerts, required this.onOpenStudent});

  final List<StudentAlert> alerts;
  final ValueChanged<StudentAlert> onOpenStudent;

  @override
  State<_StudentAlertsSheet> createState() => _StudentAlertsSheetState();
}

class _StudentAlertsSheetState extends State<_StudentAlertsSheet> {
  StudentAlertCategory? _category;

  List<StudentAlert> get _visibleAlerts => _category == null
      ? widget.alerts
      : widget.alerts
          .where((alert) => alert.category == _category)
          .toList(growable: false);

  int _countOf(StudentAlertCategory category) =>
      widget.alerts.where((alert) => alert.category == category).length;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final visibleAlerts = _visibleAlerts;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .78,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الإشعارات',
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'طلاب بلغوا حد التنبيه أو حد الفصل في السلوك أو الغياب.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _categoryChip(
                      label: 'الكل',
                      count: widget.alerts.length,
                      selected: _category == null,
                      onSelected: () => setState(() => _category = null),
                    ),
                    const SizedBox(width: AppTokens.tightGap * 2),
                    _categoryChip(
                      label: 'الغياب',
                      count: _countOf(StudentAlertCategory.absence),
                      selected: _category == StudentAlertCategory.absence,
                      onSelected: () =>
                          setState(() => _category = StudentAlertCategory.absence),
                    ),
                    const SizedBox(width: AppTokens.tightGap * 2),
                    _categoryChip(
                      label: 'السلوك',
                      count: _countOf(StudentAlertCategory.behavior),
                      selected: _category == StudentAlertCategory.behavior,
                      onSelected: () =>
                          setState(() => _category = StudentAlertCategory.behavior),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: visibleAlerts.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.notifications_none_outlined,
                        title: 'لا توجد إشعارات',
                        message:
                            'ستظهر هنا أسماء الطلاب الذين بلغوا حد التنبيه أو حد الفصل، ويمكن ضبط الحدود من الإعدادات.',
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: visibleAlerts.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AlertTile(
                            alert: visibleAlerts[index],
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onOpenStudent(visibleAlerts[index]);
                            },
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

  Widget _categoryChip({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
      selectedColor: scheme.primaryContainer,
      backgroundColor: scheme.surfaceContainerHighest,
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert, required this.onTap});

  final StudentAlert alert;
  final VoidCallback onTap;

  /// وصف السطر: درجة الإشعار وسببُه وتاريخ آخر واقعة إن وُجدت.
  String _subtitle() {
    final recordedAt = alert.recordedAt;
    if (recordedAt == null) return '${alert.levelLabel} • ${alert.detail}';
    final date = '${recordedAt.day}/${recordedAt.month}/${recordedAt.year}';
    return '${alert.levelLabel} • ${alert.detail} • $date';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isAbsence = alert.category == StudentAlertCategory.absence;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 4),
        leading: CircleAvatar(
          backgroundColor: alert.isDismissal ? scheme.errorContainer : scheme.tertiaryContainer,
          foregroundColor:
              alert.isDismissal ? scheme.onErrorContainer : scheme.onTertiaryContainer,
          child: Icon(
            isAbsence ? Icons.event_busy_outlined : Icons.rule_folder_outlined,
          ),
        ),
        title: Text(
          alert.student.fullName,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(_subtitle()),
        trailing: AppStatusPill(
          label: alert.categoryLabel,
          icon: isAbsence ? Icons.event_busy_outlined : Icons.rule_folder_outlined,
          tone: alert.isDismissal ? AppStatusTone.error : AppStatusTone.warning,
          compact: true,
        ),
      ),
    );
  }
}
