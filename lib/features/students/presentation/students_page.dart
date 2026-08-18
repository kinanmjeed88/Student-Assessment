import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/behavior/behavior_summary.dart';
import '../../../core/database/app_snapshot.dart';
import '../../../core/database/isar_models.dart';
import '../../../core/providers.dart';
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('الطلاب'),
        actions: [
          IconButton(
            tooltip: 'استيراد الطلاب',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ImportStudentsPage())),
            icon: const Icon(Icons.upload_file_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStudentForm(snapshot),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('إضافة طالب'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(appControllerProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          children: [
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'ابحث بالاسم أو الرقم...', prefixIcon: Icon(Icons.search)),
            ),
            const SizedBox(height: 12),
            _FilterRow(
              label: 'الصف',
              value: _classFilter,
              items: [
                const DropdownMenuItem(value: 'all', child: Text('كل الصفوف')),
                ...snapshot.classes.map((item) => DropdownMenuItem(value: item.uuid, child: Text(item.name))),
              ],
              onChanged: (value) => setState(() => _classFilter = value ?? 'all'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _attentionChip('all', 'الكل'),
                _attentionChip('behavior-alert', 'تنبيهات السلوك'),
                _attentionChip('repeated-absence', 'غياب متكرر'),
              ],
            ),
            const SizedBox(height: 16),
            Text('${students.length} طالب', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (students.isEmpty)
              const _EmptyStudents()
            else
              ...students.map((student) => _StudentCard(snapshot: snapshot, student: student, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentDetailsPage(studentUuid: student.uuid))), onEdit: () => _showStudentForm(snapshot, student: student), onDelete: () => _deleteStudent(student))),
          ],
        ),
      ),
    );
  }

  Widget _attentionChip(String value, String label) {
    return ChoiceChip(label: Text(label), selected: _attentionFilter == value, onSelected: (_) => setState(() => _attentionFilter = value));
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
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _RequiredField(controller: firstName, label: 'الاسم الأول'),
                    const SizedBox(height: 10),
                    TextFormField(controller: fatherName, decoration: const InputDecoration(labelText: 'اسم الأب')),
                    const SizedBox(height: 10),
                    _RequiredField(controller: lastName, label: 'اسم العائلة'),
                    const SizedBox(height: 10),
                    TextFormField(controller: number, decoration: const InputDecoration(labelText: 'رقم الطالب')),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<StudentGender>(
                      value: gender,
                      decoration: const InputDecoration(labelText: 'الجنس'),
                      items: const [DropdownMenuItem(value: StudentGender.male, child: Text('ذكر')), DropdownMenuItem(value: StudentGender.female, child: Text('أنثى'))],
                      onChanged: (value) => setDialogState(() => gender = value ?? gender),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: classUuid,
                      decoration: const InputDecoration(labelText: 'الصف'),
                      items: snapshot.classes.map((item) => DropdownMenuItem(value: item.uuid, child: Text(item.name))).toList(),
                      onChanged: (value) => setDialogState(() {
                        classUuid = value ?? classUuid;
                        if (!snapshot.sections.any((section) => section.uuid == sectionUuid && section.classUuid == classUuid)) sectionUuid = '';
                      }),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: sectionUuid.isEmpty ? null : sectionUuid,
                      decoration: const InputDecoration(labelText: 'الشعبة (اختياري)'),
                      items: snapshot.sections.where((item) => item.classUuid == classUuid).map((item) => DropdownMenuItem(value: item.uuid, child: Text(item.name))).toList(),
                      onChanged: (value) => setDialogState(() => sectionUuid = value ?? ''),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(controller: guardian, decoration: const InputDecoration(labelText: 'ولي الأمر')),
                    const SizedBox(height: 10),
                    TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'هاتف ولي الأمر')),
                    if (student != null) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<StudentStatus>(
                        value: status,
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
            ElevatedButton(
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
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('حذف الطالب؟'), content: Text('سيتم حذف حضور ودرجات وسلوك وملاحظات ${student.fullName}.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف'))]));
    if (confirmed == true) await ref.read(appControllerProvider.notifier).deleteStudent(student.uuid);
  }
}

class _RequiredField extends StatelessWidget {
  const _RequiredField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextFormField(controller: controller, decoration: InputDecoration(labelText: label), validator: (value) => value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null);
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.label, required this.value, required this.items, required this.onChanged});
  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(initialValue: value, decoration: InputDecoration(labelText: label), items: items, onChanged: onChanged);
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
    final scheme = Theme.of(context).colorScheme;
    final summary = calculateBehaviorSummary(records: snapshot.behaviorsFor(student.uuid), settings: snapshot.settings);
    final absences = snapshot.attendanceFor(student.uuid).where((item) => item.status == AttendanceStatus.absent).length;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(backgroundColor: scheme.primaryContainer, foregroundColor: scheme.primary, child: Text(student.firstName.isEmpty ? '?' : student.firstName.characters.first)),
        title: Text(student.fullName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Wrap(spacing: 6, runSpacing: 4, children: [Text(student.studentNumber.isEmpty ? 'دون رقم' : student.studentNumber), if (absences > 0) _MiniBadge(label: 'غياب $absences', color: scheme.error), if (summary.hasAlert) _MiniBadge(label: summary.label, color: scheme.tertiary)])),
        trailing: PopupMenuButton<String>(onSelected: (value) { if (value == 'edit') onEdit(); if (value == 'delete') onDelete(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('تعديل')), PopupMenuItem(value: 'delete', child: Text('حذف'))]),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => DecoratedBox(decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700))));
}

class _EmptyStudents extends StatelessWidget {
  const _EmptyStudents();
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 70), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.groups_outlined, size: 56, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 12), Text('لا توجد نتائج مطابقة.', style: Theme.of(context).textTheme.titleMedium)]));
}
