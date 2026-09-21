import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_snapshot.dart';
import '../../../core/database/isar_models.dart';
import '../../../core/providers.dart';
import '../../dashboard/presentation/app_shell.dart';
import '../../../core/utils/iterable_extensions.dart';

class ImportHistoryPage extends ConsumerWidget {
  const ImportHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AsyncStateView(
      state: state,
      child: state.when(loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink(), data: (snapshot) => _content(context, ref, snapshot)),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, AppSnapshot snapshot) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل الاستيراد')),
      body: snapshot.imports.isEmpty
          ? const Center(child: Text('لا توجد عمليات استيراد مسجلة.'))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: snapshot.imports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final record = snapshot.imports[index];
                final className = snapshot.classes.where((item) => item.uuid == record.classUuid).firstOrNull?.name ?? 'صف محذوف';
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(record.sourceFormat == StudentImportFormat.excel ? Icons.table_chart_outlined : Icons.text_snippet_outlined)),
                    title: Text(record.sourceFilename, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('$className • ${record.addedCount} طالب • ${_date(record.createdAt)}${record.revertedAt == null ? '' : '\nتم التراجع عن العملية'}'),
                    trailing: record.revertedAt == null ? IconButton(tooltip: 'تراجع', onPressed: () => _revert(context, ref, record), icon: const Icon(Icons.undo_outlined)) : const Icon(Icons.check_circle_outline),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _revert(BuildContext context, WidgetRef ref, StudentImportRecord record) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('التراجع عن الاستيراد؟'), content: Text('سيتم حذف ${record.addedCount} طالباً أضيفوا في هذه العملية فقط.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('تراجع'))]));
    if (confirmed == true) await ref.read(appControllerProvider.notifier).revertImport(record.uuid);
  }
}

String _date(DateTime value) => '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';
