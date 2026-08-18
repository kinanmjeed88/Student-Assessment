import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/behavior/behavior_summary.dart';
import '../../../core/database/app_snapshot.dart';
import '../../../core/providers.dart';
import '../../../core/services/report_service.dart';
import '../../dashboard/presentation/app_shell.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AsyncStateView(state: state, child: state.when(loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink(), data: (snapshot) => _content(context, ref, snapshot)));
  }

  Widget _content(BuildContext context, WidgetRef ref, AppSnapshot snapshot) {
    final alerts = snapshot.students.where((student) => calculateBehaviorSummary(records: snapshot.behaviorsFor(student.uuid), settings: snapshot.settings).hasAlert).toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير والبيانات')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SummaryGrid(snapshot: snapshot, alerts: alerts.length),
          const SizedBox(height: 24),
          Text('التصدير', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _ExportTile(icon: Icons.table_chart_outlined, title: 'تقرير الطلاب Excel', subtitle: 'قائمة الطلاب والصفوف وحالة السلوك', onTap: () => _export(context, ReportService().exportStudentsXlsx(snapshot), 'students.xlsx')),
          _ExportTile(icon: Icons.fact_check_outlined, title: 'تقرير السلوك Excel', subtitle: 'كل السجلات والنقاط والإجراءات', onTap: () => _export(context, ReportService().exportBehaviorXlsx(snapshot), 'behavior.xlsx')),
          _ExportTile(icon: Icons.event_available_outlined, title: 'تقرير الحضور Excel', subtitle: 'الحضور والغياب والتأخر والأعذار', onTap: () => _export(context, ReportService().exportAttendanceXlsx(snapshot), 'attendance.xlsx')),
          _ExportTile(icon: Icons.school_outlined, title: 'تقرير الدرجات Excel', subtitle: 'التقييمات والدرجات والنسب والملاحظات', onTap: () => _export(context, ReportService().exportGradesXlsx(snapshot), 'grades.xlsx')),
          _ExportTile(icon: Icons.notes_outlined, title: 'تقرير الملاحظات Excel', subtitle: 'الملاحظات الأكاديمية والصحية والمتابعة', onTap: () => _export(context, ReportService().exportNotesXlsx(snapshot), 'notes.xlsx')),
          _ExportTile(icon: Icons.history_outlined, title: 'تقرير سجل الاستيراد Excel', subtitle: 'مصادر الملفات وعمليات الإضافة والتراجع', onTap: () => _export(context, ReportService().exportImportHistoryXlsx(snapshot), 'import-history.xlsx')),
          _ExportTile(icon: Icons.picture_as_pdf_outlined, title: 'تقرير الطلاب PDF', subtitle: 'نسخة مناسبة للطباعة والمشاركة', onTap: () async => _export(context, await ReportService().exportStudentsPdf(snapshot), 'students-report.pdf')),
          const SizedBox(height: 24),
          Text('النسخ الاحتياطي', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _ExportTile(icon: Icons.backup_outlined, title: 'تصدير نسخة احتياطية JSON', subtitle: 'الإعدادات والطلاب والحضور والدرجات والسلوك والملاحظات', onTap: () => _backup(context, ref, snapshot)),
          if (alerts.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('طلاب يحتاجون متابعة', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...alerts.take(8).map((student) => Card(child: ListTile(leading: const Icon(Icons.warning_amber_outlined), title: Text(student.fullName), subtitle: Text(calculateBehaviorSummary(records: snapshot.behaviorsFor(student.uuid), settings: snapshot.settings).label)))),
          ],
        ],
      ),
    );
  }

  Future<void> _backup(BuildContext context, WidgetRef ref, AppSnapshot snapshot) async {
    final json = await ref.read(localRepositoryProvider).exportBackupJson();
    await _export(context, ReportService().exportBackupJson(json), 'al-moktaber-backup.json');
  }

  Future<void> _export(BuildContext context, List<int> bytes, String filename) async {
    final path = await FilePicker.platform.saveFile(dialogTitle: 'حفظ التقرير', fileName: filename, bytes: bytes);
    if (context.mounted && path != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ الملف: $path')));
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.snapshot, required this.alerts});
  final AppSnapshot snapshot;
  final int alerts;
  @override
  Widget build(BuildContext context) => GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.55, children: [_SummaryTile(label: 'الطلاب', value: '${snapshot.students.length}', icon: Icons.groups_outlined), _SummaryTile(label: 'الحضور اليوم', value: '${snapshot.todayAttendance.length}', icon: Icons.fact_check_outlined), _SummaryTile(label: 'سجلات السلوك', value: '${snapshot.behaviors.length}', icon: Icons.psychology_outlined), _SummaryTile(label: 'تنبيهات', value: '$alerts', icon: Icons.warning_amber_outlined)]);
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) { final scheme = Theme.of(context).colorScheme; return Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [CircleAvatar(backgroundColor: scheme.primaryContainer, foregroundColor: scheme.primary, child: Icon(icon)), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)), Text(label)])]))); }
}

class _ExportTile extends StatelessWidget {
  const _ExportTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(onTap: onTap, leading: Icon(icon), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(subtitle), trailing: const Icon(Icons.arrow_back_ios_new, size: 16)));
}
