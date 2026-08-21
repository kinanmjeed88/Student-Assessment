import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/behavior/behavior_summary.dart';
import '../../../core/database/app_snapshot.dart';
import '../../../core/database/isar_models.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_tokens.dart';
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
  String _sectionFilter = 'all';
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
      final matchesSection = _sectionFilter == 'all' || student.sectionUuid == _sectionFilter;
      final summary = calculateBehaviorSummary(records: snapshot.behaviorsFor(student.uuid), settings: snapshot.settings);
      final absences = snapshot.attendanceFor(student.uuid).where((item) => item.status == AttendanceStatus.absent).length;
      final matchesAttention = switch (_attentionFilter) {
        'behavior-alert' => summary.hasAlert,
        'repeated-absence' => absences >= 2,
        _ => true,
      };
      return matchesQuery && matchesClass && matchesSection && matchesAttention;
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
            padding: AppSpacing.contentList,
          children: [
            AppResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FilterPanel(
                    controller: _searchController,
                    classFilter: _classFilter,
                    sectionFilter: _sectionFilter,
                    classItems: snapshot.classes,
                    sectionItems: snapshot.sections,
                    attentionFilter: _attentionFilter,
                    onSearchChanged: (_) => setState(() {}),
                    onClassChanged: (value) => setState(() {
                      _classFilter = value ?? 'all';
                      _sectionFilter = 'all';
                    }),
                    onSectionChanged: (value) => setState(() => _sectionFilter = value ?? 'all'),
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
                      title: 'لا يوجد طلاب',
                      message: _searchController.text.trim().isEmpty ? 'أضف طالباً جديداً أو استورد قائمة الطلاب.' : 'جرّب تغيير عبارة البحث أو المرشحات الحالية.',
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

    await showAppFormSheet<void>(
      context: context,
      title: student == null ? 'إضافة طالب' : 'تعديل ملف الطالب',
      subtitle: 'أدخل بيانات الطالب الأساسية واربطه بالصف والشعبة الصحيحة.',
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          final fatherField = TextFormField(controller: fatherName, decoration: const InputDecoration(labelText: 'اسم الأب'));
          final lastNameField = _RequiredField(controller: lastName, label: 'اسم العائلة');
          return Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RequiredField(controller: firstName, label: 'الاسم الأول'),
                AppSpacing.item,
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 420) {
                      return Column(children: [fatherField, AppSpacing.item, lastNameField]);
                    }
                    return Row(children: [Expanded(child: fatherField), const SizedBox(width: AppTokens.itemGap), Expanded(child: lastNameField)]);
                  },
                ),
                AppSpacing.item,
                TextFormField(controller: number, decoration: const InputDecoration(labelText: 'رقم الطالب')),
                AppSpacing.item,
                DropdownButtonFormField<StudentGender>(
                  value: gender,
                  decoration: const InputDecoration(labelText: 'الجنس'),
                  items: const [DropdownMenuItem(value: StudentGender.male, child: Text('ذكر')), DropdownMenuItem(value: StudentGender.female, child: Text('أنثى'))],
                  onChanged: (value) => setSheetState(() => gender = value ?? gender),
                ),
                AppSpacing.item,
                DropdownButtonFormField<String>(
                  value: classUuid,
                  decoration: const InputDecoration(labelText: 'الصف'),
                  items: snapshot.classes.map((item) => DropdownMenuItem(value: item.uuid, child: Text(item.name))).toList(),
                  onChanged: (value) => setSheetState(() {
                    classUuid = value ?? classUuid;
                    if (!snapshot.sections.any((section) => section.uuid == sectionUuid && section.classUuid == classUuid)) sectionUuid = '';
                  }),
                ),
                AppSpacing.item,
                DropdownButtonFormField<String>(
                  value: sectionUuid.isEmpty ? null : sectionUuid,
                  decoration: const InputDecoration(labelText: 'الشعبة (اختياري)'),
                  items: [
                    const DropdownMenuItem<String>(value: '', child: Text('بدون شعبة')),
                    ...snapshot.sections.where((item) => item.classUuid == classUuid).map((item) => DropdownMenuItem(value: item.uuid, child: Text(item.name))),
                  ],
                  onChanged: (value) => setSheetState(() => sectionUuid = value ?? ''),
                ),
                AppSpacing.item,
                TextFormField(controller: guardian, decoration: const InputDecoration(labelText: 'ولي الأمر')),
                AppSpacing.item,
                TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'هاتف ولي الأمر')),
                if (student != null) ...[
                  AppSpacing.item,
                  DropdownButtonFormField<StudentStatus>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'حالة الطالب'),
                    items: const [DropdownMenuItem(value: StudentStatus.active, child: Text('نشط')), DropdownMenuItem(value: StudentStatus.transferred, child: Text('منقول')), DropdownMenuItem(value: StudentStatus.graduated, child: Text('متخرج')), DropdownMenuItem(value: StudentStatus.suspended, child: Text('موقوف'))],
                    onChanged: (value) => setSheetState(() => status = value ?? status),
                  ),
                ],
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton.icon(
          onPressed: () async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            final controller = ref.read(appControllerProvider.notifier);
            if (student == null) {
              await controller.addStudent(firstName: firstName.text.trim(), fatherName: fatherName.text.trim(), lastName: lastName.text.trim(), studentNumber: number.text.trim(), classUuid: classUuid, sectionUuid: sectionUuid, gender: gender, guardianName: guardian.text.trim(), guardianPhone: phone.text.trim());
            } else {
              await controller.updateStudent(studentUuid: student.uuid, firstName: firstName.text.trim(), fatherName: fatherName.text.trim(), lastName: lastName.text.trim(), studentNumber: number.text.trim(), classUuid: classUuid, sectionUuid: sectionUuid, gender: gender, status: status, guardianName: guardian.text.trim(), guardianPhone: phone.text.trim());
            }
            if (context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('حفظ'),
        ),
      ],
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
  const _FilterPanel({required this.controller, required this.classFilter, required this.sectionFilter, required this.classItems, required this.sectionItems, required this.attentionFilter, required this.onSearchChanged, required this.onClassChanged, required this.onSectionChanged, required this.onAttentionChanged});

  final TextEditingController controller;
  final String classFilter;
  final String sectionFilter;
  final List<SchoolClass> classItems;
  final List<Section> sectionItems;
  final String attentionFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<String?> onSectionChanged;
  final ValueChanged<String> onAttentionChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceVariant,
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
              value: classFilter,
              isDense: true,
              decoration: const InputDecoration(labelText: 'تصفية حسب الصف', isDense: true),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('كل الصفوف')),
                ...classItems.map((item) => DropdownMenuItem(value: item.uuid, child: Text(item.name))),
              ],
              onChanged: onClassChanged,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: sectionFilter,
              isDense: true,
              decoration: const InputDecoration(labelText: 'تصفية حسب الشعبة', isDense: true),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('كل الشعب')),
                ...sectionItems
                    .where((item) => classFilter == 'all' || item.classUuid == classFilter)
                    .map((item) => DropdownMenuItem(value: item.uuid, child: Text(item.name))),
              ],
              onChanged: classFilter == 'all' ? null : onSectionChanged,
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
    return ChoiceChip(
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      selected: selected,
      onSelected: (_) => onChanged(filterValue),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
      selectedColor: scheme.primaryContainer,
      backgroundColor: scheme.surface,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _choice(context, label: 'الكل', filterValue: 'all'),
          const SizedBox(width: AppTokens.compactGap / 2),
          _choice(context, label: 'تنبيهات السلوك', filterValue: 'behavior-alert'),
          const SizedBox(width: AppTokens.compactGap / 2),
          _choice(context, label: 'غياب متكرر', filterValue: 'repeated-absence'),
        ],
      ),
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
    final className = schoolClass?.name ?? 'صف غير محدد';
    final sectionName = section?.name ?? 'شعبة غير محددة';

    return Card(
      child: ListTile(
        dense: true,
        minVerticalPadding: 4,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 2, 8, 2),
        onTap: onTap,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                student.fullName,
                softWrap: true,
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: AppTokens.itemGap),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  className,
                  softWrap: true,
                  style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: AppTokens.tightGap),
                Text(
                  sectionName,
                  softWrap: true,
                  style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
        trailing: Padding(
          padding: const EdgeInsetsDirectional.only(start: AppTokens.tightGap),
          child: PopupMenuButton<String>(
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
      ),
    );
  }
}
