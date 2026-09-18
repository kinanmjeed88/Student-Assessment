import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/core/database/app_snapshot.dart';
import 'package:almoktaber/core/database/isar_models.dart';
import 'package:almoktaber/core/notifications/student_alert.dart';

Student _student({required String uuid, required String fullName}) => Student()
  ..uuid = uuid
  ..fullName = fullName
  ..firstName = fullName.split(' ').first
  ..lastName = fullName.split(' ').last
  ..classUuid = 'class-1';

AttendanceRecord _absence(String studentUuid, int day) => AttendanceRecord()
  ..studentUuid = studentUuid
  ..date = DateTime(2026, 2, day)
  ..status = AttendanceStatus.absent;

BehaviorRecord _violation(String studentUuid, double points) => BehaviorRecord()
  ..uuid = 'behavior-$studentUuid'
  ..studentUuid = studentUuid
  ..category = BehaviorCategory.negative
  ..violationType = BehaviorViolationType.other
  ..title = 'مخالفة'
  ..details = 'تفاصيل المخالفة'
  ..penaltyPoints = points;

AppSnapshot _snapshot({
  required AppSettings settings,
  required List<Student> students,
  required List<AttendanceRecord> attendance,
  required List<BehaviorRecord> behaviors,
}) =>
    AppSnapshot(
      settings: settings,
      classes: const [],
      sections: const [],
      students: students,
      gradeFields: const [],
      grades: const [],
      attendance: attendance,
      todayAttendance: const [],
      behaviors: behaviors,
      notes: const [],
      imports: const [],
    );

void main() {
  final settings = AppSettings()
    ..warningThreshold = 10
    ..dismissalThreshold = 20
    ..absenceWarningThreshold = 3
    ..absenceDismissalThreshold = 5;

  test('collects absence and behavior alerts ordered by severity', () {
    final snapshot = _snapshot(
      settings: settings,
      students: [
        _student(uuid: 'student-a', fullName: 'أحمد العلي'),
        _student(uuid: 'student-b', fullName: 'سارة محمد'),
      ],
      attendance: [
        for (var day = 1; day <= 5; day++) _absence('student-a', day),
        _absence('student-b', 1),
      ],
      behaviors: [_violation('student-b', 25)],
    );

    final alerts = buildStudentAlerts(snapshot);

    expect(alerts, hasLength(2));
    expect(alerts.first.student.uuid, 'student-a');
    expect(alerts.first.category, StudentAlertCategory.absence);
    expect(alerts.first.level, StudentAlertLevel.dismissal);
    expect(alerts.first.isDismissal, isTrue);
    expect(alerts.first.detail, 'غياب بدون عذر 5 من 5 يوماً');
    expect(alerts.first.recordedAt, DateTime(2026, 2, 5));

    expect(alerts.last.student.uuid, 'student-b');
    expect(alerts.last.category, StudentAlertCategory.behavior);
    expect(alerts.last.level, StudentAlertLevel.dismissal);
    expect(alerts.last.detail, 'الدرجة السلوكية 25 من 20');
  });

  test('ignores excused absences and behavior below the warning limit', () {
    final snapshot = _snapshot(
      settings: settings,
      students: [_student(uuid: 'student-c', fullName: 'خالد يوسف')],
      attendance: [
        AttendanceRecord()
          ..studentUuid = 'student-c'
          ..date = DateTime(2026, 2, 1)
          ..status = AttendanceStatus.excused,
        AttendanceRecord()
          ..studentUuid = 'student-c'
          ..date = DateTime(2026, 2, 2)
          ..status = AttendanceStatus.late,
      ],
      behaviors: [_violation('student-c', 4)],
    );

    expect(buildStudentAlerts(snapshot), isEmpty);
  });

  test('shows a warning level when only the warning limit is reached', () {
    final snapshot = _snapshot(
      settings: settings,
      students: [_student(uuid: 'student-d', fullName: 'ليان سعد')],
      attendance: [_absence('student-d', 3)],
      behaviors: const [],
    );

    final alerts = buildStudentAlerts(snapshot);

    expect(alerts, hasLength(1));
    expect(alerts.single.level, StudentAlertLevel.warning);
    expect(alerts.single.levelLabel, 'تنبيه');
    expect(alerts.single.categoryLabel, 'غياب');
    expect(alerts.single.detail, 'غياب بدون عذر 3 من 5 يوماً');
  });
}
