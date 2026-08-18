import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../dashboard/presentation/app_shell.dart';
import '../data/backup_service.dart';

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
  void dispose() {
    _schoolController.dispose();
    _teacherController.dispose();
    _yearController.dispose();
    _stageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    return AsyncStateView(
      state: state,
      child: state.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (snapshot) {
          if (!_initialized) {
            _schoolController.text = snapshot.settings.schoolName;
            _teacherController.text = snapshot.settings.teacherName;
            _yearController.text = snapshot.settings.academicYear;
            _stageController.text = snapshot.settings.stage;
            _initialized = true;
          }
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: const Text('الإعدادات')),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              children: [
                const Text('بيانات المدرسة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(controller: _schoolController, decoration: const InputDecoration(labelText: 'اسم المدرسة')),
                        const SizedBox(height: 12),
                        TextField(controller: _teacherController, decoration: const InputDecoration(labelText: 'اسم المعلم')),
                        const SizedBox(height: 12),
                        TextField(controller: _yearController, decoration: const InputDecoration(labelText: 'العام الدراسي')),
                        const SizedBox(height: 12),
                        TextField(controller: _stageController, decoration: const InputDecoration(labelText: 'المرحلة الدراسية')),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
                          label: const Text('حفظ الإعدادات'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('النسخ والتنبيهات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.notifications_active_outlined),
                        title: const Text('صلاحيات التنبيهات'),
                        subtitle: const Text('تهيئة Android 13+ والتنبيهات الدقيقة عند الحاجة.'),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: _requestNotificationPermission,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.restore_outlined),
                        title: const Text('استعادة نسخة JSON'),
                        subtitle: const Text('استبدال البيانات المحلية بملف احتياطي موثوق.'),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => _restoreBackup(ref),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.backup_outlined),
                        title: const Text('تصدير نسخة احتياطية'),
                        subtitle: const Text('JSON شامل لاستعادة البيانات على جهاز آخر.'),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => _exportBackup(ref),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.offline_bolt_outlined),
                    title: Text('وضع العمل المحلي'),
                    subtitle: Text('البيانات محفوظة في Isar ولا يتطلب التطبيق اتصالاً بالشبكة.'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(appControllerProvider.notifier).saveSettings(
      schoolName: _schoolController.text,
      teacherName: _teacherController.text,
      academicYear: _yearController.text,
      stage: _stageController.text,
    );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات بنجاح ✓')));
    }
  }

  Future<void> _requestNotificationPermission() async {
    final granted = await ref.read(notificationServiceProvider).requestPermissions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(granted ? 'تم تفعيل صلاحية التنبيهات ✓' : 'لم يتم منح صلاحية التنبيهات.')));
  }

  Future<void> _restoreBackup(WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استعادة النسخة؟'),
        content: const Text('سيتم حذف البيانات المحلية الحالية واستبدالها بمحتوى الملف. يجب تنفيذ نسخة احتياطية أولاً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('متابعة')),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final bytes = await result?.readAsBytes();
    if (bytes == null) return;
    try {
      await ref.read(appControllerProvider.notifier).restoreBackup(utf8.decode(bytes));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت استعادة النسخة الاحتياطية بنجاح ✓')));
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _exportBackup(WidgetRef ref) async {
    final json = await ref.read(localRepositoryProvider).exportBackupJson();
    final path = await BackupService().saveJson(json);
    if (!mounted || path == null) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تصدير النسخة الاحتياطية بنجاح ✓')));
  }
}
