import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_snapshot.dart';
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
      return (_classUuid == 'all' || student.classUuid == _classUuid) && (query.isEmpty || student.fullName.contains(query));
    }).toList(growable: false);
    return Scaffold(
      backgroundColor: Colors.transparent,
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
              DropdownButtonFormField<String>(initialValue: selectedField?.uuid, decoration: const InputDecoration(labelText: 'حقل التقييم'), items: snapshot.gradeFields.map((item) => DropdownMenuItem(value: item.uuid, child: Text('${item.subject} — ${item.title} (${item.maxScore})'))).toList(), onChanged: (value) => setState(() => _fieldUuid = value)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(initialValue: _classUuid, decoration: const InputDecoration(labelText: 'تصفية الصف'), items: [const DropdownMenuItem(value: 'all', child: Text('كل الصفوف')), ...snapshot.classes.map((item) => DropdownMenuItem(value: item.uuid, child: Text(item.name)))], onChanged: (value) => setState(() => _classUuid = value ?? 'all')),
              const SizedBox(height: 12),
              TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث عن طالب')),
              const SizedBox(height: 16),
              if (students.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('لا يوجد طلاب ضمن التصفية.'))),
              if (selectedField != null) ...students.map((student) => _GradeRow(snapshot: snapshot, student: student, field: selectedField, onEdit: () => _showGradeForm(snapshot, student, selectedField))),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showFieldForm() async {
    final subject = TextEditingController();
    final title = TextEditingController();
    final maxScore = TextEditingController(text: '100');
    final term = TextEditingController(text: 'الفصل الأول');
    final key = GlobalKey<FormState>();
    await showAppFormSheet<void>(
      context: context,
      title: 'إضافة حقل تقييم',
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
            await ref.read(appControllerProvider.notifier).createGradeField(subject: subject.text.trim(), title: title.text.trim(), maxScore: double.parse(maxScore.text), term: term.text.trim());
            if (context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.add_task_outlined),
          label: const Text('إنشاء الحقل'),
        ),
      ],
    );
    subject.dispose(); title.dispose(); maxScore.dispose(); term.dispose();
  }

  Future<void> _showGradeForm(AppSnapshot snapshot, Student student, GradeField field) async {
    final existing = snapshot.grades.where((item) => item.studentUuid == student.uuid && item.fieldUuid == field.uuid).firstOrNull;
    final score = TextEditingController(text: existing?.score.toString());
    final notes = TextEditingController(text: existing?.notes);
    await showAppFormSheet<void>(
      context: context,
      title: 'إدخال درجة الطالب',
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
            await ref.read(appControllerProvider.notifier).saveGrade(studentUuid: student.uuid, fieldUuid: field.uuid, score: value, notes: notes.text.trim());
            if (context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('حفظ الدرجة'),
        ),
      ],
    );
    score.dispose(); notes.dispose();
  }

  TextFormField _required(TextEditingController controller, String label) => TextFormField(controller: controller, decoration: InputDecoration(labelText: label), validator: (v) => v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null);
}

class _GradeRow extends StatelessWidget {
  const _GradeRow({required this.snapshot, required this.student, required this.field, required this.onEdit});
  final AppSnapshot snapshot;
  final Student student;
  final GradeField field;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final grade = snapshot.grades.where((item) => item.studentUuid == student.uuid && item.fieldUuid == field.uuid).firstOrNull;
    final percentage = grade == null || field.maxScore == 0 ? null : grade.score / field.maxScore;
    final subtitle = grade == null || percentage == null
        ? const Text('لم تُسجل الدرجة بعد')
        : Text('${grade.score} من ${field.maxScore} — ${(percentage * 100).toStringAsFixed(0)}%');
    return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(onTap: onEdit, leading: CircleAvatar(backgroundColor: scheme.primaryContainer, foregroundColor: scheme.primary, child: Text(student.firstName.characters.first)), title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: subtitle, trailing: IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined))));
  }
}
