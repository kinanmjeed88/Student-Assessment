import '../database/isar_models.dart';

class AttendanceSummary {
  const AttendanceSummary({
    required this.absentCount,
    required this.threshold,
  });

  final int absentCount;
  final int threshold;

  bool get hasAlert => absentCount >= threshold;

  /// نص يوضح الحالة: عند التجاوز يظهر حد الفصل، وإلا يظهر عدد الغيابات.
  String get label => hasAlert ? 'تجاوز حد الغياب' : 'منتظم';

  String get detailsLabel => '$absentCount / $threshold غياب';
}

AttendanceSummary calculateAttendanceSummary({
  required Iterable<AttendanceRecord> records,
  required AppSettings settings,
}) {
  final absentCount = records.where((item) => item.status == AttendanceStatus.absent).length;
  return AttendanceSummary(
    absentCount: absentCount,
    threshold: settings.absenceThreshold,
  );
}
