import '../behavior/behavior_summary.dart';
import '../database/isar_models.dart';
import 'monthly_report_scope.dart';

/// صيغة ملف تقرير ولي الأمر.
enum GuardianReportFormat {
  pdf('pdf', 'PDF', 'application/pdf'),
  xlsx(
    'xlsx',
    'Excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );

  const GuardianReportFormat(this.extension, this.label, this.mimeType);

  final String extension;
  final String label;
  final String mimeType;
}

/// يبني نص المعاينة من اللقطة الشهرية نفسها المستخدمة لإنشاء الملف.
///
/// تُحسب أعداد الحضور هنا مباشرةً كي لا يعيد فرع Windows إدخال ميزة ملخص
/// الحضور التي أزيلت منه عمداً.
String buildGuardianReportText({
  required AppSettings settings,
  required Student student,
  required MonthlyStudentReport monthly,
  required GuardianReportFormat format,
}) {
  final snapshot = monthly.snapshot;
  final records = snapshot.attendanceFor(student.uuid);
  final presentCount = records
      .where((record) => record.status == AttendanceStatus.present)
      .length;
  final absentCount = records
      .where((record) => record.status == AttendanceStatus.absent)
      .length;
  final excusedCount = records
      .where((record) => record.status == AttendanceStatus.excused)
      .length;
  final lateCount = records
      .where((record) => record.status == AttendanceStatus.late)
      .length;
  final behavior = calculateBehaviorSummary(
    records: snapshot.behaviorsFor(student.uuid),
    settings: settings,
  );
  final gradeCount = snapshot.gradesFor(student.uuid).length;
  final noteCount = snapshot.notesFor(student.uuid).length;
  final school = settings.schoolName.trim();
  final teacher = settings.teacherName.trim();

  final lines = <String>[
    'السلام عليكم ورحمة الله وبركاته،',
    'تقرير الطالب ${student.fullName} عن الفترة من ${monthly.period.startLabel} إلى ${monthly.period.endLabel}.',
    'الحضور: $presentCount يوم حضور، $absentCount يوم غياب بدون عذر، $excusedCount بعذر، $lateCount تأخر.',
    'الدرجات: $gradeCount تقييم مسجّل خلال الفترة.',
    'السلوك: ${_numberLabel(behavior.totalPoints)} نقطة — ${behavior.label}.',
    'الملاحظات: $noteCount ملاحظة مسجّلة خلال الفترة.',
    if (school.isNotEmpty) 'المدرسة: $school',
    if (teacher.isNotEmpty) 'المعلم: $teacher',
    'سيُشارك ملف التقرير بنفس تنسيق ملف الطالب في رسالة مستقلة بصيغة ${format.label}، ويغطي الفترة المذكورة فقط.',
  ];
  return lines.join('\n');
}

String _numberLabel(double value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}
