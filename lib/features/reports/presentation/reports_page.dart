import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/behavior/behavior_summary.dart';
import '../../../core/database/app_snapshot.dart';
import '../../../core/providers.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../core/services/report_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../dashboard/presentation/app_shell.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AsyncStateView(
      state: state,
      child: state.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (snapshot) => _content(context, ref, snapshot),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, AppSnapshot snapshot) {
    final alerts = snapshot.students.where((student) => calculateBehaviorSummary(records: snapshot.behaviorsFor(student.uuid), settings: snapshot.settings).hasAlert).toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير والبيانات')),
      body: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: _SummaryGrid(snapshot: snapshot, alerts: alerts.length),
            ),
            const SizedBox(height: 24),
            Text('التصدير', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _ExportTile(icon: Icons.table_chart_outlined, title: 'تقرير الطلاب Excel', subtitle: 'قائمة الطلاب والصفوف والشعب والحالة وملخص السلوك', onTap: () => _export(context, ReportService().exportStudentsXlsx(snapshot), 'students.xlsx')),
            _ExportTile(icon: Icons.fact_check_outlined, title: 'تقرير السلوك Excel', subtitle: 'كل السجلات والنقاط والأنواع والإجراءات والمتابعات', onTap: () => _export(context, ReportService().exportBehaviorXlsx(snapshot), 'behavior.xlsx')),
            _ExportTile(icon: Icons.event_available_outlined, title: 'تقرير الحضور Excel', subtitle: 'الحضور والغياب والتأخر والأعذار والأسباب والملاحظات', onTap: () => _export(context, ReportService().exportAttendanceXlsx(snapshot), 'attendance.xlsx')),
            _ExportTile(icon: Icons.school_outlined, title: 'تقرير الدرجات Excel', subtitle: 'التقييمات والدرجات والنسب والتقديرات والملاحظات', onTap: () => _export(context, ReportService().exportGradesXlsx(snapshot), 'grades.xlsx')),
            _ExportTile(icon: Icons.notes_outlined, title: 'تقرير الملاحظات Excel', subtitle: 'الملاحظات الأكاديمية والصحية والتربوية ومواعيد المتابعة', onTap: () => _export(context, ReportService().exportNotesXlsx(snapshot), 'notes.xlsx')),
            _ExportTile(icon: Icons.history_outlined, title: 'تقرير سجل الاستيراد Excel', subtitle: 'مصادر الملفات وعمليات الإضافة والتراجع وحالة العملية', onTap: () => _export(context, ReportService().exportImportHistoryXlsx(snapshot), 'import-history.xlsx')),
            _ExportTile(icon: Icons.picture_as_pdf_outlined, title: 'تقرير الطلاب PDF', subtitle: 'تقرير عربي منسق للطباعة والمشاركة يشمل الملخص والقائمة', onTap: () async => _export(context, await ReportService().exportStudentsPdf(snapshot), 'students-report.pdf')),
            const SizedBox(height: 24),
            Text('النسخ الاحتياطي', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _ExportTile(icon: Icons.backup_outlined, title: 'تصدير نسخة احتياطية JSON', subtitle: 'الإعدادات والطلاب والحضور والدرجات والسلوك والملاحظات', onTap: () => _backup(context, ref)),
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('طلاب يحتاجون متابعة', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...alerts.take(8).map((student) {
                final summary = calculateBehaviorSummary(records: snapshot.behaviorsFor(student.uuid), settings: snapshot.settings);
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_outlined),
                    title: Text(student.fullName),
                    subtitle: Text(summary.label),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    try {
      final json = await ref.read(localRepositoryProvider).exportBackupJson();
      await _export(context, ReportService().exportBackupJson(json), 'sajel-al-talib-backup.json');
    } catch (error) {
      _showError(context, error);
    }
  }

  Future<void> _export(BuildContext context, List<int> bytes, String filename) async {
    try {
      if (bytes.isEmpty) throw const FormatException('تعذر إنشاء التقرير لأن الملف الناتج فارغ.');
      final path = await const FileStorageService().saveBytes(
        dialogTitle: 'حفظ التقرير',
        fileName: filename,
        bytes: bytes,
      );
      if (!context.mounted) return;
      if (path == null) {
        _showMessage(context, 'تم إلغاء حفظ الملف.');
      } else {
        _showMessage(context, 'تم حفظ الملف بنجاح.');
      }
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء الملف: $error')));
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.snapshot, required this.alerts});
  final AppSnapshot snapshot;
  final int alerts;

  @override
  Widget build(BuildContext context) {
    final gap = AppTokens.compactGap;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _SummaryTile(label: 'الطلاب', value: '${snapshot.students.length}', icon: Icons.groups_outlined),
        ),
        SizedBox(width: gap),
        Expanded(
          child: _SummaryTile(label: 'الحضور اليوم', value: '${snapshot.todayAttendance.length}', icon: Icons.fact_check_outlined),
        ),
        SizedBox(width: gap),
        Expanded(
          child: _SummaryTile(label: 'السلوك', value: '${snapshot.behaviors.length}', icon: Icons.rule_folder_outlined),
        ),
        SizedBox(width: gap),
        Expanded(
          child: _SummaryTile(label: 'تنبيهات', value: '$alerts', icon: Icons.warning_amber_outlined),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.compactGap),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: Icon(icon, size: 17),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, maxLines: 1, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            ),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  const _ExportTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: scheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_back_ios_new, size: 16),
      ),
    );
  }
}
