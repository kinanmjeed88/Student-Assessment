import '../attendance/attendance_summary.dart';
import '../behavior/behavior_summary.dart';
import '../database/app_snapshot.dart';
import '../database/isar_models.dart';

/// مصدر الإشعار المعروض داخل زر الإشعارات في الصفحة الرئيسية.
enum StudentAlertCategory { absence, behavior }

/// درجة الإشعار بحسب الحد الذي بلغه الطالب.
enum StudentAlertLevel { warning, dismissal }

/// إشعار واحد مرتبط بطالب، إما بسبب الغياب أو بسبب السلوك.
class StudentAlert {
  const StudentAlert({
    required this.student,
    required this.category,
    required this.level,
    required this.detail,
    required this.recordedAt,
  });

  final Student student;
  final StudentAlertCategory category;
  final StudentAlertLevel level;

  /// وصف مختصر لسبب الإشعار يظهر في قائمة الإشعارات.
  final String detail;

  /// تاريخ آخر واقعة أدت إلى الإشعار إن وُجدت.
  final DateTime? recordedAt;

  bool get isDismissal => level == StudentAlertLevel.dismissal;

  String get categoryLabel => switch (category) {
        StudentAlertCategory.absence => 'غياب',
        StudentAlertCategory.behavior => 'سلوك',
      };

  String get levelLabel => switch (level) {
        StudentAlertLevel.dismissal => 'حد الفصل',
        StudentAlertLevel.warning => 'تنبيه',
      };

  /// ترتيب الخطورة: حد الفصل أعلى من التنبيه.
  int get severity => switch (level) {
        StudentAlertLevel.dismissal => 2,
        StudentAlertLevel.warning => 1,
      };
}

/// يبني قائمة الإشعارات الموحدة للغياب والسلوك مرتبة حسب الخطورة ثم الاسم.
///
/// قد يظهر الطالب أكثر من مرة إذا كان لديه إشعار غياب وإشعار سلوك معاً، لأن
/// كل سطر يوضح سبباً مستقلاً ويمكن الانتقال منه إلى ملف الطالب.
List<StudentAlert> buildStudentAlerts(AppSnapshot snapshot) {
  final alerts = <StudentAlert>[];
  for (final student in snapshot.students) {
    final behaviorRecords = snapshot.behaviorsFor(student.uuid);
    final behavior = calculateBehaviorSummary(
      records: behaviorRecords,
      settings: snapshot.settings,
    );
    if (behavior.hasAlert) {
      alerts.add(
        StudentAlert(
          student: student,
          category: StudentAlertCategory.behavior,
          level: behavior.dismissed
              ? StudentAlertLevel.dismissal
              : StudentAlertLevel.warning,
          detail:
              'الدرجة السلوكية ${_formatPoints(behavior.totalPoints)} من ${_formatPoints(behavior.dismissalThreshold)}',
          recordedAt: _latestDate(behaviorRecords.map((record) => record.date)),
        ),
      );
    }

    final attendanceRecords = snapshot.attendanceFor(student.uuid);
    final absenceRecords = attendanceRecords
        .where((record) => record.status == AttendanceStatus.absent)
        .toList(growable: false);
    final attendance = calculateAttendanceSummary(
      records: attendanceRecords,
      settings: snapshot.settings,
    );
    if (attendance.hasAlert) {
      alerts.add(
        StudentAlert(
          student: student,
          category: StudentAlertCategory.absence,
          level: attendance.dismissed
              ? StudentAlertLevel.dismissal
              : StudentAlertLevel.warning,
          detail:
              'غياب بدون عذر ${attendance.absentCount} من ${attendance.dismissalThreshold} يوماً',
          recordedAt: _latestDate(absenceRecords.map((record) => record.date)),
        ),
      );
    }
  }

  alerts.sort((first, second) {
    final bySeverity = second.severity.compareTo(first.severity);
    if (bySeverity != 0) return bySeverity;
    final byCategory = first.category.index.compareTo(second.category.index);
    if (byCategory != 0) return byCategory;
    return first.student.fullName.compareTo(second.student.fullName);
  });

  return List<StudentAlert>.unmodifiable(alerts);
}

DateTime? _latestDate(Iterable<DateTime> dates) {
  DateTime? latest;
  for (final date in dates) {
    if (latest == null || date.isAfter(latest)) latest = date;
  }
  return latest;
}

String _formatPoints(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
