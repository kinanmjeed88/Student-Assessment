import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/isar_models.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_tokens.dart';
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
            actions: [
              IconButton(
                tooltip: 'إضافة صف',
                onPressed: () => _showClassForm(context, ref),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showClassForm(context, ref),
            icon: const Icon(Icons.add_outlined),
            label: const Text('إضافة صف'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
            children: [
              AppResponsiveContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الصفوف والشعب',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 16),
                    if (snapshot.classes.isEmpty)
                      AppEmptyState(
                        icon: Icons.class_outlined,
                        title: 'لا توجد صفوف بعد',
                        message: 'أنشئ أول صف حتى تتمكن من إضافة الشعب والطلاب وربطهم بها.',
                        action: FilledButton.icon(
                          onPressed: () => _showClassForm(context, ref),
                          icon: const Icon(Icons.add_outlined),
                          label: const Text('إضافة صف'),
                        ),
                      )
                    else
                      ...snapshot.classes.map((schoolClass) {
                        final studentCount = snapshot.students.where((student) => student.classUuid == schoolClass.uuid).length;
                        final sectionCount = snapshot.sections.where((section) => section.classUuid == schoolClass.uuid).length;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ClassCard(
                            name: schoolClass.name,
                            stage: schoolClass.stage,
                            studentCount: studentCount,
                            sectionCount: sectionCount,
                            onTap: () => _showClassDetails(context, ref, schoolClass.uuid, schoolClass.name),
                            onAddSection: () => _showSectionForm(context, ref, schoolClass.uuid, schoolClass.name),
                            onEdit: () => _showClassForm(context, ref, schoolClass: schoolClass),
                            onDelete: () async {
                              final confirmed = await _confirmDeleteClass(context, schoolClass.name);
                              if (confirmed && context.mounted) {
                                await ref.read(appControllerProvider.notifier).deleteClass(schoolClass.uuid);
                              }
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

  static Future<void> _showClassForm(BuildContext context, WidgetRef ref, {SchoolClass? schoolClass}) async {
    final name = TextEditingController(text: schoolClass?.name ?? '');
    final stage = TextEditingController(text: schoolClass?.stage ?? '');
    final notes = TextEditingController(text: schoolClass?.notes ?? '');
    final formKey = GlobalKey<FormState>();
    final editing = schoolClass != null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => AppFormSheet(
        title: editing ? 'تعديل الصف' : 'إضافة صف',
        subtitle: editing ? 'تحديث بيانات الصف وحفظها في السجل المحلي.' : 'أدخل بيانات الصف الأساسية للبدء بإضافة الشعب.',
        actions: [
          TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('إلغاء')),
          FilledButton.icon(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final controller = ref.read(appControllerProvider.notifier);
              if (editing) {
                await controller.updateClass(classUuid: schoolClass.uuid, name: name.text, stage: stage.text, notes: notes.text);
              } else {
                await controller.addClass(name: name.text, stage: stage.text, notes: notes.text);
              }
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            },
            icon: Icon(editing ? Icons.save_outlined : Icons.add_outlined),
            label: Text(editing ? 'حفظ التعديل' : 'حفظ الصف'),
          ),
        ],
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'اسم الصف', hintText: 'مثال: الصف الثالث'),
                validator: (value) => value == null || value.trim().isEmpty ? 'أدخل اسم الصف' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: stage,
                decoration: const InputDecoration(labelText: 'المرحلة الدراسية', hintText: 'مثال: الابتدائية'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ملاحظات اختيارية'),
              ),
            ],
          ),
        ),
      ),
    );
    name.dispose();
    stage.dispose();
    notes.dispose();
  }

  static Future<void> _showSectionForm(BuildContext context, WidgetRef ref, String classUuid, String className, {Section? section}) async {
    final name = TextEditingController(text: section?.name ?? '');
    final notes = TextEditingController(text: section?.notes ?? '');
    final formKey = GlobalKey<FormState>();
    final editing = section != null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => AppFormSheet(
        title: editing ? 'تعديل الشعبة' : 'إضافة شعبة',
        subtitle: editing ? 'تحديث بيانات الشعبة التابعة إلى $className.' : 'إضافة شعبة جديدة إلى $className.',
        actions: [
          TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('إلغاء')),
          FilledButton.icon(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final controller = ref.read(appControllerProvider.notifier);
              if (editing) {
                await controller.updateSection(sectionUuid: section.uuid, name: name.text, notes: notes.text);
              } else {
                await controller.addSection(classUuid: classUuid, name: name.text, notes: notes.text);
              }
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            },
            icon: Icon(editing ? Icons.save_outlined : Icons.add_outlined),
            label: Text(editing ? 'حفظ التعديل' : 'حفظ الشعبة'),
          ),
        ],
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'اسم الشعبة', hintText: 'مثال: أ أو شعبة 1'),
                validator: (value) => value == null || value.trim().isEmpty ? 'أدخل اسم الشعبة' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ملاحظات اختيارية'),
              ),
            ],
          ),
        ),
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
            error: (_, __) => const SafeArea(child: Padding(padding: EdgeInsets.all(32), child: Text('تعذر تحميل تفاصيل الصف.'))),
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
                          AppSectionHeader(title: className, subtitle: 'إدارة الشعب والطلاب المرتبطين بهذا الصف.'),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: AppMetricTile(label: 'الطلاب', value: '$studentCount', icon: Icons.groups_outlined, tone: AppStatusTone.neutral)),
                              const SizedBox(width: 10),
                              Expanded(child: AppMetricTile(label: 'الشعب', value: '${sections.length}', icon: Icons.view_list_outlined, tone: AppStatusTone.success)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(child: Text('الشعب المرتبطة', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                              FilledButton.tonalIcon(onPressed: () => _showSectionForm(sheetContext, ref, classUuid, className), icon: const Icon(Icons.add), label: const Text('إضافة شعبة')),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (sections.isEmpty)
                            const AppEmptyState(icon: Icons.view_list_outlined, title: 'لا توجد شعب بعد', message: 'استخدم زر «إضافة شعبة» لإنشاء أول شعبة لهذا الصف.')
                          else
                            ...sections.map(
                              (section) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                    foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                                    child: const Icon(Icons.view_list_outlined),
                                  ),
                                  title: Text(section.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                  subtitle: section.notes.trim().isEmpty ? null : Text(section.notes),
                                  trailing: PopupMenuButton<String>(
                                    tooltip: 'إجراءات الشعبة',
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        await _showSectionForm(sheetContext, ref, classUuid, className, section: section);
                                      } else if (value == 'delete') {
                                        await _confirmDeleteSection(sheetContext, ref, section);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Text('تعديل الشعبة')),
                                      PopupMenuItem(value: 'delete', child: Text('حذف الشعبة')),
                                    ],
                                  ),
                                ),
                              ),
                            ),
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

  static Future<bool> _confirmDeleteClass(BuildContext context, String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الصف؟'),
        content: Text('سيؤدي حذف $name إلى حذف طلابه وجميع سجلاتهم بشكل متسلسل.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف نهائي')),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<void> _confirmDeleteSection(BuildContext context, WidgetRef ref, Section section) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الشعبة؟'),
        content: Text('سيتم حذف ${section.name} وإلغاء ربط الطلاب بها، دون حذف ملفات الطلاب أو سجلاتهم.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف الشعبة')),
        ],
      ),
    );
    if (result == true && context.mounted) {
      await ref.read(appControllerProvider.notifier).deleteSection(section.uuid);
    }
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.name, required this.stage, required this.studentCount, required this.sectionCount, required this.onTap, required this.onAddSection, required this.onEdit, required this.onDelete});

  final String name;
  final String stage;
  final int studentCount;
  final int sectionCount;
  final VoidCallback onTap;
  final VoidCallback onAddSection;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.largeRadius),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 12, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < AppBreakpoints.medium;
              final badges = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppStatusPill(label: '$studentCount طالب', icon: Icons.groups_outlined, compact: true),
                  const SizedBox(width: AppTokens.tightGap),
                  AppStatusPill(label: '$sectionCount شعبة', icon: Icons.view_list_outlined, tone: AppStatusTone.success, compact: true),
                ],
              );
              return Row(
                children: [
                  Expanded(
                    flex: isCompact ? 4 : 5,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        if (stage.trim().isNotEmpty)
                          Text(
                            stage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelSmall,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTokens.tightGap),
                  Flexible(
                    flex: isCompact ? 4 : 5,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.center,
                      child: badges,
                    ),
                  ),
                  const SizedBox(width: AppTokens.tightGap),
                  IconButton(
                    onPressed: onAddSection,
                    tooltip: 'إضافة شعبة',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: AppTokens.minTouchTarget, minHeight: AppTokens.minTouchTarget),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'إجراءات الصف',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: AppTokens.minTouchTarget, minHeight: AppTokens.minTouchTarget),
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('تعديل الصف')),
                      PopupMenuItem(value: 'delete', child: Text('حذف الصف')),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
