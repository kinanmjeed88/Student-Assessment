import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/app_components.dart';
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddClassDialog(context, ref),
            icon: const Icon(Icons.add_outlined),
            label: const Text('إضافة فصل'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
            children: [
              AppResponsiveContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppPageHeader(
                      title: 'هيكل المدرسة',
                      subtitle: 'نظّم الفصول والشعب وتابع عدد الطلاب في كل مجموعة.',
                    ),
                    if (snapshot.classes.isEmpty)
                      AppEmptyState(
                        icon: Icons.class_outlined,
                        title: 'لا توجد فصول بعد',
                        message: 'أنشئ أول فصل حتى تتمكن من إضافة الطلاب وربطهم بالشعب.',
                        action: FilledButton.icon(onPressed: () => _showAddClassDialog(context, ref), icon: const Icon(Icons.add_outlined), label: const Text('إضافة فصل')),
                      )
                    else
                      ...snapshot.classes.map((schoolClass) {
                        final studentCount = snapshot.students.where((student) => student.classUuid == schoolClass.uuid).length;
                        final sections = snapshot.sections.where((section) => section.classUuid == schoolClass.uuid).toList(growable: false);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ClassCard(
                            name: schoolClass.name,
                            stage: schoolClass.stage,
                            studentCount: studentCount,
                            sections: sections.map((section) => section.name).toList(growable: false),
                            onTap: () => _showClassDetails(context, schoolClass.name, studentCount, sections.map((item) => item.name).toList()),
                            onDelete: () async {
                              final confirmed = await _confirmDelete(context, schoolClass.name);
                              if (confirmed && context.mounted) await ref.read(appControllerProvider.notifier).deleteClass(schoolClass.uuid);
                            },
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _showAddClassDialog(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة فصل'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'اسم الفصل', hintText: 'مثال: الصف الثالث أ'),
              validator: (value) => value == null || value.trim().isEmpty ? 'أدخل اسم الفصل' : null,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              await ref.read(appControllerProvider.notifier).addClass(name: name.text.trim());
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
              AppSectionHeader(title: name, subtitle: 'ملخص الفصل والشعب المرتبطة به.'),
              const SizedBox(height: 16),
              Row(children: [Expanded(child: AppMetricTile(label: 'الطلاب', value: '$studentCount', icon: Icons.groups_outlined, tone: AppStatusTone.neutral)), const SizedBox(width: 12), Expanded(child: AppMetricTile(label: 'الشعب', value: '${sections.length}', icon: Icons.view_list_outlined, tone: AppStatusTone.success))]),
              const SizedBox(height: 16),
              Text(sections.isEmpty ? 'لا توجد شعب مرتبطة بهذا الفصل بعد.' : 'الشعب: ${sections.join('، ')}'),
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
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف نهائي')),
        ],
      ),
    );
    return result ?? false;
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.name, required this.stage, required this.studentCount, required this.sections, required this.onTap, required this.onDelete});

  final String name;
  final String stage;
  final int studentCount;
  final List<String> sections;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 28, backgroundColor: scheme.primaryContainer, foregroundColor: scheme.onPrimaryContainer, child: const Icon(Icons.class_outlined)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    if (stage.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(stage),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppStatusPill(label: '$studentCount طالب', icon: Icons.groups_outlined),
                        AppStatusPill(label: '${sections.length} شعبة', icon: Icons.view_list_outlined, tone: AppStatusTone.success),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'إجراءات الفصل',
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('حذف الفصل'))],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
