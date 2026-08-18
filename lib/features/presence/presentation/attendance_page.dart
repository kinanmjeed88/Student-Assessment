import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/isar_models.dart';
import '../../../core/providers.dart';
import '../../dashboard/presentation/app_shell.dart';

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  DateTime _selectedDate = DateTime.now();
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
          final students = snapshot.students;
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.event_available),
                      title: Text(_dateLabel(_selectedDate), style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${students.length} طالباً في القائمة'),
                      trailing: TextButton(onPressed: _pickDate, child: const Text('تغيير')),
                    ),
                  ),
                ),
                Expanded(
                  child: students.isEmpty
                      ? const Center(child: Text('أضف طلاباً لبدء تسجيل الحضور.'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final student = students[index];
                            final status = _draft[student.uuid] ?? AttendanceStatus.present;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                                subtitle: Text(student.studentNumber.isEmpty ? 'بدون رقم' : student.studentNumber),
                                trailing: DropdownButton<AttendanceStatus>(
                                  value: status,
                                  underline: const SizedBox.shrink(),
                                  items: AttendanceStatus.values
                                      .map((value) => DropdownMenuItem(value: value, child: Text(_statusLabel(value))))
                                      .toList(),
                                  onChanged: (value) async {
                                    if (value == null) return;
                                    setState(() => _draft[student.uuid] = value);
                                    await ref.read(appControllerProvider.notifier).setAttendance(
                                      studentUuid: student.uuid,
                                      date: _selectedDate,
                                      status: value,
                                    );
                                  },
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
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  static String _dateLabel(DateTime date) => '${date.day}/${date.month}/${date.year}';

  static String _statusLabel(AttendanceStatus status) => switch (status) {
        AttendanceStatus.present => 'حاضر',
        AttendanceStatus.absent => 'غائب',
        AttendanceStatus.excused => 'بعذر',
        AttendanceStatus.late => 'متأخر',
        AttendanceStatus.leave => 'إجازة',
      };
}
