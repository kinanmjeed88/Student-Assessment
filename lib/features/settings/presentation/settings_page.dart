import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../dashboard/presentation/app_shell.dart';
import '../../import/presentation/import_history_page.dart';
import '../../import/presentation/import_students_page.dart';
import '../../reports/presentation/reports_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _schoolController = TextEditingController();
  final _teacherController = TextEditingController();
  final _yearController = TextEditingController();
  final _stageController = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() { _schoolController.dispose(); _teacherController.dispose(); _yearController.dispose(); _stageController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    return AsyncStateView(state: state, child: state.when(loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink(), data: (snapshot) {
      if (!_initialized) { _schoolController.text = snapshot.settings.schoolName; _teacherController.text = snapshot.settings.teacherName; _yearController.text = snapshot.settings.academicYear; _stageController.text = snapshot.settings.stage; _initialized = true; }
      return Scaffold(appBar: AppBar(title: const Text('الإعدادات')), body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), children: [
        Text('بيانات المدرسة', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [_field(_schoolController, 'اسم المدرسة'), const SizedBox(height: 12), _field(_teacherController, 'اسم المعلم'), const SizedBox(height: 12), _field(_yearController, 'العام الدراسي'), const SizedBox(height: 12), _field(_stageController, 'المرحلة الدراسية'), const SizedBox(height: 16), FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: const Text('حفظ الإعدادات'))])),
        const SizedBox(height: 24), Text('إدارة البيانات', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 12),
        Card(child: Column(children: [_tile(context, Icons.assessment_outlined, 'التقارير والتصدير', 'إنشاء XLSX وPDF ونسخ احتياطية', const ReportsPage()), const Divider(height: 1), _tile(context, Icons.upload_file_outlined, 'استيراد الطلاب', 'إضافة مجموعة من ملف Excel أو CSV', const ImportStudentsPage()), const Divider(height: 1), _tile(context, Icons.history_outlined, 'سجل الاستيراد', 'مراجعة العمليات والتراجع عنها', const ImportHistoryPage()), const Divider(height: 1), ListTile(leading: const Icon(Icons.restore_outlined), title: const Text('استعادة نسخة JSON'), subtitle: const Text('استبدال البيانات المحلية بملف احتياطي موثوق.'), trailing: const Icon(Icons.chevron_left), onTap: _restoreBackup), ListTile(leading: const Icon(Icons.backup_outlined), title: const Text('تصدير نسخة احتياطية'), subtitle: const Text('JSON شامل لجميع المجالات.'), trailing: const Icon(Icons.chevron_left), onTap: _exportBackup)])),
        const SizedBox(height: 24), Text('التنبيهات', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 12), Card(child: ListTile(leading: const Icon(Icons.notifications_active_outlined), title: const Text('صلاحيات التنبيهات'), subtitle: const Text('تهيئة Android 13+ والتنبيهات الدقيقة عند الحاجة.'), trailing: const Icon(Icons.chevron_left), onTap: _requestNotificationPermission)),
        const SizedBox(height: 20), const Card(child: ListTile(leading: Icon(Icons.offline_bolt_outlined), title: Text('وضع العمل المحلي'), subtitle: Text('البيانات محفوظة في Isar ولا يتطلب التطبيق اتصالاً بالشبكة.'))),
      ]));
    }));
  }

  TextField _field(TextEditingController controller, String label) => TextField(controller: controller, decoration: InputDecoration(labelText: label));
  ListTile _tile(BuildContext context, IconData icon, String title, String subtitle, Widget page) => ListTile(leading: Icon(icon, color: Theme.of(context).colorScheme.primary), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page)));

  Future<void> _save() async { setState(() => _saving = true); await ref.read(appControllerProvider.notifier).saveSettings(schoolName: _schoolController.text, teacherName: _teacherController.text, academicYear: _yearController.text, stage: _stageController.text); if (!mounted) return; setState(() => _saving = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات بنجاح.'))); }

  Future<void> _requestNotificationPermission() async { final granted = await ref.read(notificationServiceProvider).requestPermissions(); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(granted ? 'تم تفعيل صلاحية التنبيهات.' : 'لم يتم منح صلاحية التنبيهات.'))); }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('استعادة النسخة؟'), content: const Text('سيتم حذف البيانات المحلية الحالية واستبدالها بمحتوى الملف.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('متابعة'))]));
    if (confirmed != true) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;
    try { await ref.read(appControllerProvider.notifier).restoreBackup(utf8.decode(bytes)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت استعادة النسخة الاحتياطية.'))); } on FormatException catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message))); }
  }

  Future<void> _exportBackup() async {
    final json = await ref.read(localRepositoryProvider).exportBackupJson();
    final path = await FilePicker.platform.saveFile(dialogTitle: 'حفظ النسخة الاحتياطية', fileName: 'al-moktaber-backup.json', bytes: utf8.encode(json));
    if (mounted && path != null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تصدير النسخة الاحتياطية.')));
  }
}
