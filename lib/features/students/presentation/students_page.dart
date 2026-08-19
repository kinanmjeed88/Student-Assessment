import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/behavior/behavior_summary.dart';
import '../../../core/database/app_snapshot.dart';
import '../../../core/database/isar_models.dart';
import '../../../core/providers.dart';
import '../../../core/utils/iterable_extensions.dart';
import '../../../core/widgets/app_components.dart';
import '../../dashboard/presentation/app_shell.dart';
import '../../import/presentation/import_students_page.dart';
import 'student_details_page.dart';

class StudentsPage extends ConsumerStatefulWidget {
  const StudentsPage({super.key});

  @override
  ConsumerState<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends ConsumerState<StudentsPage> {
  final _searchController = TextEditingController();
  String _classFilter = 'all';
  String _attentionFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
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
        data: (snapshot) => _buildContent(context, snapshot),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppSnapshot snapshot) {
    final students = snapshot.students.where((student) {
      final query = _searchController.text.trim();
      final matchesQuery = query.isEmpty || student.fullName.contains(query) || student.studentNumber.contains(query);
      final matchesClass = _classFilter == 'all' || student.classUuid == _classFilter;
      final summary = calculateBehaviorSummary(records: snapshot.behaviorsFor(student.uuid), settings: snapshot.settings);
      final absences = snapshot.attendanceFor(student.uuid).where((item) => item.status == AttendanceStatus.absent).length;
      final matchesAttention = switch (_attentionFilter) {
        'behavior-alert' => summary.hasAlert,
        'repeated-absence' => absences >= 2,
        _ => true,
      };
      return matchesQuery && matchesClass && matchesAttention;
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلاب'),
        actions: [
          IconButton(
            tooltip: 'استيراد الطلاب',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ImportStudentsPage())),
            icon: const Icon(Icons.upload_file_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStudentForm(snapshot),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('إضافة طالب'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(appControllerProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          children: [
            AppResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FilterPanel(
                    controller: _searchController,
                    classFilter: _classFilter,
                    classItems: snapshot.classes,
                    attentionFilter: _attentionFilter,
                    onSearchChanged: (_) => setState(() {}),
                    onClassChanged: (value) => setState(() => _classFilter = value ?? 'all'),
                    onAttentionChanged: (value) => setState(() => _attentionFilter = value),
                  ),
                  const SizedBox(height: 12),
                  AppSectionHeader(
                    title: 'الطلاب',
                    subtitle: '${students.length} طالب مطابق للمرشحات الحالية.',
                  ),
                  const SizedBox(height: 6),
                  if (students.isEmpty)
                    AppEmptyState(
                      icon: Icons.person_search_outlined,
                      title: 'لا توجد نتائج',
                      message: _searchController.text.trim().isEmpty ? 'أضف طالباً جديداً أو استورد قائمة الطلاب.' : 'جرّب تغيير عبارة البحث أو المرشحات.',
                      action: _searchController.text.trim().isEmpty ? FilledButton.icon(onPressed: () => _showStudentForm(snapshot), icon: const Icon(Icons.person_add_alt_1_outlined), label: const Text('إضافة طالب')) : null,
                    )
                  else
                    ...students.map(
                      (student) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _StudentCard(
                          snapshot: snapshot,
                          student: student,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StudentDetailsPage(studentUuid: student.uuid))),
                          onEdit: () => _showStudentForm(snapshot, student: student),
                          onDelete: () => _deleteStudent(student),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStudentForm(AppSnapshot snapshot, {Student? student}) async {
    if (snapshot.classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف صفاً أولاً قبل إنشاء ملف طالب.')));
      return;
    }
    final firstName = TextEditingController(text: student?.firstName);
    final fatherName = TextEditingController(text: student?.fatherName);
    final lastName = TextEditingController(text: student?.lastName);
    final number = TextEditingController(text: student?.studentNumber);
    final guardian = TextEditingController(text: student?.guardianName);
    final phone = TextEditingController(text: student?.guardianPhone);
    var classUuid = student?.classUuid ?? snapshot.classes.first.uuid;
    var sectionUuid = student?.sectionUuid ?? '';
    var gender = student?.gender ?? StudentGender.male;
    var status = student?.status ?? StudentStatus.active;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(student == null ? 'إضافة طالب' : 'تعديل ملف الطالب'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _RequiredField(controller: firstName, label: 'الاسم الأول'),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 420;
                        final fields = [
                          Expanded(child: TextFormField(controller: fatherName, decoration: const InputDecoration(labelText: 'اسم الأب'))),
                          Expanded(child: _RequiredField(controller: lastName, label: 'اسم العائلة')),
                        ];
                        return compact ? Column(children: [fields[0], const SizedBox(height: 12), fields[1]]) : Row(children: [fields[0], const SizedBox(width: 12), fields[1]]);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: number, decoration: const InputDecoration(labelText: 'رقم الطالب')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<StudentGender>(
                      initialValue: gender,
                      decoration: const InputDecoration(labelText: 'الجنس'),
                      items: const [DropdownMenuItem(value: StudentGender.male, child: Text('ذكر')), DropdownMenuItem(value: StudentGender.female, child: Text('أنثى'))],
                      onChanged: (value) => setDialogState(() => gender = value ?? gender),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: classUuid,
                      decoration: const InputDecoration(labelText: 'الصف'),
                      items: snapshot.classes.map((item) => DropdownMenuItem(value: item.uuid, child: Text(item.name))).toList(),
                      onChanged: (value) => setDialogState(() {
                        classUuid = value ?? classUuid;
                        if (!snapshot.sections.any((section) => section.uuid == sectionUuid && section.classUuid == classUuid)) sectionUuid = '';
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: sectionUuid.isEmpty ? null : sectionUuid,
                      decoration: const InputDecoration(labelText: 'الشعبة (اختياري)'),
                      items: snapshot.sections.where((item) => item.classUuid == classUuid).map((item) => DropdownMenuItem(value: item.uuid, child: Text(item.name))).toList(),
                      onChanged: (value) => setDialogState(() => sectionUuid = value ?? ''),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: guardian, decoration: const InputDecoration(labelText: 'ولي الأمر')),
                    const SizedBox(height: 12),
                    TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'هاتف ولي الأمر')),
                    if (student != null) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<StudentStatus>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'حالة الطالب'),
                        items: const [DropdownMenuItem(value: StudentStatus.active, child: Text('نشط')), DropdownMenuItem(value: StudentStatus.transferred, child: Text('منقول')), DropdownMenuItem(value: StudentStatus.graduated, child: Text('متخرج')), DropdownMenuItem(value: StudentStatus.suspended, child: Text('موقوف'))],
                        onChanged: (value) => setDialogState(() => status = value ?? status),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final controller = ref.read(appControllerProvider.notifier);
                if (student == null) {
                  await controller.addStudent(firstName: firstName.text, fatherName: fatherName.text, lastName: lastName.text, studentNumber: number.text, classUuid: classUuid, sectionUuid: sectionUuid, gender: gender, guardianName: guardian.text, guardianPhone: phone.text);
                } else {
                  await controller.updateStudent(studentUuid: student.uuid, firstName: firstName.text, fatherName: fatherName.text, lastName: lastName.text, studentNumber: number.text, classUuid: classUuid, sectionUuid: sectionUuid, gender: gender, status: status, guardianName: guardian.text, guardianPhone: phone.text);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    firstName.dispose();
    fatherName.dispose();
    lastName.dispose();
    number.dispose();
    guardian.dispose();
    phone.dispose();
  }

  Future<void> _deleteStudent(Student student) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('حذف الطالب؟'), content: Text('سيتم حذف حضور ودرجات وسلوك وملاحظات ${student.fullName}.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف'))]));
    if (confirmed == true) await ref.read(appControllerProvider.notifier).deleteStudent(student.uuid);
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({required this.controller, required this.classFilter, required this.classItems, required this.attentionFilter, required this.onSearchChanged, required this.onClassChanged, required this.onAttentionChanged});

  final TextEditingController controller;
  final String classFilter;
  final List<SchoolClass> classItems;
  final String attentionFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<String> onAttentionChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'ابحث بالاسم أو الرقم...',
                prefixIcon: Icon(Icons.search_outlined),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: classFilter,
              isDense: true,
              decoration: const InputDecoration(labelText: 'تصفية حسب الصف', isDense: true),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('كل الصفوف')),
                ...classItems.map((item) => DropdownMenuItem(value: item.uuid, child: Text(item.name))),
              ],
              onChanged: onClassChanged,
            ),
            const SizedBox(height: 8),
            _AttentionFilters(value: attentionFilter, onChanged: onAttentionChanged),
          ],
        ),
      ),
    );
  }
}

class _AttentionFilters extends StatelessWidget {
  const _AttentionFilters({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  Widget _choice(BuildContext context, {required String label, required String filterValue}) {
    final scheme = Theme.of(context).colorScheme;
    final selected = value == filterValue;
    return Expanded(
      child: ChoiceChip(
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        selected: selected,
        onSelected: (_) => onChanged(filterValue),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
        selectedColor: scheme.primaryContainer,
        backgroundColor: scheme.surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _choice(context, label: 'الكل', filterValue: 'all'),
        const SizedBox(width: 6),
        _choice(context, label: 'تنبيهات السلوك', filterValue: 'behavior-alert'),
        const SizedBox(width: 6),
        _choice(context, label: 'غياب متكرر', filterValue: 'repeated-absence'),
      ],
    );
  }
}

class _RequiredField extends StatelessWidget {
  const _RequiredField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextFormField(controller: controller, decoration: InputDecoration(labelText: label), validator: (value) => value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null);
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.snapshot, required this.student, required this.onTap, required this.onEdit, required this.onDelete});

  final AppSnapshot snapshot;
  final Student student;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final schoolClass = snapshot.classes.where((item) => item.uuid == student.classUuid).firstOrNull;
    final section = snapshot.sections.where((item) => item.uuid == student.sectionUuid).firstOrNull;
    final textTheme = Theme.of(context).textTheme;
    final secondary = [
      schoolClass?.name ?? 'صف غير محدد',
      if (section != null) section.name,
    ].join(' • ');

    return Card(
      child: ListTile(
        dense: true,
        onTap: onTap,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 2, 8, 2),
        title: Row(
          children: [
            Expanded(
              child: Text(
                student.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                secondary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'إجراءات الطالب',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('تعديل الملف')),
            PopupMenuItem(value: 'delete', child: Text('حذف الطالب')),
          ],
        ),
      ),
    );
  }
}
