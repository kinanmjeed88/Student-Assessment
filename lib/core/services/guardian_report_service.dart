import 'dart:io';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../database/app_snapshot.dart';
import '../database/isar_models.dart';
import 'guardian_phone.dart';
import 'guardian_report_text.dart';
import 'monthly_report_scope.dart';
import 'report_service.dart';

/// النص والملف اللذان جُهزا معاً من لقطة شهرية واحدة.
class PreparedGuardianReport {
  const PreparedGuardianReport({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.text,
    required this.period,
    required this.guardianPhone,
    required this.format,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final String text;
  final MonthlyReportPeriod period;
  final String guardianPhone;
  final GuardianReportFormat format;
}

/// تصف فقط نتيجة طلب واجهة المشاركة من النظام.
///
/// [shareUiRequested] لا تعني اختيار مستلم أو نجاح الإرسال داخل التطبيق
/// المستقبِل؛ بعض منصات سطح المكتب لا تعيد نتيجة نهائية أصلاً.
enum GuardianShareOutcome { shareUiRequested, dismissed }

/// يجهّز تقرير ولي الأمر، ثم يتيح مشاركة النص والملف كلٌ على حدة.
class GuardianReportService {
  GuardianReportService({
    ReportService? reportService,
    Future<GuardianShareOutcome> Function(ShareParams params)? sharer,
  })  : _reportService = reportService ?? ReportService(),
        _sharer = sharer ?? _shareThroughPlatform;

  final ReportService _reportService;
  final Future<GuardianShareOutcome> Function(ShareParams params) _sharer;

  Future<PreparedGuardianReport> prepare({
    required AppSnapshot snapshot,
    required String studentUuid,
    required String guardianPhone,
    required GuardianReportFormat format,
    DateTime? now,
    String? text,
  }) async {
    if (text != null && text.trim().isEmpty) {
      throw const FormatException('نص الرسالة فارغ.');
    }

    Student? student;
    for (final candidate in snapshot.students) {
      if (candidate.uuid == studentUuid) {
        student = candidate;
        break;
      }
    }
    if (student == null) throw const FormatException('الطالب غير موجود.');

    final phoneError = GuardianPhone.validationError(guardianPhone);
    if (phoneError != null) throw FormatException(phoneError);

    final monthly = scopeToCurrentMonth(snapshot, now: now);
    final bytes = switch (format) {
      GuardianReportFormat.pdf =>
        await _reportService.exportStudentPdf(monthly.snapshot, studentUuid),
      GuardianReportFormat.xlsx =>
        _reportService.exportStudentXlsx(monthly.snapshot, studentUuid),
    };
    if (bytes.isEmpty) throw const FormatException('تعذر إنشاء ملف التقرير.');

    return PreparedGuardianReport(
      bytes: bytes,
      fileName: _fileName(student, monthly.period, format),
      mimeType: format.mimeType,
      // نص المعاينة يمر حرفياً حتى يكون ما شاركه المستخدم هو ما راجعه.
      text: text ??
          buildGuardianReportText(
            settings: snapshot.settings,
            student: student,
            monthly: monthly,
            format: format,
          ),
      period: monthly.period,
      guardianPhone: GuardianPhone.normalize(guardianPhone),
      format: format,
    );
  }

  /// يطلب مشاركة النص وحده بلا ملف.
  Future<GuardianShareOutcome> shareTextOnly(PreparedGuardianReport report) =>
      _sharer(
        ShareParams(
          text: report.text,
          title: 'نص تقرير الطالب',
        ),
      );

  /// يطلب مشاركة الملف المجهز نفسه بلا نص إضافي.
  Future<GuardianShareOutcome> shareFileOnly(
    PreparedGuardianReport report, {
    required String filePath,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const FormatException('ملف التقرير المجهز غير موجود.');
    }
    if (await file.length() == 0) {
      throw const FormatException('ملف التقرير المجهز فارغ.');
    }
    return _sharer(
      ShareParams(
        title: 'ملف تقرير الطالب',
        files: [XFile(file.path, mimeType: report.mimeType)],
        fileNameOverrides: [report.fileName],
      ),
    );
  }

  static Future<GuardianShareOutcome> _shareThroughPlatform(
    ShareParams params,
  ) async {
    final result = await SharePlus.instance.share(params);
    return result.status == ShareResultStatus.dismissed
        ? GuardianShareOutcome.dismissed
        : GuardianShareOutcome.shareUiRequested;
  }

  static String _fileName(
    Student student,
    MonthlyReportPeriod period,
    GuardianReportFormat format,
  ) {
    final safeName = student.fullName
        .replaceAll(RegExp(r'[\\/:*?"<>|\r\n]'), ' ')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    final name = safeName.isEmpty ? student.uuid : safeName;
    return 'تقرير_${name}_${period.startLabel}_${period.endLabel}.${format.extension}';
  }
}
