import 'dart:typed_data';

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

/// نتيجة خطوة تسليم الملف إلى المستخدم؛ `completed` تعني أن الواجهة أتمت
/// عملها (فتح المحادثة أو حفظ الملف) ولا تعني أن المستلم ضغط إرسال داخل
/// التطبيق المستقبِل أو واتساب.
enum GuardianShareOutcome { completed, dismissed }

/// يجهّز التقرير الشهري مرة واحدة لاستخدامه في المرحلتين: النص ثم الملف.
///
/// على ويندوز ٧ لا توجد ورقة مشاركة أنظمة للملفات، لذا يُفتح رابط `wa.me`
/// بنص الرسالة في المرحلة الأولى، ويُحفظ الملف باختيار المستخدم في المرحلة
/// الثانية، ويبقى الإرسال النهائي بيد المستخدم. لا يُرسل التطبيق رسالة
/// آلياً من الخلفية، وهو السلوك الموثوق دون خادم أو مفاتيح API.
class GuardianReportService {
  GuardianReportService({ReportService? reportService})
      : _reportService = reportService ?? ReportService();

  final ReportService _reportService;

  /// يولّد الملف العادي للطالب بعد تقييد بياناته بالشهر الحالي حتى [now].
  ///
  /// عند تمرير نص المعاينة [text] يُستخدم حرفياً؛ لا تُعاد صياغته هنا أبداً،
  /// فيطابق ما يراه المستخدم في المعاينة ما يُرسل في الرسالة والملف.
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
      text: text ??
          buildGuardianReportText(
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
