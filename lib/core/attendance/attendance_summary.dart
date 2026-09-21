import '../database/isar_models.dart';

/// ملخص مواظبة الطالب المحسوب من سجلات الحضور وحدود الغياب في الإعدادات.
///
/// الأساس في الاحتساب هو الغياب بدون عذر ([AttendanceStatus.absent])، أما
/// الغياب بعذر والتأخر والإجازة فتبقى ظاهرة في الملخص دون أن تُحتسب على
/// الطالب في حدي التنبيه والفصل.
class AttendanceSummary {
  const AttendanceSummary({
    required this.absentCount,
    required this.excusedCount,
    required this.lateCount,
    required this.leaveCount,
    required this.presentCount,
    required this.warningThreshold,
    required this.dismissalThreshold,
  });

  /// عدد أيام الغياب بدون عذر.
  final int absentCount;

  /// عدد أيام الغياب بعذر.
  final int excusedCount;

  /// عدد أيام التأخر.
  final int lateCount;

  /// عدد أيام الإجازة.
  final int leaveCount;

  /// عدد أيام الحضور.
  final int presentCount;

  /// عدد أيام الغياب الذي يبدأ عنده التنبيه.
  final int warningThreshold;

  /// عدد أيام الغياب الذي يُعد بلوغه حد فصل.
  final int dismissalThreshold;

  bool get dismissed => absentCount >= dismissalThreshold;
  bool get warning => !dismissed && absentCount >= warningThreshold;
  bool get hasAlert => dismissed || warning;

  /// عدد أيام الغياب المتبقية قبل بلوغ حد الفصل.
  int get remainingToDismissal => absentCount >= dismissalThreshold
      ? 0
      : dismissalThreshold - absentCount;

  String get label => dismissed ? 'حد الفصل' : warning ? 'تنبيه' : 'منتظم';
}

/// يحسب ملخص المواظبة من سجلات الحضور وحدود الإعدادات الحالية.
AttendanceSummary calculateAttendanceSummary({
  required Iterable<AttendanceRecord> records,
  required AppSettings settings,
}) {
  var absent = 0;
  var excused = 0;
  var lateRecords = 0;
  var leave = 0;
  var present = 0;
  for (final record in records) {
    switch (record.status) {
      case AttendanceStatus.absent:
        absent++;
      case AttendanceStatus.excused:
        excused++;
      case AttendanceStatus.late:
        lateRecords++;
      case AttendanceStatus.leave:
        leave++;
      case AttendanceStatus.present:
        present++;
    }
  }

  final dismissalThreshold = AbsenceThresholds.dismissalOf(settings);
  final rawWarningThreshold = AbsenceThresholds.warningOf(settings);

  return AttendanceSummary(
    absentCount: absent,
    excusedCount: excused,
    lateCount: lateRecords,
    leaveCount: leave,
    presentCount: present,
    warningThreshold: rawWarningThreshold > dismissalThreshold
        ? dismissalThreshold
        : rawWarningThreshold,
    dismissalThreshold: dismissalThreshold,
  );
}
