import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/core/attendance/attendance_summary.dart';
import 'package:almoktaber/core/database/isar_models.dart';

AttendanceRecord _record(AttendanceStatus status, {String studentUuid = 'student-1'}) =>
    AttendanceRecord()
      ..studentUuid = studentUuid
      ..date = DateTime(2026, 1, 1)
      ..status = status;

void main() {
  test('counts only unexcused absences and keeps other statuses visible', () {
    final settings = AppSettings()
      ..absenceWarningThreshold = 3
      ..absenceDismissalThreshold = 5;

    final summary = calculateAttendanceSummary(
      records: [
        _record(AttendanceStatus.absent),
        _record(AttendanceStatus.absent),
        _record(AttendanceStatus.excused),
        _record(AttendanceStatus.late),
        _record(AttendanceStatus.leave),
        _record(AttendanceStatus.present),
      ],
      settings: settings,
    );

    expect(summary.absentCount, 2);
    expect(summary.excusedCount, 1);
    expect(summary.lateCount, 1);
    expect(summary.leaveCount, 1);
    expect(summary.presentCount, 1);
    expect(summary.hasAlert, isFalse);
    expect(summary.label, 'منتظم');
    expect(summary.remainingToDismissal, 3);
  });

  test('moves from warning to dismissal as unexcused absences grow', () {
    final settings = AppSettings()
      ..absenceWarningThreshold = 3
      ..absenceDismissalThreshold = 5;

    final records = <AttendanceRecord>[
      for (var index = 0; index < 3; index++) _record(AttendanceStatus.absent),
    ];

    final warning = calculateAttendanceSummary(records: records, settings: settings);
    expect(warning.warning, isTrue);
    expect(warning.dismissed, isFalse);
    expect(warning.label, 'تنبيه');

    records.addAll([
      _record(AttendanceStatus.absent),
      _record(AttendanceStatus.absent),
      _record(AttendanceStatus.excused),
    ]);

    final dismissed = calculateAttendanceSummary(records: records, settings: settings);
    expect(dismissed.warning, isFalse);
    expect(dismissed.dismissed, isTrue);
    expect(dismissed.hasAlert, isTrue);
    expect(dismissed.label, 'حد الفصل');
    expect(dismissed.remainingToDismissal, 0);
  });

  test('falls back to the default thresholds when values are missing', () {
    final settings = AppSettings()
      ..absenceWarningThreshold = 0
      ..absenceDismissalThreshold = 0;

    final summary = calculateAttendanceSummary(records: const [], settings: settings);

    expect(summary.warningThreshold, AbsenceThresholds.defaultWarning);
    expect(summary.dismissalThreshold, AbsenceThresholds.defaultDismissal);
  });

  test('normalizes missing and conflicting thresholds once', () {
    final legacy = AppSettings()
      ..absenceWarningThreshold = 0
      ..absenceDismissalThreshold = 0;

    expect(AbsenceThresholds.normalize(legacy), isTrue);
    expect(legacy.absenceWarningThreshold, AbsenceThresholds.defaultWarning);
    expect(legacy.absenceDismissalThreshold, AbsenceThresholds.defaultDismissal);
    expect(AbsenceThresholds.normalize(legacy), isFalse);

    final conflicting = AppSettings()
      ..absenceWarningThreshold = 8
      ..absenceDismissalThreshold = 4;

    expect(AbsenceThresholds.normalize(conflicting), isTrue);
    expect(conflicting.absenceDismissalThreshold, 8);
  });

  test('exposes absence limits in the settings payload', () {
    final settings = AppSettings()
      ..absenceWarningThreshold = 4
      ..absenceDismissalThreshold = 9;

    final json = settings.toJson();
    final attendance = json['attendance'] as Map<String, dynamic>;

    expect(attendance['warningThreshold'], 4);
    expect(attendance['dismissalThreshold'], 9);
  });
}
