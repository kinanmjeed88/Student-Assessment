import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/behavior/behavior_summary.dart';
import '../../../core/database/app_snapshot.dart';
import '../../../core/database/isar_models.dart';
import '../../../core/providers.dart';
import '../../../core/services/report_service.dart';
import '../../../core/utils/iterable_extensions.dart';
import '../../../core/widgets/app_components.dart';

class StudentDetailsPage extends ConsumerWidget {
  const StudentDetailsPage({required this.studentUuid, super.key});
  final String studentUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('ملف الطالب')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذر تحميل ملف الطالب.')),
        data: (snapshot) {
          final student = snapshot.students.where((item) => item.uuid == studentUuid).firstOrNull;
          if (student == null) return const _MissingStudent();
          return _StudentProfile(snapshot: snapshot, student: student);
        },
      ),
    );
  }
}

class _MissingStudent extends StatelessWidget {
  const _MissingStudent();
  @override
  Widget build(BuildContext context) => Center(
        child: FilledButton.icon(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
          label: const Text('العودة إلى الطلاب'),
        ),
      );
}

class _StudentProfile extends ConsumerStatefulWidget {
  const _StudentProfile({required this.snapshot, required this.student});
  final AppSnapshot snapshot;
  final Student student;

  @override
  ConsumerState<_StudentProfile> createState() => _StudentProfileState();
}

class _StudentProfileState extends ConsumerState<_StudentProfile> {

  AppSnapshot get snapshot => widget.snapshot;
  Student get student => widget.student;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final schoolClass = snapshot.classes.where((item) => item.uuid == student.classUuid).firstOrNull;
    final section = snapshot.sections.where((item) => item.uuid == student.sectionUuid).firstOrNull;
    final attendance = snapshot.attendanceFor(student.uuid)..sort((a, b) => b.date.compareTo(a.date));
    final grades = snapshot.gradesFor(student.uuid);
    final behaviors = snapshot.behaviorsFor(student.uuid)..sort((a, b) => b.date.compareTo(a.date));
    final notes = snapshot.notesFor(student.uuid)..sort((a, b) => b.date.compareTo(a.date));
    final summary = calculateBehaviorSummary(records: behaviors, settings: snapshot.settings);
    final absentCount = attendance.where((item) => item.status == AttendanceStatus.absent).length;
    final average = _average(snapshot, grades);
    final profileHeader = _ProfileHeader(
      student: student,
      schoolClass: schoolClass?.name,
      section: section?.name,
      summary: summary,
      attendanceCount: attendance.where((item) => item.status == AttendanceStatus.present).length,
      absentCount: absentCount,
      average: average,
      onExportExcel: () => _exportExcel(context),
      onExportPdf: () => _exportPdf(context),
    );

    return DefaultTabController(
      length: 4,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: AppResponsiveContent(child: profileHeader))),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarHeaderDelegate(
              child: Material(
                color: scheme.surface,
                child: const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelPadding: EdgeInsets.symmetric(horizontal: 10),
                  tabs: [
                    Tab(text: 'الدرجات', icon: Icon(Icons.grade_outlined)),
                    Tab(text: 'الحضور', icon: Icon(Icons.fact_check_outlined)),
                    Tab(text: 'السلوك', icon: Icon(Icons.rule_folder_outlined)),
                    Tab(text: 'الملاحظات', icon: Icon(Icons.note_alt_outlined)),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          children: [
            _TabBody(child: _GradesSection(snapshot: snapshot, grades: grades, studentUuid: student.uuid, onAdd: () => _addGrade(context))),
            _TabBody(child: _AttendanceSection(records: attendance)),
            _TabBody(child: _BehaviorSection(records: behaviors, summary: summary, onAdd: () => _addBehavior(context), onDelete: _deleteBehavior)),
            _TabBody(child: _NotesSection(notes: notes, onAdd: () => _addNote(context), onDelete: _deleteNote)),
          ],
        ),
      ),
    );
  }

  double? _average(AppSnapshot data, List<Grade> grades) {
    if (grades.isEmpty) return null;
    var total = 0.0;
    var count = 0;
    for (final grade in grades) {
      final field = data.gradeFields.where((item) => item.uuid == grade.fieldUuid).firstOrNull;
      if (field == null || field.maxScore <= 0) continue;
      total += grade.score / field.maxScore;
      count++;
    }
    return count == 0 ? null : total / count * 100;
  }

  Future<void> _addGrade(BuildContext context) async {
    final subject = TextEditingController();
    final title = TextEditingController();
    final maxScore = TextEditingController(text: '100');
    final score = TextEditingController();
    final notes = TextEditingController();
    var term = 'الفصل الأول';
    final formKey = GlobalKey<FormState>();
    await showAppFormSheet<void>(
      context: context,
      title: 'إضافة درجة',
      subtitle: 'أدخل بيانات التقييم والدرجة في نموذج واضح قابل للتمرير.',
      child: StatefulBuilder(
        builder: (context, setState) => Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _input(subject, 'المادة'),
              AppSpacing.item,
              _input(title, 'اسم التقييم'),
              AppSpacing.item,
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 420) {
                    return Column(children: [_input(maxScore, 'الدرجة العظمى', numeric: true), AppSpacing.item, _input(score, 'درجة الطالب', numeric: true)]);
                  }
                  return Row(children: [Expanded(child: _input(maxScore, 'الدرجة العظمى', numeric: true)), const SizedBox(width: 12), Expanded(child: _input(score, 'درجة الطالب', numeric: true))]);
                },
              ),
              AppSpacing.item,
              DropdownButtonFormField<String>(initialValue: term, decoration: const InputDecoration(labelText: 'الفصل الدراسي'), items: const [DropdownMenuItem(value: 'الفصل الأول', child: Text('الفصل الأول')), DropdownMenuItem(value: 'الفصل الثاني', child: Text('الفصل الثاني'))], onChanged: (value) => setState(() => term = value ?? term)),
              AppSpacing.item,
              _input(notes, 'ملاحظات', maxLines: 3, required: false),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton.icon(
          onPressed: () async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            final max = double.tryParse(maxScore.text.trim());
            final value = double.tryParse(score.text.trim());
            if (max == null || value == null) return;
            if (value > max) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('درجة الطالب لا يمكن أن تتجاوز الدرجة العظمى.')));
              return;
            }
            Navigator.pop(context);
            await ref.read(appControllerProvider.notifier).createGradeEntry(studentUuid: student.uuid, subject: subject.text.trim(), title: title.text.trim(), maxScore: max, term: term, score: value, notes: notes.text.trim());
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('حفظ الدرجة'),
        ),
      ],
    );
    subject.dispose();
    title.dispose();
    maxScore.dispose();
    score.dispose();
    notes.dispose();
  }

  Future<void> _addBehavior(BuildContext context) async {
    final title = TextEditingController();
    final details = TextEditingController();
    final action = TextEditingController();
    final followUp = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var category = BehaviorCategory.negative;
    var violation = BehaviorViolationType.absence;
    await showAppFormSheet<void>(
      context: context,
      title: 'إضافة سجل سلوك',
      subtitle: 'سجّل الواقعة والإجراء والمتابعة في نموذج منظم.',
      child: StatefulBuilder(
        builder: (context, setState) => Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<BehaviorCategory>(initialValue: category, decoration: const InputDecoration(labelText: 'تصنيف السلوك'), items: const [DropdownMenuItem(value: BehaviorCategory.negative, child: Text('مخالفة سلبية')), DropdownMenuItem(value: BehaviorCategory.followup, child: Text('متابعة')), DropdownMenuItem(value: BehaviorCategory.positive, child: Text('إيجابي'))], onChanged: (value) => setState(() => category = value ?? category)),
              AppSpacing.item,
              if (category == BehaviorCategory.negative) ...[
                DropdownButtonFormField<BehaviorViolationType>(initialValue: violation, decoration: const InputDecoration(labelText: 'نوع المخالفة'), items: const [DropdownMenuItem(value: BehaviorViolationType.absence, child: Text('غياب')), DropdownMenuItem(value: BehaviorViolationType.lessonDisruption, child: Text('تشويش الحصة')), DropdownMenuItem(value: BehaviorViolationType.seriousMisconduct, child: Text('سلوك جسيم')), DropdownMenuItem(value: BehaviorViolationType.other, child: Text('أخرى'))], onChanged: (value) => setState(() => violation = value ?? violation)),
                AppSpacing.item,
              ],
              _input(title, 'عنوان السجل'),
              AppSpacing.item,
              _input(details, 'تفاصيل السلوك', maxLines: 4),
              AppSpacing.item,
              _input(action, 'الإجراء المتخذ', required: false, maxLines: 2),
              AppSpacing.item,
              _input(followUp, 'المتابعة اللاحقة', required: false, maxLines: 2),
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
            await ref.read(appControllerProvider.notifier).addBehavior(studentUuid: student.uuid, category: category, title: title.text.trim(), details: details.text.trim(), violationType: category == BehaviorCategory.negative ? violation : BehaviorViolationType.none, actionTaken: action.text.trim(), followUp: followUp.text.trim());
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('حفظ السجل'),
        ),
      ],
    );
    title.dispose();
    details.dispose();
    action.dispose();
    followUp.dispose();
  }

  Future<void> _addNote(BuildContext context) async {
    final title = TextEditingController();
    final details = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var category = NoteCategory.academic;
    var needsFollowUp = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة ملاحظة'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<NoteCategory>(initialValue: category, decoration: const InputDecoration(labelText: 'تصنيف الملاحظة'), items: const [DropdownMenuItem(value: NoteCategory.academic, child: Text('أكاديمية')), DropdownMenuItem(value: NoteCategory.health, child: Text('صحية')), DropdownMenuItem(value: NoteCategory.educational, child: Text('تربوية')), DropdownMenuItem(value: NoteCategory.attendance, child: Text('حضور')), DropdownMenuItem(value: NoteCategory.other, child: Text('أخرى'))], onChanged: (value) => setDialogState(() => category = value ?? category)),
                _input(title, 'عنوان الملاحظة'),
                _input(details, 'التفاصيل', maxLines: 4),
                CheckboxListTile(value: needsFollowUp, onChanged: (value) => setDialogState(() => needsFollowUp = value ?? false), title: const Text('تحتاج إلى متابعة'), contentPadding: EdgeInsets.zero),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext);
                await ref.read(appControllerProvider.notifier).addNote(studentUuid: student.uuid, category: category, title: title.text, details: details.text, needsFollowUp: needsFollowUp);
              },
              child: const Text('حفظ الملاحظة'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    details.dispose();
  }

  Future<void> _deleteBehavior(String uuid) async {
    if (!await _confirmDelete('حذف سجل السلوك؟')) return;
    await ref.read(appControllerProvider.notifier).deleteBehavior(uuid);
  }

  Future<void> _deleteNote(String uuid) async {
    if (!await _confirmDelete('حذف الملاحظة؟')) return;
    await ref.read(appControllerProvider.notifier).deleteNote(uuid);
  }

  Future<bool> _confirmDelete(String title) async => await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text(title), content: const Text('لا يمكن التراجع عن هذه العملية.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف'))])) ?? false;

  Future<void> _exportExcel(BuildContext context) async {
    final bytes = ReportService().exportStudentXlsx(snapshot, student.uuid);
    final path = await FilePicker.saveFile(dialogTitle: 'حفظ ملف الطالب', fileName: 'بيانات_${student.fullName}.xlsx', bytes: Uint8List.fromList(bytes));
    if (context.mounted && path != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ الملف: $path')));
  }

  Future<void> _exportPdf(BuildContext context) async {
    final bytes = await ReportService().exportStudentPdf(snapshot, student.uuid);
    final path = await FilePicker.saveFile(dialogTitle: 'حفظ ملف الطالب PDF', fileName: 'ملف_${student.fullName}.pdf', bytes: Uint8List.fromList(bytes));
    if (context.mounted && path != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ الملف: $path')));
  }

  InputDecoration _decoration(String label) => InputDecoration(labelText: label);
  TextFormField _input(TextEditingController controller, String label, {bool numeric = false, bool required = true, int maxLines = 1}) => TextFormField(controller: controller, maxLines: maxLines, keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: _decoration(label), validator: required ? (value) => value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null : null);

}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.student, required this.schoolClass, required this.section, required this.summary, required this.attendanceCount, required this.absentCount, required this.average, required this.onExportExcel, required this.onExportPdf});

  final Student student;
  final String? schoolClass;
  final String? section;
  final BehaviorSummary summary;
  final int attendanceCount;
  final int absentCount;
  final double? average;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final statusTone = student.status == StudentStatus.active ? AppStatusTone.success : AppStatusTone.warning;
    final alertColor = summary.dismissed ? scheme.errorContainer : summary.warning ? scheme.tertiaryContainer : scheme.surfaceContainerHighest;
    final buttonStyle = ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(scheme.primaryContainer),
      foregroundColor: WidgetStatePropertyAll(scheme.onPrimaryContainer),
      elevation: const WidgetStatePropertyAll(0),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(student.fullName, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('${schoolClass ?? 'الصف غير محدد'}${section == null ? '' : ' — $section'}', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 420;
                    final status = AppStatusPill(label: _statusLabelForProfile(student.status), icon: _statusIconForProfile(student.status), tone: statusTone);
                    final compactActions = Row(
                      children: [
                        Expanded(child: FilledButton.icon(onPressed: onExportExcel, style: buttonStyle, icon: const Icon(Icons.table_view_outlined), label: const Text('Excel'))),
                        const SizedBox(width: 8),
                        Expanded(child: FilledButton.icon(onPressed: onExportPdf, style: buttonStyle, icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('PDF'))),
                      ],
                    );
                    final wideActions = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.icon(onPressed: onExportExcel, style: buttonStyle, icon: const Icon(Icons.table_view_outlined), label: const Text('Excel')),
                        const SizedBox(width: 8),
                        FilledButton.icon(onPressed: onExportPdf, style: buttonStyle, icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('PDF')),
                      ],
                    );
                    if (compact) {
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [status]), const SizedBox(height: 8), compactActions]);
                    }
                    return Row(children: [status, const SizedBox(width: 12), wideActions]);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          color: alertColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(summary.dismissed || summary.warning ? Icons.warning_amber_outlined : Icons.verified_outlined, color: summary.dismissed ? scheme.error : scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(summary.dismissed ? 'إشعار فصل' : summary.warning ? 'تنبيه سلوك' : 'السجل السلوكي سليم', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                          Text('النقاط ${summary.totalPoints.toStringAsFixed(0)} من ${summary.dismissalThreshold.toStringAsFixed(0)}', style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text('${summary.negativeCount} مخالفات  •  ${summary.followUpCount} متابعات  •  ${summary.positiveCount} إيجابيات', style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _Metric(label: 'متوسط الدرجات', value: average == null ? '—' : '${average!.toStringAsFixed(0)}%', icon: Icons.grade_outlined)),
            const SizedBox(width: 8),
            Expanded(child: _Metric(label: 'الغياب', value: '$absentCount', icon: Icons.event_busy_outlined)),
            const SizedBox(width: 8),
            Expanded(child: _Metric(label: 'الحضور', value: '$attendanceCount', icon: Icons.fact_check_outlined)),
          ],
        ),
        const SizedBox(height: 10),
        _StudentInfoCard(student: student),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 20, 24), child: AppResponsiveContent(child: child));
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 72;

  @override
  double get maxExtent => 72;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) => oldDelegate.child != child;
}

String _statusLabelForProfile(StudentStatus status) => switch (status) { StudentStatus.active => 'نشط', StudentStatus.transferred => 'منقول', StudentStatus.graduated => 'متخرج', StudentStatus.suspended => 'موقوف' };
IconData _statusIconForProfile(StudentStatus status) => switch (status) { StudentStatus.active => Icons.check_circle_outline, StudentStatus.transferred => Icons.swap_horiz, StudentStatus.graduated => Icons.school_outlined, StudentStatus.suspended => Icons.pause_circle_outline };

class _StudentInfoCard extends StatelessWidget {
  const _StudentInfoCard({required this.student});
  final Student student;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _InfoRow(label: 'رقم الطالب', value: student.studentNumber.isEmpty ? 'غير محدد' : student.studentNumber, icon: Icons.badge_outlined),
              _InfoRow(label: 'الجنس', value: student.gender == StudentGender.male ? 'ذكر' : 'أنثى', icon: Icons.person_outline),
              _InfoRow(label: 'ولي الأمر', value: student.guardianName.isEmpty ? 'غير محدد' : student.guardianName, icon: Icons.family_restroom),
              _InfoRow(label: 'هاتف ولي الأمر', value: student.guardianPhone.isEmpty ? 'غير محدد' : student.guardianPhone, icon: Icons.phone_outlined),
            ],
          ),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon, color: Theme.of(context).colorScheme.primary), title: Text(label), subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _GradesSection extends StatelessWidget {
  const _GradesSection({required this.snapshot, required this.grades, required this.studentUuid, required this.onAdd});

  final AppSnapshot snapshot;
  final List<Grade> grades;
  final String studentUuid;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => _SectionCard(
        title: 'الدرجات',
        icon: Icons.grade_outlined,
        action: FilledButton.tonalIcon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('إضافة')),
        child: grades.isEmpty
            ? const Align(alignment: AlignmentDirectional.centerEnd, child: Text('لا توجد درجات مسجلة لهذا الطالب.'))
            : Column(
                children: grades.map((grade) {
                  final field = snapshot.gradeFields.where((item) => item.uuid == grade.fieldUuid).firstOrNull;
                  if (field == null) return const SizedBox.shrink();
                  final ratio = field.maxScore <= 0 ? 0.0 : grade.score / field.maxScore;
                  final scoreColor = ratio <= 0.5 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.tertiary;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(backgroundColor: scoreColor.withValues(alpha: 0.12), foregroundColor: scoreColor, child: Text('${(ratio * 100).round()}')),
                    title: Text('${field.subject} — ${field.title}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    subtitle: Text('${field.term} · ${grade.notes.isEmpty ? 'بدون ملاحظات' : grade.notes}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text('${grade.score}/${field.maxScore}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scoreColor, fontWeight: FontWeight.w900)),
                  );
                }).toList(),
              ),
      );
}

class _AttendanceSection extends StatelessWidget {
  const _AttendanceSection({required this.records});

  final List<AttendanceRecord> records;

  @override
  Widget build(BuildContext context) => _SectionCard(
        title: 'الحضور والغياب',
        icon: Icons.fact_check_outlined,
        child: records.isEmpty
            ? const Align(alignment: AlignmentDirectional.centerEnd, child: Text('لا توجد سجلات حضور لهذا الطالب.'))
            : Column(
                children: records.take(50).map((record) {
                  final label = _attendanceLabel(record.status);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_attendanceIcon(record.status), color: _attendanceColor(context, record.status)),
                    title: Text(_date(record.date), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    subtitle: Text(record.reason.isEmpty ? label : '$label — ${record.reason}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: record.notes.isEmpty ? null : const Icon(Icons.notes_outlined, size: 18),
                  );
                }).toList(),
              ),
      );
}

class _BehaviorSection extends StatelessWidget {
  const _BehaviorSection({required this.records, required this.summary, required this.onAdd, required this.onDelete});

  final List<BehaviorRecord> records;
  final BehaviorSummary summary;
  final VoidCallback onAdd;
  final Future<void> Function(String uuid) onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SectionCard(
      title: 'السلوك',
      icon: Icons.rule_folder_outlined,
      action: FilledButton.tonalIcon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('إضافة')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (records.isEmpty) const Align(alignment: AlignmentDirectional.centerEnd, child: Text('لا توجد سجلات سلوك لهذا الطالب.')),
          if (records.isNotEmpty)
            ...records.map(
              (record) => Dismissible(
                key: ValueKey(record.uuid),
                direction: DismissDirection.startToEnd,
                confirmDismiss: (_) async {
                  await onDelete(record.uuid);
                  return false;
                },
                background: Container(color: scheme.error, alignment: Alignment.centerLeft, padding: const EdgeInsetsDirectional.only(start: 20), child: const Icon(Icons.delete_outline)),
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_behaviorIcon(record.category), color: _behaviorColor(context, record.category)),
                  title: Text(record.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  subtitle: Text('${record.details}\n${_date(record.date)}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Text(record.penaltyPoints == 0 ? 'إيجابي' : '-${record.penaltyPoints.toStringAsFixed(0)}', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: record.penaltyPoints == 0 ? scheme.tertiary : scheme.error, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          const Divider(height: 16),
          Align(alignment: AlignmentDirectional.centerEnd, child: Text('إجمالي النقاط: ${summary.totalPoints.toStringAsFixed(1)}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  const _NotesSection({required this.notes, required this.onAdd, required this.onDelete});

  final List<StudentNote> notes;
  final VoidCallback onAdd;
  final Future<void> Function(String uuid) onDelete;

  @override
  Widget build(BuildContext context) => _SectionCard(
        title: 'الملاحظات',
        icon: Icons.note_alt_outlined,
        action: FilledButton.tonalIcon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('إضافة')),
        child: notes.isEmpty
            ? const Align(alignment: AlignmentDirectional.centerEnd, child: Text('لا توجد ملاحظات لهذا الطالب.'))
            : Column(
                children: notes
                    .map(
                      (note) => Dismissible(
                        key: ValueKey(note.uuid),
                        direction: DismissDirection.startToEnd,
                        confirmDismiss: (_) async {
                          await onDelete(note.uuid);
                          return false;
                        },
                        background: Container(color: Theme.of(context).colorScheme.error, alignment: Alignment.centerLeft, padding: const EdgeInsetsDirectional.only(start: 20), child: const Icon(Icons.delete_outline)),
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.note_alt_outlined, color: Theme.of(context).colorScheme.primary),
                          title: Text(note.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          subtitle: Text('${note.details}\n${_date(note.date)}', maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: note.needsFollowUp ? Icon(Icons.flag_outlined, color: Theme.of(context).colorScheme.tertiary) : null,
                        ),
                      ),
                    )
                    .toList(),
              ),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.child, this.action});
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

IconData _attendanceIcon(AttendanceStatus status) => switch (status) { AttendanceStatus.present => Icons.check_circle_outline, AttendanceStatus.absent => Icons.cancel_outlined, AttendanceStatus.excused => Icons.assignment_turned_in_outlined, AttendanceStatus.late => Icons.schedule_outlined, AttendanceStatus.leave => Icons.event_available_outlined };
String _attendanceLabel(AttendanceStatus status) => switch (status) { AttendanceStatus.present => 'حاضر', AttendanceStatus.absent => 'غائب', AttendanceStatus.excused => 'معذور', AttendanceStatus.late => 'متأخر', AttendanceStatus.leave => 'إجازة' };
Color _attendanceColor(BuildContext context, AttendanceStatus status) => switch (status) { AttendanceStatus.present => Theme.of(context).colorScheme.tertiary, AttendanceStatus.absent => Theme.of(context).colorScheme.error, AttendanceStatus.excused => Theme.of(context).colorScheme.secondary, AttendanceStatus.late => Theme.of(context).colorScheme.tertiary, AttendanceStatus.leave => Theme.of(context).colorScheme.primary };
IconData _behaviorIcon(BehaviorCategory category) => switch (category) { BehaviorCategory.positive => Icons.thumb_up_alt_outlined, BehaviorCategory.negative => Icons.warning_amber_outlined, BehaviorCategory.followup => Icons.follow_the_signs_outlined };
Color _behaviorColor(BuildContext context, BehaviorCategory category) => switch (category) { BehaviorCategory.positive => Theme.of(context).colorScheme.tertiary, BehaviorCategory.negative => Theme.of(context).colorScheme.error, BehaviorCategory.followup => Color.alphaBlend(Theme.of(context).colorScheme.error.withValues(alpha: 0.45), Theme.of(context).colorScheme.surface) };
String _date(DateTime value) => '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';
