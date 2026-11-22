import '../behavior/behavior_summary.dart';
import '../database/isar_models.dart';
import 'monthly_report_scope.dart';

/// صيغة ملف التقرير المُرسل إلى ولي الأمر.
enum GuardianReportFormat {
  pdf('pdf', 'PDF', 'application/pdf'),
  xlsx('xlsx', 'Excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

  const GuardianReportFormat(this.extension, this.label, this.mimeType);

  final String extension;
  final String label;
  final String mimeType;
}

/// النص المكتوب الذي يرافق الملف في رسالة واتساب.
///
/// يُبنى من اللقطة الشهرية نفسها التي تُبنى منها المرفقات، فتتطابق الأرقام
/// الواردة في الرسالة مع الأرقام الظاهرة داخل الملف تماماً.
String buildGuardianReportText({
  required AppSettings settings,
  required Student student,
  required MonthlyStudentReport monthly,
  required GuardianReportFormat format,
}) {
  final snapshot = monthly.snapshot;
  // فرع ويندوز ٧ لا يضم وحدة ملخص الحضور في main، فتُحتسب الأرقام الأربعة
  // من سجلات اللقطة نفسها بنفس احتساب `calculateAttendanceSummary` حتى
  // يبقى نص الرسالة مطابقاً لنص PR #12 حرفياً.
  var presentCount = 0;
  var absentCount = 0;
  var excusedCount = 0;
  var lateCount = 0;
  for (final record in snapshot.attendanceFor(student.uuid)) {
    switch (record.status) {
      case AttendanceStatus.present:
        presentCount++;
      case AttendanceStatus.absent:
        absentCount++;
      case AttendanceStatus.excused:
        excusedCount++;
      case AttendanceStatus.late:
        lateCount++;
      case AttendanceStatus.leave:
        break;
    }
  }

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
    'نرفق إليكم تقرير الطالب ${student.fullName} عن الفترة من ${monthly.period.startLabel} إلى ${monthly.period.endLabel}.',
    'الحضور: $presentCount يوم حضور، $absentCount يوم غياب بدون عذر، $excusedCount بعذر، $lateCount تأخر.',
    'الدرجات: $gradeCount تقييم مسجّل خلال الفترة.',
    'السلوك: ${behavior.totalPoints.toStringAsFixed(0)} نقطة — ${behavior.label}.',
    'الملاحظات: $noteCount ملاحظة مسجّلة خلال الفترة.',
    if (school.isNotEmpty) 'المدرسة: $school',
    if (teacher.isNotEmpty) 'المعلم: $teacher',
    'المرفق ملف التقرير بنفس تنسيق ملف الطالب في التطبيق بصيغة ${format.label}، ويغطي الفترة المذكورة فقط.',
  ];
  return lines.join('\n');
}
