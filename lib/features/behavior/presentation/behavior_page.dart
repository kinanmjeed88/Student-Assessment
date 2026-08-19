import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_snapshot.dart';
import '../../../core/database/isar_models.dart';
import '../../../core/providers.dart';
import '../../../core/utils/iterable_extensions.dart';
import '../../../core/widgets/app_components.dart';
import '../../students/presentation/student_details_page.dart';

class BehaviorPage extends ConsumerStatefulWidget {
  const BehaviorPage({super.key, this.studentUuid});

  final String? studentUuid;

  @override
  ConsumerState<BehaviorPage> createState() => _BehaviorPageState();
}

class _BehaviorPageState extends ConsumerState<BehaviorPage> {
  String _filter = 'all';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
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
        data: (snapshot) => _content(context, snapshot),
      ),
    );
  }

  Widget _content(BuildContext context, AppSnapshot snapshot) {
    final records = snapshot.behaviors.where((item) {
      final student = snapshot.students.where((s) => s.uuid == item.studentUuid).firstOrNull;
      final query = _search.text.trim();
      final matchesStudent = widget.studentUuid == null || item.studentUuid == widget.studentUuid;
      final matchesQuery = query.isEmpty ||
          item.title.contains(query) ||
          item.details.contains(query) ||
          (student?.fullName.contains(query) ?? false);
      final matchesFilter = _filter == 'all' || item.category.name == _filter;
      return matchesStudent && matchesQuery && matchesFilter;
    }).toList(growable: false);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('السلوك والمتابعة')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(snapshot),
        icon: const Icon(Icons.add_task_outlined),
        label: const Text('تسجيل سلوك'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(appControllerProvider.notifier).refresh(),
        child: ListView(
          padding: AppSpacing.contentList,
          children: [
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ابحث في السلوك أو اسم الطالب',
              ),
            ),
            AppSpacing.compact,
            Wrap(
              spacing: AppTokens.compactGap,
              runSpacing: AppTokens.compactGap,
              children: [
                _chip('all', 'الكل'),
                _chip('negative', 'سلبي'),
                _chip('positive', 'إيجابي'),
                _chip('followup', 'متابعة'),
              ],
            ),
            AppSpacing.item,
            if (records.isEmpty)
              const _EmptyBehavior()
            else
              ...records.map(
                (record) => _BehaviorCard(
                  snapshot: snapshot,
                  record: record,
                  onEdit: () => _showForm(snapshot, record: record),
                  onDelete: () => _delete(record),
                  onOpenStudent: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StudentDetailsPage(studentUuid: record.studentUuid),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String value, String label) => ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
      );

  Future<void> _showForm(AppSnapshot snapshot, {BehaviorRecord? record}) async {
    if (snapshot.students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف طالباً أولاً لتسجيل السلوك.')),
      );
      return;
    }

    final title = TextEditingController(text: record?.title ?? '');
    final details = TextEditingController(text: record?.details ?? '');
    final action = TextEditingController(text: record?.actionTaken ?? '');
    final followUp = TextEditingController(text: record?.followUp ?? '');
    var studentUuid = record?.studentUuid ?? widget.studentUuid ?? snapshot.students.first.uuid;
    var category = record?.category ?? BehaviorCategory.negative;
    var type = record?.violationType ?? BehaviorViolationType.other;
    final formKey = GlobalKey<FormState>();
    final editing = record != null;

    await showAppFormSheet<void>(
      context: context,
      title: editing ? 'تعديل سجل السلوك' : 'تسجيل سلوك',
      subtitle: editing
          ? 'حدّث بيانات السجل ثم احفظ التغييرات.'
          : 'اختر الطالب ثم أدخل تفاصيل الواقعة والإجراء والمتابعة.',
      child: StatefulBuilder(
        builder: (context, setState) => Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: studentUuid,
                decoration: const InputDecoration(labelText: 'الطالب'),
                items: snapshot.students
                    .map(
                      (student) => DropdownMenuItem(
                        value: student.uuid,
                        child: Text(student.fullName, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: editing
                    ? null
                    : (value) => setState(() => studentUuid = value ?? studentUuid),
              ),
              AppSpacing.item,
              DropdownButtonFormField<BehaviorCategory>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'التصنيف'),
                items: const [
                  DropdownMenuItem(value: BehaviorCategory.negative, child: Text('سلوك سلبي')),
                  DropdownMenuItem(value: BehaviorCategory.positive, child: Text('سلوك إيجابي')),
                  DropdownMenuItem(value: BehaviorCategory.followup, child: Text('متابعة')),
                ],
                onChanged: (value) => setState(() => category = value ?? category),
              ),
              if (category == BehaviorCategory.negative) ...[
                AppSpacing.item,
                DropdownButtonFormField<BehaviorViolationType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'نوع المخالفة'),
                  items: const [
                    DropdownMenuItem(value: BehaviorViolationType.absence, child: Text('غياب')),
                    DropdownMenuItem(
                      value: BehaviorViolationType.lessonDisruption,
                      child: Text('تشويش الدرس'),
                    ),
                    DropdownMenuItem(
                      value: BehaviorViolationType.seriousMisconduct,
                      child: Text('مخالفة جسيمة'),
                    ),
                    DropdownMenuItem(value: BehaviorViolationType.other, child: Text('أخرى')),
                  ],
                  onChanged: (value) => setState(() => type = value ?? type),
                ),
              ],
              AppSpacing.item,
              TextFormField(
                controller: title,
                decoration: const InputDecoration(labelText: 'العنوان'),
                validator: (value) => value == null || value.trim().isEmpty ? 'العنوان مطلوب' : null,
              ),
              AppSpacing.item,
              TextFormField(
                controller: details,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'التفاصيل'),
                validator: (value) => value == null || value.trim().isEmpty ? 'التفاصيل مطلوبة' : null,
              ),
              AppSpacing.item,
              TextFormField(
                controller: action,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'الإجراء المتخذ'),
              ),
              AppSpacing.item,
              TextFormField(
                controller: followUp,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'خطة المتابعة'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton.icon(
          onPressed: () async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(context);
            final controller = ref.read(appControllerProvider.notifier);
            final violationType = category == BehaviorCategory.negative
                ? type
                : BehaviorViolationType.none;
            if (editing) {
              await controller.updateBehavior(
                behaviorUuid: record.uuid,
                category: category,
                title: title.text.trim(),
                details: details.text.trim(),
                violationType: violationType,
                actionTaken: action.text.trim(),
                followUp: followUp.text.trim(),
              );
            } else {
              await controller.addBehavior(
                studentUuid: studentUuid,
                category: category,
                title: title.text.trim(),
                details: details.text.trim(),
                violationType: violationType,
                actionTaken: action.text.trim(),
                followUp: followUp.text.trim(),
              );
            }
          },
          icon: Icon(editing ? Icons.save_outlined : Icons.add_task_outlined),
          label: Text(editing ? 'حفظ التعديل' : 'حفظ السجل'),
        ),
      ],
    );

    title.dispose();
    details.dispose();
    action.dispose();
    followUp.dispose();
  }

  Future<void> _delete(BehaviorRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف السجل؟'),
        content: const Text('سيتم حذف سجل السلوك نهائياً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(appControllerProvider.notifier).deleteBehavior(record.uuid);
    }
  }
}

class _BehaviorCard extends StatelessWidget {
  const _BehaviorCard({
    required this.snapshot,
    required this.record,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenStudent,
  });

  final AppSnapshot snapshot;
  final BehaviorRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpenStudent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final student = snapshot.students.where((item) => item.uuid == record.studentUuid).firstOrNull;
    final color = switch (record.category) {
      BehaviorCategory.positive => scheme.primary,
      BehaviorCategory.negative => scheme.error,
      BehaviorCategory.followup => scheme.tertiary,
    };
    final icon = switch (record.category) {
      BehaviorCategory.positive => Icons.thumb_up_alt_outlined,
      BehaviorCategory.negative => Icons.flag_outlined,
      BehaviorCategory.followup => Icons.follow_the_signs_outlined,
    };

    return Card(
      margin: EdgeInsets.only(bottom: AppTokens.compactGap),
      child: ListTile(
        onTap: onOpenStudent,
        leading: Icon(icon, color: color),
        title: Text(
          '${record.title} - ${record.penaltyPoints.toStringAsFixed(0)} نقطة',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${student?.fullName ?? 'طالب غير معروف'}\n${record.details}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: AppTokens.compactGap,
          children: [
            IconButton(
              tooltip: 'تعديل',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'حذف',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBehavior extends StatelessWidget {
  const _EmptyBehavior();

  @override
  Widget build(BuildContext context) => Padding(
        padding: AppSpacing.emptyState,
        child: Column(
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
            AppSpacing.compact,
            const Text('لا توجد سجلات سلوك حتى الآن.'),
          ],
        ),
      );
}
