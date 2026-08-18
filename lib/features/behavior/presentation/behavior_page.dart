import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_snapshot.dart';
import '../../../core/database/isar_models.dart';
import '../../../core/providers.dart';
import '../../dashboard/presentation/app_shell.dart';
import '../../../core/utils/iterable_extensions.dart';

class BehaviorPage extends ConsumerStatefulWidget {
  const BehaviorPage({super.key, this.studentUuid});
  final String? studentUuid;

  @override
  ConsumerState<BehaviorPage> createState() => _BehaviorPageState();
}

class _BehaviorPageState extends ConsumerState<BehaviorPage> {
  String _filter = 'all';
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
    final records = snapshot.behaviors.where((item) {
      final student = snapshot.students.where((s) => s.uuid == item.studentUuid).firstOrNull;
      final query = _search.text.trim();
      final matchesStudent = widget.studentUuid == null || item.studentUuid == widget.studentUuid;
      final matchesQuery = query.isEmpty || item.title.contains(query) || item.details.contains(query) || (student?.fullName.contains(query) ?? false);
      final matchesFilter = _filter == 'all' || item.category.name == _filter;
      return matchesStudent && matchesQuery && matchesFilter;
    }).toList(growable: false);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('السلوك والمتابعة')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _showForm(snapshot), icon: const Icon(Icons.add_task_outlined), label: const Text('تسجيل سلوك')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(appControllerProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          children: [
            TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث في السلوك أو اسم الطالب')),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [_chip('all', 'الكل'), _chip('negative', 'سلبي'), _chip('positive', 'إيجابي'), _chip('followup', 'متابعة')]),
            const SizedBox(height: 16),
            if (records.isEmpty)
              const _EmptyBehavior()
            else
              ...records.map((record) => _BehaviorCard(snapshot: snapshot, record: record, onDelete: () => _delete(record))),
          ],
        ),
      ),
    );
  }

  Widget _chip(String value, String label) => ChoiceChip(label: Text(label), selected: _filter == value, onSelected: (_) => setState(() => _filter = value));

  Future<void> _showForm(AppSnapshot snapshot) async {
    if (snapshot.students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف طالباً أولاً لتسجيل السلوك.')));
      return;
    }
    final title = TextEditingController();
    final details = TextEditingController();
    final action = TextEditingController();
    final followUp = TextEditingController();
    var studentUuid = widget.studentUuid ?? snapshot.students.first.uuid;
    var category = BehaviorCategory.negative;
    var type = BehaviorViolationType.other;
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('تسجيل سلوك'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(children: [
                  DropdownButtonFormField<String>(value: studentUuid, decoration: const InputDecoration(labelText: 'الطالب'), items: snapshot.students.map((s) => DropdownMenuItem(value: s.uuid, child: Text(s.fullName))).toList(), onChanged: (v) => setState(() => studentUuid = v ?? studentUuid)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<BehaviorCategory>(value: category, decoration: const InputDecoration(labelText: 'التصنيف'), items: const [DropdownMenuItem(value: BehaviorCategory.negative, child: Text('سلوك سلبي')), DropdownMenuItem(value: BehaviorCategory.positive, child: Text('سلوك إيجابي')), DropdownMenuItem(value: BehaviorCategory.followup, child: Text('متابعة'))], onChanged: (v) => setState(() => category = v ?? category)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<BehaviorViolationType>(value: type, decoration: const InputDecoration(labelText: 'نوع المخالفة'), items: const [DropdownMenuItem(value: BehaviorViolationType.absence, child: Text('غياب')), DropdownMenuItem(value: BehaviorViolationType.lessonDisruption, child: Text('تشويش الدرس')), DropdownMenuItem(value: BehaviorViolationType.seriousMisconduct, child: Text('مخالفة جسيمة')), DropdownMenuItem(value: BehaviorViolationType.other, child: Text('أخرى'))], onChanged: (v) => setState(() => type = v ?? type)),
                  const SizedBox(height: 10),
                  TextFormField(controller: title, decoration: const InputDecoration(labelText: 'العنوان'), validator: (v) => v == null || v.trim().isEmpty ? 'العنوان مطلوب' : null),
                  const SizedBox(height: 10),
                  TextFormField(controller: details, maxLines: 3, decoration: const InputDecoration(labelText: 'التفاصيل'), validator: (v) => v == null || v.trim().isEmpty ? 'التفاصيل مطلوبة' : null),
                  const SizedBox(height: 10),
                  TextFormField(controller: action, decoration: const InputDecoration(labelText: 'الإجراء المتخذ')),
                  const SizedBox(height: 10),
                  TextFormField(controller: followUp, decoration: const InputDecoration(labelText: 'خطة المتابعة')),
                ]),
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')), ElevatedButton(onPressed: () async { if (!(formKey.currentState?.validate() ?? false)) return; await ref.read(appControllerProvider.notifier).addBehavior(studentUuid: studentUuid, category: category, title: title.text, details: details.text, violationType: type, actionTaken: action.text, followUp: followUp.text); if (dialogContext.mounted) Navigator.pop(dialogContext); }, child: const Text('حفظ'))],
        ),
      ),
    );
    title.dispose(); details.dispose(); action.dispose(); followUp.dispose();
  }

  Future<void> _delete(BehaviorRecord record) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('حذف السجل؟'), content: const Text('سيتم حذف سجل السلوك نهائياً.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف'))]));
    if (confirmed == true) await ref.read(appControllerProvider.notifier).deleteBehavior(record.uuid);
  }
}

class _BehaviorCard extends StatelessWidget {
  const _BehaviorCard({required this.snapshot, required this.record, required this.onDelete});
  final AppSnapshot snapshot;
  final BehaviorRecord record;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final student = snapshot.students.where((item) => item.uuid == record.studentUuid).firstOrNull;
    final color = record.category == BehaviorCategory.positive ? scheme.primary : record.category == BehaviorCategory.negative ? scheme.error : scheme.tertiary;
    return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: CircleAvatar(backgroundColor: color.withOpacity(.12), foregroundColor: color, child: Icon(record.category == BehaviorCategory.positive ? Icons.thumb_up_alt_outlined : Icons.flag_outlined)), title: Text(record.title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${student?.fullName ?? 'طالب غير معروف'}\n${record.details}\n${record.penaltyPoints > 0 ? 'خصم ${record.penaltyPoints} نقطة' : 'دون خصم'}'), isThreeLine: true, trailing: IconButton(tooltip: 'حذف', onPressed: onDelete, icon: const Icon(Icons.delete_outline))));
  }
}

class _EmptyBehavior extends StatelessWidget {
  const _EmptyBehavior();
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 80), child: Column(children: [Icon(Icons.fact_check_outlined, size: 60, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 12), const Text('لا توجد سجلات سلوك حتى الآن.')]))
}
