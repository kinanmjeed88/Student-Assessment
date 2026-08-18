import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_snapshot.dart';
import '../../../core/database/isar_models.dart';
import '../../../core/providers.dart';
import '../../../core/services/import_export_service.dart';
import '../../dashboard/presentation/app_shell.dart';

class ImportStudentsPage extends ConsumerStatefulWidget {
  const ImportStudentsPage({super.key});
  @override
  ConsumerState<ImportStudentsPage> createState() => _ImportStudentsPageState();
}

class _ImportStudentsPageState extends ConsumerState<ImportStudentsPage> {
  final _service = ImportExportService();
  ImportedStudentsFile? _file;
  String? _classUuid;
  String? _sectionUuid;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    return AsyncStateView(
      state: state,
      child: state.when(loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink(), data: (snapshot) => _content(context, snapshot)),
    );
  }

  Widget _content(BuildContext context, AppSnapshot snapshot) {
    final classUuid = _classUuid ?? (snapshot.classes.isEmpty ? null : snapshot.classes.first.uuid);
    final sections = snapshot.sections.where((section) => section.classUuid == classUuid).toList(growable: false);
    final sectionUuid = _sectionUuid != null && sections.any((item) => item.uuid == _sectionUuid) ? _sectionUuid! : (sections.isEmpty ? '' : sections.first.uuid);
    return Scaffold(
      appBar: AppBar(title: const Text('استيراد الطلاب')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [Icon(Icons.upload_file_outlined, size: 56, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 12), Text('استيراد من Excel أو Word أو CSV أو TXT', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('يُقرأ الاسم من العمود الأول، وتُتجاهل الصفوف التي تمثل عناوين.'), const SizedBox(height: 16), OutlinedButton.icon(onPressed: _busy ? null : _pickFile, icon: const Icon(Icons.folder_open_outlined), label: Text(_file == null ? 'اختيار ملف' : _file!.filename))]))),
          const SizedBox(height: 16),
          if (snapshot.classes.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('أضف صفاً أولاً حتى تحدد وجهة الطلاب.'))),
          if (snapshot.classes.isNotEmpty) ...[
            DropdownButtonFormField<String>(initialValue: classUuid, decoration: const InputDecoration(labelText: 'الصف المستهدف'), items: snapshot.classes.map((item) => DropdownMenuItem(value: item.uuid, child: Text(item.name))).toList(), onChanged: (value) => setState(() { _classUuid = value; _sectionUuid = null; })),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(initialValue: sectionUuid.isEmpty ? null : sectionUuid, decoration: const InputDecoration(labelText: 'الشعبة المستهدفة (اختياري)'), items: sections.map((item) => DropdownMenuItem(value: item.uuid, child: Text(item.name))).toList(), onChanged: (value) => setState(() => _sectionUuid = value)),
          ],
          if (_file != null) ...[
            const SizedBox(height: 24),
            Text('المعاينة (${_file!.names.length} اسماً)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Card(child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 260), child: ListView.builder(itemCount: _file!.names.length, itemBuilder: (_, index) => ListTile(dense: true, leading: CircleAvatar(radius: 14, child: Text('${index + 1}')), title: Text(_file!.names[index]))))),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _busy || classUuid == null ? null : () => _import(classUuid, sectionUuid), icon: const Icon(Icons.cloud_upload_outlined), label: const Text('إضافة الطلاب وتسجيل العملية')),
          ],
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      setState(() => _busy = true);
      final file = await _service.pickStudentsFile();
      if (mounted) setState(() => _file = file);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر قراءة الملف: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import(String classUuid, String sectionUuid) async {
    final file = _file;
    if (file == null) return;
    try {
      setState(() => _busy = true);
      await ref.read(appControllerProvider.notifier).importStudents(classUuid: classUuid, sectionUuid: sectionUuid, sourceFilename: file.filename, sourceFormat: file.format == 'excel' ? StudentImportFormat.excel : file.format == 'word' ? StudentImportFormat.word : StudentImportFormat.text, names: file.names);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استيراد الطلاب وتسجيل العملية.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
