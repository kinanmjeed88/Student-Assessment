import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/database/app_snapshot.dart';
import '../../../core/database/isar_models.dart';
import '../../../core/services/guardian_phone.dart';
import '../../../core/services/guardian_phone_copier.dart';
import '../../../core/services/guardian_report_file_store.dart';
import '../../../core/services/guardian_report_service.dart';
import '../../../core/services/guardian_report_text.dart';
import '../../../core/services/guardian_send_session.dart';
import '../../../core/services/monthly_report_scope.dart';
import '../../../core/widgets/app_components.dart';

const String guardianReportStartLabel = 'إرسال التقرير والملف';
const String guardianReportFileStepTitle = 'إرسال ملف التقرير';

Future<void> showGuardianReportSheet({
  required BuildContext context,
  required AppSnapshot snapshot,
  required Student student,
  required GuardianReportService reportService,
  required GuardianReportFileStore fileStore,
  required GuardianPhoneCopier phoneCopier,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => GuardianReportSheet(
      snapshot: snapshot,
      student: student,
      reportService: reportService,
      fileStore: fileStore,
      phoneCopier: phoneCopier,
    ),
  );
}

class GuardianReportSheet extends StatefulWidget {
  const GuardianReportSheet({
    required this.snapshot,
    required this.student,
    required this.reportService,
    required this.fileStore,
    required this.phoneCopier,
    super.key,
  });

  final AppSnapshot snapshot;
  final Student student;
  final GuardianReportService reportService;
  final GuardianReportFileStore fileStore;
  final GuardianPhoneCopier phoneCopier;

  @override
  State<GuardianReportSheet> createState() => _GuardianReportSheetState();
}

class _GuardianReportSheetState extends State<GuardianReportSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phone;
  late final GuardianSendSession _session;
  late final DateTime _reportNow;
  late final MonthlyStudentReport _monthlyPreview;
  late String _previewText;
  GuardianReportFormat _format = GuardianReportFormat.pdf;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: widget.student.guardianPhone);
    _reportNow = DateTime.now();
    _monthlyPreview = scopeToCurrentMonth(
      widget.snapshot,
      now: _reportNow,
    );
    _previewText = _buildPreviewText();
    _session = GuardianSendSession(removeFile: widget.fileStore.remove);
  }

  @override
  void dispose() {
    unawaited(_session.dispose());
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GuardianSendSnapshot>(
      valueListenable: _session.state,
      builder: (context, sendState, _) {
        final busy = sendState.isBusy;
        return PopScope(
          canPop: !busy,
          child: AppFormSheet(
            title: 'إرسال تقرير ولي الأمر',
            subtitle:
                'يُجهَّز نص المعاينة وملف الشهر الحالي مرة واحدة، ثم تُفتح مشاركتهما في خطوتين منفصلتين.',
            closeEnabled: !busy,
            actions: _buildActions(context, sendState),
            child: _buildContent(context, sendState),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    GuardianSendSnapshot sendState,
  ) {
    final showSetup = sendState.stage == GuardianSendStage.idle ||
        (sendState.stage == GuardianSendStage.failed &&
            _session.report == null);
    if (showSetup) return _buildSetup(context, sendState);

    final report = _session.report;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _stageTitle(sendState),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        Text(sendState.message),
        if (sendState.error.isNotEmpty) ...[
          AppSpacing.item,
          _StatusMessage(
            icon: Icons.error_outline,
            message: sendState.error,
            color: Theme.of(context).colorScheme.error,
          ),
        ],
        if (sendState.warning.isNotEmpty) ...[
          AppSpacing.item,
          _StatusMessage(
            icon: Icons.info_outline,
            message: sendState.warning,
            color: Theme.of(context).colorScheme.tertiary,
          ),
        ],
        if (_session.autoCopySucceeded) ...[
          AppSpacing.item,
          const _StatusMessage(
            icon: Icons.content_copy_outlined,
            message: 'نُسخ الرقم الدولي تلقائياً عند بدء العملية.',
          ),
        ],
        if (report != null) ...[
          AppSpacing.item,
          _SheetInfo(label: 'الصيغة', value: report.format.label),
          AppSpacing.item,
          _SheetInfo(
            label: 'فترة التقرير',
            value:
                '${report.period.startLabel} إلى ${report.period.endLabel}',
          ),
          AppSpacing.item,
          _PhoneInfo(
            phone: report.guardianPhone,
            onCopy: () => _copyPhone(report.guardianPhone),
          ),
          AppSpacing.item,
          _SheetInfo(label: 'الملف المجهز', value: report.fileName),
        ],
        AppSpacing.item,
        const _ManualSendNotice(),
      ],
    );
  }

  Widget _buildSetup(
    BuildContext context,
    GuardianSendSnapshot sendState,
  ) {
    final normalized = GuardianPhone.normalize(_phone.text);
    final scheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sendState.error.isNotEmpty) ...[
            _StatusMessage(
              icon: Icons.error_outline,
              message: sendState.error,
              color: scheme.error,
            ),
            AppSpacing.item,
          ],
          Text(
            'الرقم المثبت في الملف: ${widget.student.guardianPhone.isEmpty ? 'غير محدد' : widget.student.guardianPhone}',
          ),
          AppSpacing.item,
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'رقم هاتف ولي الأمر',
              helperText:
                  'إذا لم يظهر ولي الأمر، انسخ الرقم الدولي وابحث عنه في التطبيق أو أضفه إلى جهات الاتصال.',
              suffixIcon: IconButton(
                tooltip: 'نسخ الرقم الدولي',
                icon: const Icon(Icons.copy_all_outlined),
                onPressed: () => _copyPhone(_phone.text),
              ),
            ),
            validator: (_) => GuardianPhone.validationError(_phone.text),
            onChanged: (_) => setState(() {}),
          ),
          if (normalized.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'الصيغة الدولية التي ستُنسخ: $normalized',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          AppSpacing.item,
          SegmentedButton<GuardianReportFormat>(
            selected: {_format},
            onSelectionChanged: (value) {
              setState(() {
                _format = value.first;
                _previewText = _buildPreviewText();
              });
            },
            segments: const [
              ButtonSegment(
                value: GuardianReportFormat.pdf,
                label: Text('PDF'),
                icon: Icon(Icons.picture_as_pdf_outlined),
              ),
              ButtonSegment(
                value: GuardianReportFormat.xlsx,
                label: Text('Excel'),
                icon: Icon(Icons.table_view_outlined),
              ),
            ],
          ),
          AppSpacing.item,
          _SheetInfo(
            label: 'فترة التقرير',
            value:
                '${_monthlyPreview.period.startLabel} إلى ${_monthlyPreview.period.endLabel}',
          ),
          AppSpacing.item,
          Text(
            'معاينة الرسالة',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_previewText),
          ),
          AppSpacing.item,
          const _ManualSendNotice(),
        ],
      ),
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    GuardianSendSnapshot sendState,
  ) {
    final busy = sendState.isBusy;
    return [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: Text(
          sendState.stage == GuardianSendStage.completed ? 'إغلاق' : 'إلغاء',
        ),
      ),
      if (sendState.stage != GuardianSendStage.completed)
        FilledButton.icon(
          onPressed: busy ? null : () => _handlePrimary(sendState),
          icon: busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  sendState.retryStep == GuardianRetryStep.file ||
                          sendState.stage == GuardianSendStage.fileReady
                      ? Icons.attach_file
                      : Icons.send_outlined,
                ),
          label: Text(_actionLabel(sendState)),
        ),
    ];
  }

  Future<void> _handlePrimary(GuardianSendSnapshot sendState) async {
    if (sendState.stage == GuardianSendStage.fileReady ||
        sendState.retryStep == GuardianRetryStep.file) {
      await _shareFile();
      return;
    }
    await _startText();
  }

  Future<void> _startText() async {
    if (_session.report == null &&
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final rawPhone = _phone.text;

    await _session.startText(
      prepare: () => widget.reportService.prepare(
        snapshot: widget.snapshot,
        studentUuid: widget.student.uuid,
        guardianPhone: rawPhone,
        format: _format,
        now: _reportNow,
        text: _previewText,
      ),
      writeFile: widget.fileStore.write,
      copyPhone: (phone) async {
        final copied = await widget.phoneCopier.copy(phone);
        return copied != null;
      },
      shareText: widget.reportService.shareTextOnly,
    );
  }

  Future<void> _shareFile() => _session.shareFile(
        share: (report, path) => widget.reportService.shareFileOnly(
          report,
          filePath: path,
        ),
      );

  String _buildPreviewText() => buildGuardianReportText(
        settings: widget.snapshot.settings,
        student: widget.student,
        monthly: _monthlyPreview,
        format: _format,
      );

  Future<void> _copyPhone(String rawPhone) async {
    try {
      final copied = await widget.phoneCopier.copy(rawPhone);
      if (!mounted) return;
      _showMessage(
        copied == null
            ? 'رقم ولي الأمر غير صالح.'
            : 'نُسخ الرقم الدولي: $copied',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('تعذر نسخ الرقم: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _stageTitle(GuardianSendSnapshot state) => switch (state.stage) {
        GuardianSendStage.preparing => 'جارٍ تجهيز التقرير',
        GuardianSendStage.textSharing => 'مشاركة نص التقرير',
        GuardianSendStage.fileReady => guardianReportFileStepTitle,
        GuardianSendStage.fileSharing => 'جارٍ فتح مشاركة الملف',
        GuardianSendStage.completed => 'طُلبت مشاركة ملف التقرير',
        GuardianSendStage.failed => state.retryStep == GuardianRetryStep.file
            ? 'تعذر فتح مشاركة الملف'
            : 'تعذر مشاركة النص',
        GuardianSendStage.idle => '',
      };

  String _actionLabel(GuardianSendSnapshot state) => switch (state.stage) {
        GuardianSendStage.idle => guardianReportStartLabel,
        GuardianSendStage.preparing => 'جارٍ التجهيز...',
        GuardianSendStage.textSharing => 'جارٍ فتح مشاركة النص...',
        GuardianSendStage.fileReady => guardianReportFileStepTitle,
        GuardianSendStage.fileSharing => 'جارٍ فتح مشاركة الملف...',
        GuardianSendStage.failed => state.retryStep == GuardianRetryStep.file
            ? 'إعادة مشاركة الملف'
            : _session.report == null
                ? guardianReportStartLabel
                : 'إعادة مشاركة النص',
        GuardianSendStage.completed => 'إغلاق',
      };
}

class _ManualSendNotice extends StatelessWidget {
  const _ManualSendNotice();

  @override
  Widget build(BuildContext context) => Card.filled(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.privacy_tip_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'لا يختار التطبيق المستلم ولا يرسل النص أو الملف تلقائياً. اختر التطبيق والمستلم، وراجع المحتوى، ثم أكد الإرسال بنفسك. مشاركة الملف تفتح طلباً جديداً ولا توجهه إلى المحادثة السابقة.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
}

class _PhoneInfo extends StatelessWidget {
  const _PhoneInfo({required this.phone, required this.onCopy});

  final String phone;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: _SheetInfo(label: 'الرقم الدولي', value: phone)),
          IconButton(
            tooltip: 'نسخ الرقم الدولي',
            onPressed: onCopy,
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      );
}

class _SheetInfo extends StatelessWidget {
  const _SheetInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          Expanded(child: Text(value)),
        ],
      );
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.message,
    this.color,
  });

  final IconData icon;
  final String message;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                  ),
            ),
          ),
        ],
      );
}
