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
                      subtitle: 'أنشئ الفصول أولاً، ثم أضف لكل فصل شعبه من زر «إضافة شعبة».',
                    ),
                    if (snapshot.classes.isEmpty)
                      AppEmptyState(
                        icon: Icons.class_outlined,
                        title: 'لا توجد فصول بعد',
                        message: 'أنشئ أول فصل حتى تتمكن من إضافة الشعب والطلاب وربطهم بها.',
                        action: FilledButton.icon(
                          onPressed: () => _showAddClassDialog(context, ref),
                          icon: const Icon(Icons.add_outlined),
                          label: const Text('إضافة فصل'),
                        ),
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
                            onTap: () => _showClassDetails(context, ref, schoolClass.uuid, schoolClass.name),
                            onAddSection: () => _showAddSectionDialog(context, ref, schoolClass.uuid, schoolClass.name),
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
      builder: (dialogContext) => _FormDialog(
        title: 'إضافة فصل',
        formKey: formKey,
        fields: [
          TextFormField(
            controller: name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'اسم الفصل', hintText: 'مثال: الصف الثالث أ'),
            validator: (value) => value == null || value.trim().isEmpty ? 'أدخل اسم الفصل' : null,
          ),
        ],
        cancelLabel: 'إلغاء',
        saveLabel: 'حفظ الفصل',
        onSave: () async {
          if (!(formKey.currentState?.validate() ?? false)) return;
          await ref.read(appControllerProvider.notifier).addClass(name: name.text.trim());
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        },
      ),
    );
    name.dispose();
  }

  static Future<void> _showAddSectionDialog(BuildContext context, WidgetRef ref, String classUuid, String className) async {
    final name = TextEditingController();
    final notes = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _FormDialog(
        title: 'إضافة شعبة',
        subtitle: 'إضافة شعبة جديدة إلى $className',
        formKey: formKey,
        fields: [
          TextFormField(
            controller: name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'اسم الشعبة', hintText: 'مثال: أ، ب، أو شعبة 1'),
            validator: (value) => value == null || value.trim().isEmpty ? 'أدخل اسم الشعبة' : null,
          ),
          TextFormField(
            controller: notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'ملاحظات اختيارية'),
          ),
        ],
        cancelLabel: 'إلغاء',
        saveLabel: 'حفظ الشعبة',
        onSave: () async {
          if (!(formKey.currentState?.validate() ?? false)) return;
          await ref.read(appControllerProvider.notifier).addSection(classUuid: classUuid, name: name.text.trim(), notes: notes.text.trim());
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        },
      ),
    );
    name.dispose();
    notes.dispose();
  }

  static Future<void> _showClassDetails(BuildContext context, WidgetRef ref, String classUuid, String className) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(appControllerProvider);
          return state.when(
            loading: () => const SafeArea(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))),
            error: (_, __) => const SafeArea(child: Padding(padding: EdgeInsets.all(32), child: Text('تعذر تحميل تفاصيل الفصل.'))),
            data: (snapshot) {
              final sections = snapshot.sections.where((section) => section.classUuid == classUuid).toList(growable: false);
              final studentCount = snapshot.students.where((student) => student.classUuid == classUuid).length;
              return SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .78),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    child: AppResponsiveContent(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSectionHeader(title: className, subtitle: 'إدارة الشعب والطلاب المرتبطين بهذا الفصل.'),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth < 480 ? 1 : 2;
                              final width = (constraints.maxWidth - (columns == 2 ? 12 : 0)) / columns;
                              return Wrap(spacing: 12, runSpacing: 12, children: [SizedBox(width: width, child: AppMetricTile(label: 'الطلاب', value: '$studentCount', icon: Icons.groups_outlined, tone: AppStatusTone.neutral)), SizedBox(width: width, child: AppMetricTile(label: 'الشعب', value: '${sections.length}', icon: Icons.view_list_outlined, tone: AppStatusTone.success))]);
                            },
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(child: Text('الشعب المرتبطة', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                              FilledButton.tonalIcon(onPressed: () => _showAddSectionDialog(sheetContext, ref, classUuid, className), icon: const Icon(Icons.add), label: const Text('إضافة شعبة')),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (sections.isEmpty)
                            AppEmptyState(icon: Icons.view_list_outlined, title: 'لا توجد شعب بعد', message: 'استخدم زر «إضافة شعبة» لإنشاء أول شعبة لهذا الفصل.')
                          else
                            ...sections.map((section) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.secondaryContainer, foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer, child: const Icon(Icons.view_list_outlined)), title: Text(section.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), subtitle: section.notes.trim().isEmpty ? null : Text(section.notes), trailing: const Icon(Icons.check_circle_outline)))),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
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

class _FormDialog extends StatelessWidget {
  const _FormDialog({required this.title, required this.formKey, required this.fields, required this.cancelLabel, required this.saveLabel, required this.onSave, this.subtitle});

  final String title;
  final String? subtitle;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;
  final String cancelLabel;
  final String saveLabel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [if (subtitle != null) ...[Text(subtitle!), const SizedBox(height: 16)], for (var index = 0; index < fields.length; index++) ...[fields[index], if (index < fields.length - 1) const SizedBox(height: 14)]]),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(cancelLabel)), FilledButton(onPressed: onSave, child: Text(saveLabel))],
      );
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.name, required this.stage, required this.studentCount, required this.sections, required this.onTap, required this.onAddSection, required this.onDelete});

  final String name;
  final String stage;
  final int studentCount;
  final List<String> sections;
  final VoidCallback onTap;
  final VoidCallback onAddSection;
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
                    if (stage.trim().isNotEmpty) ...[const SizedBox(height: 4), Text(stage)],
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [AppStatusPill(label: '$studentCount طالب', icon: Icons.groups_outlined), AppStatusPill(label: '${sections.length} شعبة', icon: Icons.view_list_outlined, tone: AppStatusTone.success)]),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(onPressed: onAddSection, icon: const Icon(Icons.add), label: const Text('إضافة شعبة')),
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
