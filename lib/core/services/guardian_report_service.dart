import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// نتيجة اختيار المستخدم في ورقة المشاركة النظامية.
enum GuardianShareOutcome { shared, dismissed }

/// يجهّز التقرير الشهري ويشاركه عبر واتساب أو أي تطبيق مشاركة آخر.
///
/// لا يُرسل التطبيق رسالة آلياً من الخلفية: يُفتح واتساب أو قائمة المشاركة
/// ويبقى الإرسال النهائي بيد المستخدم، وهو السلوك الموثوق دون خادم أو مفاتيح API.
class GuardianReportService {
  GuardianReportService({ReportService? reportService})
      : _reportService = reportService ?? ReportService();

  final ReportService _reportService;

  /// يولّد الملف العادي للطالب بعد تقييد بياناته بالشهر الحالي حتى [now].
  Future<PreparedGuardianReport> prepare({
    required AppSnapshot snapshot,
    required String studentUuid,
    required String guardianPhone,
    required GuardianReportFormat format,
    DateTime? now,
  }) async {
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
      text: buildGuardianReportText(
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

  /// يفتح قائمة المشاركة في النظام مع النص والملف ليسهل اختيار واتساب.
  Future<GuardianShareOutcome> share(PreparedGuardianReport report) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        text: report.text,
        title: 'تقرير الطالب',
        files: [
          XFile.fromData(report.bytes, mimeType: report.mimeType),
        ],
        fileNameOverrides: [report.fileName],
      ),
    );
    return switch (result.status) {
      ShareResultStatus.dismissed => GuardianShareOutcome.dismissed,
      _ => GuardianShareOutcome.shared,
    };
  }

  /// بديل مباشر عندما يتعذر إرفاق ملف من قائمة المشاركة: يفتح محادثة الرقم
  /// المثبت بالنص جاهزاً، ويطلب من المستخدم إرفاق الملف يدوياً.
  Future<void> openWhatsAppChat(PreparedGuardianReport report) async {
    final uri = GuardianPhone.chatUri(
      phone: report.guardianPhone,
      text: report.text,
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw const FormatException('تعذر فتح واتساب. تأكد من تثبيت التطبيق.');
    }
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
