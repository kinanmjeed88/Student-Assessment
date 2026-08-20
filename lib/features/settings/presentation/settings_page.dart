import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simple_icons/simple_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/isar_models.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../dashboard/presentation/app_shell.dart';
import '../../import/presentation/import_history_page.dart';
import '../../import/presentation/import_students_page.dart';
import '../../reports/presentation/reports_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _schoolController = TextEditingController();
  final _teacherController = TextEditingController();
  final _yearController = TextEditingController();
  final _stageController = TextEditingController();
  final _dismissalController = TextEditingController();
  final _warningController = TextEditingController();
  final _absencePointsController = TextEditingController();
  final _disruptionPointsController = TextEditingController();
  final _seriousMisconductPointsController = TextEditingController();
  final _otherPointsController = TextEditingController();
  bool _institutionLineAnimated = false;
  double _institutionLineSpeed = 40;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _schoolController.dispose();
    _teacherController.dispose();
    _yearController.dispose();
    _stageController.dispose();
    _dismissalController.dispose();
    _warningController.dispose();
    _absencePointsController.dispose();
    _disruptionPointsController.dispose();
    _seriousMisconductPointsController.dispose();
    _otherPointsController.dispose();
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
          if (!_initialized) {
            _schoolController.text = snapshot.settings.schoolName;
            _teacherController.text = snapshot.settings.teacherName;
            _yearController.text = snapshot.settings.academicYear;
            _stageController.text = snapshot.settings.stage;
            _dismissalController.text = _number(snapshot.settings.dismissalThreshold);
            _warningController.text = _number(snapshot.settings.warningThreshold);
            _absencePointsController.text = _number(snapshot.settings.penalties.absence);
            _disruptionPointsController.text = _number(snapshot.settings.penalties.lessonDisruption);
            _seriousMisconductPointsController.text = _number(snapshot.settings.penalties.seriousMisconduct);
            _otherPointsController.text = _number(snapshot.settings.penalties.other);
            _institutionLineAnimated = snapshot.settings.institutionLineAnimated;
            _institutionLineSpeed = snapshot.settings.institutionLineSpeed.clamp(10, 200).toDouble();
            _initialized = true;
          }
          return Scaffold(
            appBar: AppBar(title: const Text('الإعدادات')),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                AppResponsiveContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppPageHeader(title: 'إعدادات النظام', subtitle: 'خصّص بيانات المدرسة ونظّم أدوات البيانات والإشعارات.'),
                      const AppSectionHeader(title: 'بيانات المؤسسة', subtitle: 'تظهر هذه البيانات في التقارير والملفات المصدّرة.'),
                      AppSpacing.compact,
                      AppSurfaceCard(
                        child: Column(
                          children: [
                            _field(_schoolController, 'اسم المدرسة', Icons.school_outlined),
                            AppSpacing.item,
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 520;
                                final teacher = _field(_teacherController, 'اسم المعلم', Icons.person_outline);
                                final year = _field(_yearController, 'العام الدراسي', Icons.calendar_today_outlined);
                                return compact ? Column(children: [teacher, AppSpacing.item, year]) : Row(children: [Expanded(child: teacher), const SizedBox(width: 12), Expanded(child: year)]);
                              },
                            ),
                            AppSpacing.item,
                            _field(_stageController, 'المرحلة الدراسية', Icons.account_tree_outlined),
                            const SizedBox(height: 18),
                            Align(alignment: AlignmentDirectional.centerStart, child: FilledButton.icon(onPressed: _saving ? null : _saveInstitutionSettings, icon: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: const Text('حفظ بيانات المؤسسة'))),
                          ],
                        ),
                      ),
                      AppSpacing.section,
                      const AppSectionHeader(title: 'سطر المؤسسة في الرئيسية', subtitle: 'اعرض اسم المعلم والمدرسة أسفل عنوان سجل الطالب بشكل ثابت أو متحرك.'),
                      AppSpacing.compact,
                      AppSurfaceCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            SwitchListTile(
                              secondary: const Icon(Icons.short_text_outlined),
                              title: const Text('تفعيل الحركة'),
                              subtitle: const Text('يتحرك السطر تلقائياً عندما يكون النص أطول من المساحة المتاحة.'),
                              value: _institutionLineAnimated,
                              onChanged: _saving
                                  ? null
                                  : (value) {
                                      setState(() => _institutionLineAnimated = value);
                                      _saveInstitutionLineSettings();
                                    },
                            ),
                            if (_institutionLineAnimated) ...[
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text('سرعة الحركة: ${_institutionLineSpeed.round()} بكسل/ثانية', style: Theme.of(context).textTheme.titleSmall),
                                    Slider(
                                      value: _institutionLineSpeed,
                                      min: 10,
                                      max: 200,
                                      divisions: 19,
                                      label: '${_institutionLineSpeed.round()}',
                                      onChanged: _saving ? null : (value) => setState(() => _institutionLineSpeed = value),
                                      onChangeEnd: _saving ? null : (_) => _saveInstitutionLineSettings(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      AppSpacing.section,
                      const AppSectionHeader(title: 'نقاط السلوك', subtitle: 'حدد نقاط كل نوع وحدود التنبيه والفصل المستخدمة في ملف الطالب.'),
                      AppSpacing.compact,
                      AppSurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 520;
                                final warning = _numberField(_warningController, 'حد التنبيه');
                                final dismissal = _numberField(_dismissalController, 'حد الفصل');
                                return compact ? Column(children: [warning, AppSpacing.item, dismissal]) : Row(children: [Expanded(child: warning), const SizedBox(width: 12), Expanded(child: dismissal)]);
                              },
                            ),
                            AppSpacing.item,
                            Text('نقاط المخالفات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 520;
                                final absence = _numberField(_absencePointsController, 'غياب');
                                final disruption = _numberField(_disruptionPointsController, 'تشويش الدرس');
                                final serious = _numberField(_seriousMisconductPointsController, 'سلوك جسيم');
                                final other = _numberField(_otherPointsController, 'أخرى');
                                final fields = [absence, disruption, serious, other];
                                if (compact) return Column(children: [for (var index = 0; index < fields.length; index++) ...[fields[index], if (index < fields.length - 1) AppSpacing.item]]);
                                return Row(children: [for (var index = 0; index < fields.length; index++) ...[Expanded(child: fields[index]), if (index < fields.length - 1) const SizedBox(width: 8)]]);
                              },
                            ),
                            const SizedBox(height: 14),
                            Text('تُطبّق هذه القيم تلقائياً عند تسجيل مخالفة جديدة، بينما تبقى السجلات السابقة محفوظة بنقاطها المسجلة.', style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 18),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: FilledButton.icon(
                                onPressed: _saving ? null : _saveBehaviorSettings,
                                icon: _saving
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: const Text('حفظ نقاط السلوك'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.section,
                      const AppSectionHeader(title: 'إدارة البيانات', subtitle: 'استورد وسلّم التقارير والنسخ الاحتياطية بأمان.'),
                      AppSpacing.compact,
                      AppSurfaceCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _tile(context, Icons.assessment_outlined, 'التقارير والتصدير', 'إنشاء ملفات XLSX وPDF ونسخ احتياطية', const ReportsPage()),
                            const Divider(height: 1),
                            _tile(context, Icons.upload_file_outlined, 'استيراد الطلاب', 'إضافة مجموعة من ملف Excel أو CSV أو Word', const ImportStudentsPage()),
                            const Divider(height: 1),
                            _tile(context, Icons.history_outlined, 'سجل الاستيراد', 'مراجعة العمليات والتراجع عنها بأمان', const ImportHistoryPage()),
                            const Divider(height: 1),
                            _actionTile(context, Icons.restore_outlined, 'استعادة نسخة JSON', 'استبدال البيانات المحلية بمحتوى ملف احتياطي', _restoreBackup),
                            const Divider(height: 1),
                            _actionTile(context, Icons.backup_outlined, 'تصدير نسخة احتياطية', 'JSON شامل لجميع مجالات التطبيق', _exportBackup),
                          ],
                        ),
                      ),
                      AppSpacing.section,
                      const AppSectionHeader(title: 'الإشعارات والخصوصية', subtitle: 'تحكم في الصلاحيات وطبيعة تخزين البيانات.'),
                      AppSpacing.compact,
                      AppSurfaceCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _actionTile(context, Icons.notifications_active_outlined, 'صلاحيات التنبيهات', 'تهيئة إشعارات Android عند الحاجة', _requestNotificationPermission),
                            const Divider(height: 1),
                            _actionTile(context, Icons.person_outline, 'حول مطور التطبيق', 'معلومات المطور ووسائل التواصل', () => _showDeveloperInfo(context)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  TextField _field(TextEditingController controller, String label, IconData icon) => TextField(controller: controller, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)));

  TextField _numberField(TextEditingController controller, String label) => TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: label, suffixText: 'نقطة'));

  String _number(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

  ListTile _tile(BuildContext context, IconData icon, String title, String subtitle, Widget page) => ListTile(leading: Icon(icon, color: Theme.of(context).colorScheme.primary), title: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), subtitle: Text(subtitle), trailing: Icon(Icons.arrow_back_ios_new, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page)));

  ListTile _actionTile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) => ListTile(leading: Icon(icon, color: Theme.of(context).colorScheme.primary), title: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), subtitle: Text(subtitle), trailing: Icon(Icons.arrow_back_ios_new, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant), onTap: onTap);

  Future<void> _saveInstitutionSettings() async {
    setState(() => _saving = true);
    try {
      await ref.read(appControllerProvider.notifier).saveSettings(
            schoolName: _schoolController.text,
            teacherName: _teacherController.text,
            academicYear: _yearController.text,
            stage: _stageController.text,
            institutionLineAnimated: _institutionLineAnimated,
            institutionLineSpeed: _institutionLineSpeed,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ بيانات المؤسسة بنجاح.')));
    } on FormatException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveBehaviorSettings() async {
    final values = [
      _warningController,
      _dismissalController,
      _absencePointsController,
      _disruptionPointsController,
      _seriousMisconductPointsController,
      _otherPointsController,
    ].map((controller) => double.tryParse(controller.text.trim().replaceAll(',', '.'))).toList();
    if (values.any((value) => value == null || value < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل أرقاماً صحيحة وغير سالبة لإعدادات السلوك.')));
      return;
    }
    final warning = values[0]!;
    final dismissal = values[1]!;
    if (warning > dismissal) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حد التنبيه يجب أن يكون أقل من أو مساوياً لحد الفصل.')));
      return;
    }
    final penalties = PenaltyRules()
      ..absence = values[2]!
      ..lessonDisruption = values[3]!
      ..seriousMisconduct = values[4]!
      ..other = values[5]!;
    setState(() => _saving = true);
    try {
      await ref.read(appControllerProvider.notifier).saveSettings(
            schoolName: _schoolController.text,
            teacherName: _teacherController.text,
            academicYear: _yearController.text,
            stage: _stageController.text,
            warningThreshold: warning,
            dismissalThreshold: dismissal,
            penalties: penalties,
            institutionLineAnimated: _institutionLineAnimated,
            institutionLineSpeed: _institutionLineSpeed,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات بنجاح.')));
    } on FormatException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveInstitutionLineSettings() async {
    try {
      await ref.read(appControllerProvider.notifier).saveSettings(
            schoolName: _schoolController.text,
            teacherName: _teacherController.text,
            academicYear: _yearController.text,
            stage: _stageController.text,
            institutionLineAnimated: _institutionLineAnimated,
            institutionLineSpeed: _institutionLineSpeed,
          );
    } on FormatException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _showDeveloperInfo(BuildContext context) async {
    const links = <_SocialLink>[
      _SocialLink('Telegram', SimpleIcons.telegram, 'https://t.me/techtouch7'),
      _SocialLink('YouTube', SimpleIcons.youtube, 'https://youtube.com/@kinanmajeed?si=I2yuzJT2rRnEHLVg'),
      _SocialLink('Instagram', SimpleIcons.instagram, 'https://www.instagram.com/techtouch0'),
      _SocialLink('Facebook', SimpleIcons.facebook, 'https://www.facebook.com/share/1EsapVHA6W/'),
      _SocialLink('TikTok', SimpleIcons.tiktok, 'https://www.tiktok.com/@techtouch6'),
    ];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        final textTheme = Theme.of(dialogContext).textTheme;
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          titlePadding: const EdgeInsets.fromLTRB(28, 26, 28, 0),
          contentPadding: const EdgeInsets.fromLTRB(28, 20, 28, 10),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
          title: const Center(child: Text('حول مطور التطبيق')),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(child: Text('المطور', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: scheme.primary))),
                const SizedBox(height: 10),
                Center(child: Text('كنان الصائغ', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900))),
                const SizedBox(height: 4),
                Center(child: Text('Kinan Al-Sayegh', style: textTheme.titleMedium)),
                const SizedBox(height: 18),
                Center(child: Text('التطبيق حالياً مجاني - نسخة تجريبية', style: textTheme.bodyLarge)),
                const SizedBox(height: 24),
                Center(child: Text('للتواصل', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final iconButtonSize = ((constraints.maxWidth - 10) / links.length).clamp(40.0, 52.0).toDouble();
                    return Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final link in links)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: IconButton(
                                tooltip: link.label,
                                onPressed: () => _openSocialLink(dialogContext, link.url),
                                icon: Icon(link.icon, size: 25),
                                style: IconButton.styleFrom(
                                  minimumSize: Size.square(iconButtonSize),
                                  maximumSize: Size.square(iconButtonSize),
                                  padding: EdgeInsets.zero,
                                  foregroundColor: scheme.primary,
                                  backgroundColor: scheme.primaryContainer,
                                  shape: const CircleBorder(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
          ],
        );
      },
    );
  }

  Future<void> _openSocialLink(BuildContext context, String value) async {
    final uri = Uri.parse(value);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط.')));
    }
  }

  Future<void> _requestNotificationPermission() async {
    final granted = await ref.read(notificationServiceProvider).requestPermissions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(granted ? 'تم تفعيل صلاحية التنبيهات.' : 'لم يتم منح صلاحية التنبيهات.')));
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('استعادة النسخة؟'), content: const Text('سيتم حذف البيانات المحلية الحالية واستبدالها بمحتوى الملف.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('متابعة'))]));
    if (confirmed != true) return;
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (files.isEmpty) return;
    final bytes = await files.first.readAsBytes();
    try {
      await ref.read(appControllerProvider.notifier).restoreBackup(utf8.decode(bytes));
      if (!mounted) return;
      setState(() => _initialized = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت استعادة النسخة الاحتياطية.')));
    } on FormatException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _exportBackup() async {
    final json = await ref.read(localRepositoryProvider).exportBackupJson();
    final path = await FilePicker.saveFile(dialogTitle: 'حفظ النسخة الاحتياطية', fileName: 'student-record-backup.json', bytes: Uint8List.fromList(utf8.encode(json)));
    if (mounted && path != null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تصدير النسخة الاحتياطية.')));
  }
}


class _SocialLink {
  const _SocialLink(this.label, this.icon, this.url);

  final String label;
  final IconData icon;
  final String url;
}
