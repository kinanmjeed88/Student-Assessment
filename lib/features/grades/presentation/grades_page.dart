import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_snapshot.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/database/isar_models.dart';
import '../../../core/providers.dart';
import '../../dashboard/presentation/app_shell.dart';
import '../../../core/utils/iterable_extensions.dart';

class GradesPage extends ConsumerStatefulWidget {
  const GradesPage({super.key});
  @override
  ConsumerState<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends ConsumerState<GradesPage> {
  String? _fieldUuid;
  String _classUuid = 'all';
  String _sectionUuid = 'all';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    return AsyncStateView(state: state, child: state.when(loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink(), data: (snapshot) => _content(context, snapshot)));
  }

  Widget _content(BuildContext context, AppSnapshot snapshot) {
    final field = _fieldUuid == null ? null : snapshot.gradeFields.where((item) => item.uuid == _fieldUuid).firstOrNull;
    final selectedField = field ?? (snapshot.gradeFields.isEmpty ? null : snapshot.gradeFields.first);
    final students = snapshot.students.where((student) {
      final query = _search.text.trim();
      return (_classUuid == 'all' || student.classUuid == _classUuid) && (_sectionUuid == 'all' || student.sectionUuid == _sectionUuid) && (query.isEmpty || student.fullName.contains(query));
    }).toList(growable: false);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('الدرجات')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _showFieldForm(), icon: const Icon(Icons.add_chart_outlined), label: const Text('حقل تقييم')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(appControllerProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          children: [
            if (snapshot.gradeFields.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('لم تُنشأ حقول درجات بعد. أضف اختباراً أو تسميعاً أو تقييماً للبدء.')))
            else ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(value: selectedField?.uuid, decoration: const InputDecoration(labelText: 'حقل التقييم'), items: snapshot.gradeFields.map((item) => DropdownMenuItem(value: item.uuid, child: Text('${item.subject} — ${item.title} (${item.maxScore})'))).toList(), onChanged: (value) => setState(() => _fieldUuid = value)),
                  ),
                  IconButton(onPressed: selectedField == null ? null : () => _showFieldForm(field: selectedField), tooltip: 'تعديل حقل التقييم', icon: const Icon(Icons.edit_outlined)),
                  IconButton(onPressed: selectedField == null ? null : () => _deleteField(selectedField), tooltip: 'حذف حقل التقييم', icon: const Icon(Icons.delete_outline)),
                ],
              ),
              AppSpacing.item,
              DropdownButtonFormField<String>(
                value: _classUuid,
                decoration: const InputDecoration(labelText: 'تصفية الصف'),
                items: [const DropdownMenuItem(value: 'all', child: Text('كل الصفوف')), ...snapshot.classes.map((item) => DropdownMenuItem(value: item.uuid, child: Text(item.name)))],
                onChanged: (value) => setState(() {
                  _classUuid = value ?? 'all';
                  if (_sectionUuid != 'all' && !snapshot.sections.any((section) => section.uuid == _sectionUuid && section.classUuid == _classUuid)) _sectionUuid = 'all';
                }),
              ),
              AppSpacing.item,
              DropdownButtonFormField<String>(
                value: _sectionUuid,
                decoration: const InputDecoration(labelText: 'تصفية الشعبة'),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('كل الشعب')),
                  ...snapshot.sections.where((section) => _classUuid == 'all' || section.classUuid == _classUuid).map((section) => DropdownMenuItem(value: section.uuid, child: Text(section.name))),
                ],
                onChanged: (value) => setState(() => _sectionUuid = value ?? 'all'),
              ),
              AppSpacing.item,
              TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث عن طالب')),
              const SizedBox(height: 16),
              if (students.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('لا يوجد طلاب ضمن التصفية.'))),
              if (selectedField != null)
                ...students.map(
                  (student) => _GradeRow(
                    snapshot: snapshot,
                    student: student,
                    field: selectedField,
                    onEdit: () => _showGradeForm(snapshot, student, selectedField),
                    onDelete: () => _deleteGrade(student, selectedField),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showFieldForm({GradeField? field}) async {
    final subject = TextEditingController(text: field?.subject);
    final title = TextEditingController(text: field?.title);
    final maxScore = TextEditingController(text: (field?.maxScore ?? 100).toString());
    final term = TextEditingController(text: field?.term ?? 'الفصل الأول');
    final key = GlobalKey<FormState>();
    await showAppFormSheet<void>(
      context: context,
      title: field == null ? 'إضافة حقل تقييم' : 'تعديل حقل التقييم',
      subtitle: 'عرّف المادة والتقييم والدرجة العظمى قبل إدخال درجات الطلاب.',
      child: Form(
        key: key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _required(subject, 'المادة'),
            AppSpacing.item,
            _required(title, 'اسم التقييم'),
            AppSpacing.item,
            TextFormField(controller: maxScore, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الدرجة العظمى'), validator: (value) => double.tryParse(value ?? '') == null ? 'أدخل رقماً صحيحاً' : null),
            AppSpacing.item,
            TextFormField(controller: term, decoration: const InputDecoration(labelText: 'الفصل الدراسي')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton.icon(
          onPressed: () async {
            if (!(key.currentState?.validate() ?? false)) return;
            final controller = ref.read(appControllerProvider.notifier);
            final value = double.parse(maxScore.text);
            if (field == null) {
              await controller.createGradeField(subject: subject.text.trim(), title: title.text.trim(), maxScore: value, term: term.text.trim());
            } else {
              await controller.updateGradeField(fieldUuid: field.uuid, subject: subject.text.trim(), title: title.text.trim(), maxScore: value, term: term.text.trim());
            }
            if (context.mounted) Navigator.pop(context);
          },
          icon: Icon(field == null ? Icons.add_task_outlined : Icons.save_outlined),
          label: Text(field == null ? 'إنشاء الحقل' : 'حفظ التعديل'),
        ),
      ],
    );
    subject.dispose(); title.dispose(); maxScore.dispose(); term.dispose();
  }

  Future<void> _deleteField(GradeField field) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف حقل التقييم؟'),
        content: Text('سيتم حذف حقل ${field.title} وجميع درجات الطلاب المرتبطة به.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف نهائي')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(appControllerProvider.notifier).deleteGradeField(field.uuid);
      if (mounted) setState(() => _fieldUuid = null);
    }
  }

  Future<void> _deleteGrade(Student student, GradeField field) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الدرجة؟'),
        content: Text('سيتم حذف درجة ${student.fullName} من حقل ${field.title}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(appControllerProvider.notifier).deleteGrade(
            studentUuid: student.uuid,
            fieldUuid: field.uuid,
          );
    }
  }

  Future<void> _showGradeForm(AppSnapshot snapshot, Student student, GradeField field) async {
    final existing = snapshot.grades.where((item) => item.studentUuid == student.uuid && item.fieldUuid == field.uuid).firstOrNull;
    final score = TextEditingController(text: existing?.score.toString());
    final notes = TextEditingController(text: existing?.notes);
    await showAppFormSheet<void>(
      context: context,
      title: existing == null ? 'إدخال درجة الطالب' : 'تعديل درجة الطالب',
      subtitle: '${student.fullName} — ${field.subject} / ${field.title}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppStatusPill(label: 'الدرجة العظمى: ${field.maxScore}', icon: Icons.assessment_outlined, tone: AppStatusTone.neutral),
          AppSpacing.compact,
          TextField(controller: score, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'درجة الطالب')),
          AppSpacing.item,
          TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'ملاحظات اختيارية')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton.icon(
          onPressed: () async {
            final value = double.tryParse(score.text.trim());
            if (value == null || value < 0 || value > field.maxScore) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('أدخل قيمة بين 0 و${field.maxScore}')));
              return;
            }
            final controller = ref.read(appControllerProvider.notifier);
            if (existing == null) {
              await controller.saveGrade(studentUuid: student.uuid, fieldUuid: field.uuid, score: value, notes: notes.text.trim());
            } else {
              await controller.updateGrade(studentUuid: student.uuid, fieldUuid: field.uuid, subject: field.subject, title: field.title, maxScore: field.maxScore, term: field.term, score: value, notes: notes.text.trim());
            }
            if (context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.save_outlined),
          label: Text(existing == null ? 'حفظ الدرجة' : 'حفظ التعديل'),
        ),
      ],
    );
    score.dispose(); notes.dispose();
  }

  TextFormField _required(TextEditingController controller, String label) => TextFormField(controller: controller, decoration: InputDecoration(labelText: label), validator: (v) => v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null);
}

class _GradeRow extends StatelessWidget {
  const _GradeRow({required this.snapshot, required this.student, required this.field, required this.onEdit, required this.onDelete});
  final AppSnapshot snapshot;
  final Student student;
  final GradeField field;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final grade = snapshot.grades.where((item) => item.studentUuid == student.uuid && item.fieldUuid == field.uuid).firstOrNull;
    final percentage = grade == null || field.maxScore == 0 ? null : grade.score / field.maxScore;
    final subtitle = grade == null || percentage == null
        ? const Text('لم تُسجل الدرجة بعد')
        : Text('${grade.score} من ${field.maxScore} — ${(percentage * 100).toStringAsFixed(0)}%');
    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.compactGap),
      child: ListTile(
        onTap: onEdit,
        leading: Icon(Icons.person_outline, color: scheme.primary),
        title: Text(
          student.fullName,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: subtitle,
        trailing: Wrap(
          spacing: AppTokens.compactGap,
          children: [
            IconButton(onPressed: onEdit, tooltip: 'تعديل', icon: const Icon(Icons.edit_outlined)),
            if (grade != null)
              IconButton(onPressed: onDelete, tooltip: 'حذف', icon: const Icon(Icons.delete_outline)),
          ],
        ),
      ),
    );
  }
}
