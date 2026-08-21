import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/isar_models.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../dashboard/presentation/app_shell.dart';

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  DateTime _selectedDate = DateTime.now();
  String _classUuid = 'all';
  String _sectionUuid = 'all';
  final Map<String, AttendanceStatus> _draft = {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    return AsyncStateView(
      state: state,
      child: state.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (snapshot) {
          final students = snapshot.students.where((student) {
            final matchesClass = _classUuid == 'all' || student.classUuid == _classUuid;
            final matchesSection = _sectionUuid == 'all' || student.sectionUuid == _sectionUuid;
            return matchesClass && matchesSection;
          }).toList(growable: false);
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              title: const Text('الحضور اليومي'),
              actions: [
                IconButton(
                  tooltip: 'اختيار التاريخ',
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ],
            ),
            body: Column(
              children: [
                Padding(
                  padding: AppSpacing.contentList.copyWith(top: AppTokens.compactGap, bottom: AppTokens.compactGap),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _classUuid,
                        decoration: const InputDecoration(labelText: 'تصفية الصف', floatingLabelBehavior: FloatingLabelBehavior.always),
                        items: [const DropdownMenuItem(value: 'all', child: Text('كل الصفوف')), ...snapshot.classes.map((item) => DropdownMenuItem(value: item.uuid, child: Text(item.name)))],
                        onChanged: (value) => setState(() {
                          _classUuid = value ?? 'all';
                          if (_sectionUuid != 'all' && !snapshot.sections.any((section) => section.uuid == _sectionUuid && section.classUuid == _classUuid)) _sectionUuid = 'all';
                        }),
                      ),
                      AppSpacing.item,
                      DropdownButtonFormField<String>(
                        value: _sectionUuid,
                        decoration: const InputDecoration(labelText: 'تصفية الشعبة', floatingLabelBehavior: FloatingLabelBehavior.always),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('كل الشعب')),
                          ...snapshot.sections.where((section) => _classUuid == 'all' || section.classUuid == _classUuid).map((section) => DropdownMenuItem(value: section.uuid, child: Text(section.name))),
                        ],
                        onChanged: (value) => setState(() => _sectionUuid = value ?? 'all'),
                      ),
                      AppSpacing.item,
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.event_available),
                          title: Text(_dateLabel(_selectedDate), style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text('${students.length} طالباً في القائمة'),
                          trailing: TextButton(onPressed: _pickDate, child: const Text('تغيير')),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: students.isEmpty
                      ? const Center(child: Text('أضف طلاباً لبدء تسجيل الحضور.'))
                      : ListView.builder(
                          padding: AppSpacing.contentList.copyWith(top: 0, bottom: 28),
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final student = students[index];
                            final existing = snapshot.attendance.where((item) => item.studentUuid == student.uuid && _sameDay(item.date, _selectedDate)).firstOrNull;
                            final status = _draft[student.uuid] ?? existing?.status ?? AttendanceStatus.present;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                                subtitle: Text(student.studentNumber.isEmpty ? 'بدون رقم' : student.studentNumber),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    DropdownButton<AttendanceStatus>(
                                      value: status,
                                      underline: const SizedBox.shrink(),
                                      items: AttendanceStatus.values
                                          .map((value) => DropdownMenuItem(value: value, child: Text(_statusLabel(value))))
                                          .toList(),
                                      onChanged: (value) async {
                                        if (value == null) return;
                                        setState(() => _draft[student.uuid] = value);
                                        await ref.read(appControllerProvider.notifier).updateAttendance(
                                          studentUuid: student.uuid,
                                          date: _selectedDate,
                                          status: value,
                                        );
                                      },
                                    ),
                                    if (existing != null)
                                      IconButton(
                                        tooltip: 'حذف سجل الحضور',
                                        onPressed: () => _deleteAttendance(student.uuid),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('ar'),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _draft.clear();
      });
    }
  }

  Future<void> _deleteAttendance(String studentUuid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف سجل الحضور؟'),
        content: const Text('سيتم حذف تسجيل هذا الطالب في التاريخ المحدد.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(appControllerProvider.notifier).deleteAttendance(
          studentUuid: studentUuid,
          date: _selectedDate,
        );
    setState(() => _draft.remove(studentUuid));
  }

  static bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year && first.month == second.month && first.day == second.day;

  static String _dateLabel(DateTime date) => '${date.day}/${date.month}/${date.year}';

  static String _statusLabel(AttendanceStatus status) => switch (status) {
        AttendanceStatus.present => 'حاضر',
        AttendanceStatus.absent => 'غائب',
        AttendanceStatus.excused => 'بعذر',
        AttendanceStatus.late => 'متأخر',
        AttendanceStatus.leave => 'إجازة',
      };
}
