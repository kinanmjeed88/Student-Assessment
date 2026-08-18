import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/presentation/app_shell.dart';
import 'student_details_page.dart';

class StudentsPage extends ConsumerStatefulWidget {
  const StudentsPage({super.key});

  @override
  ConsumerState<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends ConsumerState<StudentsPage> {
  final _searchController = TextEditingController();

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
        data: (snapshot) {
          final query = _searchController.text.trim();
          final students = snapshot.students.where((student) {
            return query.isEmpty ||
                student.fullName.contains(query) ||
                student.studentNumber.contains(query);
          }).toList(growable: false);
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: const Text('الطلاب')),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _showAddStudentDialog(snapshot.classes),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('إضافة طالب'),
            ),
            body: RefreshIndicator(
              onRefresh: () => ref.read(appControllerProvider.notifier).refresh(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'ابحث بالاسم أو الرقم...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: students.isEmpty
                          ? const _EmptyStudents()
                          : ListView.builder(
                              itemCount: students.length,
                              itemBuilder: (context, index) {
                                final student = students[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentDetailsPage(studentUuid: student.uuid))),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(0xFFDCE8FF),
                                        foregroundColor: AppTheme.primary,
                                        child: Text(student.firstName.characters.first),
                                      ),
                                      title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      subtitle: Text(student.studentNumber.isEmpty ? 'دون رقم طالب' : student.studentNumber),
                                      trailing: PopupMenuButton<String>(
                                        onSelected: (value) async {
                                          if (value != 'delete') return;
                                          final confirmed = await _confirmDelete(student.fullName);
                                          if (confirmed && mounted) {
                                            await ref.read(appControllerProvider.notifier).deleteStudent(student.uuid);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(value: 'delete', child: Text('حذف الطالب')),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddStudentDialog(List<dynamic> classes) async {
    if (classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف فصلاً أولاً قبل إضافة طالب.')));
      return;
    }
    final firstName = TextEditingController();
    final lastName = TextEditingController();
    final number = TextEditingController();
    var classUuid = classes.first.uuid as String;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة طالب'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: firstName, autofocus: true, decoration: const InputDecoration(labelText: 'الاسم الأول')),
                const SizedBox(height: 12),
                TextField(controller: lastName, decoration: const InputDecoration(labelText: 'اسم العائلة')),
                const SizedBox(height: 12),
                TextField(controller: number, decoration: const InputDecoration(labelText: 'رقم الطالب (اختياري)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: classUuid,
                  decoration: const InputDecoration(labelText: 'الفصل'),
                  items: classes.map((item) => DropdownMenuItem<String>(value: item.uuid as String, child: Text(item.name as String))).toList(),
                  onChanged: (value) => setDialogState(() => classUuid = value ?? classUuid),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                await ref.read(appControllerProvider.notifier).addStudent(
                  firstName: firstName.text,
                  lastName: lastName.text,
                  studentNumber: number.text,
                  classUuid: classUuid,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    firstName.dispose();
    lastName.dispose();
    number.dispose();
  }

  Future<bool> _confirmDelete(String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الطالب؟'),
        content: Text('سيتم حذف سجلات الحضور والدرجات والسلوك والملاحظات للطالب $name.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    return result ?? false;
  }
}

class _EmptyStudents extends StatelessWidget {
  const _EmptyStudents();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.groups_outlined, size: 56, color: AppTheme.primary),
          const SizedBox(height: 12),
          Text('لا توجد نتائج مطابقة.', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
