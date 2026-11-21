import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../database/app_snapshot.dart';
import '../database/isar_models.dart';
import 'guardian_phone.dart';
import 'guardian_report_text.dart';
import 'monthly_report_scope.dart';
import 'report_service.dart';

/// كل ما يحتاجه إرسال تقرير ولي الأمر: الملف الشهري والنص المصاحب ورقمه.
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

/// نتيجة ورقة المشاركة النظامية؛ `completed` تعني أن الواجهة أكملت عملها
/// ولا تعني أن المستلم ضغط إرسال داخل التطبيق المستقبِل.
enum GuardianShareOutcome { completed, dismissed }

/// يجهّز التقرير الشهري ويشاركه عبر واتساب أو أي تطبيق مشاركة آخر.
///
/// لا يُرسل التطبيق رسالة آلياً من الخلفية: يُفتح واتساب أو قائمة المشاركة
/// ويبقى الإرسال النهائي بيد المستخدم، وهو السلوك الموثوق دون خادم أو مفاتيح API.
class GuardianReportService {
  GuardianReportService({
    ReportService? reportService,
    Future<GuardianShareOutcome> Function(ShareParams params)? sharer,
  })  : _reportService = reportService ?? ReportService(),
        _sharer = sharer ?? _shareThroughPlatform;

  final ReportService _reportService;
  final Future<GuardianShareOutcome> Function(ShareParams params) _sharer;

  /// يولّد الملف العادي للطالب بعد تقييد بياناته بالشهر الحالي حتى [now].
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

    final normalizedPhone = GuardianPhone.normalize(guardianPhone);
    return PreparedGuardianReport(
      bytes: bytes,
      fileName: _fileName(student, monthly.period, format),
      mimeType: format.mimeType,
      // عند تمرير نص المعاينة يُستخدم حرفياً؛ لا تُعاد صياغته هنا أبداً.
      text: text ?? buildGuardianReportText(
        settings: snapshot.settings,
        student: student,
        monthly: monthly,
        format: format,
      ),
      period: monthly.period,
      guardianPhone: normalizedPhone,
      format: format,
    );
  }

  /// يشارك النص وحده، ويُستخدم على المنصات التي لا تفتح تطبيق واتساب.
  Future<GuardianShareOutcome> shareTextOnly(PreparedGuardianReport report) =>
      _sharer(ShareParams(
        text: report.text,
        title: 'تقرير الطالب',
      ));

  /// يشارك الملف وحده في رسالة مستقلة، دون أي نص إضافي.
  Future<GuardianShareOutcome> shareFileOnly(PreparedGuardianReport report) =>
      _sharer(ShareParams(
        title: 'تقرير الطالب',
        files: [
          XFile.fromData(report.bytes, mimeType: report.mimeType),
        ],
        fileNameOverrides: [report.fileName],
      ));

  /// يبقى متاحاً للتوافق مع أي استخدام سابق، لكن مسار ولي الأمر الجديد
  /// يستخدم المرحلتين المنفصلتين ولا يعتمد على اجتماع النص والملف.
  Future<GuardianShareOutcome> share(PreparedGuardianReport report) =>
      _sharer(ShareParams(
        text: report.text,
        title: 'تقرير الطالب',
        files: [
          XFile.fromData(report.bytes, mimeType: report.mimeType),
        ],
        fileNameOverrides: [report.fileName],
      ));

  static Future<GuardianShareOutcome> _shareThroughPlatform(
    ShareParams params,
  ) async {
    final result = await SharePlus.instance.share(params);
    return switch (result.status) {
      ShareResultStatus.dismissed => GuardianShareOutcome.dismissed,
      _ => GuardianShareOutcome.completed,
    };
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
