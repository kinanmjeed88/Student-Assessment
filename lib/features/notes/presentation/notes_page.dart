import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_snapshot.dart';
import '../../../core/database/isar_models.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/iterable_extensions.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../students/presentation/student_details_page.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key, this.studentUuid});

  final String? studentUuid;

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  String _filter = 'all';
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
    final query = _search.text.trim();
    final notes = snapshot.notes.where((note) {
      final student = snapshot.students.where((item) => item.uuid == note.studentUuid).firstOrNull;
      final matchesStudent = widget.studentUuid == null || note.studentUuid == widget.studentUuid;
      final matchesClass = _classUuid == 'all' || student?.classUuid == _classUuid;
      final matchesSection = _sectionUuid == 'all' || student?.sectionUuid == _sectionUuid;
      final matchesFilter = _filter == 'all' || note.category.name == _filter;
      final matchesQuery = query.isEmpty ||
          note.title.contains(query) ||
          note.details.contains(query) ||
          (student?.fullName.contains(query) ?? false);
      return matchesStudent && matchesClass && matchesSection && matchesFilter && matchesQuery;
    }).toList(growable: false);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('الملاحظات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(snapshot),
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('إضافة ملاحظة'),
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
                hintText: 'ابحث في الملاحظات أو اسم الطالب',
              ),
            ),
            AppSpacing.compact,
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
            AppSpacing.compact,
            Wrap(
              spacing: AppTokens.compactGap,
              runSpacing: AppTokens.compactGap,
              children: [
                _chip('all', 'الكل'),
                _chip('academic', 'أكاديمية'),
                _chip('educational', 'تربوية'),
                _chip('attendance', 'حضور'),
                _chip('health', 'صحية'),
                _chip('other', 'أخرى'),
              ],
            ),
            AppSpacing.item,
            if (notes.isEmpty)
              const _EmptyNotes()
            else
              ...notes.map(
                (note) => _NoteCard(
                  snapshot: snapshot,
                  note: note,
                  onEdit: () => _showForm(snapshot, note: note),
                  onDelete: () => _delete(note),
                  onOpenStudent: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StudentDetailsPage(studentUuid: note.studentUuid),
                    ),
                  ),
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

  Future<void> _showForm(AppSnapshot snapshot, {StudentNote? note}) async {
    if (snapshot.students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف طالباً أولاً لإضافة ملاحظة.')),
      );
      return;
    }

    final title = TextEditingController(text: note?.title ?? '');
    final details = TextEditingController(text: note?.details ?? '');
    var studentUuid = note?.studentUuid ?? widget.studentUuid ?? snapshot.students.first.uuid;
    var category = note?.category ?? NoteCategory.academic;
    var needsFollowUp = note?.needsFollowUp ?? false;
    var followUpDate = note?.followUpDate;
    final key = GlobalKey<FormState>();
    final editing = note != null;

    await showAppFormSheet<void>(
      context: context,
      title: editing ? 'تعديل الملاحظة' : 'إضافة ملاحظة',
      subtitle: 'احفظ ملاحظة مرتبطة بالطالب مع خيار تحديد موعد متابعة.',
      child: StatefulBuilder(
        builder: (context, setState) => Form(
          key: key,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: studentUuid,
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
              DropdownButtonFormField<NoteCategory>(
                value: category,
                decoration: const InputDecoration(labelText: 'نوع الملاحظة'),
                items: const [
                  DropdownMenuItem(value: NoteCategory.academic, child: Text('أكاديمية')),
                  DropdownMenuItem(value: NoteCategory.health, child: Text('صحية')),
                  DropdownMenuItem(value: NoteCategory.educational, child: Text('تربوية')),
                  DropdownMenuItem(value: NoteCategory.attendance, child: Text('حضور')),
                  DropdownMenuItem(value: NoteCategory.other, child: Text('أخرى')),
                ],
                onChanged: (value) => setState(() => category = value ?? category),
              ),
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
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('تحتاج إلى متابعة'),
                value: needsFollowUp,
                onChanged: (value) => setState(() => needsFollowUp = value),
              ),
              if (needsFollowUp)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(
                    followUpDate == null
                        ? 'تحديد تاريخ المتابعة'
                        : 'المتابعة: ${followUpDate!.day}/${followUpDate!.month}/${followUpDate!.year}',
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: followUpDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      locale: const Locale('ar'),
                    );
                    if (picked != null) setState(() => followUpDate = picked);
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton.icon(
          onPressed: () async {
            if (!(key.currentState?.validate() ?? false)) return;
            Navigator.pop(context);
            final controller = ref.read(appControllerProvider.notifier);
            if (editing) {
              await controller.updateNote(
                noteUuid: note.uuid,
                category: category,
                title: title.text.trim(),
                details: details.text.trim(),
                needsFollowUp: needsFollowUp,
                followUpDate: needsFollowUp ? followUpDate : null,
              );
            } else {
              await controller.addNote(
                studentUuid: studentUuid,
                category: category,
                title: title.text.trim(),
                details: details.text.trim(),
                needsFollowUp: needsFollowUp,
                followUpDate: needsFollowUp ? followUpDate : null,
              );
            }
          },
          icon: Icon(editing ? Icons.save_outlined : Icons.note_add_outlined),
          label: Text(editing ? 'حفظ التعديل' : 'حفظ الملاحظة'),
        ),
      ],
    );

    title.dispose();
    details.dispose();
  }

  Future<void> _delete(StudentNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الملاحظة؟'),
        content: const Text('سيتم حذف الملاحظة نهائياً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(appControllerProvider.notifier).deleteNote(note.uuid);
    }
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.snapshot,
    required this.note,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenStudent,
  });

  final AppSnapshot snapshot;
  final StudentNote note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpenStudent;

  @override
  Widget build(BuildContext context) {
    final student = snapshot.students.where((item) => item.uuid == note.studentUuid).firstOrNull;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.compactGap),
      child: ListTile(
        onTap: onOpenStudent,
        leading: Icon(Icons.sticky_note_2_outlined, color: scheme.primary),
        title: Text(
          note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${student?.fullName ?? 'طالب غير معروف'}\n${note.details}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: AppTokens.compactGap,
          children: [
            IconButton(tooltip: 'تعديل', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
            IconButton(tooltip: 'حذف', onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes();

  @override
  Widget build(BuildContext context) => Padding(
        padding: AppSpacing.emptyState,
        child: Column(
          children: [
            Icon(Icons.note_alt_outlined, size: 60, color: Theme.of(context).colorScheme.primary),
            AppSpacing.compact,
            const Text('لا توجد ملاحظات حتى الآن.'),
          ],
        ),
      );
}
