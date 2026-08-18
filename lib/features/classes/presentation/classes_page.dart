import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../dashboard/presentation/app_shell.dart';

class ClassesPage extends ConsumerWidget {
  const ClassesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AsyncStateView(
      state: state,
      child: state.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (snapshot) => Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('الفصول والشعب'),
            actions: [
              IconButton(
                tooltip: 'إضافة فصل',
                onPressed: () => _showAddClassDialog(context, ref),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          body: snapshot.classes.isEmpty
              ? const Center(child: Text('لا توجد فصول. استخدم زر الإضافة للبدء.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  itemCount: snapshot.classes.length,
                  itemBuilder: (context, index) {
                    final schoolClass = snapshot.classes[index];
                    final studentCount = snapshot.students
                        .where((student) => student.classUuid == schoolClass.uuid)
                        .length;
                    final sections = snapshot.sections
                        .where((section) => section.classUuid == schoolClass.uuid)
                        .toList(growable: false);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _showClassDetails(context, schoolClass.name, studentCount, sections.map((e) => e.name).toList()),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(color: const Color(0xFFE8F0FF), borderRadius: BorderRadius.circular(16)),
                                child: const Icon(Icons.class_, color: Color(0xFF1D4ED8)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(schoolClass.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text('$studentCount طالب • ${sections.length} شعبة'),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value != 'delete') return;
                                  final confirmed = await _confirmDelete(context, schoolClass.name);
                                  if (confirmed && context.mounted) {
                                    await ref.read(appControllerProvider.notifier).deleteClass(schoolClass.uuid);
                                  }
                                },
                                itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('حذف الفصل'))],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddClassDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('إضافة فصل'),
          ),
        ),
      ),
    );
  }

  static Future<void> _showAddClassDialog(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة فصل'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'اسم الفصل', hintText: 'مثال: الصف الثالث أ'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(appControllerProvider.notifier).addClass(name.text);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    name.dispose();
  }

  static Future<void> _showClassDetails(BuildContext context, String name, int studentCount, List<String> sections) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('عدد الطلاب: $studentCount'),
              const SizedBox(height: 8),
              Text(sections.isEmpty ? 'لا توجد شعب بعد.' : 'الشعب: ${sections.join('، ')}'),
            ],
          ),
        ),
      ),
    );
  }

  static Future<bool> _confirmDelete(BuildContext context, String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الفصل؟'),
        content: Text('سيؤدي حذف $name إلى حذف طلابه وجميع سجلاتهم بشكل متسلسل.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف نهائي')),
        ],
      ),
    );
    return result ?? false;
  }
}
